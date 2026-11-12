extends RefCounted
## Every kind of building block. Add new block types here.
## Use via: const BlockTypes = preload("res://scripts/building/block_types.gd")

const BLOCK_SIZE := 0.5  # metres

const ROUGH_LOG := 1

## cost = build supplies used per block (1 log = 10 supplies, see supply_pile.gd).
const TYPES := {
	1: {
		"name": "Rough log block",
		"side": Color(0.42, 0.29, 0.18),
		"end": Color(0.74, 0.58, 0.38),
		"cost": 1,
	},
}


static func get_info(type: int) -> Dictionary:
	return TYPES.get(type, TYPES[ROUGH_LOG])


static func get_type_name(type: int) -> String:
	return get_info(type)["name"]


static func get_cost(type: int) -> int:
	return get_info(type)["cost"]
