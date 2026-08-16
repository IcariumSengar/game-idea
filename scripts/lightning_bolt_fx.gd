class_name LightningBoltFx
extends Node2D

## A single jagged bolt segment between two points -- one instance per hop
## in Lightning Chain (see spell_caster.gd's _cast_lightning_chain()).
## Positioned at the world origin and drawn in global coordinates (rather
## than parented+localized) so a chain of several bolts stays simple to
## spawn: just two positions, no parenting math.

const DURATION: float = 0.18
const JAG_COUNT: int = 5
const JAG_OFFSET: float = 10.0
const COLOR: Color = Color(0.6, 0.85, 1.0)

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO

var _time: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_points = _build_jagged_line()


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _build_jagged_line() -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(from_point)
	for i in range(1, JAG_COUNT):
		var t: float = float(i) / float(JAG_COUNT)
		var base: Vector2 = from_point.lerp(to_point, t)
		var direction: Vector2 = (to_point - from_point).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		points.append(base + perpendicular * randf_range(-JAG_OFFSET, JAG_OFFSET))
	points.append(to_point)
	return points


func _draw() -> void:
	var alpha: float = 1.0 - (_time / DURATION)
	var color := Color(COLOR.r, COLOR.g, COLOR.b, alpha)
	for i in range(_points.size() - 1):
		draw_line(_points[i], _points[i + 1], color, 3.0)
		draw_line(_points[i], _points[i + 1], Color(1.0, 1.0, 1.0, alpha * 0.6), 1.0)
