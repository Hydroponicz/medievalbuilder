extends Node3D
## Build mode. Press B to toggle it, and Tab for the bird's-eye camera.
## A see-through "ghost" shows where things go: green = OK, red = can't place.
##
## Shapes (press R to cycle): Single, Line, Wall, Floor.
##  - Single: left click places one block, right click removes one. Hold to repeat.
##  - Line / Wall / Floor: click and drag from start to end, release to build the whole shape.
##    Right-drag removes in the same shape. Ctrl + mouse wheel changes wall height.

signal status_changed(text: String)

const BlockTypes := preload("res://scripts/building/block_types.gd")
const VoxelWorld := preload("res://scripts/building/voxel_world.gd")
const SUPPLY_PILE_SCENE := preload("res://scenes/supply_pile.tscn")

enum Item { ROUGH_LOG_BLOCK, SUPPLY_PILE }
enum Shape { SINGLE, LINE, WALL, FLOOR }
enum Drag { NONE, PLACE, REMOVE }

const ITEM_NAMES := ["Rough log block", "Supply pile"]
const SHAPE_NAMES := ["Single", "Line", "Wall", "Floor"]

const BLOCK_SIZE := BlockTypes.BLOCK_SIZE
const OK_COLOR := Color(0.45, 1.0, 0.55, 0.35)
const BAD_COLOR := Color(1.0, 0.35, 0.3, 0.35)
const REMOVE_COLOR := Color(1.0, 0.6, 0.2, 0.45)
## Safety limit so a huge accidental drag can't freeze the game.
const MAX_SHAPE_BLOCKS := 1024

## How far you can build in first/third person, in metres.
@export var reach := 6.0
## Seconds between blocks while holding the mouse button in Single mode.
@export var repeat_delay := 0.18
## Wall height in blocks (4 blocks = 2 m).
@export var wall_height := 4
@export var max_wall_height := 16

var active := false
var birds_eye := false
var selected := Item.ROUGH_LOG_BLOCK
var shape := Shape.SINGLE

var _player = null
var _voxels = null
var _birds_eye_rig = null
var _world: Node = null

var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _block_ghost_mesh: BoxMesh
var _pile_ghost_mesh: BoxMesh
var _shape_ok: MultiMeshInstance3D
var _shape_bad: MultiMeshInstance3D
var _shape_bad_material: StandardMaterial3D

var _repeat_timer := 0.0
var _wait_for_release := false
var _drag := Drag.NONE
var _drag_start := Vector3i.ZERO
var _drag_end := Vector3i.ZERO
var _drag_plane_y := 0.0
var _drag_info := ""

var _status := ""
var _notice := ""
var _notice_time := 0.0


func setup(player, voxels, birds_eye_rig, world: Node) -> void:
	_player = player
	_voxels = voxels
	_birds_eye_rig = birds_eye_rig
	_world = world


func _ready() -> void:
	_ghost_material = _make_ghost_material(OK_COLOR)
	_shape_bad_material = _make_ghost_material(BAD_COLOR)

	_block_ghost_mesh = BoxMesh.new()
	_block_ghost_mesh.size = Vector3.ONE * BLOCK_SIZE * 1.02
	_pile_ghost_mesh = BoxMesh.new()
	_pile_ghost_mesh.size = Vector3(1.7, 0.6, 1.8)

	_ghost = MeshInstance3D.new()
	_ghost.mesh = _block_ghost_mesh
	_ghost.material_override = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)

	_shape_ok = _make_shape_preview(_make_ghost_material(OK_COLOR))
	_shape_bad = _make_shape_preview(_shape_bad_material)


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if active and wheel != null and wheel.pressed and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + wheel: wall height.
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			wall_height = mini(wall_height + 1, max_wall_height)
			get_viewport().set_input_as_handled()
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wall_height = maxi(wall_height - 1, 1)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_build"):
		set_active(not active)
	elif event.is_action_pressed("toggle_birds_eye"):
		set_birds_eye(not birds_eye)
	elif active and event.is_action_pressed("hotbar_1"):
		selected = Item.ROUGH_LOG_BLOCK
	elif active and event.is_action_pressed("hotbar_2"):
		selected = Item.SUPPLY_PILE
		_cancel_drag()
	elif active and event.is_action_pressed("cycle_shape"):
		shape = ((shape + 1) % SHAPE_NAMES.size()) as Shape
		_cancel_drag()


