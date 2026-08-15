class_name SkillTreeView
extends Control

## Circular chained skill tree, styled after mobile-RPG skill trees:
## per-branch accent color, glowing filled nodes for purchased tiers,
## dim outlines for locked ones, and a bigger "capstone" node at the end
## of each chain.

signal node_clicked(stat_id: StringName)

const NODE_RADIUS: float = 24.0
const CAPSTONE_RADIUS: float = 30.0
const NODE_SPACING: Vector2 = Vector2(66.0, 84.0)
const ZIGZAG_AMOUNT: float = 15.0
const PULSE_DECAY_PER_SEC: float = 2.5
const PULSE_SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")
const LOCKED_BORDER: Color = Color(0.32, 0.32, 0.34, 1.0)
const LOCKED_FILL: Color = Color(0.14, 0.14, 0.16, 1.0)
const NO_CURRENCY_TINT: Color = Color(0.9, 0.35, 0.3, 1.0)
const ICON_DIM: Color = Color(0.5, 0.5, 0.52, 1.0)
const TOOLTIP_GOLD: Color = Color(0.92, 0.82, 0.4, 1.0)
const TOOLTIP_CYAN: Color = Color(0.3, 0.75, 0.9, 1.0)
const STATUS_GREEN: Color = Color(0.3, 0.72, 0.32, 1.0)
const STATUS_RED: Color = Color(0.85, 0.3, 0.28, 1.0)
const STATUS_MUTED: Color = Color(0.6, 0.6, 0.62, 1.0)

const STAT_DESCRIPTIONS: Dictionary = {
	&"damage": "Your spells crackle with arcane power, striking harder.",
	&"move_speed": "Swift feet carry you through the void.",
	&"pickup_range": "Widens your arcane pull, drawing loot in from farther away.",
	&"backpack_capacity": "Stitches an extra pocket into your satchel.",
	&"compactor_common": "Grows your Commons Hoard, raising its max stack.",
	&"compactor_uncommon": "Grows your Uncommon Stash, raising its max stack.",
	&"compactor_rare": "Grows your Rare Vault, raising its max stack.",
	&"compactor_epic": "Grows your Epic Trove, raising its max stack.",
	&"compactor_mythic": "Grows your Mythic Hoard, raising its max stack.",
	&"purge": "Automatically discards your lowest-rarity loot once your hoard nears its limit.",
}

var _accent_color: Color = Color(0.85, 0.75, 0.5, 1.0)
var _node_positions: Dictionary = {}
var _nodes: Array[TreeNode] = []
var _hovered_node: StringName = StringName()
var _pulse_amount: Dictionary = {}


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
	if _pulse_amount.is_empty():
		set_process(false)
	queue_redraw()


func set_tree_data(
	stats: Array[StatDef],
	level_getter: Callable,
	gating_checker: Callable,
	currency_checker: Callable,
	accent_color: Color
) -> void:
	_accent_color = accent_color
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
	_chain_remaining_roots()
	_calculate_positions()
	queue_redraw()


func _build_tree_relationships(nodes_by_id: Dictionary) -> void:
	var parent_of: Dictionary = {
		MetaProgression.STAT_COMPACTOR_COMMON: MetaProgression.STAT_BACKPACK_CAPACITY,
		MetaProgression.STAT_COMPACTOR_UNCOMMON: MetaProgression.STAT_COMPACTOR_COMMON,
		MetaProgression.STAT_COMPACTOR_RARE: MetaProgression.STAT_COMPACTOR_UNCOMMON,
		MetaProgression.STAT_COMPACTOR_EPIC: MetaProgression.STAT_COMPACTOR_RARE,
		MetaProgression.STAT_COMPACTOR_MYTHIC: MetaProgression.STAT_COMPACTOR_EPIC,
		MetaProgression.STAT_PURGE: MetaProgression.STAT_COMPACTOR_RARE,
	}

	for child_id: StringName in parent_of:
		var parent_id: StringName = parent_of[child_id]
		if child_id in nodes_by_id and parent_id in nodes_by_id:
			var child: TreeNode = nodes_by_id[child_id]
			var parent: TreeNode = nodes_by_id[parent_id]
			child.parent = parent
			child.is_real_gate = true
			parent.children.append(child)


## Stats with no real prerequisite (e.g. the flat Player Tree) still get
## chained into a single visual line, drawn with a thin cosmetic link
## instead of a solid gate line, so every tree reads as one flowing branch.
func _chain_remaining_roots() -> void:
	var previous_root: TreeNode = null
	for node in _nodes:
		if node.parent == null:
			if previous_root != null:
				node.parent = previous_root
				previous_root.children.append(node)
			previous_root = node


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

	var children_width: float = node.children.size() * spacing
	var start_x: float = x - children_width / 2.0 + spacing / 2.0

	for i in range(node.children.size()):
		var child: TreeNode = node.children[i]
		var child_x: float = start_x + i * spacing
		_position_subtree(child, child_x, y + NODE_SPACING.y, spacing * 0.85, depth + 1)


