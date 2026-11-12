extends StaticBody3D
## A simple log stack. Carry logs here and press E to stack them neatly.
## Stacked logs are your stored wood, and stacking them earns Forestry points.

signal stored_changed(count: int, capacity: int)

const LogItem := preload("res://scripts/gathering/log_item.gd")
const PLANK := preload("res://materials/wood_plank.tres")

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
	if player.is_carrying():
		if stored < capacity:
			return "[E] Stack log   (%d / %d)" % [stored, capacity]
		return "Log stack is full   (%d / %d)" % [stored, capacity]
	return "Log stack   (%d / %d)" % [stored, capacity]


func interact(player) -> void:
	if not player.is_carrying() or stored >= capacity:
		return
	var item = player.take_carried()
	item.queue_free()

	var visual := LogItem.build_visual()
	_stack_root.add_child(visual)
	var slot := _slot_position(stored)
	visual.position = slot + Vector3.UP * 0.35
	visual.rotation.y = randf_range(-0.04, 0.04)
	create_tween().tween_property(visual, "position", slot, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	stored += 1
	Progression.add_points(Progression.FORESTRY, points_per_log, "Log stacked")
	stored_changed.emit(stored, capacity)


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
