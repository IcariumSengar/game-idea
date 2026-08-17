class_name PactDef
extends Resource

## Depth Pass Group E "Pacts" (DESIGN.md 2026-08-17): a per-run rule
## mutation chosen at run-prep, not a purchased stat -- deliberately no
## cost/level fields (mirrors StatDef's identity shape, not its curve).

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
