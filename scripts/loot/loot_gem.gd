extends Node2D

## Procedurally-drawn gem visual for loot at rest. Simplified from the
## original faceted crystal (DESIGN.md/TODO.md's "pips, not gems" rework
## -- the original read as cluttered/too big the moment several piled up
## mid-fight) but kept as an actual faceted shape rather than a plain
## dot, per live-play feedback that a flat circle lost the game's magic-
## gem aesthetic. Sized to be trackable/followable at a glance without
## cluttering the screen -- went too far small on the first pass after
## the crystal-detail cut, sized back up on live-play feedback. Tinted
## by rarity via modulate (set by loot.gd).
##
## Painted Hoard (DESIGN.md's "Art Direction," 2026-08-17), starting
## point: each facet's old flat draw_colored_polygon() fill is now a
## light-to-dark gradient (draw_polygon() with a color per vertex --
## Godot interpolates the fill between them, no GradientTexture2D or
## shader needed), plus a warm dark-brown ink stroke around the outer
## silhouette instead of the old unstroked flat polygons. Tint source is
## unchanged -- these are still neutral grayscale-ish values multiplied
## by loot.gd's rarity-color modulate, only the per-facet fill/outline
## technique changed.

const GEM_HEIGHT: float = 12.0
const GEM_WIDTH: float = 8.2
const INK_WIDTH: float = 1.1


func _draw() -> void:
	var top := Vector2(0.0, -GEM_HEIGHT * 0.6)
	var left := Vector2(-GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var right := Vector2(GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var bottom := Vector2(0.0, GEM_HEIGHT * 0.55)

	# Shadowed facet -- darkest at the bottom, away from the implied light.
	draw_polygon(
		PackedVector2Array([top, left, bottom]),
		PackedColorArray(
			[
				Color(0.95, 0.95, 0.95, 1.0),
				Color(0.72, 0.72, 0.72, 1.0),
				Color(0.5, 0.5, 0.5, 1.0),
			]
		)
	)
	# Lit facet -- brightest overall, still falls off toward the bottom.
	draw_polygon(
		PackedVector2Array([top, right, bottom]),
		PackedColorArray(
			[
				Color(1.0, 1.0, 1.0, 1.0),
				Color(0.9, 0.9, 0.9, 1.0),
				Color(0.7, 0.7, 0.7, 1.0),
			]
		)
	)
	# Highlight cap -- the brightest patch, near-flat since it IS the
	# light source rather than a shaded form.
	draw_polygon(
		PackedVector2Array([top, left, right]),
		PackedColorArray(
			[
				Color(1.0, 1.0, 1.0, 0.95),
				Color(0.92, 0.92, 0.92, 0.9),
				Color(0.98, 0.98, 0.98, 0.9),
			]
		)
	)

	var outline := PackedVector2Array([top, right, bottom, left, top])
	draw_polyline(outline, Palette.PAINTED_INK_GEM, INK_WIDTH, true)
