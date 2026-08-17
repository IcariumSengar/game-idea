class_name EnemyProjectile
extends Area2D

## Straight-line bolt fired by Elite enemies. No sprite assets exist for
## this yet, so it's a procedurally-drawn orb (see _draw() below),
## tinted to read as a hostile attack distinct from the player's UI
## palette.

const LIFETIME: float = 3.0
const SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const RADIUS: float = 6.0

@export var speed: float = 150.0
@export var damage: float = 8.0

var direction: Vector2 = Vector2.ZERO

var _time_left: float = LIFETIME


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Palette.ENEMY_PROJECTILE_BOLT)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Palette.ENEMY_PROJECTILE_CORE)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(damage, position)
		_spawn_spark()
		queue_free()


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = Palette.ENEMY_PROJECTILE_BOLT
	spark.amount = 6
	get_parent().add_child(spark)
	spark.emitting = true
