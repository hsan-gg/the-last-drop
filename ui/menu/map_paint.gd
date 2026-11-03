class_name MapPaint
extends RefCounted
## The look of the map, kept apart from what it shows: aged parchment, ink
## lines and little hand-drawn icons, in the spirit of Stardew Valley's map.

const PAPER := Color("#e9d6a8")
const PAPER_DARK := Color("#cdb27c")
const PAPER_EDGE := Color("#a8875a")
const INK := Color("#5a3e2a")
const INK_SOFT := Color("#8a6a48")
const WATER := Color("#7ab0bc")
const TOXIC := Color("#9ab048")
const ROAD := Color("#d4b47a")
const FOG := Color("#c4a874")
const FOG_LINE := Color("#b0925e")
const GOLD := Color("#e0a030")
const RED := Color("#b8483a")


## A sheet of parchment: a darker rim and a few faint stains.
static func parchment(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, PAPER_EDGE)
	canvas.draw_rect(rect.grow(-2), PAPER_DARK)
	canvas.draw_rect(rect.grow(-5), PAPER)
	for index in 7:
		var at := rect.grow(-24).position + Vector2(_hash(index) * (rect.size.x - 48.0), _hash(index + 9) * (rect.size.y - 48.0))
		canvas.draw_circle(at, 6.0 + _hash(index + 3) * 12.0, Color(PAPER_DARK.r, PAPER_DARK.g, PAPER_DARK.b, 0.25))


## A ribbon banner with a name on it, centred at `at`.
static func banner(canvas: CanvasItem, at: Vector2, text: String, color: Color = INK) -> void:
	var font := UiTheme.FONT_FILE as Font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
	var rect := Rect2(at - Vector2(width / 2.0, 5), Vector2(width, 11))
	canvas.draw_rect(Rect2(rect.position + Vector2(-4, 2), Vector2(6, 9)), PAPER_EDGE)
	canvas.draw_rect(Rect2(rect.end - Vector2(2, 9), Vector2(6, 9)), PAPER_EDGE)
	canvas.draw_rect(rect, Color("#f6e8c4"))
	canvas.draw_rect(rect, INK_SOFT, false, 1.0)
	canvas.draw_string(font, Vector2(rect.position.x + 5, rect.position.y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


## The player's face as a map pin.
static func player_pin(canvas: CanvasItem, at: Vector2, t: float) -> void:
	var bob := floorf(sin(t * 4.0) * 1.5)
	var pin := at + Vector2(0, -9 + bob)
	canvas.draw_circle(at, 2.5, Color(0, 0, 0, 0.25))
	canvas.draw_circle(pin, 7.0, INK)
	canvas.draw_circle(pin, 6.0, Color("#f6e8c4"))
	canvas.draw_texture_rect_region(_face(), Rect2(pin - Vector2(5, 5), Vector2(10, 10)), Rect2(3, 2, 10, 10))
	canvas.draw_colored_polygon(PackedVector2Array([pin + Vector2(-3, 5), pin + Vector2(3, 5), at + Vector2(0, -1)]), INK)


static func _face() -> Texture2D:
	return preload("res://assets/sprites/player.png")


## Little icons for things on the area map.
static func icon(canvas: CanvasItem, kind: String, at: Vector2, t: float, lit := false) -> void:
	match kind:
		"gate":
			canvas.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), INK)
			canvas.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 7)), Color("#7bc043") if lit else INK_SOFT)
			canvas.draw_rect(Rect2(at + Vector2(-1, -1), Vector2(2, 5)), INK)
		"back":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(1, -4), at + Vector2(1, 4)]), INK_SOFT)
			canvas.draw_rect(Rect2(at + Vector2(1, -1.5), Vector2(4, 3)), INK_SOFT)
		"chest":
			canvas.draw_rect(Rect2(at - Vector2(4, 3), Vector2(8, 6)), INK)
			canvas.draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 4)), Color("#c08a3a"))
			canvas.draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), GOLD)
		"generator":
			var glow := 0.5 + 0.5 * sin(t * 3.0) if lit else 0.0
			if lit:
				canvas.draw_circle(at, 7.0, Color(1.0, 0.85, 0.3, 0.25 + 0.2 * glow))
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(1, -5), at + Vector2(-3, 1), at + Vector2(0, 1), at + Vector2(-1, 5), at + Vector2(3, -1), at + Vector2(0, -1)]), GOLD if lit else INK_SOFT)
		"repair":
			canvas.draw_circle(at, 4.0, INK)
			canvas.draw_circle(at, 1.5, PAPER)
			for spoke in 6:
				canvas.draw_rect(Rect2(at + Vector2.from_angle(spoke * TAU / 6.0) * 4.0 - Vector2(1, 1), Vector2(2, 2)), INK)
		"terminal":
			canvas.draw_rect(Rect2(at - Vector2(4, 3), Vector2(8, 6)), INK)
			canvas.draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 3)), Color("#5fb0a0"))
		"errand":
			var hop := floorf(sin(t * 5.0) * 1.5)
			canvas.draw_circle(at + Vector2(0, hop), 5.0, GOLD)
			canvas.draw_rect(Rect2(at + Vector2(-1, -3 + hop), Vector2(2, 4)), INK)
			canvas.draw_rect(Rect2(at + Vector2(-1, 2 + hop), Vector2(2, 1)), INK)
		"objective":
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			canvas.draw_arc(at, 5.0 + 2.0 * pulse, 0.0, TAU, 16, RED, 1.5)
			canvas.draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), RED, 1.5)
			canvas.draw_line(at + Vector2(-3, 3), at + Vector2(3, -3), RED, 1.5)


static func compass(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_circle(at, 9.0, Color(PAPER_DARK.r, PAPER_DARK.g, PAPER_DARK.b, 0.6))
	canvas.draw_arc(at, 9.0, 0.0, TAU, 20, INK_SOFT, 1.0)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -8), at + Vector2(-2.5, 0), at + Vector2(2.5, 0)]), RED)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, 8), at + Vector2(-2.5, 0), at + Vector2(2.5, 0)]), INK)
	canvas.draw_string(UiTheme.FONT_FILE, at + Vector2(-2, -11), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)


static func _hash(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)
