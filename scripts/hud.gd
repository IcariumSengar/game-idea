extends CanvasLayer

@onready var _hp_label: Label = $HPLabel


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	player.hp_changed.connect(_on_hp_changed)


func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_label.text = "HP: %d / %d" % [roundi(current), roundi(max_hp)]
