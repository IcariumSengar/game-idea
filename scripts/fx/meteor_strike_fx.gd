class_name MeteorStrikeFx
extends Node2D

## Trench Collapse's telegraph-then-impact flash: spreading pressure
## cracks warn the impact zone for TELEGRAPH_DURATION, then a bright
## flash marks the actual hit the instant damage lands (see
## spell_caster.gd's _cast_meteor_strike(), which awaits this node's
## `impact` signal before dealing damage -- so the visual and the damage
## are never out of sync).
##
## Abyssal Dive (DESIGN.md's "Art Direction," 2026-08-18): the old plain
## circular telegraph ring becomes jagged cracks radiating outward from
## the impact point, growing with TELEGRAPH_DURATION -- "the seafloor
## implodes under crushing pressure," not a meteor's landing marker. Only
## the telegraph shape changed; the impact flash stays a circular
## shockwave, which already reads correctly for a sudden implosion.

signal impact

const TELEGRAPH_DURATION: float = 0.5
const FLASH_DURATION: float = 0.25
const CRACK_COUNT: int = 7
const CRACK_SEGMENTS: int = 3
const CRACK_JITTER: float = 12.0

var radius: float = 100.0

var _time: float = 0.0
var _impacted: bool = false
var _crack_angles: PackedFloat32Array = []
var _crack_jitters: Array[PackedFloat32Array] = []


func _ready() -> void:
	for i in CRACK_COUNT:
		_crack_angles.append((float(i) / float(CRACK_COUNT)) * TAU + randf_range(-0.3, 0.3))
		var jitters := PackedFloat32Array()
		for j in CRACK_SEGMENTS:
			jitters.append(randf_range(-CRACK_JITTER, CRACK_JITTER))
		_crack_jitters.append(jitters)


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
		var alpha: float = 0.5 + 0.3 * sin(progress * PI * 6.0)
		var crack_length: float = radius * progress
		for i in _crack_angles.size():
			_draw_crack(
				_crack_angles[i],
				_crack_jitters[i],
				crack_length,
				Color(base.r, base.g, base.b, alpha)
			)
		# Faint boundary ring at the eventual impact extent -- keeps the
		# "how far does this reach" read the old full ring gave for free.
		draw_arc(
			Vector2.ZERO, radius, 0.0, TAU, 40, Color(base.r, base.g, base.b, alpha * 0.25), 1.0
		)
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


## One jagged crack radiating from the impact center out to `length`,
## perpendicular jitter per segment growing with distance so it reads as
## a fracture spreading outward, not a wobbly straight line.
func _draw_crack(angle: float, jitters: PackedFloat32Array, length: float, color: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array([Vector2.ZERO])
	for i in jitters.size():
		var t: float = float(i + 1) / float(jitters.size())
		points.append(dir * length * t + perp * jitters[i] * t)
	draw_polyline(points, color, 2.0, true)
