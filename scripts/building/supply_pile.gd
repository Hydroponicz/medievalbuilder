extends StaticBody3D
## A build supply pile. Place it near where you want to build, then carry logs to it.
## Each log becomes build supplies, and blocks placed nearby use those supplies.

signal supplies_changed(supplies: int)

const LogItem := preload("res://scripts/gathering/log_item.gd")
const LOG_SCENE := preload("res://scenes/log.tscn")
const PLANK := preload("res://materials/wood_plank.tres")

## How many blocks one log is worth.
@export var blocks_per_log := 10
## How many logs fit on the pile.
@export var max_logs := 10
## Forestry points for delivering a freshly chopped log here (same as the log stack).
@export var points_per_log := 2
## Blocks can be placed and removed within this distance (measured flat, so tall builds still work).
@export var build_radius := 12.0

var supplies := 0
var _logs_root: Node3D


func _ready() -> void:
	add_to_group("supply_piles")
	collision_layer = 1
	collision_mask = 0
	_build_pallet()
	_logs_root = Node3D.new()
	add_child(_logs_root)
	_refresh_logs()


func get_interaction_prompt(player) -> String:
	if player.is_carrying():
		if _has_room_for_log():
			var count := mini(player.carried_count(), _room_in_logs())
			var what := "1 log" if count == 1 else "%d logs" % count
			return "[E] Add %s to build supplies   (%d blocks)" % [what, supplies]
		return "Build supplies are full   (%d blocks)" % supplies
	return "Build supplies   (%d blocks)" % supplies


func interact(player) -> void:
	var fresh := 0
	while player.is_carrying() and _has_room_for_log():
		var item = player.take_carried()
		if not item.counted:
			fresh += 1
		item.queue_free()
		add_supplies(blocks_per_log)
	if fresh > 0:
		Progression.add_points(Progression.FORESTRY, points_per_log * fresh, "Logs delivered")


func is_in_range(point: Vector3) -> bool:
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	return flat.length() <= build_radius


func use_supplies(amount: int) -> bool:
	if supplies < amount:
		return false
	supplies -= amount
	_refresh_logs()
	supplies_changed.emit(supplies)
	return true


## Refunds from removed blocks may go over the hauling limit; that's fine.
func add_supplies(amount: int) -> void:
	supplies += amount
	_refresh_logs()
	supplies_changed.emit(supplies)


## Packs the pile up: whole logs' worth of supplies drop as loose logs.
func dismantle() -> void:
	var log_count := floori(float(supplies) / blocks_per_log)
	for i in log_count:
		var item = LOG_SCENE.instantiate()
		item.counted = true
		get_parent().add_child(item)
		item.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.6 + i * 0.45, randf_range(-0.6, 0.6))
		item.rotation.y = randf() * TAU
	queue_free()


func get_save_data() -> Dictionary:
	var p := global_position
	return {"position": [p.x, p.y, p.z], "yaw": rotation.y, "supplies": supplies}


func apply_save_data(data: Dictionary) -> void:
	var p: Array = data.get("position", [])
	if p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(data.get("yaw", 0.0))
	supplies = int(data.get("supplies", 0))
	_refresh_logs()


func _has_room_for_log() -> bool:
	return _room_in_logs() > 0


func _room_in_logs() -> int:
	return floori(float(max_logs * blocks_per_log - supplies) / blocks_per_log)


## Shows roughly how full the pile is: one log per 10 supplies, in a small pyramid.
func _refresh_logs() -> void:
	if _logs_root == null:
		return
	for child in _logs_root.get_children():
		_logs_root.remove_child(child)
		child.queue_free()

	var to_show := mini(ceili(float(supplies) / blocks_per_log), 10)
	var spacing := LogItem.RADIUS * 2.0 + 0.02
	var shown := 0
	var row := 0
	while shown < to_show:
		var in_row := 4 - row
		for i in in_row:
			if shown >= to_show:
				break
			var visual := LogItem.build_visual()
			_logs_root.add_child(visual)
			var z := (i - (in_row - 1) * 0.5) * spacing
			visual.position = Vector3(0.0, 0.14 + LogItem.RADIUS + row * spacing * 0.866, z)
			shown += 1
		row += 1


func _build_pallet() -> void:
	var pallet_mesh := BoxMesh.new()
	pallet_mesh.size = Vector3(1.7, 0.12, 1.8)
	pallet_mesh.material = PLANK
	var pallet := MeshInstance3D.new()
	pallet.mesh = pallet_mesh
	pallet.position.y = 0.06
	add_child(pallet)

	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.3, 1.8)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = 0.65
	add_child(shape)
