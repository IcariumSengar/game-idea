extends Node

## Central registry of loot rarity tiers -- numbers match the rarity table
## in DESIGN.md's "Loot, backpack & shop economy" section exactly. That
## table is the source of truth; update there first, then mirror here.
## Data-driven like MetaProgression's stats -- add a tier with one
## _register() call, everything else (drop rolls, backpack coloring,
## currency value, stack limits) reads the registry generically.

var _types: Array[LootTypeDef] = []


func _ready() -> void:
	_register(&"common", "Common", Color.WHITE, 1, 10, 50.0)
	_register(&"uncommon", "Uncommon", Color(0.3, 0.8, 0.35), 3, 8, 27.0)
	_register(&"rare", "Rare", Color(0.25, 0.55, 0.95), 10, 5, 14.0)
	_register(&"epic", "Epic", Color(0.65, 0.3, 0.9), 40, 3, 6.0)
	_register(&"mythic", "Mythic", Color(0.95, 0.55, 0.15), 150, 2, 2.5)
	_register(&"legendary", "Legendary", Color(0.9, 0.2, 0.2), 800, 1, 0.5)


func get_types() -> Array[LootTypeDef]:
	return _types


func get_type(id: StringName) -> LootTypeDef:
	for def in _types:
		if def.id == id:
			return def
	return null


## Now a thin wrapper over pick_random_weighted() -- see The Forge's note
## there for why both roll paths have to share one implementation.
func pick_random_type() -> LootTypeDef:
	return pick_random_weighted(_flat_weights())


func _flat_weights() -> Dictionary:
	var weights: Dictionary = {}
	for def in _types:
		weights[def.id] = def.drop_weight
	return weights


## Rolls among only the tiers listed in `weights` (tier id -> weight),
## e.g. an enemy's per-tier loot table from DESIGN.md's "Enemy Types &
## Loot Tiers" section. Falls back to the flat table if weights is empty.
##
## The Forge (DESIGN.md's "The Forge: buy odds, not numbers," 2026-08-17):
## its own spec flags the real crux -- adjusting only pick_random_type()'s
## rarely-hit fallback table would visibly do nothing, since per-enemy
## drop tables (routed through here) are what almost every roll actually
## uses. Both paths now go through this one function (see
## pick_random_type() above), so one Forge check covers both.
func pick_random_weighted(weights: Dictionary) -> LootTypeDef:
	if weights.is_empty():
		weights = _flat_weights()
	var forge_level: int = MetaProgression.get_level(MetaProgression.STAT_FORGE)
	if forge_level > 0:
		weights = get_forge_adjusted_weights(weights, forge_level)
	var total: float = 0.0
	for tier_id: StringName in weights:
		total += float(weights[tier_id])
	var roll := randf() * total
	var accum := 0.0
	var last_def: LootTypeDef = null
	for tier_id: StringName in weights:
		accum += float(weights[tier_id])
		last_def = get_type(tier_id)
		if roll <= accum:
			return last_def
	return last_def


## Shifts weight from Common/Uncommon toward every other tier (Rare and
## up), proportional to their existing relative weights so the upper
## tiers' own ratio to each other stays intact -- Forge moves mass
## up-tier, it doesn't invent a new distribution among the tiers it moves
## it into. `level` is a plain param (not read live off MetaProgression)
## so this stays a pure, directly-testable function; STAT_FORGE's
## per_level_gain (percentage points, not a 0.0-1.0 fraction -- see its
## registration comment) is the one place the actual balance number
## lives, read here rather than duplicated as a second constant.
func get_forge_adjusted_weights(base: Dictionary, level: int) -> Dictionary:
	if level <= 0 or base.is_empty():
		return base
	var per_level_gain: float = (
		MetaProgression.get_stat_def(MetaProgression.STAT_FORGE).per_level_gain
	)
	var shift_fraction: float = float(level) * per_level_gain / 100.0
	const LOW_TIERS: Array[StringName] = [&"common", &"uncommon"]
	var high_total: float = 0.0
	for tier_id: StringName in base:
		if tier_id not in LOW_TIERS:
			high_total += float(base[tier_id])
	if high_total <= 0.0:
		return base
	var adjusted: Dictionary = base.duplicate()
	var moved: float = 0.0
	for tier_id: StringName in LOW_TIERS:
		if not base.has(tier_id):
			continue
		var reduction: float = float(base[tier_id]) * shift_fraction
		adjusted[tier_id] = float(base[tier_id]) - reduction
		moved += reduction
	for tier_id: StringName in base:
		if tier_id in LOW_TIERS:
			continue
		var share: float = float(base[tier_id]) / high_total
		adjusted[tier_id] = float(adjusted[tier_id]) + moved * share
	return adjusted


## Fixed per-tier constant since Compacting's removal (DESIGN.md
## 2026-08-16, "Compacting removed entirely") -- every tier's stack size
## is now permanently whatever's registered above, not an upgradeable
## lever. Kept as its own function (not just reading def.stack_size at
## call sites directly) since it's still the one place callers should
## ask "how many of this tier fit in a slot," even though the answer no
## longer varies.
func get_effective_stack_size(type_id: StringName) -> int:
	var def := get_type(type_id)
	if def == null:
		return 1
	return def.stack_size


## Total occupied slots across a backpack dict: one slot per stack instance
## of a tier (ceil-rounded against its stack size), not one slot per
## distinct tier -- a tier spans multiple slots once its own stack fills.
## Shared by Player (fill %/capacity) and BackpackGrid (the HUD readout) so
## both always agree on the same number instead of each hand-rolling it.
func count_slots_used(backpack: Dictionary) -> int:
	var total := 0
	for type_id: StringName in backpack:
		var stack_size: int = get_effective_stack_size(type_id)
		total += ceili(float(backpack[type_id]) / float(stack_size))
	return total


## Per-slot breakdown of a backpack dict, in the same slot count as
## count_slots_used() -- each entry is [type_id, count_in_that_slot].
## BackpackGrid draws one rect per real slot instead of one per distinct
## tier, so it needs the split, not just the total.
func slot_breakdown(backpack: Dictionary) -> Array:
	var slots: Array = []
	for type_id: StringName in backpack:
		var stack_size: int = get_effective_stack_size(type_id)
		var remaining: int = int(backpack[type_id])
		while remaining > 0:
			var slot_count: int = mini(remaining, stack_size)
			slots.append([type_id, slot_count])
			remaining -= slot_count
	return slots


## Index into the registered tier order (0 = Common ... 5 = Legendary) --
## shared by every "rarer tier = bigger number" formula (Streak, Cast
## Off, Attunement) instead of each hand-rolling its own copy of the
## order, per CLAUDE.md's "duplicated lookups belong on the autoload that
## owns the data" guidance -- this was already duplicated twice before
## Attunement made it three.
func get_tier_index(type_id: StringName) -> int:
	for i in _types.size():
		if _types[i].id == type_id:
			return i
	return 0


func get_tier_count() -> int:
	return _types.size()


func _register(
	id: StringName,
	display_name: String,
	color: Color,
	value: int,
	stack_size: int,
	drop_weight: float
) -> void:
	var def := LootTypeDef.new()
	def.id = id
	def.display_name = display_name
	def.color = color
	def.value = value
	def.stack_size = stack_size
	def.drop_weight = drop_weight
	_types.append(def)
