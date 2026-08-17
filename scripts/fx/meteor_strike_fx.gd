class_name MeteorStrikeFx
extends Node2D

## Meteor Strike's telegraph-then-impact flash: a growing danger ring warns
## the impact zone for TELEGRAPH_DURATION, then a bright flash marks the
## actual hit the instant damage lands (see spell_caster.gd's
## _cast_meteor_strike(), which awaits this node's `impact` signal before
## dealing damage -- so the visual and the damage are never out of sync).

signal impact

const TELEGRAPH_DURATION: float = 0.5
const FLASH_DURATION: float = 0.25

var radius: float = 100.0

var _time: float = 0.0
var _impacted: bool = false


func _process(delta: float) -> void:
	_time += delta
	if not _impacted and _time >= TELEGRAPH_DURATION:
		_impacted = true
		impact.emit()
	if _impacted and _time >= TELEGRAPH_DURATION + FLASH_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var base := Palette.SPELL_METEOR
	if not _impacted:
		var progress: float = _time / TELEGRAPH_DURATION
		var alpha: float = 0.3 + 0.5 * sin(progress * PI * 6.0) * 0.5 + 0.3
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(base.r, base.g, base.b, alpha), 2.0)
	else:
		var flash_progress: float = (_time - TELEGRAPH_DURATION) / FLASH_DURATION
		var flash_radius: float = lerp(radius * 0.3, radius * 1.3, flash_progress)
		var flash_alpha: float = 1.0 - flash_progress
		var core := Palette.SPELL_METEOR_CORE
		var ring := Palette.SPELL_METEOR_FLASH_RING
		draw_circle(Vector2.ZERO, flash_radius, Color(base.r, base.g, base.b, flash_alpha))
		draw_circle(Vector2.ZERO, flash_radius * 0.5, Color(core.r, core.g, core.b, flash_alpha))
		draw_arc(
			Vector2.ZERO, radius, 0.0, TAU, 40, Color(ring.r, ring.g, ring.b, flash_alpha), 4.0
		)
