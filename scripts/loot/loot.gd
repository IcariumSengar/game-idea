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
const DISCARD_FADE_DURATION: float = 0.22
## Cast Off (DESIGN.md's Depth Pass Group A, 2026-08-17): Discard no longer
## deletes the gem in place -- it throws it in the player's facing
## direction, dealing tier-scaled damage/knockback on impact, no value
## banked. Reuses Streak's tier-index multiplier table (spell_caster.gd's
## TIER_ORDER) rather than inventing a second one -- see CAST_OFF_TIER_ORDER
## below. Deliberately not Spellpower-scaled like the 8 spells are: this is
## the gem itself hurting something on the way out, not a cast.
const CAST_OFF_DISTANCE: float = 180.0
const CAST_OFF_FLIGHT_DURATION: float = 0.22
const CAST_OFF_IMPACT_RADIUS: float = 40.0
const CAST_OFF_KNOCKBACK_STRENGTH: float = 150.0
const CAST_OFF_BASE_DAMAGE: float = 10.0
const CAST_OFF_SPIN_TURNS: float = 1.0
const CAST_OFF_TIER_ORDER: Array[StringName] = [
	&"common", &"uncommon", &"rare", &"epic", &"mythic", &"legendary"
]

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
var _pulse_scale_amount: float = PULSE_SCALE_AMOUNT
## Set once this gem reaches a real-input player and enters their triage
## queue (see player.gd's enqueue_loot()) -- Player then drives position
## directly each frame, so magnet-chasing has to stop or the two would
## fight over it. Bob/pulse keep running -- a queued gem stays visibly
## "alive," not frozen dead, while it waits.
var _is_queued: bool = false

@onready var _sprite: Node2D = $Gem


func _ready() -> void:
	var def := LootTypes.get_type(type_id)
	if def != null:
		_color = def.color
	_is_affixed = randf() < float(AFFIX_CHANCE_BY_TIER.get(type_id, 0.0))
	if _is_affixed:
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
	if _magnet_target != null and not _is_queued:
		position = position.move_toward(_magnet_target.position, _pull_speed * delta)
	_sprite.position.y = sin(_time * BOB_SPEED) * BOB_AMOUNT
	var pulse: float = SPRITE_SCALE + sin(_time * PULSE_SPEED) * _pulse_scale_amount
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
	if _is_affixed:
		text.setup("+%d Blessed!" % (value + _affix_bonus_value()), AFFIX_COLOR, 20)
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


func _cast_off_damage() -> float:
	var tier_index: int = maxi(CAST_OFF_TIER_ORDER.find(type_id), 0)
	return CAST_OFF_BASE_DAMAGE * float(tier_index + 1)


func _affix_bonus_value() -> int:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	return roundi(value * AFFIX_VALUE_MULTIPLIER)
