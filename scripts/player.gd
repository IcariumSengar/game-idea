class_name Player
extends CharacterBody2D

signal died
signal hit
signal hp_changed(current: float, max_hp: float)
signal loot_changed(current: int)

const RADIUS: float = 16.0
const SPARK_COLOR: Color = Color.CYAN
const FLASH_DECAY_PER_SEC: float = 6.0
const HIT_FLASH_COLOR: Color = Color(1.0, 0.35, 0.35)
const KNOCKBACK_SPEED: float = 400.0
const KNOCKBACK_DECAY_PER_SEC: float = 8.0
const MIN_HP_FRACTION: float = 0.2
const HIT_SPARK_AMOUNT: int = 8
const SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")

@export var speed: float = 250.0
@export var arena_size: Vector2 = Vector2(1280.0, 720.0)
@export var base_max_hp: float = 100.0
@export var pickup_range: float = 60.0
@export var backpack_capacity: int = 20

var hp: float
var max_hp: float
var loot: int = 0

var _flash_amount: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.UP

@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


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
		_sprite.flip_h = _facing.x < 0.0
		_sprite.play("run")
	else:
		_sprite.play("idle")
	velocity = input_direction * speed + _knockback
	move_and_slide()
	position = position.clamp(Vector2(RADIUS, RADIUS), arena_size - Vector2(RADIUS, RADIUS))

	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY_PER_SEC * speed * delta)
	if _flash_amount > 0.0:
		_flash_amount = max(_flash_amount - FLASH_DECAY_PER_SEC * delta, 0.0)
	_sprite.modulate = Color.WHITE.lerp(HIT_FLASH_COLOR, _flash_amount)


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


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = SPARK_COLOR
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
