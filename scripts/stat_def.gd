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
## Sanctum UX (DESIGN.md 2026-08-17): node shape/size in the skill tree
## must be asserted, not inferred from "happens to have no children" --
## that inference drew a flat leaf stat larger than a real capstone like
## Spell Unlock, an accident of tree topology, not a design choice.
@export var is_milestone: bool = false
