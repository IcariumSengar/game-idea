class_name BackpackGrid
extends Control

## Illustrates the backpack as a grid of item-type slots -- each occupied
## slot shows its rarity color and stack count -- instead of an abstract
## fill bar, per DESIGN.md's post-MVP UI direction. Capacity growing (shop
## upgrades) is reflected by the grid growing; a background wash behind the
## whole grid trends toward red as more slots fill, mirroring the HP bar's
## color logic so the risk mechanic reads at a glance.

const SLOT_SIZE: float = 20.0
const SLOT_GAP: float = 4.0
const SLOTS_PER_ROW: int = 10
const SLOT_PADDING: float = 4.0
const EMPTY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)
const EMPTY_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.22)
const FILLED_BORDER_DARKEN: float = 0.4
const DANGER_COLOR_LOW: Color = Color(0.3, 0.65, 0.9, 0.0)
const DANGER_COLOR_HIGH: Color = Color(0.9, 0.25, 0.2, 0.35)
const COUNT_FONT_SIZE: int = 11
const COUNT_SHADOW_OFFSET: Vector2 = Vector2(1.0, 1.0)
## Ghost slot: previews the next Bearing purchase right in the HUD, per
## DESIGN.md's Backpack UI "longer-term idea" note. Fainter than a real
## empty (purchased-but-unfilled) slot and dashed rather than solid, so it
## reads as "not real yet" at a glance.
const GHOST_COLOR: Color = Color(1.0, 1.0, 1.0, 0.04)
const GHOST_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.16)
const GHOST_DASH_LENGTH: float = 3.0
## Leaden's ballast slots (Depth Pass Group C, DESIGN.md 2026-08-17) aren't
## tied to a real backpack dict entry -- drawn as their own plain, muted
## slots after the real ones so the grid's filled count always matches
## Player.get_slots_used() exactly, same lesson as the 2026-08-17 fill-%
## bugfix (HUD and this grid must never read two different formulas).
const BALLAST_COLOR: Color = Color(0.3, 0.28, 0.26)
const BALLAST_BORDER_COLOR: Color = Color(0.5, 0.46, 0.42)

var _capacity: int = 0
var _slot_ids: Array[StringName] = []
var _slot_counts: Array[int] = []
var _ballast_slots: int = 0
var _show_ghost_slot: bool = false


func update(backpack: Dictionary, capacity: int, ballast_slots: int = 0) -> void:
	_capacity = capacity
	_slot_ids.clear()
	_slot_counts.clear()
	for slot: Array in LootTypes.slot_breakdown(backpack):
		_slot_ids.append(slot[0])
		_slot_counts.append(slot[1])
	_ballast_slots = ballast_slots
	_show_ghost_slot = not MetaProgression.is_maxed(MetaProgression.STAT_BACKPACK_CAPACITY)
	_update_min_size()
	queue_redraw()


func _update_min_size() -> void:
	if _capacity <= 0:
		custom_minimum_size = Vector2.ZERO
		return
	custom_minimum_size = _grid_size(_capacity + (1 if _show_ghost_slot else 0))


func _grid_size(slot_count: int) -> Vector2:
	var cols := mini(slot_count, SLOTS_PER_ROW)
	var rows := ceili(float(slot_count) / float(SLOTS_PER_ROW))
	return Vector2(
		cols * SLOT_SIZE + maxi(cols - 1, 0) * SLOT_GAP,
		rows * SLOT_SIZE + maxi(rows - 1, 0) * SLOT_GAP
	)


func _draw() -> void:
	if _capacity <= 0:
		return
	var filled_total: int = _slot_ids.size() + _ballast_slots
	var fraction := float(filled_total) / float(_capacity)
	var danger_color := DANGER_COLOR_LOW.lerp(DANGER_COLOR_HIGH, fraction)
	var grid_size := _grid_size(_capacity)
	draw_rect(
		Rect2(-Vector2.ONE * SLOT_PADDING, grid_size + Vector2.ONE * SLOT_PADDING * 2.0),
		danger_color
	)

	var font := ThemeDB.fallback_font
	for i in _capacity:
		var col := i % SLOTS_PER_ROW
		var row := i / SLOTS_PER_ROW
		var rect := Rect2(
			Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP)),
			Vector2(SLOT_SIZE, SLOT_SIZE)
		)
		if i < _slot_ids.size():
			_draw_filled_slot(rect, font, _slot_ids[i], _slot_counts[i])
		elif i < filled_total:
			_draw_ballast_slot(rect)
		else:
			draw_rect(rect, EMPTY_COLOR)
			draw_rect(rect, EMPTY_BORDER_COLOR, false, 1.0)

	if _show_ghost_slot:
		_draw_ghost_slot(_capacity)


func _draw_ballast_slot(rect: Rect2) -> void:
	draw_rect(rect, BALLAST_COLOR)
	draw_rect(rect, BALLAST_BORDER_COLOR, false, 1.5)


func _draw_ghost_slot(index: int) -> void:
	var col := index % SLOTS_PER_ROW
	var row := index / SLOTS_PER_ROW
	var rect := Rect2(
		Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP)),
		Vector2(SLOT_SIZE, SLOT_SIZE)
	)
	draw_rect(rect, GHOST_COLOR)
	_draw_dashed_border(rect, GHOST_BORDER_COLOR)


func _draw_dashed_border(rect: Rect2, color: Color) -> void:
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	for i in corners.size():
		draw_dashed_line(
			corners[i], corners[(i + 1) % corners.size()], color, 1.0, GHOST_DASH_LENGTH
		)


func _draw_filled_slot(rect: Rect2, font: Font, type_id: StringName, count: int) -> void:
	var def := LootTypes.get_type(type_id)
	var color: Color = def.color if def != null else Color.WHITE
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(FILLED_BORDER_DARKEN), false, 1.5)

	var count_text := str(count)
	var text_size := font.get_string_size(
		count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, COUNT_FONT_SIZE
	)
	var text_pos := (
		rect.position
		+ Vector2(rect.size.x * 0.5 - text_size.x * 0.5, rect.size.y * 0.5 + text_size.y * 0.25)
	)
	draw_string(
		font,
		text_pos + COUNT_SHADOW_OFFSET,
		count_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		COUNT_FONT_SIZE,
		Color(0.0, 0.0, 0.0, 0.8)
	)
	draw_string(
		font, text_pos, count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, COUNT_FONT_SIZE, Color.WHITE
	)
