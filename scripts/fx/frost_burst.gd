class_name FrostBurst
extends Node2D

## Small procedural frost-ring flash where Frost Nova lands. Mirrors
## InfernoBurst's shape (expanding ring + radiating spikes) but colored icy
## cyan/white, slower to fade (chill lingers, fire flashes), and sized to
## the spell's actual radius stat so the ring doubles as a readable hit-area
## indicator rather than pure cosmetic.

const DURATION: float = 0.4
const MIN_RADIUS: float = 8.0
const SPIKE_COUNT: int = 10

var target_radius: float = 150.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = _time / DURATION
	var radius: float = lerp(MIN_RADIUS, target_radius, progress)
	var alpha: float = 1.0 - progress
	var base := Palette.SPELL_FROST_BURST
	var core := Palette.SPELL_FROST_CORE
	var color: Color = Color(base.r, base.g, base.b, alpha)
	var core_color: Color = Color(core.r, core.g, core.b, alpha * 0.85)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 3.0)
	draw_arc(Vector2.ZERO, radius * 0.94, 0.0, TAU, 32, core_color, 1.2)
	for i in range(SPIKE_COUNT):
		var angle: float = TAU * i / SPIKE_COUNT
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(dir * radius * 0.75, dir * radius, color, 2.0)
		draw_line(dir * radius * 0.75, dir * radius * 0.88, core_color, 1.0)
