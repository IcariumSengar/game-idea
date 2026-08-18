extends Control

## Abyssal Dive's shared menu backdrop (DESIGN.md's "Art Direction,"
## 2026-08-18): a murky depth gradient, slow-rising bubbles, and a jagged
## reef/seafloor silhouette -- no image assets needed. Same technique and
## file this project's night-sky backdrop already used (replaces stars
## with rising bubbles, a mountain skyline with a reef silhouette), kept
## as one script shared by main_menu/save_slot_selector/run_prep/shop/
## settings_menu rather than five separate re-themes. Bubble/reef
## positions are stored normalized (0..1) and scaled at draw time so
## layout survives being resized after _ready() runs.

const BUBBLE_COUNT: int = 90
const GRADIENT_STEPS: int = 32
## Bubbles rise (normalized units/sec) and wrap back to the bottom once
## they drift past the top, rather than the old stars' static twinkle-in-
## place -- motion reads as "underwater," not just a recolored sky.
const RISE_SPEED_MIN: float = 0.015
const RISE_SPEED_MAX: float = 0.05
const SWAY_AMOUNT: float = 4.0

var _bubbles: Array = []
var _reef_norm_x: PackedFloat32Array = []
var _reef_norm_y: PackedFloat32Array = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_generate_bubbles()
	_generate_reef()
	resized.connect(queue_redraw)


func _generate_bubbles() -> void:
	_bubbles.clear()
	for i in BUBBLE_COUNT:
		(
			_bubbles
			. append(
				{
					"x": randf(),
					"y": randf(),
					"radius": randf_range(0.5, 1.8),
					"base_alpha": randf_range(0.2, 0.75),
					"rise_speed": randf_range(RISE_SPEED_MIN, RISE_SPEED_MAX),
					"sway_speed": randf_range(0.4, 1.2),
					"offset": randf() * TAU,
				}
			)
		)


func _generate_reef() -> void:
	_reef_norm_x = PackedFloat32Array([0.0])
	_reef_norm_y = PackedFloat32Array([1.0])
	var x := 0.0
	while x < 1.0:
		x += randf_range(0.05, 0.11)
		_reef_norm_x.append(minf(x, 1.0))
		_reef_norm_y.append(1.0 - randf_range(0.03, 0.14))
	_reef_norm_x.append(1.0)
	_reef_norm_y.append(1.0)


func _process(delta: float) -> void:
	_time += delta
	for bubble: Dictionary in _bubbles:
		bubble["y"] -= bubble["rise_speed"] * delta
		if bubble["y"] < 0.0:
			bubble["y"] = 1.0
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	for i in GRADIENT_STEPS:
		var t0: float = float(i) / GRADIENT_STEPS
		var t1: float = float(i + 1) / GRADIENT_STEPS
		var color: Color
		if t0 < 0.6:
			color = Palette.VOID_BASE.lerp(Palette.NIGHT_SKY_MID, t0 / 0.6)
		else:
			color = Palette.NIGHT_SKY_MID.lerp(Palette.NIGHT_SKY_HORIZON, (t0 - 0.6) / 0.4)
		draw_rect(Rect2(0.0, size.y * t0, size.x, size.y * (t1 - t0) + 1.0), color)

	var tint := Palette.STAR_TINT
	for bubble: Dictionary in _bubbles:
		var shimmer: float = 0.5 + 0.5 * sin(_time * bubble["sway_speed"] + bubble["offset"])
		var alpha: float = bubble["base_alpha"] * (0.5 + 0.5 * shimmer)
		var sway: float = sin(_time * bubble["sway_speed"] * 0.5 + bubble["offset"]) * SWAY_AMOUNT
		var pos := Vector2(bubble["x"] * size.x + sway, bubble["y"] * size.y)
		draw_circle(pos, bubble["radius"], Color(tint.r, tint.g, tint.b, alpha))

	var points := PackedVector2Array()
	for i in _reef_norm_x.size():
		points.append(Vector2(_reef_norm_x[i] * size.x, _reef_norm_y[i] * size.y))
	if points.size() > 2:
		draw_colored_polygon(points, Palette.NIGHT_SKY_MOUNTAIN)
