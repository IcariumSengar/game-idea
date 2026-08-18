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
const STAT_FORGE: StringName = &"forge"

## Facets (DESIGN.md's "Facets," 2026-08-17): Hades' Mirror pattern --
## already-purchased levels of a facet stat express either face, no new
## currency/cost/cap, switched freely from the Sanctum. Two stats only
## for this first pass ("every stat" was too broad); everything else has
## a single fixed effect and never reads these tables. Face A is just
## each stat's normal registered per_level_gain (below); Face B instead
## grants a reduced primary gain (half of Face A's, first-pass numbers)
## plus a secondary bonus -- dash-cooldown reduction for Swiftness,
## Cast Off damage for Gleam -- read by player.gd/loot.gd respectively
## via get_facet_bonus().
const FACET_STATS: Array[StringName] = [STAT_MOVE_SPEED, STAT_PICKUP_RANGE]
const FACET_FACE_B_PRIMARY_GAIN: Dictionary = {STAT_MOVE_SPEED: 5.0, STAT_PICKUP_RANGE: 4.0}
const FACET_FACE_B_SECONDARY_GAIN: Dictionary = {STAT_MOVE_SPEED: 0.03, STAT_PICKUP_RANGE: 2.0}

const SPELL_ARCANE_BOLT: StringName = &"arcane_bolt"
const SPELL_INFERNO_BLADE: StringName = &"inferno_blade"
const SPELL_FROST_NOVA: StringName = &"frost_nova"
const SPELL_METEOR_STRIKE: StringName = &"meteor_strike"
const SPELL_LIGHTNING_CHAIN: StringName = &"lightning_chain"
const SPELL_TIME_WARP: StringName = &"time_warp"
const SPELL_TELEPORT_PULSE: StringName = &"teleport_pulse"
const SPELL_SUMMON_FAMILIAR: StringName = &"summon_familiar"

## Migration-only now (DESIGN.md's Spell Choice, 2026-08-17): this used to
## be the live spell->required-level check, but which spell each Spell
## Unlock level grants is chosen, not fixed, as of that change. Kept
## solely to backfill chosen_spells for saves from before it (see
## _migrate_fixed_spell_order()) and to seed playtest batches (see
## debug_set_level()) -- is_spell_unlocked() no longer reads this.
const SPELL_UNLOCK_REQUIREMENTS: Dictionary = {
	SPELL_INFERNO_BLADE: 1,
	SPELL_FROST_NOVA: 2,
	SPELL_METEOR_STRIKE: 3,
	SPELL_LIGHTNING_CHAIN: 4,
	SPELL_TIME_WARP: 5,
	SPELL_TELEPORT_PULSE: 6,
	SPELL_SUMMON_FAMILIAR: 7,
}
## The 7 spells a Spell Unlock choice can ever grant (everything except
## Arcane, which needs no unlock).
const UNLOCKABLE_SPELLS: Array[StringName] = [
	SPELL_INFERNO_BLADE,
	SPELL_FROST_NOVA,
	SPELL_METEOR_STRIKE,
	SPELL_LIGHTNING_CHAIN,
	SPELL_TIME_WARP,
	SPELL_TELEPORT_PULSE,
	SPELL_SUMMON_FAMILIAR,
]

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
## Personal-best categories (DESIGN.md's HUD + death-summary rework,
## 2026-08-17), alongside best_run_time above. Richest: total Essence
## earned in a run. Leanest: seconds_survived * (1.0 - max_fill_ratio) --
## rewards surviving long while staying light, zero for either extreme.
## Most Refused: total discards (L presses) in a run.
var best_run_essence: int = 0
var best_run_leanness: float = 0.0
var best_run_discards: int = 0
## Sanctum UX point 1 (DESIGN.md 2026-08-17): currency as of the last time
## the shop was closed -- shop.gd compares this against current currency
## on open to find nodes that crossed into affordable since the last
## visit (a one-off "welcome back" shimmer, not a live effect). Session-
## only, not persisted to a save file -- it's a presentation cue, not
## progress.
var last_shop_close_player_currency: int = 0
var last_shop_close_backpack_currency: int = 0
## Combo id -> true, once ever triggered on this save. Codex-only state --
## nothing in actual gameplay reads this, combos work identically whether
## discovered or not.
var discovered_combos: Dictionary = {}
## Codex-only state for the Ship's Log, same spirit as discovered_combos --
## the Angler only spawns from Phase 2 on, so unlike Attunement (always
## visible in the Ship's Log, since nothing about it is a run-time
## surprise) it has real "hasn't happened yet" discovery value.
var angler_encountered: bool = false
## Spell Choice (DESIGN.md 2026-08-17): Spell Unlock level -> which spell
## that level actually granted, once resolved. A level can legitimately be
## bought (STAT_SPELL_UNLOCK's own level already incremented via the
## normal buy_upgrade() path) before its choice is made -- this can have
## fewer entries than get_level(STAT_SPELL_UNLOCK) while a choice is
## pending, and that's a valid, save-safe state (quitting mid-choice loses
## nothing, see has_pending_spell_choice()).
var chosen_spells: Dictionary = {}
## Facets: stat id -> true means Face B is active, absent/false means
## Face A (the default, matching pre-Facets behavior for a save that's
## never touched this).
var active_facet: Dictionary = {}
## Trophy Hall (DESIGN.md's "A hoard you can actually see," 2026-08-17):
## tier id -> highest single-item value ever seen for that tier, six
## fixed entries forever (Common through Legendary) rather than an
## unbounded "everything ever collected" list. Checked at death time
## against that run's final backpack breakdown (see hud.gd's
## _update_trophy_hall()) rather than a new mid-run signal hook -- scoped
## honestly: this reads each tier's fixed LootTypeDef.value, not a
## discarded-before-death item's or an affixed item's real bonus-inflated
## value, since neither survives into the backpack's tier->count
## aggregate by the time death is reached.
var best_loot_value: Dictionary = {}

