extends Node

## Casts every spell the player has unlocked, simultaneously and
## independently -- v10 replaces v9's single-active-spell switching.
## Arcane Bolt is always available; the rest join in permanently once
## unlocked via the Spell Unlock skill-tree node (L1-L7, see
## MetaProgression.SPELL_UNLOCK_REQUIREMENTS). Each spell tracks its own
## cast-rate cooldown so they don't interfere with each other.
##
## Each spell's "Power" scales with Spellpower proportionally to its base
## value relative to Spellpower's own base of 20, per DESIGN.md's
## "Spellpower stat applies to all spells uniformly" note.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/fx/spell_projectile.tscn")
const SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const INFERNO_BURST_SCENE: PackedScene = preload("res://scenes/fx/inferno_burst.tscn")
const FROST_BURST_SCENE: PackedScene = preload("res://scenes/fx/frost_burst.tscn")
const METEOR_FX_SCENE: PackedScene = preload("res://scenes/fx/meteor_strike_fx.tscn")
const LIGHTNING_FX_SCENE: PackedScene = preload("res://scenes/fx/lightning_bolt_fx.tscn")
const TIME_WARP_BURST_SCENE: PackedScene = preload("res://scenes/fx/time_warp_burst.tscn")
const FAMILIAR_SCENE: PackedScene = preload("res://scenes/player/familiar.tscn")

const SPELLPOWER_BASE: float = 20.0
const ARCANE_RANGE: float = 220.0
const ARCANE_BASE_POWER: float = 20.0
const INFERNO_RANGE: float = 120.0
const INFERNO_BASE_POWER: float = 25.0
const INFERNO_BURN_DURATION: float = 1.5
const INFERNO_TICK_INTERVAL: float = 0.5
const INFERNO_TICK_COUNT: int = 3
const INFERNO_COLOR: Color = Color(0.95, 0.4, 0.15)
const INFERNO_KNOCKBACK_STRENGTH: float = 200.0
const FROST_BASE_POWER: float = 15.0
const FROST_FREEZE_DURATION: float = 0.8
const FROST_COLOR: Color = Color(0.5, 0.85, 1.0)

## v11 spells. Each got exactly one upgrade stat (see meta_progression.gd)
## instead of the 2-3 the original three got, to keep five new spells'
## worth of shop surface proportional -- all other numbers below are fixed.
const METEOR_SEEK_RANGE: float = 99999.0
const METEOR_BASE_POWER: float = 90.0
const METEOR_RADIUS: float = 100.0
const LIGHTNING_RANGE: float = 200.0
const LIGHTNING_CHAIN_RANGE: float = 150.0
const LIGHTNING_MAX_HITS: int = 4
const LIGHTNING_BASE_POWER: float = 15.0
const LIGHTNING_DAMAGE_DECAY: float = 0.8
const TIME_WARP_RADIUS: float = 200.0
const TIME_WARP_BASE_POWER: float = 10.0
const TIME_WARP_SLOW_STRENGTH: float = 0.8
const TIME_WARP_DURATION: float = 2.0
const TIME_WARP_COLOR: Color = Color(0.65, 0.45, 0.95)
const TELEPORT_BASE_POWER: float = 20.0
const TELEPORT_DISTANCE: float = 250.0
const TELEPORT_BURST_RADIUS: float = 80.0
const TELEPORT_ARENA_MARGIN: float = 20.0
const TELEPORT_COLOR: Color = Color(0.6, 0.85, 1.0)
const FAMILIAR_RESUMMON_COOLDOWN: float = 8.0

## Gem Combos' "Full Set" (DESIGN.md, Tweak 3): not a levelled spell --
## purely in-run, no currency/meta-progression, one-time per run. Visual
## radius only (kill is unconditional, see _on_full_set_impact), sized to
## read as a big impressive clear rather than to literally reach every
## corner of the arena.
const FULL_SET_RADIUS: float = 700.0
## Combo-completion feedback (DESIGN.md's "Combo feedback" note, Hyperslice-
## referenced pacing): a hard punch on the payoff, scaled to the combo's
## size, so Full Set hits harder than Streak.
const FULL_SET_SHAKE_SCALE: float = 2.0
const FULL_SET_HIT_STOP: float = 0.1

