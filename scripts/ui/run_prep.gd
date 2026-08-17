extends Control

## Pre-run menu - view progress and decide to start run or view skill tree.

## Pacts (Depth Pass Group E, DESIGN.md 2026-08-17): re-selected every run,
## not a permanent purchase -- shown here, ahead of Start Run, reusing the
## screen space the deleted Backpack Ability picker used to occupy. "None"
## is always the first option and always valid; Pacts are opt-in.
const NONE_PACT_LABEL: String = "None"
const NONE_PACT_TOOLTIP: String = "No rule mutation this run -- the default."
const PACT_ACCENT: Color = Color(0.75, 0.4, 0.85, 1.0)

var _pact_buttons: Dictionary = {}

@onready var _progress_label: Label = %ProgressLabel
@onready var _pact_row: HBoxContainer = %PactRow


func _ready() -> void:
	_update_progress_display()
	_build_pact_row()


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


## Built in code rather than hand-laid in the .tscn since the roster comes
## from MetaProgression's Pact registry -- adding a Pact there shows up
## here with no scene edit needed, same reasoning as the skill tree's
## data-driven nodes.
func _build_pact_row() -> void:
	_pact_buttons.clear()
	_add_pact_button(StringName(), NONE_PACT_LABEL, NONE_PACT_TOOLTIP)
	for def: PactDef in MetaProgression.get_pact_defs():
		_add_pact_button(def.id, def.display_name, def.description)
	_refresh_pact_buttons()


func _add_pact_button(pact_id: StringName, label: String, tooltip: String) -> void:
	var button := TabButton.new()
	button.text = label
	button.tooltip_text = tooltip
	button.accent_color = PACT_ACCENT
	button.pressed.connect(_on_pact_button_pressed.bind(pact_id))
	_pact_row.add_child(button)
	_pact_buttons[pact_id] = button


func _on_pact_button_pressed(pact_id: StringName) -> void:
	MetaProgression.set_active_pact(pact_id)
	_refresh_pact_buttons()


func _refresh_pact_buttons() -> void:
	for pact_id: StringName in _pact_buttons:
		var button: TabButton = _pact_buttons[pact_id]
		button.set_active(pact_id == MetaProgression.active_pact)


func _on_start_run_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/arena.tscn")


func _on_view_tree_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/shop.tscn")


func _on_grimoire_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/grimoire.tscn")


func _on_back_pressed() -> void:
	SaveManager.clear_last_slot()
	SceneTransition.goto_scene("res://scenes/ui/save_slot_selector.tscn")
