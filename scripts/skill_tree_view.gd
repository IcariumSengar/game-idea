class_name SkillTreeView
extends Control

## Medieval-themed skill tree with better visual hierarchy.

signal node_clicked(stat_id: StringName)

const NODE_SIZE: Vector2 = Vector2(110.0, 110.0)
const NODE_SPACING: Vector2 = Vector2(140.0, 140.0)
const LINE_COLOR: Color = Color(0.6, 0.5, 0.35, 0.7)
const LINE_WIDTH: float = 2.0
const AVAILABLE_COLOR: Color = Color(0.85, 0.75, 0.5, 1.0)
const LOCKED_COLOR: Color = Color(0.35, 0.3, 0.25, 1.0)
const MAXED_COLOR: Color = Color(0.4, 0.7, 0.4, 1.0)
const NO_CURRENCY_COLOR: Color = Color(0.7, 0.4, 0.3, 1.0)
const PULSE_DECAY_PER_SEC: float = 2.5
const PULSE_SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")
const PULSE_SPARK_COLOR: Color = Color(1.0, 0.9, 0.5)

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


func _ready() -> void:
	custom_minimum_size = Vector2(0, 550)
	mouse_filter = MOUSE_FILTER_STOP
	set_process(false)


func pulse(stat_id: StringName) -> void:
	_pulse_amount[stat_id] = 1.0
	set_process(true)
	if stat_id in _node_positions:
		var center: Vector2 = _node_positions[stat_id] + NODE_SIZE / 2.0
		var spark: CPUParticles2D = PULSE_SPARK_SCENE.instantiate()
		spark.position = center
		spark.color = PULSE_SPARK_COLOR
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
	currency_checker: Callable
) -> void:
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
	_calculate_positions(nodes_by_id)
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
			parent.children.append(child)


func _calculate_positions(_nodes_by_id: Dictionary) -> void:
	var roots: Array[TreeNode] = []
	for node in _nodes:
		if node.parent == null:
			roots.append(node)

	var current_y: float = 30.0
	for root in roots:
		_position_subtree(root, 40.0, current_y, NODE_SPACING.x)
		current_y += _get_subtree_height(root) + 80.0


func _position_subtree(node: TreeNode, x: float, y: float, spacing: float) -> void:
	_node_positions[node.stat_id] = Vector2(x, y)

	if node.children.is_empty():
		return

	var children_width: float = node.children.size() * spacing
	var start_x: float = x - children_width / 2.0 + spacing / 2.0

	for i in range(node.children.size()):
		var child: TreeNode = node.children[i]
		var child_x: float = start_x + i * spacing
		_position_subtree(child, child_x, y + NODE_SPACING.y, spacing * 0.85)


func _get_subtree_height(node: TreeNode) -> float:
	if node.children.is_empty():
		return NODE_SIZE.y
	var max_child_height: float = 0.0
	for child in node.children:
		max_child_height = max(max_child_height, _get_subtree_height(child))
	return NODE_SIZE.y + NODE_SPACING.y + max_child_height


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		for node in _nodes:
			var node_rect: Rect2 = Rect2(_node_positions[node.stat_id], NODE_SIZE)
			if node_rect.has_point(pos):
				node_clicked.emit(node.stat_id)
				get_tree().root.set_input_as_handled()
				return
	elif event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		_hovered_node = StringName()
		for node in _nodes:
			var node_rect: Rect2 = Rect2(_node_positions[node.stat_id], NODE_SIZE)
			if node_rect.has_point(pos):
				_hovered_node = node.stat_id
				break
		queue_redraw()


func _draw() -> void:
	# Draw connections first (behind nodes)
	for node in _nodes:
		if node.parent == null:
			continue
		var parent_pos: Vector2 = _node_positions[node.parent.stat_id] + NODE_SIZE / 2.0
		var child_pos: Vector2 = _node_positions[node.stat_id] + NODE_SIZE / 2.0
		draw_line(parent_pos, child_pos, LINE_COLOR, LINE_WIDTH)

	# Draw nodes
	for node in _nodes:
		_draw_node(node, _node_positions[node.stat_id])


