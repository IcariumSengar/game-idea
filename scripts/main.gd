extends Control


func _ready() -> void:
	# Always show slot selector at startup to let player choose which save to use
	get_tree().change_scene_to_file("res://scenes/save_slot_selector.tscn")
	return


func _read_version() -> String:
	var file := FileAccess.open("res://VERSION", FileAccess.READ)
	if file == null:
		return "?"
	return file.get_as_text().strip_edges()
