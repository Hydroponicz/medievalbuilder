extends Node
## Tracks progression for each skill line (Forestry, later Farming, Mining...).
## Doing work by hand earns points; points raise the skill's level.
## Each level after the first gives one unlock point, spent on upgrades the player chooses.
## Upgrades are defined in upgrades.gd.

const Upgrades := preload("res://scripts/progression/upgrades.gd")

signal points_gained(skill: StringName, amount: int, reason: String)
signal level_up(skill: StringName, new_level: int)
## Fired when an upgrade is unlocked or made.
signal upgrades_changed
## Fired when progress is loaded from a save or reset for a new world.
signal state_loaded

const FORESTRY := &"forestry"

const SKILL_NAMES := {
	&"forestry": "Forestry",
}

## Total points needed to reach each level. Index 0 = level 1, index 1 = level 2, ...
const LEVEL_THRESHOLDS := [0, 25, 75, 160, 300, 500, 800]

var _points := {}
## Upgrade ids the player has spent an unlock point on.
var _unlocked := {}
## Tool upgrade ids the player has crafted.
var _made := {}


func add_points(skill: StringName, amount: int, reason := "") -> void:
	var old_level := get_level(skill)
	_points[skill] = get_points(skill) + amount
	points_gained.emit(skill, amount, reason)
	var new_level := get_level(skill)
	if new_level > old_level:
		level_up.emit(skill, new_level)


func get_points(skill: StringName) -> int:
	return _points.get(skill, 0)


func get_level(skill: StringName) -> int:
	var points := get_points(skill)
	var level := 0
	for threshold in LEVEL_THRESHOLDS:
		if points >= threshold:
			level += 1
		else:
			break
	return level


## Returns (points at the start of the current level, points needed for the next level).
## At max level both values are equal.
func get_level_bounds(skill: StringName) -> Vector2i:
	var level := get_level(skill)
	var low: int = LEVEL_THRESHOLDS[level - 1]
	if level >= LEVEL_THRESHOLDS.size():
		return Vector2i(low, low)
	var high: int = LEVEL_THRESHOLDS[level]
	return Vector2i(low, high)


func get_skill_name(skill: StringName) -> String:
	return SKILL_NAMES.get(skill, String(skill).capitalize())


# --- Upgrades --------------------------------------------------------------------

## Unspent unlock points for a skill: one per level after the first.
func get_unlock_points(skill: StringName) -> int:
	var spent := 0
	for id in _unlocked:
		if Upgrades.get_upgrade(id).get("skill", "") == String(skill):
			spent += 1
	return maxi(get_level(skill) - 1 - spent, 0)


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func is_made(id: String) -> bool:
	return _made.has(id)


## True when an upgrade is actually in effect: tools once crafted, structures once unlocked.
func has_upgrade(id: String) -> bool:
	var upgrade := Upgrades.get_upgrade(id)
	if upgrade.is_empty():
		return false
	if upgrade["kind"] == Upgrades.TOOL:
		return is_made(id)
	return is_unlocked(id)


func requirements_met(id: String) -> bool:
	for required in Upgrades.get_upgrade(id).get("requires", []):
		if not is_unlocked(required):
			return false
	return true


func can_unlock(id: String) -> bool:
	var upgrade := Upgrades.get_upgrade(id)
	if upgrade.is_empty() or not upgrade["available"] or is_unlocked(id):
		return false
	return requirements_met(id) and get_unlock_points(StringName(upgrade["skill"])) > 0


func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	_unlocked[id] = true
	upgrades_changed.emit()
	return true


func mark_made(id: String) -> void:
	_made[id] = true
	upgrades_changed.emit()


# --- Saving ----------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var points := {}
	for skill in _points:
		points[String(skill)] = _points[skill]
	return {"points": points, "unlocked": _unlocked.keys(), "made": _made.keys()}


func apply_save_data(data: Dictionary) -> void:
	_points.clear()
	_unlocked.clear()
	_made.clear()
	# Older saves stored only the points dictionary.
	var points: Dictionary = data["points"] if data.has("points") else data
	for key in points:
		_points[StringName(key)] = int(points[key])
	for id in data.get("unlocked", []):
		_unlocked[String(id)] = true
	for id in data.get("made", []):
		_made[String(id)] = true
	state_loaded.emit()
	upgrades_changed.emit()


func reset() -> void:
	_points.clear()
	_unlocked.clear()
	_made.clear()
	state_loaded.emit()
	upgrades_changed.emit()
