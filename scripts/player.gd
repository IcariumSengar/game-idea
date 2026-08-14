class_name Player
extends CharacterBody2D

const RADIUS: float = 16.0

@export var speed: float = 250.0
@export var arena_size: Vector2 = Vector2(1280.0, 720.0)


func _physics_process(_delta: float) -> void:
	velocity = _get_input_direction() * speed
	move_and_slide()
	position = position.clamp(Vector2(RADIUS, RADIUS), arena_size - Vector2(RADIUS, RADIUS))


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.CYAN)


func _get_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	return dir.normalized()
