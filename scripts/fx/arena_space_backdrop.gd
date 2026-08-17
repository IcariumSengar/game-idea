extends Node2D

## Procedural space backdrop for the arena: a dark void, soft nebula
## color washes, and twinkling stars -- replaces the dungeon floor
## tileset so combat reads as floating in space rather than a stone
## room with a repeating grid.

const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const STAR_COUNT: int = 220
const NEBULA_COUNT: int = 7

var _stars: Array = []
var _nebulae: Array = []
var _time: float = 0.0


func _ready() -> void:
	z_index = -10
	_generate_stars()
	_generate_nebulae()


func _generate_stars() -> void:
	_stars.clear()
	for i in STAR_COUNT:
		(
			_stars
			. append(
				{
					"pos": Vector2(randf() * ARENA_SIZE.x, randf() * ARENA_SIZE.y),
					"radius": randf_range(0.6, 2.0),
					"base_alpha": randf_range(0.25, 0.85),
					"speed": randf_range(0.4, 1.8),
					"offset": randf() * TAU,
				}
			)
		)


func _generate_nebulae() -> void:
	_nebulae.clear()
	for i in NEBULA_COUNT:
		(
			_nebulae
			. append(
				{
					"pos": Vector2(randf() * ARENA_SIZE.x, randf() * ARENA_SIZE.y),
					"radius": randf_range(140.0, 260.0),
					"color": Palette.NEBULA_TINTS[i % Palette.NEBULA_TINTS.size()],
				}
			)
		)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Palette.VOID_BASE)

	for nebula: Dictionary in _nebulae:
		draw_circle(nebula["pos"], nebula["radius"], nebula["color"])

	for star: Dictionary in _stars:
		var twinkle: float = 0.5 + 0.5 * sin(_time * star["speed"] + star["offset"])
		var alpha: float = star["base_alpha"] * (0.4 + 0.6 * twinkle)
		var tint := Palette.STAR_TINT
		draw_circle(star["pos"], star["radius"], Color(tint.r, tint.g, tint.b, alpha))
