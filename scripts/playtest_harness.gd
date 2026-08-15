extends Node

## Headless auto-playtest loop. Launch with:
##
##   Godot.exe --headless --path . -- --playtest \
##       [--playtest-runs=N] [--playtest-seed=stat_id:level,...]
##
## Runs N full auto-played runs back to back (bot-controlled movement from
## playtest_bot_ai.gd; spells already auto-cast per v10), then prints an
## aggregate survival/economy report to stdout and quits. Everything after
## the bare `--` are user args Godot passes through untouched -- `--` alone
## is what OS.get_cmdline_user_args() filters on, keeping this separate
## from engine flags like --headless.
##
## Uses MetaProgression.PLAYTEST_SLOT so it never reads or writes the
## player's real save data (see meta_progression.gd's _playtest_mode).

const DEFAULT_RUNS: int = 15
const SEED_ARG_PREFIX: String = "--playtest-seed="
const RUNS_ARG_PREFIX: String = "--playtest-runs="
## Godot's real-time frame pacing isn't something --fixed-fps reliably
## bypasses in practice, so the sim is sped up the direct way instead: more
## game-seconds simulated per real second. Moderate, to avoid physics
## tunneling at extreme deltas. Camera juice (screen shake/hit-stop) is
## skipped in playtest mode (see arena.gd/hud.gd) since it fights this by
## repeatedly resetting Engine.time_scale to 1.0.
const TIME_SCALE: float = 8.0

var active: bool = false

var _runs_remaining: int = 0
var _results: Array[Dictionary] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--playtest" in args:
		return
	active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = TIME_SCALE
	_runs_remaining = _parse_int_arg(args, RUNS_ARG_PREFIX, DEFAULT_RUNS)
	_apply_seed(args)
	_begin()


## Racing change_scene_to_file() against the engine's own initial load of
## run/main_scene (main_menu.tscn) loses the race silently -- wait for that
## first scene to actually be current before ever touching scene changes.
func _begin() -> void:
	while get_tree().current_scene == null:
		await get_tree().process_frame
	_start_next_run()


func _parse_int_arg(args: PackedStringArray, prefix: String, default_value: int) -> int:
	for arg in args:
		if arg.begins_with(prefix):
			return int(arg.substr(prefix.length()))
	return default_value


func _apply_seed(args: PackedStringArray) -> void:
	for arg in args:
		if not arg.begins_with(SEED_ARG_PREFIX):
			continue
		for pair in arg.substr(SEED_ARG_PREFIX.length()).split(","):
			var parts := pair.split(":")
			if parts.size() == 2:
				MetaProgression.debug_set_level(StringName(parts[0]), int(parts[1]))


func _start_next_run() -> void:
	if _runs_remaining <= 0:
		_print_report()
		get_tree().quit()
		return
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/arena.tscn")
	var player := await _await_player()
	if player == null:
		push_error("Playtest harness: player never appeared after scene change, aborting")
		get_tree().quit()
		return
	var bot := PlaytestBotAI.new()
	player.add_child(bot)
	bot.setup(player)
	player.died.connect(_on_run_finished.bind(player), CONNECT_ONE_SHOT)


## change_scene_to_file() defers the actual swap, and isn't reliably done by
## the very next frame -- poll instead of assuming a fixed number of frames.
func _await_player() -> Player:
	for i in 60:
		await get_tree().process_frame
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null:
			return player
	return null


func _on_run_finished(player: Player) -> void:
	var arena := get_tree().current_scene as Arena
	(
		_results
		. append(
			{
				"survival_time": arena.get_run_time(),
				"phase_reached": arena.get_phase(),
				"enemies_killed": arena.get_enemies_killed(),
				"loot_value": player.get_total_loot_value(),
				"max_fill_ratio": player.get_max_fill_ratio(),
			}
		)
	)
	_runs_remaining -= 1
	call_deferred("_start_next_run")


func _print_report() -> void:
	print("=== PLAYTEST REPORT (%d runs) ===" % _results.size())
	var total_time := 0.0
	var total_kills := 0
	var total_loot := 0
	var max_time := 0.0
	var min_time: float = INF
	for i in _results.size():
		var r: Dictionary = _results[i]
		print(
			(
				"Run %2d: %5.1fs  phase %d  kills %2d  loot %3d  fill %3d%%"
				% [
					i + 1,
					r.survival_time,
					r.phase_reached,
					r.enemies_killed,
					r.loot_value,
					roundi(r.max_fill_ratio * 100.0),
				]
			)
		)
		total_time += r.survival_time
		total_kills += r.enemies_killed
		total_loot += r.loot_value
		max_time = max(max_time, r.survival_time)
		min_time = min(min_time, r.survival_time)
	var n: int = max(_results.size(), 1)
	print("---")
	print("Avg survival: %.1fs  (min %.1fs, max %.1fs)" % [total_time / n, min_time, max_time])
	print(
		"Avg kills: %.1f   Avg loot value: %.1f" % [float(total_kills) / n, float(total_loot) / n]
	)
