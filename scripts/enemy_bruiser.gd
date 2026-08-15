class_name EnemyBruiser
extends Enemy

## Tier 2: pauses to telegraph, then charges in a straight line at the
## player's last-known position. Only deals contact damage while
## charging -- the pause is a dodge window, not a free hit, per
## DESIGN.md's "Introduces evasion timing" role for this tier.

enum State { PAUSE, CHARGE }

@export var charge_speed: float = 250.0
@export var charge_distance: float = 400.0
@export var pause_duration_min: float = 2.0
@export var pause_duration_max: float = 3.0

var _state: State = State.PAUSE
var _state_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_distance_left: float = 0.0


func _ready() -> void:
	super._ready()
	loot_weights = {&"common": 20.0, &"uncommon": 50.0, &"rare": 25.0, &"epic": 5.0}
	_state_timer = randf_range(pause_duration_min, pause_duration_max)


func _update_behavior(delta: float) -> void:
	match _state:
		State.PAUSE:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_charge_direction = position.direction_to(target.position)
				_charge_distance_left = charge_distance
				_state = State.CHARGE
		State.CHARGE:
			velocity = _charge_direction * charge_speed
			move_and_slide()
			_charge_distance_left -= charge_speed * delta
			_apply_contact_damage(delta)
			if _charge_distance_left <= 0.0:
				_state = State.PAUSE
				_state_timer = randf_range(pause_duration_min, pause_duration_max)
