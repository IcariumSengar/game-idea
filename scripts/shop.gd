extends Control

const BOUNCE_SCALE: float = 1.15
const PLAYER_ACCENT: Color = Color(0.85, 0.7, 0.35, 1.0)
const BACKPACK_ACCENT: Color = Color(0.35, 0.75, 0.85, 1.0)

var _last_player_currency: int = -1
var _last_backpack_currency: int = -1

@onready var _player_currency_label: Label = $ShopPanel/Margin/VBox/PlayerCurrencyLabel
@onready var _backpack_currency_label: Label = $ShopPanel/Margin/VBox/BackpackCurrencyLabel
@onready var _backpack_tree: SkillTreeView = %BackpackTreeView
@onready var _player_tree: SkillTreeView = %PlayerTreeView
@onready var _backpack_header: Label = %BackpackHeader
@onready var _player_header: Label = %PlayerHeader


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
		backpack_stats,
		MetaProgression.get_level,
		_is_stat_gated,
		_is_locked_by_currency,
		BACKPACK_ACCENT
	)
	_player_tree.set_tree_data(
		player_stats,
		MetaProgression.get_level,
		_is_stat_gated,
		_is_locked_by_currency,
		PLAYER_ACCENT
	)
	_backpack_header.text = "BACKPACK TREE\n%d levels bought" % _total_levels(backpack_stats)
	_player_header.text = "PLAYER TREE\n%d levels bought" % _total_levels(player_stats)

	# Disconnect old signals to avoid duplicates
	if _backpack_tree.node_clicked.is_connected(_on_backpack_node_clicked):
		_backpack_tree.node_clicked.disconnect(_on_backpack_node_clicked)
	if _player_tree.node_clicked.is_connected(_on_player_node_clicked):
		_player_tree.node_clicked.disconnect(_on_player_node_clicked)

	_backpack_tree.node_clicked.connect(_on_backpack_node_clicked)
	_player_tree.node_clicked.connect(_on_player_node_clicked)


func _total_levels(stats: Array[StatDef]) -> int:
	var total := 0
	for def in stats:
		total += MetaProgression.get_level(def.id)
	return total


func _on_backpack_node_clicked(stat_id: StringName) -> void:
	if MetaProgression.buy_upgrade(stat_id):
		_backpack_tree.pulse(stat_id)
		AudioManager.play("purchase")


func _on_player_node_clicked(stat_id: StringName) -> void:
	if MetaProgression.buy_upgrade(stat_id):
		_player_tree.pulse(stat_id)
		AudioManager.play("purchase")


func _on_currency_changed() -> void:
	_refresh_currency()
	_update_trees()


func _on_stat_changed(_stat_id: StringName, _level: int) -> void:
	_update_trees()


func _on_start_run_button_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/arena.tscn")


func _refresh_currency() -> void:
	_player_currency_label.text = "Player Currency: %d" % MetaProgression.player_currency
	_backpack_currency_label.text = "Backpack Currency: %d" % MetaProgression.backpack_currency

	if _last_player_currency != -1 and MetaProgression.player_currency != _last_player_currency:
		_bounce_label(_player_currency_label)
	if (
		_last_backpack_currency != -1
		and MetaProgression.backpack_currency != _last_backpack_currency
	):
		_bounce_label(_backpack_currency_label)
	_last_player_currency = MetaProgression.player_currency
	_last_backpack_currency = MetaProgression.backpack_currency


func _bounce_label(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	var tween := create_tween()
	(
		tween
		. tween_property(label, "scale", Vector2.ONE * BOUNCE_SCALE, 0.08)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)


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


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/run_prep.tscn")
