class_name Arena
extends Node2D

const MINION_SCENE: PackedScene = preload("res://scenes/enemy/enemy.tscn")
const MINION_FAST_SCENE: PackedScene = preload("res://scenes/enemy/enemy_minion_fast.tscn")
const MINION_TANKY_SCENE: PackedScene = preload("res://scenes/enemy/enemy_minion_tanky.tscn")
const BRUISER_SCENE: PackedScene = preload("res://scenes/enemy/enemy_bruiser.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemy/enemy_elite.tscn")
const MAGPIE_SCENE: PackedScene = preload("res://scenes/enemy/enemy_magpie.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/enemy/enemy_boss.tscn")
const LOOT_SCENE: PackedScene = preload("res://scenes/loot/loot.tscn")
const ALTAR_SCENE: PackedScene = preload("res://scenes/structures/altar.tscn")
## Tier 4: unique, one per run, spawned directly at this mark rather than
## through PHASE_SPAWN_WEIGHTS' repeating roll -- per DESIGN.md's "Future
## Expansions" note ("unique, 55+ sec, guaranteed Mythic+ drop").
const BOSS_SPAWN_TIME: float = 55.0

## Phase -> {enemy scene: spawn weight}, per DESIGN.md's "Spawn Rules":
## spawn mix stays fixed within a phase while frequency (RAMP_DURATION
## below) keeps accelerating independently. Each phase's "Minion" bucket is
## split 70/15/15 between the base chaser and its Fast/Tanky variants --
## same tier, same loot table (they share enemy.gd's defaults), just a
## speed/HP tradeoff for visual and tactical variety within the tier. Splits
## the existing per-phase Minion weight rather than changing the documented
## Minion-vs-Bruiser-vs-Elite ratios themselves.
## Magpie (Depth Pass Group C's "Loot Has Consequences," DESIGN.md
## 2026-08-17) is added on top rather than carved out of the existing
## per-tier ratios above -- it's a new axis (reacts to loot), not a
## replacement for an existing tier's role, and _pick_enemy_scene()'s
## weights don't need to sum to anything in particular. Absent from Phase
## 1 on purpose: there's barely any loot on the ground yet for it to
## react to, and Phase 1 is meant to stay gentle/accessible.
const MAGPIE_PHASE_WEIGHT: Array[float] = [0.0, 0.0, 0.12, 0.18]
const PHASE_SPAWN_WEIGHTS: Array[Dictionary] = [
	{},
	{MINION_SCENE: 0.7, MINION_FAST_SCENE: 0.15, MINION_TANKY_SCENE: 0.15},
	{
		MINION_SCENE: 0.49,
		MINION_FAST_SCENE: 0.105,
		MINION_TANKY_SCENE: 0.105,
		BRUISER_SCENE: 0.3,
	},
	{
		MINION_SCENE: 0.28,
		MINION_FAST_SCENE: 0.06,
		MINION_TANKY_SCENE: 0.06,
		BRUISER_SCENE: 0.35,
		ELITE_SCENE: 0.25,
	},
]
## Scatter (Depth Pass Group C): rarity scales how far a drop skitters from
## its kill site -- Common lands ~in place, Legendary skitters toward the
## edge, per DESIGN.md's "80-150px" call for the top tier. Direction is
## radially outward from the arena center (continuing the same line the
## kill already happened on), so chasing rare loot costs a worse position
## rather than a random one.
const SCATTER_RANGE_BY_TIER: Dictionary = {
	&"common": Vector2.ZERO,
	&"uncommon": Vector2(10.0, 25.0),
	&"rare": Vector2(25.0, 50.0),
	&"epic": Vector2(45.0, 80.0),
	&"mythic": Vector2(65.0, 110.0),
	&"legendary": Vector2(80.0, 150.0),
}
const SCATTER_ARENA_MARGIN: float = 20.0
const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const SHAKE_DURATION: float = 0.15
const SHAKE_MAGNITUDE: float = 8.0
const DEATH_SHAKE_DURATION: float = 0.4
const DEATH_SHAKE_MAGNITUDE: float = 16.0
const HIT_STOP_DURATION: float = 0.05
const HIT_STOP_SCALE: float = 0.05
const DEATH_HIT_STOP_DURATION: float = 0.12
const RAMP_DURATION: float = 45.0
const SPAWN_INTERVAL_START: float = 1.0
const SPAWN_INTERVAL_MIN: float = 0.25
const ENEMY_HP_SCALE_MIN: float = 1.5
const ENEMY_HP_SCALE_MAX: float = 3.0
const ENEMY_SPEED_SCALE_MIN: float = 1.6
const ENEMY_SPEED_SCALE_MAX: float = 2.4
## Phase 4 (DESIGN.md's "Phase 4: the arena becomes the antagonist,"
## 2026-08-17): one shape for this first pass -- a closing safe zone --
## chosen well clear of the Boss's 55s beat so Phase 3 gets its own
## stretch before escalating again. "Going dark" and hostile drop zones
## are real follow-on scope, deliberately deferred, not forgotten.
const PHASE_4_TIME: float = 90.0
const PHASE_4_SHRINK_DURATION: float = 30.0
const PHASE_4_SAFE_ZONE_SIZE: Vector2 = Vector2(640.0, 360.0)
## Reuses BackpackGrid's own red danger-color language rather than
## inventing new color vocabulary for this second "danger" signal.
const PHASE_4_DANGER_COLOR: Color = Palette.DANGER_HIGH
const PHASE_4_EDGE_WIDTH: float = 4.0
## Altar (DESIGN.md's "Altar," 2026-08-17): spawns at each existing phase
## boundary (reusing the 20s/40s pacing beats already gating Phase 2/3,
## not a new clock), offset from the player's current position so
## reaching it is a real "go get it" decision, not already underfoot.
const ALTAR_SPAWN_TIMES: Array[float] = [20.0, 40.0]
const ALTAR_OFFSET_RANGE: Vector2 = Vector2(150.0, 250.0)
const ALTAR_ARENA_MARGIN: float = 40.0