func _get_subtree_height(node: TreeNode) -> float:
	if node.children.is_empty():
		return NODE_RADIUS * 2.0
	var max_child_height: float = 0.0
	for child in node.children:
		max_child_height = max(max_child_height, _get_subtree_height(child))
	return NODE_RADIUS * 2.0 + NODE_SPACING.y + max_child_height


func _get_node_radius(node: TreeNode) -> float:
	return CAPSTONE_RADIUS if node.children.is_empty() else NODE_RADIUS


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
			queue_redraw()


func _build_tooltip_text(node: TreeNode) -> String:
	var def := node.def
	var lines: Array[String] = ["[b]%s[/b]" % def.display_name]

	if node.is_gated:
		lines.append("")
		lines.append("[color=#%s]LOCKED[/color]" % STATUS_RED.to_html(false))
		if node.parent != null:
			lines.append(
				(
					"[color=#%s]Requires: %s[/color]"
					% [STATUS_MUTED.to_html(false), node.parent.def.display_name]
				)
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
	label.add_theme_font_size_override("bold_font_size", 13)
	panel.add_child(label)

	return panel


func _draw() -> void:
	for node in _nodes:
		if node.parent == null:
			continue
		var parent_pos: Vector2 = _node_positions[node.parent.stat_id]
		var child_pos: Vector2 = _node_positions[node.stat_id]
		if node.is_real_gate:
			draw_line(parent_pos, child_pos, _accent_color.lerp(Color.BLACK, 0.15), 3.0)
		else:
			_draw_dashed_line(parent_pos, child_pos, _accent_color * Color(1, 1, 1, 0.35))

	for node in _nodes:
		_draw_node(node)


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
	var center: Vector2 = _node_positions[node.stat_id]
	var radius: float = _get_node_radius(node)
	var is_hovered: bool = node.stat_id == _hovered_node
	var pulse: float = _pulse_amount.get(node.stat_id, 0.0)

	if node.level > 0 or pulse > 0.0:
		var glow_alpha: float = (0.18 if node.is_maxed else 0.1) + pulse * 0.35
		draw_circle(
			center,
			radius + 6.0,
			Color(_accent_color.r, _accent_color.g, _accent_color.b, glow_alpha)
		)

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
	if is_hovered and not node.is_gated:
		draw_arc(center, radius + 3.0, 0.0, TAU, 28, Color.WHITE, 1.5)

	_draw_stat_icon(node.stat_id, center, radius * 0.62, icon_color)
	_draw_level_pips(node, center, radius)


func _draw_level_pips(node: TreeNode, center: Vector2, radius: float) -> void:
	var cap: int = node.def.level_cap
	if cap <= 1:
		return
	var pip_radius: float = 2.0
	var pip_spacing: float = 7.0
	var row_y: float = center.y + radius + 8.0
	var start_x: float = center.x - (cap * pip_spacing) / 2.0 + pip_spacing / 2.0
	for i in range(cap):
		var pip_color: Color = _accent_color if i < node.level else Color(0.3, 0.3, 0.32, 0.6)
		draw_circle(Vector2(start_x + i * pip_spacing, row_y), pip_radius, pip_color)


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
		_:
			_draw_gem_icon(stat_id, center, s, color)


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


func _draw_gem_icon(stat_id: StringName, center: Vector2, s: float, color: Color) -> void:
	var tier_color := _get_compactor_tier_color(stat_id)
	var gem_color: Color = tier_color if tier_color != Color.TRANSPARENT else color
	var gem := PackedVector2Array(
		[
			center + Vector2(0.0, -s),
			center + Vector2(s * 0.8, 0.0),
			center + Vector2(0.0, s),
			center + Vector2(-s * 0.8, 0.0)
		]
	)
	draw_colored_polygon(gem, gem_color)
	draw_polyline(gem + PackedVector2Array([gem[0]]), gem_color.darkened(0.35), 1.5, true)


func _get_compactor_tier_color(stat_id: StringName) -> Color:
	var tier_id: StringName = StringName()
	match stat_id:
		MetaProgression.STAT_COMPACTOR_COMMON:
			tier_id = &"common"
		MetaProgression.STAT_COMPACTOR_UNCOMMON:
			tier_id = &"uncommon"
		MetaProgression.STAT_COMPACTOR_RARE:
			tier_id = &"rare"
		MetaProgression.STAT_COMPACTOR_EPIC:
			tier_id = &"epic"
		MetaProgression.STAT_COMPACTOR_MYTHIC:
			tier_id = &"mythic"
		_:
			return Color.TRANSPARENT
	var def := LootTypes.get_type(tier_id)
	return def.color if def != null else Color.TRANSPARENT
