extends RefCounted
## Every upgrade in every skill tree. Add or rebalance upgrades here.
## Use via: const Upgrades = preload("res://scripts/progression/upgrades.gd")
##
## How upgrades work:
##  1. Each skill level gives one unlock point.
##  2. Spend a point to unlock any upgrade whose requirements are met (the player chooses the order).
##  3. Then make it with wood:
##     - "tool": crafted at the log stack, paid with logs in storage ("cost" = logs).
##     - "structure": built in build mode, paid from a supply pile ("cost" = build supplies).
##
## "available": false means it's shown in the tree but arrives in a later update.

const TOOL := "tool"
const STRUCTURE := "structure"

const ALL := [
	{
		"id": "shoulder_strap",
		"skill": "forestry",
		"name": "Shoulder strap",
		"description": "A leather strap to steady the load. Carry 2 logs at once.",
		"kind": TOOL,
		"cost": 3,
		"requires": [],
		"available": true,
	},
	{
		"id": "sharpened_axe",
		"skill": "forestry",
		"name": "Sharpened axe",
		"description": "A keener edge. Trees and logs split in about 40% fewer hits.",
		"kind": TOOL,
		"cost": 4,
		"requires": [],
		"available": true,
	},
	{
		"id": "chopping_block",
		"skill": "forestry",
		"name": "Chopping block",
		"description": "Split logs into planks by hand. 1 log = 20 plank blocks, which look far better than rough logs.",
		"kind": STRUCTURE,
		"cost": 10,
		"requires": [],
		"available": true,
	},
	{
		"id": "log_shelter",
		"skill": "forestry",
		"name": "Log shelter",
		"description": "Roof over your log stack and make it bigger.",
		"kind": STRUCTURE,
		"cost": 0,
		"requires": [],
		"available": false,
	},
	{
		"id": "carrying_frame",
		"skill": "forestry",
		"name": "Carrying frame",
		"description": "A wooden frame on your back. Carry 3 logs at once.",
		"kind": TOOL,
		"cost": 0,
		"requires": ["shoulder_strap"],
		"available": false,
	},
	{
		"id": "sapling_nursery",
		"skill": "forestry",
		"name": "Sapling nursery",
		"description": "Plant saplings on stumps so the forest grows back.",
		"kind": STRUCTURE,
		"cost": 0,
		"requires": ["chopping_block"],
		"available": false,
	},
]


static func get_upgrade(id: String) -> Dictionary:
	for upgrade in ALL:
		if upgrade["id"] == id:
			return upgrade
	return {}


static func for_skill(skill: String) -> Array:
	var list := []
	for upgrade in ALL:
		if upgrade["skill"] == skill:
			list.append(upgrade)
	return list
