extends Node2D

## Procedurally-drawn gem visual for loot at rest. Small and simple by
## design (DESIGN.md/TODO.md's "pips, not gems" rework -- the original
## faceted crystal read as cluttered/too big the moment several piled up
## mid-fight), but kept as an actual faceted shape rather than a plain
## dot, per live-play feedback that a flat circle lost the game's magic-
## gem aesthetic. No glow ring, no outline stroke -- just two shaded
## facets and a bright cap, small enough to stay quiet on the ground.
## Tinted by rarity via modulate (set by loot.gd).

const GEM_HEIGHT: float = 5.0
const GEM_WIDTH: float = 3.4


func _draw() -> void:
	var top := Vector2(0.0, -GEM_HEIGHT * 0.6)
	var left := Vector2(-GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var right := Vector2(GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var bottom := Vector2(0.0, GEM_HEIGHT * 0.55)

	draw_colored_polygon(PackedVector2Array([top, left, bottom]), Color(0.85, 0.85, 0.85, 1.0))
	draw_colored_polygon(PackedVector2Array([top, right, bottom]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([top, left, right]), Color(1.0, 1.0, 1.0, 0.9))
