class_name SkillTreeView
extends Control

## Visual skill tree with nodes and connections.
## Displays upgrades as interconnected nodes showing gating hierarchy.

signal node_clicked(stat_id: StringName)

const NODE_SIZE: Vector2 = Vector2(120.0, 70.0)
const NODE_SPACING: Vector2 = Vector2(150.0, 110.0)
const LINE_COLOR: Color = Color(0.4, 0.6, 0.8, 0.5)
const LINE_WIDTH: float = 2.5
const NODE_BORDER_WIDTH: float = 2.0
const PADDING: float = 30.0

var _node_positions: Dictionary = {}
var _nodes: Array[TreeNode] = []
var _node_by_id: Dictionary = {}


class TreeNode:
	var stat_id: StringName
	var def: StatDef
	var level: int
	var is_maxed: bool
	var is_gated: bool
	var is_locked_by_currency: bool
	var children: Array[TreeNode] = []
	var parent: TreeNode = null


func _ready() -> void:
	custom_minimum_size = Vector2(0, 400)
	mouse_filter = MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var pos: Vector2 = event.position
	for node in _nodes:
		var node_rect: Rect2 = Rect2(_node_positions[node.stat_id], NODE_SIZE)
		if node_rect.has_point(pos):
			node_clicked.emit(node.stat_id)
			get_tree().root.set_input_as_handled()
			return


func set_tree_data(stats: Array[StatDef], level_getter: Callable, gating_checker: Callable, currency_checker: Callable) -> void:
	_nodes.clear()
	_node_positions.clear()

	# Build tree structure from stat data
	var root: TreeNode = null
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

	# Build parent-child relationships
	_build_tree_relationships(nodes_by_id)

	# Calculate positions
	_calculate_positions(nodes_by_id)

	queue_redraw()


func _build_tree_relationships(nodes_by_id: Dictionary) -> void:
	# Backpack tree structure:
	# Capacity (root)
	# ├─ Common Compactor
	# │  ├─ Uncommon Compactor
	# │  ├─ Rare Compactor
	# │  ├─ Epic Compactor
	# │  ├─ Mythic Compactor
	# │  └─ Purge
	# Player tree: all root level, no hierarchy

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
			parent.children.append(child)


func _calculate_positions(nodes_by_id: Dictionary) -> void:
	# Position nodes in a tree layout
	var roots: Array[TreeNode] = []
	for node in _nodes:
		if node.parent == null:
			roots.append(node)

	var current_y: float = 20.0
	for root in roots:
		_position_subtree(root, 20.0, current_y, NODE_SPACING.x)
		current_y += _get_subtree_height(root) + 40.0


func _position_subtree(node: TreeNode, x: float, y: float, spacing: float) -> void:
	_node_positions[node.stat_id] = Vector2(x, y)

	if node.children.is_empty():
		return

	var children_width: float = node.children.size() * spacing
	var start_x: float = x - children_width / 2.0 + spacing / 2.0

	for i in range(node.children.size()):
		var child: TreeNode = node.children[i]
		var child_x: float = start_x + i * spacing
		_position_subtree(child, child_x, y + NODE_SPACING.y, spacing * 0.8)


func _get_subtree_height(node: TreeNode) -> float:
	if node.children.is_empty():
		return NODE_SIZE.y
	var max_child_height: float = 0.0
	for child in node.children:
		max_child_height = max(max_child_height, _get_subtree_height(child))
	return NODE_SIZE.y + NODE_SPACING.y + max_child_height


func _draw() -> void:
	# Draw connections first
	for node in _nodes:
		if node.parent == null:
			continue
		var parent_pos: Vector2 = _node_positions[node.parent.stat_id]
		var child_pos: Vector2 = _node_positions[node.stat_id]
		var parent_bottom: Vector2 = parent_pos + Vector2(NODE_SIZE.x / 2.0, NODE_SIZE.y)
		var child_top: Vector2 = child_pos + Vector2(NODE_SIZE.x / 2.0, 0)
		draw_line(parent_bottom, child_top, LINE_COLOR, LINE_WIDTH)

	# Draw nodes
	for node in _nodes:
		_draw_node(node, _node_positions[node.stat_id])


func _draw_node(node: TreeNode, pos: Vector2) -> void:
	var color: Color = _get_node_color(node)
	var rect: Rect2 = Rect2(pos, NODE_SIZE)
	var border_color: Color = _get_node_border_color(node)

	# Draw background with gradient effect
	draw_rect(rect, color)
	draw_rect(rect, border_color, false, NODE_BORDER_WIDTH)

	# Draw inner highlight for non-locked nodes
	if not node.is_gated and not node.is_locked_by_currency:
		var inner_rect := rect.grow(-NODE_BORDER_WIDTH)
		draw_rect(inner_rect, Color.WHITE, false, 1.0)

	# Draw label with better formatting
	var display_name: String = node.def.display_name.trim_prefix("Compactor: ")
	var status: String = ""
	var status_color: Color = Color.WHITE

	if node.is_gated:
		status = "LOCKED"
		status_color = Color(0.8, 0.4, 0.4)
	elif node.is_locked_by_currency:
		status = "NEED\nCURRENCY"
		status_color = Color(0.8, 0.7, 0.3)
	elif node.is_maxed:
		status = "MAXED"
		status_color = Color(0.4, 0.8, 0.4)
	else:
		status = "Lv %d/%d" % [node.level, node.def.level_cap]
		status_color = Color(0.7, 0.9, 1.0)

	var font: Font = get_theme_font("font")
	var title_size: int = 12
	var status_size: int = 11

	# Draw title
	var title_pos: Vector2 = rect.position + Vector2(NODE_SIZE.x / 2.0, 10.0)
	draw_string(font, title_pos - Vector2(font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size).x / 2.0, 0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)

	# Draw status
	var status_pos: Vector2 = rect.position + Vector2(NODE_SIZE.x / 2.0, 38.0)
	var status_size_vec: Vector2 = font.get_string_size(status, HORIZONTAL_ALIGNMENT_CENTER, -1, status_size)
	draw_string(font, status_pos - status_size_vec / 2.0, status, HORIZONTAL_ALIGNMENT_LEFT, -1, status_size, status_color)


func _get_node_color(node: TreeNode) -> Color:
	if node.is_gated:
		return Color(0.25, 0.25, 0.25, 0.85)
	if node.is_locked_by_currency:
		return Color(0.55, 0.35, 0.25, 0.85)
	if node.is_maxed:
		return Color(0.25, 0.5, 0.35, 0.85)
	return Color(0.15, 0.35, 0.55, 0.85)


func _get_node_border_color(node: TreeNode) -> Color:
	if node.is_gated:
		return Color(0.4, 0.4, 0.4, 0.9)
	if node.is_locked_by_currency:
		return Color(0.7, 0.5, 0.3, 0.9)
	if node.is_maxed:
		return Color(0.3, 0.7, 0.4, 0.9)
	return Color(0.3, 0.6, 0.9, 0.9)
