extends Control

@onready var _player_currency_label: Label = $ShopPanel/Margin/VBox/PlayerCurrencyLabel
@onready var _backpack_currency_label: Label = $ShopPanel/Margin/VBox/BackpackCurrencyLabel
@onready var _backpack_tree: Control = $ShopPanel/Margin/VBox/TreesContainer/BackpackTreeView
@onready var _player_tree: Control = $ShopPanel/Margin/VBox/TreesContainer/PlayerTreeView


func _ready() -> void:
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.stat_changed.connect(_on_stat_changed)
	_update_trees()
	_refresh_currency()


func _update_trees() -> void:
	var backpack_stats: Array[StatDef] = []
	var player_stats: Array[StatDef] = []

	for def in MetaProgression.get_stat_defs():
		if def.currency == StatDef.Currency.BACKPACK:
			backpack_stats.append(def)
		else:
			player_stats.append(def)

	_backpack_tree.set_tree_data(
		backpack_stats, MetaProgression.get_level, _is_stat_gated, _is_locked_by_currency
	)
	_player_tree.set_tree_data(player_stats, MetaProgression.get_level, _is_stat_gated, _is_locked_by_currency)

	# Disconnect old signals to avoid duplicates
	if _backpack_tree.node_clicked.is_connected(_on_backpack_node_clicked):
		_backpack_tree.node_clicked.disconnect(_on_backpack_node_clicked)
	if _player_tree.node_clicked.is_connected(_on_player_node_clicked):
		_player_tree.node_clicked.disconnect(_on_player_node_clicked)

	_backpack_tree.node_clicked.connect(_on_backpack_node_clicked)
	_player_tree.node_clicked.connect(_on_player_node_clicked)


func _on_backpack_node_clicked(stat_id: StringName) -> void:
	MetaProgression.buy_upgrade(stat_id)


func _on_player_node_clicked(stat_id: StringName) -> void:
	MetaProgression.buy_upgrade(stat_id)


func _on_currency_changed() -> void:
	_refresh_currency()
	_update_trees()


func _on_stat_changed(_stat_id: StringName, _level: int) -> void:
	_update_trees()


func _on_start_run_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _refresh_currency() -> void:
	_player_currency_label.text = "Player Currency: %d" % MetaProgression.player_currency
	_backpack_currency_label.text = "Backpack Currency: %d" % MetaProgression.backpack_currency


func _is_stat_gated(stat_id: StringName) -> bool:
	match stat_id:
		MetaProgression.STAT_COMPACTOR_UNCOMMON:
			return MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_COMMON) < 1
		MetaProgression.STAT_COMPACTOR_RARE:
			return MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_UNCOMMON) < 1
		MetaProgression.STAT_COMPACTOR_EPIC:
			return MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_RARE) < 1
		MetaProgression.STAT_COMPACTOR_MYTHIC:
			return MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_EPIC) < 1
		MetaProgression.STAT_PURGE:
			return MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_RARE) < 1
	return false


func _is_locked_by_currency(stat_id: StringName) -> bool:
	var def := _find_def(stat_id)
	if def == null or MetaProgression.is_maxed(stat_id):
		return false
	var cost := MetaProgression.get_cost(stat_id)
	match def.currency:
		StatDef.Currency.PLAYER:
			return MetaProgression.player_currency < cost
		StatDef.Currency.BACKPACK:
			return MetaProgression.backpack_currency < cost
	return false


func _find_def(stat_id: StringName) -> StatDef:
	for def in MetaProgression.get_stat_defs():
		if def.id == stat_id:
			return def
	return null
