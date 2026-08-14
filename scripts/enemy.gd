class_name Enemy
extends CharacterBody2D

const RADIUS: float = 14.0

@export var speed: float = 120.0

var target: Node2D


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	velocity = position.direction_to(target.position) * speed
	move_and_slide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.CRIMSON)