func set_active(on: bool) -> void:
	active = on
	if not on and birds_eye:
		set_birds_eye(false)
	_player.set_build_mode(on)
	_cancel_drag()
	_ghost.visible = false


func set_birds_eye(on: bool) -> void:
	if on == birds_eye:
		return
	if on:
		if not active:
			set_active(true)
		birds_eye = true
		_birds_eye_rig.activate(_player.global_position, _player.rotation.y)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		birds_eye = false
		_birds_eye_rig.deactivate()
		_player.make_camera_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_cancel_drag()


func _process(delta: float) -> void:
	_notice_time -= delta

	if birds_eye and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not active:
		_ghost.visible = false
		_hide_shape_preview()
		_set_status("")
		return

	var can_click := birds_eye or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var place_held := can_click and Input.is_action_pressed("build_place")
	var remove_held := can_click and Input.is_action_pressed("build_remove")
	if not place_held and not remove_held:
		_wait_for_release = false

	var hit := _aim()
	var plan := _plan_placement(hit)

	if selected == Item.ROUGH_LOG_BLOCK and shape != Shape.SINGLE:
		_process_shape(hit, plan, place_held, remove_held)
	else:
		_hide_shape_preview()
		_update_ghost(plan)
		_process_single(hit, plan, place_held, remove_held, delta)

	_set_status(_build_status_text(plan))


# --- Single block / supply pile --------------------------------------------------

func _process_single(hit: Dictionary, plan: Dictionary, place_held: bool, remove_held: bool, delta: float) -> void:
	if _wait_for_release or (not place_held and not remove_held):
		_repeat_timer = 0.0
		return
	if _repeat_timer <= 0.0:
		_repeat_timer = repeat_delay
		if place_held:
			_place_single(plan)
		else:
			_remove_single(hit)
	_repeat_timer -= delta


func _place_single(plan: Dictionary) -> void:
	if not plan.get("has_spot", false):
		return
	if not plan.valid:
		if plan.reason != "":
			_show_notice(plan.reason)
		return

	if plan.item == Item.SUPPLY_PILE:
		var pile: Node3D = SUPPLY_PILE_SCENE.instantiate()
		_world.add_child(pile)
		pile.global_position = plan.position
		pile.rotation.y = _facing_yaw()
		_wait_for_release = true  # One pile per click.
		return

	var cost := BlockTypes.get_cost(BlockTypes.ROUGH_LOG)
	if plan.pile.use_supplies(cost):
		_voxels.place_block(plan.cell, BlockTypes.ROUGH_LOG)


func _remove_single(hit: Dictionary) -> void:
	if _try_dismantle_pile(hit):
		return
	var cell = _removal_cell(hit)
	if cell == null:
		return
	_remove_cells([cell])


