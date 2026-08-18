extends Control

## Grimoire: an in-game reference for spells and Gem Combos, since none of
## this is otherwise taught -- 8 spells with a specific unlock ladder and
## Gem Combos with their own trigger conditions previously only existed in
## DESIGN.md and chat history. Progressive discovery, not a full list from
## run 1 (direct decision): spells show once unlocked
## (MetaProgression.is_spell_unlocked()), combos show once triggered at
## least once ever (MetaProgression.is_combo_discovered()) -- everything
## else reads "???" rather than spoiling what hasn't happened yet.

const LOCKED_COLOR: String = "#666660"
const NAME_COLOR: String = "#e0e0dc"
const DESC_COLOR: String = "#a0a09c"
const HEADER_COLOR: String = "#e6cc99"

const SPELLS: Array[Dictionary] = [
	{
		"id": &"arcane_bolt",
		"name": "Luminous Dart",
		"desc": "Fires a homing bolt at the nearest enemy.",
	},
	{
		"id": &"inferno_blade",
		"name": "The Undertow",
		"desc": "Omnidirectional melee burn -- hits everything in range.",
	},
	{"id": &"frost_nova", "name": "Deep Chill", "desc": "AOE damage and slows everything nearby."},
	{
		"id": &"meteor_strike",
		"name": "Trench Collapse",
		"desc": "Telegraphed strike, heavy AOE damage on impact.",
	},
	{
		"id": &"lightning_chain",
		"name": "Eel Current",
		"desc": "Arcs between up to 4 enemies, damage fading each hop.",
	},
	{
		"id": &"time_warp",
		"name": "Crushing Depths",
		"desc": "Large-radius crowd control, slows everything caught in it.",
	},
	{
		"id": &"teleport_pulse",
		"name": "Ink Jet",
		"desc": "Blinks you forward, damaging enemies at both ends.",
	},
	{
		"id": &"summon_familiar",
		"name": "Anglerling",
		"desc": "Summons a pet that fires its own bolts at enemies.",
	},
]

const COMBOS: Array[Dictionary] = [
	{
		"id": &"full_set",
		"name": "Full Set",
		"desc":
		(
			"Hold one of each of the six rarity tiers at once. Clears every"
			+ " enemy on screen. Once per run."
		),
	},
	{
		"id": &"streak",
		"name": "Streak",
		"desc":
		(
			"Collect three of the same tier in a row. AOE damage burst,"
			+ " stronger for rarer tiers. Repeatable."
		),
	},
]

## The Angler (Depth Pass Group C): progressive discovery like Gem Combos
## above, since it only spawns from Phase 2 on and a fresh run genuinely
## hasn't seen one yet. Attunement below is always shown instead --
## nothing about it is a run-time surprise (it's a passive, always-on
## mechanic from the moment a run starts) so hiding it behind discovery
## would gate information the player already has access to, not protect
## a real reveal.
const MAGPIE_NAME: String = "the Angler"
const MAGPIE_DESC: String = (
	"Steals unclaimed loot off the ground and eats it. Kill it before"
	+ " it gets away and it drops everything it ate, at a bonus."
)

@onready var _body: RichTextLabel = %GrimoireBody


func _ready() -> void:
	_body.text = _build_bbcode()


func _build_bbcode() -> String:
	var lines: Array[String] = []
	lines.append("[color=%s][b]SPELLS[/b][/color]" % HEADER_COLOR)
	lines.append("")
	for spell: Dictionary in SPELLS:
		if MetaProgression.is_spell_unlocked(spell["id"]):
			lines.append("[color=%s][b]%s[/b][/color]" % [NAME_COLOR, spell["name"]])
			lines.append("[color=%s]%s[/color]" % [DESC_COLOR, spell["desc"]])
		else:
			# Spell Choice (DESIGN.md 2026-08-17): which level grants which
			# spell is chosen, not fixed, so there's no single "Lv N" to
			# name anymore -- a spell could be offered as early as L1.
			lines.append(
				"[color=%s][b]???[/b]  (unlock it via a Spell Unlock choice)[/color]" % LOCKED_COLOR
			)
		lines.append("")

	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append("[color=%s][b]GEM COMBOS[/b][/color]" % HEADER_COLOR)
	lines.append("")
	for combo: Dictionary in COMBOS:
		if MetaProgression.is_combo_discovered(combo["id"]):
			lines.append("[color=%s][b]%s[/b][/color]" % [NAME_COLOR, combo["name"]])
			lines.append("[color=%s]%s[/color]" % [DESC_COLOR, combo["desc"]])
		else:
			lines.append(
				(
					"[color=%s][b]???[/b]  (undiscovered -- trigger it to reveal)[/color]"
					% LOCKED_COLOR
				)
			)
		lines.append("")

	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append("[color=%s][b]THREATS[/b][/color]" % HEADER_COLOR)
	lines.append("")
	if MetaProgression.angler_encountered:
		lines.append("[color=%s][b]%s[/b][/color]" % [NAME_COLOR, MAGPIE_NAME])
		lines.append("[color=%s]%s[/color]" % [DESC_COLOR, MAGPIE_DESC])
	else:
		lines.append(
			(
				"[color=%s][b]???[/b]  (undiscovered -- reaches the arena from Phase 2 on)[/color]"
				% LOCKED_COLOR
			)
		)
	lines.append("")

	lines.append("[color=#666666]────────────────────────[/color]")
	lines.append("[color=%s][b]ATTUNEMENT[/b][/color]" % HEADER_COLOR)
	lines.append("")
	lines.append(
		(
			(
				"[color=%s]Your bag's composition tunes your spells, live. Lean and"
				+ " common-heavy: faster casts, weaker hits. Hoarding rares: slower"
				+ " casts, harder hits. An empty bag is worse than either end.[/color]"
			)
			% DESC_COLOR
		)
	)
	lines.append("")

	return "\n".join(lines)


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/run_prep.tscn")
