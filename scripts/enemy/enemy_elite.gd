class_name EnemyElite
extends Enemy

## Tier 3: kites to a preferred range and fires bolts instead of
## melee-attacking -- no contact damage, so closing the distance is the
## player's counter-play against it, per DESIGN.md's "requires
## positioning and kiting" role for this tier.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy/enemy_projectile.tscn")

@export var preferred_range: float = 300.0
@export var range_tolerance: float = 40.0
@export var attack_cooldown_min: float = 1.5
@export var attack_cooldown_max: float = 2.0
@export var projectile_speed: float = 150.0
@export var projectile_damage: float = 8.0

var _attack_timer: float = 0.0


func _ready() -> void:
	super._ready()
	# Epic 30->40%, Mythic 5->15% -- Elite is where rarer tiers should
	# feel real (Phase 3, 40s+), per live-play feedback that they were
	# still too rare even once a player actually reached this enemy tier.
	loot_weights = {
		&"common": 3.0, &"uncommon": 12.0, &"rare": 30.0, &"epic": 40.0, &"mythic": 15.0
	}
	_attack_timer = randf_range(attack_cooldown_min, attack_cooldown_max)


func apply_difficulty_scale(hp_scale: float, speed_scale: float) -> void:
	super.apply_difficulty_scale(hp_scale, speed_scale)
	projectile_speed *= speed_scale


func _update_behavior(delta: float) -> void:
	var to_target: Vector2 = _chase_position() - position
	var distance: float = to_target.length()
	if distance < preferred_range - range_tolerance:
		velocity = -to_target.normalized() * _slowed(speed) + _knockback
	elif distance > preferred_range + range_tolerance:
		velocity = to_target.normalized() * _slowed(speed) + _knockback
	else:
		velocity = _knockback
	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_fire_projectile()
		_attack_timer = randf_range(attack_cooldown_min, attack_cooldown_max)


func _fire_projectile() -> void:
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate()
	projectile.position = position
	projectile.direction = position.direction_to(target.position)
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	get_parent().add_child(projectile)
	AudioManager.play("enemy_cast")
