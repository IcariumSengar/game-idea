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
const NODE_SPACING: Vector2 = Vector2(66.0, 84.0)
const ZIGZAG_AMOUNT: float = 15.0
## Wide sibling groups (e.g. Spell Unlock's 6 gated upgrade nodes) wrap
## after this many instead of spreading across a single row, which would
## otherwise overflow past the tree column's width.
const MAX_CHILDREN_PER_ROW: int = 4
const PULSE_DECAY_PER_SEC: float = 2.5
const PULSE_SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const LOCKED_BORDER: Color = Color(0.32, 0.32, 0.34, 1.0)
const LOCKED_FILL: Color = Color(0.14, 0.14, 0.16, 1.0)
const NO_CURRENCY_TINT: Color = Color(0.9, 0.35, 0.3, 1.0)
const ICON_DIM: Color = Color(0.5, 0.5, 0.52, 1.0)
const TOOLTIP_GOLD: Color = Color(0.92, 0.82, 0.4, 1.0)
const TOOLTIP_CYAN: Color = Color(0.3, 0.75, 0.9, 1.0)
const STATUS_GREEN: Color = Color(0.3, 0.72, 0.32, 1.0)
const STATUS_RED: Color = Color(0.85, 0.3, 0.28, 1.0)
const STATUS_MUTED: Color = Color(0.6, 0.6, 0.62, 1.0)
## Sanctum UX (DESIGN.md 2026-08-17), point 1: a partial ring outside the
## node showing progress toward its next level's cost.
const CURRENCY_RING_GAP: float = 6.0
const CURRENCY_RING_WIDTH: float = 2.5
const CURRENCY_RING_COLOR_ALPHA: float = 0.65
## Point 3: a partial arc on the node's own border showing level/cap --
## replaces the old pip row, which overlapped neighboring nodes on any
## stat with a double-digit level cap.
const LEVEL_ARC_WIDTH: float = 3.5
## Point 4: a maxed node's sealed state needs to read as clearly distinct
## from "just leveled," not a barely-different alpha (the old 0.9 vs 0.7
## locked-alpha was functionally invisible at a glance).
const SEALED_RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const SEALED_RING_WIDTH: float = 2.0
## Denied-click shake (point 4) -- same tween-driven juice technique
## juicy_button.gd uses for its own press feedback, applied to this
## node's draw offset instead of a separate Button's scale, since tree
## nodes aren't individual Button instances here.
const DENIED_SHAKE_DURATION: float = 0.3
const DENIED_SHAKE_MAGNITUDE: float = 6.0
## Shimmer (point 1): a node crossing into affordable since the shop was
## last closed gets a one-off glow -- reuses the exact same _pulse_amount
## mechanism a purchase pulse already uses, just triggered by a different
## cause, so there's one glow language instead of two.
const SHIMMER_PULSE_AMOUNT: float = 0.7

## Visual pass (direct feedback, 2026-08-17: "make use of Godot's ability
## to render cool visuals" -- the flat single-circle glow/straight-line
## tree read as flat). Layered soft glow instead of one low-alpha circle:
## several concentric rings with quadratic falloff fake a bloom without a
## shader or a second draw surface.
const GLOW_LAYERS: int = 4
const GLOW_LAYER_SPACING: float = 5.5
## Real-gate connectors curve instead of drawing straight -- a cubic
## Bezier that leaves each node vertically before bending toward the
## other's x, the standard "flowchart connector" shape, reads as an
## organic branch rather than a wiring diagram. Cosmetic (non-gate)
## connections stay straight/dashed on purpose -- see _draw() -- so the
## curve itself doubles as "this is a real dependency" signal.
const CURVE_SEGMENTS: int = 16
## Hover now eases in/out (scale + ring alpha) instead of snapping,
## mirroring the shake/pulse tween-driven juice this file already uses
## elsewhere rather than adding a new animation technique.
const HOVER_SCALE_BUMP: float = 0.12
const HOVER_LERP_SPEED: float = 10.0

