class_name SkillTreeLayout
extends RefCounted

## The Constellation (DESIGN.md 2026-08-18): pure node-positioning math for
## skill_tree_view.gd, split out since a per-tree-shape rewrite (radial arc
## for Spell Tree, hub-and-spoke for Player Tree, tight cluster for Backpack
## Tree) doesn't need CanvasItem/drawing access at all -- it only computes
## where each node goes, skill_tree_view.gd still owns drawing them.
##
enum TreeKind { SPELL, PLAYER, BACKPACK }

## Reserved key for a tree's non-purchasable hub position (Player Tree's
## Diver, drawn specially by skill_tree_view.gd -- not a real TreeNode, not
## click-handled).
const HUB_KEY: StringName = &"__hub__"

const SPELL_ARC_RADIUS: float = 170.0
const SPELL_ARC_SPAN_DEGREES: float = 150.0
const SPELL_CLUSTER_RADIUS: float = 46.0
## Cluster members lay out two-per-row, extending outward along the spoke
## direction only every second member -- see the row-packing comment
## below for why (level 1 alone has 5 members). ZIGZAG is the side-to-
## side offset within a row; it must clear NODE_RADIUS (24.0, see
## skill_tree_view.gd) so same-row members don't touch.
const SPELL_CLUSTER_ROW_SPACING: float = 46.0
const SPELL_CLUSTER_ZIGZAG: float = 26.0
const SPELL_HUB_MARGIN_TOP: float = 55.0

const PLAYER_SPOKE_RADIUS: float = 140.0

const BACKPACK_NODE_GAP: float = 60.0
const BACKPACK_MARGIN_TOP: float = 70.0


static func calculate_positions(
	nodes: Array, tree_kind: TreeKind, control_size: Vector2
) -> Dictionary:
	match tree_kind:
		TreeKind.SPELL:
			return _layout_radial(nodes, control_size)
		TreeKind.PLAYER:
			return _layout_hub_and_spoke(nodes, control_size)
		_:
			return _layout_tight_cluster(nodes, control_size)


## Groups STAT_SPELL_UNLOCK's direct children by gate_min_level (1-7) --
## there's no existing "per-spell root" node, each spell's 1-3 upgrade
## stats are flat siblings today, distinguished only by that level. Each
## level gets one arc anchor; its group's members fan out in a tight local
## cluster past that anchor, radiating away from the hub.
static func _layout_radial(nodes: Array, control_size: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var min_anchor: float = SPELL_ARC_RADIUS + SPELL_CLUSTER_RADIUS + 30.0
	var center_x: float = control_size.x / 2.0 if control_size.x > min_anchor * 2.0 else min_anchor
	var hub_pos := Vector2(center_x, SPELL_HUB_MARGIN_TOP)

	var trunk: Object = null
	for node: Object in nodes:
		if node.parent == null:
			trunk = node
			break
	if trunk == null:
		return positions
	positions[trunk.stat_id] = hub_pos

	# Every direct child of the trunk (there's no existing "per-spell root"
	# node -- each spell's 1-3 upgrade stats are flat siblings today,
	# distinguished only by gate_min_level) groups by that shared level.
	var groups: Dictionary = {}
	for child: Object in trunk.children:
		var level: int = child.gate_min_level
		if not groups.has(level):
			groups[level] = []
		groups[level].append(child)

	var levels: Array = groups.keys()
	levels.sort()
	var span_rad: float = deg_to_rad(SPELL_ARC_SPAN_DEGREES)
	for i in levels.size():
		var level: int = levels[i]
		var t: float = float(i) / float(maxi(levels.size() - 1, 1))
		var angle: float = PI / 2.0 + lerp(-span_rad / 2.0, span_rad / 2.0, t)
		var direction := Vector2(cos(angle), sin(angle))
		var anchor: Vector2 = hub_pos + direction * SPELL_ARC_RADIUS

		# Two members per row (side by side, perpendicular to the spoke)
		# rather than one long line -- level 1 alone has 5 members (Arcane's
		# 2 + Inferno's 3, both ungated so they share the default gate
		# level), and a single-file line that long would push well past the
		# tree column's width.
		var members: Array = groups[level]
		var perp := Vector2(-direction.y, direction.x)
		for m in members.size():
			var row: int = m / 2
			var side: float = SPELL_CLUSTER_ZIGZAG if m % 2 == 0 else -SPELL_CLUSTER_ZIGZAG
			var out_dist: float = SPELL_CLUSTER_RADIUS + float(row) * SPELL_CLUSTER_ROW_SPACING
			positions[members[m].stat_id] = anchor + direction * out_dist + perp * side

	return positions


## A virtual, non-purchasable hub (the Diver) at center with the tree's
## stats as fixed spokes radiating out evenly -- Player Tree's 3 stats stay
## flat/ungated by design, so this is a pure presentation reflow, not new
## topology.
static func _layout_hub_and_spoke(nodes: Array, control_size: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var min_anchor: float = PLAYER_SPOKE_RADIUS + 40.0
	var center: Vector2 = (
		control_size / 2.0
		if control_size.x > min_anchor * 2.0 and control_size.y > min_anchor * 2.0
		else Vector2(min_anchor, min_anchor + 40.0)
	)
	positions[HUB_KEY] = center

	var count: int = nodes.size()
	if count == 0:
		return positions
	for i in count:
		var angle: float = -PI / 2.0 + TAU * float(i) / float(count)
		var direction := Vector2(cos(angle), sin(angle))
		positions[nodes[i].stat_id] = center + direction * PLAYER_SPOKE_RADIUS

	return positions


## The existing linear chain (Hold -> Discard -> Lure), just compressed
## into a small local radius instead of stretching down the full column --
## "a tight, intimate pool of light," not a thinned-out copy of Spell
## Tree's template.
static func _layout_tight_cluster(nodes: Array, control_size: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	var center_x: float = control_size.x / 2.0 if control_size.x > 120.0 else 60.0

	var chain: Array = []
	var by_id: Dictionary = {}
	for node: Object in nodes:
		by_id[node.stat_id] = node
	for node: Object in nodes:
		if node.parent == null:
			chain.append(node)
	# Walk each root's single-child chain in order -- Backpack Tree is a
	# straight line today (Hold -> Discard -> Lure), not a branching tree.
	var ordered: Array = []
	for root: Object in chain:
		var current: Object = root
		while current != null:
			ordered.append(current)
			current = current.children[0] if current.children.size() > 0 else null

	for i in ordered.size():
		positions[ordered[i].stat_id] = Vector2(
			center_x, BACKPACK_MARGIN_TOP + float(i) * BACKPACK_NODE_GAP
		)

	return positions
