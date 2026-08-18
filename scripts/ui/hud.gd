extends CanvasLayer

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
## Phase 4 (DESIGN.md's "Phase 4: the arena becomes the antagonist,"
## 2026-08-17) gets the same announcement treatment every other phase
## transition already has -- the closing safe zone is otherwise a purely
## visual reveal (arena.gd's own _draw()), easy to miss the moment it
## actually starts.
const PHASE_LABELS: Dictionary = {2: "BRUISERS!", 3: "ELITES!", 4: "THE ARENA CLOSES IN!"}
const PHASE_LABEL_COLORS: Dictionary = {
	2: Palette.PHASE_2_LABEL, 3: Palette.PHASE_3_LABEL, 4: Palette.PHASE_4_LABEL
}
const BOSS_LABEL: String = "BOSS!"
const BOSS_LABEL_COLOR: Color = Palette.PHASE_BOSS_LABEL
const PHASE_LABEL_OFFSET: Vector2 = Vector2(0.0, -48.0)
const PHASE_LABEL_FONT_SIZE: int = 24

## Surfacing (DESIGN.md's "the hoard is losable," decided 2026-08-18): a
## voluntary extraction window opens every SURFACE_INTERVAL seconds
## survived, offering to bank the run early at SURFACE_BONUS_MULTIPLIER
## instead of pushing on toward death.
const SURFACE_INTERVAL: float = 30.0
const SURFACE_BONUS_MULTIPLIER: float = 1.1

var _backpack_capacity: int
var _player: Player
var _spell_caster: SpellCaster
var _stardust_update_timer: float = 0.0
var _last_phase: int = 1
var _boss_announced: bool = false
var _next_surface_time: float = SURFACE_INTERVAL

@onready var _arena: Arena = get_parent()
@onready var _time_value: Label = %TimeValue
@onready var _essence_value: Label = %EssenceValue
@onready var _stardust_value: Label = %StardustValue
@onready var _hp_bar: StatBar = $StatsPanel/Margin/VBox/HPRow/HPBar
@onready var _hp_value: Label = $StatsPanel/Margin/VBox/HPRow/HPValue
@onready var _loot_grid: BackpackGrid = $StatsPanel/Margin/VBox/LootRow/LootGrid
@onready var _loot_value: Label = $StatsPanel/Margin/VBox/LootRow/LootValue
@onready var _attunement_bar: StatBar = $StatsPanel/Margin/VBox/AttunementRow/AttunementBar
@onready var _stats_label: Label = $StatsPanel/Margin/VBox/MetaStatsLabel
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _game_over_circle: Control = $GameOverCircle
@onready var _summary_body: RichTextLabel = %SummaryBody
@onready var _pause_panel: PanelContainer = $PausePanel
@onready var _surfacing_panel: PanelContainer = $SurfacingPanel
@onready var _resume_button: Button = $PausePanel/PauseMargin/PauseVBox/ResumeButton
@onready var _continue_button: Button = $GameOverPanel/GameOverMargin/GameOverVBox/ContinueButton


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_spell_caster = _player.spell_caster
	_backpack_capacity = _player.backpack_capacity
	_player.hp_changed.connect(_on_hp_changed)
	_player.loot_changed.connect(_on_loot_changed)
	_player.died.connect(_on_player_died)
	_stats_label.text = (
		"Current: %d   Gleam: %d   Hold: %d"
		% [_player.speed, _player.pickup_range, _player.backpack_capacity]
	)
	_on_loot_changed(_player.backpack)


func _process(delta: float) -> void:
	_time_value.text = _format_time(_arena.get_run_time())
	_check_phase_announcements()
	_check_surfacing_window()

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
## while the death screen or the Surfacing prompt is already up (already
## paused for a different reason -- don't stack a second overlay on top).
func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and not _game_over_panel.visible
		and not _surfacing_panel.visible
	):
		if get_tree().paused:
			_resume()
		else:
			_pause_panel.show()
			get_tree().paused = true
			_resume_button.grab_focus()


