extends Control

## Main menu - entry point for the game.


func _ready() -> void:
	# playtest_harness.gd drives its own navigation/save-slot sandboxing and
	# would otherwise race this auto-load (and get its slot/seed clobbered
	# by it loading the player's real last-used slot).
	if PlaytestHarness.active:
		return
	# Auto-load last save if it exists
	var last_slot := MetaProgression.get_last_slot()
	if last_slot >= 0:
		MetaProgression.set_slot(last_slot)
		SceneTransition.goto_scene.call_deferred("res://scenes/run_prep.tscn")
		return

	var version := _read_version()
	$CenterContainer/ContentVBox/VersionLabel.text = "v%s" % version


func _on_new_game_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/save_slot_selector.tscn")


func _on_load_game_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/save_slot_selector.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/settings_menu.tscn")


func _on_quit_pressed() -> void:
	MetaProgression.save()
	CloudSync.sync_now()
	get_tree().quit()


func _read_version() -> String:
	var file := FileAccess.open("res://VERSION", FileAccess.READ)
	if file == null:
		return "?"
	return file.get_as_text().strip_edges()
