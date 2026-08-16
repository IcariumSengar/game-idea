extends Control

## Pre-run menu - view progress and decide to start run or view skill tree.

@onready var _progress_label: Label = %ProgressLabel
@onready var _condense_button: Button = %CondenseButton
@onready var _clear_button: Button = %ClearButton


func _ready() -> void:
	_update_progress_display()
	_update_ability_buttons()


func _update_progress_display() -> void:
	var progress_text: String = ""
	progress_text += "Your Hoard\n\n"
	progress_text += "Essence: %d\n" % MetaProgression.player_currency
	progress_text += "Stardust: %d\n\n" % MetaProgression.backpack_currency

	progress_text += "Upgrades:\n"
	for def in MetaProgression.get_stat_defs():
		var level := MetaProgression.get_level(def.id)
		if level > 0:
			progress_text += "  %s: Lv %d\n" % [def.display_name, level]

	if progress_text.ends_with("\n\n"):
		progress_text += "  (No upgrades yet)\n"

	_progress_label.text = progress_text


## Pre-run choice between Condense (merge 2 of a tier into 1 of the next
## tier up) and Clear (bank 1 item's value, free the slot) -- see
## backpack_ability.gd. Persists immediately since it's a save-level
## preference, not something bought.
func _on_condense_pressed() -> void:
	MetaProgression.set_backpack_ability(MetaProgression.BACKPACK_ABILITY_CONDENSE)
	_update_ability_buttons()


func _on_clear_pressed() -> void:
	MetaProgression.set_backpack_ability(MetaProgression.BACKPACK_ABILITY_CLEAR)
	_update_ability_buttons()


func _update_ability_buttons() -> void:
	var active: StringName = MetaProgression.active_backpack_ability
	_condense_button.text = (
		"> Condense" if active == MetaProgression.BACKPACK_ABILITY_CONDENSE else "Condense"
	)
	_clear_button.text = "> Clear" if active == MetaProgression.BACKPACK_ABILITY_CLEAR else "Clear"


func _on_start_run_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/arena.tscn")


func _on_view_tree_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/shop.tscn")


func _on_back_pressed() -> void:
	SaveManager.clear_last_slot()
	SceneTransition.goto_scene("res://scenes/ui/save_slot_selector.tscn")
