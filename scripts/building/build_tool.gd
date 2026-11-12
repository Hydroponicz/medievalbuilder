extends Node3D
## Build mode. Press B to toggle it, and Tab for the bird's-eye camera.
## A see-through "ghost" shows where the next thing goes: green = OK, red = can't place.
## Left click places, right click removes. 1 / 2 picks what to place.

signal status_changed(text: String)

const BlockTypes := preload("res://scripts/building/block_types.gd")
const VoxelWorld := preload("res://scripts/building/voxel_world.gd")
const SUPPLY_PILE_SCENE := preload("res://scenes/supply_pile.tscn")

enum Item { ROUGH_LOG_BLOCK, SUPPLY_PILE }

const BLOCK_SIZE := BlockTypes.BLOCK_SIZE
const OK_COLOR := Color(0.45, 1.0, 0.55, 0.35)
const BAD_COLOR := Color(1.0, 0.35, 0.3, 0.35)

## How far you can build in first/third person, in metres.
@export var reach := 6.0
## Seconds between blocks while holding the mouse button.
@export var repeat_delay := 0.18

var active := false
var birds_eye := false
var selected := Item.ROUGH_LOG_BLOCK

var _player = null
var _voxels = null
var _birds_eye_rig = null
var _world: Node = null

var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _block_ghost_mesh: BoxMesh
var _pile_ghost_mesh: BoxMesh
var _repeat_timer := 0.0
var _status := ""
var _notice := ""
var _notice_time := 0.0


func setup(player, voxels, birds_eye_rig, world: Node) -> void:
	_player = player
	_voxels = voxels
	_birds_eye_rig = birds_eye_rig
	_world = world


func _ready() -> void:
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_material.albedo_color = OK_COLOR

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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		set_active(not active)
	elif event.is_action_pressed("toggle_birds_eye"):
		set_birds_eye(not birds_eye)
	elif active and event.is_action_pressed("hotbar_1"):
		selected = Item.ROUGH_LOG_BLOCK
	elif active and event.is_action_pressed("hotbar_2"):
		selected = Item.SUPPLY_PILE


func set_active(on: bool) -> void:
	active = on
	if not on and birds_eye:
		set_birds_eye(false)
	_player.set_build_mode(on)
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


func _process(delta: float) -> void:
	_notice_time -= delta

	if birds_eye and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not active:
		_ghost.visible = false
		_set_status("")
		return

	var hit := _aim()
	var plan := _plan_placement(hit)
	_update_ghost(plan)

	var can_click := birds_eye or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var place_held := can_click and Input.is_action_pressed("build_place")
	var remove_held := can_click and Input.is_action_pressed("build_remove")
	if not place_held and not remove_held:
		_repeat_timer = 0.0
	elif _repeat_timer <= 0.0:
		_repeat_timer = repeat_delay
		if place_held:
			_place(plan)
		else:
			_remove(hit)
	_repeat_timer -= delta

	_set_status(_build_status_text(plan))


# --- Aiming ----------------------------------------------------------------------

func _aim() -> Dictionary:
	var from: Vector3
	var direction: Vector3
	var length := reach
	if birds_eye:
		var camera: Camera3D = _birds_eye_rig.camera
		var mouse := get_viewport().get_mouse_position()
		from = camera.project_ray_origin(mouse)
		direction = camera.project_ray_normal(mouse)
		length = 400.0
	else:
		from = _player.get_aim_origin()
		direction = _player.get_aim_direction()
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
	elif VoxelWorld.cell_aabb(cell).intersects(_player.get_body_aabb()):
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


# --- Placing and removing --------------------------------------------------------

func _place(plan: Dictionary) -> void:
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
		_repeat_timer = 999.0  # One pile per click.
		return

	var cost := BlockTypes.get_cost(BlockTypes.ROUGH_LOG)
	if plan.pile.use_supplies(cost):
		_voxels.place_block(plan.cell, BlockTypes.ROUGH_LOG)


func _remove(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	var collider = hit.collider

	if collider != null and collider.is_in_group("supply_piles"):
		collider.dismantle()
		_repeat_timer = 999.0
		return

	if not VoxelWorld.is_block_body(collider):
		return
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position
	var cell: Vector3i = VoxelWorld.world_to_cell(point - normal * (BLOCK_SIZE * 0.5))
	if not _voxels.has_block(cell):
		return

	# The wood goes back onto the nearest supply pile.
	var pile = _find_pile(VoxelWorld.cell_center(cell), 0)
	if pile == null:
		_show_notice("Needs a supply pile nearby to take the wood back")
		return
	var type: int = _voxels.remove_block(cell)
	pile.add_supplies(BlockTypes.get_cost(type))


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


func _facing_yaw() -> float:
	if birds_eye:
		return _birds_eye_rig.rotation.y
	return _player.rotation.y


# --- On-screen help --------------------------------------------------------------

func _show_notice(text: String) -> void:
	_notice = text
	_notice_time = 2.5


func _build_status_text(plan: Dictionary) -> String:
	var items := ""
	var names := ["Rough log block", "Supply pile"]
	for i in names.size():
		var label := "%d  %s" % [i + 1, names[i]]
		items += ("[ %s ]" % label) if i == selected else ("  %s  " % label)
		items += "     "

	var info := ""
	if _notice_time > 0.0:
		info = _notice
	elif plan.get("has_spot", false) and plan.item == Item.ROUGH_LOG_BLOCK:
		if plan.has("pile") and plan.pile != null:
			info = "Build supplies here: %d blocks" % plan.pile.supplies
		elif plan.reason != "":
			info = plan.reason

	var controls := "Left click  place     Right click  remove     Tab  bird's-eye     B  exit"
	if birds_eye:
		controls = "WASD  pan     Q / E  rotate     Wheel  zoom     Left click  place     Right click  remove     Tab  back to player"

	return "BUILD MODE\n%s\n%s\n%s" % [items.strip_edges(), info, controls]


func _set_status(text: String) -> void:
	if text != _status:
		_status = text
		status_changed.emit(text)
