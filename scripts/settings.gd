extends Node

## Persisted player-facing device settings (volume, fullscreen) -- separate
## from MetaProgression's per-save-slot progression data since these are
## device preferences, not tied to any particular save slot.

signal settings_changed

const SETTINGS_FILE: String = "user://settings.json"
const MASTER_BUS: String = "Master"

var master_volume: float = 1.0
var fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()
	settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	_save()
	settings_changed.emit()


func _apply() -> void:
	var bus_index := AudioServer.get_bus_index(MASTER_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(master_volume, 0.0001)))
	# No window to resize under the headless playtest harness.
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		return
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	master_volume = float(data.get("master_volume", 1.0))
	fullscreen = bool(data.get("fullscreen", false))


func _save() -> void:
	var data := {"master_volume": master_volume, "fullscreen": fullscreen}
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
