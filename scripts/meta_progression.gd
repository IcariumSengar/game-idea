extends Node

const CAPACITY_UPGRADE_AMOUNT: int = 5
const CAPACITY_UPGRADE_COST: int = 10
const PICKUP_RANGE_UPGRADE_AMOUNT: float = 15.0
const PICKUP_RANGE_UPGRADE_COST: int = 10

var currency: int = 0
var backpack_capacity: int = 20
var pickup_range: float = 60.0


func add_currency(amount: int) -> void:
	currency += amount


func buy_capacity_upgrade() -> bool:
	if currency < CAPACITY_UPGRADE_COST:
		return false
	currency -= CAPACITY_UPGRADE_COST
	backpack_capacity += CAPACITY_UPGRADE_AMOUNT
	return true


func buy_pickup_range_upgrade() -> bool:
	if currency < PICKUP_RANGE_UPGRADE_COST:
		return false
	currency -= PICKUP_RANGE_UPGRADE_COST
	pickup_range += PICKUP_RANGE_UPGRADE_AMOUNT
	return true
