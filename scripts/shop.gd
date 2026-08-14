extends Control

const BUTTON_STYLE_NORMAL: StyleBoxFlat = preload("res://resources/button_normal.tres")
const BUTTON_STYLE_HOVER: StyleBoxFlat = preload("res://resources/button_hover.tres")
const BUTTON_STYLE_PRESSED: StyleBoxFlat = preload("res://resources/button_pressed.tres")
const BUTTON_MIN_HEIGHT: float = 44.0
const BUTTON_FONT_SIZE: int = 16

@onready var _player_currency_label: Label = $ShopPanel/Margin/VBox/PlayerCurrencyLabel
@onready var _backpack_currency_label: Label = $ShopPanel/Margin/VBox/BackpackCurrencyLabel
@onready var _backpack_upgrades: VBoxContainer = $ShopPanel/Margin/VBox/TreesContainer/BackpackTree/BackpackUpgrades
@onready var _player_upgrades: VBoxContainer = $ShopPanel/Margin/VBox/TreesContainer/PlayerTree/PlayerUpgrades


func _ready() -> void:
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.stat_changed.connect(_on_stat_changed)
	for def in MetaProgression.get_stat_defs():
		var container: VBoxContainer = (
			_backpack_upgrades
			if def.currency == StatDef.Currency.BACKPACK
			else _player_upgrades
		)
		_add_upgrade_button(def, container)
	_refresh_currency()


func _add_upgrade_button(def: StatDef, container: VBoxContainer) -> void:
	var button := Button.new()
	button.name = _button_name(def.id)
	button.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_stylebox_override("normal", BUTTON_STYLE_NORMAL)
	button.add_theme_stylebox_override("hover", BUTTON_STYLE_HOVER)
	button.add_theme_stylebox_override("pressed", BUTTON_STYLE_PRESSED)
	button.pressed.connect(_on_upgrade_pressed.bind(def.id))
	container.add_child(button)
	_refresh_button(def)


func _on_upgrade_pressed(id: StringName) -> void:
	MetaProgression.buy_upgrade(id)


func _on_currency_changed() -> void:
	_refresh_currency()
	for def in MetaProgression.get_stat_defs():
		_refresh_button(def)


func _on_stat_changed(stat_id: StringName, _level: int) -> void:
	for def in MetaProgression.get_stat_defs():
		if def.id == stat_id:
			_refresh_button(def)
			return


func _on_start_run_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _refresh_currency() -> void:
	_player_currency_label.text = "Player Currency: %d" % MetaProgression.player_currency
	_backpack_currency_label.text = "Backpack Currency: %d" % MetaProgression.backpack_currency


func _refresh_button(def: StatDef) -> void:
	var container: VBoxContainer = (
		_backpack_upgrades if def.currency == StatDef.Currency.BACKPACK else _player_upgrades
	)
	var button: Button = container.get_node(_button_name(def.id))
	var current_value := _format(MetaProgression.get_stat(def.id), def.decimals)
	var level := MetaProgression.get_level(def.id)
	var is_gated := _is_stat_gated(def.id)

	if is_gated:
		button.text = "%s: %s   (LOCKED)" % [def.display_name, current_value]
		button.disabled = true
		return

	if MetaProgression.is_maxed(def.id):
		button.text = "%s: %s   (MAX, Lvl %d)" % [def.display_name, current_value, level]
		button.disabled = true
		return

	var cost := MetaProgression.get_cost(def.id)
	var currency_name := "Player" if def.currency == StatDef.Currency.PLAYER else "Backpack"
	var available := (
		MetaProgression.player_currency
		if def.currency == StatDef.Currency.PLAYER
		else MetaProgression.backpack_currency
	)
	button.text = (
		"%s: %s   (Lvl %d/%d)   Cost: %d %s"
		% [def.display_name, current_value, level, def.level_cap, cost, currency_name]
	)
	button.disabled = available < cost


func _button_name(id: StringName) -> String:
	return "Upgrade_%s" % id


func _format(value: float, decimals: int) -> String:
	return ("%." + str(decimals) + "f") % value


func _is_stat_gated(stat_id: StringName) -> bool:
	# Compacting tiers are gated by previous tier (not yet implemented).
	# Purge is gated by Rare Compactor (not yet implemented).
	# All other stats are ungated.
	return false
