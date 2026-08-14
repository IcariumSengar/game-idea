extends Node2D

## Floating combat-text popup: rises, drifts sideways, fades, then frees
## itself. Used for damage numbers and loot-value pickups.

const RISE_DISTANCE: float = 36.0
const DURATION: float = 0.7
const DRIFT_X_MAX: float = 10.0
const START_SCALE: float = 0.6

@onready var _label: Label = $Label


func setup(text: String, color: Color, font_size: int = 20) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_font_size_override("font_size", font_size)


func _ready() -> void:
	scale = Vector2.ONE * START_SCALE
	var drift_x := randf_range(-DRIFT_X_MAX, DRIFT_X_MAX)
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "position", position + Vector2(drift_x, -RISE_DISTANCE), DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(_label, "modulate:a", 0.0, DURATION * 0.65).set_delay(DURATION * 0.35)
	tween.chain().tween_callback(queue_free)
