extends CanvasLayer

const HP_COLOR_HIGH: Color = Color(0.3, 0.85, 0.4)
const HP_COLOR_MID: Color = Color(0.9, 0.8, 0.2)
const HP_COLOR_LOW: Color = Color(0.9, 0.25, 0.25)
const LOOT_COLOR_EMPTY: Color = Color(0.3, 0.65, 0.9)
const LOOT_COLOR_FULL: Color = Color(0.9, 0.35, 0.2)

var _backpack_capacity: int
var _current_loot: int = 0

@onready var _hp_bar: StatBar = $StatsPanel/Margin/VBox/HPRow/HPBar
@onready var _hp_value: Label = $StatsPanel/Margin/VBox/HPRow/HPValue
@onready var _loot_bar: StatBar = $StatsPanel/Margin/VBox/LootRow/LootBar
@onready var _loot_value: Label = $StatsPanel/Margin/VBox/LootRow/LootValue
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _game_over_label: Label = $GameOverPanel/GameOverMargin/GameOverVBox/GameOverLabel


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	_backpack_capacity = player.backpack_capacity
	player.hp_changed.connect(_on_hp_changed)
	player.loot_changed.connect(_on_loot_changed)
	player.died.connect(_on_player_died)


func _on_hp_changed(current: float, max_hp: float) -> void:
	var fraction: float = current / max_hp if max_hp > 0.0 else 0.0
	_hp_bar.update(fraction, _hp_color(fraction))
	_hp_value.text = "%d/%d" % [roundi(current), roundi(max_hp)]


func _on_loot_changed(current: int) -> void:
	_current_loot = current
	var fraction: float = float(current) / float(_backpack_capacity) if _backpack_capacity > 0 else 0.0
	_loot_bar.update(fraction, LOOT_COLOR_EMPTY.lerp(LOOT_COLOR_FULL, fraction))
	_loot_value.text = "%d/%d" % [current, _backpack_capacity]


func _on_player_died() -> void:
	MetaProgression.add_currency(_current_loot)
	_game_over_label.text = "YOU DIED\n\nLoot collected: %d" % _current_loot
	_game_over_panel.show()
	get_tree().paused = true


func _hp_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return HP_COLOR_MID.lerp(HP_COLOR_HIGH, (fraction - 0.5) * 2.0)
	return HP_COLOR_LOW.lerp(HP_COLOR_MID, fraction * 2.0)


func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/shop.tscn")
