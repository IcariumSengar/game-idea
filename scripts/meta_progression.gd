extends Node

## Single source of truth for cross-run player stats and both currencies.
## New upgradeable stats only need a _register_stat() call here -- Shop
## and HUD read the definitions generically and need no per-stat code.
##
## Two independent currency pools per DESIGN.md: player currency (from
## loot value collected) funds player-power stats; backpack currency (from
## time survived) funds backpack-only stats. Each StatDef is tagged with
## which pool funds it.

signal currency_changed
signal stat_changed(stat_id: StringName, level: int)

const STAT_BACKPACK_CAPACITY: StringName = &"backpack_capacity"
const STAT_PICKUP_RANGE: StringName = &"pickup_range"
const STAT_DAMAGE: StringName = &"damage"
const STAT_MOVE_SPEED: StringName = &"move_speed"
const STAT_COMPACTOR_COMMON: StringName = &"compactor_common"
const STAT_COMPACTOR_UNCOMMON: StringName = &"compactor_uncommon"
const STAT_COMPACTOR_RARE: StringName = &"compactor_rare"
const STAT_COMPACTOR_EPIC: StringName = &"compactor_epic"
const STAT_COMPACTOR_MYTHIC: StringName = &"compactor_mythic"
const STAT_PURGE: StringName = &"purge"

## Placeholder rate per DESIGN.md pending playtesting.
const BACKPACK_CURRENCY_PER_SECOND: float = 1.0

const SAVE_SLOTS: int = 4
const SAVE_DIR: String = "user://saves"
const SLOT_INDEX_FILE: String = "user://current_slot.txt"

var player_currency: int = 0
var backpack_currency: int = 0
var current_slot: int = 0

var _stat_defs: Array[StatDef] = []
var _stat_levels: Dictionary = {}
var _slot_metadata: Array = []  # Array of {date, playtime, stats}


func _ready() -> void:
	_register_stat(
		STAT_BACKPACK_CAPACITY,
		"Backpack Capacity",
		1.0,
		1.0,
		20,
		1.20,
		12,
		0,
		StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_PICKUP_RANGE, "Magnet Range", 60.0, 8.0, 12, 1.15, 15, 0, StatDef.Currency.PLAYER
	)
	_register_stat(STAT_DAMAGE, "Damage", 20.0, 2.0, 15, 1.15, 20, 0, StatDef.Currency.PLAYER)
	_register_stat(
		STAT_MOVE_SPEED, "Move Speed", 250.0, 10.0, 15, 1.18, 10, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_COMPACTOR_COMMON, "Compactor: Common", 64.0, 16.0, 8, 1.10, 8, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_UNCOMMON,
		"Compactor: Uncommon",
		32.0,
		8.0,
		15,
		1.12,
		6,
		0,
		StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_RARE, "Compactor: Rare", 16.0, 4.0, 25, 1.14, 5, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_EPIC, "Compactor: Epic", 8.0, 2.0, 40, 1.16, 4, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_MYTHIC,
		"Compactor: Mythic",
		4.0,
		1.0,
		70,
		1.18,
		3,
		0,
		StatDef.Currency.BACKPACK
	)
	_register_stat(STAT_PURGE, "Purge", 0.0, 0.0, 100, 1.30, 4, 0, StatDef.Currency.BACKPACK)
	_initialize_slots()
	_load_slot_metadata()
	_load()


func get_stat_defs() -> Array[StatDef]:
	return _stat_defs


func get_stat(id: StringName) -> float:
	var def := _find_def(id)
	if def == null:
		push_error("Unknown stat id: %s" % id)
		return 0.0
	return def.base_value + float(get_level(id)) * def.per_level_gain


func get_level(id: StringName) -> int:
	return _stat_levels.get(id, 0)


func get_cost(id: StringName) -> int:
	var def := _find_def(id)
	if def == null:
		return 0
	return roundi(float(def.base_cost) * pow(def.cost_growth, get_level(id)))


func is_maxed(id: StringName) -> bool:
	var def := _find_def(id)
	if def == null:
		return true
	return get_level(id) >= def.level_cap


func award_run_end_currency(loot_value: int, seconds_survived: float) -> void:
	player_currency += loot_value
	backpack_currency += roundi(seconds_survived * BACKPACK_CURRENCY_PER_SECOND)
	currency_changed.emit()


func buy_upgrade(id: StringName) -> bool:
	var def := _find_def(id)
	if def == null or is_maxed(id):
		return false
	var cost := get_cost(id)
	match def.currency:
		StatDef.Currency.PLAYER:
			if player_currency < cost:
				return false
			player_currency -= cost
		StatDef.Currency.BACKPACK:
			if backpack_currency < cost:
				return false
			backpack_currency -= cost
	var new_level: int = get_level(id) + 1
	_stat_levels[id] = new_level
	currency_changed.emit()
	stat_changed.emit(id, new_level)
	return true


func _register_stat(
	id: StringName,
	display_name: String,
	base_value: float,
	per_level_gain: float,
	base_cost: int,
	cost_growth: float,
	level_cap: int,
	decimals: int,
	currency: StatDef.Currency
) -> void:
	var def := StatDef.new()
	def.id = id
	def.display_name = display_name
	def.base_value = base_value
	def.per_level_gain = per_level_gain
	def.base_cost = base_cost
	def.cost_growth = cost_growth
	def.level_cap = level_cap
	def.decimals = decimals
	def.currency = currency
	_stat_defs.append(def)
	_stat_levels[id] = 0


func _find_def(id: StringName) -> StatDef:
	for def in _stat_defs:
		if def.id == id:
			return def
	return null


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
		return
	var file := FileAccess.open(slot_file, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	player_currency = data.get("player_currency", 0)
	backpack_currency = data.get("backpack_currency", 0)
	var saved_levels: Dictionary = data.get("stat_levels", {})
	for stat_id: String in saved_levels:
		_stat_levels[StringName(stat_id)] = int(saved_levels[stat_id])
	currency_changed.emit()


func save() -> void:
	_ensure_save_dir()
	var data := {
		"player_currency": player_currency,
		"backpack_currency": backpack_currency,
		"stat_levels": _stat_levels
	}
	var slot_file := _get_slot_save_path(current_slot)
	var file := FileAccess.open(slot_file, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		_update_slot_metadata(current_slot)


func _ensure_save_dir() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func set_slot(slot: int) -> void:
	if slot < 0 or slot >= SAVE_SLOTS:
		return
	current_slot = slot
	_load()


func _update_slot_metadata(slot: int) -> void:
	if slot < 0 or slot >= _slot_metadata.size():
		return
	var metadata: Dictionary = _slot_metadata[slot]
	metadata["last_played"] = Time.get_ticks_msec()
	metadata["playtime_hours"] = 0.0
	metadata["preview"] = _get_slot_preview()
	_save_slot_metadata()


func _get_slot_preview() -> String:
	var preview: Array = []
	for def in _stat_defs:
		var level := get_level(def.id)
		if level > 0:
			preview.append("%s Lv%d" % [def.display_name.trim_prefix("Compactor: "), level])
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


func get_all_slots() -> Array:
	return _slot_metadata
