class_name Loot
extends Area2D

const SPAWN_GRACE: float = 0.15
const BOB_SPEED: float = 3.0
const BOB_AMOUNT: float = 3.0
const PULSE_SPEED: float = 4.0
## Sized alongside loot_gem.gd's shape constants -- went too small after
## the "pips, not gems" cut, sized back up on live-play feedback (needs
## to read as trackable/followable, not just "quiet").
const SPRITE_SCALE: float = 1.6
const PULSE_SCALE_AMOUNT: float = 0.22
## Pickup-moment feedback, per the "pips, not gems" rework (DESIGN.md/
## TODO.md): resting pips are deliberately quiet, so the payoff moves
## here instead -- a bigger spark burst plus a quick pop-and-fade on the
## sprite itself before it frees.
const PICKUP_SPARK_AMOUNT: int = 14
const COLLECT_POP_DURATION: float = 0.18
const COLLECT_POP_SCALE: float = 2.4
const SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/fx/floating_text.tscn")
## Loot affixes, per DESIGN.md's "higher tiers drop items with +modifiers"
## note. Individual backpack items aren't tracked as instances (just a
## count per tier), so an affix can't persist as a stack-slot property --
## instead it's a one-time bonus awarded straight to Player.bonus_loot_value
## on pickup, with its own distinct color/pulse/floating-text so it still
## reads as a special drop in the moment, even though it doesn't linger.
const AFFIX_CHANCE_BY_TIER: Dictionary = {&"epic": 0.15, &"mythic": 0.25, &"legendary": 0.4}
const AFFIX_VALUE_MULTIPLIER: float = 0.5
const AFFIX_PULSE_SCALE_AMOUNT: float = 0.4
const AFFIX_COLOR: Color = Color(1.0, 0.85, 0.3)
## Leaden (Depth Pass Group C, DESIGN.md 2026-08-17): Blessed's dark mirror
## -- more value, but folds extra "ballast" weight into the player's real
## slot count even though it's still one item, so a high-value pickup can
## finally be a genuine space gamble instead of an always-correct Keep.
## Same AFFIX_CHANCE_BY_TIER roll as Blessed; a second coin-flip on a
## successful roll decides which of the two it becomes.
const AFFIX_LEADEN_CHANCE: float = 0.5
const LEADEN_VALUE_MULTIPLIER: float = 0.8
const LEADEN_BALLAST_SLOTS: int = 1
const LEADEN_PULSE_SCALE_AMOUNT: float = 0.12
const LEADEN_PULSE_SPEED: float = 2.0
const LEADEN_COLOR: Color = Color(0.35, 0.32, 0.3)
## A Magpie (Depth Pass Group C) that dies after eating drops everything
## it stole back at its death position, at a bonus -- the reward for
## catching it in time rather than a straight refund.
const RECOVERED_VALUE_BONUS_MULTIPLIER: float = 0.5
const RECOVERED_COLOR: Color = Color(0.4, 0.85, 0.6)
const DISCARD_FADE_DURATION: float = 0.22
## Scatter (Depth Pass Group C): rarity scales how far a drop skitters from
## its kill site -- Common lands ~in place, Legendary skitters toward the
## edge. arena.gd computes the actual offset (it knows the kill position
## and arena bounds); this just plays the launch-and-settle hop.
const SCATTER_DURATION: float = 0.35
## Cast Off (DESIGN.md's Depth Pass Group A, 2026-08-17): Discard no longer
## deletes the gem in place -- it throws it in the player's facing
## direction, dealing tier-scaled damage/knockback on impact, no value
## banked. Reuses Streak's tier-index multiplier (LootTypes.get_tier_index())
## rather than inventing a second one. Deliberately not Spellpower-scaled
## like the 8 spells are: this is the gem itself hurting something on the
## way out, not a cast.
const CAST_OFF_DISTANCE: float = 180.0
const CAST_OFF_FLIGHT_DURATION: float = 0.22
const CAST_OFF_IMPACT_RADIUS: float = 40.0
const CAST_OFF_KNOCKBACK_STRENGTH: float = 150.0
const CAST_OFF_BASE_DAMAGE: float = 10.0
const CAST_OFF_SPIN_TURNS: float = 1.0

## Pull speed (px/s) at zero pickup range. Combined with pull_speed_per_range
## below to get the actual homing speed once magnetized.
@export var pull_speed_base: float = 60.0
## Extra pull speed (px/s) added per point of the player's pickup_range —
## this is what makes upgrading the magnet stat visibly pull loot in faster.
@export var pull_speed_per_range: float = 4.0

var type_id: StringName = &"common"

