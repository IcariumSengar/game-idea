extends Node

## Passively processes backpack items over time, per DESIGN.md's Backpack
## Ability sketch: a pre-run choice (MetaProgression.active_backpack_ability,
## picked in run_prep.tscn) between two mutually-exclusive abilities --
## Condense (merges 2 of a tier into 1 of the next tier up, for value
## density) and Clear (banks 1 item's value as currency immediately and
## frees the slot, for space). Each rarity tier ticks on its own interval,
## rarer tiers processing slower; Legendary never processes (matches its
## existing Compacting exemption -- it's the one tier that always eats a
## whole slot by design).

const TIER_ORDER: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"mythic"]
const TIER_INTERVALS: Dictionary = {
	&"common": 3.0,
	&"uncommon": 6.0,
	&"rare": 12.0,
	&"epic": 24.0,
	&"mythic": 48.0,
}
## Condense's cadence is double the tier's base interval -- it moves twice
## the items (2 consumed) in one go, so ticking at 2x keeps its throughput
## comparable to Clear's rather than doubling it outright.
const CONDENSE_INTERVAL_MULTIPLIER: float = 2.0
const CONDENSE_CONSUME_COUNT: int = 2
const CONDENSE_NEXT_TIER: Dictionary = {
	&"common": &"uncommon",
	&"uncommon": &"rare",
	&"rare": &"epic",
	&"epic": &"mythic",
}

var _owner_body: Player
var _timers: Dictionary = {}


func _ready() -> void:
	_owner_body = get_parent()
	for tier: StringName in TIER_ORDER:
		_timers[tier] = _current_interval(tier)


func _process(delta: float) -> void:
	var ability: StringName = MetaProgression.active_backpack_ability
	for tier: StringName in TIER_ORDER:
		_timers[tier] -= delta
		if _timers[tier] > 0.0:
			continue
		_timers[tier] = _current_interval(tier)
		if ability == MetaProgression.BACKPACK_ABILITY_CONDENSE:
			_try_condense(tier)
		elif ability == MetaProgression.BACKPACK_ABILITY_CLEAR:
			_try_clear(tier)


func _current_interval(tier: StringName) -> float:
	var speed_mult: float = MetaProgression.get_stat(MetaProgression.STAT_BACKPACK_ABILITY_SPEED)
	var base: float = TIER_INTERVALS[tier]
	if MetaProgression.active_backpack_ability == MetaProgression.BACKPACK_ABILITY_CONDENSE:
		base *= CONDENSE_INTERVAL_MULTIPLIER
	return base / speed_mult


func _try_condense(tier: StringName) -> void:
	var next_tier: StringName = CONDENSE_NEXT_TIER.get(tier, StringName())
	if next_tier == StringName():
		return
	if int(_owner_body.backpack.get(tier, 0)) < CONDENSE_CONSUME_COUNT:
		return
	if _owner_body.consume_loot(tier, CONDENSE_CONSUME_COUNT) == CONDENSE_CONSUME_COUNT:
		_owner_body.collect_loot(next_tier)


func _try_clear(tier: StringName) -> void:
	if _owner_body.consume_loot(tier, 1) <= 0:
		return
	var def := LootTypes.get_type(tier)
	var value: int = def.value if def != null else 1
	_owner_body.add_bonus_loot_value(value)
