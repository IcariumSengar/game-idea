extends Control

const BOUNCE_SCALE: float = 1.15
const PLAYER_ACCENT: Color = Color(0.85, 0.7, 0.35, 1.0)
const SPELL_ACCENT: Color = Color(0.65, 0.45, 0.85, 1.0)
const BACKPACK_ACCENT: Color = Color(0.35, 0.75, 0.85, 1.0)
## Shop structure rework (DESIGN.md 2026-08-17): Player Tree stays flat and
## small on purpose -- Spellpower/Swiftness/Gleam, no cross-gating -- with
## everything spell-related (Spell Unlock plus every per-spell upgrade
## stat) split out into its own Spell Tree tab instead. Explicit allowlist
## rather than "everything not backpack-currency," so a future non-spell
## Player-currency stat doesn't silently land in the wrong tree by default.
const PLAYER_TREE_STAT_IDS: Array[StringName] = [
	MetaProgression.STAT_DAMAGE, MetaProgression.STAT_MOVE_SPEED, MetaProgression.STAT_PICKUP_RANGE
]
## Spell Choice (DESIGN.md 2026-08-17): short display names for the choice
## panel's option buttons. Grimoire.SPELLS already has fuller name+desc
## pairs, but only for UI-string purposes local to that screen -- this is
## a small, deliberate duplication rather than exposing Grimoire's
## anonymous-Dictionary data as a cross-script API for one caller.
const SPELL_DISPLAY_NAMES: Dictionary = {
	MetaProgression.SPELL_INFERNO_BLADE: "Inferno Blade",
	MetaProgression.SPELL_FROST_NOVA: "Frost Nova",
	MetaProgression.SPELL_METEOR_STRIKE: "Meteor Strike",
	MetaProgression.SPELL_LIGHTNING_CHAIN: "Lightning Chain",
	MetaProgression.SPELL_TIME_WARP: "Time Warp",
	MetaProgression.SPELL_TELEPORT_PULSE: "Teleport Pulse",
	MetaProgression.SPELL_SUMMON_FAMILIAR: "Summon Familiar",
}

var _last_player_currency: int = -1
var _last_backpack_currency: int = -1
var _active_tab: StringName = &"player"

@onready var _player_currency_label: Label = $ShopPanel/Margin/VBox/PlayerCurrencyLabel
@onready var _backpack_currency_label: Label = $ShopPanel/Margin/VBox/BackpackCurrencyLabel
@onready var _backpack_tree: SkillTreeView = %BackpackTreeView
@onready var _player_tree: SkillTreeView = %PlayerTreeView
@onready var _spell_tree: SkillTreeView = %SpellTreeView
@onready var _backpack_header: Label = %BackpackHeader
@onready var _player_header: Label = %PlayerHeader
@onready var _spell_header: Label = %SpellHeader
@onready var _player_tab: TabButton = %PlayerTabButton
@onready var _spell_tab: TabButton = %SpellTabButton
@onready var _backpack_tab: TabButton = %BackpackTabButton
@onready var _player_scroll: ScrollContainer = %PlayerScroll
@onready var _spell_scroll: ScrollContainer = %SpellScroll
@onready var _backpack_scroll: ScrollContainer = %BackpackScroll
@onready var _spell_choice_panel: PanelContainer = %SpellChoicePanel
@onready var _spell_choice_option_row: HBoxContainer = %OptionRow


func _ready() -> void:
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.stat_changed.connect(_on_stat_changed)
	_player_tab.pressed.connect(_set_active_tab.bind(&"player"))
	_spell_tab.pressed.connect(_set_active_tab.bind(&"spell"))
	_backpack_tab.pressed.connect(_set_active_tab.bind(&"backpack"))
	_update_trees()
	_refresh_currency()
	_set_active_tab(_active_tab)


## Only one tree is visible at a time -- all three used to be considered
## for side-by-side display, but Spell Tree alone runs to 14 nodes across
## 8 spells, so showing more than one at once doesn't fit. Each tab gets
## the full panel width instead of a fraction of it.
func _set_active_tab(tab: StringName) -> void:
	_active_tab = tab
	_player_scroll.visible = tab == &"player"
	_spell_scroll.visible = tab == &"spell"
	_backpack_scroll.visible = tab == &"backpack"
	_player_tab.set_active(tab == &"player")
	_spell_tab.set_active(tab == &"spell")
	_backpack_tab.set_active(tab == &"backpack")
	if tab == &"spell" and MetaProgression.has_pending_spell_choice():
		_show_spell_choice_panel()
	else:
		_spell_choice_panel.hide()


