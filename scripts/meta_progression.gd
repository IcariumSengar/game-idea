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
const STAT_SPELL_UNLOCK: StringName = &"spell_unlock"
const STAT_ARCANE_HASTE: StringName = &"arcane_haste"
const STAT_ARCANE_PROJECTILE_SPEED: StringName = &"arcane_projectile_speed"
const STAT_INFERNO_FURY: StringName = &"inferno_fury"
const STAT_INFERNO_ARC_WIDTH: StringName = &"inferno_arc_width"
const STAT_INFERNO_BURN_DAMAGE: StringName = &"inferno_burn_damage"
const STAT_FROST_FREQUENCY: StringName = &"frost_frequency"
const STAT_FROST_RADIUS: StringName = &"frost_radius"
const STAT_FROST_SLOW_STRENGTH: StringName = &"frost_slow_strength"

const SPELL_ARCANE_BOLT: StringName = &"arcane_bolt"
const SPELL_INFERNO_BLADE: StringName = &"inferno_blade"
const SPELL_FROST_NOVA: StringName = &"frost_nova"

## v6 balance: deliberately slow -- Bearing is a late-game prestige
## upgrade, not something funded within the first few runs.
const BACKPACK_CURRENCY_PER_SECOND: float = 0.05

const SAVE_SLOTS: int = 4
const SAVE_DIR: String = "user://saves"
const SLOT_INDEX_FILE: String = "user://current_slot.txt"
const LAST_SLOT_FILE: String = "user://last_slot.json"
## Outside the 0-3 range the Load Game screen manages, so a playtest batch
## (see playtest_harness.gd) never shows up there and never touches the
## player's real slots -- it gets its own save file, reset fresh every run.
const PLAYTEST_SLOT: int = 99

var player_currency: int = 0
var backpack_currency: int = 0
var best_run_time: float = 0.0
var current_slot: int = 0

var _stat_defs: Array[StatDef] = []
var _stat_levels: Dictionary = {}
var _slot_metadata: Array = []  # Array of {date, playtime, stats}
var _session_start_msec: int = 0
var _playtest_mode: bool = false


