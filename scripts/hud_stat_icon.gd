extends Control

## Small procedural icon for the in-run stats overlay (clock/sparkle) --
## no matching sprite assets exist for these, so drawn as simple vector
## shapes matching the icon style used in the skill tree.

enum Kind { CLOCK, SPARKLE }

@export var kind: Kind = Kind.CLOCK
@export var icon_color: Color = Color.WHITE


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var s: float = minf(size.x, size.y) / 2.0 * 0.8
	match kind:
		Kind.CLOCK:
			draw_arc(center, s, 0.0, TAU, 24, icon_color, 2.0)
			draw_line(center, center + Vector2(0.0, -s * 0.6), icon_color, 2.0)
			draw_line(center, center + Vector2(s * 0.4, 0.0), icon_color, 2.0)
		Kind.SPARKLE:
			draw_line(center + Vector2(0.0, -s), center + Vector2(0.0, s), icon_color, 2.0)
			draw_line(center + Vector2(-s, 0.0), center + Vector2(s, 0.0), icon_color, 2.0)
			draw_line(
				center + Vector2(-s * 0.6, -s * 0.6),
				center + Vector2(s * 0.6, s * 0.6),
				icon_color,
				1.5
			)
			draw_line(
				center + Vector2(-s * 0.6, s * 0.6),
				center + Vector2(s * 0.6, -s * 0.6),
				icon_color,
				1.5
			)