func _update_trees() -> void:
	var backpack_stats: Array[StatDef] = []
	var player_stats: Array[StatDef] = []
	var spell_stats: Array[StatDef] = []

	for def in MetaProgression.get_stat_defs():
		if def.currency == StatDef.Currency.BACKPACK:
			backpack_stats.append(def)
		elif def.id in PLAYER_TREE_STAT_IDS:
			player_stats.append(def)
		else:
			spell_stats.append(def)

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
	_spell_tree.set_tree_data(
		spell_stats, MetaProgression.get_level, _is_stat_gated, _is_locked_by_currency, SPELL_ACCENT
	)
	_backpack_header.text = "STARDUST TREE\n%d levels bought" % _total_levels(backpack_stats)
	_player_header.text = "ESSENCE TREE\n%d levels bought" % _total_levels(player_stats)
	_spell_header.text = "SPELL TREE\n%d levels bought" % _total_levels(spell_stats)

	# Disconnect old signals to avoid duplicates
	if _backpack_tree.node_clicked.is_connected(_on_backpack_node_clicked):
		_backpack_tree.node_clicked.disconnect(_on_backpack_node_clicked)
	if _player_tree.node_clicked.is_connected(_on_player_node_clicked):
		_player_tree.node_clicked.disconnect(_on_player_node_clicked)
	if _spell_tree.node_clicked.is_connected(_on_spell_node_clicked):
		_spell_tree.node_clicked.disconnect(_on_spell_node_clicked)

	_backpack_tree.node_clicked.connect(_on_backpack_node_clicked)
	_player_tree.node_clicked.connect(_on_player_node_clicked)
	_spell_tree.node_clicked.connect(_on_spell_node_clicked)


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


## Spell Choice (DESIGN.md 2026-08-17): buying Spell Unlock is now a
## two-step flow -- the click above still spends currency and grows the
## trunk immediately (same as every other node), but doesn't grant a
## spell by itself anymore; a follow-up choice does. If a choice is
## already pending, clicking again just re-shows the panel instead of
## buying a level ahead of an unresolved one.
func _on_spell_node_clicked(stat_id: StringName) -> void:
	if stat_id == MetaProgression.STAT_SPELL_UNLOCK and MetaProgression.has_pending_spell_choice():
		_show_spell_choice_panel()
		return
	if MetaProgression.buy_upgrade(stat_id):
		_spell_tree.pulse(stat_id)
		AudioManager.play("purchase")
		if stat_id == MetaProgression.STAT_SPELL_UNLOCK:
			_show_spell_choice_panel()


func _show_spell_choice_panel() -> void:
	var level := MetaProgression.pending_spell_choice_level()
	if level == 0:
		_spell_choice_panel.hide()
		return
	for child in _spell_choice_option_row.get_children():
		child.queue_free()
	var offer: Array[StringName] = MetaProgression.get_spell_choice_offer(level)
	for spell_id: StringName in offer:
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 60)
		button.text = SPELL_DISPLAY_NAMES.get(spell_id, String(spell_id))
		button.pressed.connect(_on_spell_choice_picked.bind(spell_id))
		_spell_choice_option_row.add_child(button)
	_spell_choice_panel.show()


func _on_spell_choice_picked(spell_id: StringName) -> void:
	MetaProgression.choose_spell(spell_id)
	AudioManager.play("purchase")
	_spell_choice_panel.hide()
	_update_trees()


func _on_currency_changed() -> void:
	_refresh_currency()
	_update_trees()


func _on_stat_changed(_stat_id: StringName, _level: int) -> void:
	_update_trees()


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


## stat_id -> [prerequisite stat_id, minimum level required in it]. Arcane
## Bolt's two upgrades are deliberately absent -- Arcane needs no unlock,
## so they stay ungated (see skill_tree_view.gd's parent_of for their
## purely-visual trunk-root branch).
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
