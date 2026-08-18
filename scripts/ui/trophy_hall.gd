extends Control

## Trophy Hall (DESIGN.md's "A hoard you can actually see," 2026-08-17):
## pure-display Sanctum-adjacent screen, same non-economic role the
## Grimoire already has -- no currency spent, nothing to buy. Six fixed
## slots (Common through Legendary), each showing the highest single-item
## value ever seen for that tier (MetaProgression.best_loot_value),
## deliberately not "everything ever collected" -- unbounded and
## illegible at scale, where best-of-tier stays exactly six entries
## forever and gives a concrete, nameable target ("beat your best
## Legendary").

const LOCKED_COLOR: String = "#666660"
const NAME_COLOR: String = "#e0e0dc"
const VALUE_COLOR: String = "#e6cc99"
const HEADER_COLOR: String = "#e6cc99"

@onready var _body: RichTextLabel = %TrophyHallBody


func _ready() -> void:
	_body.text = _build_bbcode()
	$CenterContainer/OuterVBox/BackButton.grab_focus()


func _build_bbcode() -> String:
	var lines: Array[String] = []
	lines.append("[color=%s][b]BEST OF EACH TIER[/b][/color]" % HEADER_COLOR)
	lines.append("")
	for def: LootTypeDef in LootTypes.get_types():
		var best_value := MetaProgression.get_best_loot_value(def.id)
		lines.append("[color=#%s][b]%s[/b][/color]" % [def.color.to_html(false), def.display_name])
		if best_value > 0:
			lines.append("[color=%s]Best found: %d[/color]" % [VALUE_COLOR, best_value])
		else:
			lines.append("[color=%s]Not yet found[/color]" % LOCKED_COLOR)
		lines.append("")

	return "\n".join(lines)


func _on_back_pressed() -> void:
	SceneTransition.goto_scene("res://scenes/ui/run_prep.tscn")
