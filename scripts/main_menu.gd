extends Control

## Main menu - entry point for the game.


func _ready() -> void:
	# Auto-load last save if it exists
	var last_slot := MetaProgression.get_last_slot()
	if last_slot >= 0:
		MetaProgression.set_slot(last_slot)
		SceneTransition.goto_scene.call_deferred("res://scenes/run_prep.tscn")
		return

	var version := _read_version()
	$CenterContainer/Panel/Margin/VBox/VersionLabel.text = "v%s" % version


func _on_new_game_pressed() -> void:
	MetaProgression.set_slot(0)
	MetaProgression.player_currency = 0
	MetaProgression.backpack_currency = 0
	MetaProgression._stat_levels.clear()
	MetaProgression._initialize_slots()
	SceneTransition.goto_scene("res://scenes/arena.tscn")


func _on_load_game_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/save_slot_selector.tscn")


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