var _stat_defs: Array[StatDef] = []
var _stat_levels: Dictionary = {}


func _ready() -> void:
	_register_stat(
		STAT_BACKPACK_CAPACITY, "Hold", 5.0, 1.0, 100, 1.25, 10, 0, StatDef.Currency.BACKPACK
	)
	_register_stat(STAT_PICKUP_RANGE, "Gleam", 60.0, 8.0, 12, 1.15, 15, 0, StatDef.Currency.PLAYER)
	_register_stat(STAT_DAMAGE, "Fathom", 20.0, 2.0, 15, 1.15, 20, 0, StatDef.Currency.PLAYER)
	_register_stat(
		STAT_MOVE_SPEED, "Current", 250.0, 10.0, 15, 1.18, 10, 0, StatDef.Currency.PLAYER
	)
	# Depth Pass Group B (DESIGN.md 2026-08-17): Discard no longer auto-purges
	# at a fill threshold -- each level now adds flat bonus damage to Cast
	# Off instead, read generically via get_stat() like every other stat's
	# effect (loot.gd's _cast_off_damage()).
	_register_stat(STAT_PURGE, "Discard", 0.0, 4.0, 100, 1.30, 4, 0, StatDef.Currency.BACKPACK)
	# The Forge (DESIGN.md's "The Forge: buy odds, not numbers," 2026-08-17):
	# extends the Backpack Tree chain past Discard. base_value/per_level_gain
	# are percentage POINTS (0, 2, 4... 20 at cap), not a 0.0-1.0 fraction --
	# LootTypes.get_forge_adjusted_weights() divides by 100 itself, so the
	# skill-tree tooltip's "Current: X -> Y" reads as plain whole numbers
	# like every other stat instead of a confusing 0.02-style fraction.
	_register_stat(STAT_FORGE, "Lure", 0.0, 2.0, 150, 1.2, 10, 0, StatDef.Currency.BACKPACK)
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

	# Sanctum UX (DESIGN.md 2026-08-17): asserted milestone status, not
	# inferred from tree topology -- Spell Unlock is the gated trunk,
	# Discard is Backpack Tree's own capstone.
	get_stat_def(STAT_SPELL_UNLOCK).is_milestone = true
	# The Forge extends the Backpack Tree past Discard (DESIGN.md's "The
	# Forge," 2026-08-17) -- it's the chain's real capstone now, so the
	# milestone flag moves from Discard to it rather than both being large.
	get_stat_def(STAT_FORGE).is_milestone = true


func get_stat_defs() -> Array[StatDef]:
	return _stat_defs


func get_stat(id: StringName) -> float:
	var def := get_stat_def(id)
	if def == null:
		push_error("Unknown stat id: %s" % id)
		return 0.0
	var per_level_gain: float = def.per_level_gain
	if is_facet_b_active(id) and FACET_FACE_B_PRIMARY_GAIN.has(id):
		per_level_gain = FACET_FACE_B_PRIMARY_GAIN[id]
	return def.base_value + float(get_level(id)) * per_level_gain


func is_facet_stat(stat_id: StringName) -> bool:
	return stat_id in FACET_STATS


func is_facet_b_active(stat_id: StringName) -> bool:
	return active_facet.get(stat_id, false)


func set_facet(stat_id: StringName, use_face_b: bool) -> void:
	if not is_facet_stat(stat_id):
		return
	active_facet[stat_id] = use_face_b
	stat_changed.emit(stat_id, get_level(stat_id))


