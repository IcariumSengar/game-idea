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
## Abyssal Dive (DESIGN.md's "Art Direction," 2026-08-18): "dark ground,
## glow reads as meaning" -- the facets themselves are now a desaturated/
## darkened fill (a dimmer version of the rarity tint, not the flat
## bright-white-to-gray range Painted Hoard used), with 2-3 layered
## low-alpha glow circles drawn behind them carrying the actual rarity
## color. Near-white glow base so loot.gd's rarity-color modulate tints
## it to match, same "layered soft glow" technique already used for
## skill tree nodes/the Legendary beacon/spell projectiles. Cool-toned
## ink stroke (Palette.ABYSS_INK_GEM) replaces Painted Hoard's warm
## dark-brown one. Tint source is unchanged -- these are still neutral
## grayscale-ish values multiplied by loot.gd's rarity-color modulate,
## only the per-facet fill/outline/glow technique changed.

const GEM_HEIGHT: float = 12.0
const GEM_WIDTH: float = 8.2
const INK_WIDTH: float = 1.1
const GLOW_LAYERS: int = 3
const GLOW_BASE_RADIUS: float = 5.0
const GLOW_LAYER_SPACING: float = 2.6
const GLOW_BASE_ALPHA: float = 0.4


func _draw() -> void:
	var top := Vector2(0.0, -GEM_HEIGHT * 0.6)
	var left := Vector2(-GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var right := Vector2(GEM_WIDTH * 0.5, -GEM_HEIGHT * 0.1)
	var bottom := Vector2(0.0, GEM_HEIGHT * 0.55)
	var glow_center := Vector2(0.0, -GEM_HEIGHT * 0.05)

	for layer in GLOW_LAYERS:
		var layer_t: float = float(layer + 1) / float(GLOW_LAYERS)
		var radius: float = GLOW_BASE_RADIUS + GLOW_LAYER_SPACING * float(layer)
		var alpha: float = GLOW_BASE_ALPHA * (1.0 - layer_t) * (1.0 - layer_t)
		draw_circle(glow_center, radius, Color(1.0, 1.0, 1.0, alpha))

	# Shadowed facet -- darkest at the bottom, away from the implied light.
	draw_polygon(
		PackedVector2Array([top, left, bottom]),
		PackedColorArray(
			[
				Color(0.45, 0.45, 0.45, 1.0),
				Color(0.28, 0.28, 0.28, 1.0),
				Color(0.15, 0.15, 0.15, 1.0),
			]
		)
	)
	# Lit facet -- brightest overall, still falls off toward the bottom.
	draw_polygon(
		PackedVector2Array([top, right, bottom]),
		PackedColorArray(
			[
				Color(0.55, 0.55, 0.55, 1.0),
				Color(0.4, 0.4, 0.4, 1.0),
				Color(0.25, 0.25, 0.25, 1.0),
			]
		)
	)
	# Highlight cap -- the brightest patch, near-flat since it IS the
	# light source rather than a shaded form.
	draw_polygon(
		PackedVector2Array([top, left, right]),
		PackedColorArray(
			[
				Color(0.65, 0.65, 0.65, 0.95),
				Color(0.55, 0.55, 0.55, 0.9),
				Color(0.6, 0.6, 0.6, 0.9),
			]
		)
	)

	var outline := PackedVector2Array([top, right, bottom, left, top])
	draw_polyline(outline, Palette.ABYSS_INK_GEM, INK_WIDTH, true)
