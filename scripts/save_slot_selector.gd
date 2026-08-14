extends Control

## Load/select save slot screen shown at game start.

@onready var _slots_container: VBoxContainer = $ScrollContainer/VBoxContainer/SlotsContainer


func _ready() -> void:
	_populate_slots()


func _populate_slots() -> void:
	for slot in range(MetaProgression.SAVE_SLOTS):
		var metadata := MetaProgression.get_slot_metadata(slot)
		_add_slot_button(slot, metadata)


func _add_slot_button(slot: int, metadata: Dictionary) -> void:
	var button_container := HBoxContainer.new()
	button_container.custom_minimum_size = Vector2(0, 60)

	# Slot info
	var info_label := Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if metadata.get("last_played", 0) == 0:
		info_label.text = "Slot %d — Empty" % (slot + 1)
	else:
		var last_played_str := _format_timestamp(metadata.get("last_played", 0))
		var playtime: float = metadata.get("playtime_hours", 0.0)
		var preview: String = metadata.get("preview", "No upgrades")
		info_label.text = "Slot %d — %s | %d h | %s" % [slot + 1, last_played_str, roundi(playtime), preview]

	button_container.add_child(info_label)

	# Load button
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(80, 0)
	load_btn.pressed.connect(_on_load_pressed.bind(slot))
	load_btn.disabled = metadata.get("last_played", 0) == 0
	button_container.add_child(load_btn)

	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(80, 0)
	delete_btn.pressed.connect(_on_delete_pressed.bind(slot))
	delete_btn.disabled = metadata.get("last_played", 0) == 0
	button_container.add_child(delete_btn)

	_slots_container.add_child(button_container)


func _on_load_pressed(slot: int) -> void:
	MetaProgression.set_slot(slot)
	get_tree().change_scene_to_file("res://scenes/run_prep.tscn")


func _on_delete_pressed(slot: int) -> void:
	var file_path := "user://saves/slot_%d.json" % slot
	if ResourceLoader.exists(file_path):
		DirAccess.remove_absolute(file_path)
	MetaProgression.get_slot_metadata(slot).clear()
	get_tree().reload_current_scene()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _format_timestamp(timestamp_ms: int) -> String:
	if timestamp_ms == 0:
		return "Never"
	var now_ms := Time.get_ticks_msec()
	var diff_ms := now_ms - timestamp_ms
	var diff_sec := diff_ms / 1000
	var diff_min := diff_sec / 60
	var diff_hours := diff_min / 60
	var diff_days := diff_hours / 24

	if diff_days > 0:
		return "%d days ago" % diff_days
	elif diff_hours > 0:
		return "%d hours ago" % diff_hours
	elif diff_min > 0:
		return "%d min ago" % diff_min
	else:
		return "Just now"