## Face B's secondary bonus, scaled by level -- 0.0 on Face A or a
## non-facet stat. Callers (player.gd's dash cooldown, loot.gd's Cast
## Off damage) add this on top of their own base calculation.
func get_facet_bonus(stat_id: StringName) -> float:
	if not is_facet_b_active(stat_id):
		return 0.0
	return float(get_level(stat_id)) * float(FACET_FACE_B_SECONDARY_GAIN.get(stat_id, 0.0))


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


func update_best_essence(total_value: int) -> int:
	var previous_best := best_run_essence
	if total_value > best_run_essence:
		best_run_essence = total_value
	return previous_best


func update_best_leanness(leanness: float) -> float:
	var previous_best := best_run_leanness
	if leanness > best_run_leanness:
		best_run_leanness = leanness
	return previous_best


func update_best_discards(discards: int) -> int:
	var previous_best := best_run_discards
	if discards > best_run_discards:
		best_run_discards = discards
	return previous_best


func is_spell_unlocked(spell_id: StringName) -> bool:
	if spell_id == SPELL_ARCANE_BOLT:
		return true
	return spell_id in chosen_spells.values()


## True while a bought Spell Unlock level hasn't had its spell chosen yet.
func has_pending_spell_choice() -> bool:
	return chosen_spells.size() < get_level(STAT_SPELL_UNLOCK)


## The level currently awaiting a choice (matches Spell Unlock's own
## level numbering), or 0 if nothing's pending.
func pending_spell_choice_level() -> int:
	return chosen_spells.size() + 1 if has_pending_spell_choice() else 0


## Candidate spells offered for the given pending level. Exactly 7 spells
## across exactly 7 levels means a strict "offer 2, keep 1, remove from
## the pool" can't sustain a real 2-way choice all the way to the last
## level -- the pool for the 6 non-Familiar spells only has enough slack
## for 5 real choices (L1-L5; sizes 6,5,4,3,2 all have >=2 candidates
## going in). L6 is left with exactly one non-Familiar spell -- returned
## alone, no real choice, since there's nothing left to pair it with. L7
## always returns Familiar alone -- the capstone reservation ("only ever
## offered at the final level") made literal rather than merely a
## priority rule, since by L7 it's the only spell left in the whole pool
## either way. Both single-candidate levels still route through the same
## reveal panel as a real choice would, just with one option instead of
## two -- a "new spell" moment either way, not a silent auto-grant.
## Recomputed fresh (not stored) each call, so re-opening the panel before
## deciding can reshuffle a real 2-way offer -- accepted tradeoff, not
## treated as a bug, given how small the actual exploit surface is.
func get_spell_choice_offer(level: int) -> Array[StringName]:
	var level_cap: int = get_stat_def(STAT_SPELL_UNLOCK).level_cap
	if level >= level_cap:
		return [SPELL_SUMMON_FAMILIAR]
	var chosen_so_far: Array = chosen_spells.values()
	var remaining: Array[StringName] = []
	for spell_id: StringName in UNLOCKABLE_SPELLS:
		if spell_id != SPELL_SUMMON_FAMILIAR and spell_id not in chosen_so_far:
			remaining.append(spell_id)
	if remaining.size() <= 1:
		return remaining
	remaining.shuffle()
	return [remaining[0], remaining[1]]


## Resolves the currently-pending choice. No-op if nothing's pending.
func choose_spell(spell_id: StringName) -> void:
	var level := pending_spell_choice_level()
	if level == 0:
		return
	chosen_spells[level] = spell_id


## Called by spell_caster.gd the moment a combo actually fires. Harmless
## to call repeatedly -- a combo stays discovered forever once seen once.
func mark_combo_discovered(combo_id: StringName) -> void:
	discovered_combos[combo_id] = true


func is_combo_discovered(combo_id: StringName) -> bool:
	return discovered_combos.get(combo_id, false)


func update_best_loot_value(tier_id: StringName, value: int) -> void:
	if value > int(best_loot_value.get(tier_id, 0)):
		best_loot_value[tier_id] = value


func get_best_loot_value(tier_id: StringName) -> int:
	return best_loot_value.get(tier_id, 0)


## Called by EnemyAngler the moment one spawns in. Harmless to call
## repeatedly -- stays encountered forever once seen once.
func mark_angler_encountered() -> void:
	angler_encountered = true


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
## bot actually exercises it), never reachable from normal play. Setting
## STAT_SPELL_UNLOCK this way also backfills chosen_spells using the old
## fixed order (SPELL_UNLOCK_REQUIREMENTS) -- debug seeding has no player
## to click through a real choice panel, so without this a seeded batch
## would bump the trunk level but leave every spell's choice pending
## forever, unlocking nothing.
func debug_set_level(id: StringName, level: int) -> void:
	_stat_levels[id] = level
	if id == STAT_SPELL_UNLOCK:
		for spell_id: StringName in SPELL_UNLOCK_REQUIREMENTS:
			var required_level: int = SPELL_UNLOCK_REQUIREMENTS[spell_id]
			if required_level <= level:
				chosen_spells[required_level] = spell_id


