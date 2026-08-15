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
@onready var _game_over_circle: Control = $GameOverCircle
@onready var _game_over_label: Label = $GameOverPanel/GameOverMargin/GameOverVBox/GameOverLabel


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_backpack_capacity = _player.backpack_capacity
	_player.hp_changed.connect(_on_hp_changed)
	_player.loot_changed.connect(_on_loot_changed)
	_player.died.connect(_on_player_died)
	_stats_label.text = (
		"Speed: %d   Magnet Range: %d   Capacity: %d"
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
	CloudSync.sync_now()
	_game_over_label.text = (
		"LOST TO THE VOID\n\nEssence collected: %d\nTime survived: %ds"
		% [total_value, roundi(seconds_survived)]
	)
	AudioManager.play("player_death")
	await arena.play_death_shake()
	_show_game_over_panel()
	get_tree().paused = true


func _show_game_over_panel() -> void:
	_game_over_circle.show()
	_game_over_panel.show()
	_game_over_panel.pivot_offset = _game_over_panel.size / 2.0
	_game_over_panel.scale = Vector2.ONE * 0.7
	_game_over_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	(
		tween
		. tween_property(_game_over_panel, "scale", Vector2.ONE, 0.25)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(_game_over_panel, "modulate:a", 1.0, 0.2)


func _hp_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return HP_COLOR_MID.lerp(HP_COLOR_HIGH, (fraction - 0.5) * 2.0)
	return HP_COLOR_LOW.lerp(HP_COLOR_MID, fraction * 2.0)


func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	SceneTransition.goto_scene("res://scenes/shop.tscn")