const STAT_DESCRIPTIONS: Dictionary = {
	&"damage": "Your spells crackle with arcane power, striking harder.",
	&"move_speed": "Swift feet carry you through the void.",
	&"pickup_range": "Widens your arcane pull and keeps a fuller triage queue processable.",
	&"backpack_capacity": "Stitches an extra pocket into your satchel.",
	&"purge": "Sharpens what you throw away -- boosts Cast Off's damage when you discard a gem.",
}

var _accent_color: Color = Color(0.85, 0.75, 0.5, 1.0)
var _node_positions: Dictionary = {}
var _nodes: Array[TreeNode] = []
var _hovered_node: StringName = StringName()
var _pulse_amount: Dictionary = {}
## Sanctum UX point 1: this tree's current/previous-close currency, used
## to draw each node's progress-to-next-level ring and to detect which
## nodes crossed into affordable since the shop was last closed (shimmer).
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
	set_process(false)
	resized.connect(_on_resized)


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

	if _pulse_amount.is_empty() and _shake_amount.is_empty() and hover_settled:
		set_process(false)
	queue_redraw()


## current_currency (Sanctum UX point 1, DESIGN.md 2026-08-17): feeds each
## node's progress-to-next-level ring -- every stat in a given tree call
## shares one currency (Player/Spell Tree both spend Essence, Backpack
## Tree spends Stardust), so one value per call suffices.
func set_tree_data(
	stats: Array[StatDef],
	level_getter: Callable,
	gating_checker: Callable,
	currency_checker: Callable,
	accent_color: Color,
	current_currency: int
) -> void:
	_accent_color = accent_color
	_current_currency = current_currency
	_nodes.clear()
	_node_positions.clear()

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
	queue_redraw()


