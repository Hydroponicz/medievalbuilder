extends CharacterBody3D
## The player: walks, looks around, swings an axe, and carries logs.
## Press V to switch between first person and third person.

signal prompt_changed(text: String)

enum CameraMode { FIRST_PERSON, THIRD_PERSON }

const HANDLE := preload("res://materials/wood_plank.tres")
const METAL := preload("res://materials/axe_metal.tres")
const BODY := preload("res://materials/player_body.tres")

const LAYER_PLAYER := 2
const MASK_WORLD_AND_LOGS := 1 | 4
const AXE_REST := Vector3(-0.25, 0.15, 0.0)

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.0
## Carrying a heavy log slows you down.
@export var carry_speed_multiplier := 0.65
@export var jump_velocity := 4.8
@export var ground_acceleration := 14.0
@export var air_acceleration := 3.0

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var third_person_distance := 3.8
@export var field_of_view := 75.0

@export_group("Actions")
## How far away you can chop or pick things up, in metres.
@export var reach := 3.0
## Seconds for one full axe swing.
@export var swing_duration := 0.55

var camera_mode := CameraMode.FIRST_PERSON

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _carried = null
var _target = null
var _prompt := ""
var _is_swinging := false
var _suppress_chop := false
var _spawn_point := Vector3.ZERO

