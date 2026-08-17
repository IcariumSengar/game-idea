extends Node

## Single source of truth for cross-run player stats and both currencies.
## New upgradeable stats only need a _register_stat() call here -- Shop
## and HUD read the definitions generically and need no per-stat code.
##
## Two independent currency pools per DESIGN.md: player currency (from
## loot value collected) funds player-power stats; backpack currency (from
## time survived) funds backpack-only stats. Each StatDef is tagged with
## which pool funds it.

signal currency_changed
signal stat_changed(stat_id: StringName, level: int)

const STAT_BACKPACK_CAPACITY: StringName = &"backpack_capacity"
const STAT_PICKUP_RANGE: StringName = &"pickup_range"
const STAT_DAMAGE: StringName = &"damage"
const STAT_MOVE_SPEED: StringName = &"move_speed"
const STAT_PURGE: StringName = &"purge"
const STAT_SPELL_UNLOCK: StringName = &"spell_unlock"
const STAT_ARCANE_HASTE: StringName = &"arcane_haste"
const STAT_ARCANE_PROJECTILE_SPEED: StringName = &"arcane_projectile_speed"
const STAT_INFERNO_FURY: StringName = &"inferno_fury"
const STAT_INFERNO_ARC_WIDTH: StringName = &"inferno_arc_width"
const STAT_INFERNO_BURN_DAMAGE: StringName = &"inferno_burn_damage"
const STAT_FROST_FREQUENCY: StringName = &"frost_frequency"
const STAT_FROST_RADIUS: StringName = &"frost_radius"
const STAT_FROST_SLOW_STRENGTH: StringName = &"frost_slow_strength"
const STAT_METEOR_FREQUENCY: StringName = &"meteor_frequency"
const STAT_LIGHTNING_FREQUENCY: StringName = &"lightning_frequency"
const STAT_TIME_WARP_FREQUENCY: StringName = &"time_warp_frequency"
const STAT_TELEPORT_FREQUENCY: StringName = &"teleport_frequency"
const STAT_FAMILIAR_DURATION: StringName = &"familiar_duration"

const SPELL_ARCANE_BOLT: StringName = &"arcane_bolt"
const SPELL_INFERNO_BLADE: StringName = &"inferno_blade"
const SPELL_FROST_NOVA: StringName = &"frost_nova"
const SPELL_METEOR_STRIKE: StringName = &"meteor_strike"
const SPELL_LIGHTNING_CHAIN: StringName = &"lightning_chain"
const SPELL_TIME_WARP: StringName = &"time_warp"
const SPELL_TELEPORT_PULSE: StringName = &"teleport_pulse"
const SPELL_SUMMON_FAMILIAR: StringName = &"summon_familiar"

## Spell -> Spell Unlock level required. Arcane Bolt isn't listed -- it's
## always available, checked separately in is_spell_unlocked().
const SPELL_UNLOCK_REQUIREMENTS: Dictionary = {
	SPELL_INFERNO_BLADE: 1,
	SPELL_FROST_NOVA: 2,
	SPELL_METEOR_STRIKE: 3,
	SPELL_LIGHTNING_CHAIN: 4,
	SPELL_TIME_WARP: 5,
	SPELL_TELEPORT_PULSE: 6,
	SPELL_SUMMON_FAMILIAR: 7,
}

## Gem Combos, for the codex's progressive-discovery tracking (see
## discovered_combos below) -- combos themselves stay purely in-run/
## ephemeral (DESIGN.md: "no currency, no meta-progression, no
## persistence"), but *whether a combo has ever been seen* is a real,
## persistent save fact the codex needs, distinct from the combo's own
## per-run state.
const COMBO_FULL_SET: StringName = &"full_set"
const COMBO_STREAK: StringName = &"streak"

## v6 balance: deliberately slow -- Bearing is a late-game prestige
## upgrade, not something funded within the first few runs.
const BACKPACK_CURRENCY_PER_SECOND: float = 0.05

var player_currency: int = 0
var backpack_currency: int = 0
var best_run_time: float = 0.0
## Combo id -> true, once ever triggered on this save. Codex-only state --
## nothing in actual gameplay reads this, combos work identically whether
## discovered or not.
var discovered_combos: Dictionary = {}

var _stat_defs: Array[StatDef] = []
var _stat_levels: Dictionary = {}


