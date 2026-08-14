extends Control

@onready var _currency_label: Label = $ShopPanel/Margin/VBox/CurrencyLabel
@onready var _capacity_button: Button = $ShopPanel/Margin/VBox/BuyCapacityButton
@onready var _pickup_button: Button = $ShopPanel/Margin/VBox/BuyPickupRangeButton


func _ready() -> void:
	_refresh()


func _on_buy_capacity_button_pressed() -> void:
	MetaProgression.buy_capacity_upgrade()
	_refresh()


func _on_buy_pickup_range_button_pressed() -> void:
	MetaProgression.buy_pickup_range_upgrade()
	_refresh()


func _on_start_run_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _refresh() -> void:
	_currency_label.text = "Currency: %d" % MetaProgression.currency
	_capacity_button.text = (
		"Upgrade Capacity +%d (Cost: %d)  [Current: %d]"
		% [
			MetaProgression.CAPACITY_UPGRADE_AMOUNT,
			MetaProgression.CAPACITY_UPGRADE_COST,
			MetaProgression.backpack_capacity,
		]
	)
	_pickup_button.text = (
		"Upgrade Pickup Range +%.0f (Cost: %d)  [Current: %.0f]"
		% [
			MetaProgression.PICKUP_RANGE_UPGRADE_AMOUNT,
			MetaProgression.PICKUP_RANGE_UPGRADE_COST,
			MetaProgression.pickup_range,
		]
	)
