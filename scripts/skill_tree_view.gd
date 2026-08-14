class_name SkillTreeView
extends Control

## Visual skill tree with nodes and connections.
## Displays upgrades as interconnected nodes showing gating hierarchy.

signal node_clicked(stat_id: StringName)

const NODE_SIZE: Vector2 = Vector2(140.0, 60.0)
const NODE_SPACING: Vector2 = Vector2(160.0, 100.0)
const LINE_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)
const LINE_WIDTH: float = 2.0

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

	# Draw background
	draw_rect(rect, color)
	draw_rect(rect, Color.WHITE, false, 1.0)

	# Draw label
	var label: String = node.def.display_name.trim_prefix("Compactor: ")
	if node.is_gated:
		label += "\n(LOCKED)"
	elif node.is_locked_by_currency:
		label += "\n(No currency)"
	elif node.is_maxed:
		label += "\n(MAX)"
	else:
		label += "\nLvl %d" % node.level

	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = rect.get_center() - text_size / 2.0
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _get_node_color(node: TreeNode) -> Color:
	if node.is_gated:
		return Color(0.3, 0.3, 0.3, 0.8)
	if node.is_locked_by_currency:
		return Color(0.5, 0.3, 0.3, 0.8)
	if node.is_maxed:
		return Color(0.3, 0.5, 0.3, 0.8)
	return Color(0.2, 0.4, 0.6, 0.8)
