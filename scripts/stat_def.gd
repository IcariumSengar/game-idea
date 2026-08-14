class_name StatDef
extends Resource

## Cost curve: cost(level) = round(base_cost * cost_growth ^ level). A flat
## cost_growth of 1.0 degenerates to a constant flat cost -- used for stats
## that don't have a designed curve yet (e.g. Backpack Capacity).

enum Currency { PLAYER, BACKPACK }

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_value: float = 0.0
@export var per_level_gain: float = 0.0
@export var base_cost: int = 0
@export var cost_growth: float = 1.0
@export var level_cap: int = 999
@export var decimals: int = 0
@export var currency: Currency = Currency.PLAYER
