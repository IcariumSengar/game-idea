class_name SkillTreeView
extends Control

## Circular chained skill tree, styled after mobile-RPG skill trees:
## per-branch accent color, glowing filled nodes for purchased tiers,
## dim outlines for locked ones, and a bigger "capstone" node at the end
## of each chain.

signal node_clicked(stat_id: StringName)
## Sanctum UX point 5 (DESIGN.md 2026-08-17): lets shop.gd react to
## hovering a specific node (e.g. Bearing's ghost-slot preview) without
## polling -- fired on every hover change, including to/from "none".
signal node_hovered(stat_id: StringName)

const NODE_RADIUS: float = 24.0
const CAPSTONE_RADIUS: float = 30.0
const PULSE_DECAY_PER_SEC: float = 2.5
const PULSE_SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const LOCKED_BORDER: Color = Palette.SKILL_TREE_LOCKED_BORDER
const LOCKED_FILL: Color = Palette.SKILL_TREE_LOCKED_FILL
const NO_CURRENCY_TINT: Color = Palette.SKILL_TREE_NO_CURRENCY_TINT
const ICON_DIM: Color = Palette.SKILL_TREE_ICON_DIM
const TOOLTIP_GOLD: Color = Palette.SKILL_TREE_TOOLTIP_GOLD
const TOOLTIP_CYAN: Color = Palette.SKILL_TREE_TOOLTIP_CYAN
const STATUS_GREEN: Color = Palette.STATUS_GREEN
const STATUS_RED: Color = Palette.STATUS_RED
const STATUS_MUTED: Color = Palette.STATUS_MUTED
## The Constellation (DESIGN.md 2026-08-18): the shortfall/LOCKED denied-
## click message still uses this tint (see _draw_denied_message()) -- the
## per-node currency-locked border it used to also drive is gone, folded
## into the plain DIM state now (see SkillTreeGlow.State).
## Denied-click shake -- same tween-driven juice technique juicy_button.gd
## uses for its own press feedback, applied to this node's draw offset
## instead of a separate Button's scale, since tree nodes aren't
## individual Button instances here.
const DENIED_SHAKE_DURATION: float = 0.3
const DENIED_SHAKE_MAGNITUDE: float = 6.0
## Shimmer (point 1): a node crossing into affordable since the shop was
## last closed gets a one-off glow -- reuses the exact same _pulse_amount
## mechanism a purchase pulse already uses, just triggered by a different
## cause, so there's one glow language instead of two.
const SHIMMER_PULSE_AMOUNT: float = 0.7
## The Constellation: one shared breathing rhythm for every affordable
## node in the tab at once, not a per-node timer -- see _process() and
## SkillTreeGlow.draw_node_glow()'s breathing_phase param.
const BREATHING_SPEED: float = 1.6
## Hover now eases in/out (scale + ring alpha) instead of snapping,
## mirroring the shake/pulse tween-driven juice this file already uses
## elsewhere rather than adding a new animation technique.
const HOVER_SCALE_BUMP: float = 0.12
const HOVER_LERP_SPEED: float = 10.0
## Keyboard/gamepad node navigation: tree nodes aren't real Controls (see
## the DENIED_SHAKE_DURATION comment above), so ui_up/down/left/right can't
## use Godot's normal focus-neighbor traversal -- _move_selection() instead
## picks the nearest node roughly in the pressed direction from
## _node_positions directly, using these as candidate directions.
const NAV_ACTIONS: Dictionary = {
	&"ui_up": Vector2.UP,
	&"ui_down": Vector2.DOWN,
	&"ui_left": Vector2.LEFT,
	&"ui_right": Vector2.RIGHT
}

const STAT_DESCRIPTIONS: Dictionary = {
	&"damage": "Your spells crackle with arcane power, striking harder.",
	&"move_speed": "Swift feet carry you through the void.",
	&"pickup_range": "Widens your arcane pull and keeps a fuller triage queue processable.",
	&"backpack_capacity": "Stitches an extra pocket into your satchel.",
	&"purge": "Sharpens what you throw away -- boosts Cast Off's damage when you discard a gem.",
}