## Skipped entirely during a headless playtest batch -- the bot has no way
## to dismiss the prompt, and pausing the tree for an input it'll never
## give would soft-lock every run past the first window.
func _check_surfacing_window() -> void:
	if PlaytestHarness.active:
		return
	if _game_over_panel.visible or _surfacing_panel.visible or get_tree().paused:
		return
	if _arena.get_run_time() < _next_surface_time:
		return
	_next_surface_time += SURFACE_INTERVAL
	_surfacing_panel.show()
	get_tree().paused = true


func _on_hp_changed(current: float, max_hp: float) -> void:
	var fraction: float = current / max_hp if max_hp > 0.0 else 0.0
	_hp_bar.update(fraction, _hp_color(fraction))
	_hp_value.text = "%d/%d" % [roundi(current), roundi(max_hp)]


## Combo-nearing pips (DESIGN.md's HUD + death-summary rework, 2026-08-17):
## Streak progress comes straight off SpellCaster's own tracking; Full Set
## nearness is just counting distinct tiers currently held (a tier's key
## is erased from `backpack` the instant its count hits zero, so
## `backpack.size()` already *is* that count) -- no new tracking either
## way, both are read live off state that already exists.
func _on_loot_changed(backpack: Dictionary) -> void:
	var streak_progress: float = clampf(
		float(_spell_caster.get_streak_count() - 1) / float(SpellCaster.STREAK_THRESHOLD - 1),
		0.0,
		1.0
	)
	var full_set_near: bool = backpack.size() == LootTypes.get_tier_count() - 1
	_loot_grid.update(
		backpack,
		_backpack_capacity,
		_player.get_ballast_slots(),
		_spell_caster.get_streak_tier(),
		streak_progress,
		full_set_near
	)
	_loot_value.text = "%d/%d" % [_player.get_slots_used(), _backpack_capacity]
	_essence_value.text = "%d" % _player.get_total_loot_value()

	var attunement: float = _player.get_attunement()
	_attunement_bar.update(
		attunement, Palette.ATTUNEMENT_LOW.lerp(Palette.ATTUNEMENT_HIGH, attunement)
	)


func _on_player_died() -> void:
	await _end_run(1.0, "Lost to the Void", "#e066a3", true)


## Surfacing (DESIGN.md's "the hoard is losable," decided 2026-08-18): the
## same run-end path as death, just triggered by a button instead of HP
## hitting zero, with a bonus multiplier and no death FX.
func _on_surface_now_button_pressed() -> void:
	_surfacing_panel.hide()
	await _end_run(SURFACE_BONUS_MULTIPLIER, "Surfaced Safely", "#4de6cc", false)


func _on_keep_diving_button_pressed() -> void:
	_surfacing_panel.hide()
	get_tree().paused = false


## Shared by death and Surfacing so both count identically for personal
## bests, Trophy Hall, and the save -- only the bonus multiplier, title,
## and whether the death FX plays differ.
func _end_run(
	bonus_multiplier: float, title: String, title_color: String, play_death_fx: bool
) -> void:
	var seconds_survived := _arena.get_run_time()
	var raw_value := _player.get_total_loot_value()
	var total_value := roundi(raw_value * bonus_multiplier)
	var stardust_earned := roundi(
		seconds_survived * MetaProgression.BACKPACK_CURRENCY_PER_SECOND * bonus_multiplier
	)
	var leanness := seconds_survived * (1.0 - _player.get_max_fill_ratio())
	var discards := _player.get_discards_this_run()

	## Bundled into one Dictionary rather than passed positionally --
	## _build_summary_bbcode was already at 9 args before Surfacing added
	## title/title_color/bonus_multiplier, past gdlint's 10-arg ceiling.
	var run_stats: Dictionary = {
		"total_value": total_value,
		"stardust_earned": stardust_earned,
		"seconds_survived": seconds_survived,
		"leanness": leanness,
		"discards": discards,
		"previous_time": MetaProgression.update_best_run(seconds_survived),
		"previous_essence": MetaProgression.update_best_essence(total_value),
		"previous_leanness": MetaProgression.update_best_leanness(leanness),
		"previous_discards": MetaProgression.update_best_discards(discards),
	}
	_update_trophy_hall(_player.backpack)

	MetaProgression.award_run_end_currency(raw_value, seconds_survived, bonus_multiplier)
	SaveManager.save()

	if PlaytestHarness.active:
		return

	_summary_body.text = _build_summary_bbcode(title, title_color, bonus_multiplier, run_stats)

	if play_death_fx:
		AudioManager.play("player_death")
		await _arena.play_death_shake()
	else:
		AudioManager.play("purchase")
	_show_game_over_panel()
	get_tree().paused = true