var _shake_time_left: float = 0.0
var _shake_magnitude: float = SHAKE_MAGNITUDE
var _run_time: float = 0.0
var _enemies_killed: int = 0
var _boss_spawned: bool = false
var _altars_spawned: int = 0
var _player: Player

@onready var _spawn_timer: Timer = $EnemySpawnTimer


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_player.hit.connect(_on_player_hit)


func _process(delta: float) -> void:
	_run_time += delta
	_player.set_safe_zone(get_safe_zone_rect())
	if _run_time >= PHASE_4_TIME:
		queue_redraw()
	if (
		_altars_spawned < ALTAR_SPAWN_TIMES.size()
		and _run_time >= ALTAR_SPAWN_TIMES[_altars_spawned]
	):
		_spawn_altar()
		_altars_spawned += 1
	if _shake_time_left <= 0.0:
		return
	_shake_time_left = max(_shake_time_left - delta, 0.0)
	if _shake_time_left > 0.0:
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_magnitude
	else:
		position = Vector2.ZERO


func _draw() -> void:
	if _run_time < PHASE_4_TIME:
		return
	draw_rect(get_safe_zone_rect(), PHASE_4_DANGER_COLOR, false, PHASE_4_EDGE_WIDTH)


func _spawn_altar() -> void:
	var altar: Altar = ALTAR_SCENE.instantiate()
	var angle: float = randf() * TAU
	var distance: float = randf_range(ALTAR_OFFSET_RANGE.x, ALTAR_OFFSET_RANGE.y)
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	altar.position = (_player.position + offset).clamp(
		Vector2(ALTAR_ARENA_MARGIN, ALTAR_ARENA_MARGIN),
		ARENA_SIZE - Vector2(ALTAR_ARENA_MARGIN, ALTAR_ARENA_MARGIN)
	)
	add_child(altar)


