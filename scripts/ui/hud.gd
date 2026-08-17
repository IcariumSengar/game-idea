extends CanvasLayer

const HP_COLOR_HIGH: Color = Color(0.3, 0.85, 0.4)
const HP_COLOR_MID: Color = Color(0.9, 0.8, 0.2)
const HP_COLOR_LOW: Color = Color(0.9, 0.25, 0.25)
const STARDUST_UPDATE_INTERVAL: float = 0.1
const TIER_ORDER: Array[StringName] = [
	&"common", &"uncommon", &"rare", &"epic", &"mythic", &"legendary"
]

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/fx/floating_text.tscn")
## Enemy-tier unlocks, per DESIGN.md's Enemy Types table -- each new tier
## also unlocks rarer loot (Bruiser can drop Epic, Elite Epic/Mythic,
## Boss Mythic/Legendary), but that's otherwise invisible: a run that
## never survives past Phase 1 has no way to know progression exists at
## all. Announced the same way combo completions are (spell_caster.gd's
## _spawn_combo_label), above the player.
const PHASE_LABELS: Dictionary = {2: "BRUISERS!", 3: "ELITES!"}
const PHASE_LABEL_COLORS: Dictionary = {2: Color(0.9, 0.55, 0.25), 3: Color(0.85, 0.3, 0.85)}
const BOSS_LABEL: String = "BOSS!"
const BOSS_LABEL_COLOR: Color = Color(0.95, 0.2, 0.25)
const PHASE_LABEL_OFFSET: Vector2 = Vector2(0.0, -48.0)
const PHASE_LABEL_FONT_SIZE: int = 24

var _backpack_capacity: int
var _player: Player
var _stardust_update_timer: float = 0.0
var _last_phase: int = 1
var _boss_announced: bool = false

@onready var _arena: Arena = get_parent()
@onready var _time_value: Label = %TimeValue
@onready var _essence_value: Label = %EssenceValue
@onready var _stardust_value: Label = %StardustValue
@onready var _hp_bar: StatBar = $StatsPanel/Margin/VBox/HPRow/HPBar
@onready var _hp_value: Label = $StatsPanel/Margin/VBox/HPRow/HPValue
@onready var _loot_grid: BackpackGrid = $StatsPanel/Margin/VBox/LootRow/LootGrid
@onready var _loot_value: Label = $StatsPanel/Margin/VBox/LootRow/LootValue
@onready var _stats_label: Label = $StatsPanel/Margin/VBox/MetaStatsLabel
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _game_over_circle: Control = $GameOverCircle
@onready var _summary_body: RichTextLabel = %SummaryBody
@onready var _pause_panel: PanelContainer = $PausePanel


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_backpack_capacity = _player.backpack_capacity
	_player.hp_changed.connect(_on_hp_changed)
	_player.loot_changed.connect(_on_loot_changed)
	_player.died.connect(_on_player_died)
	_stats_label.text = (
		"Swiftness: %d   Gleam: %d   Bearing: %d"
		% [_player.speed, _player.pickup_range, _player.backpack_capacity]
	)
	_on_loot_changed(_player.backpack)


func _process(delta: float) -> void:
	_time_value.text = _format_time(_arena.get_run_time())
	_check_phase_announcements()

	_stardust_update_timer += delta
	if _stardust_update_timer >= STARDUST_UPDATE_INTERVAL:
		_stardust_update_timer = 0.0
		var stardust: float = _arena.get_run_time() * MetaProgression.BACKPACK_CURRENCY_PER_SECOND
		_stardust_value.text = "%.1f" % stardust


func _check_phase_announcements() -> void:
	var phase := _arena.get_phase()
	if phase != _last_phase:
		_last_phase = phase
		if PHASE_LABELS.has(phase):
			_spawn_phase_label(PHASE_LABELS[phase], PHASE_LABEL_COLORS[phase])
	if not _boss_announced and _arena.get_run_time() >= Arena.BOSS_SPAWN_TIME:
		_boss_announced = true
		_spawn_phase_label(BOSS_LABEL, BOSS_LABEL_COLOR)


func _spawn_phase_label(label: String, color: Color) -> void:
	var text: Node2D = FLOATING_TEXT_SCENE.instantiate()
	text.position = _player.position + PHASE_LABEL_OFFSET
	_arena.add_child(text)
	text.setup(label, color, PHASE_LABEL_FONT_SIZE)


