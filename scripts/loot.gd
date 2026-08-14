class_name Loot
extends Area2D

const RADIUS: float = 8.0
const VALUE: int = 1


func collect(player: Player) -> void:
	player.collect_loot(VALUE)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect(body)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.GOLD)