func _draw_node(node: TreeNode, pos: Vector2) -> void:
	var rect: Rect2 = Rect2(pos, NODE_SIZE)
	var is_hovered: bool = node.stat_id == _hovered_node

	var bg_color: Color = _get_node_color(node)
	var border_color: Color = _get_node_border_color(node)

	# Draw outer border (stone/medieval frame)
	draw_rect(rect, border_color, false, 3.0)

	# Draw background with pattern
	draw_rect(rect.grow_individual(-3, -3, -3, -3), bg_color)

	# Draw decorative corners (medieval style)
	var corner_size: float = 8.0
	var corners_color: Color = border_color.lightened(0.2)

	# Top-left
	draw_rect(Rect2(rect.position, Vector2(corner_size, corner_size)), corners_color)
	# Top-right
	draw_rect(
		Rect2(
			rect.position + Vector2(rect.size.x - corner_size, 0), Vector2(corner_size, corner_size)
		),
		corners_color
	)
	# Bottom-left
	draw_rect(
		Rect2(
			rect.position + Vector2(0, rect.size.y - corner_size), Vector2(corner_size, corner_size)
		),
		corners_color
	)
	# Bottom-right
	draw_rect(
		Rect2(
			rect.position + Vector2(rect.size.x - corner_size, rect.size.y - corner_size),
			Vector2(corner_size, corner_size)
		),
		corners_color
	)

	# Draw hover effect
	if is_hovered and not node.is_gated and not node.is_locked_by_currency:
		draw_rect(rect.grow_individual(-3, -3, -3, -3), Color.WHITE, false, 2.0)

	# Draw purchase pulse (brief gold flash on buy)
	var pulse: float = _pulse_amount.get(node.stat_id, 0.0)
	if pulse > 0.0:
		draw_rect(rect.grow_individual(-3, -3, -3, -3), Color(1.0, 0.95, 0.75, pulse * 0.55))

	# Draw level indicator (filled circles)
	var level_y: float = rect.position.y + rect.size.y - 15.0
	var circle_radius: float = 2.5
	var circle_spacing: float = 8.0
	for i in range(node.def.level_cap):
		var circle_x: float = (
			rect.position.x
			+ rect.size.x / 2.0
			- (node.def.level_cap * circle_spacing / 2.0)
			+ (i * circle_spacing)
		)
		var circle_color: Color = border_color if i < node.level else Color(0.2, 0.2, 0.2, 0.5)
		draw_circle(Vector2(circle_x, level_y), circle_radius, circle_color)

	# Draw text
	var font: Font = get_theme_font("font")
	var name_size: int = 12
	var status_size: int = 9

	# Name (trimmed for display)
	var display_name: String = node.def.display_name.trim_prefix("Compactor: ")
	if display_name.length() > 12:
		display_name = display_name.substr(0, 10) + ".."

	var name_pos: Vector2 = rect.position + Vector2(rect.size.x / 2.0, 30.0)
	var name_width: float = (
		font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_CENTER, -1, name_size).x
	)
	draw_string(
		font,
		name_pos - Vector2(name_width / 2.0, 8.0),
		display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		name_size,
		Color.WHITE
	)

	# Status
	var status: String = ""
	var status_color: Color = Color.WHITE

	if node.is_gated:
		status = "[LOCKED]"
		status_color = Color(0.7, 0.5, 0.5)
	elif node.is_locked_by_currency:
		status = "[NEED $]"
		status_color = Color(0.8, 0.7, 0.4)
	elif node.is_maxed:
		status = "[MAX]"
		status_color = Color(0.5, 0.8, 0.5)
	else:
		status = "Lv %d/%d" % [node.level, node.def.level_cap]
		status_color = Color(0.8, 0.9, 1.0)

	var status_pos: Vector2 = rect.position + Vector2(rect.size.x / 2.0, 60.0)
	var status_width: float = (
		font.get_string_size(status, HORIZONTAL_ALIGNMENT_CENTER, -1, status_size).x
	)
	draw_string(
		font,
		status_pos - Vector2(status_width / 2.0, 4.0),
		status,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		status_size,
		status_color
	)


func _get_node_color(node: TreeNode) -> Color:
	if node.is_gated:
		return LOCKED_COLOR
	if node.is_locked_by_currency:
		return NO_CURRENCY_COLOR
	if node.is_maxed:
		return MAXED_COLOR
	return AVAILABLE_COLOR


func _get_node_border_color(node: TreeNode) -> Color:
	var base: Color
	if node.is_gated:
		base = Color(0.4, 0.3, 0.3)
	elif node.is_locked_by_currency:
		base = Color(0.6, 0.4, 0.2)
	elif node.is_maxed:
		base = Color(0.3, 0.6, 0.3)
	else:
		base = Color(0.7, 0.6, 0.3)

	return base
