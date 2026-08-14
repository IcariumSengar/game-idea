class_name Loot
extends Area2D

const RADIUS: float = 8.0
const VALUE: int = 1
const SPAWN_GRACE: float = 0.15


func _ready() -> void:
	monitoring = false
	monitorable = false
	get_tree().create_timer(SPAWN_GRACE).timeout.connect(_enable_pickup)


func _enable_pickup() -> void:
	monitoring = true
	monitorable = true


func collect(player: Player) -> void:
	if player.collect_loot(VALUE):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect(body)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.GOLD)
