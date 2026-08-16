class_name Player
extends CharacterBody2D

signal died
signal hit
signal hp_changed(current: float, max_hp: float)
signal loot_changed(backpack: Dictionary)
## Fired once per successful collect_loot() with which tier was picked up
## -- loot_changed only carries the resulting backpack state, not which
## pickup caused it, so per-pickup combo tracking (Streak) needs this
## separately.
signal loot_collected(type_id: StringName)

const RADIUS: float = 16.0
const SPARK_COLOR: Color = Color.CYAN
const FLASH_DECAY_PER_SEC: float = 6.0
const HIT_FLASH_COLOR: Color = Color(1.0, 0.35, 0.35)
const KNOCKBACK_SPEED: float = 400.0
const KNOCKBACK_DECAY_PER_SEC: float = 8.0
## Backpack-fill penalty (Tweak 4, DESIGN.md 2026-08-16): a full bag no
## longer shrinks HP -- it grows the player's sprite and actual
## CollisionShape2D radius instead, making a fuller bag a mechanically
## bigger, easier-to-hit target. Eased from an initial 1.5 (50% bigger at
## 100% fill) after live-play feedback that the penalty ramped up too
## fast -- mostly a symptom of starting Bearing capacity still being 1
## slot (fixed alongside, see meta_progression.gd), but the peak size was
## softened too on the same pass.
const MAX_SIZE_FRACTION: float = 1.3
const MIN_SPEED_FRACTION: float = 0.8
const HIT_SPARK_AMOUNT: int = 8
const SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/fx/floating_text.tscn")
const DAMAGE_TEXT_COLOR: Color = Color(1.0, 0.35, 0.35)

@export var speed: float = 250.0
@export var arena_size: Vector2 = Vector2(1280.0, 720.0)
@export var base_max_hp: float = 60.0
@export var pickup_range: float = 60.0
@export var backpack_capacity: int = 20
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

var hp: float
var max_hp: float
var backpack: Dictionary = {}
## Extra currency from affixed loot (see loot.gd) -- tracked separately
## from the backpack since affixes are a one-time value bonus on pickup,
## not a persistent property of a stack slot the way Compacting/rarity are.
var bonus_loot_value: int = 0

var _effective_speed: float = 0.0
var _max_fill_ratio: float = 0.0
var _flash_amount: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.UP
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _space_was_pressed: bool = false
var _bot_active: bool = false
var _bot_direction: Vector2 = Vector2.ZERO
var _bot_dash_requested: bool = false

@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _base_sprite_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("player")
	backpack_capacity = int(MetaProgression.get_stat(MetaProgression.STAT_BACKPACK_CAPACITY))
	pickup_range = MetaProgression.get_stat(MetaProgression.STAT_PICKUP_RANGE)
	speed = MetaProgression.get_stat(MetaProgression.STAT_MOVE_SPEED)
	_effective_speed = speed
	max_hp = base_max_hp
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_base_sprite_scale = _sprite.scale
	# Shapes on an instanced scene's local sub-resources can be shared
	# across instantiate() calls (e.g. the playtest harness spawns many
	# Players per batch) -- duplicate before ever mutating radius so one
	# instance's fill state can't leak into another's.
	_pickup_shape.shape = _pickup_shape.shape.duplicate()
	_body_shape.shape = _body_shape.shape.duplicate()
	(_pickup_shape.shape as CircleShape2D).radius = pickup_range
	_pickup_area.area_entered.connect(_on_pickup_area_entered)


func _on_pickup_area_entered(area: Area2D) -> void:
	if area is Loot and can_collect_loot(area.type_id):
		area.start_magnet(self)


func can_collect_loot(type_id: StringName) -> bool:
	var count: int = backpack.get(type_id, 0)
	var stack_size: int = LootTypes.get_effective_stack_size(type_id)
	if _needs_new_slot(count, stack_size):
		return _slots_used() < backpack_capacity
	return true


func _physics_process(delta: float) -> void:
	var input_direction := _get_input_direction()
	if input_direction != Vector2.ZERO:
		_facing = input_direction
		_sprite.flip_h = _facing.x < 0.0
		if _sprite.animation != &"run":
			_sprite.play("run")
	elif _sprite.animation != &"idle":
		_sprite.play("idle")

	_check_dash_input()

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * dash_speed
	else:
		velocity = input_direction * _effective_speed + _knockback

	move_and_slide()
	position = position.clamp(Vector2(RADIUS, RADIUS), arena_size - Vector2(RADIUS, RADIUS))

	_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY_PER_SEC * speed * delta)
	if _flash_amount > 0.0:
		_flash_amount = max(_flash_amount - FLASH_DECAY_PER_SEC * delta, 0.0)
	_sprite.modulate = Color.WHITE.lerp(HIT_FLASH_COLOR, _flash_amount)


func _check_dash_input() -> void:
	var want_dash: bool = (
		_bot_dash_requested if _bot_active else Input.is_physical_key_pressed(KEY_SPACE)
	)
	if _bot_active:
		_bot_dash_requested = false
	if want_dash and not _space_was_pressed and _dash_cooldown_left <= 0.0:
		_dash_direction = _facing
		_dash_time_left = dash_duration
		_dash_cooldown_left = dash_cooldown
		AudioManager.play("dash")
	_space_was_pressed = want_dash


