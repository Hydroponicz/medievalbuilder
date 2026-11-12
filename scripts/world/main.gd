extends Node3D
## Sets up the world: sky and sun, a forest on the terrain, the log stack, the player and the HUD.

const TREE_SCENE := preload("res://scenes/tree.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STOCKPILE_SCENE := preload("res://scenes/log_stockpile.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

@export var tree_count := 140
@export var world_seed := 2026
## No trees grow closer than this to the spawn point.
@export var clearing_radius := 14.0
@export var min_tree_spacing := 3.2

@onready var terrain = $Terrain


func _ready() -> void:
	_setup_environment()

	var stockpile: Node3D = STOCKPILE_SCENE.instantiate()
	add_child(stockpile)
	stockpile.global_position = _on_ground(3.5, -2.0)
	stockpile.rotation.y = 0.35

	_spawn_forest(stockpile.global_position)

	var player: Node3D = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = _on_ground(0.0, 7.0) + Vector3.UP * 0.5

	var hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.bind(player, stockpile)


func _on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.get_height(x, z), z)


func _spawn_forest(keep_clear: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	# Low-frequency noise groups trees into woods and open glades.
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = world_seed
	forest_noise.frequency = 0.03

	var limit: float = terrain.world_size * 0.5 - 22.0
	var placed: Array[Vector2] = []
	var attempts := 0

	while placed.size() < tree_count and attempts < tree_count * 40:
		attempts += 1
		var spot := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if spot.length() < clearing_radius:
			continue
		if spot.distance_to(Vector2(keep_clear.x, keep_clear.z)) < 5.0:
			continue
		if forest_noise.get_noise_2d(spot.x, spot.y) < -0.15:
			continue
		if _too_close(spot, placed):
			continue
		placed.append(spot)

		var tree = TREE_SCENE.instantiate()
		var height := rng.randf_range(4.5, 8.0)
		tree.trunk_height = height
		tree.trunk_radius = lerpf(0.24, 0.38, (height - 4.5) / 3.5)
		tree.hits_to_fell = int(round(height * 0.8))
		tree.log_count = maxi(2, int(round(height / 2.2)))
		add_child(tree)
		tree.global_position = _on_ground(spot.x, spot.y)


func _too_close(spot: Vector2, others: Array[Vector2]) -> bool:
	for other in others:
		if spot.distance_to(other) < min_tree_spacing:
			return true
	return false


func _setup_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.72, 0.8, 0.88)
	sky_material.ground_horizon_color = Color(0.6, 0.65, 0.6)
	sky_material.ground_bottom_color = Color(0.25, 0.3, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.7, 0.78, 0.86)
	environment.fog_density = 0.006
	environment.fog_aerial_perspective = 0.5

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