## Right-clicking a supply pile packs it up. Returns true if that happened.
func _try_dismantle_pile(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var collider = hit.collider
	if collider != null and collider.is_in_group("supply_piles"):
		collider.dismantle()
		_wait_for_release = true
		return true
	return false


# --- Shapes: Line, Wall, Floor ---------------------------------------------------

func _process_shape(hit: Dictionary, plan: Dictionary, place_held: bool, remove_held: bool) -> void:
	if _drag == Drag.NONE:
		_hide_shape_preview()
		_update_ghost(plan)
		_drag_info = ""
		if _wait_for_release:
			return
		if place_held and plan.get("has_spot", false):
			_begin_drag(Drag.PLACE, plan.cell)
		elif remove_held:
			if _try_dismantle_pile(hit):
				return
			var cell = _removal_cell(hit)
			if cell != null:
				_begin_drag(Drag.REMOVE, cell)
		return

	_ghost.visible = false
	var end = _aim_on_drag_plane()
	if end != null:
		_drag_end = end
	var cells := _shape_cells(_drag_start, _drag_end)

	# Pressing the other mouse button cancels the drag.
	if (_drag == Drag.PLACE and remove_held) or (_drag == Drag.REMOVE and place_held):
		_cancel_drag()
		_wait_for_release = true
		return

	var still_held := place_held if _drag == Drag.PLACE else remove_held
	if not still_held:
		if _drag == Drag.PLACE:
			_place_cells(cells)
		else:
			_remove_cells(cells)
		_cancel_drag()
		return

	_show_shape_preview(cells)


func _begin_drag(mode: Drag, start: Vector3i) -> void:
	_drag = mode
	_drag_start = start
	_drag_end = start
	# Dragging follows a flat plane through the start block's layer, so shapes stay level.
	_drag_plane_y = (start.y + 0.5) * BLOCK_SIZE


func _cancel_drag() -> void:
	_drag = Drag.NONE
	_drag_info = ""
	if _shape_ok != null:
		_hide_shape_preview()


func _aim_on_drag_plane():
	var ray := _aim_ray()
	var from: Vector3 = ray[0]
	var direction: Vector3 = ray[1]
	if absf(direction.y) < 0.0001:
		return null
	var distance := (_drag_plane_y - from.y) / direction.y
	if distance <= 0.0 or distance > 300.0:
		return null
	var cell := VoxelWorld.world_to_cell(from + direction * distance)
	return Vector3i(cell.x, _drag_start.y, cell.z)


func _shape_cells(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if shape == Shape.FLOOR:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				cells.append(Vector3i(x, a.y, z))
	else:
		# Line and Wall run straight along whichever direction you dragged further.
		var height := wall_height if shape == Shape.WALL else 1
		var dx := b.x - a.x
		var dz := b.z - a.z
		var along_x := absi(dx) >= absi(dz)
		var length := absi(dx) if along_x else absi(dz)
		var step := signi(dx) if along_x else signi(dz)
		for i in length + 1:
			for y in height:
				if along_x:
					cells.append(Vector3i(a.x + i * step, a.y + y, a.z))
				else:
					cells.append(Vector3i(a.x, a.y + y, a.z + i * step))
	if cells.size() > MAX_SHAPE_BLOCKS:
		cells.resize(MAX_SHAPE_BLOCKS)
	return cells


func _show_shape_preview(cells: Array[Vector3i]) -> void:
	var ok: Array[Vector3i] = []
	var bad: Array[Vector3i] = []

	if _drag == Drag.PLACE:
		var cost := BlockTypes.get_cost(BlockTypes.ROUGH_LOG)
		var budget := _supplies_near(VoxelWorld.cell_center(_drag_start))
		for cell in cells:
			if _voxels.has_block(cell):
				continue
			if _blocks_player(cell) or budget < cost:
				bad.append(cell)
			else:
				ok.append(cell)
				budget -= cost
		_shape_bad_material.albedo_color = BAD_COLOR
		_drag_info = "%s: %d blocks   (%d build supplies nearby)" % [SHAPE_NAMES[shape], ok.size() + bad.size(), _supplies_near(VoxelWorld.cell_center(_drag_start))]
		if not bad.is_empty():
			_drag_info += "   Not enough supplies for the red blocks"
	else:
		for cell in cells:
			if _voxels.has_block(cell):
				bad.append(cell)
		_shape_bad_material.albedo_color = REMOVE_COLOR
		_drag_info = "Remove %d blocks" % bad.size()

	_fill_preview(_shape_ok, ok)
	_fill_preview(_shape_bad, bad)


# --- Placing and removing many blocks --------------------------------------------

func _place_cells(cells: Array[Vector3i]) -> void:
	var cost := BlockTypes.get_cost(BlockTypes.ROUGH_LOG)
	var wanted := 0
	var placed := 0
	for cell in cells:
		if _voxels.has_block(cell) or _blocks_player(cell):
			continue
		wanted += 1
		var pile = _find_pile(VoxelWorld.cell_center(cell), cost)
		if pile == null:
			continue
		pile.use_supplies(cost)
		_voxels.place_block(cell, BlockTypes.ROUGH_LOG)
		placed += 1
	if placed < wanted:
		_show_notice("Placed %d of %d blocks. Not enough build supplies nearby" % [placed, wanted])


func _remove_cells(cells: Array) -> void:
	var stuck := 0
	for cell in cells:
		if not _voxels.has_block(cell):
			continue
		# The wood goes back onto the nearest supply pile.
		var pile = _find_pile(VoxelWorld.cell_center(cell), 0)
		if pile == null:
			stuck += 1
			continue
		var type: int = _voxels.remove_block(cell)
		pile.add_supplies(BlockTypes.get_cost(type))
	if stuck > 0:
		_show_notice("Needs a supply pile nearby to take the wood back")


# --- Aiming ----------------------------------------------------------------------

## Returns [origin, direction] of what the player is pointing at.
func _aim_ray() -> Array:
	if birds_eye:
		var camera: Camera3D = _birds_eye_rig.camera
		var mouse := get_viewport().get_mouse_position()
		return [camera.project_ray_origin(mouse), camera.project_ray_normal(mouse)]
	return [_player.get_aim_origin(), _player.get_aim_direction()]


func _aim() -> Dictionary:
	var ray := _aim_ray()
	var from: Vector3 = ray[0]
	var direction: Vector3 = ray[1]
	var length := 400.0 if birds_eye else reach
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * length, 1)
	query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


## Works out what a left click would do right now, and whether it's allowed.
func _plan_placement(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {"has_spot": false}
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position

	if selected == Item.SUPPLY_PILE:
		var pile_plan := {"has_spot": true, "item": Item.SUPPLY_PILE, "position": point, "valid": true, "reason": ""}
		if normal.y < 0.75:
			pile_plan.valid = false
			pile_plan.reason = "Supply piles need flat ground"
		return pile_plan

	var cell: Vector3i = VoxelWorld.world_to_cell(point + normal * (BLOCK_SIZE * 0.5))
	var plan := {"has_spot": true, "item": Item.ROUGH_LOG_BLOCK, "cell": cell, "valid": true, "reason": ""}
	var cost := BlockTypes.get_cost(BlockTypes.ROUGH_LOG)
	var center: Vector3 = VoxelWorld.cell_center(cell)

	if _voxels.has_block(cell):
		plan.valid = false
	elif _blocks_player(cell):
		plan.valid = false
		plan.reason = "You're standing in the way"
	else:
		var pile = _find_pile(center, cost)
		plan.pile = pile
		if pile == null:
			plan.valid = false
			if _find_pile(center, 0) == null:
				plan.reason = "No build supplies nearby. Place a supply pile [2] and bring logs to it"
			else:
				plan.reason = "Out of build supplies. Carry more logs to the supply pile"
	return plan


## The block under the crosshair/mouse, or null.
func _removal_cell(hit: Dictionary):
	if hit.is_empty() or not VoxelWorld.is_block_body(hit.collider):
		return null
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position
	var cell: Vector3i = VoxelWorld.world_to_cell(point - normal * (BLOCK_SIZE * 0.5))
	if not _voxels.has_block(cell):
		return null
	return cell


func _blocks_player(cell: Vector3i) -> bool:
	return VoxelWorld.cell_aabb(cell).intersects(_player.get_body_aabb())


## Nearest supply pile in range of a point that has at least `need` supplies.
func _find_pile(point: Vector3, need: int):
	var best = null
	var best_distance := INF
	for pile in get_tree().get_nodes_in_group("supply_piles"):
		if pile.is_queued_for_deletion() or not pile.is_in_range(point) or pile.supplies < need:
			continue
		var distance: float = pile.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = pile
	return best


## Total supplies of every pile in range of a point.
func _supplies_near(point: Vector3) -> int:
	var total := 0
	for pile in get_tree().get_nodes_in_group("supply_piles"):
		if not pile.is_queued_for_deletion() and pile.is_in_range(point):
			total += pile.supplies
	return total


func _facing_yaw() -> float:
	if birds_eye:
		return _birds_eye_rig.rotation.y
	return _player.rotation.y


# --- Ghost previews --------------------------------------------------------------

func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material


func _make_shape_preview(material: StandardMaterial3D) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _block_ghost_mesh
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	add_child(instance)
	return instance


func _fill_preview(instance: MultiMeshInstance3D, cells: Array[Vector3i]) -> void:
	var multimesh := instance.multimesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), VoxelWorld.cell_center(cells[i])))
	instance.visible = not cells.is_empty()