var _accent_color: Color = Color(0.85, 0.75, 0.5, 1.0)
var _tree_kind: SkillTreeLayout.TreeKind = SkillTreeLayout.TreeKind.SPELL
var _node_positions: Dictionary = {}
## The Constellation: only set for Player Tree's hub-and-spoke layout --
## a virtual, non-purchasable center (the Diver), drawn specially in
## _draw() and never fed through _gui_input()'s node hit-testing since
## it's not in _nodes.
var _hub_position: Vector2 = Vector2.ZERO
var _has_hub: bool = false
var _nodes: Array[TreeNode] = []
var _hovered_node: StringName = StringName()
var _pulse_amount: Dictionary = {}
var _time: float = 0.0
## Sanctum UX point 1: this tree's current currency -- feeds each node's
## affordable/dim state (see _node_state()) and detects which nodes
## crossed into affordable since the shop was last closed (shimmer).
var _current_currency: int = 0
## Denied-click shake offsets (point 4), decaying like _pulse_amount but
## a separate map since a node can be mid-shake independent of pulsing.
var _shake_amount: Dictionary = {}
## The message shown alongside an active shake (shortfall amount, or
## "LOCKED") -- keyed the same as _shake_amount, cleared together.
var _denied_message: Dictionary = {}
## Eases toward 1.0 while a node is hovered, back to 0.0 once it isn't --
## drives both the hover scale bump and the hover ring's fade, see
## HOVER_SCALE_BUMP/HOVER_LERP_SPEED above.
var _hover_amount: Dictionary = {}


class TreeNode:
	var stat_id: StringName
	var def: StatDef
	var level: int
	var is_maxed: bool
	var is_gated: bool
	var is_locked_by_currency: bool
	var children: Array[TreeNode] = []
	var parent: TreeNode = null
	var is_real_gate: bool = false
	var gate_min_level: int = 1


func _ready() -> void:
	custom_minimum_size = Vector2(0, 460)
	mouse_filter = MOUSE_FILTER_STOP
	# Selection is already shown via the per-node hover ring (_hover_amount)
	# -- a whole-control focus rectangle on top of that would just be noise
	# across this much area.
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	set_process(false)
	resized.connect(_on_resized)
	focus_entered.connect(_on_focus_entered)


## Selects the first node the instant the tree gains focus (tab switch,
## or ui_down from the tab row above) rather than waiting for the first
## direction press, so there's always immediate visual feedback.
func _on_focus_entered() -> void:
	if _hovered_node == StringName() and not _nodes.is_empty():
		_select_node(_nodes[0])


## The container layout pass finishes after _ready(), so size.x isn't
## known yet when set_tree_data() first lays out the tree. Once resized
## fires with the real column width, recenter using it.
func _on_resized() -> void:
	if not _nodes.is_empty():
		_calculate_positions()
		queue_redraw()


func pulse(stat_id: StringName) -> void:
	_pulse_amount[stat_id] = 1.0
	set_process(true)
	if stat_id in _node_positions:
		var spark: CPUParticles2D = PULSE_SPARK_SCENE.instantiate()
		spark.position = _node_positions[stat_id]
		spark.color = _accent_color
		spark.amount = 14
		spark.scale_amount_min = 1.2
		spark.scale_amount_max = 2.0
		add_child(spark)
		spark.emitting = true


