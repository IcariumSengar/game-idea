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
const FLASH_DECAY_PER_SEC: float = 6.0
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

## Active Pickup: Manual Triage (DESIGN.md 2026-08-16) -- gems no longer
## auto-commit on arrival; they queue in front of the player awaiting an
## explicit keep/discard decision. Only real-input players triage
## (see is_bot_controlled() / loot.gd's _on_body_entered) -- the playtest
## bot auto-collects same as before, so balance-signal batches stay
## meaningful without needing to simulate triage decisions.
const QUEUE_ACTIVE_OFFSET: Vector2 = Vector2(0.0, -34.0)
const QUEUE_STACK_OFFSET: Vector2 = Vector2(0.0, -13.0)
const QUEUE_STACK_SCALE: float = 0.7
## Depth Pass Group A "Queue pressure" (DESIGN.md 2026-08-17): a pending
## (undecided) gem used to cost nothing to ignore -- pure decoration until
## it resolved. Counting it toward fill % at partial weight makes a backed-
## up queue visibly heavier right now, not just once resolved. Recomputed
## fresh every time (see _update_fill_effects()) rather than tracked
## incrementally, so resolving a gem (Keep -> full slot weight, Discard ->
## zero) transitions cleanly with no separate bookkeeping to desync.
const PENDING_SLOT_WEIGHT: float = 0.5
## Depth Pass Group B "Re-point Gleam" (DESIGN.md 2026-08-17): more Gleam
## range pulls in more incoming volume, which was a pure downside once
## queue pressure landed (more gems arriving = more fill % from nothing
## but waiting). Paired bonus: each Gleam level trims the pending-slot
## weight itself, so a higher-Gleam player's queue stays roughly as
## processable per unit of incoming volume instead of just piling up
## faster. Floored, not zeroed -- queue pressure should never fully
## disappear. Tuned so the floor lands right around Gleam's own level cap
## (15), not sooner.
const MIN_PENDING_SLOT_WEIGHT: float = 0.25
const PENDING_WEIGHT_REDUCTION_PER_GLEAM_LEVEL: float = 0.0167
## Keep/discard gesture, on the same sprite. No "throw"/"interact" pose
## exists in the wizzard_m sheet (idle/run/hit are the only animations
## shipped in this asset pack) and there's no way to draw new frames --
## approximated instead with a quick tilt + hop on the existing sprite,
## the same cheap-juice technique (no new art needed) used for every
## other punch in this game. Keep leans up-and-back (an arm reaching up
## over the shoulder to stow something); Discard leans the opposite way,
## sharper and without the hop (a batting-away swipe).
const KEEP_GESTURE_DURATION: float = 0.22
const KEEP_GESTURE_HOP: float = -7.0
const KEEP_GESTURE_TILT: float = -0.32
const DISCARD_GESTURE_DURATION: float = 0.2
const DISCARD_GESTURE_TILT: float = 0.4
## Facets (DESIGN.md's "Facets," 2026-08-17): Swiftness's Face B trades
## some move speed (see MetaProgression.get_stat()'s own facet branch)
## for a dash-cooldown reduction, applied once at run start alongside
## every other MetaProgression-derived stat below. Floored, not zeroed --
## same "floored, not zeroed" caution as MIN_PENDING_SLOT_WEIGHT
## elsewhere, so a maxed-out Swiftness Face B can't reduce dash cooldown
## to a degenerate near-zero value.
const DASH_COOLDOWN_FLOOR: float = 0.15
## Phase 4 (DESIGN.md's "Phase 4: the arena becomes the antagonist,"
## 2026-08-17): periodic damage for standing outside arena.gd's current
## safe zone (see set_safe_zone()) -- doesn't clamp/teleport the player
## back in, just punishes lingering, same as a battle-royale storm
## circle. Interval-based like Enemy's own CONTACT_COOLDOWN rather than
## flat per-frame damage.
const PHASE_4_DAMAGE: float = 6.0
const PHASE_4_DAMAGE_INTERVAL: float = 0.5
## Altar boons (DESIGN.md's "Altar," 2026-08-17) -- ship one or two, not
## the full illustrative list. Spellpower and full heal, the two
## simplest; a guaranteed-tier-up boon needs new per-run drop-override
## state and is real follow-on scope, not built here.
const ALTAR_BOON_SPELLPOWER: StringName = &"spellpower"
const ALTAR_BOON_FULL_HEAL: StringName = &"full_heal"
const ALTAR_BOON_SPELLPOWER_BONUS: float = 15.0

