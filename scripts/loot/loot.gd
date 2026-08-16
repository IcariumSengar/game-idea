class_name Loot
extends Area2D

const SPAWN_GRACE: float = 0.15
const BOB_SPEED: float = 3.0
const BOB_AMOUNT: float = 3.0
const PULSE_SPEED: float = 4.0
const SPRITE_SCALE: float = 1.8
const PULSE_SCALE_AMOUNT: float = 0.22
const PICKUP_SPARK_AMOUNT: int = 8
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
	if _magnet_target != null:
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


func collect(player: Player) -> void:
	if player.collect_loot(type_id):
		if _is_affixed:
			player.add_bonus_loot_value(_affix_bonus_value())
		_spawn_spark()
		_spawn_value_text()
		AudioManager.play("pickup")
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect(body)


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = _color
	spark.amount = PICKUP_SPARK_AMOUNT
	spark.scale_amount_min = 1.0
	spark.scale_amount_max = 2.0
	get_parent().add_child(spark)
	spark.emitting = true


func _spawn_value_text() -> void:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	var text: Node2D = FLOATING_TEXT_SCENE.instantiate()
	text.position = position
	get_parent().add_child(text)
	if _is_affixed:
		text.setup("+%d Blessed!" % (value + _affix_bonus_value()), AFFIX_COLOR, 17)
	else:
		text.setup("+%d" % value, _color, 15)


func _affix_bonus_value() -> int:
	var def := LootTypes.get_type(type_id)
	var value: int = def.value if def != null else 1
	return roundi(value * AFFIX_VALUE_MULTIPLIER)
