class_name Altar
extends Area2D

## Altar (DESIGN.md's "Altar," 2026-08-17): a structure spawning at each
## phase boundary (arena.gd's own 20s/40s beats), offering ONE boon (not
## a menu -- the decision is whether, not which) at a stated cost in
## items of a tier. Despawns after DESPAWN_TIME if unused -- skipping it
## is a real, if minor, cost. Structured like Loot/Enemy: an Area2D the
## player walks into, then confirms with a key press rather than a menu.

const DESPAWN_TIME: float = 15.0
const SACRIFICE_COUNT: int = 3
## "3 Rare or higher" per the idea's own illustrative cost -- simplified
## to one concrete tier drawn from that range (matching
## Player.sacrifice_loot()'s single-tier signature) rather than an
## any-of-several-tiers combo cost.
const COST_TIER_POOL: Array[StringName] = [&"rare", &"epic", &"mythic", &"legendary"]
## Ship one or two boons, not the full illustrative list (same "one thing
## first" discipline Group A used for Streak before Rampage/Ascension).
## Spellpower and full heal are the two simplest; a guaranteed-tier-up
## boon needs new per-run drop-override state -- real follow-on scope,
## not built here.
const BOON_POOL: Array[StringName] = [Player.ALTAR_BOON_SPELLPOWER, Player.ALTAR_BOON_FULL_HEAL]
const BOON_LABELS: Dictionary = {
	Player.ALTAR_BOON_SPELLPOWER: "Arcane Surge (+Spellpower, rest of run)",
	Player.ALTAR_BOON_FULL_HEAL: "Vital Bloom (full heal)",
}
const RADIUS: float = 22.0
const DETECTION_RADIUS: float = 50.0
const ACCENT_COLOR: Color = Palette.ALTAR_ACCENT
const DENIED_COLOR: Color = Palette.ALTAR_DENIED
const PULSE_SPEED: float = 2.0
const PULSE_AMOUNT: float = 0.15
## Fades out over the last few seconds before despawn -- a visible
## countdown, not a surprise disappearance.
const DESPAWN_WARNING_TIME: float = 4.0
const DENIED_MESSAGE_DURATION: float = 1.0
const PROMPT_OFFSET: Vector2 = Vector2(-90.0, -46.0)
const SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")

var cost_tier: StringName
var boon_id: StringName
var _time_left: float = DESPAWN_TIME
var _time: float = 0.0
var _player_in_range: Player = null
var _denied_message_time_left: float = 0.0


func _ready() -> void:
	cost_tier = COST_TIER_POOL[randi() % COST_TIER_POOL.size()]
	boon_id = BOON_POOL[randi() % BOON_POOL.size()]
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	_time_left -= delta
	if _denied_message_time_left > 0.0:
		_denied_message_time_left = maxf(_denied_message_time_left - delta, 0.0)
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


## Bots never interact -- same "real-input players only" split Manual
## Triage already established (playtest balance signal shouldn't depend
## on the bot learning a new interaction).
func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body.is_bot_controlled():
		_player_in_range = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == Settings.get_keybind(&"keep"):
		_try_confirm()


func _try_confirm() -> void:
	if not _player_in_range.sacrifice_loot(cost_tier, SACRIFICE_COUNT):
		_denied_message_time_left = DENIED_MESSAGE_DURATION
		AudioManager.play("discard")
		return
	_player_in_range.apply_altar_boon(boon_id)
	AudioManager.play("purchase")
	_spawn_spark()
	queue_free()


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = ACCENT_COLOR
	spark.amount = 20
	get_parent().add_child(spark)
	spark.emitting = true


func _draw() -> void:
	var pulse: float = 1.0 + sin(_time * PULSE_SPEED) * PULSE_AMOUNT
	var fade: float = (
		1.0 if _time_left > DESPAWN_WARNING_TIME else _time_left / DESPAWN_WARNING_TIME
	)
	var ring_color := Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, ACCENT_COLOR.a * fade)
	draw_circle(Vector2.ZERO, RADIUS * pulse, Color(ring_color.r, ring_color.g, ring_color.b, 0.25))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, ring_color, 3.0)
	draw_line(Vector2(0.0, -RADIUS * 0.6), Vector2(0.0, RADIUS * 0.6), ring_color, 3.0)
	draw_line(Vector2(-RADIUS * 0.5, 0.0), Vector2(RADIUS * 0.5, 0.0), ring_color, 3.0)

	var font := ThemeDB.fallback_font
	if _player_in_range != null:
		var tier_def := LootTypes.get_type(cost_tier)
		var tier_name: String = tier_def.display_name if tier_def != null else String(cost_tier)
		var prompt: String = (
			"[K] %s -- Sacrifice %d %s+"
			% [BOON_LABELS.get(boon_id, ""), SACRIFICE_COUNT, tier_name]
		)
		draw_string(font, PROMPT_OFFSET, prompt, HORIZONTAL_ALIGNMENT_LEFT, 240, 13, Color.WHITE)
	if _denied_message_time_left > 0.0:
		draw_string(
			font,
			PROMPT_OFFSET + Vector2(30.0, 18.0),
			"Not enough!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			DENIED_COLOR
		)
