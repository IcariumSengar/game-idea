extends Control

## Decorative summoning-circle motif drawn behind the menu: two
## concentric rings, an inscribed triangle, and small rune circles at
## its points. Purely ornamental, sits behind the menu VBox.

const RING_COLOR: Color = Color(0.75, 0.65, 0.9, 0.35)
const OUTER_LINE_WIDTH: float = 1.5
const INNER_LINE_WIDTH: float = 1.0
const ROTATION_SPEED: float = 0.05

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	var rotation: float = _time * ROTATION_SPEED

	draw_arc(center, radius, 0.0, TAU, 64, RING_COLOR, OUTER_LINE_WIDTH)
	draw_arc(center, radius * 0.88, 0.0, TAU, 64, RING_COLOR, INNER_LINE_WIDTH)

	var tri := PackedVector2Array()
	for i in 3:
		var angle: float = rotation - PI / 2.0 + i * TAU / 3.0
		tri.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.8)
	tri.append(tri[0])
	draw_polyline(tri, RING_COLOR, INNER_LINE_WIDTH)

	for i in 3:
		var angle: float = rotation - PI / 2.0 + i * TAU / 3.0
		var pt: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.8
		draw_arc(pt, radius * 0.12, 0.0, TAU, 24, RING_COLOR, INNER_LINE_WIDTH)
