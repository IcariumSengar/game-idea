extends Control

## Main menu - entry point for the game.


func _ready() -> void:
	var version := _read_version()
	$PanelContainer/MarginContainer/VBoxContainer/VersionLabel.text = "v%s" % version


func _on_new_game_pressed() -> void:
	MetaProgression.set_slot(0)
	MetaProgression.player_currency = 0
	MetaProgression.backpack_currency = 0
	MetaProgression._stat_levels.clear()
	MetaProgression._initialize_slots()
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _on_load_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/save_slot_selector.tscn")


func _on_settings_pressed() -> void:
	pass  # TODO: Implement settings menu


func _on_quit_pressed() -> void:
	MetaProgression.save()
	CloudSync.sync_now()
	get_tree().quit()


func _read_version() -> String:
	var file := FileAccess.open("res://VERSION", FileAccess.READ)
	if file == null:
		return "?"
	return file.get_as_text().strip_edges()
