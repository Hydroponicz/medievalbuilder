extends Node3D
## An overhead camera for planning and placing blocks from above.
## WASD pans, Shift pans faster, Q/E rotates, the mouse wheel zooms.

@export var pitch_degrees := -55.0
@export var min_distance := 5.0
@export var max_distance := 70.0
@export var rotate_speed := 1.8

var camera: Camera3D
var terrain = null
var active := false

var _focus := Vector3.ZERO
var _yaw := 0.0
var _distance := 22.0
var _pitch_node: Node3D


func _ready() -> void:
	_pitch_node = Node3D.new()
	_pitch_node.rotation.x = deg_to_rad(pitch_degrees)
	add_child(_pitch_node)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 600.0
	_pitch_node.add_child(camera)
	set_process(false)


func activate(focus: Vector3, yaw: float) -> void:
	_focus = focus
	_yaw = yaw
	active = true
	_apply()
	camera.current = true
	set_process(true)


func deactivate() -> void:
	active = false
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("zoom_in"):
		_distance = clampf(_distance * 0.88, min_distance, max_distance)
	elif event.is_action_pressed("zoom_out"):
		_distance = clampf(_distance * 1.14, min_distance, max_distance)


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed := _distance * 0.9
	if Input.is_action_pressed("sprint"):
		speed *= 2.0
	_focus += Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y) * speed * delta

	var turn := 0.0
	if Input.is_action_pressed("camera_rotate_left"):
		turn += 1.0
	if Input.is_action_pressed("camera_rotate_right"):
		turn -= 1.0
	_yaw += turn * rotate_speed * delta

	if terrain != null:
		var limit: float = terrain.world_size * 0.5 - 5.0
		_focus.x = clampf(_focus.x, -limit, limit)
		_focus.z = clampf(_focus.z, -limit, limit)
		var ground: float = terrain.get_height(_focus.x, _focus.z)
		_focus.y = lerpf(_focus.y, ground, clampf(delta * 5.0, 0.0, 1.0))

	_apply()


func _apply() -> void:
	global_position = _focus
	rotation = Vector3(0.0, _yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, _distance)