## Gamepad support: fixed bindings, not part of Settings.DEFAULT_KEYBINDS,
## same reasoning as the hardcoded arrow-key movement fallback below -- one
## working control scheme that survives even a bad rebind, and there's only
## one local player so a single hardcoded device index is fine. Left stick
## is read as a continuous vector (see _get_joy_stick_direction()) rather
## than through Settings' keycode-based rebind map, so it needs its own
## deadzone rather than reusing a keybind.
const GAMEPAD_DEVICE: int = 0
const JOY_DEADZONE: float = 0.2

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
## not a persistent property of a stack slot the way stack size/rarity are.
var bonus_loot_value: int = 0
## Leaden's extra "ballast" weight (Depth Pass Group C, DESIGN.md
## 2026-08-17) -- same reasoning as bonus_loot_value above: the backpack
## only tracks a count per tier, not item instances, so a per-item weight
## bump is banked as a running total rather than a persistent property.
var bonus_ballast_slots: int = 0
## Temporary, in-run-only Spellpower bonus from an Altar boon -- added on
## top of MetaProgression's permanent Spellpower in
## SpellCaster._scaled_power(), not written back to MetaProgression
## itself (a run-scoped boon must never leak into the permanent stat).
var bonus_spellpower: float = 0.0

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
var _pending_gem: Loot = null
var _gem_queue: Array[Loot] = []
var _keep_was_pressed: bool = false
var _discard_was_pressed: bool = false
## Personal-best "Most Refused" (DESIGN.md's HUD + death-summary rework,
## 2026-08-17) -- total discards this run, read by hud.gd at death.
var _discards_this_run: int = 0
## Phase 4's safe zone (see set_safe_zone()) -- defaults to the full
## arena so a standalone Player in a unit test that never calls
## set_safe_zone() (no Arena parent driving it) never takes this damage.
var _safe_zone: Rect2 = Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
var _phase4_damage_cooldown: float = 0.0

@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
## Public (unlike the private onreadys above) -- hud.gd reads Streak
## progress off this for the combo-nearing pips.
@onready var spell_caster: SpellCaster = $SpellCaster

var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	backpack_capacity = int(MetaProgression.get_stat(MetaProgression.STAT_BACKPACK_CAPACITY))
	pickup_range = MetaProgression.get_stat(MetaProgression.STAT_PICKUP_RANGE)
	speed = MetaProgression.get_stat(MetaProgression.STAT_MOVE_SPEED)
	dash_cooldown = maxf(
		dash_cooldown - MetaProgression.get_facet_bonus(MetaProgression.STAT_MOVE_SPEED),
		DASH_COOLDOWN_FLOOR
	)
	_effective_speed = speed
	max_hp = base_max_hp
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_base_sprite_scale = _sprite.scale
	_base_sprite_position = _sprite.position
	# Shapes on an instanced scene's local sub-resources can be shared
	# across instantiate() calls (e.g. the playtest harness spawns many
	# Players per batch) -- duplicate before ever mutating radius so one
	# instance's fill state can't leak into another's.
	_pickup_shape.shape = _pickup_shape.shape.duplicate()
	_body_shape.shape = _body_shape.shape.duplicate()
	(_pickup_shape.shape as CircleShape2D).radius = pickup_range
	_pickup_area.area_entered.connect(_on_pickup_area_entered)


## Bots still gate magnetizing on backpack capacity (matches the old
## full-auto pickup exactly, so playtest balance signal doesn't shift).
## Real players don't -- Gleam is now "how far away a gem starts being
## eligible to queue," not "how much gets vacuumed in"; whether it fits
## is resolved later, at the keep decision, not at magnet-start.
func _on_pickup_area_entered(area: Area2D) -> void:
	if area is not Loot:
		return
	if _bot_active:
		if can_collect_loot(area.type_id):
			area.start_magnet(self)
	else:
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
	_sprite.modulate = Color.WHITE.lerp(Palette.PLAYER_HIT_FLASH, _flash_amount)

	_check_triage_input()
	_reposition_queue()
	_check_phase4_damage(delta)


