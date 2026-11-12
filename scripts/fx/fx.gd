extends RefCounted
## Small, reusable visual effects. Use via: const Fx = preload("res://scripts/fx/fx.gd")

const CHIP_MATERIAL := preload("res://materials/wood_cut.tres")
const LEAF_MATERIAL := preload("res://materials/leaves.tres")


## Wood chips flying off when an axe bites into a trunk.
static func wood_chips(parent: Node, at: Vector3, amount := 10) -> void:
	var chip := BoxMesh.new()
	chip.size = Vector3(0.05, 0.02, 0.08)
	chip.material = CHIP_MATERIAL
	_burst(parent, at, chip, amount, 60.0, 1.5, 3.5, 0.9)


## A puff of leaves when a tree hits the ground.
static func leaf_burst(parent: Node, at: Vector3, amount := 30) -> void:
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.12, 0.02, 0.12)
	leaf.material = LEAF_MATERIAL
	_burst(parent, at, leaf, amount, 180.0, 1.0, 3.0, 1.4)


static func _burst(parent: Node, at: Vector3, mesh: Mesh, amount: int, spread: float,
		speed_min: float, speed_max: float, lifetime: float) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.mesh = mesh
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.95
	particles.direction = Vector3.UP
	particles.spread = spread
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	parent.get_tree().create_timer(lifetime + 0.5).timeout.connect(particles.queue_free)
