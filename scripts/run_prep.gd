extends Control

## Pre-run menu - view progress and decide to start run or view skill tree.

@onready var _progress_label: Label = $CenterContainer/VBoxContainer/ProgressLabel


func _ready() -> void:
	_update_progress_display()


func _update_progress_display() -> void:
	var progress_text: String = ""
	progress_text += "Current Progress\n\n"
	progress_text += "Player Currency: %d\n" % MetaProgression.player_currency
	progress_text += "Backpack Currency: %d\n\n" % MetaProgression.backpack_currency

	progress_text += "Upgrades:\n"
	for def in MetaProgression.get_stat_defs():
		var level := MetaProgression.get_level(def.id)
		if level > 0:
			progress_text += "  %s: Lv %d\n" % [def.display_name, level]

	if progress_text.ends_with("\n\n"):
		progress_text += "  (No upgrades yet)\n"

	_progress_label.text = progress_text


func _on_start_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _on_view_tree_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/save_slot_selector.tscn")
