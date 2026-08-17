extends Node

## Headless pure-logic unit-test runner. Launch with:
##
##   Godot.exe --headless --path . -- --unit-test
##
## Self-contained assertion runner (no GUT/gdUnit4 dependency), same style
## as playtest_harness.gd -- for formulas that don't need a full run to
## verify (cost curves, drop-weight math, stat lerps), where the playtest
## harness would be a slow, indirect way to catch what a five-line
## assertion catches instantly. Prints PASS/FAIL per case and exits
## non-zero on any failure.
##
## Runs against the live MetaProgression/LootTypes autoloads rather than
## reimplementing their data -- save_manager.gd's _playtest_mode also
## triggers on --unit-test, so this never touches the player's real save
## (see SaveManager.PLAYTEST_SLOT).

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--unit-test" in args:
		return
	print("=== UNIT TESTS ===")
	_test_meta_progression_cost_and_stat_curve()
	_test_meta_progression_level_cap()
	_test_meta_progression_buy_upgrade()
	_test_loot_weighted_pick()
	_test_loot_effective_stack_size()
	_test_loot_slot_accounting()
	_test_backpack_fill_effects()
	_test_backpack_slots_used()
	_test_manual_triage_queue()
	_test_queue_pressure()
	_test_collect_denied_when_full()
	_test_cast_off_damage()
	_test_gleam_pending_weight_reduction()
	_test_combo_discovery_save_round_trip()
	await _test_gem_combo_full_set()
	print("=== %d passed, %d failed ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _assert(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		print("  FAIL  %s" % label)


func _almost_eq(a: float, b: float, epsilon: float = 0.01) -> bool:
	return absf(a - b) <= epsilon


## Verifies get_cost()/get_stat() against the documented formula
## (cost(level) = round(base_cost * cost_growth^level), stat(level) =
## base_value + level * per_level_gain) using each def's own live fields,
## not hardcoded balance numbers -- stays valid across balance passes.
func _test_meta_progression_cost_and_stat_curve() -> void:
	for def: StatDef in MetaProgression.get_stat_defs():
		var original_level := MetaProgression.get_level(def.id)
		var probe_level: int = mini(3, def.level_cap)
		MetaProgression.debug_set_level(def.id, probe_level)
		var expected_cost := roundi(float(def.base_cost) * pow(def.cost_growth, probe_level))
		var expected_stat: float = def.base_value + float(probe_level) * def.per_level_gain
		_assert(
			MetaProgression.get_cost(def.id) == expected_cost,
			"%s cost at level %d == %d" % [def.id, probe_level, expected_cost]
		)
		_assert(
			_almost_eq(MetaProgression.get_stat(def.id), expected_stat),
			"%s stat value at level %d == %.2f" % [def.id, probe_level, expected_stat]
		)
		MetaProgression.debug_set_level(def.id, original_level)


func _test_meta_progression_level_cap() -> void:
	for def: StatDef in MetaProgression.get_stat_defs():
		var original_level := MetaProgression.get_level(def.id)
		MetaProgression.debug_set_level(def.id, def.level_cap)
		_assert(MetaProgression.is_maxed(def.id), "%s is maxed at level_cap" % def.id)
		if def.level_cap > 0:
			MetaProgression.debug_set_level(def.id, def.level_cap - 1)
			_assert(not MetaProgression.is_maxed(def.id), "%s is not maxed one below cap" % def.id)
		MetaProgression.debug_set_level(def.id, original_level)


## Exercises buy_upgrade() against one PLAYER-pool and one BACKPACK-pool
## stat: rejects when underfunded, spends exactly get_cost() from the
## right pool and leaves the other untouched, and refuses once maxed even
## with unlimited currency.
func _test_meta_progression_buy_upgrade() -> void:
	var player_stat := MetaProgression.STAT_DAMAGE
	var backpack_stat := MetaProgression.STAT_BACKPACK_CAPACITY
	for id in [player_stat, backpack_stat]:
		var def: StatDef = null
		for candidate: StatDef in MetaProgression.get_stat_defs():
			if candidate.id == id:
				def = candidate
		var original_level := MetaProgression.get_level(id)
		var original_player_currency := MetaProgression.player_currency
		var original_backpack_currency := MetaProgression.backpack_currency
		MetaProgression.debug_set_level(id, 0)

		var cost := MetaProgression.get_cost(id)
		MetaProgression.player_currency = 0
		MetaProgression.backpack_currency = 0
		_assert(not MetaProgression.buy_upgrade(id), "%s buy_upgrade fails when underfunded" % id)
		_assert(MetaProgression.get_level(id) == 0, "%s level unchanged after failed buy" % id)

		match def.currency:
			StatDef.Currency.PLAYER:
				MetaProgression.player_currency = cost
			StatDef.Currency.BACKPACK:
				MetaProgression.backpack_currency = cost
		_assert(MetaProgression.buy_upgrade(id), "%s buy_upgrade succeeds when funded" % id)
		_assert(MetaProgression.get_level(id) == 1, "%s level incremented after buy" % id)
		var remaining: int = (
			MetaProgression.player_currency
			if def.currency == StatDef.Currency.PLAYER
			else MetaProgression.backpack_currency
		)
		_assert(remaining == 0, "%s spent exactly its cost" % id)

		MetaProgression.debug_set_level(id, def.level_cap)
		MetaProgression.player_currency = 999999
		MetaProgression.backpack_currency = 999999
		_assert(not MetaProgression.buy_upgrade(id), "%s buy_upgrade refuses once maxed" % id)

		MetaProgression.debug_set_level(id, original_level)
		MetaProgression.player_currency = original_player_currency
		MetaProgression.backpack_currency = original_backpack_currency


func _test_loot_weighted_pick() -> void:
	var flat_ids: Array = []
	for def: LootTypeDef in LootTypes.get_types():
		flat_ids.append(def.id)

	for i in 20:
		var picked := LootTypes.pick_random_weighted({})
		_assert(
			picked != null and picked.id in flat_ids,
			"empty-weights fallback picks a real tier (got %s)" % picked.id
		)

	for i in 20:
		var picked := LootTypes.pick_random_weighted({&"rare": 5.0})
		_assert(picked.id == &"rare", "single-tier weights always returns that tier")

	var restricted := {&"common": 1.0, &"epic": 1.0}
	for i in 30:
		var picked := LootTypes.pick_random_weighted(restricted)
		_assert(
			picked.id == &"common" or picked.id == &"epic",
			"restricted weights never returns an excluded tier (got %s)" % picked.id
		)


## Compacting was removed entirely (DESIGN.md 2026-08-16) -- every
## tier's effective stack size is now a fixed constant, always equal to
## its own registry value, with no stat/level to bump it anymore.
func _test_loot_effective_stack_size() -> void:
	for def: LootTypeDef in LootTypes.get_types():
		_assert(
			LootTypes.get_effective_stack_size(def.id) == def.stack_size,
			"%s's effective stack size always matches its fixed registry value" % def.id
		)


## Verifies the 2026-08-17 HUD/BackpackGrid fill-% bugfix: count_slots_used()
## and slot_breakdown() must agree, and a tier spans multiple slots once its
## own stack fills rather than one slot per distinct tier touched (the bug
## both display sites had before this fix).
func _test_loot_slot_accounting() -> void:
	var backpack: Dictionary = {&"common": 22, &"legendary": 3}
	_assert(
		LootTypes.count_slots_used(backpack) == 6,
		"22 common (stack 10 -> 3 slots) + 3 legendary (stack 1 -> 3 slots) = 6 slots total"
	)
	var breakdown: Array = LootTypes.slot_breakdown(backpack)
	_assert(breakdown.size() == 6, "slot_breakdown returns one entry per real slot, not per tier")
	var common_slot_counts: Array = []
	var legendary_slot_counts: Array = []
	for slot: Array in breakdown:
		if slot[0] == &"common":
			common_slot_counts.append(slot[1])
		elif slot[0] == &"legendary":
			legendary_slot_counts.append(slot[1])
	_assert(
		common_slot_counts == [10, 10, 2], "common's 22 items split into full/full/partial slots"
	)
	_assert(
		legendary_slot_counts == [1, 1, 1],
		"legendary's stack size of 1 keeps each item its own slot"
	)
	_assert(LootTypes.count_slots_used({}) == 0, "an empty backpack uses zero slots")


## Verifies player.gd's backpack-fill speed/size lerp (Tweak 4: HP no
## longer shrinks with fill -- size/hitbox grows instead) by driving a
## real, isolated Player instance through its actual public API
## (collect_loot/consume_loot), not by reaching into the private lerp
## directly.
func _test_backpack_fill_effects() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	var base_max_hp := player.base_max_hp
	var base_speed := player.speed
	var base_shape_radius: float = (player._body_shape.shape as CircleShape2D).radius
	var base_sprite_scale := player._sprite.scale
	player.backpack_capacity = 4
	player.backpack.clear()

	player.collect_loot(&"__test_a")
	var expected_speed := base_speed * lerpf(1.0, Player.MIN_SPEED_FRACTION, 0.25)
	var expected_size := lerpf(1.0, Player.MAX_SIZE_FRACTION, 0.25)
	_assert(_almost_eq(player.max_hp, base_max_hp), "max_hp is unaffected by fill (Tweak 4)")
	_assert(
		_almost_eq(player._effective_speed, expected_speed),
		"effective_speed at 25% fill matches lerp formula"
	)
	_assert(
		_almost_eq(
			(player._body_shape.shape as CircleShape2D).radius, base_shape_radius * expected_size
		),
		"hitbox radius at 25% fill matches size lerp formula"
	)
	_assert(
		_almost_eq(player._sprite.scale.x, base_sprite_scale.x * expected_size),
		"sprite scale at 25% fill matches size lerp formula"
	)

	player.collect_loot(&"__test_b")
	player.collect_loot(&"__test_c")
	player.collect_loot(&"__test_d")
	_assert(_almost_eq(player.max_hp, base_max_hp), "max_hp still unaffected at 100% fill")
	_assert(
		_almost_eq(player._effective_speed, base_speed * Player.MIN_SPEED_FRACTION),
		"effective_speed at 100% fill hits the MIN_SPEED_FRACTION floor"
	)
	_assert(
		_almost_eq(
			(player._body_shape.shape as CircleShape2D).radius,
			base_shape_radius * Player.MAX_SIZE_FRACTION
		),
		"hitbox radius at 100% fill hits the MAX_SIZE_FRACTION ceiling"
	)

	player.consume_loot(&"__test_a", 1)
	player.consume_loot(&"__test_b", 1)
	player.consume_loot(&"__test_c", 1)
	player.consume_loot(&"__test_d", 1)
	_assert(
		_almost_eq(player._effective_speed, base_speed),
		"effective_speed returns to baseline once empty"
	)
	_assert(
		_almost_eq((player._body_shape.shape as CircleShape2D).radius, base_shape_radius),
		"hitbox radius returns to baseline once empty"
	)

	player.queue_free()


## Verifies the slot-based fill % fix (DESIGN.md's Tweak 3): a tier
## should consume more than one slot once its stack fills, instead of
## fill % being capped at "distinct tiers touched." Uses legendary since
## its effective stack size is always 1, making the slot math
## deterministic regardless of anything else.
func _test_backpack_slots_used() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.backpack_capacity = 3
	player.backpack.clear()

	player.collect_loot(&"legendary")
	_assert(player._slots_used() == 1, "one legendary item uses one slot")

	player.collect_loot(&"legendary")
	_assert(player._slots_used() == 2, "a second legendary consumes a second slot (stack size 1)")

	player.collect_loot(&"legendary")
	_assert(player._slots_used() == 3, "a third legendary fills capacity (3/3 slots)")
	_assert(
		not player.can_collect_loot(&"legendary"),
		"a fourth legendary can't fit once slots are full (stack size 1, needs a new slot)"
	)

	player.queue_free()


## Verifies Manual Triage's queue mechanics (DESIGN.md's "Active Pickup:
## Manual Triage") directly -- enqueue/advance/resolve -- rather than via
## _check_triage_input()'s real-key polling, which headless has no way to
## simulate. Exercises the same collect()/resolve_discard() paths a real
## keep/discard key press would trigger, just called directly.
func _test_manual_triage_queue() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.backpack_capacity = 10
	player.backpack.clear()

	var gem_a: Loot = preload("res://scenes/loot/loot.tscn").instantiate()
	gem_a.type_id = &"common"
	var gem_b: Loot = preload("res://scenes/loot/loot.tscn").instantiate()
	gem_b.type_id = &"uncommon"
	add_child(gem_a)
	add_child(gem_b)

	player.enqueue_loot(gem_a)
	_assert(player._pending_gem == gem_a, "first enqueued gem becomes active")
	_assert(player._gem_queue.is_empty(), "queue stays empty with only one gem enqueued")

	player.enqueue_loot(gem_b)
	_assert(player._pending_gem == gem_a, "active gem is unchanged when a second one arrives")
	_assert(
		player._gem_queue.size() == 1 and player._gem_queue[0] == gem_b,
		"second gem waits behind the active one"
	)

	gem_a.collect(player)
	player._advance_queue()
	_assert(
		player.backpack.get(&"common", 0) == 1, "keeping the active gem adds it to the backpack"
	)
	_assert(
		player._pending_gem == gem_b, "the next queued gem becomes active once the front resolves"
	)
	_assert(player._gem_queue.is_empty(), "queue empties out as gems advance")

	gem_b.resolve_discard(Vector2.UP, player.position)
	player._advance_queue()
	_assert(player.backpack.get(&"uncommon", 0) == 0, "discarding never adds to the backpack")
	_assert(player._pending_gem == null, "queue is empty once everything's resolved")

	player.queue_free()


## Verifies Depth Pass Group A's "queue pressure" (DESIGN.md 2026-08-17):
## pending (undecided) gems must weigh on fill % at PENDING_SLOT_WEIGHT
## before they're resolved, and transition cleanly to full weight (Keep) or
## zero (Discard) with no residual. Also verifies the collect() bool-return
## contract a full backpack relies on (see player.gd's _check_triage_input()
## -- a denied Keep must leave the gem queued, not silently orphan it).
func _test_queue_pressure() -> void:
	# Group B paired Gleam's level to the pending-slot weight itself -- pin
	# it to 0 so this test's expected values (written against the base
	# PENDING_SLOT_WEIGHT) hold regardless of what other tests leave behind.
	var original_gleam_level := MetaProgression.get_level(MetaProgression.STAT_PICKUP_RANGE)
	MetaProgression.debug_set_level(MetaProgression.STAT_PICKUP_RANGE, 0)

	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.backpack_capacity = 4
	player.backpack.clear()

	var gem_a: Loot = preload("res://scenes/loot/loot.tscn").instantiate()
	gem_a.type_id = &"common"
	var gem_b: Loot = preload("res://scenes/loot/loot.tscn").instantiate()
	gem_b.type_id = &"common"
	add_child(gem_a)
	add_child(gem_b)

	player.enqueue_loot(gem_a)
	var expected_size_one: float = lerpf(1.0, Player.MAX_SIZE_FRACTION, 0.5 / 4.0)
	_assert(
		_almost_eq(player._sprite.scale.x, player._base_sprite_scale.x * expected_size_one),
		"one pending gem weighs PENDING_SLOT_WEIGHT (0.5) of a real slot"
	)

	player.enqueue_loot(gem_b)
	var expected_size_two: float = lerpf(1.0, Player.MAX_SIZE_FRACTION, 1.0 / 4.0)
	_assert(
		_almost_eq(player._sprite.scale.x, player._base_sprite_scale.x * expected_size_two),
		"two pending gems weigh a full real slot's worth (2 x 0.5)"
	)

	gem_a.collect(player)
	player._advance_queue()
	# gem_b was promoted from the queue to active pending -- 1 real slot
	# (gem_a) + 1 still-pending gem (gem_b, 0.5 weight) = 1.5, matching the
	# pre-resolve total exactly (the "clean transition" this test verifies).
	var expected_size_resolved: float = lerpf(1.0, Player.MAX_SIZE_FRACTION, 1.5 / 4.0)
	_assert(
		_almost_eq(player._sprite.scale.x, player._base_sprite_scale.x * expected_size_resolved),
		"keeping transitions cleanly: 1 real slot + 1 pending (0.5) matches the pre-resolve total"
	)

	gem_b.resolve_discard(Vector2.UP, player.position)
	player._advance_queue()
	var expected_size_empty: float = lerpf(1.0, Player.MAX_SIZE_FRACTION, 1.0 / 4.0)
	_assert(
		_almost_eq(player._sprite.scale.x, player._base_sprite_scale.x * expected_size_empty),
		"discarding drops back to zero pending weight, leaving only the 1 kept real slot"
	)

	player.queue_free()
	MetaProgression.debug_set_level(MetaProgression.STAT_PICKUP_RANGE, original_gleam_level)


## A full backpack must refuse collect() (returns false) rather than
## silently dropping the gem -- the caller (player.gd's _check_triage_input)
## relies on this to leave a denied gem queued instead of orphaning it.
func _test_collect_denied_when_full() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.backpack_capacity = 1
	player.backpack.clear()
	player.collect_loot(&"legendary")

	var gem: Loot = preload("res://scenes/loot/loot.tscn").instantiate()
	gem.type_id = &"legendary"
	add_child(gem)
	player.enqueue_loot(gem)

	_assert(not gem.collect(player), "collect() returns false once the backpack is full")
	_assert(
		player.backpack.get(&"legendary", 0) == 1, "a denied collect never touches the backpack"
	)

	gem.queue_free()
	player.queue_free()


## Depth Pass Group B "Re-point Discard" (DESIGN.md 2026-08-17): Discard's
## level must add flat bonus damage to Cast Off on top of the tier-scaled
## base, read generically via get_stat() (STAT_PURGE's per_level_gain now
## *is* that bonus).
func _test_cast_off_damage() -> void:
	var original_purge_level := MetaProgression.get_level(MetaProgression.STAT_PURGE)
	MetaProgression.debug_set_level(MetaProgression.STAT_PURGE, 2)

	var gem: Loot = preload("res://scenes/loot/loot.tscn").instantiate()
	gem.type_id = &"rare"
	add_child(gem)
	var tier_index := 2
	var expected: float = (
		Loot.CAST_OFF_BASE_DAMAGE * float(tier_index + 1)
		+ MetaProgression.get_stat(MetaProgression.STAT_PURGE)
	)
	_assert(
		_almost_eq(gem._cast_off_damage(), expected),
		"Cast Off damage is tier-scaled base plus Discard's flat bonus"
	)

	gem.queue_free()
	MetaProgression.debug_set_level(MetaProgression.STAT_PURGE, original_purge_level)


## Depth Pass Group B "Re-point Gleam": each Gleam level trims the pending-
## slot weight, floored at MIN_PENDING_SLOT_WEIGHT so queue pressure never
## fully disappears.
func _test_gleam_pending_weight_reduction() -> void:
	var original_gleam_level := MetaProgression.get_level(MetaProgression.STAT_PICKUP_RANGE)
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)

	MetaProgression.debug_set_level(MetaProgression.STAT_PICKUP_RANGE, 0)
	_assert(
		_almost_eq(player._pending_slot_weight(), Player.PENDING_SLOT_WEIGHT),
		"zero Gleam levels leaves the base pending weight untouched"
	)

	MetaProgression.debug_set_level(MetaProgression.STAT_PICKUP_RANGE, 15)
	_assert(
		_almost_eq(player._pending_slot_weight(), Player.MIN_PENDING_SLOT_WEIGHT),
		"max Gleam level reaches the pending-weight floor"
	)

	player.queue_free()
	MetaProgression.debug_set_level(MetaProgression.STAT_PICKUP_RANGE, original_gleam_level)


## Verifies the Grimoire's progressive-discovery tracking round-trips
## through save/load correctly -- combos themselves stay purely in-run
## (DESIGN.md), but *whether one's ever been seen* has to survive across
## saves, which means it has to go through export_save_data()/
## import_save_data() like everything else persistent.
func _test_combo_discovery_save_round_trip() -> void:
	# reset_progress() (exercised below) touches more than discovered_combos --
	# snapshot everything it can reach so this test can't leak state into
	# whatever runs after it, not just the one field this test cares about.
	var original_discovered: Dictionary = MetaProgression.discovered_combos.duplicate()
	var original_player_currency := MetaProgression.player_currency
	var original_backpack_currency := MetaProgression.backpack_currency
	var original_best_run_time := MetaProgression.best_run_time
	var original_levels: Dictionary = MetaProgression._stat_levels.duplicate()

	MetaProgression.discovered_combos.clear()
	_assert(
		not MetaProgression.is_combo_discovered(MetaProgression.COMBO_FULL_SET),
		"a combo starts undiscovered"
	)

	MetaProgression.mark_combo_discovered(MetaProgression.COMBO_FULL_SET)
	_assert(
		MetaProgression.is_combo_discovered(MetaProgression.COMBO_FULL_SET),
		"marking a combo discovered makes is_combo_discovered() true"
	)
	_assert(
		not MetaProgression.is_combo_discovered(MetaProgression.COMBO_STREAK),
		"discovering one combo doesn't discover the other"
	)

	var exported := MetaProgression.export_save_data()
	MetaProgression.discovered_combos.clear()
	MetaProgression.import_save_data(exported)
	_assert(
		MetaProgression.is_combo_discovered(MetaProgression.COMBO_FULL_SET),
		"discovery survives an export/import round-trip"
	)

	MetaProgression.reset_progress()
	_assert(
		not MetaProgression.is_combo_discovered(MetaProgression.COMBO_FULL_SET),
		"reset_progress() clears discovered combos along with everything else"
	)

	MetaProgression.discovered_combos = original_discovered
	MetaProgression.player_currency = original_player_currency
	MetaProgression.backpack_currency = original_backpack_currency
	MetaProgression.best_run_time = original_best_run_time
	MetaProgression._stat_levels = original_levels


## Verifies Gem Combos' "Full Set" (DESIGN.md's Tweak 3): holding one of
## each of the six rarity tiers simultaneously should trigger a one-time
## AOE clear. The clear runs on MeteorStrikeFx's telegraph-then-impact
## timing (spell_caster.gd), so this test has to actually wait for it
## rather than asserting synchronously -- the one async case in this
## suite, hence _ready() awaiting it specially.
func _test_gem_combo_full_set() -> void:
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.backpack_capacity = 10
	player.backpack.clear()

	var enemy: Enemy = preload("res://scenes/enemy/enemy.tscn").instantiate()
	enemy.position = Vector2(500.0, 500.0)
	add_child(enemy)
	# Enemy._ready() looks up the "player" group itself -- give both a
	# frame to enter the tree and initialize before checking anything.
	await get_tree().process_frame
	await get_tree().process_frame

	for def: LootTypeDef in LootTypes.get_types():
		player.collect_loot(def.id)

	# MeteorStrikeFx telegraphs for 0.5s before its impact signal fires
	# (see meteor_strike_fx.gd) -- wait past that before checking the kill.
	await get_tree().create_timer(0.7).timeout
	_assert(not is_instance_valid(enemy), "Full Set clear kills every enemy on its impact")

	player.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
