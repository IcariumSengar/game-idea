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
	_test_backpack_fill_lerp()
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
			_assert(
				not MetaProgression.is_maxed(def.id), "%s is not maxed one below cap" % def.id
			)
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


func _test_loot_effective_stack_size() -> void:
	var original_common := MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_COMMON)
	var original_legendary_level := MetaProgression.get_level(MetaProgression.STAT_COMPACTOR_MYTHIC)

	MetaProgression.debug_set_level(MetaProgression.STAT_COMPACTOR_COMMON, 0)
	var common_def := LootTypes.get_type(&"common")
	_assert(
		LootTypes.get_effective_stack_size(&"common") == common_def.stack_size,
		"common stack size matches registry default at compactor level 0"
	)

	MetaProgression.debug_set_level(MetaProgression.STAT_COMPACTOR_COMMON, 3)
	var expected := roundi(MetaProgression.get_stat(MetaProgression.STAT_COMPACTOR_COMMON))
	_assert(
		LootTypes.get_effective_stack_size(&"common") == expected,
		"common stack size follows Compactor level once leveled"
	)

	_assert(
		LootTypes.get_effective_stack_size(&"legendary") == 1,
		"legendary stack size is always 1, no compactor tier"
	)

	MetaProgression.debug_set_level(MetaProgression.STAT_COMPACTOR_COMMON, original_common)
	MetaProgression.debug_set_level(MetaProgression.STAT_COMPACTOR_MYTHIC, original_legendary_level)


## Verifies player.gd's backpack-fill HP/speed lerp by driving a real,
## isolated Player instance through its actual public API (collect_loot/
## consume_loot), not by reaching into the private lerp directly.
func _test_backpack_fill_lerp() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate()
	add_child(player)
	var base_max_hp := player.base_max_hp
	var base_speed := player.speed
	player.backpack_capacity = 4
	player.backpack.clear()

	player.collect_loot(&"__test_a")
	var expected_hp := base_max_hp * lerpf(1.0, Player.MIN_HP_FRACTION, 0.25)
	var expected_speed := base_speed * lerpf(1.0, Player.MIN_SPEED_FRACTION, 0.25)
	_assert(_almost_eq(player.max_hp, expected_hp), "max_hp at 25% fill matches lerp formula")
	_assert(
		_almost_eq(player._effective_speed, expected_speed),
		"effective_speed at 25% fill matches lerp formula"
	)

	player.collect_loot(&"__test_b")
	player.collect_loot(&"__test_c")
	player.collect_loot(&"__test_d")
	_assert(
		_almost_eq(player.max_hp, base_max_hp * Player.MIN_HP_FRACTION),
		"max_hp at 100% fill hits the MIN_HP_FRACTION floor"
	)
	_assert(
		_almost_eq(player._effective_speed, base_speed * Player.MIN_SPEED_FRACTION),
		"effective_speed at 100% fill hits the MIN_SPEED_FRACTION floor"
	)

	player.consume_loot(&"__test_a", 1)
	player.consume_loot(&"__test_b", 1)
	player.consume_loot(&"__test_c", 1)
	player.consume_loot(&"__test_d", 1)
	_assert(_almost_eq(player.max_hp, base_max_hp), "max_hp returns to baseline once empty")
	_assert(
		_almost_eq(player._effective_speed, base_speed), "effective_speed returns to baseline once empty"
	)

	player.queue_free()
