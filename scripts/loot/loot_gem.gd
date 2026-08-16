extends Node2D

## Procedurally-drawn pip visual for loot at rest -- deliberately minimal
## (DESIGN.md/TODO.md's "pips, not gems" rework): the old faceted-crystal
## shape read as cluttered/too big the moment several piled up mid-fight.
## Quiet on the ground; the visual payoff moved to the pickup moment
## instead (see loot.gd's collect()). Tinted by rarity via modulate (set
## by loot.gd).

const PIP_RADIUS: float = 4.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, PIP_RADIUS, Color.WHITE)
	draw_circle(
		Vector2(-PIP_RADIUS * 0.3, -PIP_RADIUS * 0.3), PIP_RADIUS * 0.35, Color(1.0, 1.0, 1.0, 0.7)
	)
