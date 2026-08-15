extends Node

## Casts whichever spell is currently equipped (MetaProgression.active_spell).
## Replaces the old flat weapon.gd -- v9 supports one active spell at a
## time, switched between runs in the shop; v10+ adds casting multiple
## simultaneously.
##
## Each spell's "Power" scales with Spellpower proportionally to its base
## value (20 for Arcane, 25 for Inferno, 15 for Frost) relative to
## Spellpower's own base of 20, per DESIGN.md's "Spellpower stat applies
## to all spells uniformly" note.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/spell_projectile.tscn")
const SPARK_SCENE: PackedScene = preload("res://scenes/spark_burst.tscn")
const INFERNO_BURST_SCENE: PackedScene = preload("res://scenes/inferno_burst.tscn")

const SPELLPOWER_BASE: float = 20.0
const ARCANE_RANGE: float = 220.0
const ARCANE_BASE_POWER: float = 20.0
const INFERNO_RANGE: float = 120.0
const INFERNO_BASE_POWER: float = 25.0
const INFERNO_BURN_DURATION: float = 1.5
const INFERNO_TICK_INTERVAL: float = 0.5
const INFERNO_TICK_COUNT: int = 3
const INFERNO_COLOR: Color = Color(0.95, 0.4, 0.15)
const FROST_BASE_POWER: float = 15.0
const FROST_FREEZE_DURATION: float = 0.8
const FROST_COLOR: Color = Color(0.5, 0.85, 1.0)

var _owner_body: Player
## Enemy -> {ticks_left: int, tick_damage: float, timer: float}
var _burning: Dictionary = {}

@onready var _cast_timer: Timer = $AttackTimer


func _ready() -> void:
	_owner_body = get_parent()
	_cast_timer.wait_time = _current_cast_rate()


func _process(delta: float) -> void:
	var finished: Array = []
	for enemy: Enemy in _burning:
		if not is_instance_valid(enemy):
			finished.append(enemy)
			continue
		var info: Dictionary = _burning[enemy]
		info.timer -= delta
		if info.timer <= 0.0:
			enemy.take_damage(info.tick_damage)
			info.ticks_left -= 1
			info.timer = INFERNO_TICK_INTERVAL
			if info.ticks_left <= 0:
				finished.append(enemy)
	for enemy in finished:
		_burning.erase(enemy)


func _on_attack_timer_timeout() -> void:
	match MetaProgression.active_spell:
		MetaProgression.SPELL_ARCANE_BOLT:
			_cast_arcane_bolt()
		MetaProgression.SPELL_INFERNO_BLADE:
			_cast_inferno_blade()
		MetaProgression.SPELL_FROST_NOVA:
			_cast_frost_nova()
	_cast_timer.wait_time = _current_cast_rate()


func _current_cast_rate() -> float:
	match MetaProgression.active_spell:
		MetaProgression.SPELL_INFERNO_BLADE:
			return MetaProgression.get_stat(MetaProgression.STAT_INFERNO_FURY)
		MetaProgression.SPELL_FROST_NOVA:
			return MetaProgression.get_stat(MetaProgression.STAT_FROST_FREQUENCY)
	return MetaProgression.get_stat(MetaProgression.STAT_ARCANE_HASTE)


func _scaled_power(spell_base_power: float) -> float:
	var spellpower: float = MetaProgression.get_stat(MetaProgression.STAT_DAMAGE)
	return spell_base_power * (spellpower / SPELLPOWER_BASE)


func _cast_arcane_bolt() -> void:
	var enemy := _find_nearest_enemy(ARCANE_RANGE)
	if enemy == null:
		return
	var projectile: SpellProjectile = PROJECTILE_SCENE.instantiate()
	projectile.position = _owner_body.position
	projectile.direction = _owner_body.position.direction_to(enemy.position)
	projectile.speed = MetaProgression.get_stat(MetaProgression.STAT_ARCANE_PROJECTILE_SPEED)
	projectile.damage = _scaled_power(ARCANE_BASE_POWER)
	_owner_body.get_parent().add_child(projectile)
	AudioManager.play("arcane_cast")


func _cast_inferno_blade() -> void:
	# Omnidirectional per playtesting feedback: the player shouldn't need
	# to be facing an enemy for Inferno Blade to hit it. "Reach" (still a
	# 90-180 stat curve under the hood) now widens the hit radius instead
	# of a cone angle -- range grows past the base 120px by however far
	# its value sits above the 90 baseline.
	var reach_stat: float = MetaProgression.get_stat(MetaProgression.STAT_INFERNO_ARC_WIDTH)
	var effective_range: float = INFERNO_RANGE + (reach_stat - 90.0)
	var damage: float = _scaled_power(INFERNO_BASE_POWER)
	var burn_total: float = MetaProgression.get_stat(MetaProgression.STAT_INFERNO_BURN_DAMAGE)
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if _owner_body.position.distance_to(enemy.position) > effective_range:
			continue
		hit_any = true
		enemy.take_damage(damage)
		if burn_total > 0.0:
			_apply_burn(enemy, burn_total)
	if hit_any:
		_spawn_burst(_owner_body.position, INFERNO_COLOR)
		_spawn_inferno_graphic(_owner_body.position)
		AudioManager.play("inferno_cast")


func _cast_frost_nova() -> void:
	var radius: float = MetaProgression.get_stat(MetaProgression.STAT_FROST_RADIUS)
	var slow_strength: float = (
		MetaProgression.get_stat(MetaProgression.STAT_FROST_SLOW_STRENGTH) / 100.0
	)
	var damage: float = _scaled_power(FROST_BASE_POWER)
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if _owner_body.position.distance_to(enemy.position) > radius:
			continue
		hit_any = true
		enemy.take_damage(damage)
		enemy.apply_slow(1.0 - slow_strength, FROST_FREEZE_DURATION)
	if hit_any:
		_spawn_burst(_owner_body.position, FROST_COLOR)
	AudioManager.play("frost_cast")


func _apply_burn(enemy: Enemy, total_damage: float) -> void:
	_burning[enemy] = {
		"ticks_left": INFERNO_TICK_COUNT,
		"tick_damage": total_damage / INFERNO_TICK_COUNT,
		"timer": INFERNO_TICK_INTERVAL,
	}


func _spawn_inferno_graphic(at_position: Vector2) -> void:
	var burst: InfernoBurst = INFERNO_BURST_SCENE.instantiate()
	burst.position = at_position
	_owner_body.get_parent().add_child(burst)


func _spawn_burst(at_position: Vector2, color: Color) -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = at_position
	spark.color = color
	spark.amount = 14
	spark.scale_amount_min = 1.2
	spark.scale_amount_max = 2.2
	_owner_body.get_parent().add_child(spark)
	spark.emitting = true


func _find_nearest_enemy(max_range: float) -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := max_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var distance := _owner_body.position.distance_to(enemy.position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest
