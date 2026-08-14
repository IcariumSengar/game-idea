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
const MIN_HP_FRACTION: float = 0.2
const HIT_SPARK_AMOUNT: int = 8
const FACING_LENGTH: float = 10.0
const FACING_WIDTH: float = 6.0
const SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")

@export var speed: float = 250.0
@export var arena_size: Vector2 = Vector2(1280.0, 720.0)
@export var base_max_hp: float = 100.0
@export var pickup_range: float = 60.0
@export var backpack_capacity: int = 20
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

var hp: float
var max_hp: float
var loot: int = 0

var _flash_amount: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.UP
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _space_was_pressed: bool = false

@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	backpack_capacity = int(MetaProgression.get_stat(MetaProgression.STAT_BACKPACK_CAPACITY))
	pickup_range = MetaProgression.get_stat(MetaProgression.STAT_PICKUP_RANGE)
	max_hp = base_max_hp
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	(_pickup_shape.shape as CircleShape2D).radius = pickup_range
	_pickup_area.area_entered.connect(_on_pickup_area_entered)


func _on_pickup_area_entered(area: Area2D) -> void:
	if area is Loot:
		area.start_magnet(self)


func _physics_process(delta: float) -> void:
	var input_direction := _get_input_direction()
	if input_direction != Vector2.ZERO:
		_facing = input_direction

	_check_dash_input()

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * dash_speed
	else:
		velocity = input_direction * speed + _knockback

	move_and_slide()
	position = position.clamp(Vector2(RADIUS, RADIUS), arena_size - Vector2(RADIUS, RADIUS))

	_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY_PER_SEC * speed * delta)
	if _flash_amount > 0.0:
		_flash_amount = max(_flash_amount - FLASH_DECAY_PER_SEC * delta, 0.0)
	queue_redraw()


func _check_dash_input() -> void:
	var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if space_pressed and not _space_was_pressed and _dash_cooldown_left <= 0.0:
		_dash_direction = _facing
		_dash_time_left = dash_duration
		_dash_cooldown_left = dash_cooldown
	_space_was_pressed = space_pressed


func collect_loot(amount: int) -> bool:
	if loot >= backpack_capacity:
		return false
	loot = min(loot + amount, backpack_capacity)
	loot_changed.emit(loot)
	var fill_ratio := float(loot) / float(backpack_capacity)
	max_hp = base_max_hp * lerp(1.0, MIN_HP_FRACTION, fill_ratio)
	_set_hp(min(hp, max_hp))
	return true


func take_damage(amount: float, from_position: Vector2) -> void:
	if hp <= 0.0:
		return
	hit.emit()
	_flash_amount = 1.0
	queue_redraw()
	_spawn_spark()
	if from_position != position:
		_knockback = position.direction_to(from_position) * -KNOCKBACK_SPEED
	_set_hp(hp - amount)


func _set_hp(new_hp: float) -> void:
	if hp <= 0.0:
		return
	hp = clamp(new_hp, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
		set_physics_process(false)
		hide()


func _draw() -> void:
	var fill := BASE_COLOR.lerp(Color.WHITE, _flash_amount)
	draw_circle(Vector2(0.0, 4.0), RADIUS * 0.9, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, fill)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, fill.darkened(0.4), 2.0, true)
	_draw_facing_notch(fill.lightened(0.5))


func _draw_facing_notch(notch_color: Color) -> void:
	var tip := _facing * (RADIUS + FACING_LENGTH)
	var side := _facing.orthogonal() * FACING_WIDTH * 0.5
	var base_center := _facing * RADIUS * 0.4
	draw_polygon(
		PackedVector2Array([tip, base_center + side, base_center - side]),
		PackedColorArray([notch_color]),
	)


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = BASE_COLOR
	spark.amount = HIT_SPARK_AMOUNT
	get_parent().add_child(spark)
	spark.emitting = true


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