## Phase 4: the current "don't linger here" rect, centered on the arena
## and shrinking from the full ARENA_SIZE toward PHASE_4_SAFE_ZONE_SIZE
## over PHASE_4_SHRINK_DURATION once PHASE_4_TIME is reached. Read by
## both this scene's own _draw() (the visible encroaching edge) and
## player.gd's damage-over-time check (see Player.set_safe_zone()) -- the
## hard arena-bounds clamp stays fixed at the full ARENA_SIZE always, a
## player can still walk to the true edge, this is a separate zone
## layered on top of it, not a replacement for it.
func get_safe_zone_rect() -> Rect2:
	if _run_time < PHASE_4_TIME:
		return Rect2(Vector2.ZERO, ARENA_SIZE)
	var shrink_progress: float = clampf(
		(_run_time - PHASE_4_TIME) / PHASE_4_SHRINK_DURATION, 0.0, 1.0
	)
	var size: Vector2 = ARENA_SIZE.lerp(PHASE_4_SAFE_ZONE_SIZE, shrink_progress)
	var offset: Vector2 = (ARENA_SIZE - size) / 2.0
	return Rect2(offset, size)


func _on_player_hit() -> void:
	trigger_shake()


## Generic screen-shake + hit-stop, scaled by magnitude_scale (1.0 matches
## a normal player-hit). Used by combo-completion feedback (spell_caster.gd)
## as well as the player-hit case above, so juice stays consistent in feel
## rather than each caller inventing its own version.
func trigger_shake(magnitude_scale: float = 1.0, stop_duration: float = HIT_STOP_DURATION) -> void:
	# Screen shake/hit-stop are camera juice for a human viewer -- pointless
	# for a headless bot and would fight the playtest harness's speedup
	# (every hit resets Engine.time_scale to 1.0 for its duration).
	if PlaytestHarness.active:
		return
	_shake_time_left = SHAKE_DURATION
	_shake_magnitude = SHAKE_MAGNITUDE * magnitude_scale
	_hit_stop(stop_duration)


