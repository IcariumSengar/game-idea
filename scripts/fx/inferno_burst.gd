class_name InfernoBurst
extends Node2D

## Small procedural flame-burst flash where Inferno Blade lands. Being
## omnidirectional, it has no travelling projectile to carry visual
## weight the way Arcane Bolt's does, so this fills that gap: an
## expanding ring with a few radiating flame spikes, gone in a quarter
## second.

const DURATION: float = 0.25
const MIN_RADIUS: float = 8.0
const MAX_RADIUS: float = 40.0
const SPIKE_COUNT: int = 8
const COLOR: Color = Color(0.95, 0.4, 0.15)
## Painted Hoard (DESIGN.md's "Art Direction," 2026-08-17): a warm bright
## core alongside the saturated outer color approximates a light-to-dark
## gradient across the ring/spike cross-section, instead of the old
## single flat-color stroke.
const HOT_CORE_COLOR: Color = Color(1.0, 0.85, 0.55)

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = _time / DURATION
	var radius: float = lerp(MIN_RADIUS, MAX_RADIUS, progress)
	var alpha: float = 1.0 - progress
	var color: Color = Color(COLOR.r, COLOR.g, COLOR.b, alpha)
	var hot_color: Color = Color(HOT_CORE_COLOR.r, HOT_CORE_COLOR.g, HOT_CORE_COLOR.b, alpha * 0.85)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 4.0)
	draw_arc(Vector2.ZERO, radius * 0.92, 0.0, TAU, 24, hot_color, 1.5)
	for i in range(SPIKE_COUNT):
		var angle: float = TAU * i / SPIKE_COUNT
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(dir * radius * 0.5, dir * radius, color, 3.0)
		draw_line(dir * radius * 0.5, dir * radius * 0.75, hot_color, 1.5)
