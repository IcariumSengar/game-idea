extends Control

const BOUNCE_SCALE: float = 1.15
const PLAYER_ACCENT: Color = Palette.COVE_PLAYER_ACCENT
const SPELL_ACCENT: Color = Palette.COVE_SPELL_ACCENT
const BACKPACK_ACCENT: Color = Palette.COVE_BACKPACK_ACCENT
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
	MetaProgression.SPELL_INFERNO_BLADE: "The Undertow",
	MetaProgression.SPELL_FROST_NOVA: "Deep Chill",
	MetaProgression.SPELL_METEOR_STRIKE: "Trench Collapse",
	MetaProgression.SPELL_LIGHTNING_CHAIN: "Eel Current",
	MetaProgression.SPELL_TIME_WARP: "Crushing Depths",
	MetaProgression.SPELL_TELEPORT_PULSE: "Ink Jet",
	MetaProgression.SPELL_SUMMON_FAMILIAR: "Anglerling",
}
## Sanctum UX (DESIGN.md 2026-08-17), point 4: steps the purchase tone's
## pitch with the node's post-purchase level, so level 1 and a maxed
## level 20 no longer sound identical. Capped well short of "chipmunk" --
## the highest realistic level cap (Bearing/Gleam, 10-15) still lands
## under 1.8x.
const PURCHASE_PITCH_STEP: float = 0.04
const PURCHASE_PITCH_MAX: float = 1.8
## Gamepad/keyboard tab cycling: works from anywhere regardless of what has
## GUI focus (a tab button, or deep inside a tree's own node navigation),
## unlike ui_left/ui_right which only move focus within whatever row is
## currently focused. Matches TAB_ORDER below.
const TAB_ORDER: Array[StringName] = [&"player", &"spell", &"backpack"]
## Facets (DESIGN.md's "Facets," 2026-08-17): Hades' Mirror toggle,
## free/no-cost, so this is plain descriptive tooltip text rather than
## a cost/level readout like the tree nodes' own tooltips.
const FACET_FACE_A_DESC: Dictionary = {
	MetaProgression.STAT_MOVE_SPEED: "Face A: full Move Speed per level (current).",
	MetaProgression.STAT_PICKUP_RANGE: "Face A: full pickup range per level (current).",
}
const FACET_FACE_B_DESC: Dictionary = {
	MetaProgression.STAT_MOVE_SPEED:
	"Face B: reduced Move Speed per level, trades the rest for a shorter Dash cooldown.",
	MetaProgression.STAT_PICKUP_RANGE:
	"Face B: reduced pickup range per level, trades the rest for bonus Cast Off damage.",
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
@onready var _bearing_preview_grid: BackpackGrid = %BearingPreviewGrid
@onready var _facets_section: VBoxContainer = %FacetsSection


func _ready() -> void:
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.stat_changed.connect(_on_stat_changed)
	_player_tab.accent_color = PLAYER_ACCENT
	_spell_tab.accent_color = SPELL_ACCENT
	_backpack_tab.accent_color = BACKPACK_ACCENT
	_player_tab.pressed.connect(_set_active_tab.bind(&"player"))
	_spell_tab.pressed.connect(_set_active_tab.bind(&"spell"))
	_backpack_tab.pressed.connect(_set_active_tab.bind(&"backpack"))
	_backpack_tree.node_hovered.connect(_on_backpack_node_hovered)
	_update_trees()
	_refresh_currency()
	_show_newly_affordable_shimmer()
	_set_active_tab(_active_tab)
	_focus_active_tab()


## Left/right shoulder (or Q/E) always cycles tabs, independent of whatever
## currently has GUI focus -- the reliable way back to the tab row once
## focus is deep inside a tree's own node navigation (_gui_input there
## consumes ui_left/ui_right for moving between nodes, not switching tabs).
func _unhandled_input(event: InputEvent) -> void:
	var direction: int = 0
	var joy_event := event as InputEventJoypadButton
	if joy_event != null and joy_event.pressed:
		if joy_event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			direction = -1
		elif joy_event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			direction = 1
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.physical_keycode == KEY_Q:
			direction = -1
		elif key_event.physical_keycode == KEY_E:
			direction = 1
	if direction != 0:
		_cycle_tab(direction)
		get_viewport().set_input_as_handled()


func _cycle_tab(direction: int) -> void:
	var index: int = wrapi(TAB_ORDER.find(_active_tab) + direction, 0, TAB_ORDER.size())
	_set_active_tab(TAB_ORDER[index])
	_focus_active_tab()


func _focus_active_tab() -> void:
	match _active_tab:
		&"player":
			_player_tab.grab_focus()
		&"spell":
			_spell_tab.grab_focus()
		&"backpack":
			_backpack_tab.grab_focus()


## Sanctum UX point 1: a node that crossed into affordable since the shop
## was last closed gets a one-off shimmer -- a "welcome back" cue, not a
## live effect, so this runs once here rather than being folded into
## _update_trees()'s per-call logic (which would also fire it on every
## in-session currency change, e.g. right after buying something else).
func _show_newly_affordable_shimmer() -> void:
	for def: StatDef in MetaProgression.get_stat_defs():
		if MetaProgression.is_maxed(def.id) or _is_stat_gated(def.id):
			continue
		var cost: int = MetaProgression.get_cost(def.id)
		var current: int = (
			MetaProgression.player_currency
			if def.currency == StatDef.Currency.PLAYER
			else MetaProgression.backpack_currency
		)
		var previous: int = (
			MetaProgression.last_shop_close_player_currency
			if def.currency == StatDef.Currency.PLAYER
			else MetaProgression.last_shop_close_backpack_currency
		)
		if current >= cost and previous < cost:
			_tree_for_stat(def.id).pulse(def.id)


func _tree_for_stat(stat_id: StringName) -> SkillTreeView:
	if stat_id in PLAYER_TREE_STAT_IDS:
		return _player_tree
	var def := MetaProgression.get_stat_def(stat_id)
	if def != null and def.currency == StatDef.Currency.BACKPACK:
		return _backpack_tree
	return _spell_tree


## Sanctum UX point 5: hovering Bearing ghost-previews the slot it would
## add, reusing the exact ghost-slot concept already built for the in-run
## HUD (backpack_grid.gd) -- this is a separate instance embedded here
## rather than an existing one carried over, since the in-run one lives in
## arena.tscn's HUD, a different scene. Gleam/Discard previews are real,
## separable follow-on scope per the spec, not built here.
func _on_backpack_node_hovered(stat_id: StringName) -> void:
	_bearing_preview_grid.visible = stat_id == MetaProgression.STAT_BACKPACK_CAPACITY
	if _bearing_preview_grid.visible:
		var capacity: int = int(MetaProgression.get_stat(MetaProgression.STAT_BACKPACK_CAPACITY))
		_bearing_preview_grid.update_preview(capacity)


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
		BACKPACK_ACCENT,
		MetaProgression.backpack_currency,
		SkillTreeLayout.TreeKind.BACKPACK
	)
	_player_tree.set_tree_data(
		player_stats,
		MetaProgression.get_level,
		_is_stat_gated,
		_is_locked_by_currency,
		PLAYER_ACCENT,
		MetaProgression.player_currency,
		SkillTreeLayout.TreeKind.PLAYER
	)
	_spell_tree.set_tree_data(
		spell_stats,
		MetaProgression.get_level,
		_is_stat_gated,
		_is_locked_by_currency,
		SPELL_ACCENT,
		MetaProgression.player_currency,
		SkillTreeLayout.TreeKind.SPELL
	)
	_backpack_header.text = "DEPTH TREE\n%d levels bought" % _total_levels(backpack_stats)
	_player_header.text = "GLOW TREE\n%d levels bought" % _total_levels(player_stats)
	_spell_header.text = "SPELL TREE\n%d levels bought" % _total_levels(spell_stats)

	# Sanctum UX point 3: a per-tab "N affordable" count so a player can
	# tell which tab is worth entering before entering it -- freed up by
	# the level pip row moving onto the node itself as an arc.
	_player_tab.text = _tab_label("PLAYER", player_stats)
	_spell_tab.text = _tab_label("SPELLS", spell_stats)
	_backpack_tab.text = _tab_label("BACKPACK", backpack_stats)

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

	_update_facets_section()


