class_name Player
extends CharacterBody2D

signal died
signal hit
signal hp_changed(current: float, max_hp: float)
signal loot_changed(current: int)

const RADIUS: float = 16.0
const BASE_COLOR: Color = Color.CYAN
const FLASH_DECAY_PER_SEC: float = 6.0
const KNOCKBACK_SPEED: float = 400.0
const KNOCKBACK_DECAY_PER_SEC: float = 8.0

@export var speed: float = 250.0
@export var arena_size: Vector2 = Vector2(1280.0, 720.0)
@export var max_hp: float = 100.0
@export var pickup_range: float = 60.0

var hp: float
var loot: int = 0

var _flash_amount: float = 0.0
var _knockback: Vector2 = Vector2.ZERO

@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	(_pickup_shape.shape as CircleShape2D).radius = pickup_range
	_pickup_area.area_entered.connect(_on_pickup_area_entered)


func _on_pickup_area_entered(area: Area2D) -> void:
	if area is Loot:
		area.collect(self)


func _physics_process(delta: float) -> void:
	velocity = _get_input_direction() * speed + _knockback
	move_and_slide()
	position = position.clamp(Vector2(RADIUS, RADIUS), arena_size - Vector2(RADIUS, RADIUS))

	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY_PER_SEC * speed * delta)
	if _flash_amount > 0.0:
		_flash_amount = max(_flash_amount - FLASH_DECAY_PER_SEC * delta, 0.0)
		queue_redraw()


func collect_loot(amount: int) -> void:
	loot += amount
	loot_changed.emit(loot)


func take_damage(amount: float, from_position: Vector2) -> void:
	if hp <= 0.0:
		return
	hp = max(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	hit.emit()
	_flash_amount = 1.0
	queue_redraw()
	if from_position != position:
		_knockback = position.direction_to(from_position) * -KNOCKBACK_SPEED
	if hp <= 0.0:
		died.emit()
		set_physics_process(false)
		hide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, BASE_COLOR.lerp(Color.WHITE, _flash_amount))


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
