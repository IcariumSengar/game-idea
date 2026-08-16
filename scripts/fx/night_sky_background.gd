extends Control

## Procedural night-sky backdrop: gradient sky, twinkling stars, and a
## jagged mountain silhouette -- no image assets needed. Star/mountain
## positions are stored normalized (0..1) and scaled at draw time so
## layout survives being resized after _ready() runs.

const STAR_COUNT: int = 140
const SKY_TOP: Color = Color(0.04, 0.03, 0.09)
const SKY_MID: Color = Color(0.22, 0.09, 0.24)
const SKY_HORIZON: Color = Color(0.55, 0.24, 0.32)
const MOUNTAIN_COLOR: Color = Color(0.03, 0.035, 0.05)
const STAR_BAND: float = 0.62
const GRADIENT_STEPS: int = 32

var _stars: Array = []
var _mountain_norm_x: PackedFloat32Array = []
var _mountain_norm_y: PackedFloat32Array = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_generate_stars()
	_generate_mountains()
	resized.connect(queue_redraw)


func _generate_stars() -> void:
	_stars.clear()
	for i in STAR_COUNT:
		(
			_stars
			. append(
				{
					"x": randf(),
					"y": randf() * STAR_BAND,
					"radius": randf_range(0.6, 1.8),
					"base_alpha": randf_range(0.3, 0.9),
					"speed": randf_range(0.5, 2.0),
					"offset": randf() * TAU,
				}
			)
		)


func _generate_mountains() -> void:
	_mountain_norm_x = PackedFloat32Array([0.0])
	_mountain_norm_y = PackedFloat32Array([1.0])
	var x := 0.0
	while x < 1.0:
		x += randf_range(0.06, 0.13)
		_mountain_norm_x.append(minf(x, 1.0))
		_mountain_norm_y.append(1.0 - randf_range(0.05, 0.22))
	_mountain_norm_x.append(1.0)
	_mountain_norm_y.append(1.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	for i in GRADIENT_STEPS:
		var t0: float = float(i) / GRADIENT_STEPS
		var t1: float = float(i + 1) / GRADIENT_STEPS
		var color: Color
		if t0 < 0.6:
			color = SKY_TOP.lerp(SKY_MID, t0 / 0.6)
		else:
			color = SKY_MID.lerp(SKY_HORIZON, (t0 - 0.6) / 0.4)
		draw_rect(Rect2(0.0, size.y * t0, size.x, size.y * (t1 - t0) + 1.0), color)

	for star: Dictionary in _stars:
		var twinkle: float = 0.5 + 0.5 * sin(_time * star["speed"] + star["offset"])
		var alpha: float = star["base_alpha"] * (0.4 + 0.6 * twinkle)
		var pos := Vector2(star["x"] * size.x, star["y"] * size.y)
		draw_circle(pos, star["radius"], Color(1.0, 1.0, 1.0, alpha))

	var points := PackedVector2Array()
	for i in _mountain_norm_x.size():
		points.append(Vector2(_mountain_norm_x[i] * size.x, _mountain_norm_y[i] * size.y))
	if points.size() > 2:
		draw_colored_polygon(points, MOUNTAIN_COLOR)