var _head: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _body_parts: Array[MeshInstance3D] = []
var _axe: Node3D
var _hold_point: Node3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_WORLD_AND_LOGS
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	_spawn_point = global_position

	_build_body()
	_build_camera()
	_build_axe()
	_apply_camera_mode(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Public API used by trees, logs and the log stack ---------------------------

func is_carrying() -> bool:
	return _carried != null


func pick_up(item) -> void:
	if _carried != null:
		return
	_carried = item
	item.set_carried(true)


## Hands the carried item to someone else (e.g. the log stack) without dropping it.
func take_carried():
	var item = _carried
	_carried = null
	return item


func drop_carried() -> void:
	if _carried == null:
		return
	var item = _carried
	_carried = null
	var forward := -global_transform.basis.z
	item.global_position = global_position + Vector3.UP * 1.1 + forward * 0.8
	item.set_carried(false)
	item.linear_velocity = velocity * 0.5 + forward * 1.5


# --- Input -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_head.rotation.x = clampf(_head.rotation.x - motion.relative.y * mouse_sensitivity, -1.45, 1.45)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not captured:
		# Click back into the game window to resume.
		if event is InputEventMouseButton and event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_suppress_chop = true
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_camera"):
		if camera_mode == CameraMode.FIRST_PERSON:
			camera_mode = CameraMode.THIRD_PERSON
		else:
			camera_mode = CameraMode.FIRST_PERSON
		_apply_camera_mode(true)
	elif event.is_action_pressed("interact"):
		_interact()


func _interact() -> void:
	if _target != null and _target.has_method("interact"):
		_target.interact(self)
	elif _carried != null:
		drop_carried()


# --- Per-frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_move(delta)

	if _carried != null:
		_carried.global_transform = _hold_point.global_transform

	_update_target()
	_update_chopping()

	# Safety net: if something goes wrong and we fall out of the world, come back.
	if global_position.y < -50.0:
		global_position = _spawn_point
		velocity = Vector3.ZERO


func _move(delta: float) -> void:
	var carrying := _carried != null

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity * (0.7 if carrying else 1.0)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var speed := walk_speed
	if Input.is_action_pressed("sprint") and not carrying:
		speed = sprint_speed
	if carrying:
		speed *= carry_speed_multiplier

	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var weight := clampf(accel * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)

	move_and_slide()


func _update_chopping() -> void:
	var chop_held := Input.is_action_pressed("chop")
	if not chop_held:
		_suppress_chop = false
		return
	if _suppress_chop or _is_swinging or _carried != null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_start_swing()


## Looks at whatever is under the crosshair and updates the on-screen prompt.
func _update_target() -> void:
	var hit := _raycast()
	var text := ""
	_target = null

	if not hit.is_empty():
		var collider = hit.collider
		if collider != null and collider.has_method("get_interaction_prompt"):
			text = collider.get_interaction_prompt(self)
			if text != "":
				_target = collider

	if text == "" and _carried != null:
		text = "[E] Drop log"

	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _raycast() -> Dictionary:
	var from := _head.global_position
	var forward := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * reach, MASK_WORLD_AND_LOGS)
	var exclude: Array[RID] = [get_rid()]
	if _carried != null:
		exclude.append(_carried.get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- Axe swing -------------------------------------------------------------------

func _start_swing() -> void:
	_is_swinging = true
	var tween := create_tween()
	# Wind up...
	tween.tween_property(_axe, "rotation:x", 0.55, swing_duration * 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ...strike...
	tween.tween_property(_axe, "rotation:x", -1.15, swing_duration * 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_swing_impact)
	# ...and recover.
	tween.tween_property(_axe, "rotation:x", AXE_REST.x, swing_duration * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_on_swing_finished)


func _on_swing_impact() -> void:
	var hit := _raycast()
	if hit.is_empty():
		return
	var collider = hit.collider
	if collider != null and collider.has_method("chop"):
		collider.chop(self, hit.position)
		_camera_kick()


func _on_swing_finished() -> void:
	_is_swinging = false


func _camera_kick() -> void:
	var tween := create_tween()
	tween.tween_property(_camera, "v_offset", -0.035, 0.04)
	tween.tween_property(_camera, "v_offset", 0.0, 0.12)


# --- Camera ----------------------------------------------------------------------

func _apply_camera_mode(animate: bool) -> void:
	var third_person := camera_mode == CameraMode.THIRD_PERSON
	var arm_length := third_person_distance if third_person else 0.0
	var arm_offset := Vector3(0.0, 0.3, 0.0) if third_person else Vector3.ZERO

	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_spring_arm, "spring_length", arm_length, 0.25)
		tween.tween_property(_spring_arm, "position", arm_offset, 0.25)
	else:
		_spring_arm.spring_length = arm_length
		_spring_arm.position = arm_offset

	# In first person the body is invisible but still casts a shadow.
	for part in _body_parts:
		if third_person:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


# --- Building the player out of simple shapes (placeholder art) ------------------

func _build_body() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.8
	body_mesh.material = BODY
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.position.y = 0.9
	add_child(body)
	_body_parts.append(body)

	# A belt on the front, so you can see which way you face in third person.
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(0.5, 0.12, 0.1)
	belt_mesh.material = HANDLE
	var belt := MeshInstance3D.new()
	belt.mesh = belt_mesh
	belt.position = Vector3(0.0, 1.0, -0.3)
	add_child(belt)
	_body_parts.append(belt)

	# Carried logs rest on the right shoulder, pointing forward.
	_hold_point = Node3D.new()
	_hold_point.position = Vector3(0.42, 1.42, -0.1)
	_hold_point.rotation.y = PI * 0.5
	add_child(_hold_point)


func _build_camera() -> void:
	_head = Node3D.new()
	_head.position.y = 1.6
	add_child(_head)

	_spring_arm = SpringArm3D.new()
	_spring_arm.collision_mask = 1
	_spring_arm.margin = 0.2
	_spring_arm.add_excluded_object(get_rid())
	_head.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = field_of_view
	_camera.near = 0.05
	_spring_arm.add_child(_camera)
	_camera.current = true


func _build_axe() -> void:
	_axe = Node3D.new()
	_axe.position = Vector3(0.38, -0.36, -0.5)
	_axe.rotation = AXE_REST
	_head.add_child(_axe)

	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.04, 0.6, 0.04)
	handle_mesh.material = HANDLE
	var handle := MeshInstance3D.new()
	handle.mesh = handle_mesh
	handle.position.y = 0.2
	_axe.add_child(handle)

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.025, 0.14, 0.2)
	blade_mesh.material = METAL
	var blade := MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, 0.45, -0.08)
	_axe.add_child(blade)
