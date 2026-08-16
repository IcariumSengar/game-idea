extends Button

## Text-only menu item styled like a fantasy title screen: pale gray by
## default, gold with flourish lines above/below when hovered/focused.
## No button box -- just color, scale, and drawn accents.

const NORMAL_COLOR: Color = Color(0.82, 0.82, 0.85, 1.0)
const HOVER_COLOR: Color = Color(0.95, 0.85, 0.35, 1.0)
const LINE_COLOR: Color = Color(0.95, 0.85, 0.35, 0.9)
const HOVER_SCALE: float = 1.08
const TWEEN_DURATION: float = 0.15

var _hover_amount: float = 0.0


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	add_theme_color_override("font_color", NORMAL_COLOR)
	add_theme_color_override("font_hover_color", HOVER_COLOR)
	add_theme_color_override("font_pressed_color", HOVER_COLOR)
	add_theme_color_override("font_focus_color", HOVER_COLOR)
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	_animate_hover(1.0)


func _on_mouse_exited() -> void:
	_animate_hover(0.0)


func _on_pressed() -> void:
	AudioManager.play("click")


func _animate_hover(target: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hover_amount, _hover_amount, target, TWEEN_DURATION)
	tween.tween_property(
		self, "scale", Vector2.ONE * lerpf(1.0, HOVER_SCALE, target), TWEEN_DURATION
	)


func _set_hover_amount(value: float) -> void:
	_hover_amount = value
	queue_redraw()


func _draw() -> void:
	if _hover_amount <= 0.001:
		return
	var line_color := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, LINE_COLOR.a * _hover_amount)
	var half_width: float = size.x * 0.55 * _hover_amount
	var center_x: float = size.x / 2.0
	draw_line(
		Vector2(center_x - half_width, 1.0), Vector2(center_x + half_width, 1.0), line_color, 2.0
	)
	draw_line(
		Vector2(center_x - half_width, size.y - 1.0),
		Vector2(center_x + half_width, size.y - 1.0),
		line_color,
		2.0
	)
