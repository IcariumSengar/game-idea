extends Control

const BOUNCE_SCALE: float = 1.15
const PLAYER_ACCENT: Color = Color(0.85, 0.7, 0.35, 1.0)
const BACKPACK_ACCENT: Color = Color(0.35, 0.75, 0.85, 1.0)

var _last_player_currency: int = -1
var _last_backpack_currency: int = -1
var _active_tab: StringName = &"player"

@onready var _player_currency_label: Label = $ShopPanel/Margin/VBox/PlayerCurrencyLabel
@onready var _backpack_currency_label: Label = $ShopPanel/Margin/VBox/BackpackCurrencyLabel
@onready var _backpack_tree: SkillTreeView = %BackpackTreeView
@onready var _player_tree: SkillTreeView = %PlayerTreeView
@onready var _backpack_header: Label = %BackpackHeader
@onready var _player_header: Label = %PlayerHeader
@onready var _player_tab: TabButton = %PlayerTabButton
@onready var _backpack_tab: TabButton = %BackpackTabButton
@onready var _player_scroll: ScrollContainer = %PlayerScroll
@onready var _backpack_scroll: ScrollContainer = %BackpackScroll
@onready var _spell_status_labels: Dictionary = {
	MetaProgression.SPELL_ARCANE_BOLT: %ArcaneBoltStatusLabel,
	MetaProgression.SPELL_INFERNO_BLADE: %InfernoBladeStatusLabel,
	MetaProgression.SPELL_FROST_NOVA: %FrostNovaStatusLabel,
	MetaProgression.SPELL_METEOR_STRIKE: %MeteorStrikeStatusLabel,
	MetaProgression.SPELL_LIGHTNING_CHAIN: %LightningChainStatusLabel,
	MetaProgression.SPELL_TIME_WARP: %TimeWarpStatusLabel,
	MetaProgression.SPELL_TELEPORT_PULSE: %TeleportPulseStatusLabel,
	MetaProgression.SPELL_SUMMON_FAMILIAR: %SummonFamiliarStatusLabel,
}
@onready var _spell_display_names: Dictionary = {
	MetaProgression.SPELL_ARCANE_BOLT: "Arcane Bolt",
	MetaProgression.SPELL_INFERNO_BLADE: "Inferno Blade",
	MetaProgression.SPELL_FROST_NOVA: "Frost Nova",
	MetaProgression.SPELL_METEOR_STRIKE: "Meteor Strike",
	MetaProgression.SPELL_LIGHTNING_CHAIN: "Lightning Chain",
	MetaProgression.SPELL_TIME_WARP: "Time Warp",
	MetaProgression.SPELL_TELEPORT_PULSE: "Teleport Pulse",
	MetaProgression.SPELL_SUMMON_FAMILIAR: "Summon Familiar",
}


func _ready() -> void:
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.stat_changed.connect(_on_stat_changed)
	_player_tab.pressed.connect(_set_active_tab.bind(&"player"))
	_backpack_tab.pressed.connect(_set_active_tab.bind(&"backpack"))
	_update_trees()
	_refresh_currency()
	_update_spell_status()
	_set_active_tab(_active_tab)


## Only one tree is visible at a time -- both used to sit side by side, but
## with the Player tree now spanning 17 stats across 8 spells (v11), showing
## both trees at once got too cluttered. Each tab gets the full panel width
## instead of half.
func _set_active_tab(tab: StringName) -> void:
	_active_tab = tab
	var player_active: bool = tab == &"player"
	_player_scroll.visible = player_active
	_backpack_scroll.visible = not player_active
	_player_tab.set_active(player_active)
	_backpack_tab.set_active(not player_active)


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
	_backpack_header.text = "STARDUST TREE\n%d levels bought" % _total_levels(backpack_stats)
	_player_header.text = "ESSENCE TREE\n%d levels bought" % _total_levels(player_stats)

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
	_update_spell_status()


## v10: every unlocked spell casts simultaneously, so this panel is just a
## status readout (what's currently firing) rather than a switcher.
func _update_spell_status() -> void:
	for spell_id: StringName in _spell_status_labels:
		var label: Label = _spell_status_labels[spell_id]
		var display_name: String = _spell_display_names[spell_id]
		var unlocked: bool = MetaProgression.is_spell_unlocked(spell_id)
		label.text = display_name if unlocked else "%s (Locked)" % display_name
		label.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.5)


func _on_start_run_button_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/arena.tscn")


func _refresh_currency() -> void:
	_player_currency_label.text = "Essence: %d" % MetaProgression.player_currency
	_backpack_currency_label.text = "Stardust: %d" % MetaProgression.backpack_currency

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


## stat_id -> [prerequisite stat_id, minimum level required in it]. Inferno
## Blade's upgrades need Spell Unlock L1 (where Inferno itself unlocks),
## Frost Nova's need L2 -- upgrading a spell you don't have yet doesn't
## make sense.
func _gate_requirements() -> Dictionary:
	return {
		# Was gated behind Compacting's Rare Vault node before its removal
		# (DESIGN.md 2026-08-16) -- re-pointed to Bearing's first level so
		# Backpack Tree keeps some gating structure instead of going flat.
		MetaProgression.STAT_PURGE: [MetaProgression.STAT_BACKPACK_CAPACITY, 1],
		MetaProgression.STAT_INFERNO_FURY: [MetaProgression.STAT_SPELL_UNLOCK, 1],
		MetaProgression.STAT_INFERNO_ARC_WIDTH: [MetaProgression.STAT_SPELL_UNLOCK, 1],
		MetaProgression.STAT_INFERNO_BURN_DAMAGE: [MetaProgression.STAT_SPELL_UNLOCK, 1],
		MetaProgression.STAT_FROST_FREQUENCY: [MetaProgression.STAT_SPELL_UNLOCK, 2],
		MetaProgression.STAT_FROST_RADIUS: [MetaProgression.STAT_SPELL_UNLOCK, 2],
		MetaProgression.STAT_FROST_SLOW_STRENGTH: [MetaProgression.STAT_SPELL_UNLOCK, 2],
		MetaProgression.STAT_METEOR_FREQUENCY: [MetaProgression.STAT_SPELL_UNLOCK, 3],
		MetaProgression.STAT_LIGHTNING_FREQUENCY: [MetaProgression.STAT_SPELL_UNLOCK, 4],
		MetaProgression.STAT_TIME_WARP_FREQUENCY: [MetaProgression.STAT_SPELL_UNLOCK, 5],
		MetaProgression.STAT_TELEPORT_FREQUENCY: [MetaProgression.STAT_SPELL_UNLOCK, 6],
		MetaProgression.STAT_FAMILIAR_DURATION: [MetaProgression.STAT_SPELL_UNLOCK, 7],
	}


func _is_stat_gated(stat_id: StringName) -> bool:
	var requirements: Dictionary = _gate_requirements()
	if not requirements.has(stat_id):
		return false
	var requirement: Array = requirements[stat_id]
	return MetaProgression.get_level(requirement[0]) < int(requirement[1])


func _is_locked_by_currency(stat_id: StringName) -> bool:
	var def := MetaProgression.get_stat_def(stat_id)
	if def == null or MetaProgression.is_maxed(stat_id):
		return false
	var cost := MetaProgression.get_cost(stat_id)
	match def.currency:
		StatDef.Currency.PLAYER:
			return MetaProgression.player_currency < cost
		StatDef.Currency.BACKPACK:
			return MetaProgression.backpack_currency < cost
	return false


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/run_prep.tscn")