## Facets (DESIGN.md's "Facets," 2026-08-17): rebuilt on every tree
## refresh, same reactive-rebuild pattern set_tree_data() already uses --
## cheap at two rows, and avoids stale button state after a facet toggle
## (which itself fires stat_changed, routing back through this same
## _update_trees() call, see _on_facet_button_pressed()).
func _update_facets_section() -> void:
	for child in _facets_section.get_children():
		child.queue_free()
	for stat_id: StringName in MetaProgression.FACET_STATS:
		_facets_section.add_child(_build_facet_row(stat_id))


func _build_facet_row(stat_id: StringName) -> HBoxContainer:
	var def := MetaProgression.get_stat_def(stat_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = def.display_name if def != null else String(stat_id)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var is_face_b := MetaProgression.is_facet_b_active(stat_id)

	var face_a := TabButton.new()
	face_a.text = "Face A"
	face_a.accent_color = PLAYER_ACCENT
	face_a.tooltip_text = FACET_FACE_A_DESC.get(stat_id, "")
	face_a.set_active(not is_face_b)
	face_a.pressed.connect(_on_facet_button_pressed.bind(stat_id, false))
	row.add_child(face_a)

	var face_b := TabButton.new()
	face_b.text = "Face B"
	face_b.accent_color = PLAYER_ACCENT
	face_b.tooltip_text = FACET_FACE_B_DESC.get(stat_id, "")
	face_b.set_active(is_face_b)
	face_b.pressed.connect(_on_facet_button_pressed.bind(stat_id, true))
	row.add_child(face_b)

	return row


## set_facet() already emits stat_changed, which _on_stat_changed() below
## already routes to _update_trees() -- no separate refresh call needed
## here, same as every other stat-mutating click in this file.
func _on_facet_button_pressed(stat_id: StringName, use_face_b: bool) -> void:
	MetaProgression.set_facet(stat_id, use_face_b)


func _tab_label(base_text: String, stats: Array[StatDef]) -> String:
	var affordable := 0
	for def in stats:
		if not MetaProgression.is_maxed(def.id) and not _is_stat_gated(def.id):
			if not _is_locked_by_currency(def.id):
				affordable += 1
	return "%s (%d)" % [base_text, affordable] if affordable > 0 else base_text


func _total_levels(stats: Array[StatDef]) -> int:
	var total := 0
	for def in stats:
		total += MetaProgression.get_level(def.id)
	return total


func _on_backpack_node_clicked(stat_id: StringName) -> void:
	_try_buy(stat_id, _backpack_tree)


func _on_player_node_clicked(stat_id: StringName) -> void:
	_try_buy(stat_id, _player_tree)


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
	if _try_buy(stat_id, _spell_tree) and stat_id == MetaProgression.STAT_SPELL_UNLOCK:
		_show_spell_choice_panel()


## Shared by all three trees' click handlers. Enforces gating -- a real
## bug this Sanctum UX pass surfaced, not a cosmetic gap:
## MetaProgression.buy_upgrade() itself has no gating check at all, so a
## click on a visually-locked node went through anyway if the player could
## afford it, bypassing the intended unlock order entirely. Also gives
## every denied click real feedback (shake + reason) instead of doing
## nothing, per Sanctum UX point 4. Returns whether the purchase actually
## went through, so callers (Spell Choice) can layer a follow-up only when
## it did.
func _try_buy(stat_id: StringName, tree: SkillTreeView) -> bool:
	if _is_stat_gated(stat_id):
		tree.flash_denied(stat_id, "LOCKED")
		return false
	if _is_locked_by_currency(stat_id):
		var def := MetaProgression.get_stat_def(stat_id)
		var cost := MetaProgression.get_cost(stat_id)
		var owned: int = (
			MetaProgression.player_currency
			if def.currency == StatDef.Currency.PLAYER
			else MetaProgression.backpack_currency
		)
		tree.flash_denied(stat_id, "-%d" % (cost - owned))
		return false
	if not MetaProgression.buy_upgrade(stat_id):
		return false
	var pitch: float = minf(
		1.0 + float(MetaProgression.get_level(stat_id)) * PURCHASE_PITCH_STEP, PURCHASE_PITCH_MAX
	)
	tree.pulse(stat_id)
	AudioManager.play("purchase", 0.0, 0.0, pitch)
	return true


func _show_spell_choice_panel() -> void:
	var level := MetaProgression.pending_spell_choice_level()
	if level == 0:
		_spell_choice_panel.hide()
		return
	for child in _spell_choice_option_row.get_children():
		child.queue_free()
	var offer: Array[StringName] = MetaProgression.get_spell_choice_offer(level)
	# Tracked by reference, not get_child(0) after the loop -- queue_free()
	# above doesn't remove the old buttons until end of frame, so the
	# children array would still contain them alongside the new ones.
	var first_button: Button = null
	for spell_id: StringName in offer:
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 60)
		button.text = SPELL_DISPLAY_NAMES.get(spell_id, String(spell_id))
		button.pressed.connect(_on_spell_choice_picked.bind(spell_id))
		_spell_choice_option_row.add_child(button)
		if first_button == null:
			first_button = button
	_spell_choice_panel.show()
	if first_button != null:
		first_button.grab_focus()


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
	_save_shop_close_snapshot()
	SceneTransition.goto_scene("res://scenes/arena.tscn")


## Sanctum UX point 1: snapshots currency on the way out so the *next*
## shop visit can tell which nodes crossed into affordable while away
## (see _show_newly_affordable_shimmer()).
func _save_shop_close_snapshot() -> void:
	MetaProgression.last_shop_close_player_currency = MetaProgression.player_currency
	MetaProgression.last_shop_close_backpack_currency = MetaProgression.backpack_currency


func _refresh_currency() -> void:
	_player_currency_label.text = "Glow: %d" % MetaProgression.player_currency
	_backpack_currency_label.text = "Depth: %d" % MetaProgression.backpack_currency

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
		# The Forge extends the Backpack Tree chain past Discard (DESIGN.md's
		# "The Forge," 2026-08-17) -- same "previous node bought once" gate
		# pattern as everything else in the shop.
		MetaProgression.STAT_FORGE: [MetaProgression.STAT_PURGE, 1],
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
	_save_shop_close_snapshot()
	SceneTransition.goto_scene("res://scenes/ui/run_prep.tscn")
