class_name TimeWarpBurst
extends Node2D

## Time Warp's expanding double-ring flash, sized to its actual radius
## stat like frost_burst.gd. Two concentric rings (rather than one ring +
## spikes like Inferno/Frost) to read as a slow-motion field rather than
## an impact.

const DURATION: float = 0.5
const MIN_RADIUS: float = 8.0
const COLOR: Color = Color(0.65, 0.45, 0.95)

var target_radius: float = 200.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = _time / DURATION
	var outer_radius: float = lerp(MIN_RADIUS, target_radius, progress)
	var inner_radius: float = lerp(MIN_RADIUS, target_radius * 0.7, progress)
	var alpha: float = 1.0 - progress
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 40, Color(COLOR.r, COLOR.g, COLOR.b, alpha), 3.0)
	draw_arc(
		Vector2.ZERO, inner_radius, 0.0, TAU, 40, Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.6), 2.0
	)