func _check_dash_input() -> void:
	var want_dash: bool = (
		_bot_dash_requested
		if _bot_active
		else (
			Input.is_physical_key_pressed(Settings.get_keybind(&"dash"))
			or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_A)
		)
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


func is_bot_controlled() -> bool:
	return _bot_active


func collect_loot(type_id: StringName) -> bool:
	var count: int = backpack.get(type_id, 0)
	var stack_size: int = LootTypes.get_effective_stack_size(type_id)
	if _needs_new_slot(count, stack_size) and _slots_used() >= backpack_capacity:
		return false
	backpack[type_id] = count + 1
	_update_fill_effects()
	loot_changed.emit(backpack)
	loot_collected.emit(type_id)
	return true


## Called by loot.gd once a magnetized gem physically reaches the player
## (real-input players only -- bots skip the queue entirely and collect
## directly, see loot.gd's _on_body_entered). Becomes the active/front
## gem immediately if nothing's already pending, otherwise waits behind
## it -- no cap, so a neglected queue backing up under pressure is the
## intended tension, not something to design away by default.
func enqueue_loot(loot: Loot) -> void:
	if _pending_gem == null:
		_pending_gem = loot
	else:
		_gem_queue.append(loot)
	loot.enter_queue()
	_reposition_queue()
	_update_fill_effects()


func _check_triage_input() -> void:
	if _bot_active or _pending_gem == null:
		return
	var want_keep := (
		Input.is_physical_key_pressed(Settings.get_keybind(&"keep"))
		or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_RIGHT_SHOULDER)
	)
	var want_discard := (
		Input.is_physical_key_pressed(Settings.get_keybind(&"discard"))
		or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_LEFT_SHOULDER)
	)
	if want_keep and not _keep_was_pressed:
		# A full backpack can refuse the Keep (collect() returns false) --
		# leave the gem queued rather than advancing past it, so it isn't
		# silently orphaned (untracked, unfreed) the way it used to be.
		if _pending_gem.collect(self):
			_play_keep_gesture()
			_advance_queue()
	elif want_discard and not _discard_was_pressed:
		_pending_gem.resolve_discard(_facing, position)
		_play_discard_gesture()
		_advance_queue()
		_discards_this_run += 1
	_keep_was_pressed = want_keep
	_discard_was_pressed = want_discard


## Arm-reaching-up-and-back read: a hop plus a backward tilt, easing out
## sharply then settling back to neutral -- see the QUEUE_ACTIVE_OFFSET
## block above for why this is a tilt/hop rather than a real animation.
func _play_keep_gesture() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(
			_sprite,
			"position:y",
			_base_sprite_position.y + KEEP_GESTURE_HOP,
			KEEP_GESTURE_DURATION * 0.4
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(_sprite, "rotation", KEEP_GESTURE_TILT, KEEP_GESTURE_DURATION * 0.4)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. tween_property(
			_sprite, "position:y", _base_sprite_position.y, KEEP_GESTURE_DURATION * 0.6
		)
		. set_delay(KEEP_GESTURE_DURATION * 0.4)
	)
	tween.tween_property(_sprite, "rotation", 0.0, KEEP_GESTURE_DURATION * 0.6).set_delay(
		KEEP_GESTURE_DURATION * 0.4
	)


