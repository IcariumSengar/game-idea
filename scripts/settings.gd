extends Node

## Persisted player-facing device settings (volume, fullscreen,
## keybindings) -- separate from MetaProgression's per-save-slot
## progression data since these are device preferences, not tied to any
## particular save slot.

signal settings_changed

const SETTINGS_FILE: String = "user://settings.json"
const MASTER_BUS: String = "Master"

## Rebindable actions -- player.gd already polls physical keycodes
## directly (Input.is_physical_key_pressed()) rather than Godot's
## InputMap/actions system, so keybindings live here as plain keycodes
## rather than InputEventKey/action remaps. Move Up/Down/Left/Right keep
## WASD as their rebindable primary; the arrow-key fallback stays fixed
## in player.gd, not part of this map, so there's always at least one
## working movement scheme even after a bad rebind.
const DEFAULT_KEYBINDS: Dictionary = {
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"dash": KEY_SPACE,
	&"keep": KEY_K,
	&"discard": KEY_L,
}
## Display order + label for the settings-menu rebind list.
const KEYBIND_LABELS: Dictionary = {
	&"move_up": "Move Up",
	&"move_down": "Move Down",
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	&"dash": "Dash",
	&"keep": "Keep Gem",
	&"discard": "Discard Gem",
}
const KEYBIND_ORDER: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"dash", &"keep", &"discard"
]

var master_volume: float = 1.0
var fullscreen: bool = false
var keybinds: Dictionary = DEFAULT_KEYBINDS.duplicate()


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


## Returns false (and leaves the binding unchanged) if `keycode` is already
## bound to a different action -- callers use this to show a denied-rebind
## cue rather than silently creating a two-actions-one-key conflict.
func set_keybind(action: StringName, keycode: int) -> bool:
	for other_action: StringName in keybinds:
		if other_action != action and keybinds[other_action] == keycode:
			return false
	keybinds[action] = keycode
	_save()
	settings_changed.emit()
	return true


func get_keybind(action: StringName) -> int:
	return keybinds.get(action, DEFAULT_KEYBINDS.get(action, KEY_NONE))


func reset_keybinds() -> void:
	keybinds = DEFAULT_KEYBINDS.duplicate()
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
	var saved_keybinds: Dictionary = data.get("keybinds", {})
	for action: String in saved_keybinds:
		if DEFAULT_KEYBINDS.has(StringName(action)):
			keybinds[StringName(action)] = int(saved_keybinds[action])


func _save() -> void:
	var serialized_keybinds: Dictionary = {}
	for action: StringName in keybinds:
		serialized_keybinds[String(action)] = keybinds[action]
	var data := {
		"master_volume": master_volume, "fullscreen": fullscreen, "keybinds": serialized_keybinds
	}
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
