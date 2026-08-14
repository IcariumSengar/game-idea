class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

const RADIUS: float = 14.0
const CONTACT_DAMAGE: float = 10.0
const CONTACT_COOLDOWN: float = 0.4
const BASE_COLOR: Color = Color.CRIMSON
const FLASH_DECAY_PER_SEC: float = 8.0

@export var speed: float = 120.0
@export var max_hp: float = 30.0

var hp: float
var target: Player

var _flash_amount: float = 0.0
var _contact_cooldown: float = 0.0
var _approach_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	hp = max_hp
	add_to_group("enemies")
	var angle := randf() * TAU
	var radius := randf_range(20.0, 60.0)
	_approach_offset = Vector2(cos(angle), sin(angle)) * radius


func _physics_process(delta: float) -> void:
	if target == null:
		return
	velocity = position.direction_to(target.position + _approach_offset) * speed
	move_and_slide()
	_contact_cooldown = max(_contact_cooldown - delta, 0.0)
	if _contact_cooldown <= 0.0:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider() == target:
				target.take_damage(CONTACT_DAMAGE, position)
				_contact_cooldown = CONTACT_COOLDOWN
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