## Playtest-only hook (see playtest_harness.gd/playtest_bot_ai.gd): once
## enabled, movement/dash come from bot_set_input() instead of real input.
func set_bot_control(active: bool) -> void:
	_bot_active = active


func bot_set_input(direction: Vector2, want_dash: bool) -> void:
	_bot_direction = direction
	_bot_dash_requested = want_dash


func collect_loot(type_id: StringName) -> bool:
	var count: int = backpack.get(type_id, 0)
	var stack_size: int = LootTypes.get_effective_stack_size(type_id)
	if _needs_new_slot(count, stack_size):
		if _slots_used() >= backpack_capacity:
			_try_purge()
			if _slots_used() >= backpack_capacity:
				return false
	backpack[type_id] = count + 1
	_update_fill_effects()
	loot_changed.emit(backpack)
	loot_collected.emit(type_id)
	return true


## Removes up to `count` items of `type_id` -- returns how many were
## actually removed, since a tier can hold fewer than requested. Frees
## the slot entirely once its count hits zero, same as any other way a
## stack empties.
func consume_loot(type_id: StringName, count: int) -> int:
	var available: int = backpack.get(type_id, 0)
	var removed: int = mini(available, count)
	if removed <= 0:
		return 0
	if removed >= available:
		backpack.erase(type_id)
	else:
		backpack[type_id] = available - removed
	_update_fill_effects()
	loot_changed.emit(backpack)
	return removed


## True if adding one more `type_id` item would need a slot beyond
## whatever's already allocated to it -- i.e. count is at a stack-size
## boundary (e.g. a 10-stack tier going from 10 to 11 needs a 2nd slot,
## but 7 to 8 doesn't). Slots, not distinct tiers, are what fill %/
## capacity are measured against (see DESIGN.md's Tweak 3).
func _needs_new_slot(count: int, stack_size: int) -> bool:
	var current_slots: int = ceili(float(count) / float(stack_size)) if count > 0 else 0
	var next_slots: int = ceili(float(count + 1) / float(stack_size))
	return next_slots > current_slots


## Total occupied slots: one slot per stack instance of a tier, capped by
## that tier's Compacting-modified stack size -- a tier spans multiple
## slots once its current stack is full, instead of the old "one slot per
## distinct tier touched" (which silently hard-capped fill % at the 6
## rarity tiers regardless of Bearing/Compacting level).
func _slots_used() -> int:
	var total := 0
	for type_id: StringName in backpack:
		var stack_size: int = LootTypes.get_effective_stack_size(type_id)
		total += ceili(float(backpack[type_id]) / float(stack_size))
	return total


func _try_purge() -> void:
	var purge_level := MetaProgression.get_level(MetaProgression.STAT_PURGE)
	if purge_level == 0:
		return
	var fill_ratio := float(_slots_used()) / float(backpack_capacity)
	var threshold := _get_purge_threshold(purge_level)
	if fill_ratio < threshold:
		return
	var lowest_tier := _find_lowest_rarity_type()
	if lowest_tier != StringName():
		var count: int = backpack.get(lowest_tier, 0)
		if count > 0:
			backpack[lowest_tier] = count - 1
			if backpack[lowest_tier] == 0:
				backpack.erase(lowest_tier)


func _get_purge_threshold(level: int) -> float:
	match level:
		1:
			return 0.90
		2:
			return 0.85
		3:
			return 0.80
		4:
			return 0.70
	return 0.90


func _find_lowest_rarity_type() -> StringName:
	var tiers := [&"legendary", &"mythic", &"epic", &"rare", &"uncommon", &"common"]
	for tier in tiers:
		if tier in backpack:
			return tier
	return StringName()


## Backpack fill no longer touches max_hp (Tweak 4) -- it scales speed
## down and the player's visual/physical size up instead. Renamed from
## _update_hp_from_backpack to match what it actually drives now.
func _update_fill_effects() -> void:
	var fill_ratio := float(_slots_used()) / float(backpack_capacity)
	_max_fill_ratio = max(_max_fill_ratio, fill_ratio)
	_effective_speed = speed * lerp(1.0, MIN_SPEED_FRACTION, fill_ratio)
	var size_scale: float = lerp(1.0, MAX_SIZE_FRACTION, fill_ratio)
	_sprite.scale = _base_sprite_scale * size_scale
	(_body_shape.shape as CircleShape2D).radius = RADIUS * size_scale


func get_max_fill_ratio() -> float:
	return _max_fill_ratio


func get_total_loot_value() -> int:
	var total := bonus_loot_value
	for type_id: StringName in backpack:
		var def := LootTypes.get_type(type_id)
		var value: int = def.value if def != null else 1
		total += value * int(backpack[type_id])
	return total


func add_bonus_loot_value(amount: int) -> void:
	bonus_loot_value += amount


func take_damage(amount: float, from_position: Vector2) -> void:
	if hp <= 0.0:
		return
	hit.emit()
	_flash_amount = 1.0
	_spawn_spark()
	_spawn_damage_text(amount)
	AudioManager.play("player_hit")
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


func _spawn_damage_text(amount: float) -> void:
	var text: Node2D = FLOATING_TEXT_SCENE.instantiate()
	text.position = position + Vector2(0.0, -24.0)
	get_parent().add_child(text)
	text.setup("-%d" % roundi(amount), DAMAGE_TEXT_COLOR, 22)


func _get_input_direction() -> Vector2:
	if _bot_active:
		return _bot_direction
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
