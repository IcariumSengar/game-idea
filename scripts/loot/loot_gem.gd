extends Node2D

## Procedurally-drawn gem visual for loot at rest. Simplified from the
## original faceted crystal (DESIGN.md/TODO.md's "pips, not gems" rework
## -- the original read as cluttered/too big the moment several piled up
## mid-fight) but kept as an actual faceted shape rather than a plain
## dot, per live-play feedback that a flat circle lost the game's magic-
## gem aesthetic. No glow ring, no outline stroke -- just two shaded
## facets and a bright cap. Sized to be trackable/followable at a glance
## without cluttering the screen -- went too far small on the first pass
## after the crystal-detail cut, sized back up on live-play feedback.
## Tinted by rarity via modulate (set by loot.gd).

const GEM_HEIGHT: float = 12.0
const GEM_WIDTH: float = 8.2


func _draw() -> void:
	var top := Vector2(0.0, -GEM_HEIGHT * 0.6)
	var left := Vector2(-GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var right := Vector2(GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var bottom := Vector2(0.0, GEM_HEIGHT * 0.55)

	draw_colored_polygon(PackedVector2Array([top, left, bottom]), Color(0.85, 0.85, 0.85, 1.0))
	draw_colored_polygon(PackedVector2Array([top, right, bottom]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([top, left, right]), Color(1.0, 1.0, 1.0, 0.9))