## Batting-away swipe: a sharper opposite-direction tilt, no hop -- reads
## as pushing something off rather than reaching for it.
func _play_discard_gesture() -> void:
	var tween := create_tween()
	(
		tween
		. tween_property(_sprite, "rotation", DISCARD_GESTURE_TILT, DISCARD_GESTURE_DURATION * 0.35)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(_sprite, "rotation", 0.0, DISCARD_GESTURE_DURATION * 0.65)


## Promotes the next queued gem (if any) to active. Left null if the
## queue's empty -- collect()/resolve_discard() on the old pending gem
## already freed it (eventually, via its own pop/fade tween), so there's
## nothing to clean up here beyond the reference itself.
func _advance_queue() -> void:
	_pending_gem = _gem_queue.pop_front() if not _gem_queue.is_empty() else null
	_reposition_queue()
	_update_fill_effects()


## Re-anchors every queued gem to the player each frame -- called from
## _physics_process so the whole queue follows while the player moves,
## not just on enqueue. The active gem sits just above the player; each
## gem behind it stacks further up and renders smaller, so a backed-up
## queue reads as visibly mounting pressure rather than a hidden counter.
func _reposition_queue() -> void:
	if _pending_gem != null:
		_pending_gem.position = position + QUEUE_ACTIVE_OFFSET
		_pending_gem.scale = Vector2.ONE
	for i in _gem_queue.size():
		_gem_queue[i].position = position + QUEUE_ACTIVE_OFFSET + QUEUE_STACK_OFFSET * float(i + 1)
		_gem_queue[i].scale = Vector2.ONE * QUEUE_STACK_SCALE


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


## Altar's pure sacrifice (DESIGN.md's "Altar," 2026-08-17) -- reuses
## consume_loot()'s actual backpack removal (already exactly "subtract
## from backpack directly, no value/Cast Off path") but all-or-nothing:
## checks affordability first rather than consume_loot()'s own
## partial-removal semantics (built for the since-removed Backpack
## Ability, where "however much is available" was the intended
## behavior). Distinct from collect_loot()/resolve_discard() -- no value
## banked, no Cast Off throw, a pure sacrifice.
func sacrifice_loot(type_id: StringName, count: int) -> bool:
	if backpack.get(type_id, 0) < count:
		return false
	consume_loot(type_id, count)
	return true


func apply_altar_boon(boon_id: StringName) -> void:
	match boon_id:
		ALTAR_BOON_SPELLPOWER:
			bonus_spellpower += ALTAR_BOON_SPELLPOWER_BONUS
		ALTAR_BOON_FULL_HEAL:
			_set_hp(max_hp)


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
## that tier's fixed stack size (Compacting, previously a lever on this,
## was removed entirely -- DESIGN.md 2026-08-16) -- a tier spans multiple
## slots once its current stack is full, instead of the old "one slot per
## distinct tier touched" (which silently hard-capped fill % at the 6
## rarity tiers regardless of Bearing level). Delegates to LootTypes so
## HUD/BackpackGrid can read the exact same number instead of re-deriving
## it (DESIGN.md 2026-08-17 bugfix -- they were still reading the old
## distinct-tier-count formula). Includes Leaden's ballast (Depth Pass
## Group C) on top of the real tier-derived count.
func _slots_used() -> int:
	return LootTypes.count_slots_used(backpack) + bonus_ballast_slots


## Public wrapper for HUD/UI callers -- _slots_used() stays private-by-
## convention for internal use (fill ratio, etc.).
func get_slots_used() -> int:
	return _slots_used()


## Attunement (Depth Pass Group D, DESIGN.md 2026-08-17): weighted average
## tier-index of everything currently held, normalized 0.0-1.0 -- Low
## (Common-heavy) to High (Legendary-heavy). Recomputed fresh each call
## (no cached/stored state), same pattern as _slots_used(), so it's always
## "live" without needing its own change-signal. Callers must check
## backpack.is_empty() separately (see spell_caster.gd) -- an empty bag is
## its own distinct worst case per the design, not just attunement 0.0.
func get_attunement() -> float:
	if backpack.is_empty():
		return 0.0
	var weighted_sum := 0.0
	var total_count := 0
	for type_id: StringName in backpack:
		var count: int = backpack[type_id]
		weighted_sum += float(LootTypes.get_tier_index(type_id) * count)
		total_count += count
	var average_tier_index: float = weighted_sum / float(total_count)
	return average_tier_index / float(LootTypes.get_tier_count() - 1)


func add_ballast_slots(amount: int) -> void:
	bonus_ballast_slots += amount
	_update_fill_effects()


func get_ballast_slots() -> int:
	return bonus_ballast_slots


## Number of gems currently pending a keep/discard decision (active + queued
## behind it) -- weighted at less than a real slot in _update_fill_effects()
## below, so a backed-up queue applies pressure without being penalized as
## harshly as loot already committed to the backpack.
func _pending_queue_size() -> int:
	return (1 if _pending_gem != null else 0) + _gem_queue.size()


## Depth Pass Group B: Gleam's paired queue-processability bonus -- see the
## PENDING_WEIGHT_REDUCTION_PER_GLEAM_LEVEL const above.
func _pending_slot_weight() -> float:
	var gleam_level: int = MetaProgression.get_level(MetaProgression.STAT_PICKUP_RANGE)
	return maxf(
		MIN_PENDING_SLOT_WEIGHT,
		PENDING_SLOT_WEIGHT - float(gleam_level) * PENDING_WEIGHT_REDUCTION_PER_GLEAM_LEVEL
	)


## Backpack fill no longer touches max_hp (Tweak 4) -- it scales speed
## down and the player's visual/physical size up instead. Renamed from
## _update_hp_from_backpack to match what it actually drives now. Also
## called on every queue change (enqueue/advance), not just on real
## backpack changes, since Group A's queue pressure (DESIGN.md 2026-08-17)
## means pending gems already weigh on fill % before they're resolved.
func _update_fill_effects() -> void:
	var effective_slots: float = (
		float(_slots_used()) + float(_pending_queue_size()) * _pending_slot_weight()
	)
	var fill_ratio: float = clampf(effective_slots / float(backpack_capacity), 0.0, 1.0)
	_max_fill_ratio = max(_max_fill_ratio, fill_ratio)
	_effective_speed = speed * lerp(1.0, MIN_SPEED_FRACTION, fill_ratio)
	var size_scale: float = lerp(1.0, MAX_SIZE_FRACTION, fill_ratio)
	_sprite.scale = _base_sprite_scale * size_scale
	(_body_shape.shape as CircleShape2D).radius = RADIUS * size_scale


func get_max_fill_ratio() -> float:
	return _max_fill_ratio


func get_discards_this_run() -> int:
	return _discards_this_run


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
	spark.color = Palette.PLAYER_SPARK
	spark.amount = HIT_SPARK_AMOUNT
	get_parent().add_child(spark)
	spark.emitting = true


func _spawn_damage_text(amount: float) -> void:
	var text: Node2D = FLOATING_TEXT_SCENE.instantiate()
	text.position = position + Vector2(0.0, -24.0)
	get_parent().add_child(text)
	text.setup("-%d" % roundi(amount), Palette.PLAYER_DAMAGE_TEXT, 22)


## Called every frame by arena.gd once Phase 4 starts (see its own
## get_safe_zone_rect()) -- a no-op call with the full-arena default
## outside Phase 4, or in any context with no Arena driving it.
func set_safe_zone(rect: Rect2) -> void:
	_safe_zone = rect


func _check_phase4_damage(delta: float) -> void:
	_phase4_damage_cooldown = maxf(_phase4_damage_cooldown - delta, 0.0)
	if _safe_zone.has_point(position) or _phase4_damage_cooldown > 0.0:
		return
	take_damage(PHASE_4_DAMAGE, position)
	_phase4_damage_cooldown = PHASE_4_DAMAGE_INTERVAL


func _get_input_direction() -> Vector2:
	if _bot_active:
		return _bot_direction
	var dir := Vector2.ZERO
	if (
		Input.is_physical_key_pressed(Settings.get_keybind(&"move_up"))
		or Input.is_physical_key_pressed(KEY_UP)
		or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_UP)
	):
		dir.y -= 1.0
	if (
		Input.is_physical_key_pressed(Settings.get_keybind(&"move_down"))
		or Input.is_physical_key_pressed(KEY_DOWN)
		or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_DOWN)
	):
		dir.y += 1.0
	if (
		Input.is_physical_key_pressed(Settings.get_keybind(&"move_left"))
		or Input.is_physical_key_pressed(KEY_LEFT)
		or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_LEFT)
	):
		dir.x -= 1.0
	if (
		Input.is_physical_key_pressed(Settings.get_keybind(&"move_right"))
		or Input.is_physical_key_pressed(KEY_RIGHT)
		or Input.is_joy_button_pressed(GAMEPAD_DEVICE, JOY_BUTTON_DPAD_RIGHT)
	):
		dir.x += 1.0
	# limit_length() rather than normalized(): keyboard/d-pad input is always
	# exactly unit length already (or zero), so this is a no-op for them, but
	# it lets the analog stick contribute partial magnitude below instead of
	# being snapped to full speed on the lightest tilt.
	return (dir + _get_joy_stick_direction()).limit_length(1.0)


## Left stick, kept separate from the digital d-pad/keyboard block above
## since it reports a continuous vector rather than a fixed +-1 per axis.
func _get_joy_stick_direction() -> Vector2:
	var stick := Vector2(
		Input.get_joy_axis(GAMEPAD_DEVICE, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(GAMEPAD_DEVICE, JOY_AXIS_LEFT_Y)
	)
	return stick if stick.length() >= JOY_DEADZONE else Vector2.ZERO
