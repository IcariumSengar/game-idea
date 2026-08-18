extends Node2D

## Procedural arena backdrop: a dark abyss void, murky drifting
## particulate clouds, and suspended motes of light -- replaces the
## dungeon floor tileset so combat reads as descending through open water
## rather than a stone room with a repeating grid. Abyssal Dive (DESIGN.md
## 2026-08-18): same "void + soft color washes + twinkling points"
## technique the arena already used, just retinted via Palette rather
## than rebuilt -- VOID_BASE/NEBULA_TINTS/STAR_TINT already carry the new
## cold, scarce-color abyss language now.

const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MOTE_COUNT: int = 220
const PARTICULATE_COUNT: int = 7

var _motes: Array = []
var _particulate: Array = []
var _time: float = 0.0


func _ready() -> void:
	z_index = -10
	_generate_motes()
	_generate_particulate()


func _generate_motes() -> void:
	_motes.clear()
	for i in MOTE_COUNT:
		(
			_motes
			. append(
				{
					"pos": Vector2(randf() * ARENA_SIZE.x, randf() * ARENA_SIZE.y),
					"radius": randf_range(0.6, 2.0),
					"base_alpha": randf_range(0.25, 0.85),
					"speed": randf_range(0.4, 1.8),
					"offset": randf() * TAU,
				}
			)
		)


func _generate_particulate() -> void:
	_particulate.clear()
	for i in PARTICULATE_COUNT:
		(
			_particulate
			. append(
				{
					"pos": Vector2(randf() * ARENA_SIZE.x, randf() * ARENA_SIZE.y),
					"radius": randf_range(140.0, 260.0),
					"color": Palette.NEBULA_TINTS[i % Palette.NEBULA_TINTS.size()],
				}
			)
		)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Palette.VOID_BASE)

	for cloud: Dictionary in _particulate:
		draw_circle(cloud["pos"], cloud["radius"], cloud["color"])

	for mote: Dictionary in _motes:
		var twinkle: float = 0.5 + 0.5 * sin(_time * mote["speed"] + mote["offset"])
		var alpha: float = mote["base_alpha"] * (0.4 + 0.6 * twinkle)
		var tint := Palette.STAR_TINT
		draw_circle(mote["pos"], mote["radius"], Color(tint.r, tint.g, tint.b, alpha))
