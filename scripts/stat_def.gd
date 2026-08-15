class_name StatDef
extends Resource

## Cost curve: cost(level) = round(base_cost * cost_growth ^ level). A flat
## cost_growth of 1.0 would degenerate to a constant flat cost, though every
## registered stat currently has a designed (>1.0) growth curve.

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