func _process(delta: float) -> void:
	_time += delta
	var finished: Array[StringName] = []
	for stat_id: StringName in _pulse_amount:
		_pulse_amount[stat_id] = max(_pulse_amount[stat_id] - delta * PULSE_DECAY_PER_SEC, 0.0)
		if _pulse_amount[stat_id] <= 0.0:
			finished.append(stat_id)
	for stat_id in finished:
		_pulse_amount.erase(stat_id)

	var shake_finished: Array[StringName] = []
	var shake_decay_per_sec: float = 1.0 / DENIED_SHAKE_DURATION
	for stat_id: StringName in _shake_amount:
		_shake_amount[stat_id] = max(_shake_amount[stat_id] - delta * shake_decay_per_sec, 0.0)
		if _shake_amount[stat_id] <= 0.0:
			shake_finished.append(stat_id)
	for stat_id in shake_finished:
		_shake_amount.erase(stat_id)
		_denied_message.erase(stat_id)

	var hover_settled: bool = true
	for node in _nodes:
		var target: float = 1.0 if node.stat_id == _hovered_node else 0.0
		var current: float = _hover_amount.get(node.stat_id, 0.0)
		if not is_equal_approx(current, target):
			_hover_amount[node.stat_id] = move_toward(current, target, HOVER_LERP_SPEED * delta)
			hover_settled = false

	# The Constellation: the breathing rhythm has to keep running as long as
	# any node is affordable, not just while something transient (pulse/
	# shake/hover) is settling -- otherwise the "is it breathing" cue that
	# replaces the old currency ring would freeze the instant those finish.
	var has_affordable: bool = false
	for node in _nodes:
		if _node_state(node) == SkillTreeGlow.State.AFFORDABLE:
			has_affordable = true
			break

	if (
		_pulse_amount.is_empty()
		and _shake_amount.is_empty()
		and hover_settled
		and not has_affordable
	):
		set_process(false)
	queue_redraw()


## current_currency (Sanctum UX point 1, DESIGN.md 2026-08-17): feeds each
## node's locked/dim/affordable/maxed state -- every stat in a given tree
## call shares one currency (Player/Spell Tree both spend Glow, Backpack
## Tree spends Depth), so one value per call suffices.
func set_tree_data(
	stats: Array[StatDef],
	level_getter: Callable,
	gating_checker: Callable,
	currency_checker: Callable,
	accent_color: Color,
	current_currency: int,
	tree_kind: SkillTreeLayout.TreeKind
) -> void:
	_accent_color = accent_color
	_current_currency = current_currency
	_tree_kind = tree_kind
	_nodes.clear()
	_node_positions.clear()
	_has_hub = false

	var nodes_by_id: Dictionary = {}

	for def in stats:
		var node := TreeNode.new()
		node.stat_id = def.id
		node.def = def
		node.level = level_getter.call(def.id)
		node.is_maxed = node.level >= def.level_cap
		node.is_gated = gating_checker.call(def.id)
		node.is_locked_by_currency = currency_checker.call(def.id)
		nodes_by_id[def.id] = node
		_nodes.append(node)

	_build_tree_relationships(nodes_by_id)
	_calculate_positions()
	set_process(true)
	queue_redraw()


func _build_tree_relationships(nodes_by_id: Dictionary) -> void:
	var parent_of: Dictionary = {
		# Was chained off Compacting's Rare Vault node before its removal
		# (DESIGN.md 2026-08-16) -- Backpack Tree is now just two nodes,
		# Bearing then Discard.
		MetaProgression.STAT_PURGE: MetaProgression.STAT_BACKPACK_CAPACITY,
		# The Forge extends the chain past Discard (DESIGN.md's "The Forge,"
		# 2026-08-17) -- it's the tree's real capstone now (see
		# meta_progression.gd's is_milestone flag having moved to it).
		MetaProgression.STAT_FORGE: MetaProgression.STAT_PURGE,
		# Arcane needs no unlock, so these branch off the trunk root
		# ungated (DESIGN.md's Shop structure rework, 2026-08-17) -- solid
		# line for the visual "part of this trunk" read, but shop.gd's own
		# gate requirements never list them, so they stay buyable from L0.
		MetaProgression.STAT_ARCANE_HASTE: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_ARCANE_PROJECTILE_SPEED: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_INFERNO_FURY: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_INFERNO_ARC_WIDTH: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_INFERNO_BURN_DAMAGE: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_FROST_FREQUENCY: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_FROST_RADIUS: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_FROST_SLOW_STRENGTH: MetaProgression.STAT_SPELL_UNLOCK,
		# v11 spells (DESIGN.md's Shop structure rework, 2026-08-17): each
		# now gets the same real trunk branch Inferno/Frost already had --
		# previously these five fell through to the generic cosmetic
		# root-chain instead of visually reflecting the gate shop.gd's own
		# _gate_requirements() already enforced functionally.
		MetaProgression.STAT_METEOR_FREQUENCY: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_LIGHTNING_FREQUENCY: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_TIME_WARP_FREQUENCY: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_TELEPORT_FREQUENCY: MetaProgression.STAT_SPELL_UNLOCK,
		MetaProgression.STAT_FAMILIAR_DURATION: MetaProgression.STAT_SPELL_UNLOCK,
	}
	# Each spell's gate level, matching shop.gd's own _gate_requirements()
	# exactly -- shown in the LOCKED tooltip so a rarer spell's gate isn't
	# confused with an earlier one's (all read "Requires: Spell Unlock"
	# otherwise). Arcane's two stats are absent -- ungated, no min level.
	var gate_min_level: Dictionary = {
		MetaProgression.STAT_FROST_FREQUENCY: 2,
		MetaProgression.STAT_FROST_RADIUS: 2,
		MetaProgression.STAT_FROST_SLOW_STRENGTH: 2,
		MetaProgression.STAT_METEOR_FREQUENCY: 3,
		MetaProgression.STAT_LIGHTNING_FREQUENCY: 4,
		MetaProgression.STAT_TIME_WARP_FREQUENCY: 5,
		MetaProgression.STAT_TELEPORT_FREQUENCY: 6,
		MetaProgression.STAT_FAMILIAR_DURATION: 7,
	}

	for child_id: StringName in parent_of:
		var parent_id: StringName = parent_of[child_id]
		if child_id in nodes_by_id and parent_id in nodes_by_id:
			var child: TreeNode = nodes_by_id[child_id]
			var parent: TreeNode = nodes_by_id[parent_id]
			child.parent = parent
			child.is_real_gate = true
			child.gate_min_level = gate_min_level.get(child_id, 1)
			parent.children.append(child)