func _ready() -> void:
	_register_stat(
		STAT_BACKPACK_CAPACITY, "Bearing", 5.0, 1.0, 100, 1.25, 10, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(STAT_PICKUP_RANGE, "Gleam", 60.0, 8.0, 12, 1.15, 15, 0, StatDef.Currency.PLAYER)
	_register_stat(STAT_DAMAGE, "Spellpower", 20.0, 2.0, 15, 1.15, 20, 0, StatDef.Currency.PLAYER)
	_register_stat(
		STAT_MOVE_SPEED, "Swiftness", 250.0, 10.0, 15, 1.18, 10, 0, StatDef.Currency.PLAYER
	)
	# Depth Pass Group B (DESIGN.md 2026-08-17): Discard no longer auto-purges
	# at a fill threshold -- each level now adds flat bonus damage to Cast
	# Off instead, read generically via get_stat() like every other stat's
	# effect (loot.gd's _cast_off_damage()).
	_register_stat(STAT_PURGE, "Discard", 0.0, 4.0, 100, 1.30, 4, 0, StatDef.Currency.BACKPACK)
	# Cap raised 5->7 for v11's five new spells (L3-L7) on top of Inferno/Frost
	# (L1/L2) -- same base cost/growth as originally locked in, just extended.
	_register_stat(
		STAT_SPELL_UNLOCK, "Spell Unlock", 0.0, 0.0, 25, 1.20, 7, 0, StatDef.Currency.PLAYER
	)
	# Base/per-level both scaled by 1/1.5 vs the original curve (0.5, -0.05) so
	# Arcane Bolt fires 50% faster by default and at every upgrade level, per
	# player balance feedback.
	_register_stat(
		STAT_ARCANE_HASTE, "Haste", 0.5 / 1.5, -0.05 / 1.5, 15, 1.15, 7, 2, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_ARCANE_PROJECTILE_SPEED,
		"Velocity",
		400.0,
		50.0,
		12,
		1.15,
		4,
		0,
		StatDef.Currency.PLAYER
	)
	_register_stat(STAT_INFERNO_FURY, "Fury", 1.0, -0.15, 18, 1.16, 4, 2, StatDef.Currency.PLAYER)
	_register_stat(
		STAT_INFERNO_ARC_WIDTH, "Reach", 90.0, 15.0, 15, 1.14, 6, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_INFERNO_BURN_DAMAGE, "Burn Damage", 0.0, 5.0, 14, 1.13, 12, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FROST_FREQUENCY, "Frequency", 2.0, -0.3, 20, 1.18, 4, 1, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FROST_RADIUS, "Radius", 150.0, 20.0, 16, 1.15, 7, 0, StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FROST_SLOW_STRENGTH,
		"Slow Strength",
		50.0,
		5.0,
		18,
		1.16,
		10,
		0,
		StatDef.Currency.PLAYER
	)
	# v11 spells: each gets one upgrade stat (cast-rate or, for Familiar,
	# uptime duration) rather than the 2-3 the original three spells got --
	# keeps five new spells' worth of shop surface proportional. Cost
	# curves invented, same treatment as the original three's stats.
	_register_stat(
		STAT_METEOR_FREQUENCY,
		"Meteor Frequency",
		5.0,
		-0.5,
		22,
		1.18,
		5,
		1,
		StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_LIGHTNING_FREQUENCY,
		"Chain Frequency",
		1.5,
		-0.15,
		18,
		1.16,
		5,
		2,
		StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_TIME_WARP_FREQUENCY,
		"Warp Frequency",
		4.0,
		-0.4,
		20,
		1.17,
		5,
		1,
		StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_TELEPORT_FREQUENCY,
		"Pulse Frequency",
		3.5,
		-0.3,
		18,
		1.16,
		5,
		1,
		StatDef.Currency.PLAYER
	)
	_register_stat(
		STAT_FAMILIAR_DURATION,
		"Familiar Uptime",
		12.0,
		2.0,
		20,
		1.17,
		5,
		0,
		StatDef.Currency.PLAYER
	)


func get_stat_defs() -> Array[StatDef]:
	return _stat_defs


func get_stat(id: StringName) -> float:
	var def := get_stat_def(id)
	if def == null:
		push_error("Unknown stat id: %s" % id)
		return 0.0
	return def.base_value + float(get_level(id)) * def.per_level_gain


func get_level(id: StringName) -> int:
	return _stat_levels.get(id, 0)


func get_cost(id: StringName) -> int:
	var def := get_stat_def(id)
	if def == null:
		return 0
	return roundi(float(def.base_cost) * pow(def.cost_growth, get_level(id)))


func is_maxed(id: StringName) -> bool:
	var def := get_stat_def(id)
	if def == null:
		return true
	return get_level(id) >= def.level_cap


func award_run_end_currency(loot_value: int, seconds_survived: float) -> void:
	player_currency += loot_value
	backpack_currency += roundi(seconds_survived * BACKPACK_CURRENCY_PER_SECOND)
	currency_changed.emit()


## Returns the previous best (before this run), so callers can compare
## against what just happened before the record gets overwritten.
func update_best_run(seconds_survived: float) -> float:
	var previous_best := best_run_time
	if seconds_survived > best_run_time:
		best_run_time = seconds_survived
	return previous_best


func is_spell_unlocked(spell_id: StringName) -> bool:
	if spell_id == SPELL_ARCANE_BOLT:
		return true
	var required_level: int = SPELL_UNLOCK_REQUIREMENTS.get(spell_id, -1)
	return required_level >= 0 and get_level(STAT_SPELL_UNLOCK) >= required_level


## Called by spell_caster.gd the moment a combo actually fires. Harmless
## to call repeatedly -- a combo stays discovered forever once seen once.
func mark_combo_discovered(combo_id: StringName) -> void:
	discovered_combos[combo_id] = true


func is_combo_discovered(combo_id: StringName) -> bool:
	return discovered_combos.get(combo_id, false)


func buy_upgrade(id: StringName) -> bool:
	var def := get_stat_def(id)
	if def == null or is_maxed(id):
		return false
	var cost := get_cost(id)
	match def.currency:
		StatDef.Currency.PLAYER:
			if player_currency < cost:
				return false
			player_currency -= cost
		StatDef.Currency.BACKPACK:
			if backpack_currency < cost:
				return false
			backpack_currency -= cost
	var new_level: int = get_level(id) + 1
	_stat_levels[id] = new_level
	currency_changed.emit()
	stat_changed.emit(id, new_level)
	return true


func _register_stat(
	id: StringName,
	display_name: String,
	base_value: float,
	per_level_gain: float,
	base_cost: int,
	cost_growth: float,
	level_cap: int,
	decimals: int,
	currency: StatDef.Currency
) -> void:
	var def := StatDef.new()
	def.id = id
	def.display_name = display_name
	def.base_value = base_value
	def.per_level_gain = per_level_gain
	def.base_cost = base_cost
	def.cost_growth = cost_growth
	def.level_cap = level_cap
	def.decimals = decimals
	def.currency = currency
	_stat_defs.append(def)
	_stat_levels[id] = 0


func get_stat_def(id: StringName) -> StatDef:
	for def in _stat_defs:
		if def.id == id:
			return def
	return null


## Directly sets a stat's level without spending currency -- used only to
## seed a playtest batch's starting loadout (e.g. unlocking a spell so the
## bot actually exercises it), never reachable from normal play.
func debug_set_level(id: StringName, level: int) -> void:
	_stat_levels[id] = level


## Packs the fields SaveManager persists to a save-slot file. Save-file
## mechanics (paths, slots, when to write) live on SaveManager; only the
## shape of what gets saved lives here, next to the data itself.
func export_save_data() -> Dictionary:
	var discovered: Array = []
	for combo_id: StringName in discovered_combos:
		discovered.append(String(combo_id))
	return {
		"player_currency": player_currency,
		"backpack_currency": backpack_currency,
		"best_run_time": best_run_time,
		"stat_levels": _stat_levels,
		"discovered_combos": discovered
	}


## Unpacks a save-slot file's data (see export_save_data()) into live
## state. Called by SaveManager after it reads and JSON-parses the file.
## Older saves may still have a now-unused "active_backpack_ability" key
## (see DESIGN.md's 2026-08-16 Backpack Ability removal) -- harmless,
## just never read.
func import_save_data(data: Dictionary) -> void:
	player_currency = data.get("player_currency", 0)
	backpack_currency = data.get("backpack_currency", 0)
	best_run_time = data.get("best_run_time", 0.0)
	var saved_levels: Dictionary = data.get("stat_levels", {})
	for stat_id: String in saved_levels:
		_stat_levels[StringName(stat_id)] = int(saved_levels[stat_id])
	discovered_combos.clear()
	var saved_combos: Array = data.get("discovered_combos", [])
	for combo_id: String in saved_combos:
		discovered_combos[StringName(combo_id)] = true
	currency_changed.emit()


## Resets in-memory progress to a fresh save's defaults -- used by
## SaveManager both when switching to an empty slot (nothing to load) and
## when explicitly overwriting an occupied one. Without this, switching to
## an empty slot would silently keep whatever was in memory from the
## previously loaded slot instead of starting clean.
func reset_progress() -> void:
	player_currency = 0
	backpack_currency = 0
	best_run_time = 0.0
	for stat_id: StringName in _stat_levels:
		_stat_levels[stat_id] = 0
	discovered_combos.clear()
	currency_changed.emit()
