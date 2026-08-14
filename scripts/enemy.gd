class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

const RADIUS: float = 14.0
const CONTACT_DAMAGE: float = 10.0
const BASE_COLOR: Color = Color.CRIMSON
const FLASH_DECAY_PER_SEC: float = 8.0

@export var speed: float = 120.0
@export var max_hp: float = 30.0

var hp: float
var target: Player

var _flash_amount: float = 0.0


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	hp = max_hp
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if target == null:
		return
	velocity = position.direction_to(target.position) * speed
	move_and_slide()
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == target:
			target.take_damage(CONTACT_DAMAGE, position)
			break
	if _flash_amount > 0.0:
		_flash_amount = max(_flash_amount - FLASH_DECAY_PER_SEC * delta, 0.0)
		queue_redraw()


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit(self)
		queue_free()
		return
	_flash_amount = 1.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, BASE_COLOR.lerp(Color.WHITE, _flash_amount))
