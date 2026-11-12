extends StaticBody3D
## Splits logs into planks by hand. Put a log on the block (E), then swing your axe at it.
## Each split log becomes one plank bundle, worth 20 plank blocks at a supply pile.

const Fx := preload("res://scripts/fx/fx.gd")
const LogItem := preload("res://scripts/gathering/log_item.gd")
const PLANK_BUNDLE_SCENE := preload("res://scenes/plank_bundle.tscn")
const BARK := preload("res://materials/bark.tres")
const CUT := preload("res://materials/wood_cut.tres")

const BLOCK_HEIGHT := 0.55

@export var hits_to_split := 4
@export var points_per_hit := 1
## Forestry points for delivering a freshly chopped log straight to the block.
@export var points_per_log := 2

var _has_log := false
var _hits := 0
var _log_visual: Node3D


func _ready() -> void:
	add_to_group("chopping_blocks")
	collision_layer = 1
	collision_mask = 0
	_build()
	_refresh()


func hits_needed() -> int:
	if Progression.has_upgrade("sharpened_axe"):
		return maxi(2, ceili(hits_to_split * 0.6))
	return hits_to_split


func get_interaction_prompt(player) -> String:
	if not _has_log:
		if player.has_carried_kind("log"):
			return "[E] Put log on the chopping block"
		return "Chopping block   (bring a log to split into planks)"
	if player.is_building():
		return ""
	if player.is_carrying():
		return "Put down what you're carrying to split the log"
	return "[LMB] Split log   (%d / %d)" % [_hits, hits_needed()]


func interact(player) -> void:
	if _has_log:
		return
	var item = player.take_carried_of_kind("log")
	if item == null:
		return
	if not item.counted:
		Progression.add_points(Progression.FORESTRY, points_per_log, "Log delivered")
	item.queue_free()
	_has_log = true
	_hits = 0
	_refresh()


func chop(_player: Node3D, hit_point: Vector3) -> void:
	Fx.wood_chips(get_tree().current_scene, hit_point, 6)
	if not _has_log:
		return
	_hits += 1
	Progression.add_points(Progression.FORESTRY, points_per_hit, "Split")
	if _hits >= hits_needed():
		_split()
	else:
		var tween := create_tween()
		tween.tween_property(_log_visual, "position:y", _log_rest_y() + 0.06, 0.05)
		tween.tween_property(_log_visual, "position:y", _log_rest_y(), 0.1)


## Drops any log on the block back on the ground (used when the block is removed).
func release_log() -> void:
	if not _has_log:
		return
	_has_log = false
	var item = preload("res://scenes/log.tscn").instantiate()
	item.counted = true
	get_parent().add_child(item)
	item.global_position = global_position + Vector3.UP * 1.0


func get_save_data() -> Dictionary:
	var p := global_position
	return {"position": [p.x, p.y, p.z], "yaw": rotation.y, "has_log": _has_log, "hits": _hits}


func apply_save_data(data: Dictionary) -> void:
	var p: Array = data.get("position", [])
	if p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(data.get("yaw", 0.0))
	_has_log = data.get("has_log", false)
	_hits = int(data.get("hits", 0))
	_refresh()


func _split() -> void:
	_has_log = false
	_hits = 0
	_refresh()
	Fx.wood_chips(get_tree().current_scene, global_position + Vector3.UP * (BLOCK_HEIGHT + 0.2), 24)

	var bundle: Node3D = PLANK_BUNDLE_SCENE.instantiate()
	get_parent().add_child(bundle)
	bundle.global_position = global_position + global_transform.basis.z * 0.9 + Vector3.UP * 0.5
	bundle.rotation.y = rotation.y


func _log_rest_y() -> float:
	return BLOCK_HEIGHT + LogItem.RADIUS


func _refresh() -> void:
	if _log_visual != null:
		_log_visual.visible = _has_log


func _build() -> void:
	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = 0.42
	stump_mesh.bottom_radius = 0.48
	stump_mesh.height = BLOCK_HEIGHT + 0.2
	stump_mesh.material = BARK
	var stump := MeshInstance3D.new()
	stump.mesh = stump_mesh
	stump.position.y = (BLOCK_HEIGHT - 0.2) * 0.5
	add_child(stump)

	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.4
	top_mesh.bottom_radius = 0.4
	top_mesh.height = 0.02
	top_mesh.material = CUT
	var top := MeshInstance3D.new()
	top.mesh = top_mesh
	top.position.y = BLOCK_HEIGHT + 0.005
	add_child(top)

	# The log waiting to be split, lying across the block.
	_log_visual = LogItem.build_visual()
	_log_visual.position.y = _log_rest_y()
	add_child(_log_visual)

	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.45
	cylinder.height = BLOCK_HEIGHT + 0.4
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position.y = (BLOCK_HEIGHT + 0.4) * 0.5
	add_child(shape)