## Escape toggles the pause menu. HUD is process_mode ALWAYS specifically
## so this keeps firing after get_tree().paused is set -- otherwise
## there'd be no way to detect the second press that resumes. Ignored
## while the death screen is already up (already paused for a different
## reason -- don't stack a second overlay on top of it).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _game_over_panel.visible:
		if get_tree().paused:
			_resume()
		else:
			_pause_panel.show()
			get_tree().paused = true


func _on_hp_changed(current: float, max_hp: float) -> void:
	var fraction: float = current / max_hp if max_hp > 0.0 else 0.0
	_hp_bar.update(fraction, _hp_color(fraction))
	_hp_value.text = "%d/%d" % [roundi(current), roundi(max_hp)]


func _on_loot_changed(backpack: Dictionary) -> void:
	_loot_grid.update(backpack, _backpack_capacity)
	_loot_value.text = "%d/%d" % [_player.get_slots_used(), _backpack_capacity]
	_essence_value.text = "%d" % _player.get_total_loot_value()


func _on_player_died() -> void:
	var total_value := _player.get_total_loot_value()
	var seconds_survived := _arena.get_run_time()
	var stardust_earned := roundi(seconds_survived * MetaProgression.BACKPACK_CURRENCY_PER_SECOND)
	var previous_best := MetaProgression.update_best_run(seconds_survived)

	MetaProgression.award_run_end_currency(total_value, seconds_survived)
	SaveManager.save()

	if PlaytestHarness.active:
		return

	_summary_body.text = _build_summary_bbcode(
		total_value, stardust_earned, seconds_survived, previous_best
	)

	AudioManager.play("player_death")
	await _arena.play_death_shake()
	_show_game_over_panel()
	get_tree().paused = true


func _build_summary_bbcode(
	total_value: int, stardust_earned: int, seconds_survived: float, previous_best: float
) -> String:
	var lines: Array[String] = []
	lines.append("[color=#e066a3]Lost to the Void[/color]")
	lines.append("")
	lines.append("Time Survived: [b]%s[/b]" % _format_time(seconds_survived))
	lines.append("Difficulty Reached: [b]Phase %d[/b]" % _arena.get_phase())
	lines.append("")
	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append("[b]REWARDS THIS RUN[/b]")
	lines.append("[color=#e6cc4d]Essence:[/color] ↑ %d" % total_value)
	lines.append("[color=#4dbfe6]Stardust:[/color] ↑ %d" % stardust_earned)

	var loot_lines := _build_loot_breakdown()
	if not loot_lines.is_empty():
		lines.append("")
		lines.append("[color=#666666]────────────────────────[/color]")
		lines.append("[b]LOOT COLLECTED[/b]")
		lines.append_array(loot_lines)

	lines.append("")
	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append(
		(
			"[color=#999999]Max Backpack Fill: %d%%[/color]"
			% roundi(_player.get_max_fill_ratio() * 100.0)
		)
	)
	lines.append("[color=#999999]Enemies Killed: %d[/color]" % _arena.get_enemies_killed())

	if previous_best > 0.0:
		lines.append("")
		lines.append(
			"[color=#888888]Highest Previous Run: %s[/color]" % _format_time(previous_best)
		)

	return "\n".join(lines)


func _build_loot_breakdown() -> Array[String]:
	var lines: Array[String] = []
	for tier_id: StringName in TIER_ORDER:
		var count: int = _player.backpack.get(tier_id, 0)
		if count <= 0:
			continue
		var def := LootTypes.get_type(tier_id)
		var color_hex: String = def.color.to_html(false) if def != null else "eeeeee"
		var tier_name: String = def.display_name if def != null else String(tier_id).capitalize()
		lines.append("[color=#%s]%s[/color]  x%d" % [color_hex, tier_name, count])
	return lines


func _format_time(seconds: float) -> String:
	var total_sec: int = roundi(seconds)
	var minutes: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [minutes, secs]


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
	SceneTransition.goto_scene("res://scenes/ui/shop.tscn")


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	SceneTransition.goto_scene("res://scenes/arena.tscn")


func _resume() -> void:
	_pause_panel.hide()
	get_tree().paused = false


func _on_resume_button_pressed() -> void:
	_resume()


## Abandons the run -- no death, no run-end currency award (same as
## alt-F4ing mid-run), just banks whatever's already been saved from
## previous runs and backs out.
func _on_quit_to_menu_button_pressed() -> void:
	SaveManager.save()
	get_tree().paused = false
	SceneTransition.goto_scene("res://scenes/ui/main_menu.tscn")


func _on_quit_game_button_pressed() -> void:
	SaveManager.save()
	get_tree().quit()