## The Constellation (DESIGN.md 2026-08-18): per-tree-shape placement --
## radial arc for Spell Tree, hub-and-spoke for Player Tree, tight cluster
## for Backpack Tree -- lives in skill_tree_layout.gd now, pure geometry
## with no CanvasItem dependency. size.x/y aren't known yet on the first
## call (before the container layout pass runs); SkillTreeLayout falls
## back to a fixed anchor until _on_resized() fires and recenters using
## the real column size.
func _calculate_positions() -> void:
	var positions: Dictionary = SkillTreeLayout.calculate_positions(_nodes, _tree_kind, size)
	_has_hub = positions.has(SkillTreeLayout.HUB_KEY)
	if _has_hub:
		_hub_position = positions[SkillTreeLayout.HUB_KEY]
		positions.erase(SkillTreeLayout.HUB_KEY)
	_node_positions = positions


## Sanctum UX point 2 (DESIGN.md 2026-08-17): asserted via StatDef.is_milestone,
## not inferred from "has no children" -- that inference drew flat leaf
## stats larger than real capstones like Spell Unlock, an accident of tree
## topology rather than a design choice.
func _get_node_radius(node: TreeNode) -> float:
	return CAPSTONE_RADIUS if node.def.is_milestone else NODE_RADIUS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		for node in _nodes:
			if pos.distance_to(_node_positions[node.stat_id]) <= _get_node_radius(node):
				node_clicked.emit(node.stat_id)
				get_tree().root.set_input_as_handled()
				return
	elif event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		var hovered: TreeNode = null
		for node in _nodes:
			if pos.distance_to(_node_positions[node.stat_id]) <= _get_node_radius(node):
				hovered = node
				break
		if hovered != null:
			if hovered.stat_id != _hovered_node:
				_select_node(hovered)
		elif _hovered_node != StringName():
			_clear_selection()
	elif event.is_action_pressed(&"ui_accept"):
		if _hovered_node != StringName():
			node_clicked.emit(_hovered_node)
		get_tree().root.set_input_as_handled()
	else:
		for action_name: StringName in NAV_ACTIONS:
			if event.is_action_pressed(action_name):
				# Only consumed when a move actually happens -- at the tree's
				# edges (topmost node pressing up, say) this falls through to
				# Godot's normal focus-neighbor traversal instead, so ui_up
				# escapes to the tab row above and ui_down escapes to Start
				# Run/Back below, with no explicit wiring needed for either.
				if _move_selection(NAV_ACTIONS[action_name]):
					get_tree().root.set_input_as_handled()
				return