## Self-contained (doesn't rely on _process) so it still plays out fully
## when awaited by HUD before the tree pauses for the game-over screen.
func play_death_shake() -> void:
	Engine.time_scale = HIT_STOP_SCALE
	await get_tree().create_timer(DEATH_HIT_STOP_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0
	var elapsed: float = 0.0
	while elapsed < DEATH_SHAKE_DURATION:
		elapsed += get_process_delta_time()
		var falloff: float = 1.0 - elapsed / DEATH_SHAKE_DURATION
		position = (
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			* DEATH_SHAKE_MAGNITUDE
			* falloff
		)
		await get_tree().process_frame
	position = Vector2.ZERO


func _hit_stop(duration: float) -> void:
	Engine.time_scale = HIT_STOP_SCALE
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


func get_run_time() -> float:
	return _run_time


func get_enemies_killed() -> int:
	return _enemies_killed


## Difficulty phase (1/2/3/4), per DESIGN.md's "Spawn Rules" timing plus
## Phase 4's PHASE_4_TIME above -- drives the death-summary readout and
## (capped at 3, see _pick_enemy_scene()) PHASE_SPAWN_WEIGHTS/
## MAGPIE_PHASE_WEIGHT, which only have entries through Phase 3. Phase 4
## is about the closing arena, not a new enemy-composition tier -- keeps
## Phase 3's spawn mix rather than needing a 5th table entry.
func get_phase() -> int:
	if _run_time < 20.0:
		return 1
	if _run_time < 40.0:
		return 2
	if _run_time < PHASE_4_TIME:
		return 3
	return 4


func _on_enemy_spawn_timer_timeout() -> void:
	var ramp: float = clamp(_run_time / RAMP_DURATION, 0.0, 1.0)
	if not _boss_spawned and _run_time >= BOSS_SPAWN_TIME:
		_spawn_boss(ramp)
	var enemy: Enemy = _pick_enemy_scene().instantiate()
	enemy.position = _random_edge_position()
	enemy.apply_difficulty_scale(
		lerp(ENEMY_HP_SCALE_MIN, ENEMY_HP_SCALE_MAX, ramp),
		lerp(ENEMY_SPEED_SCALE_MIN, ENEMY_SPEED_SCALE_MAX, ramp)
	)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	_spawn_timer.wait_time = lerp(SPAWN_INTERVAL_START, SPAWN_INTERVAL_MIN, ramp)


## Spawned once, alongside (not instead of) the regularly-scheduled roll,
## the first time the spawn timer fires at/after BOSS_SPAWN_TIME.
func _spawn_boss(ramp: float) -> void:
	_boss_spawned = true
	var boss: Enemy = BOSS_SCENE.instantiate()
	boss.position = _random_edge_position()
	boss.apply_difficulty_scale(
		lerp(ENEMY_HP_SCALE_MIN, ENEMY_HP_SCALE_MAX, ramp),
		lerp(ENEMY_SPEED_SCALE_MIN, ENEMY_SPEED_SCALE_MAX, ramp)
	)
	boss.died.connect(_on_enemy_died)
	add_child(boss)


func _pick_enemy_scene() -> PackedScene:
	# Capped at 3: PHASE_SPAWN_WEIGHTS/MAGPIE_PHASE_WEIGHT only have
	# entries through Phase 3 (see get_phase()'s own docstring).
	var phase: int = mini(get_phase(), 3)
	var weights: Dictionary = PHASE_SPAWN_WEIGHTS[phase].duplicate()
	var magpie_weight: float = MAGPIE_PHASE_WEIGHT[phase]
	if magpie_weight > 0.0:
		weights[MAGPIE_SCENE] = magpie_weight
	var total: float = 0.0
	for scene: PackedScene in weights:
		total += float(weights[scene])
	var roll := randf() * total
	var accum := 0.0
	for scene: PackedScene in weights:
		accum += float(weights[scene])
		if roll <= accum:
			return scene
	return MINION_SCENE


func _on_enemy_died(enemy: Enemy) -> void:
	_enemies_killed += 1
	# Magpie (Depth Pass Group C) doesn't drop from the generic per-kill
	# roll -- it drops what it stole (see EnemyMagpie's own _on_died()), or
	# nothing at all if killed before it ever ate anything. That *is* its
	# loot table, not an addition to it.
	if enemy is EnemyMagpie:
		return
	var loot: Loot = LOOT_SCENE.instantiate()
	loot.position = enemy.position
	loot.type_id = LootTypes.pick_random_weighted(enemy.loot_weights).id
	var scatter_offset: Vector2 = _scatter_offset(loot.type_id, enemy.position)
	# Deferred: a killing blow can arrive from inside a physics signal
	# callback (a projectile's body_entered) -- adding an Area2D+shape to
	# the tree synchronously there fails against the physics server's
	# active query flush. Rare enough with one projectile at a time that
	# it likely went unnoticed in normal play; constant under the playtest
	# harness's sped-up multi-kill AOE casts.
	_spawn_loot.call_deferred(loot, scatter_offset)


func _spawn_loot(loot: Loot, scatter_offset: Vector2) -> void:
	add_child(loot)
	if scatter_offset != Vector2.ZERO:
		loot.launch_scatter(scatter_offset)


## Radially outward from the arena center, scaled by SCATTER_RANGE_BY_TIER,
## then clamped so a scattered drop never lands outside the play field.
func _scatter_offset(type_id: StringName, from_position: Vector2) -> Vector2:
	var range: Vector2 = SCATTER_RANGE_BY_TIER.get(type_id, Vector2.ZERO)
	if range.y <= 0.0:
		return Vector2.ZERO
	var distance: float = randf_range(range.x, range.y)
	var arena_center: Vector2 = ARENA_SIZE / 2.0
	var direction: Vector2 = arena_center.direction_to(from_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	var destination: Vector2 = (from_position + direction * distance).clamp(
		Vector2(SCATTER_ARENA_MARGIN, SCATTER_ARENA_MARGIN),
		ARENA_SIZE - Vector2(SCATTER_ARENA_MARGIN, SCATTER_ARENA_MARGIN)
	)
	return destination - from_position


func _random_edge_position() -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf() * ARENA_SIZE.x, 0.0)
		1:
			return Vector2(randf() * ARENA_SIZE.x, ARENA_SIZE.y)
		2:
			return Vector2(0.0, randf() * ARENA_SIZE.y)
		_:
			return Vector2(ARENA_SIZE.x, randf() * ARENA_SIZE.y)
