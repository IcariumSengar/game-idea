extends CanvasLayer

var _backpack_capacity: int
var _current_loot: int = 0

@onready var _hp_label: Label = $HPLabel
@onready var _loot_label: Label = $LootLabel
@onready var _stats_label: Label = $StatsLabel
@onready var _game_over_label: Label = $GameOverLabel
@onready var _continue_button: Button = $ContinueButton


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	_backpack_capacity = player.backpack_capacity
	player.hp_changed.connect(_on_hp_changed)
	player.loot_changed.connect(_on_loot_changed)
	player.died.connect(_on_player_died)
	_stats_label.text = (
		"Speed: %d   Pickup Range: %d   Backpack Capacity: %d"
		% [player.speed, player.pickup_range, player.backpack_capacity]
	)


func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_label.text = "HP: %d / %d" % [roundi(current), roundi(max_hp)]


func _on_loot_changed(current: int) -> void:
	_current_loot = current
	_loot_label.text = "Backpack: %d / %d" % [current, _backpack_capacity]


func _on_player_died() -> void:
	MetaProgression.add_currency(_current_loot)
	_game_over_label.text = "YOU DIED\n\nLoot collected: %d" % _current_loot
	_game_over_label.show()
	_continue_button.show()
	get_tree().paused = true


func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/shop.tscn")
