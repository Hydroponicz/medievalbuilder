extends CanvasLayer
## On-screen info: crosshair, interaction prompt, Forestry progress, stored logs,
## floating "+points" popups and a controls reminder.

const SKILL := &"forestry"

const HELP_TEXT := "WASD  move     Shift  sprint     Space  jump\n" \
	+ "Mouse  look     Left click  chop     E  pick up / take / stack / drop\n" \
	+ "B  build mode     Tab  bird's-eye view     V  first / third person\n" \
	+ "Esc  pause menu     H  hide help"

var _crosshair: ColorRect
var _prompt_label: Label
var _skill_label: Label
var _skill_bar: ProgressBar
var _points_label: Label
var _storage_label: Label
var _help_label: Label
var _paused_label: Label
var _banner: Label
var _toast_anchor: Control
var _save_notice: Label
var _build_label: Label
var _build_tool = null


func _ready() -> void:
	_build()
	Progression.points_gained.connect(_on_points_gained)
	Progression.level_up.connect(_on_level_up)
	Progression.state_loaded.connect(_refresh_skill)
	SaveGame.saved.connect(_on_saved)
	SaveGame.loaded.connect(_show_save_notice.bind("World loaded"))
	_refresh_skill()


func bind(player, stockpile, build_tool) -> void:
	_build_tool = build_tool
	build_tool.status_changed.connect(_on_build_status_changed)
	player.prompt_changed.connect(_on_prompt_changed)
	stockpile.stored_changed.connect(_on_stored_changed)
	_on_stored_changed(stockpile.stored, stockpile.capacity)


func _process(_delta: float) -> void:
	# Only shown if the mouse was released without pausing (e.g. after alt-tab).
	var birds_eye: bool = _build_tool != null and _build_tool.birds_eye
	_paused_label.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not birds_eye
	_crosshair.visible = not birds_eye


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help_label.visible = not _help_label.visible


# --- Reactions -------------------------------------------------------------------

func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text
	var half := 3.0 if text != "" else 2.0
	_crosshair.offset_left = -half
	_crosshair.offset_top = -half
	_crosshair.offset_right = half
	_crosshair.offset_bottom = half


func _on_saved(is_autosave: bool) -> void:
	# The pause menu shows its own message when saving from there.
	if not get_tree().paused:
		_show_save_notice("Autosaved" if is_autosave else "Game saved")


func _show_save_notice(text: String) -> void:
	_save_notice.text = text
	_save_notice.modulate.a = 1.0
	var tween := _save_notice.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_save_notice, "modulate:a", 0.0, 0.8)


func _on_build_status_changed(text: String) -> void:
	_build_label.text = text
	_build_label.visible = text != ""


func _on_stored_changed(count: int, capacity: int) -> void:
	_storage_label.text = "Logs stacked:  %d / %d" % [count, capacity]


func _on_points_gained(skill: StringName, amount: int, _reason: String) -> void:
	_refresh_skill()
	var toast := _make_label(20)
	toast.text = "+%d %s" % [amount, Progression.get_skill_name(skill)]
	toast.modulate = Color(1.0, 0.86, 0.5)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.size = Vector2(400, 30)
	var start_y := 40.0 + _toast_anchor.get_child_count() * 24.0
	toast.position = Vector2(-200, start_y)
	_toast_anchor.add_child(toast)

	var tween := toast.create_tween().set_parallel(true)
	tween.tween_property(toast, "position:y", start_y - 30.0, 1.3)
	tween.tween_property(toast, "modulate:a", 0.0, 1.3).set_delay(0.4)
	tween.chain().tween_callback(toast.queue_free)


func _on_level_up(skill: StringName, new_level: int) -> void:
	_refresh_skill()
	_banner.text = "%s reached level %d!" % [Progression.get_skill_name(skill), new_level]
	_banner.modulate.a = 0.0
	var tween := _banner.create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.2)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _refresh_skill() -> void:
	var level := Progression.get_level(SKILL)
	var points := Progression.get_points(SKILL)
	var bounds := Progression.get_level_bounds(SKILL)
	_skill_label.text = "%s   Level %d" % [Progression.get_skill_name(SKILL), level]
	if bounds.y > bounds.x:
		_skill_bar.max_value = bounds.y - bounds.x
		_skill_bar.value = points - bounds.x
		_points_label.text = "%d / %d points" % [points, bounds.y]
	else:
		_skill_bar.max_value = 1
		_skill_bar.value = 1
		_points_label.text = "%d points (max level)" % points


# --- Layout ----------------------------------------------------------------------

func _build() -> void:
	# Crosshair dot in the middle of the screen.
	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.85)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -2
	_crosshair.offset_top = -2
	_crosshair.offset_right = 2
	_crosshair.offset_bottom = 2
	add_child(_crosshair)

	# Floating point popups appear just below the crosshair.
	_toast_anchor = Control.new()
	_toast_anchor.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_toast_anchor)

	# Interaction prompt near the bottom of the screen.
	_prompt_label = _make_label(24)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_label.offset_top = -190
	_prompt_label.offset_bottom = -150
	add_child(_prompt_label)

	# Level-up banner near the top.
	_banner = _make_label(34)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate = Color(1.0, 0.86, 0.5, 0.0)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 130
	_banner.offset_bottom = 180
	add_child(_banner)

	# Skill panel, top-left.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.72)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 16)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	_skill_label = _make_label(20)
	column.add_child(_skill_label)

	_skill_bar = ProgressBar.new()
	_skill_bar.show_percentage = false
	_skill_bar.custom_minimum_size = Vector2(240, 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.16, 0.12)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.66, 0.3)
	bar_fill.set_corner_radius_all(3)
	_skill_bar.add_theme_stylebox_override("background", bar_bg)
	_skill_bar.add_theme_stylebox_override("fill", bar_fill)
	column.add_child(_skill_bar)

	_points_label = _make_label(15)
	_points_label.modulate = Color(1, 1, 1, 0.75)
	column.add_child(_points_label)

	_storage_label = _make_label(18)
	column.add_child(_storage_label)

	# Controls reminder, bottom-left.
	_help_label = _make_label(15)
	_help_label.text = HELP_TEXT
	_help_label.modulate = Color(1, 1, 1, 0.8)
	_help_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help_label.offset_left = 16
	_help_label.offset_right = 700
	_help_label.offset_top = -100
	_help_label.offset_bottom = -16
	_help_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_help_label)

	# Build mode info, top-centre.
	_build_label = _make_label(18)
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_build_label.offset_top = 14
	_build_label.offset_bottom = 120
	_build_label.visible = false
	add_child(_build_label)

	# Small "Game saved" notice, bottom-right.
	_save_notice = _make_label(16)
	_save_notice.modulate = Color(1, 1, 1, 0)
	_save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_notice.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_save_notice.offset_left = -316
	_save_notice.offset_right = -16
	_save_notice.offset_top = -46
	_save_notice.offset_bottom = -16
	add_child(_save_notice)

	# Shown if the mouse is released without the pause menu open.
	_paused_label = _make_label(30)
	_paused_label.text = "Click to play"
	_paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_paused_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_paused_label)

	_ignore_mouse(self)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return label


## The HUD should never swallow mouse clicks meant for the game.
func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
