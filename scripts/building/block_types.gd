extends RefCounted
## Every kind of building block. Add new block types here.
## Use via: const BlockTypes = preload("res://scripts/building/block_types.gd")

const BLOCK_SIZE := 0.5  # metres

const ROUGH_LOG := 1
const PLANK := 2

## Build supply materials held by supply piles.
const WOOD := "wood"      # From logs: 1 log = 10 rough log blocks.
const PLANKS := "planks"  # From a plank bundle: 1 bundle (1 split log) = 20 plank blocks.

## material = which build supply the block uses; cost = how much of it per block.
const TYPES := {
	1: {
		"name": "Rough log block",
		"side": Color(0.42, 0.29, 0.18),
		"end": Color(0.74, 0.58, 0.38),
		"material": WOOD,
		"cost": 1,
	},
	2: {
		"name": "Plank block",
		"side": Color(0.78, 0.6, 0.38),
		"end": Color(0.7, 0.52, 0.32),
		"material": PLANKS,
		"cost": 1,
	},
}


static func get_info(type: int) -> Dictionary:
	return TYPES.get(type, TYPES[ROUGH_LOG])


static func get_type_name(type: int) -> String:
	return get_info(type)["name"]


static func get_cost(type: int) -> int:
	return get_info(type)["cost"]


static func get_material(type: int) -> String:
	return get_info(type)["material"]
