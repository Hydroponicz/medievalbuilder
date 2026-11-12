extends StaticBody3D
## A simple log stack: storage for logs. Carry logs here and press E to stack them neatly,
## or press E with empty hands to take logs off it.
## Delivering a freshly chopped log here (or to a supply pile) earns Forestry points.

signal stored_changed(count: int, capacity: int)

const LogItem := preload("res://scripts/gathering/log_item.gd")
const PLANK := preload("res://materials/wood_plank.tres")
const LOG_SCENE := preload("res://scenes/log.tscn")

@export var rows := 6
@export var logs_per_row := 4
@export var points_per_log := 2

var stored := 0
var capacity := 0
var _stack_root: Node3D


func _ready() -> void:
	add_to_group("stockpiles")
	collision_layer = 1
	collision_mask = 0
	capacity = rows * logs_per_row
	_build_frame()
	_stack_root = Node3D.new()
	add_child(_stack_root)


func get_interaction_prompt(player) -> String:
	if player.has_carried_kind("log"):
		if stored < capacity:
			var count := mini(_carried_log_count(player), capacity - stored)
			return "[E] Stack %s   (%d / %d)" % [_logs_text(count), stored, capacity]
		return "Log stack is full   (%d / %d)" % [stored, capacity]
	if player.is_carrying():
		return "Log stack   (%d / %d)   Only logs go here" % [stored, capacity]
	if stored > 0:
		var count := mini(player.max_carry, stored)
		return "[E] Take %s   (%d / %d)     [K] Forestry upgrades" % [_logs_text(count), stored, capacity]
	return "Log stack is empty   (0 / %d)   [K] Forestry upgrades" % capacity


func interact(player) -> void:
	if player.has_carried_kind("log"):
		_stack_carried_logs(player)
	elif not player.is_carrying():
		_take_logs(player)


## Removes logs from storage to pay for crafting. Returns false if there aren't enough.
func remove_logs(count: int) -> bool:
	if stored < count:
		return false
	for i in count:
		stored -= 1
		var top := _stack_root.get_child(_stack_root.get_child_count() - 1)
		_stack_root.remove_child(top)
		top.queue_free()
	stored_changed.emit(stored, capacity)
	return true


func _carried_log_count(player) -> int:
	var count := 0
	for item in player.get_carried():
		if item.kind == "log":
			count += 1
	return count


## Stacks every log the player is carrying (as many as fit).
func _stack_carried_logs(player) -> void:
	var fresh := 0
	while player.has_carried_kind("log") and stored < capacity:
		var item = player.take_carried_of_kind("log")
		if not item.counted:
			fresh += 1
		item.queue_free()
		_add_log_visual(stored, true)
		stored += 1
	# Only freshly chopped logs earn points, so moving logs around isn't a points trick.
	if fresh > 0:
		Progression.add_points(Progression.FORESTRY, points_per_log * fresh, "Logs delivered")
	stored_changed.emit(stored, capacity)


## Takes as many logs as the player can carry off the top of the stack.
func _take_logs(player) -> void:
	while stored > 0 and player.can_carry_more():
		stored -= 1
		var top := _stack_root.get_child(_stack_root.get_child_count() - 1)
		_stack_root.remove_child(top)
		top.queue_free()

		var item = LOG_SCENE.instantiate()
		item.counted = true
		get_parent().add_child(item)
		item.global_position = player.global_position + Vector3.UP * 1.4
		player.pick_up(item)
	stored_changed.emit(stored, capacity)


func _logs_text(count: int) -> String:
	return "1 log" if count == 1 else "%d logs" % count


func get_save_data() -> Dictionary:
	return {"stored": stored}


func apply_save_data(data: Dictionary) -> void:
	for child in _stack_root.get_children():
		_stack_root.remove_child(child)
		child.queue_free()
	stored = clampi(int(data.get("stored", 0)), 0, capacity)
	for i in stored:
		_add_log_visual(i, false)
	stored_changed.emit(stored, capacity)


func _add_log_visual(index: int, animate: bool) -> void:
	var visual := LogItem.build_visual()
	_stack_root.add_child(visual)
	var slot := _slot_position(index)
	visual.rotation.y = randf_range(-0.04, 0.04)
	if not animate:
		visual.position = slot
		return
	visual.position = slot + Vector3.UP * 0.35
	create_tween().tween_property(visual, "position", slot, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _spacing() -> float:
	return LogItem.RADIUS * 2.0 + 0.02


func _stack_width() -> float:
	return logs_per_row * _spacing() + _spacing() * 0.5


func _stack_height() -> float:
	return 0.15 + rows * _spacing() * 0.866 + 0.15


## Where log number `index` sits. Alternate rows shift sideways so logs nest in the gaps.
func _slot_position(index: int) -> Vector3:
	var row := floori(float(index) / logs_per_row)
	var column := index % logs_per_row
	var spacing := _spacing()
	var shift := 0.25 if row % 2 == 1 else -0.25
	var z := (column - (logs_per_row - 1) * 0.5 + shift) * spacing
	var y := 0.15 + LogItem.RADIUS + row * spacing * 0.866
	return Vector3(0.0, y, z)


func _build_frame() -> void:
	var width := _stack_width()
	var height := _stack_height()

	# Two sleeper beams keep the logs off the wet ground.
	for x in [-0.5, 0.5]:
		_add_box(Vector3(0.16, 0.15, width + 0.3), Vector3(x, 0.075, 0.0))

	# Four corner posts hold the stack in place.
	for x in [-0.5, 0.5]:
		for z in [-1.0, 1.0]:
			_add_box(Vector3(0.1, height + 0.2, 0.1), Vector3(x, height * 0.5 - 0.1, z * (width * 0.5 + 0.08)))

	# One collision box covering the whole stack.
	var box := BoxShape3D.new()
	box.size = Vector3(LogItem.LENGTH, height, width + 0.3)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = height * 0.5
	add_child(shape)


func _add_box(size: Vector3, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = PLANK
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