func _hide_shape_preview() -> void:
	_shape_ok.visible = false
	_shape_bad.visible = false


func _update_ghost(plan: Dictionary) -> void:
	if not plan.get("has_spot", false):
		_ghost.visible = false
		return
	_ghost.visible = true
	_ghost_material.albedo_color = OK_COLOR if plan.valid else BAD_COLOR
	if plan.item == Item.SUPPLY_PILE:
		_ghost.mesh = _pile_ghost_mesh
		_ghost.global_position = plan.position + Vector3.UP * 0.3
		_ghost.global_rotation = Vector3(0.0, _facing_yaw(), 0.0)
	else:
		_ghost.mesh = _block_ghost_mesh
		_ghost.global_position = VoxelWorld.cell_center(plan.cell)
		_ghost.global_rotation = Vector3.ZERO


# --- On-screen help --------------------------------------------------------------

func _show_notice(text: String) -> void:
	_notice = text
	_notice_time = 2.5


func _build_status_text(plan: Dictionary) -> String:
	var items := ""
	for i in ITEM_NAMES.size():
		var label := "%d  %s" % [i + 1, ITEM_NAMES[i]]
		items += ("[ %s ]" % label) if i == selected else ("  %s  " % label)
		items += "     "

	var shape_line := ""
	if selected == Item.ROUGH_LOG_BLOCK:
		shape_line = "R  Shape: %s" % SHAPE_NAMES[shape]
		if shape == Shape.WALL:
			shape_line += "     Wall height: %d blocks (Ctrl + wheel)" % wall_height

	var info := ""
	if _notice_time > 0.0:
		info = _notice
	elif _drag_info != "":
		info = _drag_info
	elif plan.get("has_spot", false) and plan.item == Item.ROUGH_LOG_BLOCK:
		if plan.has("pile") and plan.pile != null:
			info = "Build supplies here: %d blocks" % _supplies_near(VoxelWorld.cell_center(plan.cell))
		elif plan.reason != "":
			info = plan.reason

	var controls := "Left click  place     Right click  remove     Tab  bird's-eye     B  exit"
	if selected == Item.ROUGH_LOG_BLOCK and shape != Shape.SINGLE:
		controls = "Drag with left click to build, right click to remove     Tab  bird's-eye     B  exit"
	if birds_eye:
		controls += "\nWASD or middle-drag  pan     Shift + middle-drag  rotate / tilt     Q / E  rotate     Wheel  zoom"

	var lines := PackedStringArray(["BUILD MODE", items.strip_edges()])
	if shape_line != "":
		lines.append(shape_line)
	lines.append(info)
	lines.append(controls)
	return "\n".join(lines)


func _set_status(text: String) -> void:
	if text != _status:
		_status = text
		status_changed.emit(text)
