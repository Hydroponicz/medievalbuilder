extends Node
## Tracks progression points for each skill line (Forestry, later Farming, Mining...).
## Doing work by hand earns points; points raise the skill's level.
## In later phases, levels will unlock new buildings and automation for that line.

signal points_gained(skill: StringName, amount: int, reason: String)
signal level_up(skill: StringName, new_level: int)

const FORESTRY := &"forestry"

const SKILL_NAMES := {
	&"forestry": "Forestry",
}

## Total points needed to reach each level. Index 0 = level 1, index 1 = level 2, ...
const LEVEL_THRESHOLDS := [0, 25, 75, 160, 300, 500, 800]

var _points := {}


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
