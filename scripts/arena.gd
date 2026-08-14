extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const SHAKE_DURATION: float = 0.15
const SHAKE_MAGNITUDE: float = 8.0

var _shake_time_left: float = 0.0


func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	player.hit.connect(_on_player_hit)


func _process(delta: float) -> void:
	if _shake_time_left <= 0.0:
		return
	_shake_time_left = max(_shake_time_left - delta, 0.0)
	if _shake_time_left > 0.0:
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAGNITUDE
	else:
		position = Vector2.ZERO


func _on_player_hit() -> void:
	_shake_time_left = SHAKE_DURATION


func _on_enemy_spawn_timer_timeout() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.position = _random_edge_position()
	add_child(enemy)


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
