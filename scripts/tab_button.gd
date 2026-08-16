class_name TabButton
extends Button

## Toggle-style tab button (Player/Backpack skill-tree pages). Unlike
## menu_link_button.gd's hover-only accent, the active tab's color and
## underline persist after the click via set_active(), so the current
## page stays visually distinct once the mouse moves away.

const INACTIVE_COLOR: Color = Color(0.6, 0.6, 0.63, 1.0)
const HOVER_SCALE: float = 1.05
const TWEEN_DURATION: float = 0.15
const UNDERLINE_HEIGHT: float = 2.5
const UNDERLINE_MARGIN: float = 4.0

@export var accent_color: Color = Color(0.85, 0.7, 0.35, 1.0)

var is_active: bool = false


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	mouse_entered.connect(func() -> void: _animate_hover(1.0))
	mouse_exited.connect(func() -> void: _animate_hover(0.0))
	pressed.connect(func() -> void: AudioManager.play("click"))
	_update_colors()


func set_active(active: bool) -> void:
	is_active = active
	_update_colors()
	queue_redraw()


func _update_colors() -> void:
	var idle_color: Color = accent_color if is_active else INACTIVE_COLOR
	add_theme_color_override("font_color", idle_color)
	add_theme_color_override("font_hover_color", accent_color)
	add_theme_color_override("font_pressed_color", accent_color)
	add_theme_color_override("font_focus_color", idle_color)


func _animate_hover(target: float) -> void:
	var tween := create_tween()
	tween.tween_property(
		self, "scale", Vector2.ONE * lerpf(1.0, HOVER_SCALE, target), TWEEN_DURATION
	)


func _draw() -> void:
	if not is_active:
		return
	draw_line(
		Vector2(UNDERLINE_MARGIN, size.y - 1.0),
		Vector2(size.x - UNDERLINE_MARGIN, size.y - 1.0),
		accent_color,
		UNDERLINE_HEIGHT
	)
