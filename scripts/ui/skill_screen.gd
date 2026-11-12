extends CanvasLayer
## The Forestry upgrades screen (K). Pauses the game while open.
## Shows every upgrade in the tree, and lets the player choose what to unlock and make.

const Upgrades := preload("res://scripts/progression/upgrades.gd")

const SKILL := &"forestry"
## How close to the log stack you must be to craft tools from its logs.
const CRAFT_DISTANCE := 5.0

const GOLD := Color(1.0, 0.86, 0.5)
const MUTED := Color(1, 1, 1, 0.6)

var _player = null
var _stockpile = null

var _root: Control
var _header: Label
var _list: VBoxContainer
var _footer: Label


func bind(player, stockpile) -> void:
	_player = player
	_stockpile = stockpile


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	# Deferred so a button isn't removed while it's still handling its own click.
	Progression.upgrades_changed.connect(_refresh.call_deferred)
	Progression.level_up.connect(func(_skill, _level): _refresh.call_deferred())


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible:
		if event.is_action_pressed("open_skills") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_skills") and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	# The build tool switches the mouse back to visible if bird's-eye view is on.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Contents --------------------------------------------------------------------

func _refresh() -> void:
	if _list == null:
		return
	var points := Progression.get_unlock_points(SKILL)
	_header.text = "%s   Level %d     Unlock points: %d" % [
		Progression.get_skill_name(SKILL), Progression.get_level(SKILL), points]

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for upgrade in Upgrades.for_skill(String(SKILL)):
		_list.add_child(_make_row(upgrade))

	if _near_log_stack():
		_footer.text = "You're at the log stack: tools can be made from its %d logs." % _stockpile.stored
	else:
		_footer.text = "Tools are made at the log stack from logs in storage. Structures are built in build mode [B]."


func _make_row(upgrade: Dictionary) -> Control:
	var id: String = upgrade["id"]
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var kind_word := "Tool" if upgrade["kind"] == Upgrades.TOOL else "Structure"
	var title := _label("%s   (%s)" % [upgrade["name"], kind_word], 20)
	text.add_child(title)

	var description := _label(upgrade["description"], 15)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(440, 0)
	text.add_child(description)

	var status := _label("", 15)
	status.modulate = MUTED
	text.add_child(status)

	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)

	# Work out where this upgrade is in its journey: unavailable, locked, unlockable, makeable, done.
	if not upgrade["available"]:
		status.text = "Coming in a later update"
		button.text = "Coming soon"
		button.disabled = true
		panel.modulate = Color(1, 1, 1, 0.55)
	elif not Progression.is_unlocked(id):
		if not Progression.requirements_met(id):
			status.text = "Requires: %s" % _names(upgrade["requires"])
			button.text = "Locked"
			button.disabled = true
		else:
			status.text = _cost_text(upgrade)
			button.text = "Unlock  (1 point)"
			button.disabled = not Progression.can_unlock(id)
			button.pressed.connect(_on_unlock.bind(id))
	elif upgrade["kind"] == Upgrades.TOOL and not Progression.is_made(id):
		var cost: int = upgrade["cost"]
		status.text = "Unlocked. Make it at the log stack: %d logs from storage." % cost
		status.modulate = GOLD
		button.text = "Make  (%d logs)" % cost
		button.disabled = not (_near_log_stack() and _stockpile.stored >= cost)
		if not _near_log_stack():
			button.tooltip_text = "Stand at the log stack to make tools."
		button.pressed.connect(_on_make.bind(id))
	elif upgrade["kind"] == Upgrades.TOOL:
		status.text = "Made and in use."
		status.modulate = GOLD
		button.text = "Owned"
		button.disabled = true
	else:
		status.text = "Unlocked. Build it in build mode [B], hotbar 4. Costs %d wood supplies." % upgrade["cost"]
		status.modulate = GOLD
		button.text = "Unlocked"
		button.disabled = true

	return panel


func _cost_text(upgrade: Dictionary) -> String:
	if upgrade["kind"] == Upgrades.TOOL:
		return "Then make it from %d logs at the log stack." % upgrade["cost"]
	return "Then build it in build mode for %d wood supplies (1 log)." % upgrade["cost"]


func _names(ids: Array) -> String:
	var names := PackedStringArray()
	for required in ids:
		names.append(Upgrades.get_upgrade(required).get("name", required))
	return ", ".join(names)


func _near_log_stack() -> bool:
	if _player == null or _stockpile == null:
		return false
	return _player.global_position.distance_to(_stockpile.global_position) <= CRAFT_DISTANCE


func _on_unlock(id: String) -> void:
	Progression.unlock(id)


func _on_make(id: String) -> void:
	var cost: int = Upgrades.get_upgrade(id)["cost"]
	if _near_log_stack() and _stockpile.remove_logs(cost):
		Progression.mark_made(id)


# --- Layout ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.075, 0.05, 0.97)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	_header = _label("", 26)
	_header.modulate = GOLD
	column.add_child(_header)

	column.add_child(_label("Each level gives an unlock point. Choose what to unlock, then make it with wood.", 15))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	_footer = _label("", 15)
	_footer.modulate = MUTED
	column.add_child(_footer)

	column.add_child(_label("K or Esc  close", 14))


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label
