class_name SpellProjectile
extends Area2D

## Arcane Bolt's projectile -- straight-line bolt fired at the nearest
## enemy. Mirrors enemy_projectile.gd's shape but targets Enemy instead of
## Player, tinted per DESIGN.md's "Arcane (blue/purple)" note.

const LIFETIME: float = 2.0
const SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")
const BOLT_COLOR: Color = Color(0.55, 0.35, 0.95)
const RADIUS: float = 6.0

@export var speed: float = 400.0
@export var damage: float = 20.0

var direction: Vector2 = Vector2.ZERO

var _time_left: float = LIFETIME


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, BOLT_COLOR)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(0.85, 0.75, 1.0))


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		body.take_damage(damage)
		_spawn_spark()
		queue_free()


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = BOLT_COLOR
	spark.amount = 6
	get_parent().add_child(spark)
	spark.emitting = true
