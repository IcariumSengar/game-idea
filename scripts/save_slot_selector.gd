extends Control

## Load/select save slot screen shown at game start.

const JUICY_BUTTON_SCRIPT: Script = preload("res://scripts/juicy_button.gd")
const BTN_NORMAL: StyleBoxFlat = preload("res://resources/button_normal.tres")
const BTN_HOVER: StyleBoxFlat = preload("res://resources/button_hover.tres")
const BTN_PRESSED: StyleBoxFlat = preload("res://resources/button_pressed.tres")
const ROW_PANEL: StyleBoxFlat = preload("res://resources/panel_row.tres")

@onready var _slots_container: VBoxContainer = %SlotsContainer


func _ready() -> void:
	_populate_slots()


func _populate_slots() -> void:
	for slot in range(MetaProgression.SAVE_SLOTS):
		var metadata := MetaProgression.get_slot_metadata(slot)
		_add_slot_button(slot, metadata)


func _add_slot_button(slot: int, metadata: Dictionary) -> void:
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", ROW_PANEL)

	var button_container := HBoxContainer.new()
	button_container.custom_minimum_size = Vector2(0, 52)
	button_container.add_theme_constant_override("separation", 10)
	row_panel.add_child(button_container)

	# Slot info
	var info_label := Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if metadata.get("last_played", 0) == 0:
		info_label.text = "Slot %d — Empty" % (slot + 1)
		info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58, 1))
	else:
		var last_played_str := _format_timestamp(metadata.get("last_played", 0))
		var playtime: float = metadata.get("playtime_hours", 0.0)
		var preview: String = metadata.get("preview", "No upgrades")
		info_label.text = (
			"Slot %d — %s | %d h | %s" % [slot + 1, last_played_str, roundi(playtime), preview]
		)
		info_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.85, 1))

	button_container.add_child(info_label)

	var is_empty: bool = metadata.get("last_played", 0) == 0

	# Load/Start button -- always enabled. Empty slots start fresh there
	# (MetaProgression.set_slot resets to defaults when a slot has no save
	# file); occupied slots load existing progress.
	var load_btn := _make_styled_button("Start" if is_empty else "Load", Vector2(80, 40))
	load_btn.pressed.connect(_on_load_pressed.bind(slot))
	button_container.add_child(load_btn)

	# Overwrite button -- only meaningful (and shown) for occupied slots;
	# wipes that slot back to a fresh save.
	if not is_empty:
		var overwrite_btn := _make_styled_button("Overwrite", Vector2(90, 40))
		overwrite_btn.pressed.connect(_on_overwrite_pressed.bind(slot))
		button_container.add_child(overwrite_btn)

	# Delete button
	var delete_btn := _make_styled_button("Delete", Vector2(80, 40))
	delete_btn.pressed.connect(_on_delete_pressed.bind(slot))
	delete_btn.disabled = is_empty
	button_container.add_child(delete_btn)

	_slots_container.add_child(row_panel)


func _make_styled_button(text: String, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.set_script(JUICY_BUTTON_SCRIPT)
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_stylebox_override("normal", BTN_NORMAL)
	btn.add_theme_stylebox_override("hover", BTN_HOVER)
	btn.add_theme_stylebox_override("pressed", BTN_PRESSED)
	return btn


func _on_load_pressed(slot: int) -> void:
	MetaProgression.set_slot(slot)
	SceneTransition.goto_scene("res://scenes/run_prep.tscn")


func _on_overwrite_pressed(slot: int) -> void:
	MetaProgression.overwrite_slot(slot)
	SceneTransition.goto_scene("res://scenes/run_prep.tscn")


func _on_delete_pressed(slot: int) -> void:
	var file_path := "user://saves/slot_%d.json" % slot
	if ResourceLoader.exists(file_path):
		DirAccess.remove_absolute(file_path)
	MetaProgression.get_slot_metadata(slot).clear()
	get_tree().reload_current_scene()


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/main_menu.tscn")


## `timestamp_sec` is a real Unix-epoch second count (from
## Time.get_unix_time_from_system()), not engine uptime -- it has to
## survive across process restarts to mean anything as "last played".
func _format_timestamp(timestamp_sec: int) -> String:
	if timestamp_sec == 0:
		return "Never"
	var now_sec := int(Time.get_unix_time_from_system())
	var diff_sec := now_sec - timestamp_sec
	var diff_min := diff_sec / 60
	var diff_hours := diff_min / 60
	var diff_days := diff_hours / 24

	if diff_days > 0:
		return "%d days ago" % diff_days
	if diff_hours > 0:
		return "%d hours ago" % diff_hours
	if diff_min > 0:
		return "%d min ago" % diff_min
	return "Just now"