## Gem Combos' "Streak" (DESIGN.md): N consecutive pickups of the *same*
## tier, uninterrupted, triggers a small tier-flavored AOE burst -- unlike
## Full Set, repeatable all run. "Tier-flavored" made concrete as damage
## scaling with tier rarity (index into TIER_ORDER), so streaking a rarer
## tier hits harder. Instant, no telegraph -- Full Set is the "build
## tension" moment; Streak is the immediate reward for aggressive
## same-tier looting.
const TIER_ORDER: Array[StringName] = [
	&"common", &"uncommon", &"rare", &"epic", &"mythic", &"legendary"
]
const STREAK_THRESHOLD: int = 3
const STREAK_BASE_POWER: float = 12.0
const STREAK_RADIUS: float = 200.0
const STREAK_SHAKE_SCALE: float = 0.6

var _owner_body: Player
## Enemy -> {ticks_left: int, tick_damage: float, timer: float}
var _burning: Dictionary = {}
var _active_familiar: Familiar = null
var _full_set_used_this_run: bool = false
var _streak_tier: StringName = StringName()
var _streak_count: int = 0

var _arcane_cooldown: float = 0.0
var _inferno_cooldown: float = 0.0
var _frost_cooldown: float = 0.0
var _meteor_cooldown: float = 0.0
var _lightning_cooldown: float = 0.0
var _time_warp_cooldown: float = 0.0
var _teleport_cooldown: float = 0.0
var _familiar_cooldown: float = 0.0


func _ready() -> void:
	_owner_body = get_parent()
	_owner_body.loot_changed.connect(_on_loot_changed)
	_owner_body.loot_collected.connect(_on_loot_collected)
	_arcane_cooldown = MetaProgression.get_stat(MetaProgression.STAT_ARCANE_HASTE)
	_inferno_cooldown = MetaProgression.get_stat(MetaProgression.STAT_INFERNO_FURY)
	_frost_cooldown = MetaProgression.get_stat(MetaProgression.STAT_FROST_FREQUENCY)
	_meteor_cooldown = MetaProgression.get_stat(MetaProgression.STAT_METEOR_FREQUENCY)
	_lightning_cooldown = MetaProgression.get_stat(MetaProgression.STAT_LIGHTNING_FREQUENCY)
	_time_warp_cooldown = MetaProgression.get_stat(MetaProgression.STAT_TIME_WARP_FREQUENCY)
	_teleport_cooldown = MetaProgression.get_stat(MetaProgression.STAT_TELEPORT_FREQUENCY)
	_familiar_cooldown = FAMILIAR_RESUMMON_COOLDOWN


func _process(delta: float) -> void:
	_process_burns(delta)
	_arcane_cooldown -= delta
	if _arcane_cooldown <= 0.0:
		_cast_arcane_bolt()
		_arcane_cooldown = MetaProgression.get_stat(MetaProgression.STAT_ARCANE_HASTE)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_INFERNO_BLADE):
		_inferno_cooldown -= delta
		if _inferno_cooldown <= 0.0:
			_cast_inferno_blade()
			_inferno_cooldown = MetaProgression.get_stat(MetaProgression.STAT_INFERNO_FURY)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_FROST_NOVA):
		_frost_cooldown -= delta
		if _frost_cooldown <= 0.0:
			_cast_frost_nova()
			_frost_cooldown = MetaProgression.get_stat(MetaProgression.STAT_FROST_FREQUENCY)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_METEOR_STRIKE):
		_meteor_cooldown -= delta
		if _meteor_cooldown <= 0.0:
			_cast_meteor_strike()
			_meteor_cooldown = MetaProgression.get_stat(MetaProgression.STAT_METEOR_FREQUENCY)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_LIGHTNING_CHAIN):
		_lightning_cooldown -= delta
		if _lightning_cooldown <= 0.0:
			_cast_lightning_chain()
			_lightning_cooldown = MetaProgression.get_stat(MetaProgression.STAT_LIGHTNING_FREQUENCY)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_TIME_WARP):
		_time_warp_cooldown -= delta
		if _time_warp_cooldown <= 0.0:
			_cast_time_warp()
			_time_warp_cooldown = MetaProgression.get_stat(MetaProgression.STAT_TIME_WARP_FREQUENCY)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_TELEPORT_PULSE):
		_teleport_cooldown -= delta
		if _teleport_cooldown <= 0.0:
			_cast_teleport_pulse()
			_teleport_cooldown = MetaProgression.get_stat(MetaProgression.STAT_TELEPORT_FREQUENCY)
	if MetaProgression.is_spell_unlocked(MetaProgression.SPELL_SUMMON_FAMILIAR):
		_familiar_cooldown -= delta
		if _familiar_cooldown <= 0.0:
			_cast_summon_familiar()
			_familiar_cooldown = FAMILIAR_RESUMMON_COOLDOWN


