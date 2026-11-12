extends Node3D
## An overhead camera for planning and placing blocks from above.
##  - WASD or middle-mouse drag: pan (middle-drag "grabs" the ground)
##  - Shift + middle-mouse drag: rotate and tilt
##  - Q / E: rotate
##  - Mouse wheel: zoom towards the cursor (Ctrl + wheel is wall height, handled by the build tool)

@export var start_pitch_degrees := -55.0
@export var min_pitch_degrees := -88.0
@export var max_pitch_degrees := -20.0
@export var min_distance := 5.0
@export var max_distance := 70.0
@export var rotate_speed := 1.8
@export var drag_rotate_sensitivity := 0.006

var camera: Camera3D
var terrain = null
var active := false

var _focus := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _distance := 22.0
var _pitch_node: Node3D
var _middle_held := false


func _ready() -> void:
	_pitch = deg_to_rad(start_pitch_degrees)
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 600.0
	_pitch_node.add_child(camera)
	set_process(false)


func activate(focus: Vector3, yaw: float) -> void:
	_focus = focus
	_yaw = yaw
	_middle_held = false
	active = true
	_apply()
	camera.current = true
	set_process(true)


func deactivate() -> void:
	active = false
	_middle_held = false
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_held = button.pressed
		elif button.pressed and not Input.is_key_pressed(KEY_CTRL):
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.88, button.position)
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.14, button.position)
		return

	var motion := event as InputEventMouseMotion
	if motion != null and _middle_held:
		if Input.is_key_pressed(KEY_SHIFT):
			_yaw -= motion.relative.x * drag_rotate_sensitivity
			_pitch = clampf(_pitch - motion.relative.y * drag_rotate_sensitivity,
				deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
		else:
			_drag_pan(motion.relative)
		_apply()


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


## Moves the camera so the ground under the mouse follows the mouse.
func _drag_pan(relative: Vector2) -> void:
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	# Roughly how many metres of ground one pixel covers at the focus point.
	var metres_per_pixel := 2.0 * _distance * tan(deg_to_rad(camera.fov * 0.5)) / viewport_height
	var flat := Basis(Vector3.UP, _yaw)
	var right := flat * Vector3.RIGHT
	var forward := flat * Vector3.FORWARD
	# Looking down at an angle stretches the ground vertically on screen.
	var vertical_stretch := 1.0 / maxf(absf(sin(_pitch)), 0.3)
	_focus -= right * relative.x * metres_per_pixel
	_focus += forward * relative.y * metres_per_pixel * vertical_stretch


## Zooms in or out, keeping the point under the mouse in place.
func _zoom(factor: float, mouse: Vector2) -> void:
	var new_distance := clampf(_distance * factor, min_distance, max_distance)
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) > 0.001:
		var t := (_focus.y - origin.y) / direction.y
		if t > 0.0:
			var target := origin + direction * t
			var keep := new_distance / _distance
			var new_focus := target + (_focus - target) * keep
			_focus.x = new_focus.x
			_focus.z = new_focus.z
	_distance = new_distance
	_apply()


func _apply() -> void:
	global_position = _focus
	rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_node.rotation.x = _pitch
	camera.position = Vector3(0.0, 0.0, _distance)