var _time: float = randf() * TAU
var _magnet_target: Player = null
var _pull_speed: float = 0.0
var _color: Color = Color.WHITE
var _is_affixed: bool = false
var _is_leaden: bool = false
var _is_recovered: bool = false
var _pulse_scale_amount: float = PULSE_SCALE_AMOUNT
var _pulse_speed: float = PULSE_SPEED
## Set once this gem reaches a real-input player and enters their triage
## queue (see player.gd's enqueue_loot()) -- Player then drives position
## directly each frame, so magnet-chasing has to stop or the two would
## fight over it. Bob/pulse keep running -- a queued gem stays visibly
## "alive," not frozen dead, while it waits.
var _is_queued: bool = false
## True while a Scatter launch tween owns `position` -- magnet-chasing must
## not also write to `position` during this window (see _process() below).
var _is_scattering: bool = false

@onready var _sprite: Node2D = $Gem


func _ready() -> void:
	add_to_group("loot")
	var def := LootTypes.get_type(type_id)
	if def != null:
		_color = def.color
	if randf() < float(AFFIX_CHANCE_BY_TIER.get(type_id, 0.0)):
		if randf() < AFFIX_LEADEN_CHANCE:
			_is_leaden = true
			_color = _color.lerp(LEADEN_COLOR, 0.6)
			_pulse_scale_amount = LEADEN_PULSE_SCALE_AMOUNT
			_pulse_speed = LEADEN_PULSE_SPEED
		else:
			_is_affixed = true
			_color = _color.lerp(AFFIX_COLOR, 0.5)
			_pulse_scale_amount = AFFIX_PULSE_SCALE_AMOUNT
	_sprite.modulate = _color
	# Deferred: loot can spawn synchronously from inside a physics signal
	# callback (an AOE spell killing an enemy mid body_entered), and setting
	# these directly there is rejected by the physics server as "flushing
	# queries" -- see enemy.gd's take_damage() -> arena.gd's _on_enemy_died().
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	get_tree().create_timer(SPAWN_GRACE).timeout.connect(_enable_pickup)


func _process(delta: float) -> void:
	_time += delta
	if _magnet_target != null and not _is_queued and not _is_scattering:
		position = position.move_toward(_magnet_target.position, _pull_speed * delta)
	_sprite.position.y = sin(_time * BOB_SPEED) * BOB_AMOUNT
	var pulse: float = SPRITE_SCALE + sin(_time * _pulse_speed) * _pulse_scale_amount
	_sprite.scale = Vector2(pulse, pulse)


func _enable_pickup() -> void:
	# Deferred for the same reason as _ready() above -- this timer can land
	# back inside an active physics flush during dense combat.
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func start_magnet(player: Player) -> void:
	if _magnet_target != null:
		return
	_magnet_target = player
	_pull_speed = pull_speed_base + player.pickup_range * pull_speed_per_range


## Returns whether the pickup actually succeeded (the backpack had room) --
## callers must not treat a failed collect as consumed (see player.gd's
## _check_triage_input(), which leaves a denied gem queued rather than
## advancing past it).
func collect(player: Player) -> bool:
	if not player.collect_loot(type_id):
		return false
	if _is_affixed:
		player.add_bonus_loot_value(_affix_bonus_value())
	elif _is_leaden:
		player.add_bonus_loot_value(_leaden_bonus_value())
		player.add_ballast_slots(LEADEN_BALLAST_SLOTS)
	if _is_recovered:
		player.add_bonus_loot_value(_recovered_bonus_value())
	_spawn_spark()
	_spawn_value_text()
	AudioManager.play("pickup")
	set_deferred("monitoring", false)
	_play_collect_pop()
	return true


## Bots skip the queue entirely and collect immediately, same as the old
## full-auto pickup -- see player.gd's is_bot_controlled() docstring for
## why. Real players hand off to the triage queue instead of committing.
func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	if body.is_bot_controlled():
		collect(body)
	else:
		body.enqueue_loot(self)


## Marks this gem as queued and stops its own position updates -- Player
## takes over from here (see its _reposition_queue()). Also stops
## monitoring: once queued it sits pinned right next to the player every
## frame, which would otherwise keep re-firing _on_body_entered.
func enter_queue() -> void:
	_is_queued = true
	set_deferred("monitoring", false)
	AudioManager.play_rarity_cue(type_id)


## True while a Magpie (Depth Pass Group C) can steal this gem -- already-
## queued loot has committed to the player's triage decision and is off-
## limits; anything else on the ground (including mid-flight to a magnet)
## is fair game.
func is_available_to_steal() -> bool:
	return not _is_queued


## Called by EnemyMagpie once it reaches this gem -- removed without any
## player interaction. Returns the tier so the thief can remember what it
## ate and drop it back (see EnemyMagpie's _on_died()).
func steal() -> StringName:
	var stolen_type: StringName = type_id
	set_deferred("monitoring", false)
	queue_free()
	return stolen_type


## Marks this instance as loot recovered from a killed Magpie -- adds a
## bonus on top of whatever else it would have paid out (see collect()).
func mark_recovered() -> void:
	_is_recovered = true


