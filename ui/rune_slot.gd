class_name RuneSlot
extends Control
## One rune on the HUD: a framed slot with its pixel icon and key. The energy
## it can draw on fills the slot from the bottom in the rune's colour, so you
## can read at a glance whether it is ready; the frame glows while in use.

const ICONS := preload("res://assets/sprites/icons/runes.png")
const ICON_SIZE := 12

var slot := 1
var active := false


func _draw() -> void:
	var rune := Runes.in_slot(slot)
	if rune.is_empty():
		return
	var definition: Dictionary = Runes.DEFINITIONS[rune]
	var cost := float(definition["cost"]) * (0.2 if rune == "ember" else 1.0)
	var ready := Runes.can_afford(cost)
	var color := Color(definition["color"])
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color("#120c18"))
	var fill := clampf(Runes.energy / Runes.MAX_ENERGY, 0.0, 1.0)
	var fill_color := color.darkened(0.55)
	fill_color.a = 0.85
	draw_rect(Rect2(Vector2(1, 1 + (size.y - 2) * (1.0 - fill)), Vector2(size.x - 2, (size.y - 2) * fill)), fill_color)
	var index: int = Runes.ORDER.find(rune)
	var icon_at := ((size - Vector2(ICON_SIZE, ICON_SIZE)) / 2.0).floor()
	var tint := Color.WHITE if ready else Color(0.45, 0.45, 0.5)
	if active:
		tint = Color(1.3, 1.2, 1.1)
	draw_texture_rect_region(ICONS, Rect2(icon_at, Vector2(ICON_SIZE, ICON_SIZE)), Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE), tint)
	var frame := color if ready else color.darkened(0.5)
	if active:
		frame = frame.lightened(0.4)
	draw_rect(box, frame, false, 1.0)
	draw_rect(Rect2(Vector2(-1, -1), size + Vector2(2, 2)), Color(0, 0, 0, 0.6), false, 1.0)
	var key := Rect2(Vector2(size.x - 6, size.y - 6), Vector2(7, 7))
	draw_rect(key, Color("#120c18"))
	draw_rect(key, frame, false, 1.0)
	draw_string(UiTheme.FONT_FILE, key.position + Vector2(1.5, 6), str(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#f6ecd6"))
