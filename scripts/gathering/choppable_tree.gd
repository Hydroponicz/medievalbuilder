extends StaticBody3D
## A tree the player chops down by hand.
## Every hit earns Forestry points. After enough hits it falls,
## and the trunk breaks into logs the player can carry away. A stump stays behind.
##
## Note: keep the tree's root unrotated; the fall direction is calculated in world space.

signal felled(tree: Node3D)

const LOG_SCENE := preload("res://scenes/log.tscn")
const BARK := preload("res://materials/bark.tres")
const LEAVES := preload("res://materials/leaves.tres")
const Fx := preload("res://scripts/fx/fx.gd")

const STUMP_HEIGHT := 0.45

@export var trunk_height := 6.0
@export var trunk_radius := 0.3
@export var hits_to_fell := 5
@export var log_count := 3
@export var points_per_hit := 1
@export var points_for_felling := 5

var _hits_taken := 0
var _is_felled := false
var _pivot: Node3D
var _trunk_shape: CollisionShape3D


func _ready() -> void:
	add_to_group("trees")
	collision_layer = 1
	collision_mask = 0
	_build()


func get_interaction_prompt(player) -> String:
	if _is_felled or player.is_carrying():
		return ""
	return "[LMB] Chop tree   (%d / %d)" % [_hits_taken, hits_to_fell]


func chop(player: Node3D, hit_point: Vector3) -> void:
	if _is_felled:
		return
	_hits_taken += 1
	Progression.add_points(Progression.FORESTRY, points_per_hit, "Chop")
	Fx.wood_chips(get_tree().current_scene, hit_point)
	if _hits_taken >= hits_to_fell:
		_fell(player.global_position)
	else:
		_shake()


func _build() -> void:
	# Stump: stays in the world after the tree is felled.
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = trunk_radius
	stump_mesh.bottom_radius = trunk_radius * 1.25
	stump_mesh.height = STUMP_HEIGHT + 0.4  # The extra 0.4 m sinks into the ground on slopes.
	stump_mesh.material = BARK
	var stump := MeshInstance3D.new()
	stump.mesh = stump_mesh
	stump.position.y = (STUMP_HEIGHT - 0.4) * 0.5
	add_child(stump)

	var stump_cylinder := CylinderShape3D.new()
	stump_cylinder.radius = trunk_radius * 1.1
	stump_cylinder.height = STUMP_HEIGHT
	var stump_shape := CollisionShape3D.new()
	stump_shape.shape = stump_cylinder
	stump_shape.position.y = STUMP_HEIGHT * 0.5
	add_child(stump_shape)

	# Everything above the cut lives under a pivot, so it can tip over from the cut point.
	_pivot = Node3D.new()
	_pivot.position.y = STUMP_HEIGHT
	add_child(_pivot)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.7
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height
	trunk_mesh.material = BARK
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height * 0.5
	_pivot.add_child(trunk)

	# Canopy: three stacked cones (placeholder art).
	var scale_factor := trunk_height / 6.0
	for i in 3:
		var t: float = i / 2.0
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = lerpf(2.2, 1.1, t) * scale_factor
		cone.height = lerpf(2.6, 2.0, t) * scale_factor
		cone.material = LEAVES
		var layer := MeshInstance3D.new()
		layer.mesh = cone
		layer.position.y = trunk_height * lerpf(0.4, 0.84, t) + cone.height * 0.5
		_pivot.add_child(layer)

	var trunk_cylinder := CylinderShape3D.new()
	trunk_cylinder.radius = trunk_radius
	trunk_cylinder.height = trunk_height
	_trunk_shape = CollisionShape3D.new()
	_trunk_shape.shape = trunk_cylinder
	_trunk_shape.position.y = STUMP_HEIGHT + trunk_height * 0.5
	add_child(_trunk_shape)


func _set_pivot_tilt(angle: float, axis: Vector3) -> void:
	_pivot.transform.basis = Basis(axis, angle)


func _shake() -> void:
	var axis := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	var tween := create_tween()
	tween.tween_method(_set_pivot_tilt.bind(axis), 0.0, 0.05, 0.05)
	tween.tween_method(_set_pivot_tilt.bind(axis), 0.05, -0.03, 0.08)
	tween.tween_method(_set_pivot_tilt.bind(axis), -0.03, 0.0, 0.1)


func _fell(from_position: Vector3) -> void:
	_is_felled = true
	_trunk_shape.set_deferred("disabled", true)
	Progression.add_points(Progression.FORESTRY, points_for_felling, "Tree felled")

	# Fall away from whoever chopped it.
	var away := global_position - from_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	var axis := Vector3.UP.cross(away).normalized()

	var tween := create_tween()
	tween.tween_method(_set_pivot_tilt.bind(axis), 0.0, deg_to_rad(86.0), 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_pivot_tilt.bind(axis), deg_to_rad(86.0), deg_to_rad(82.0), 0.12)
	tween.tween_method(_set_pivot_tilt.bind(axis), deg_to_rad(82.0), deg_to_rad(86.0), 0.12)
	tween.tween_callback(_on_fall_landed.bind(away))


func _on_fall_landed(away: Vector3) -> void:
	var base := global_position + Vector3.UP * STUMP_HEIGHT
	Fx.leaf_burst(get_tree().current_scene, base + away * trunk_height * 0.8)

	# Break the fallen trunk into loose logs lying where it fell.
	var spacing := trunk_height / log_count
	var yaw := atan2(-away.z, away.x)  # Logs are long along their local X axis.
	for i in log_count:
		var item: Node3D = LOG_SCENE.instantiate()
		get_parent().add_child(item)
		var spot: Vector3 = base + away * (spacing * (i + 0.5))
		spot.y = _ground_height_at(spot) + 0.35
		item.global_position = spot
		item.rotation.y = yaw

	# Shrink away the trunk and canopy, leaving just the stump.
	var tween := create_tween()
	tween.tween_property(_pivot, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_callback(_pivot.queue_free)
	felled.emit(self)


func _ground_height_at(spot: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 10.0, spot + Vector3.DOWN * 20.0, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return spot.y
	return hit.position.y
