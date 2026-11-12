extends StaticBody3D
## A build supply pile. Place it near where you want to build, then carry logs or plank bundles to it.
## Logs become wood supplies (rough log blocks); plank bundles become plank supplies (plank blocks).
## Blocks placed nearby use those supplies.

signal supplies_changed

const BlockTypes := preload("res://scripts/building/block_types.gd")
const LogItem := preload("res://scripts/gathering/log_item.gd")
const LOG_SCENE := preload("res://scenes/log.tscn")
const PLANK_BUNDLE_SCENE := preload("res://scenes/plank_bundle.tscn")
const PLANK := preload("res://materials/wood_plank.tres")
const PLANK_LIGHT := preload("res://materials/wood_cut.tres")

## How many rough log blocks one log is worth.
@export var blocks_per_log := 10
## How many plank blocks one plank bundle is worth.
@export var blocks_per_bundle := 20
## How many logs fit on the pile.
@export var max_logs := 10
## How many plank bundles fit on the pile.
@export var max_bundles := 5
## Forestry points for delivering a freshly chopped log here (same as the log stack).
@export var points_per_log := 2
## Blocks can be placed and removed within this distance (measured flat, so tall builds still work).
@export var build_radius := 12.0

## Wood supplies (rough log blocks). Kept under this name so older code and saves still work.
var supplies := 0
## Plank supplies (plank blocks).
var planks := 0

var _logs_root: Node3D
var _planks_root: Node3D


func _ready() -> void:
	add_to_group("supply_piles")
	collision_layer = 1
	collision_mask = 0
	_build_pallet()
	_logs_root = Node3D.new()
	add_child(_logs_root)
	_planks_root = Node3D.new()
	add_child(_planks_root)
	_refresh_visuals()


func get_interaction_prompt(player) -> String:
	var summary := _summary()
	if player.is_carrying():
		var count := _acceptable_count(player)
		if count > 0:
			var what := "1 item" if count == 1 else "%d items" % count
			if count == player.carried_count():
				what = "what you're carrying"
			return "[E] Add %s to build supplies   (%s)" % [what, summary]
		return "Build supplies are full   (%s)" % summary
	return "Build supplies   (%s)" % summary


func interact(player) -> void:
	var fresh_logs := 0
	for item in player.get_carried().duplicate():
		if not _has_room_for(item.kind):
			continue
		player.release_carried(item)
		if item.kind == "log":
			if not item.counted:
				fresh_logs += 1
			supplies += blocks_per_log
		else:
			planks += blocks_per_bundle
		item.queue_free()
	if fresh_logs > 0:
		Progression.add_points(Progression.FORESTRY, points_per_log * fresh_logs, "Logs delivered")
	_changed()


func is_in_range(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= build_radius


func get_amount(material: String) -> int:
	return planks if material == BlockTypes.PLANKS else supplies


func use_supplies(amount: int, material := BlockTypes.WOOD) -> bool:
	if get_amount(material) < amount:
		return false
	if material == BlockTypes.PLANKS:
		planks -= amount
	else:
		supplies -= amount
	_changed()
	return true


## Refunds from removed blocks may go over the hauling limit; that's fine.
func add_supplies(amount: int, material := BlockTypes.WOOD) -> void:
	if material == BlockTypes.PLANKS:
		planks += amount
	else:
		supplies += amount
	_changed()


## Packs the pile up: whole logs and bundles' worth of supplies drop out as loose items.
func dismantle() -> void:
	var index := 0
	for i in floori(float(supplies) / blocks_per_log):
		_drop(LOG_SCENE, index)
		index += 1
	for i in floori(float(planks) / blocks_per_bundle):
		_drop(PLANK_BUNDLE_SCENE, index)
		index += 1
	queue_free()


func get_save_data() -> Dictionary:
	var p := global_position
	return {"position": [p.x, p.y, p.z], "yaw": rotation.y, "supplies": supplies, "planks": planks}


func apply_save_data(data: Dictionary) -> void:
	var p: Array = data.get("position", [])
	if p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(data.get("yaw", 0.0))
	supplies = int(data.get("supplies", 0))
	planks = int(data.get("planks", 0))
	_refresh_visuals()


func _summary() -> String:
	if planks > 0:
		return "%d rough log, %d plank blocks" % [supplies, planks]
	return "%d blocks" % supplies


func _has_room_for(kind: String) -> bool:
	if kind == "log":
		return supplies + blocks_per_log <= max_logs * blocks_per_log
	return planks + blocks_per_bundle <= max_bundles * blocks_per_bundle


## How many of the player's carried items would fit.
func _acceptable_count(player) -> int:
	var wood := supplies
	var plank := planks
	var count := 0
	for item in player.get_carried():
		if item.kind == "log" and wood + blocks_per_log <= max_logs * blocks_per_log:
			wood += blocks_per_log
			count += 1
		elif item.kind != "log" and plank + blocks_per_bundle <= max_bundles * blocks_per_bundle:
			plank += blocks_per_bundle
			count += 1
	return count


func _drop(scene: PackedScene, index: int) -> void:
	var item = scene.instantiate()
	item.counted = true
	get_parent().add_child(item)
	item.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.6 + index * 0.45, randf_range(-0.6, 0.6))
	item.rotation.y = randf() * TAU


func _changed() -> void:
	_refresh_visuals()
	supplies_changed.emit()


## Shows roughly how full the pile is: logs in a small pyramid, plank bundles stacked beside them.
func _refresh_visuals() -> void:
	if _logs_root == null:
		return
	for root in [_logs_root, _planks_root]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()

	var logs_to_show := mini(ceili(float(supplies) / blocks_per_log), 10)
	var spacing := LogItem.RADIUS * 2.0 + 0.02
	var shown := 0
	var row := 0
	while shown < logs_to_show:
		var in_row := 4 - row
		for i in in_row:
			if shown >= logs_to_show:
				break
			var visual := LogItem.build_visual()
			_logs_root.add_child(visual)
			var z := (i - (in_row - 1) * 0.5) * spacing
			visual.position = Vector3(-0.1, 0.14 + LogItem.RADIUS + row * spacing * 0.866, z)
			shown += 1
		row += 1

	# Plank bundles sit as a neat stack on the end of the pallet.
	var bundles_to_show := mini(ceili(float(planks) / blocks_per_bundle), max_bundles)
	for i in bundles_to_show:
		var bundle_mesh := BoxMesh.new()
		bundle_mesh.size = Vector3(0.5, 0.16, 1.5)
		bundle_mesh.material = PLANK_LIGHT
		var bundle := MeshInstance3D.new()
		bundle.mesh = bundle_mesh
		bundle.position = Vector3(1.15, 0.2 + i * 0.17, 0.0)
		_planks_root.add_child(bundle)


func _build_pallet() -> void:
	var pallet_mesh := BoxMesh.new()
	pallet_mesh.size = Vector3(2.4, 0.12, 1.8)
	pallet_mesh.material = PLANK
	var pallet := MeshInstance3D.new()
	pallet.mesh = pallet_mesh
	pallet.position = Vector3(0.3, 0.06, 0.0)
	add_child(pallet)

	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.3, 1.8)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.3, 0.65, 0.0)
	add_child(shape)
