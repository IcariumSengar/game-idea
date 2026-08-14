class_name Arena
extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const LOOT_SCENE: PackedScene = preload("res://scenes/loot.tscn")
const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const SHAKE_DURATION: float = 0.15
const SHAKE_MAGNITUDE: float = 8.0
const RAMP_DURATION: float = 45.0
const SPAWN_INTERVAL_START: float = 1.0
const SPAWN_INTERVAL_MIN: float = 0.25
const ENEMY_HP_SCALE_MIN: float = 1.5
const ENEMY_HP_SCALE_MAX: float = 3.0
const ENEMY_SPEED_SCALE_MIN: float = 1.6
const ENEMY_SPEED_SCALE_MAX: float = 2.4
const FLOOR_COLUMNS: int = 32
const FLOOR_ROWS: int = 18
const FLOOR_VARIANT_CHANCE: float = 0.18

var _shake_time_left: float = 0.0
var _run_time: float = 0.0

@onready var _spawn_timer: Timer = $EnemySpawnTimer
@onready var _floor: TileMapLayer = $Floor


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	player.hit.connect(_on_player_hit)
	_populate_floor()


func _populate_floor() -> void:
	for x in FLOOR_COLUMNS:
		for y in FLOOR_ROWS:
			var variant_x := 0
			if randf() < FLOOR_VARIANT_CHANCE:
				variant_x = randi_range(1, 7)
			_floor.set_cell(Vector2i(x, y), 0, Vector2i(variant_x, 0))


func _process(delta: float) -> void:
	_run_time += delta
	if _shake_time_left <= 0.0:
		return
	_shake_time_left = max(_shake_time_left - delta, 0.0)
	if _shake_time_left > 0.0:
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAGNITUDE
	else:
		position = Vector2.ZERO


func _on_player_hit() -> void:
	_shake_time_left = SHAKE_DURATION


func get_run_time() -> float:
	return _run_time


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
