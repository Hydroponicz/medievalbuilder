extends RigidBody3D
## A bundle of planks, made by splitting a log on the chopping block.
## Carry it to a supply pile: one bundle = 20 plank blocks.

const PLANK_LIGHT := preload("res://materials/wood_cut.tres")
const PLANK_DARK := preload("res://materials/wood_plank.tres")

const LENGTH := 1.5
const LAYER_ITEMS := 4  # Physics layer 3, shared with logs.
const MASK_WORLD_AND_ITEMS := 1 | 4

## What kind of carried item this is (logs are "log").
var kind := "planks"
var is_carried := false
## Plank bundles never earn Forestry points on delivery (the log already did).
var counted := true


func _ready() -> void:
	add_to_group("plank_bundles")
	mass = 15.0
	linear_damp = 0.3
	angular_damp = 3.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = LAYER_ITEMS
	collision_mask = MASK_WORLD_AND_ITEMS

	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.9
	physics_material_override = physics_material

	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH, 0.2, 0.42)
	var shape := CollisionShape3D.new()
	shape.shape = box
	add_child(shape)

	add_child(build_visual())


## Four planks tied with two dark straps. Long along local X, like logs.
static func build_visual() -> Node3D:
	var root := Node3D.new()
	for i in 4:
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(LENGTH, 0.045, 0.2)
		plank_mesh.material = PLANK_LIGHT
		var plank := MeshInstance3D.new()
		plank.mesh = plank_mesh
		plank.position = Vector3(0.0, -0.05 + (i / 2) * 0.05, -0.1 + (i % 2) * 0.2)
		root.add_child(plank)
	for x in [-0.45, 0.45]:
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.05, 0.12, 0.43)
		strap_mesh.material = PLANK_DARK
		var strap := MeshInstance3D.new()
		strap.mesh = strap_mesh
		strap.position = Vector3(x, -0.02, 0.0)
		root.add_child(strap)
	return root


func get_interaction_prompt(player) -> String:
	if is_carried or not player.can_carry_more():
		return ""
	return "[E] Pick up planks"


func interact(player) -> void:
	if not is_carried and player.can_carry_more():
		player.pick_up(self)


func set_carried(carried: bool) -> void:
	is_carried = carried
	freeze = carried
	collision_layer = 0 if carried else LAYER_ITEMS
	collision_mask = 0 if carried else MASK_WORLD_AND_ITEMS
	if not carried:
		sleeping = false