## Packs the fields SaveManager persists to a save-slot file. Save-file
## mechanics (paths, slots, when to write) live on SaveManager; only the
## shape of what gets saved lives here, next to the data itself.
func export_save_data() -> Dictionary:
	var discovered: Array = []
	for combo_id: StringName in discovered_combos:
		discovered.append(String(combo_id))
	var serialized_choices: Dictionary = {}
	for level: int in chosen_spells:
		serialized_choices[str(level)] = String(chosen_spells[level])
	var serialized_best_loot: Dictionary = {}
	for tier_id: StringName in best_loot_value:
		serialized_best_loot[String(tier_id)] = best_loot_value[tier_id]
	var serialized_facets: Dictionary = {}
	for stat_id: StringName in active_facet:
		serialized_facets[String(stat_id)] = active_facet[stat_id]
	return {
		"player_currency": player_currency,
		"backpack_currency": backpack_currency,
		"best_run_time": best_run_time,
		"best_run_essence": best_run_essence,
		"best_run_leanness": best_run_leanness,
		"best_run_discards": best_run_discards,
		"stat_levels": _stat_levels,
		"discovered_combos": discovered,
		"angler_encountered": angler_encountered,
		"chosen_spells": serialized_choices,
		"best_loot_value": serialized_best_loot,
		"active_facet": serialized_facets
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
	best_run_essence = data.get("best_run_essence", 0)
	best_run_leanness = data.get("best_run_leanness", 0.0)
	best_run_discards = data.get("best_run_discards", 0)
	var saved_levels: Dictionary = data.get("stat_levels", {})
	for stat_id: String in saved_levels:
		_stat_levels[StringName(stat_id)] = int(saved_levels[stat_id])
	discovered_combos.clear()
	var saved_combos: Array = data.get("discovered_combos", [])
	for combo_id: String in saved_combos:
		discovered_combos[StringName(combo_id)] = true
	angler_encountered = data.get("angler_encountered", false)
	best_loot_value.clear()
	var saved_best_loot: Dictionary = data.get("best_loot_value", {})
	for tier_id: String in saved_best_loot:
		best_loot_value[StringName(tier_id)] = int(saved_best_loot[tier_id])
	active_facet.clear()
	var saved_facets: Dictionary = data.get("active_facet", {})
	for stat_id: String in saved_facets:
		active_facet[StringName(stat_id)] = bool(saved_facets[stat_id])
	if data.has("chosen_spells"):
		chosen_spells.clear()
		var saved_choices: Dictionary = data["chosen_spells"]
		for level_key: String in saved_choices:
			chosen_spells[int(level_key)] = StringName(saved_choices[level_key])
	else:
		_migrate_fixed_spell_order()
	currency_changed.emit()


## One-time migration (DESIGN.md's Spell Choice, 2026-08-17): a save from
## before this feature has spells unlocked against the old fixed order
## (SPELL_UNLOCK_REQUIREMENTS), with no chosen_spells key at all --
## reconstruct it from that order so no player loses an already-unlocked
## spell. Only backfills levels actually already bought; anything above
## the save's current Spell Unlock level is left as a real pending choice,
## same as any other save going forward.
func _migrate_fixed_spell_order() -> void:
	chosen_spells.clear()
	var current_level := get_level(STAT_SPELL_UNLOCK)
	for spell_id: StringName in SPELL_UNLOCK_REQUIREMENTS:
		var required_level: int = SPELL_UNLOCK_REQUIREMENTS[spell_id]
		if required_level <= current_level:
			chosen_spells[required_level] = spell_id


## Resets in-memory progress to a fresh save's defaults -- used by
## SaveManager both when switching to an empty slot (nothing to load) and
## when explicitly overwriting an occupied one. Without this, switching to
## an empty slot would silently keep whatever was in memory from the
## previously loaded slot instead of starting clean.
func reset_progress() -> void:
	player_currency = 0
	backpack_currency = 0
	best_run_time = 0.0
	best_run_essence = 0
	best_run_leanness = 0.0
	best_run_discards = 0
	for stat_id: StringName in _stat_levels:
		_stat_levels[stat_id] = 0
	discovered_combos.clear()
	angler_encountered = false
	best_loot_value.clear()
	active_facet.clear()
	chosen_spells.clear()
	currency_changed.emit()