func _build_tree_relationships(nodes_by_id: Dictionary) -> void:
	var parent_of: Dictionary = {
		# Was chained off Compacting's Rare Vault node before its removal
		# (DESIGN.md 2026-08-16) -- Backpack Tree is now just two nodes,
		# Bearing then Discard.
		MetaProgression.STAT_PURGE: MetaProgression.STAT_BACKPACK_CAPACITY,
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


func _calculate_positions() -> void:
	var roots: Array[TreeNode] = []
	for node in _nodes:
		if node.parent == null:
			roots.append(node)

	# size.x isn't known yet on the first call (before the container layout
	# pass runs), so fall back to a fixed anchor until _on_resized() fires
	# and recenters using the real column width.
	var min_anchor: float = CAPSTONE_RADIUS + ZIGZAG_AMOUNT + 20.0
	var center_x: float = size.x / 2.0 if size.x > min_anchor * 2.0 else min_anchor
	var current_y: float = 36.0
	for root in roots:
		_position_subtree(root, center_x, current_y, NODE_SPACING.x, 0)
		current_y += _get_subtree_height(root) + 60.0


func _position_subtree(node: TreeNode, x: float, y: float, spacing: float, depth: int) -> void:
	_node_positions[node.stat_id] = Vector2(x, y)

	if node.children.is_empty():
		return

	if node.children.size() == 1:
		var offset: float = ZIGZAG_AMOUNT if depth % 2 == 0 else -ZIGZAG_AMOUNT
		_position_subtree(node.children[0], x + offset, y + NODE_SPACING.y, spacing, depth + 1)
		return

	var row_count: int = mini(node.children.size(), MAX_CHILDREN_PER_ROW)

	for i in range(node.children.size()):
		var row: int = i / row_count
		var col: int = i % row_count
		var items_in_row: int = mini(row_count, node.children.size() - row * row_count)
		var row_width: float = items_in_row * spacing
		var row_start_x: float = x - row_width / 2.0 + spacing / 2.0
		var child_x: float = row_start_x + col * spacing
		var child_y: float = y + NODE_SPACING.y * (row + 1)
		_position_subtree(node.children[i], child_x, child_y, spacing * 0.85, depth + 1)


func _get_subtree_height(node: TreeNode) -> float:
	if node.children.is_empty():
		return NODE_RADIUS * 2.0
	var row_count: int = (
		1 if node.children.size() == 1 else mini(node.children.size(), MAX_CHILDREN_PER_ROW)
	)
	var num_rows: int = (
		1 if node.children.size() == 1 else ceili(float(node.children.size()) / float(row_count))
	)
	var max_child_height: float = 0.0
	for child in node.children:
		max_child_height = max(max_child_height, _get_subtree_height(child))
	return NODE_RADIUS * 2.0 + NODE_SPACING.y * num_rows + max_child_height


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
		var hovered_id: StringName = hovered.stat_id if hovered != null else StringName()
		if hovered_id != _hovered_node:
			_hovered_node = hovered_id
			tooltip_text = _build_tooltip_text(hovered) if hovered != null else ""
			node_hovered.emit(_hovered_node)
			set_process(true)
			queue_redraw()


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
		var currency_name: String = "Essence" if is_player_currency else "Stardust"
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
		if node.is_real_gate:
			_draw_branch_curve(parent_pos, child_pos, _accent_color.lerp(Color.BLACK, 0.15), 3.0)
		else:
			_draw_dashed_line(parent_pos, child_pos, _accent_color * Color(1, 1, 1, 0.35))

	for node in _nodes:
		_draw_node(node)


## Cubic Bezier, control points pulled straight out of each endpoint
## along y before bending toward the other's x -- see CURVE_SEGMENTS'
## comment above for why this shape specifically (the standard flowchart-
## connector curve) rather than a symmetric bow.
func _draw_branch_curve(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var vertical_reach: Vector2 = Vector2(0.0, (to.y - from.y) * 0.5)
	var control_1: Vector2 = from + vertical_reach
	var control_2: Vector2 = to - vertical_reach
	var points := PackedVector2Array()
	for i in CURVE_SEGMENTS + 1:
		var t: float = float(i) / float(CURVE_SEGMENTS)
		points.append(_cubic_bezier_point(from, control_1, control_2, to, t))
	draw_polyline(points, color, width, true)


func _cubic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var a: Vector2 = p0.lerp(p1, t)
	var b: Vector2 = p1.lerp(p2, t)
	var c: Vector2 = p2.lerp(p3, t)
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var dash_len: float = 5.0
	var gap_len: float = 4.0
	var total: float = from.distance_to(to)
	var direction: Vector2 = (to - from).normalized()
	var distance: float = 0.0
	while distance < total:
		var seg_end: float = min(distance + dash_len, total)
		draw_line(from + direction * distance, from + direction * seg_end, color, 2.0)
		distance += dash_len + gap_len


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

	if node.level > 0 or pulse > 0.0:
		_draw_glow(center, radius, pulse, node.is_maxed)

	var fill_color: Color
	var border_color: Color
	var icon_color: Color

	if node.is_gated:
		fill_color = LOCKED_FILL
		border_color = LOCKED_BORDER
		icon_color = ICON_DIM
	elif node.level > 0:
		fill_color = _accent_color * Color(1, 1, 1, 0.9 if node.is_maxed else 0.7)
		border_color = _accent_color.lightened(0.3 if node.is_maxed else 0.1)
		icon_color = Color(0.08, 0.08, 0.08, 1.0)
	elif node.is_locked_by_currency:
		fill_color = LOCKED_FILL
		border_color = _accent_color.lerp(NO_CURRENCY_TINT, 0.6)
		icon_color = border_color
	else:
		fill_color = LOCKED_FILL
		border_color = _accent_color
		icon_color = _accent_color

	draw_circle(center, radius, fill_color)
	draw_arc(center, radius - 1.5, 0.0, TAU, 28, border_color, 3.0)
	if hover_amount > 0.0 and not node.is_gated:
		draw_arc(center, radius + 3.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, hover_amount), 1.5)

	# Sanctum UX point 4: sealed state -- a maxed node needs to read as
	# clearly distinct from "just leveled," not the old barely-different
	# 0.9-vs-0.7 fill alpha.
	if node.is_maxed:
		draw_arc(center, radius + 4.0, 0.0, TAU, 28, SEALED_RING_COLOR, SEALED_RING_WIDTH)

	_draw_stat_icon(node.stat_id, center, radius * 0.62, icon_color)
	_draw_level_arc(node, center, radius)
	if not node.is_maxed:
		_draw_currency_ring(node, center, radius)
	if shake > 0.0 and _denied_message.has(node.stat_id):
		_draw_denied_message(_denied_message[node.stat_id], center, radius, shake)


## Layered soft glow (see GLOW_LAYERS' comment above) -- several
## concentric, low-alpha circles with quadratic falloff read as a bloom
## without a shader or a second additive-blend draw surface.
func _draw_glow(center: Vector2, radius: float, pulse: float, is_maxed: bool) -> void:
	var glow_base_alpha: float = (0.16 if is_maxed else 0.09) + pulse * 0.3
	for layer in GLOW_LAYERS:
		var layer_t: float = float(layer + 1) / float(GLOW_LAYERS)
		var layer_radius: float = (
			radius + GLOW_LAYER_SPACING * float(layer + 1) * (1.0 + pulse * 0.6)
		)
		var layer_alpha: float = glow_base_alpha * (1.0 - layer_t) * (1.0 - layer_t)
		draw_circle(
			center,
			layer_radius,
			Color(_accent_color.r, _accent_color.g, _accent_color.b, layer_alpha)
		)


## Sanctum UX point 3: replaces the old pip row (drew level_cap pips at
## 7px each, so a 20-level stat drew a 140px-wide row against ~66px of
## node spacing -- overlapped its neighbors) with a partial arc on the
## node's own border. Distinct from the currency ring below: this shows
## overall progress toward the *cap* (level ÷ level_cap); the ring shows
## progress toward the *next* level's cost -- a node can be simultaneously
## "3 of 20 levels bought" (this arc) and "60% of the way to affording
## level 4" (the ring), so both coexist rather than one replacing the
## other.
func _draw_level_arc(node: TreeNode, center: Vector2, radius: float) -> void:
	var cap: int = node.def.level_cap
	if cap <= 1 or node.level <= 0:
		return
	var fraction: float = float(node.level) / float(cap)
	draw_arc(
		center,
		radius - 1.5,
		-PI / 2.0,
		-PI / 2.0 + TAU * fraction,
		28,
		_accent_color.lightened(0.4),
		LEVEL_ARC_WIDTH
	)


## Sanctum UX point 1: partial ring outside the node showing progress
## toward its next level's cost. The locked geometric cost curve means
## late-game nodes take many runs to afford -- a 60-second run earns ~3
## Stardust against Bearing's first level costing 100 -- so most Sanctum
## visits currently show no visible change at all on an unaffordable node
## beyond a static red-tinted border. Disappears once maxed (nothing left
## to save toward -- see the sealed ring in _draw_node() instead).
func _draw_currency_ring(node: TreeNode, center: Vector2, radius: float) -> void:
	var cost: int = MetaProgression.get_cost(node.stat_id)
	if cost <= 0:
		return
	var fraction: float = clampf(float(_current_currency) / float(cost), 0.0, 1.0)
	if fraction <= 0.0:
		return
	var ring_color: Color = Color(
		_accent_color.r, _accent_color.g, _accent_color.b, CURRENCY_RING_COLOR_ALPHA
	)
	draw_arc(
		center,
		radius + CURRENCY_RING_GAP,
		-PI / 2.0,
		-PI / 2.0 + TAU * fraction,
		28,
		ring_color,
		CURRENCY_RING_WIDTH
	)


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