func _build_summary_bbcode(
	title: String, title_color: String, bonus_multiplier: float, run: Dictionary
) -> String:
	var lines: Array[String] = []
	lines.append("[color=%s]%s[/color]" % [title_color, title])
	if bonus_multiplier > 1.0:
		lines.append(
			(
				"[color=#4de6cc]Surfacing Bonus: +%d%%[/color]"
				% roundi((bonus_multiplier - 1.0) * 100.0)
			)
		)
	lines.append("")
	lines.append("Time Survived: [b]%s[/b]" % _format_time(run.seconds_survived))
	lines.append("Difficulty Reached: [b]Phase %d[/b]" % _arena.get_phase())
	lines.append("")
	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append("[b]REWARDS THIS RUN[/b]")
	lines.append("[color=#e6cc4d]Glow:[/color] ↑ %d" % run.total_value)
	lines.append("[color=#4dbfe6]Depth:[/color] ↑ %d" % run.stardust_earned)

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

	lines.append("")
	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append("[b]PERSONAL BESTS[/b]")
	lines.append(
		_best_line(
			"Survival Time",
			_format_time(run.seconds_survived),
			run.seconds_survived,
			run.previous_time
		)
	)
	lines.append(
		_best_line(
			"Richest",
			"%d Glow" % run.total_value,
			float(run.total_value),
			float(run.previous_essence)
		)
	)
	lines.append(_best_line("Leanest", "%.1f" % run.leanness, run.leanness, run.previous_leanness))
	lines.append(
		_best_line(
			"Most Refused", "%d" % run.discards, float(run.discards), float(run.previous_discards)
		)
	)

	return "\n".join(lines)


## One personal-best line, per DESIGN.md's "compare and show 'New Record!'
## only for whichever ones a given run actually broke, rather than always
## dumping all four." previous <= 0.0 means there's no real record yet
## (this save's first-ever run in that category) -- the tag stays off
## rather than trivially firing on a first attempt, same reasoning the
## old survival-time-only comparison already used.
func _best_line(label: String, display_value: String, current: float, previous: float) -> String:
	var is_new_record: bool = previous > 0.0 and current > previous
	var suffix: String = "  [color=#e6cc4d][b]NEW RECORD![/b][/color]" if is_new_record else ""
	return "[color=#999999]%s: %s[/color]%s" % [label, display_value, suffix]


## Trophy Hall (DESIGN.md's "A hoard you can actually see," 2026-08-17):
## checked against this run's final backpack breakdown -- see
## MetaProgression.best_loot_value's own docstring for why this reads
## each tier's fixed base value rather than a true per-item value.
func _update_trophy_hall(backpack: Dictionary) -> void:
	for type_id: StringName in backpack:
		var def := LootTypes.get_type(type_id)
		if def != null:
			MetaProgression.update_best_loot_value(type_id, def.value)


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
	_continue_button.grab_focus()


func _hp_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return Palette.HP_MID.lerp(Palette.HP_HIGH, (fraction - 0.5) * 2.0)
	return Palette.HP_LOW.lerp(Palette.HP_MID, fraction * 2.0)


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
