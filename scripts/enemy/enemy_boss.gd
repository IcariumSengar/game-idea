class_name EnemyBoss
extends Enemy

## Tier 4: unique boss, one per run at 55+ seconds (see arena.gd's
## BOSS_SPAWN_TIME -- spawned once directly, not part of the weighted
## per-phase roll like the other tiers). Relentlessly approaches like a
## Minion but periodically fires a 3-shot projectile spread, combining
## pursuit with Elite-style ranged pressure so it reads as a genuine step
## up rather than just a bigger HP pool. Guaranteed Mythic+ drop on death
## (see loot_weights below) -- the one tier whose loot skips the normal
## weighted roll entirely, per DESIGN.md's "Future Expansions" note.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy/enemy_projectile.tscn")
const SPREAD_ANGLE: float = 0.35  # radians, ~20 degrees between shots

@export var attack_cooldown_min: float = 2.2
@export var attack_cooldown_max: float = 2.8
@export var projectile_speed: float = 140.0
@export var projectile_damage: float = 10.0

var _attack_timer: float = 0.0


func _ready() -> void:
	super._ready()
	loot_weights = {&"mythic": 80.0, &"legendary": 20.0}
	_attack_timer = randf_range(attack_cooldown_min, attack_cooldown_max)


func apply_difficulty_scale(hp_scale: float, speed_scale: float) -> void:
	super.apply_difficulty_scale(hp_scale, speed_scale)
	projectile_speed *= speed_scale


func _update_behavior(delta: float) -> void:
	velocity = (
		position.direction_to(target.position + _approach_offset) * _slowed(speed) + _knockback
	)
	move_and_slide()
	_apply_contact_damage(delta)

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_fire_spread()
		_attack_timer = randf_range(attack_cooldown_min, attack_cooldown_max)


func _fire_spread() -> void:
	var base_direction: Vector2 = position.direction_to(target.position)
	for offset in [-SPREAD_ANGLE, 0.0, SPREAD_ANGLE]:
		var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate()
		projectile.position = position
		projectile.direction = base_direction.rotated(offset)
		projectile.speed = projectile_speed
		projectile.damage = projectile_damage
		get_parent().add_child(projectile)
	AudioManager.play("enemy_cast")
