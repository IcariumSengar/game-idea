class_name EnemyMagpie
extends Enemy

## "Loot Has Consequences" (DESIGN.md's Depth Pass Group C, 2026-08-17):
## the arena's first enemy that reacts to loot instead of ignoring it.
## Chases the nearest unclaimed ground gem and eats it rather than always
## beelining the player; falls back to a normal chase (and normal contact
## damage) when nothing's available to steal, so it's never just idle.
## Built around a kill-it-back recovery window per the cross-game research
## cited in DESIGN.md (Diablo's Treasure Goblin, DRG's Loot Bug, Dark
## Souls' Crystal Lizard are loved because killing them fast enough gets
## the loot back, often at a bonus -- Minecraft's Creeper and Rogue's
## leprechaun are hated because the loss is final): die, and it drops
## everything it ate back, at a bonus, never a permanent theft.

const STEAL_DETECT_RANGE: float = 260.0
const EAT_RANGE: float = 20.0
const RECOVERED_LOOT_SCENE: PackedScene = preload("res://scenes/loot/loot.tscn")

var _stolen_type_ids: Array[StringName] = []


func _ready() -> void:
	super._ready()
	# No generic per-kill drop -- what it regurgitates on death (see
	# _on_died()) IS its drop, and only if it actually ate something. A
	# Magpie killed before it steals anything drops nothing, matching
	# "recoverable if you catch it in time," not "always guarantees loot."
	loot_weights = {}
	died.connect(_on_died)
	MetaProgression.mark_magpie_encountered()


func _update_behavior(delta: float) -> void:
	var loot := _nearest_stealable_loot()
	if loot != null:
		var distance: float = position.distance_to(loot.position)
		if distance <= EAT_RANGE:
			_stolen_type_ids.append(loot.steal())
			AudioManager.play("magpie_eat")
		else:
			velocity = position.direction_to(loot.position) * _slowed(speed) + _knockback
			move_and_slide()
		return
	velocity = (
		position.direction_to(target.position + _approach_offset) * _slowed(speed) + _knockback
	)
	move_and_slide()
	_apply_contact_damage(delta)


func _nearest_stealable_loot() -> Loot:
	var nearest: Loot = null
	var nearest_distance := STEAL_DETECT_RANGE
	for node in get_tree().get_nodes_in_group("loot"):
		var loot := node as Loot
		if loot == null or not loot.is_available_to_steal():
			continue
		var distance := position.distance_to(loot.position)
		if distance <= nearest_distance:
			nearest = loot
			nearest_distance = distance
	return nearest


## Drops everything it ate back at its death position -- see
## RECOVERED_VALUE_BONUS_MULTIPLIER on loot.gd for the bonus itself.
func _on_died(_dead_enemy: Enemy) -> void:
	for type_id: StringName in _stolen_type_ids:
		var loot: Loot = RECOVERED_LOOT_SCENE.instantiate()
		loot.position = position
		loot.type_id = type_id
		loot.mark_recovered()
		get_parent().add_child.call_deferred(loot)
