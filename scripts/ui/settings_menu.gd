extends Control

## Rebinding a key (DESIGN.md-adjacent direct feedback, 2026-08-17):
## clicking a keybind button arms it, then the next physical key pressed
## becomes its new binding -- Escape cancels instead of binding itself, so
## there's always a way out of "listening" mode without picking a key.
const LISTENING_LABEL: String = "Press a key..."
const CONFLICT_LABEL: String = "Already bound!"
const CONFLICT_FLASH_DURATION: float = 0.6

var _keybind_buttons: Dictionary = {}
var _listening_action: StringName = StringName()

@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value_label: Label = %VolumeValueLabel
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _keybind_container: VBoxContainer = %KeybindContainer


func _ready() -> void:
	_volume_slider.value = Settings.master_volume * 100.0
	_fullscreen_check.button_pressed = Settings.fullscreen
	_update_volume_label()
	_build_keybind_rows()
	_volume_slider.grab_focus()


func _on_volume_slider_value_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)
	_update_volume_label()


func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	Settings.set_fullscreen(toggled_on)


func _update_volume_label() -> void:
	_volume_value_label.text = "%d%%" % roundi(_volume_slider.value)


## Built in code rather than hand-laid in the .tscn -- one row per entry
## in Settings.KEYBIND_ORDER, same "data drives the UI" pattern the skill
## tree and shop tabs already use, so adding a rebindable action later
## needs no scene edit.
func _build_keybind_rows() -> void:
	_keybind_buttons.clear()
	for action: StringName in Settings.KEYBIND_ORDER:
		_add_keybind_row(action)


func _add_keybind_row(action: StringName) -> void:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = Settings.KEYBIND_LABELS.get(action, String(action))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 28)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_keybind_button_pressed.bind(action))
	row.add_child(button)

	_keybind_container.add_child(row)
	_keybind_buttons[action] = button
	_refresh_keybind_button(action)


func _refresh_keybind_button(action: StringName) -> void:
	var button: Button = _keybind_buttons[action]
	button.text = OS.get_keycode_string(Settings.get_keybind(action))


func _on_keybind_button_pressed(action: StringName) -> void:
	if _listening_action != StringName() and _listening_action != action:
		_refresh_keybind_button(_listening_action)
	_listening_action = action
	_keybind_buttons[action].text = LISTENING_LABEL


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if _listening_action == StringName() or key_event == null or not key_event.pressed:
		return
	var action := _listening_action
	_listening_action = StringName()
	if key_event.physical_keycode == KEY_ESCAPE:
		_refresh_keybind_button(action)
	elif Settings.set_keybind(action, key_event.physical_keycode):
		_refresh_keybind_button(action)
	else:
		_flash_conflict(action)
	get_viewport().set_input_as_handled()


func _flash_conflict(action: StringName) -> void:
	_keybind_buttons[action].text = CONFLICT_LABEL
	await get_tree().create_timer(CONFLICT_FLASH_DURATION).timeout
	_refresh_keybind_button(action)


func _on_reset_keybinds_pressed() -> void:
	Settings.reset_keybinds()
	for action: StringName in _keybind_buttons:
		_refresh_keybind_button(action)


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/main_menu.tscn")