## Scatter (Depth Pass Group C): plays the launch-and-settle hop toward
## `offset` (already computed and arena-clamped by arena.gd). No-ops for a
## ~zero offset (Common/Uncommon) rather than playing a pointless tween.
func launch_scatter(offset: Vector2) -> void:
	if offset.length() < 1.0:
		return
	_is_scattering = true
	var destination: Vector2 = position + offset
	var tween := create_tween()
	(
		tween
		. tween_property(self, "position", destination, SCATTER_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.finished.connect(func() -> void: _is_scattering = false)


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = _color
	spark.amount = PICKUP_SPARK_AMOUNT
	spark.scale_amount_min = 1.2
	spark.scale_amount_max = 2.6
	get_parent().add_child(spark)
	spark.emitting = true


func _spawn_value_text() -> void:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	var text: Node2D = FLOATING_TEXT_SCENE.instantiate()
	text.position = position
	get_parent().add_child(text)
	var bonus := 0
	if _is_affixed:
		bonus = _affix_bonus_value()
	elif _is_leaden:
		bonus = _leaden_bonus_value()
	if _is_recovered:
		bonus += _recovered_bonus_value()
	if _is_affixed:
		text.setup("+%d Blessed!" % (value + bonus), AFFIX_COLOR, 20)
	elif _is_leaden:
		text.setup("+%d, Leaden" % (value + bonus), LEADEN_COLOR, 20)
	elif _is_recovered:
		text.setup("+%d, Recovered!" % (value + bonus), RECOVERED_COLOR, 20)
	else:
		text.setup("+%d" % value, _color, 18)


## Quick pop-and-fade on the sprite itself before the node frees -- the
## resting pip is deliberately quiet, so this is where the pickup reads
## as snappy instead. Movement (magnet pull/bob/pulse) stops immediately
## so the pop plays in place rather than mid-slide.
func _play_collect_pop() -> void:
	set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(_sprite, "scale", Vector2.ONE * COLLECT_POP_SCALE, COLLECT_POP_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(_sprite, "modulate:a", 0.0, COLLECT_POP_DURATION)
	tween.chain().tween_callback(queue_free)


## Manual Triage's discard path (player.gd's _check_triage_input()) -- Cast
## Off (DESIGN.md's Depth Pass Group A): gone for good, no value banked
## exactly as before, but now it *does* something on the way out instead of
## just fading in place -- thrown along the player's facing direction,
## dealing tier-scaled damage/knockback to whatever it lands near.
func resolve_discard(facing: Vector2, owner_position: Vector2) -> void:
	set_deferred("monitoring", false)
	AudioManager.play("discard")
	set_process(false)
	var impact_position: Vector2 = owner_position + facing * CAST_OFF_DISTANCE
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "position", impact_position, CAST_OFF_FLIGHT_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(
		_sprite,
		"rotation",
		TAU * CAST_OFF_SPIN_TURNS * signf(facing.x if facing.x != 0.0 else 1.0),
		CAST_OFF_FLIGHT_DURATION
	)
	tween.chain().tween_callback(_impact.bind(impact_position))


## Landing moment: deals damage/knockback to anything within
## CAST_OFF_IMPACT_RADIUS, same take_damage()/apply_knockback() path every
## other damage source in the game already uses, then fades exactly like
## the old in-place discard did.
func _impact(impact_position: Vector2) -> void:
	var damage := _cast_off_damage()
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if impact_position.distance_to(enemy.position) <= CAST_OFF_IMPACT_RADIUS:
			hit_any = true
			enemy.take_damage(damage)
			enemy.apply_knockback(impact_position, CAST_OFF_KNOCKBACK_STRENGTH)
	_spawn_spark()
	if hit_any:
		AudioManager.play("cast_off_impact")
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_sprite, "scale", _sprite.scale * 0.4, DISCARD_FADE_DURATION)
	fade_tween.tween_property(_sprite, "modulate:a", 0.0, DISCARD_FADE_DURATION)
	fade_tween.chain().tween_callback(queue_free)


## Discard's level (Depth Pass Group B, DESIGN.md 2026-08-17) adds flat
## bonus damage on top of the tier-scaled base -- read generically via
## get_stat() since STAT_PURGE's per_level_gain now *is* that bonus.
func _cast_off_damage() -> float:
	var tier_index: int = LootTypes.get_tier_index(type_id)
	var base: float = CAST_OFF_BASE_DAMAGE * float(tier_index + 1)
	return base + MetaProgression.get_stat(MetaProgression.STAT_PURGE)


func _affix_bonus_value() -> int:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	return roundi(value * AFFIX_VALUE_MULTIPLIER)


func _leaden_bonus_value() -> int:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	return roundi(value * LEADEN_VALUE_MULTIPLIER)


func _recovered_bonus_value() -> int:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	return roundi(value * RECOVERED_VALUE_BONUS_MULTIPLIER)
