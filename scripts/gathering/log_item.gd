extends RigidBody3D
## A loose log. The player can pick it up, carry it, drop it, or stack it on a log stack.

const BARK := preload("res://materials/bark.tres")
const CUT := preload("res://materials/wood_cut.tres")

const LENGTH := 1.6
const RADIUS := 0.2

const LAYER_LOGS := 4  # Physics layer 3 ("logs").
const MASK_WORLD_AND_LOGS := 1 | 4

## What kind of carried item this is (plank bundles are "planks").
var kind := "log"
var is_carried := false
## True once this log has earned its Forestry points (by being delivered to a log stack or
## supply pile). Logs taken back out of a stack are already counted, so moving them earns nothing.
var counted := false


func _ready() -> void:
	add_to_group("logs")
	mass = 25.0
	linear_damp = 0.3
	angular_damp = 3.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = LAYER_LOGS
	collision_mask = MASK_WORLD_AND_LOGS

	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.9
	physics_material_override = physics_material

	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = LENGTH
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.rotation.z = PI * 0.5
	add_child(shape)

	add_child(build_visual())


## Builds the look of a log, long along the local X axis.
## Shared with the log stack so stacked logs look identical to loose ones.
static func build_visual() -> Node3D:
	var root := Node3D.new()

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = RADIUS
	body_mesh.bottom_radius = RADIUS
	body_mesh.height = LENGTH
	body_mesh.radial_segments = 12
	body_mesh.rings = 1
	body_mesh.material = BARK
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.rotation.z = PI * 0.5
	root.add_child(body)

	# Light-coloured cut ends.
	for side in [-1.0, 1.0]:
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = RADIUS * 0.92
		cap_mesh.bottom_radius = RADIUS * 0.92
		cap_mesh.height = 0.02
		cap_mesh.radial_segments = 12
		cap_mesh.rings = 1
		cap_mesh.material = CUT
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.rotation.z = PI * 0.5
		cap.position.x = side * (LENGTH * 0.5 + 0.005)
		root.add_child(cap)

	return root


func get_interaction_prompt(player) -> String:
	if is_carried or not player.can_carry_more():
		return ""
	if player.is_carrying():
		return "[E] Pick up log   (carrying %d / %d)" % [player.carried_count(), player.max_carry]
	return "[E] Pick up log"


func interact(player) -> void:
	if not is_carried and player.can_carry_more():
		player.pick_up(self)


func set_carried(carried: bool) -> void:
	is_carried = carried
	freeze = carried
	collision_layer = 0 if carried else LAYER_LOGS
	collision_mask = 0 if carried else MASK_WORLD_AND_LOGS
	if not carried:
		sleeping = false