func _ready() -> void:
	_register_stat(
		STAT_BACKPACK_CAPACITY, "Bearing", 1.0, 1.0, 100, 1.25, 10, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(STAT_PICKUP_RANGE, "Gleam", 60.0, 8.0, 12, 1.15, 15, 0, StatDef.Currency.PLAYER)
	_register_stat(STAT_DAMAGE, "Spellpower", 20.0, 2.0, 15, 1.15, 20, 0, StatDef.Currency.PLAYER)
	_register_stat(
		STAT_MOVE_SPEED, "Swiftness", 250.0, 10.0, 15, 1.18, 10, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_COMPACTOR_COMMON,
		"Commons Hoard",
		10.0,
		10.0,
		12,
		1.12,
		8,
		0,
		StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_UNCOMMON,
		"Uncommon Stash",
		8.0,
		5.0,
		18,
		1.14,
		6,
		0,
		StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_RARE, "Rare Vault", 5.0, 3.0, 28, 1.16, 5, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_EPIC, "Epic Trove", 3.0, 2.0, 42, 1.18, 4, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(
		STAT_COMPACTOR_MYTHIC, "Mythic Hoard", 2.0, 1.0, 75, 1.20, 3, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(STAT_PURGE, "Discard", 0.0, 0.0, 100, 1.30, 4, 0, StatDef.Currency.BACKPACK)
	_register_stat(
		STAT_SPELL_UNLOCK, "Spell Unlock", 0.0, 0.0, 25, 1.20, 5, 0, StatDef.Currency.PLAYER
	)
	# Base/per-level both scaled by 1/1.5 vs the original curve (0.5, -0.05) so
	# Arcane Bolt fires 50% faster by default and at every upgrade level, per
	# player balance feedback.
	_register_stat(
		STAT_ARCANE_HASTE, "Haste", 0.5 / 1.5, -0.05 / 1.5, 15, 1.15, 7, 2, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_ARCANE_PROJECTILE_SPEED,
		"Velocity",
		400.0,
		50.0,
		12,
		1.15,
		4,
		0,
		StatDef.Currency.PLAYER
	)
	_register_stat(STAT_INFERNO_FURY, "Fury", 1.0, -0.15, 18, 1.16, 4, 2, StatDef.Currency.PLAYER)
	_register_stat(
		STAT_INFERNO_ARC_WIDTH, "Reach", 90.0, 15.0, 15, 1.14, 6, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_INFERNO_BURN_DAMAGE, "Burn Damage", 0.0, 5.0, 14, 1.13, 12, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FROST_FREQUENCY, "Frequency", 2.0, -0.3, 20, 1.18, 4, 1, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FROST_RADIUS, "Radius", 150.0, 20.0, 16, 1.15, 7, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FROST_SLOW_STRENGTH,
		"Slow Strength",
		50.0,
		5.0,
		18,
		1.16,
		10,
		0,
		StatDef.Currency.PLAYER
	)
	_playtest_mode = "--playtest" in OS.get_cmdline_user_args()
	if _playtest_mode:
		current_slot = PLAYTEST_SLOT
	_initialize_slots()
	_load_slot_metadata()
	_load()
	_session_start_msec = Time.get_ticks_msec()


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


## Returns the previous best (before this run), so callers can compare
## against what just happened before the record gets overwritten.
func update_best_run(seconds_survived: float) -> float:
	var previous_best := best_run_time
	if seconds_survived > best_run_time:
		best_run_time = seconds_survived
	return previous_best


func is_spell_unlocked(spell_id: StringName) -> bool:
	match spell_id:
		SPELL_ARCANE_BOLT:
			return true
		SPELL_INFERNO_BLADE:
			return get_level(STAT_SPELL_UNLOCK) >= 1
		SPELL_FROST_NOVA:
			return get_level(STAT_SPELL_UNLOCK) >= 2
	return false


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
		_reset_to_defaults()
		currency_changed.emit()
		return
	var file := FileAccess.open(slot_file, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	player_currency = data.get("player_currency", 0)
	backpack_currency = data.get("backpack_currency", 0)
	best_run_time = data.get("best_run_time", 0.0)
	var saved_levels: Dictionary = data.get("stat_levels", {})
	for stat_id: String in saved_levels:
		_stat_levels[StringName(stat_id)] = int(saved_levels[stat_id])
	currency_changed.emit()


## Resets in-memory progress to a fresh save's defaults -- used both when
## switching to an empty slot (nothing to load) and when explicitly
## overwriting an occupied one. Without this, switching to an empty slot
## would silently keep whatever was in memory from the previously loaded
## slot instead of starting clean.
func _reset_to_defaults() -> void:
	player_currency = 0
	backpack_currency = 0
	best_run_time = 0.0
	for stat_id: StringName in _stat_levels:
		_stat_levels[stat_id] = 0


## Directly sets a stat's level without spending currency -- used only to
## seed a playtest batch's starting loadout (e.g. unlocking a spell so the
## bot actually exercises it), never reachable from normal play.
func debug_set_level(id: StringName, level: int) -> void:
	_stat_levels[id] = level


func save() -> void:
	if _playtest_mode:
		return
	_ensure_save_dir()
	var data := {
		"player_currency": player_currency,
		"backpack_currency": backpack_currency,
		"best_run_time": best_run_time,
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
	_reset_to_defaults()
	_session_start_msec = Time.get_ticks_msec()
	currency_changed.emit()


func _save_last_slot(slot: int) -> void:
	var data := {"last_slot": slot}
	var file := FileAccess.open(LAST_SLOT_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


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
	for def in _stat_defs:
		var level := get_level(def.id)
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


func get_all_slots() -> Array:
	return _slot_metadata
