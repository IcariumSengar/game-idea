extends Control


func _ready() -> void:
	var version := _read_version()
	$CenterContainer/Label.text = "game-idea v%s" % version


func _read_version() -> String:
	var file := FileAccess.open("res://VERSION", FileAccess.READ)
	if file == null:
		return "?"
	return file.get_as_text().strip_edges()