## Shared by mouse hover and keyboard/gamepad selection -- both are "this
## node is the active one" and drive the identical ring/tooltip feedback,
## so they share one code path instead of two parallel state machines.
func _select_node(node: TreeNode) -> void:
	_hovered_node = node.stat_id
	tooltip_text = _build_tooltip_text(node)
	node_hovered.emit(_hovered_node)
	set_process(true)
	queue_redraw()


func _clear_selection() -> void:
	_hovered_node = StringName()
	tooltip_text = ""
	node_hovered.emit(_hovered_node)
	set_process(true)
	queue_redraw()


## Picks the nearest node roughly in `dir` from the current selection
## (dot product against the direction, penalizing off-axis candidates by
## dividing distance by alignment) rather than walking parent/child/sibling
## links -- root-level nodes are separate stacked chains, not a left-right
## row (see _calculate_positions()), so tree-structural "sibling" doesn't
## match what's visually beside a node. Falls back to the first node when
## nothing is selected yet (e.g. the very first press after gaining focus,
## if _on_focus_entered() hasn't already picked one).
func _move_selection(dir: Vector2) -> bool:
	if _nodes.is_empty():
		return false
	var current: TreeNode = _find_node(_hovered_node)
	if current == null:
		_select_node(_nodes[0])
		return true
	var from: Vector2 = _node_positions[current.stat_id]
	var best: TreeNode = null
	var best_score: float = INF
	for node in _nodes:
		if node == current:
			continue
		var offset: Vector2 = _node_positions[node.stat_id] - from
		var dist: float = offset.length()
		if dist < 0.01:
			continue
		var along: float = offset.normalized().dot(dir)
		if along < 0.3:
			continue
		var score: float = dist / along
		if score < best_score:
			best_score = score
			best = node
	if best == null:
		return false
	_select_node(best)
	return true


## Sanctum UX point 4: a denied click (can't afford, or gated) answers
## with a short shake instead of doing nothing. Reuses the same
## tween-driven decay technique as a purchase pulse (_shake_amount decays
## in _process() below), applied to the node's own draw offset since tree
## nodes aren't individual Button instances juicy_button.gd could target
## directly. message is drawn alongside the shake (e.g. a shortfall
## amount, or "LOCKED") rather than spawning a separate floating-text
## node -- this Control already does all its own rendering via _draw(),
## so staying in that same custom-draw world keeps one rendering path
## instead of mixing in the arena's Node2D floating-text scene.
func flash_denied(stat_id: StringName, message: String) -> void:
	_shake_amount[stat_id] = 1.0
	_denied_message[stat_id] = message
	set_process(true)


func _build_tooltip_text(node: TreeNode) -> String:
	var def := node.def
	var lines: Array[String] = ["[b]%s[/b]" % def.display_name]

	if node.is_gated:
		lines.append("")
		lines.append("[color=#%s]LOCKED[/color]" % STATUS_RED.to_html(false))
		if node.parent != null:
			var requirement: String = node.parent.def.display_name
			if node.gate_min_level > 1:
				requirement += " Lv%d" % node.gate_min_level
			lines.append(
				"[color=#%s]Requires: %s[/color]" % [STATUS_MUTED.to_html(false), requirement]
			)
		return "\n".join(lines)

	lines.append(
		(
			"[color=#%s]Level %d / %d[/color]"
			% [STATUS_MUTED.to_html(false), node.level, def.level_cap]
		)
	)
	lines.append("")

	if not node.is_maxed:
		var current_value: float = def.base_value + float(node.level) * def.per_level_gain
		var next_value: float = current_value + def.per_level_gain
		lines.append(
			(
				"Current: %s → %s"
				% [
					_format_stat_value(current_value, def.decimals),
					_format_stat_value(next_value, def.decimals)
				]
			)
		)
		lines.append("")

	if node.is_maxed:
		lines.append("[color=#%s]✓ MAXED[/color]" % STATUS_GREEN.to_html(false))
	else:
		var cost: int = MetaProgression.get_cost(node.stat_id)
		var is_player_currency: bool = def.currency == StatDef.Currency.PLAYER
		var currency_name: String = "Glow" if is_player_currency else "Depth"
		var owned: int = (
			MetaProgression.player_currency
			if is_player_currency
			else MetaProgression.backpack_currency
		)
		lines.append("Cost: %d %s" % [cost, currency_name])
		if owned >= cost:
			lines.append("[color=#%s]✓ Affordable[/color]" % STATUS_GREEN.to_html(false))
		else:
			lines.append(
				(
					"[color=#%s]Need %d more %s[/color]"
					% [STATUS_MUTED.to_html(false), cost - owned, currency_name]
				)
			)

	var description: String = STAT_DESCRIPTIONS.get(node.stat_id, "")
	if description != "":
		lines.append("")
		lines.append("[color=#%s]────────────[/color]" % STATUS_MUTED.to_html(false))
		lines.append("[color=#%s][i]%s[/i][/color]" % [STATUS_MUTED.to_html(false), description])

	return "\n".join(lines)


