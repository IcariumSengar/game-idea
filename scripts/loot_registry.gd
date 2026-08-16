extends Node

## Central registry of loot rarity tiers -- numbers match the rarity table
## in DESIGN.md's "Loot, backpack & shop economy" section exactly. That
## table is the source of truth; update there first, then mirror here.
## Data-driven like MetaProgression's stats -- add a tier with one
## _register() call, everything else (drop rolls, backpack coloring,
## currency value, stack limits) reads the registry generically.

var _types: Array[LootTypeDef] = []
var _total_weight: float = 0.0


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


func pick_random_type() -> LootTypeDef:
	var roll := randf() * _total_weight
	var accum := 0.0
	for def in _types:
		accum += def.drop_weight
		if roll <= accum:
			return def
	return _types[-1]


## Rolls among only the tiers listed in `weights` (tier id -> weight),
## e.g. an enemy's per-tier loot table from DESIGN.md's "Enemy Types &
## Loot Tiers" section. Falls back to the flat table if weights is empty.
func pick_random_weighted(weights: Dictionary) -> LootTypeDef:
	if weights.is_empty():
		return pick_random_type()
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
	_total_weight += drop_weight
