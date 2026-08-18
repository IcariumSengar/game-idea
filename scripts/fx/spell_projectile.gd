class_name SpellProjectile
extends Area2D

## Arcane Bolt's projectile -- straight-line bolt fired at the nearest
## enemy. Mirrors enemy_projectile.gd's shape but targets Enemy instead of
## Player, tinted per DESIGN.md's "Arcane (blue/purple)" note.

const LIFETIME: float = 2.0
const SPARK_SCENE: PackedScene = preload("res://scenes/fx/spark_burst.tscn")
const RADIUS: float = 6.0
## Painted Hoard (DESIGN.md's "Art Direction," 2026-08-17): a layered
## warm glow instead of one flat circle -- same technique
## skill_tree_view.gd's node glow and loot.gd's Legendary beacon already
## use, reused here rather than a fourth approach. Ink outline matches
## loot_gem.gd's own warm-brown stroke, not spell-tinted, so every
## procedural visual in this pass reads as one consistent style.
const GLOW_LAYERS: int = 3

@export var speed: float = 400.0
@export var damage: float = 20.0

var direction: Vector2 = Vector2.ZERO

var _time_left: float = LIFETIME


func _draw() -> void:
	var bolt_color := Palette.SPELL_ARCANE
	for layer in GLOW_LAYERS:
		var layer_t: float = float(layer + 1) / float(GLOW_LAYERS)
		var layer_radius: float = RADIUS * (1.0 + layer_t * 1.4)
		var layer_alpha: float = 0.3 * (1.0 - layer_t) * (1.0 - layer_t)
		draw_circle(
			Vector2.ZERO, layer_radius, Color(bolt_color.r, bolt_color.g, bolt_color.b, layer_alpha)
		)
	draw_circle(Vector2.ZERO, RADIUS, bolt_color)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Palette.SPELL_ARCANE_CORE)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Palette.ABYSS_INK_PROJECTILE, 1.0)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		body.take_damage(damage)
		_spawn_spark()
		queue_free()


func _spawn_spark() -> void:
	var spark: CPUParticles2D = SPARK_SCENE.instantiate()
	spark.position = position
	spark.color = Palette.SPELL_ARCANE
	spark.amount = 6
	get_parent().add_child(spark)
	spark.emitting = true
