extends CanvasLayer

const HP_COLOR_HIGH: Color = Color(0.3, 0.85, 0.4)
const HP_COLOR_MID: Color = Color(0.9, 0.8, 0.2)
const HP_COLOR_LOW: Color = Color(0.9, 0.25, 0.25)

var _backpack_capacity: int
var _player: Player

@onready var _hp_bar: StatBar = $StatsPanel/Margin/VBox/HPRow/HPBar
@onready var _hp_value: Label = $StatsPanel/Margin/VBox/HPRow/HPValue
@onready var _loot_grid: BackpackGrid = $StatsPanel/Margin/VBox/LootRow/LootGrid
@onready var _loot_value: Label = $StatsPanel/Margin/VBox/LootRow/LootValue
@onready var _stats_label: Label = $StatsPanel/Margin/VBox/MetaStatsLabel
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _game_over_label: Label = $GameOverPanel/GameOverMargin/GameOverVBox/GameOverLabel


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_backpack_capacity = _player.backpack_capacity
	_player.hp_changed.connect(_on_hp_changed)
	_player.loot_changed.connect(_on_loot_changed)
	_player.died.connect(_on_player_died)
	_stats_label.text = (
		"Speed: %d   Pickup Range: %d   Capacity: %d"
		% [_player.speed, _player.pickup_range, _player.backpack_capacity]
	)
	_on_loot_changed(_player.backpack)


func _on_hp_changed(current: float, max_hp: float) -> void:
	var fraction: float = current / max_hp if max_hp > 0.0 else 0.0
	_hp_bar.update(fraction, _hp_color(fraction))
	_hp_value.text = "%d/%d" % [roundi(current), roundi(max_hp)]


func _on_loot_changed(backpack: Dictionary) -> void:
	_loot_grid.update(backpack, _backpack_capacity)
	_loot_value.text = "%d/%d" % [backpack.size(), _backpack_capacity]


func _on_player_died() -> void:
	var total_value := _player.get_total_loot_value()
	var arena: Arena = get_parent()
	var seconds_survived := arena.get_run_time()
	MetaProgression.award_run_end_currency(total_value, seconds_survived)
	MetaProgression.save()
	_game_over_label.text = (
		"YOU DIED\n\nLoot value collected: %d\nTime survived: %ds"
		% [total_value, roundi(seconds_survived)]
	)
	_game_over_panel.show()
	get_tree().paused = true


func _hp_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return HP_COLOR_MID.lerp(HP_COLOR_HIGH, (fraction - 0.5) * 2.0)
	return HP_COLOR_LOW.lerp(HP_COLOR_MID, fraction * 2.0)


func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/shop.tscn")
