extends CanvasLayer
## Esc menu: pauses the game and offers Resume, Save Game, New World and Quit.

var _root: Control
var _resume_button: Button
var _new_world_button: Button
var _status: Label
var _confirming_new_world := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	SaveGame.saved.connect(_on_saved)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _root.visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = ""
	_reset_new_world_button()
	_resume_button.grab_focus()


func resume() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_save_pressed() -> void:
	if not SaveGame.save_game():
		_status.text = "Could not save."


func _on_saved(_is_autosave: bool) -> void:
	if _root.visible:
		_status.text = "Game saved."


func _on_new_world_pressed() -> void:
	if not _confirming_new_world:
		_confirming_new_world = true
		_new_world_button.text = "Delete save and start over?"
		_status.text = "Click again to confirm."
		return
	SaveGame.new_world()


func _on_quit_pressed() -> void:
	SaveGame.save_game()
	get_tree().quit()


func _reset_new_world_button() -> void:
	_confirming_new_world = false
	_new_world_button.text = "New World"


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.075, 0.05, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	_resume_button = _add_button(column, "Resume", resume)
	_add_button(column, "Save Game", _on_save_pressed)
	_new_world_button = _add_button(column, "New World", _on_new_world_pressed)
	_add_button(column, "Save & Quit", _on_quit_pressed)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(1.0, 0.86, 0.5)
	_status.custom_minimum_size = Vector2(0, 26)
	column.add_child(_status)


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
