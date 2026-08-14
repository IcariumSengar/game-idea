extends Node

## Single source of truth for cross-run player stats and currency.
## New upgradeable stats only need a _register_stat() call here -- Shop
## and HUD read the definitions generically and need no per-stat code.

signal currency_changed(current: int)
signal stat_changed(stat_id: StringName, new_value: float)

const STAT_BACKPACK_CAPACITY: StringName = &"backpack_capacity"
const STAT_PICKUP_RANGE: StringName = &"pickup_range"

var currency: int = 0

var _stat_defs: Array[StatDef] = []
var _stat_values: Dictionary = {}


func _ready() -> void:
	_register_stat(STAT_BACKPACK_CAPACITY, "Backpack Capacity", 1.0, 1.0, 10, 0)
	_register_stat(STAT_PICKUP_RANGE, "Pickup Range", 60.0, 15.0, 10, 0)


func get_stat_defs() -> Array[StatDef]:
	return _stat_defs


func get_stat(id: StringName) -> float:
	if not _stat_values.has(id):
		push_error("Unknown stat id: %s" % id)
		return 0.0
	return _stat_values[id]


func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)


func buy_upgrade(id: StringName) -> bool:
	var def := _find_def(id)
	if def == null or currency < def.upgrade_cost:
		return false
	currency -= def.upgrade_cost
	_stat_values[id] += def.upgrade_amount
	currency_changed.emit(currency)
	stat_changed.emit(id, _stat_values[id])
	return true


func _register_stat(
	id: StringName,
	display_name: String,
	base_value: float,
	upgrade_amount: float,
	upgrade_cost: int,
	decimals: int
) -> void:
	var def := StatDef.new()
	def.id = id
	def.display_name = display_name
	def.base_value = base_value
	def.upgrade_amount = upgrade_amount
	def.upgrade_cost = upgrade_cost
	def.decimals = decimals
	_stat_defs.append(def)
	_stat_values[id] = base_value


func _find_def(id: StringName) -> StatDef:
	for def in _stat_defs:
		if def.id == id:
			return def
	return null
