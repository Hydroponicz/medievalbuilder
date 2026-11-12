extends Node
## Saves and loads the world to a single file on your PC.
## On Windows the file lives at:
##   %APPDATA%\Godot\app_userdata\Medieval Builder\savegame.json
##
## The world (main.gd) registers itself here and knows how to collect and apply its own state.

signal saved(is_autosave: bool)
signal loaded

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.json.tmp"
## Bump this when the save format changes, so old saves can be upgraded.
const SAVE_VERSION := 1

var world: Node = null


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(is_autosave := false) -> bool:
	if world == null:
		return false

	var data: Dictionary = world.collect_save_data()
	data["version"] = SAVE_VERSION
	data["progression"] = Progression.get_save_data()

	# Write to a temporary file first, so a crash mid-save can't corrupt the real save.
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var dir := DirAccess.open("user://")
	if dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
	dir.rename("savegame.json.tmp", "savegame.json")

	saved.emit(is_autosave)
	return true


func load_game() -> bool:
	if world == null or not has_save():
		return false

	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file could not be read. Starting a fresh world.")
		return false

	Progression.apply_save_data(data.get("progression", {}))
	world.apply_save_data(data)
	loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Wipes the save and starts over with an untouched world.
func new_world() -> void:
	delete_save()
	Progression.reset()
	world = null
	get_tree().paused = false
	get_tree().reload_current_scene()