func _process_burns(delta: float) -> void:
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
		enemy.apply_knockback(_owner_body.position, INFERNO_KNOCKBACK_STRENGTH)
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
		_spawn_frost_graphic(_owner_body.position, radius)
		AudioManager.play("frost_cast")


## Boss-killer: telegraphs briefly at the nearest enemy's position, then
## deals heavy AOE damage there. Damage is applied on MeteorStrikeFx's
## `impact` signal, not at cast time, so the hit always lands in sync with
## the visual instead of resolving instantly under a still-rising telegraph.
func _cast_meteor_strike() -> void:
	var enemy := _find_nearest_enemy(METEOR_SEEK_RANGE)
	if enemy == null:
		return
	var target_position: Vector2 = enemy.position
	var fx: MeteorStrikeFx = METEOR_FX_SCENE.instantiate()
	fx.position = target_position
	fx.radius = METEOR_RADIUS
	_owner_body.get_parent().add_child(fx)
	var damage: float = _scaled_power(METEOR_BASE_POWER)
	fx.impact.connect(_on_meteor_impact.bind(target_position, damage))
	AudioManager.play("meteor_cast")


func _on_meteor_impact(target_position: Vector2, damage: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if target_position.distance_to(enemy.position) <= METEOR_RADIUS:
			enemy.take_damage(damage)


## Arcs from the player to the nearest enemy, then hops to whichever
## unhit enemy is nearest the last one struck, up to LIGHTNING_MAX_HITS
## total, damage decaying a little each hop.
func _cast_lightning_chain() -> void:
	var first := _find_nearest_enemy(LIGHTNING_RANGE)
	if first == null:
		return
	var damage: float = _scaled_power(LIGHTNING_BASE_POWER)
	var hit: Array[Enemy] = []
	var current: Enemy = first
	var current_position: Vector2 = _owner_body.position
	for i in LIGHTNING_MAX_HITS:
		if current == null:
			break
		current.take_damage(damage)
		_spawn_lightning_bolt(current_position, current.position)
		hit.append(current)
		current_position = current.position
		damage *= LIGHTNING_DAMAGE_DECAY
		current = _find_chain_target(current_position, hit)
	AudioManager.play("lightning_cast")


func _find_chain_target(from_position: Vector2, exclude: Array[Enemy]) -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := LIGHTNING_CHAIN_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy in exclude:
			continue
		var distance := from_position.distance_to(enemy.position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


## Massive crowd control, light damage -- distinct from Frost Nova via a
## much bigger radius/duration/slow-strength rather than raw power.
func _cast_time_warp() -> void:
	var damage: float = _scaled_power(TIME_WARP_BASE_POWER)
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if _owner_body.position.distance_to(enemy.position) > TIME_WARP_RADIUS:
			continue
		hit_any = true
		enemy.take_damage(damage)
		enemy.apply_slow(1.0 - TIME_WARP_SLOW_STRENGTH, TIME_WARP_DURATION)
	if hit_any:
		_spawn_time_warp_graphic(_owner_body.position)
		AudioManager.play("warp_cast")


## Mobility spell: bursts damage at the departure point, blinks the player
## in their current movement direction (or a random one if standing
## still), then bursts again on arrival. Always fires -- unlike the
## damage/CC spells, repositioning is the point even when nothing's hit,
## so gating audio/visuals on hit_any does't apply here.
func _cast_teleport_pulse() -> void:
	var damage: float = _scaled_power(TELEPORT_BASE_POWER)
	var start_position: Vector2 = _owner_body.position
	_damage_in_radius(start_position, TELEPORT_BURST_RADIUS, damage)
	_spawn_burst(start_position, TELEPORT_COLOR)

	var direction: Vector2 = _teleport_direction()
	var target_position: Vector2 = start_position + direction * TELEPORT_DISTANCE
	target_position = target_position.clamp(
		Vector2(TELEPORT_ARENA_MARGIN, TELEPORT_ARENA_MARGIN),
		_owner_body.arena_size - Vector2(TELEPORT_ARENA_MARGIN, TELEPORT_ARENA_MARGIN)
	)
	_owner_body.position = target_position
	_damage_in_radius(target_position, TELEPORT_BURST_RADIUS, damage)
	_spawn_burst(target_position, TELEPORT_COLOR)
	AudioManager.play("teleport_cast")


func _teleport_direction() -> Vector2:
	if _owner_body.velocity.length() > 1.0:
		return _owner_body.velocity.normalized()
	return Vector2.RIGHT.rotated(randf() * TAU)


func _damage_in_radius(at_position: Vector2, radius: float, damage: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if at_position.distance_to(enemy.position) <= radius:
			enemy.take_damage(damage)


## "Mana-limited" per DESIGN.md's flavor text, stood in for by a fixed
## resummon cooldown + an upgradeable active duration rather than a whole
## new mana resource just for this one spell (see STAT_FAMILIAR_DURATION).
func _cast_summon_familiar() -> void:
	if _active_familiar != null and is_instance_valid(_active_familiar):
		_active_familiar.queue_free()
	var familiar: Familiar = FAMILIAR_SCENE.instantiate()
	familiar.position = _owner_body.position
	familiar.owner_body = _owner_body
	familiar.duration = MetaProgression.get_stat(MetaProgression.STAT_FAMILIAR_DURATION)
	_owner_body.get_parent().add_child(familiar)
	_active_familiar = familiar
	AudioManager.play("familiar_summon")


## Order-agnostic: fires the instant a backpack change leaves all six
## rarity tiers held simultaneously, regardless of the order they were
## collected in -- combat timing is too chaotic for a strict-sequence
## requirement to read as skill rather than bad luck.
func _on_loot_changed(backpack: Dictionary) -> void:
	if _full_set_used_this_run:
		return
	for def: LootTypeDef in LootTypes.get_types():
		if backpack.get(def.id, 0) <= 0:
			return
	_full_set_used_this_run = true
	_cast_full_set_clear()


func _cast_full_set_clear() -> void:
	var fx: MeteorStrikeFx = METEOR_FX_SCENE.instantiate()
	fx.position = _owner_body.position
	fx.radius = FULL_SET_RADIUS
	_owner_body.get_parent().add_child(fx)
	fx.impact.connect(_on_full_set_impact)
	AudioManager.play("meteor_cast")


## Unconditional -- kills every enemy currently alive regardless of
## distance from the impact point, matching DESIGN.md's "AOE clear of
## every enemy on screen" (there's only one screen/arena here, so that's
## every enemy in the group). Routed through take_damage() rather than a
## direct free() so it still triggers the normal death flow (loot drop,
## kill-count, death FX) -- a Full Set clear should feel like a reward,
## not a wasted wave of kills. Shake/hit-stop lands here, on the actual
## impact, not at cast time -- the telegraph already built the tension,
## this is the punch.
func _on_full_set_impact() -> void:
	var arena := get_tree().current_scene as Arena
	if arena != null:
		arena.trigger_shake(FULL_SET_SHAKE_SCALE, FULL_SET_HIT_STOP)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		enemy.take_damage(enemy.hp)


## Tracks consecutive same-tier pickups (resets to 1 the moment a
## different tier is collected), triggering Streak once the threshold is
## reached. Runs alongside Full Set's tracking rather than instead of it
## -- both listen to Player independently, so picking up the 6th distinct
## tier can complete a Full Set and count toward a Streak in the same
## pickup with no interaction between the two.
func _on_loot_collected(type_id: StringName) -> void:
	if type_id == _streak_tier:
		_streak_count += 1
	else:
		_streak_tier = type_id
		_streak_count = 1
	if _streak_count >= STREAK_THRESHOLD:
		_streak_count = 0
		_cast_streak_burst(type_id)


func _cast_streak_burst(tier_id: StringName) -> void:
	var tier_index: int = maxi(TIER_ORDER.find(tier_id), 0)
	var damage: float = _scaled_power(STREAK_BASE_POWER) * float(tier_index + 1)
	var def := LootTypes.get_type(tier_id)
	var color: Color = def.color if def != null else Color.WHITE
	_damage_in_radius(_owner_body.position, STREAK_RADIUS, damage)
	_spawn_burst(_owner_body.position, color)
	var arena := get_tree().current_scene as Arena
	if arena != null:
		arena.trigger_shake(STREAK_SHAKE_SCALE)
	AudioManager.play("lightning_cast")


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


func _spawn_frost_graphic(at_position: Vector2, radius: float) -> void:
	var burst: FrostBurst = FROST_BURST_SCENE.instantiate()
	burst.position = at_position
	burst.target_radius = radius
	_owner_body.get_parent().add_child(burst)


func _spawn_time_warp_graphic(at_position: Vector2) -> void:
	var burst: TimeWarpBurst = TIME_WARP_BURST_SCENE.instantiate()
	burst.position = at_position
	burst.target_radius = TIME_WARP_RADIUS
	_owner_body.get_parent().add_child(burst)


func _spawn_lightning_bolt(from_point: Vector2, to_point: Vector2) -> void:
	var bolt: LightningBoltFx = LIGHTNING_FX_SCENE.instantiate()
	bolt.from_point = from_point
	bolt.to_point = to_point
	_owner_body.get_parent().add_child(bolt)


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