func _format_stat_value(value: float, decimals: int) -> String:
	if decimals <= 0:
		return str(roundi(value))
	return ("%." + str(decimals) + "f") % value


func _find_node(stat_id: StringName) -> TreeNode:
	for node in _nodes:
		if node.stat_id == stat_id:
			return node
	return null


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text == "":
		return null

	var hovered_node := _find_node(_hovered_node)
	var border_color: Color = TOOLTIP_GOLD
	if hovered_node != null and hovered_node.def.currency == StatDef.Currency.BACKPACK:
		border_color = TOOLTIP_CYAN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.07, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = for_text
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(220, 0)
	label.add_theme_font_size_override("normal_font_size", 13)
	label.add_theme_font_size_override("bold_font_size", 18)
	panel.add_child(label)

	return panel


func _draw() -> void:
	for node in _nodes:
		if node.parent == null:
			continue
		var parent_pos: Vector2 = _node_positions[node.parent.stat_id]
		var child_pos: Vector2 = _node_positions[node.stat_id]
		SkillTreeGlow.draw_connection(
			self, parent_pos, child_pos, node.level > 0, _accent_color, node.is_real_gate
		)

	if _has_hub:
		_draw_hub()

	for node in _nodes:
		_draw_node(node)


## The Constellation: a non-purchasable center (the Diver) for Player
## Tree's hub-and-spoke layout -- just a small steady glow and glyph, no
## click handling (never added to _nodes, so _gui_input()'s hit-testing
## and _move_selection() both skip it automatically).
func _draw_hub() -> void:
	SkillTreeGlow.draw_node_glow(
		self, _hub_position, NODE_RADIUS * 0.7, SkillTreeGlow.State.MAXED, _accent_color, 0.0
	)
	draw_circle(_hub_position, NODE_RADIUS * 0.55, _accent_color * Color(1, 1, 1, 0.85))
	draw_arc(
		_hub_position, NODE_RADIUS * 0.55 - 1.0, 0.0, TAU, 24, _accent_color.lightened(0.3), 2.0
	)


## The Constellation (DESIGN.md 2026-08-18): one of four states computed
## fresh from data already on the node -- no new fields. Replaces the old
## currency ring/level arc/sealed ring, three separate per-node answers to
## what are actually field-wide questions, with a single brightness/pulse
## language.
func _node_state(node: TreeNode) -> SkillTreeGlow.State:
	if node.is_gated:
		return SkillTreeGlow.State.LOCKED
	if node.is_maxed:
		return SkillTreeGlow.State.MAXED
	var cost: int = MetaProgression.get_cost(node.stat_id)
	if cost > 0 and _current_currency >= cost:
		return SkillTreeGlow.State.AFFORDABLE
	return SkillTreeGlow.State.DIM


func _draw_node(node: TreeNode) -> void:
	var base_center: Vector2 = _node_positions[node.stat_id]
	var base_radius: float = _get_node_radius(node)
	var pulse: float = _pulse_amount.get(node.stat_id, 0.0)
	var hover_amount: float = _hover_amount.get(node.stat_id, 0.0)
	# Whole node (disc, border, icon, rings) scales together on hover --
	# a coherent "pop," not just the old static outline ring.
	var radius: float = base_radius * (1.0 + hover_amount * HOVER_SCALE_BUMP)
	# Sanctum UX point 4: denied-click shake -- a decaying sideways jitter,
	# applied to the draw position only (hit-testing in _gui_input() still
	# uses the node's real, un-shaken position).
	var shake: float = _shake_amount.get(node.stat_id, 0.0)
	var center: Vector2 = base_center
	if shake > 0.0:
		center += Vector2(sin(shake * PI * 6.0) * DENIED_SHAKE_MAGNITUDE * shake, 0.0)

	var state := _node_state(node)
	var breathing_phase: float = sin(_time * BREATHING_SPEED)
	SkillTreeGlow.draw_node_glow(self, center, radius, state, _accent_color, breathing_phase)
	# The one-shot purchase spark's brief extra-bright flash -- kept as a
	# separate transient layer on top of the steady state, not replaced by
	# it (never the problem the ring/arc/sealed-ring trio was).
	if pulse > 0.0:
		SkillTreeGlow.draw_node_glow(
			self,
			center,
			radius * (1.0 + pulse * 0.4),
			SkillTreeGlow.State.MAXED,
			_accent_color,
			0.0
		)

	var fill_color: Color
	var border_color: Color
	var icon_color: Color

	match state:
		SkillTreeGlow.State.LOCKED:
			fill_color = LOCKED_FILL
			border_color = LOCKED_BORDER
			icon_color = ICON_DIM
		SkillTreeGlow.State.DIM:
			fill_color = _accent_color * Color(1, 1, 1, 0.35)
			border_color = _accent_color.lerp(Color.BLACK, 0.35)
			icon_color = _accent_color
		SkillTreeGlow.State.AFFORDABLE:
			fill_color = _accent_color * Color(1, 1, 1, 0.8)
			border_color = _accent_color.lightened(0.15)
			icon_color = Color(0.08, 0.08, 0.08, 1.0)
		SkillTreeGlow.State.MAXED:
			fill_color = _accent_color * Color(1, 1, 1, 0.95)
			border_color = _accent_color.lightened(0.3)
			icon_color = Color(0.08, 0.08, 0.08, 1.0)

	draw_circle(center, radius, fill_color)
	draw_arc(center, radius - 1.5, 0.0, TAU, 28, border_color, 3.0)
	if hover_amount > 0.0 and not node.is_gated:
		draw_arc(center, radius + 3.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, hover_amount), 1.5)

	_draw_stat_icon(node.stat_id, center, radius * 0.62, icon_color)
	if shake > 0.0 and _denied_message.has(node.stat_id):
		_draw_denied_message(_denied_message[node.stat_id], center, radius, shake)


## Sanctum UX point 4: the shortfall (or "LOCKED") that goes with a denied
## click's shake -- fades out at the same rate the shake itself decays,
## so the two read as one gesture rather than two independent effects.
func _draw_denied_message(message: String, center: Vector2, radius: float, shake: float) -> void:
	var font := ThemeDB.fallback_font
	var text_pos: Vector2 = center + Vector2(0.0, -radius - 14.0)
	var color := Color(NO_CURRENCY_TINT.r, NO_CURRENCY_TINT.g, NO_CURRENCY_TINT.b, shake)
	draw_string(font, text_pos, message, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, color)


func _draw_stat_icon(stat_id: StringName, center: Vector2, s: float, color: Color) -> void:
	match stat_id:
		MetaProgression.STAT_DAMAGE:
			_draw_sword_icon(center, s, color)
		MetaProgression.STAT_MOVE_SPEED:
			_draw_speed_icon(center, s, color)
		MetaProgression.STAT_PICKUP_RANGE:
			_draw_magnet_icon(center, s, color)
		MetaProgression.STAT_BACKPACK_CAPACITY:
			_draw_bag_icon(center, s, color)
		MetaProgression.STAT_PURGE:
			_draw_purge_icon(center, s, color)
		MetaProgression.STAT_SPELL_UNLOCK:
			_draw_sparkle_icon(center, s, color)
		_:
			_draw_gem_icon(center, s, color)


