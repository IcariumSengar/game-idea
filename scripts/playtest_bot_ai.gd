class_name PlaytestBotAI
extends Node

## Reactive movement AI for headless auto-playtesting (see
## playtest_harness.gd). Not meant to play "optimally" -- just competently
## enough (flee danger, avoid walls, dash when cornered) to produce a
## stable, repeatable stand-in for an average player's survival, useful as
## a balance signal across many runs. Spells already auto-cast on their own
## (v10), so this only ever drives movement/dash.

const DANGER_RADIUS: float = 200.0
const PANIC_RADIUS: float = 90.0
const WALL_MARGIN: float = 80.0
const WANDER_CHANGE_INTERVAL: float = 1.2

var _player: Player
var _wander_direction: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0


func setup(player: Player) -> void:
	_player = player
	player.set_bot_control(true)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = WANDER_CHANGE_INTERVAL
		_wander_direction = Vector2.RIGHT.rotated(randf() * TAU)

	var threat := _sense_threats()
	var flee: Vector2 = threat.flee
	var direction: Vector2 = flee if flee != Vector2.ZERO else _wander_direction
	direction += _wall_avoidance()
	var want_dash: bool = float(threat.nearest) < PANIC_RADIUS
	_player.bot_set_input(
		direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO, want_dash
	)


## Single pass over enemies: builds a flee vector (weighted away from close
## threats) and tracks the single nearest distance for panic-dash gating.
func _sense_threats() -> Dictionary:
	var accum := Vector2.ZERO
	var nearest: float = INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var distance: float = _player.position.distance_to(enemy.position)
		nearest = min(nearest, distance)
		if distance < DANGER_RADIUS and distance > 0.0:
			accum += (_player.position - enemy.position).normalized() * (DANGER_RADIUS - distance)
	return {"flee": accum, "nearest": nearest}


func _wall_avoidance() -> Vector2:
	var push := Vector2.ZERO
	var pos: Vector2 = _player.position
	var size: Vector2 = _player.arena_size
	if pos.x < WALL_MARGIN:
		push.x += (WALL_MARGIN - pos.x) / WALL_MARGIN
	elif pos.x > size.x - WALL_MARGIN:
		push.x -= (WALL_MARGIN - (size.x - pos.x)) / WALL_MARGIN
	if pos.y < WALL_MARGIN:
		push.y += (WALL_MARGIN - pos.y) / WALL_MARGIN
	elif pos.y > size.y - WALL_MARGIN:
		push.y -= (WALL_MARGIN - (size.y - pos.y)) / WALL_MARGIN
	return push
