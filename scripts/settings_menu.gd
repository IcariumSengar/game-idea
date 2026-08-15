extends Control

@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value_label: Label = %VolumeValueLabel
@onready var _fullscreen_check: CheckButton = %FullscreenCheck


func _ready() -> void:
	_volume_slider.value = Settings.master_volume * 100.0
	_fullscreen_check.button_pressed = Settings.fullscreen
	_update_volume_label()


func _on_volume_slider_value_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)
	_update_volume_label()


func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	Settings.set_fullscreen(toggled_on)


func _update_volume_label() -> void:
	_volume_value_label.text = "%d%%" % roundi(_volume_slider.value)


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/main_menu.tscn")
