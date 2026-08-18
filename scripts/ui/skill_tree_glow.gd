class_name SkillTreeGlow
extends RefCounted

## The Constellation (DESIGN.md 2026-08-18): node glow and connection-line
## drawing for skill_tree_view.gd, split out alongside the layout rewrite
## (see skill_tree_layout.gd) since neither needs the rest of that file's
## input/tooltip logic. Static functions taking a CanvasItem and calling
## draw_circle/draw_arc/draw_polyline on it directly -- valid from any
## function invoked synchronously during the owning node's own _draw(),
## not just code textually inside it.

## Four states replacing the old currency ring + level arc + sealed ring --
## one brightness/pulse language instead of three per-node encodings.
enum State { LOCKED, DIM, AFFORDABLE, MAXED }

const GLOW_LAYERS: int = 4
const GLOW_LAYER_SPACING: float = 5.5
const DIM_BASE_ALPHA: float = 0.08
const AFFORDABLE_MIN_ALPHA: float = 0.14
const AFFORDABLE_MAX_ALPHA: float = 0.34
const MAXED_BASE_ALPHA: float = 0.22
const SEALED_RING_WIDTH: float = 2.0

const CURVE_SEGMENTS: int = 16
const DASH_LENGTH: float = 5.0
const DASH_GAP: float = 4.0
const LIT_LINE_WIDTH: float = 3.0
const LIT_HALO_WIDTH: float = 7.0
const LIT_HALO_ALPHA: float = 0.25
const UNLIT_LINE_WIDTH: float = 1.5
const UNLIT_COLOR: Color = Color(0.4, 0.44, 0.48, 0.35)


## breathing_phase: one shared sin() value the caller computes once per
## redraw (not a per-node timer) so every affordable node in the tab
## pulses together -- "can I afford this" reads as "is it breathing,"
## across the whole field at once.
static func draw_node_glow(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	state: State,
	accent_color: Color,
	breathing_phase: float
) -> void:
	if state == State.LOCKED:
		return

	var base_alpha: float
	match state:
		State.DIM:
			base_alpha = DIM_BASE_ALPHA
		State.AFFORDABLE:
			var breathe: float = 0.5 + 0.5 * breathing_phase
			base_alpha = lerp(AFFORDABLE_MIN_ALPHA, AFFORDABLE_MAX_ALPHA, breathe)
		State.MAXED:
			base_alpha = MAXED_BASE_ALPHA

	for layer in GLOW_LAYERS:
		var layer_t: float = float(layer + 1) / float(GLOW_LAYERS)
		var layer_radius: float = radius + GLOW_LAYER_SPACING * float(layer + 1)
		var layer_alpha: float = base_alpha * (1.0 - layer_t) * (1.0 - layer_t)
		canvas.draw_circle(
			center, layer_radius, Color(accent_color.r, accent_color.g, accent_color.b, layer_alpha)
		)

	if state == State.MAXED:
		canvas.draw_arc(
			center, radius + 4.0, 0.0, TAU, 28, Palette.SKILL_TREE_SEALED_RING, SEALED_RING_WIDTH
		)


## Purchased (level > 0) connections read as a lit, glowing filament;
## everything else stays a faint gray thread. Same curve-vs-dashed shape
## distinction the old per-tree connector logic already used (a real gate
## curves, a cosmetic link dashes) -- only the color/glow language is new.
static func draw_connection(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2,
	is_purchased: bool,
	accent_color: Color,
	is_real_gate: bool
) -> void:
	if not is_purchased:
		if is_real_gate:
			_draw_branch_curve(canvas, from, to, UNLIT_COLOR, UNLIT_LINE_WIDTH)
		else:
			_draw_dashed_line(canvas, from, to, UNLIT_COLOR)
		return

	var lit_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.9)
	var halo_color := Color(accent_color.r, accent_color.g, accent_color.b, LIT_HALO_ALPHA)
	if is_real_gate:
		_draw_branch_curve(canvas, from, to, halo_color, LIT_HALO_WIDTH)
		_draw_branch_curve(canvas, from, to, lit_color, LIT_LINE_WIDTH)
	else:
		canvas.draw_line(from, to, halo_color, LIT_HALO_WIDTH)
		canvas.draw_line(from, to, lit_color, LIT_LINE_WIDTH * 0.7)


static func _draw_branch_curve(
	canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float
) -> void:
	var vertical_reach: Vector2 = Vector2(0.0, (to.y - from.y) * 0.5)
	var control_1: Vector2 = from + vertical_reach
	var control_2: Vector2 = to - vertical_reach
	var points := PackedVector2Array()
	for i in CURVE_SEGMENTS + 1:
		var t: float = float(i) / float(CURVE_SEGMENTS)
		points.append(_cubic_bezier_point(from, control_1, control_2, to, t))
	canvas.draw_polyline(points, color, width, true)


static func _cubic_bezier_point(
	p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float
) -> Vector2:
	var a: Vector2 = p0.lerp(p1, t)
	var b: Vector2 = p1.lerp(p2, t)
	var c: Vector2 = p2.lerp(p3, t)
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


static func _draw_dashed_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	var total: float = from.distance_to(to)
	var direction: Vector2 = (to - from).normalized()
	var distance: float = 0.0
	while distance < total:
		var seg_end: float = min(distance + DASH_LENGTH, total)
		canvas.draw_line(
			from + direction * distance, from + direction * seg_end, color, UNLIT_LINE_WIDTH
		)
		distance += DASH_LENGTH + DASH_GAP
