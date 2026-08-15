class_name Enemy
extends CharacterBody2D

## Base enemy: shared HP/hit-flash/death-spark/damage-text plumbing plus
## the default Tier 1 "Minion" behavior (melee chaser, contact damage).
## Bruiser/Elite subclass this and override _update_behavior() for their
## own movement/attack pattern while reusing everything else.

signal died(enemy: Enemy)

const CONTACT_DAMAGE: float = 10.0
const CONTACT_COOLDOWN: float = 0.4
const SPARK_COLOR: Color = Color.CRIMSON
const FLASH_DECAY_PER_SEC: float = 8.0
const HIT_FLASH_COLOR: Color = Color(4.0, 4.0, 4.0)
const HIT_SPARK_AMOUNT: int = 6
const DEATH_SPARK_AMOUNT: int = 18
const SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/floating_text.tscn")
const DAMAGE_TEXT_COLOR: Color = Color(1.0, 0.9, 0.3)

@export var speed: float = 120.0
@export var max_hp: float = 30.0

## Loot tier -> drop weight for kills of this enemy, per DESIGN.md's
## "Enemy Types & Loot Tiers" table. Only tiers listed here can drop.
## Not @export'd -- each tier's table is a locked design value, not
## something to hand-tune per scene instance in the inspector.
var loot_weights: Dictionary = {&"common": 60.0, &"uncommon": 30.0, &"rare": 10.0}

var hp: float
var target: Player

var _flash_amount: float = 0.0
var _contact_cooldown: float = 0.0
var _approach_offset: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	hp = max_hp
	add_to_group("enemies")
	var angle := randf() * TAU
	var radius := randf_range(20.0, 60.0)
	_approach_offset = Vector2(cos(angle), sin(angle)) * radius
	_sprite.play("run")


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_update_behavior(delta)
	if velocity.x != 0.0:
		_sprite.flip_h = velocity.x < 0.0
	if _flash_amount > 0.0:
		_flash_amount = max(_flash_amount - FLASH_DECAY_PER_SEC * delta, 0.0)
	_sprite.modulate = Color.WHITE.lerp(HIT_FLASH_COLOR, _flash_amount)


## Default: Tier 1 Minion behavior (melee chaser). Subclasses override
## this for their own movement/attack pattern.
func _update_behavior(delta: float) -> void:
	velocity = position.direction_to(target.position + _approach_offset) * speed
	move_and_slide()
	_apply_contact_damage(delta)


## Shared "deal damage on physical collision with the player" used by
## Minion (always) and Bruiser (only while charging).
func _apply_contact_damage(delta: float) -> void:
	_contact_cooldown = max(_contact_cooldown - delta, 0.0)
	if _contact_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == target:
			target.take_damage(CONTACT_DAMAGE, position)
			_contact_cooldown = CONTACT_COOLDOWN
			break


func take_damage(amount: float) -> void:
	hp -= amount
	_spawn_damage_text(amount)
	if hp <= 0.0:
		_spawn_spark(DEATH_SPARK_AMOUNT)
		AudioManager.play("enemy_death")
		died.emit(self)
		queue_free()
		return
	_flash_amount = 1.0
	_spawn_spark(HIT_SPARK_AMOUNT)
	AudioManager.play("enemy_hit")


func _spawn_spark(amount: int) -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = SPARK_COLOR
	spark.amount = amount
	get_parent().add_child(spark)
	spark.emitting = true


func _spawn_damage_text(amount: float) -> void:
	var text: Node2D = FLOATING_TEXT_SCENE.instantiate()
	text.position = position + Vector2(0.0, -20.0)
	get_parent().add_child(text)
	text.setup("%d" % roundi(amount), DAMAGE_TEXT_COLOR)
