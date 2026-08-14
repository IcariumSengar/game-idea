extends Node

const DAMAGE: float = 20.0
const RANGE: float = 220.0

@onready var _owner_body: Node2D = get_parent()


func _on_attack_timer_timeout() -> void:
	var enemy := _find_nearest_enemy()
	if enemy != null:
		enemy.take_damage(DAMAGE)


func _find_nearest_enemy() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var distance := _owner_body.position.distance_to(enemy.position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest
