class_name MixGame
extends MiniGame
## Get the balance right: how much of each ingredient goes in (a compost heap,
## a filter bed, a fuel blend). Up/Down pick an ingredient, Left/Right change
## the amount, E tests it. A wrong mix explains what went wrong.

const ROW := 22.0
const BLOCK := Vector2(14, 12)

var ingredients: Array = []
var amounts: Dictionary = {}
var selected := 0


func _init() -> void:
	super()
	kind = "mix"


func _start(data: Dictionary) -> void:
	ingredients = data.get("ingredients", [])
	amounts.clear()
	for ingredient: Dictionary in ingredients:
		amounts[ingredient["id"]] = int(ingredient.get("start", 0))
	selected = 0
	_hint.text = "Up/Down choose   Left/Right amount   E test   Esc leave"


func _board_input(event: InputEvent) -> void:
	var step := arrow_step(event)
	if step.y != 0:
		selected = wrapi(selected + step.y, 0, ingredients.size())
		EventBus.sfx_requested.emit("ui_move")
	elif step.x != 0:
		var ingredient: Dictionary = ingredients[selected]
		amounts[ingredient["id"]] = clampi(int(amounts[ingredient["id"]]) + step.x, 0, int(ingredient.get("max", 6)))
		EventBus.sfx_requested.emit("dig" if step.x > 0 else "click")
	elif is_confirm(event):
		test_mix()


func set_amount(ingredient_id: String, amount: int) -> void:
	amounts[ingredient_id] = amount


func test_mix() -> void:
	var problems := MixRules.problems(_data.get("rules", []), amounts)
	if problems.is_empty():
		_win()
	else:
		_mistake(problems[0], 5.0)


func _draw_board() -> void:
	var origin := Vector2(10, 6)
	for index in ingredients.size():
		var ingredient: Dictionary = ingredients[index]
		var y := origin.y + index * ROW
		var picked := index == selected and _phase == Phase.PLAYING
		_text(Vector2(origin.x, y + 10), ("> " if picked else "  ") + str(ingredient.get("name", "")), UiTheme.COLOR_YELLOW if picked else UiTheme.COLOR_TEXT)
		var color := Color(ingredient.get("color", "#a08060"))
		for block in int(ingredient.get("max", 6)):
			var at := Vector2(190 + block * (BLOCK.x + 2), y)
			var full := block < int(amounts[ingredient["id"]])
			_board.draw_rect(Rect2(at, BLOCK), color if full else Color("#1a1a20"))
			_board.draw_rect(Rect2(at, BLOCK), color.darkened(0.4) if full else Color("#2a2a34"), false, 1.0)
	# The heap itself: layers stacked in the order of the list, so you see it build.
	var base := Vector2(_board.size.x - 60, _board.size.y - 10)
	var height := 0.0
	for ingredient: Dictionary in ingredients:
		var layer := float(amounts[ingredient["id"]]) * 3.0
		if layer <= 0.0:
			continue
		var width := 46.0 - height * 0.5
		_board.draw_rect(Rect2(base + Vector2(-width / 2.0, -height - layer), Vector2(width, layer)), Color(ingredient.get("color", "#a08060")))
		height += layer
	_board.draw_line(base + Vector2(-30, 0), base + Vector2(30, 0), Color("#5a4a30"), 2.0)
