class_name RuneSlot
extends Control
## One rune on the HUD: its little picture, its key, dim when out of energy.

var slot := 1


func _draw() -> void:
	var rune := Runes.in_slot(slot)
	if rune.is_empty():
		return
	var definition: Dictionary = Runes.DEFINITIONS[rune]
	var ready := Runes.can_afford(float(definition["cost"]) * (0.2 if rune == "ember" else 1.0))
	var color := Color(definition["color"])
	if not ready:
		color = color.darkened(0.6)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.09, 0.85))
	draw_rect(Rect2(Vector2.ZERO, size), color, false, 1.0)
	var c := size / 2.0
	match rune:
		"ember":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(-4, 3), c + Vector2(4, 3)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1), c + Vector2(-2, 3), c + Vector2(2, 3)]), Color("#fff0a0") if ready else color)
		"scatter":
			for i in 3:
				draw_line(c + Vector2(-5, 0), c + Vector2(5, -4 + i * 4), color, 1.0)
			draw_rect(Rect2(c + Vector2(-6, -1), Vector2(3, 2)), color)
		"tide":
			for row in 2:
				draw_arc(c + Vector2(-2, -2 + row * 4), 3.0, PI, TAU, 8, color, 1.0)
				draw_arc(c + Vector2(3, -2 + row * 4), 3.0, 0.0, PI, 8, color, 1.0)
	draw_string(UiTheme.FONT_FILE, Vector2(1, size.y + 7), str(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#f6ecd6"))
