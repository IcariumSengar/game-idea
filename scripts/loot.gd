class_name Loot
extends Area2D

const RADIUS: float = 8.0
const VALUE: int = 1
const SPAWN_GRACE: float = 0.15
const BOB_SPEED: float = 3.0
const BOB_AMOUNT: float = 3.0
const PULSE_SPEED: float = 4.0
const PULSE_AMOUNT: float = 1.5
const PICKUP_SPARK_AMOUNT: int = 8
const SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")

var _time: float = randf() * TAU


func _ready() -> void:
	monitoring = false
	monitorable = false
	get_tree().create_timer(SPAWN_GRACE).timeout.connect(_enable_pickup)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _enable_pickup() -> void:
	monitoring = true
	monitorable = true


func collect(player: Player) -> void:
	if player.collect_loot(VALUE):
		_spawn_spark()
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect(body)


func _draw() -> void:
	var bob_offset := Vector2(0.0, sin(_time * BOB_SPEED) * BOB_AMOUNT)
	var pulse_radius: float = RADIUS + sin(_time * PULSE_SPEED) * PULSE_AMOUNT
	draw_circle(Vector2(0.0, 6.0), RADIUS * 0.8, Color(0.0, 0.0, 0.0, 0.2))
	draw_circle(bob_offset, pulse_radius, Color.GOLD)
	draw_arc(bob_offset, pulse_radius, 0.0, TAU, 16, Color.GOLD.darkened(0.35), 1.5, true)


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = Color.GOLD
	spark.amount = PICKUP_SPARK_AMOUNT
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.0
	get_parent().add_child(spark)
	spark.emitting = true
