class_name CraftPanel
extends OverlayPanel
## The workbench: every recipe, what it needs (what you have of each), and
## what it makes. Up/Down choose, E makes it, Esc steps away.

var _list: VBoxContainer
var _detail: RichTextLabel
var _hint: Label
var _rows: Array[Label] = []
var _selected := 0
var _open := false


func _ready() -> void:
	touch_ok_label = "MAKE"
	in_world = true
	_build_shell(Vector2(440, 240), UiTheme.COLOR_YELLOW)
	_box.add_child(_label("WORKBENCH", UiTheme.COLOR_YELLOW))
	_add_health_row()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	_box.add_child(columns)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(170, 150)
	columns.add_child(_list)
	_detail = _rich(150)
	_detail.custom_minimum_size = Vector2(240, 150)
	columns.add_child(_detail)
	_hint = _label("Up/Down choose   E make   Esc leave", UiTheme.COLOR_MUTED)
	_box.add_child(_hint)
	EventBus.craft_requested.connect(open_bench)


func is_open() -> bool:
	return _open


func open_bench() -> void:
	_open = true
	_selected = 0
	_refresh()
	_show_panel()


func leave() -> void:
	if not _open:
		return
	_open = false
	_hide_panel()


func make_selected() -> bool:
	var recipes := RecipeBook.all()
	if recipes.is_empty():
		return false
	var recipe: Dictionary = recipes[_selected]
	if not RecipeBook.make(recipe):
		EventBus.sfx_requested.emit("sort_bad")
		return false
	EventBus.sfx_requested.emit("repair")
	EventBus.loot_found.emit("Made: %s" % RecipeBook.product_name(recipe))
	_refresh()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _open or _just_opened() or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		leave()
		return
	var step := MiniGame.arrow_step(event)
	if step.y != 0:
		_selected = wrapi(_selected + step.y, 0, RecipeBook.all().size())
		EventBus.sfx_requested.emit("ui_move")
		_refresh()
	elif MiniGame.is_confirm(event):
		make_selected()


## A tap picks a recipe; tapping the picked one makes it.
func tap_recipe(index: int) -> void:
	if index == _selected:
		make_selected()
		return
	_selected = index
	EventBus.sfx_requested.emit("ui_move")
	_refresh()


func _refresh() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	var recipes := RecipeBook.all()
	for index in recipes.size():
		var recipe: Dictionary = recipes[index]
		var ready := RecipeBook.can_make(recipe)
		var owned: bool = recipe["makes"].has("gear") and Gear.is_owned(recipe["makes"]["gear"])
		var color := UiTheme.COLOR_GREEN if ready else (UiTheme.COLOR_MUTED if not owned else Color("#5a6a70"))
		var row := _label(("> " if index == _selected else "  ") + RecipeBook.product_name(recipe) + ("  (made)" if owned else ""), color)
		make_tappable(row, tap_recipe.bind(index))
		_list.add_child(row)
		_rows.append(row)
	if recipes.is_empty():
		return
	var recipe: Dictionary = recipes[_selected]
	var text := "[color=#f2c94c]%s[/color]\n%s\n\n[color=#9fb0bb]NEEDS[/color]\n" % [RecipeBook.product_name(recipe), recipe.get("note", "")]
	var needs: Dictionary = recipe["needs"]
	for item_id: String in needs:
		var have := Inventory.count(item_id)
		var need := int(needs[item_id])
		text += "[color=%s]%s  %d / %d[/color]\n" % ["#7bc043" if have >= need else "#e0584a", ItemDB.display_name(item_id), have, need]
	_detail.text = text
