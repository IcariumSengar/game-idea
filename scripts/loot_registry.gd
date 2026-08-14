extends Node

## Central registry of loot rarity tiers -- numbers match the rarity table
## in DESIGN.md's "Post-MVP direction" section exactly. That table is the
## source of truth; update there first, then mirror the change here.
## Data-driven like MetaProgression's stats -- add a tier with one
## _register() call, everything else (drop rolls, backpack coloring,
## currency value, stack limits) reads the registry generically.

var _types: Array[LootTypeDef] = []
var _total_weight: float = 0.0


func _ready() -> void:
	_register(&"common", "Common", Color.WHITE, 1, 64, 50.0)
	_register(&"uncommon", "Uncommon", Color(0.3, 0.8, 0.35), 3, 32, 27.0)
	_register(&"rare", "Rare", Color(0.25, 0.55, 0.95), 10, 16, 14.0)
	_register(&"epic", "Epic", Color(0.65, 0.3, 0.9), 40, 8, 6.0)
	_register(&"mythic", "Mythic", Color(0.95, 0.55, 0.15), 150, 4, 2.5)
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


func get_effective_stack_size(type_id: StringName) -> int:
	var def := get_type(type_id)
	if def == null:
		return 1
	if type_id == &"legendary":
		return 1
	var compactor_stat := _get_compactor_stat_for_tier(type_id)
	if compactor_stat == StringName():
		return def.stack_size
	var compactor_level := MetaProgression.get_level(compactor_stat)
	if compactor_level == 0:
		return def.stack_size
	return roundi(MetaProgression.get_stat(compactor_stat))


func _get_compactor_stat_for_tier(type_id: StringName) -> StringName:
	match type_id:
		&"common":
			return MetaProgression.STAT_COMPACTOR_COMMON
		&"uncommon":
			return MetaProgression.STAT_COMPACTOR_UNCOMMON
		&"rare":
			return MetaProgression.STAT_COMPACTOR_RARE
		&"epic":
			return MetaProgression.STAT_COMPACTOR_EPIC
		&"mythic":
			return MetaProgression.STAT_COMPACTOR_MYTHIC
	return StringName()


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
