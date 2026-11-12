extends Node3D
## Stores and draws every block the player has placed.
## Blocks sit on a 0.5 m grid and are grouped into chunks. Each chunk is one mesh and one
## collision shape, and faces hidden between two blocks are skipped, so big builds stay fast.

const BlockTypes := preload("res://scripts/building/block_types.gd")
const BLOCK_MATERIAL := preload("res://materials/block.tres")

const BLOCK_SIZE := BlockTypes.BLOCK_SIZE
## Blocks per chunk side (16 blocks = 8 m).
const CHUNK_SIZE := 16

## The six faces of a unit cube. Corner order gives the clockwise winding Godot draws as the front.
const FACES := [
	{"normal": Vector3i(1, 0, 0), "corners": [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]},
	{"normal": Vector3i(-1, 0, 0), "corners": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]},
	{"normal": Vector3i(0, 1, 0), "corners": [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]},
	{"normal": Vector3i(0, -1, 0), "corners": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)]},
	{"normal": Vector3i(0, 0, 1), "corners": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]},
	{"normal": Vector3i(0, 0, -1), "corners": [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]},
]
const TRIANGLE_ORDER := [0, 1, 2, 0, 2, 3]

## cell (Vector3i) -> block type (int), for every block in the world.
var _blocks := {}
## chunk (Vector3i) -> { cell: type } for the blocks inside that chunk.
var _chunk_blocks := {}
## chunk (Vector3i) -> StaticBody3D holding that chunk's mesh and collision.
var _chunk_bodies := {}
## Chunks waiting to be rebuilt at the end of this frame.
var _dirty := {}


# --- Grid helpers ----------------------------------------------------------------

static func world_to_cell(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x / BLOCK_SIZE), floori(point.y / BLOCK_SIZE), floori(point.z / BLOCK_SIZE))


static func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(cell) * BLOCK_SIZE


static func cell_center(cell: Vector3i) -> Vector3:
	return cell_to_world(cell) + Vector3.ONE * (BLOCK_SIZE * 0.5)


static func cell_aabb(cell: Vector3i) -> AABB:
	return AABB(cell_to_world(cell), Vector3.ONE * BLOCK_SIZE)


static func is_block_body(node: Object) -> bool:
	return node is Node and node.is_in_group("voxel_chunks")


# --- Placing and removing --------------------------------------------------------

func has_block(cell: Vector3i) -> bool:
	return _blocks.has(cell)


func get_block(cell: Vector3i) -> int:
	return _blocks.get(cell, 0)


func get_block_count() -> int:
	return _blocks.size()


func place_block(cell: Vector3i, type: int) -> bool:
	if _blocks.has(cell):
		return false
	_blocks[cell] = type
	var chunk := _chunk_of(cell)
	if not _chunk_blocks.has(chunk):
		_chunk_blocks[chunk] = {}
	_chunk_blocks[chunk][cell] = type
	_mark_dirty_around(cell)
	return true


## Removes a block and returns its type (0 if there was none).
func remove_block(cell: Vector3i) -> int:
	if not _blocks.has(cell):
		return 0
	var type: int = _blocks[cell]
	_blocks.erase(cell)
	var chunk := _chunk_of(cell)
	_chunk_blocks[chunk].erase(cell)
	if _chunk_blocks[chunk].is_empty():
		_chunk_blocks.erase(chunk)
	_mark_dirty_around(cell)
	return type


# --- Saving ----------------------------------------------------------------------

## Saved as a flat list: x, y, z, type, x, y, z, type, ...
func get_save_data() -> Array:
	var flat := []
	for cell in _blocks:
		flat.append_array([cell.x, cell.y, cell.z, _blocks[cell]])
	return flat


func apply_save_data(flat: Array) -> void:
	for i in range(0, flat.size() - 3, 4):
		var cell := Vector3i(int(flat[i]), int(flat[i + 1]), int(flat[i + 2]))
		place_block(cell, int(flat[i + 3]))


# --- Meshing ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _dirty.is_empty():
		return
	for chunk in _dirty:
		_rebuild_chunk(chunk)
	_dirty.clear()


func _chunk_of(cell: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(cell.x) / CHUNK_SIZE),
		floori(float(cell.y) / CHUNK_SIZE),
		floori(float(cell.z) / CHUNK_SIZE))


## A block change can reveal or hide faces of its neighbours, which may be in other chunks.
func _mark_dirty_around(cell: Vector3i) -> void:
	_dirty[_chunk_of(cell)] = true
	for face in FACES:
		_dirty[_chunk_of(cell + face["normal"])] = true


func _rebuild_chunk(chunk: Vector3i) -> void:
	var cells: Dictionary = _chunk_blocks.get(chunk, {})
	var body: StaticBody3D = _chunk_bodies.get(chunk)

	if cells.is_empty():
		if body != null:
			body.queue_free()
			_chunk_bodies.erase(chunk)
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_count := 0

	for cell in cells:
		var info := BlockTypes.get_info(cells[cell])
		var tint := _tint_for(cell)
		var origin := cell_to_world(cell)
		for face in FACES:
			var normal: Vector3i = face["normal"]
			if _blocks.has(cell + normal):
				continue  # Hidden behind a neighbouring block.
			var base_color: Color = info["end"] if normal.y != 0 else info["side"]
			var corners: Array = face["corners"]
			st.set_normal(Vector3(normal))
			for index in TRIANGLE_ORDER:
				var corner: Vector3 = corners[index]
				# Slightly darker along the bottom edge of side faces, for a bit of depth.
				var shade := tint
				if normal.y == 0 and corner.y < 0.5:
					shade *= 0.82
				st.set_color(Color(base_color.r * shade, base_color.g * shade, base_color.b * shade))
				st.add_vertex(origin + corner * BLOCK_SIZE)
			face_count += 1

	if body == null:
		body = StaticBody3D.new()
		body.name = "Chunk_%d_%d_%d" % [chunk.x, chunk.y, chunk.z]
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("voxel_chunks")
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		body.add_child(mesh_instance)
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		body.add_child(shape)
		add_child(body)
		_chunk_bodies[chunk] = body

	var mesh_node: MeshInstance3D = body.get_node("Mesh")
	var collision: CollisionShape3D = body.get_node("Collision")
	if face_count == 0:
		mesh_node.mesh = null
		collision.shape = null
		return

	st.set_material(BLOCK_MATERIAL)
	var mesh := st.commit()
	mesh_node.mesh = mesh
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape


## Small colour variation per block so walls don't look flat.
func _tint_for(cell: Vector3i) -> float:
	var h := absi(hash(cell)) % 1000
	return 0.9 + (h / 1000.0) * 0.2
