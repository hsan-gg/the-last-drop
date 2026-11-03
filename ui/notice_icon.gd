class_name NoticeIcon
extends Control
## The little pictogram on a notification, drawn from shapes so it stays crisp.

var kind := "dot"
var color := Color.WHITE


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, 6.0, Color(color.r, color.g, color.b, 0.18))
	match kind:
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(-1, 2), c + Vector2(3, -3)]), color, 2.0)
		"flag":
			draw_line(c + Vector2(-2, -4), c + Vector2(-2, 4), color, 1.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -4), c + Vector2(4, -2), c + Vector2(-2, 0)]), color)
		"star":
			var points := PackedVector2Array()
			for index in 10:
				var radius := 4.5 if index % 2 == 0 else 2.0
				points.append(c + Vector2.from_angle(-PI / 2.0 + index * PI / 5.0) * radius)
			draw_colored_polygon(points, color)
		"bag":
			draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 5)), color)
			draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 3)), color.darkened(0.2))
		"spark":
			draw_line(c + Vector2(0, -4), c + Vector2(0, 4), color, 1.0)
			draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), color, 1.0)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
		_:
			draw_circle(c, 2.0, color)
