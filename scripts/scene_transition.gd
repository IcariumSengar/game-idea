extends CanvasLayer

## Global fade-to-black scene transition. Call goto_scene() instead of
## get_tree().change_scene_to_file() directly so every screen change gets a
## consistent fade instead of a hard cut.

const FADE_DURATION: float = 0.16

var _fade_rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.02, 0.02, 0.02, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)


func goto_scene(path: String) -> void:
	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await fade_out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
