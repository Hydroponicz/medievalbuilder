extends StaticBody3D
## Smooth, rolling terrain generated from noise.
## The ground is deliberately NOT blocky. Only player-made buildings will be voxel-based.

const TERRAIN_MATERIAL := preload("res://materials/terrain.tres")

## Width and depth of the map in metres.
@export var world_size := 160
## How tall the rolling hills get.
@export var height_scale := 6.0
## Lower = wider, gentler hills.
@export var noise_frequency := 0.01
## Flat clearing around the spawn point.
@export var clearing_radius := 16.0
## Hills rise at the map edge so the world feels naturally bounded.
@export var edge_band := 20.0
@export var edge_height := 22.0
@export var terrain_seed := 1337

var _noise := FastNoiseLite.new()
var _tint_noise := FastNoiseLite.new()
var _heights := PackedFloat32Array()
var _verts_per_side := 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_noise.seed = terrain_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 4

	_tint_noise.seed = terrain_seed + 1
	_tint_noise.frequency = 0.05

	_generate_heights()
	_build_mesh_and_collision()
	_build_edge_walls()


## Height of the ground at any world X/Z position.
func get_height(x: float, z: float) -> float:
	var half := world_size * 0.5
	var fx := clampf(x + half, 0.0, world_size - 0.001)
	var fz := clampf(z + half, 0.0, world_size - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _height_at(ix, iz)
	var h10 := _height_at(ix + 1, iz)
	var h01 := _height_at(ix, iz + 1)
	var h11 := _height_at(ix + 1, iz + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _height_formula(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * height_scale

	# Flatten a clearing around spawn.
	var distance_from_center := Vector2(x, z).length()
	h *= smoothstep(clearing_radius, clearing_radius * 2.0, distance_from_center)

	# Raise hills at the edges of the map.
	var half := world_size * 0.5
	var distance_to_edge := half - maxf(absf(x), absf(z))
	var edge := 1.0 - smoothstep(0.0, edge_band, distance_to_edge)
	h += edge * edge * edge_height
	return h


func _generate_heights() -> void:
	_verts_per_side = world_size + 1
	_heights.resize(_verts_per_side * _verts_per_side)
	var half := world_size * 0.5
	for z in _verts_per_side:
		for x in _verts_per_side:
			_heights[z * _verts_per_side + x] = _height_formula(x - half, z - half)


func _height_at(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, _verts_per_side - 1)
	iz = clampi(iz, 0, _verts_per_side - 1)
	return _heights[iz * _verts_per_side + ix]


func _normal_at(ix: int, iz: int) -> Vector3:
	var left := _height_at(ix - 1, iz)
	var right := _height_at(ix + 1, iz)
	var back := _height_at(ix, iz - 1)
	var front := _height_at(ix, iz + 1)
	return Vector3(left - right, 2.0, back - front).normalized()


func _color_for(x: float, z: float, normal: Vector3) -> Color:
	var grass := Color(0.33, 0.48, 0.2)
	var grass_dark := Color(0.24, 0.38, 0.16)
	var dirt := Color(0.42, 0.35, 0.25)
	var rock := Color(0.46, 0.45, 0.43)
	var tint := _tint_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var color := grass.lerp(grass_dark, tint)
	var slope := 1.0 - normal.y
	color = color.lerp(dirt, smoothstep(0.1, 0.25, slope))
	color = color.lerp(rock, smoothstep(0.3, 0.5, slope))
	return color


func _build_mesh_and_collision() -> void:
	var half := world_size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in _verts_per_side:
		for x in _verts_per_side:
			var normal := _normal_at(x, z)
			var wx: float = x - half
			var wz: float = z - half
			st.set_normal(normal)
			st.set_color(_color_for(wx, wz, normal))
			st.add_vertex(Vector3(wx, _height_at(x, z), wz))

	for z in world_size:
		for x in world_size:
			var a: int = z * _verts_per_side + x
			var b: int = a + 1
			var c: int = a + _verts_per_side
			var d: int = c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)

	st.set_material(TERRAIN_MATERIAL)
	var mesh := st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	add_child(collision)


## Invisible walls as a safety net so nothing can leave the map.
func _build_edge_walls() -> void:
	var half := world_size * 0.5
	var sides := [
		[Vector3(0, 30, -half), Vector3(world_size, 80, 2)],
		[Vector3(0, 30, half), Vector3(world_size, 80, 2)],
		[Vector3(-half, 30, 0), Vector3(2, 80, world_size)],
		[Vector3(half, 30, 0), Vector3(2, 80, world_size)],
	]
	for side in sides:
		var box := BoxShape3D.new()
		box.size = side[1]
		var wall := CollisionShape3D.new()
		wall.shape = box
		wall.position = side[0]
		add_child(wall)
