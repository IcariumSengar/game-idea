extends Button

## Small hover/press scale juice shared by every menu/shop button so
## interactive UI feels responsive.

const HOVER_SCALE: float = 1.05
const PRESS_SCALE: float = 0.96
const TWEEN_DURATION: float = 0.09

var _hovering: bool = false


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	_hovering = true
	if not disabled:
		_tween_scale(HOVER_SCALE)


func _on_mouse_exited() -> void:
	_hovering = false
	_tween_scale(1.0)


func _on_button_down() -> void:
	_tween_scale(PRESS_SCALE)


func _on_button_up() -> void:
	_tween_scale(HOVER_SCALE if _hovering else 1.0)


func _on_pressed() -> void:
	AudioManager.play("click")


func _tween_scale(target: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target, TWEEN_DURATION)
