extends Control

## Procedural radial vignette that darkens the arena's edges for a more
## focused, atmospheric feel. Drawn as concentric ring strokes (not
## filled disks -- those would build up density toward the center,
## the opposite of what a vignette needs) since no shader/gradient
## texture asset is used.

const RING_STEPS: int = 28
const MAX_ALPHA: float = 0.5


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center: Vector2 = size / 2.0
	var max_radius: float = size.length() / 2.0
	var ring_width: float = max_radius / RING_STEPS + 2.0
	for i in RING_STEPS:
		var t: float = float(i) / (RING_STEPS - 1)
		var radius: float = max_radius * t
		var alpha: float = MAX_ALPHA * pow(t, 2.5)
		var vignette := Palette.VIGNETTE
		draw_arc(
			center,
			radius,
			0.0,
			TAU,
			64,
			Color(vignette.r, vignette.g, vignette.b, alpha),
			ring_width
		)
