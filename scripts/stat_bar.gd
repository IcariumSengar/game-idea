class_name StatBar
extends Control

const CORNER_RADIUS: int = 6
const BORDER_WIDTH: int = 1
const EASE_SPEED: float = 8.0

@export var bg_color: Color = Color(0.08, 0.08, 0.08, 0.75)
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.6)

var _target_fraction: float = 1.0
var _display_fraction: float = 1.0
var _fill_color: Color = Color.WHITE
var _bg_style: StyleBoxFlat
var _fill_style: StyleBoxFlat


func _ready() -> void:
	_bg_style = _make_style(bg_color, true)
	_fill_style = _make_style(_fill_color, false)
	queue_redraw()


func update(fraction: float, fill_color: Color) -> void:
	_target_fraction = clamp(fraction, 0.0, 1.0)
	_fill_color = fill_color
	if _fill_style:
		_fill_style.bg_color = fill_color
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_display_fraction = lerp(_display_fraction, _target_fraction, min(delta * EASE_SPEED, 1.0))
	if absf(_display_fraction - _target_fraction) < 0.001:
		_display_fraction = _target_fraction
		set_process(false)
	queue_redraw()


func _make_style(color: Color, round_all_corners: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS if round_all_corners else 0
	style.corner_radius_bottom_right = CORNER_RADIUS if round_all_corners else 0
	return style


func _draw() -> void:
	draw_style_box(_bg_style, Rect2(Vector2.ZERO, size))
	var fill_width: float = size.x * _display_fraction
	if fill_width > 0.5:
		draw_style_box(_fill_style, Rect2(Vector2.ZERO, Vector2(fill_width, size.y)))
