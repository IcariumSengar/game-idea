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

## Placeholder rate -- DESIGN.md leaves this open pending playtesting.
const BACKPACK_CURRENCY_PER_SECOND: float = 0.33

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
		10,
		1.0,
		999,
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
