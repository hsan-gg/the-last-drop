class_name Meter
extends Control
## A small horizontal bar, drawn directly so it stays crisp at pixel scale.

var ratio: float = 1.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(64, 7)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))
	var inner := Vector2(size.x - 2.0, size.y - 2.0)
	draw_rect(Rect2(Vector2.ONE, Vector2(inner.x * ratio, inner.y)), fill_color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35), false, 1.0)
