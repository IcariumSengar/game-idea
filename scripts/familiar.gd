class_name Familiar
extends Node2D

## Summon Familiar's pet: hovers near the player and independently fires
## bolts at the nearest enemy in range. Lives for `duration` seconds (set
## by spell_caster.gd's _cast_summon_familiar() from the player's
## STAT_FAMILIAR_DURATION) then fades out -- "mana-limited" per DESIGN.md's
## flavor text, stood in for by limited uptime + a resummon cooldown rather
## than inventing a whole mana resource just for this one spell.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/spell_projectile.tscn")
const ATTACK_RANGE: float = 160.0
const ATTACK_INTERVAL: float = 0.8
const ATTACK_POWER: float = 8.0
const PROJECTILE_SPEED: float = 350.0
const FOLLOW_DISTANCE: float = 40.0
const FOLLOW_SPEED: float = 220.0
const FADE_DURATION: float = 0.4

var duration: float = 12.0
var owner_body: Player

var _age: float = 0.0
var _attack_timer: float = 0.0
var _fading: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_attack_timer = ATTACK_INTERVAL * 0.5
	_sprite.play("idle")


func _process(delta: float) -> void:
	if owner_body == null or not is_instance_valid(owner_body):
		queue_free()
		return
	_age += delta
	if _age >= duration or _fading:
		_fading = true
		modulate.a -= delta / FADE_DURATION
		if modulate.a <= 0.0:
			queue_free()
		return

	var to_owner: Vector2 = owner_body.position - position
	if to_owner.length() > FOLLOW_DISTANCE:
		position += to_owner.normalized() * FOLLOW_SPEED * delta
		_sprite.flip_h = to_owner.x < 0.0
		if _sprite.animation != &"run":
			_sprite.play("run")
	elif _sprite.animation != &"idle":
		_sprite.play("idle")

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_try_attack()
		_attack_timer = ATTACK_INTERVAL


func _try_attack() -> void:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return
	var projectile: SpellProjectile = PROJECTILE_SCENE.instantiate()
	projectile.position = position
	projectile.direction = position.direction_to(nearest.position)
	projectile.speed = PROJECTILE_SPEED
	projectile.damage = ATTACK_POWER
	get_parent().add_child(projectile)


func _find_nearest_enemy() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := ATTACK_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var distance := position.distance_to(enemy.position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest
