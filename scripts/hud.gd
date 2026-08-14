extends CanvasLayer

var _backpack_capacity: int
var _current_loot: int = 0

@onready var _hp_label: Label = $HPLabel
@onready var _loot_label: Label = $LootLabel
@onready var _game_over_label: Label = $GameOverLabel


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	_backpack_capacity = player.backpack_capacity
	player.hp_changed.connect(_on_hp_changed)
	player.loot_changed.connect(_on_loot_changed)
	player.died.connect(_on_player_died)


func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_label.text = "HP: %d / %d" % [roundi(current), roundi(max_hp)]


func _on_loot_changed(current: int) -> void:
	_current_loot = current
	_loot_label.text = "Backpack: %d / %d" % [current, _backpack_capacity]


func _on_player_died() -> void:
	_game_over_label.text = "YOU DIED\n\nLoot collected: %d" % _current_loot
	_game_over_label.show()
	get_tree().paused = true
