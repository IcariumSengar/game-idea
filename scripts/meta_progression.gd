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

## Placeholder rate -- DESIGN.md leaves this open pending playtesting.
const BACKPACK_CURRENCY_PER_SECOND: float = 0.33

const SAVE_FILE_PATH: String = "user://meta_progression.json"

var player_currency: int = 0
var backpack_currency: int = 0

var _stat_defs: Array[StatDef] = []
var _stat_levels: Dictionary = {}


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


func _load() -> void:
	if not ResourceLoader.exists(SAVE_FILE_PATH):
		return
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
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
	var data := {
		"player_currency": player_currency,
		"backpack_currency": backpack_currency,
		"stat_levels": _stat_levels
	}
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
