class_name Arena
extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const LOOT_SCENE: PackedScene = preload("res://scenes/loot.tscn")
const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const SHAKE_DURATION: float = 0.15
const SHAKE_MAGNITUDE: float = 8.0
const DEATH_SHAKE_DURATION: float = 0.4
const DEATH_SHAKE_MAGNITUDE: float = 16.0
const HIT_STOP_DURATION: float = 0.05
const HIT_STOP_SCALE: float = 0.05
const DEATH_HIT_STOP_DURATION: float = 0.12
const RAMP_DURATION: float = 45.0
const SPAWN_INTERVAL_START: float = 1.0
const SPAWN_INTERVAL_MIN: float = 0.25
const ENEMY_HP_SCALE_MIN: float = 1.5
const ENEMY_HP_SCALE_MAX: float = 3.0
const ENEMY_SPEED_SCALE_MIN: float = 1.6
const ENEMY_SPEED_SCALE_MAX: float = 2.4

var _shake_time_left: float = 0.0
var _shake_magnitude: float = SHAKE_MAGNITUDE
var _run_time: float = 0.0
var _enemies_killed: int = 0

@onready var _spawn_timer: Timer = $EnemySpawnTimer


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	player.hit.connect(_on_player_hit)


func _process(delta: float) -> void:
	_run_time += delta
	if _shake_time_left <= 0.0:
		return
	_shake_time_left = max(_shake_time_left - delta, 0.0)
	if _shake_time_left > 0.0:
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_magnitude
	else:
		position = Vector2.ZERO


func _on_player_hit() -> void:
	_shake_time_left = SHAKE_DURATION
	_shake_magnitude = SHAKE_MAGNITUDE
	_hit_stop(HIT_STOP_DURATION)


## Self-contained (doesn't rely on _process) so it still plays out fully
## when awaited by HUD before the tree pauses for the game-over screen.
func play_death_shake() -> void:
	Engine.time_scale = HIT_STOP_SCALE
	await get_tree().create_timer(DEATH_HIT_STOP_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0
	var elapsed: float = 0.0
	while elapsed < DEATH_SHAKE_DURATION:
		elapsed += get_process_delta_time()
		var falloff: float = 1.0 - elapsed / DEATH_SHAKE_DURATION
		position = (
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			* DEATH_SHAKE_MAGNITUDE
			* falloff
		)
		await get_tree().process_frame
	position = Vector2.ZERO


func _hit_stop(duration: float) -> void:
	Engine.time_scale = HIT_STOP_SCALE
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


func get_run_time() -> float:
	return _run_time


func get_enemies_killed() -> int:
	return _enemies_killed


## Difficulty phase (1/2/3) purely as a time-elapsed indicator, matching
## the phase timing already locked in for v7's enemy-tier spawn mix --
## usable now even though the enemy tiers themselves aren't built yet.
func get_phase() -> int:
	if _run_time < 20.0:
		return 1
	if _run_time < 40.0:
		return 2
	return 3


func _on_enemy_spawn_timer_timeout() -> void:
	var ramp: float = clamp(_run_time / RAMP_DURATION, 0.0, 1.0)
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.position = _random_edge_position()
	enemy.max_hp *= lerp(ENEMY_HP_SCALE_MIN, ENEMY_HP_SCALE_MAX, ramp)
	enemy.speed *= lerp(ENEMY_SPEED_SCALE_MIN, ENEMY_SPEED_SCALE_MAX, ramp)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	_spawn_timer.wait_time = lerp(SPAWN_INTERVAL_START, SPAWN_INTERVAL_MIN, ramp)


func _on_enemy_died(enemy: Enemy) -> void:
	_enemies_killed += 1
	var loot: Loot = LOOT_SCENE.instantiate()
	loot.position = enemy.position
	loot.type_id = LootTypes.pick_random_type().id
	add_child(loot)


func _random_edge_position() -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf() * ARENA_SIZE.x, 0.0)
		1:
			return Vector2(randf() * ARENA_SIZE.x, ARENA_SIZE.y)
		2:
			return Vector2(0.0, randf() * ARENA_SIZE.y)
		_:
			return Vector2(ARENA_SIZE.x, randf() * ARENA_SIZE.y)
