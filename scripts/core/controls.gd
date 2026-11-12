extends Node
## Registers every input action the game uses, in one readable place.
## To change a key binding, edit the lists below.

const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"toggle_camera": [KEY_V],
	"toggle_help": [KEY_H],
}

const MOUSE_ACTIONS := {
	"chop": [MOUSE_BUTTON_LEFT],
}


func _enter_tree() -> void:
	for action in KEY_ACTIONS:
		_reset_action(action)
		for key in KEY_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

	for action in MOUSE_ACTIONS:
		_reset_action(action)
		for button in MOUSE_ACTIONS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)


func _reset_action(action: StringName) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
