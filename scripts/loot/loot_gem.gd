extends Node2D

## Procedurally-drawn magic gem visual for loot pickups -- a faceted
## crystal with a soft glow, tinted by rarity via modulate (set by
## loot.gd). Replaces the coin sprite; no gem art asset exists in the
## dungeon tileset.

const GEM_SIZE: float = 7.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, GEM_SIZE * 1.8, Color(1.0, 1.0, 1.0, 0.12))
	draw_circle(Vector2.ZERO, GEM_SIZE * 1.3, Color(1.0, 1.0, 1.0, 0.18))

	var top := Vector2(0.0, -GEM_SIZE)
	var upper_left := Vector2(-GEM_SIZE * 0.9, -GEM_SIZE * 0.25)
	var upper_right := Vector2(GEM_SIZE * 0.9, -GEM_SIZE * 0.25)
	var bottom := Vector2(0.0, GEM_SIZE * 1.1)

	draw_colored_polygon(PackedVector2Array([top, upper_left, bottom]), Color(0.72, 0.72, 0.8, 1.0))
	draw_colored_polygon(
		PackedVector2Array([top, upper_right, bottom]), Color(0.92, 0.92, 1.0, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([top, upper_left, upper_right]), Color(1.0, 1.0, 1.0, 1.0)
	)

	var outline := PackedVector2Array([top, upper_right, bottom, upper_left, top])
	draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.5), 1.0)