func _draw_sword_icon(center: Vector2, s: float, color: Color) -> void:
	var tip: Vector2 = center + Vector2(-s * 0.85, -s * 0.85)
	var pommel: Vector2 = center + Vector2(s * 0.65, s * 0.65)
	draw_line(tip, pommel, color, 3.5)
	var guard_point: Vector2 = tip.lerp(pommel, 0.62)
	var perp: Vector2 = Vector2(1.0, -1.0).normalized() * s * 0.4
	draw_line(guard_point - perp, guard_point + perp, color, 3.5)
	draw_circle(pommel, s * 0.14, color)


func _draw_speed_icon(center: Vector2, s: float, color: Color) -> void:
	for i in range(2):
		var ox: float = -s * 0.55 + i * s * 0.7
		var top: Vector2 = center + Vector2(ox, -s * 0.6)
		var mid: Vector2 = center + Vector2(ox + s * 0.55, 0.0)
		var bottom: Vector2 = center + Vector2(ox, s * 0.6)
		draw_line(top, mid, color, 3.5)
		draw_line(mid, bottom, color, 3.5)


func _draw_magnet_icon(center: Vector2, s: float, color: Color) -> void:
	var leg_top: float = -s * 0.85
	var leg_bottom: float = s * 0.25
	var left_x: float = -s * 0.5
	var right_x: float = s * 0.5
	draw_line(center + Vector2(left_x, leg_top), center + Vector2(left_x, leg_bottom), color, 3.5)
	draw_line(center + Vector2(right_x, leg_top), center + Vector2(right_x, leg_bottom), color, 3.5)
	draw_arc(center + Vector2(0.0, leg_bottom), s * 0.5, 0.0, PI, 16, color, 3.5)
	draw_line(
		center + Vector2(left_x - s * 0.18, leg_top),
		center + Vector2(left_x + s * 0.18, leg_top),
		color,
		3.5
	)
	draw_line(
		center + Vector2(right_x - s * 0.18, leg_top),
		center + Vector2(right_x + s * 0.18, leg_top),
		color,
		3.5
	)


func _draw_bag_icon(center: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array(
		[
			center + Vector2(-s * 0.55, -s * 0.1),
			center + Vector2(-s * 0.75, s * 0.8),
			center + Vector2(s * 0.75, s * 0.8),
			center + Vector2(s * 0.55, -s * 0.1),
			center + Vector2(-s * 0.55, -s * 0.1)
		]
	)
	draw_polyline(pts, color, 2.8, true)
	draw_arc(center + Vector2(0.0, -s * 0.1), s * 0.32, PI, TAU, 12, color, 2.8)


func _draw_purge_icon(center: Vector2, s: float, color: Color) -> void:
	draw_line(center + Vector2(-s * 0.6, -s * 0.6), center + Vector2(s * 0.6, s * 0.6), color, 3.5)
	draw_line(center + Vector2(-s * 0.6, s * 0.6), center + Vector2(s * 0.6, -s * 0.6), color, 3.5)


func _draw_sparkle_icon(center: Vector2, s: float, color: Color) -> void:
	draw_line(center + Vector2(0.0, -s), center + Vector2(0.0, s), color, 3.0)
	draw_line(center + Vector2(-s, 0.0), center + Vector2(s, 0.0), color, 3.0)
	draw_line(
		center + Vector2(-s * 0.55, -s * 0.55), center + Vector2(s * 0.55, s * 0.55), color, 2.0
	)
	draw_line(
		center + Vector2(-s * 0.55, s * 0.55), center + Vector2(s * 0.55, -s * 0.55), color, 2.0
	)


## Default fallback icon for any stat not special-cased in
## _draw_stat_icon() -- mainly the per-spell upgrade stats. Used to also
## look up a rarity-tinted color for Compacting's five nodes; now always
## just uses the passed-in color like every other icon function, since
## Compacting's removal (DESIGN.md 2026-08-16) took the one caller that
## needed a different color with it.
func _draw_gem_icon(center: Vector2, s: float, color: Color) -> void:
	var gem := PackedVector2Array(
		[
			center + Vector2(0.0, -s),
			center + Vector2(s * 0.8, 0.0),
			center + Vector2(0.0, s),
			center + Vector2(-s * 0.8, 0.0)
		]
	)
	draw_colored_polygon(gem, color)
	draw_polyline(gem + PackedVector2Array([gem[0]]), color.darkened(0.35), 1.5, true)
