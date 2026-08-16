extends Node

## Save-slot persistence: file I/O, slot metadata, and the 4-slot
## selection flow. Split out of MetaProgression (which owns stat/currency
## data and math) so this autoload owns a single responsibility -- what
## gets saved lives on MetaProgression; how/when/where it's written to
## disk lives here. Talks to MetaProgression only through its public
## export_save_data()/import_save_data()/reset_progress() surface.

const SAVE_SLOTS: int = 4
const SAVE_DIR: String = "user://saves"
const LAST_SLOT_FILE: String = "user://last_slot.json"
## Outside the 0-3 range the Load Game screen manages, so a playtest batch
## (see playtest_harness.gd) never shows up there and never touches the
## player's real slots -- it gets its own save file, reset fresh every run.
const PLAYTEST_SLOT: int = 99

var current_slot: int = 0

var _slot_metadata: Array = []  # Array of {date, playtime, stats}
var _session_start_msec: int = 0
var _playtest_mode: bool = false


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	_playtest_mode = "--playtest" in user_args or "--unit-test" in user_args
	if _playtest_mode:
		current_slot = PLAYTEST_SLOT
	_initialize_slots()
	_load_slot_metadata()
	_load()
	_session_start_msec = Time.get_ticks_msec()


func _initialize_slots() -> void:
	_slot_metadata.clear()
	for i in range(SAVE_SLOTS):
		_slot_metadata.append({"last_played": 0, "playtime_hours": 0.0, "preview": ""})


func _load_slot_metadata() -> void:
	var metadata_file := _get_slot_metadata_path()
	if ResourceLoader.exists(metadata_file):
		var file := FileAccess.open(metadata_file, FileAccess.READ)
		if file != null:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data != null and data is Array:
				_slot_metadata = data


func _load() -> void:
	var slot_file := _get_slot_save_path(current_slot)
	if not ResourceLoader.exists(slot_file):
		MetaProgression.reset_progress()
		return
	var file := FileAccess.open(slot_file, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	MetaProgression.import_save_data(data)


func save() -> void:
	if _playtest_mode:
		return
	_ensure_save_dir()
	var slot_file := _get_slot_save_path(current_slot)
	var file := FileAccess.open(slot_file, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(MetaProgression.export_save_data()))
		_update_slot_metadata(current_slot)


func _ensure_save_dir() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func set_slot(slot: int) -> void:
	if slot < 0 or slot >= SAVE_SLOTS:
		return
	current_slot = slot
	_save_last_slot(slot)
	_load()
	_session_start_msec = Time.get_ticks_msec()


## Wipes the target slot's save file and starts it fresh -- used by the
## save-slot screen's "Overwrite" action on an already-occupied slot.
func overwrite_slot(slot: int) -> void:
	if slot < 0 or slot >= SAVE_SLOTS:
		return
	current_slot = slot
	_save_last_slot(slot)
	MetaProgression.reset_progress()
	_session_start_msec = Time.get_ticks_msec()


func _save_last_slot(slot: int) -> void:
	var data := {"last_slot": slot}
	var file := FileAccess.open(LAST_SLOT_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


## Clears the "resume last slot" record -- used when backing out to the
## slot-select screen so the next launch shows it instead of auto-resuming.
func clear_last_slot() -> void:
	_save_last_slot(-1)


func get_last_slot() -> int:
	if not ResourceLoader.exists(LAST_SLOT_FILE):
		return -1
	var file := FileAccess.open(LAST_SLOT_FILE, FileAccess.READ)
	if file == null:
		return -1
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return -1
	var slot: int = data.get("last_slot", -1)
	if slot < 0 or slot >= SAVE_SLOTS:
		return -1
	return slot


func _update_slot_metadata(slot: int) -> void:
	if slot < 0 or slot >= _slot_metadata.size():
		return
	var metadata: Dictionary = _slot_metadata[slot]
	var elapsed_hours: float = float(Time.get_ticks_msec() - _session_start_msec) / 3_600_000.0
	metadata["last_played"] = int(Time.get_unix_time_from_system())
	metadata["playtime_hours"] = float(metadata.get("playtime_hours", 0.0)) + elapsed_hours
	metadata["preview"] = _get_slot_preview()
	_save_slot_metadata()
	_session_start_msec = Time.get_ticks_msec()


func _get_slot_preview() -> String:
	var preview: Array = []
	for def in MetaProgression.get_stat_defs():
		var level := MetaProgression.get_level(def.id)
		if level > 0:
			preview.append("%s Lv%d" % [def.display_name, level])
	return " | ".join(preview) if preview.size() > 0 else "No upgrades"


func _save_slot_metadata() -> void:
	var metadata_file := _get_slot_metadata_path()
	var file := FileAccess.open(metadata_file, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_slot_metadata))


func _get_slot_save_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func _get_slot_metadata_path() -> String:
	return "%s/metadata.json" % SAVE_DIR


func get_slot_metadata(slot: int) -> Dictionary:
	if slot < 0 or slot >= _slot_metadata.size():
		return {}
	return _slot_metadata[slot]


## Removes a slot's save file and clears its metadata -- used by the
## save-slot screen's "Delete" action.
func delete_slot(slot: int) -> void:
	var file_path := _get_slot_save_path(slot)
	if ResourceLoader.exists(file_path):
		DirAccess.remove_absolute(file_path)
	get_slot_metadata(slot).clear()


func get_all_slots() -> Array:
	return _slot_metadata
