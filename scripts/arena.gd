extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)


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
