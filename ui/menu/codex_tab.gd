class_name CodexTab
extends MenuTab
## Everything you have learned so far, collected like a field guide. Each
## lesson unlocks the first time you meet it (sorting an item, testing water),
## and the undiscovered ones wait as ???. Finishing the guide earns rewards.

const SEEN_FLAG_FORMAT := "lesson_seen_%s"

var _header: Label
var _progress: Meter
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_build()


## Lesson ids in a stable order, discovered ones first.
func lesson_ids() -> Array[String]:
	var found: Array[String] = []
	var unknown: Array[String] = []
	for lesson in Content.all_lessons():
		(found if is_discovered(lesson["id"]) else unknown).append(lesson["id"])
	return found + unknown


static func is_discovered(lesson_id: String) -> bool:
	return GameState.has_flag(SEEN_FLAG_FORMAT % lesson_id)


static func discovered_count() -> int:
	return GameState.count_flags_with_prefix("lesson_seen_")


func refresh() -> void:
	if _list == null:
		return
	var total := Content.all_lessons().size()
	var count := discovered_count()
	_header.text = "FIELD GUIDE   %d of %d lessons discovered" % [count, total]
	_progress.ratio = float(count) / float(maxi(total, 1))
	for child in _list.get_children():
		child.queue_free()
	for lesson_id in lesson_ids():
		_list.add_child(_card(lesson_id))


func tab_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 28
	elif event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= 28
	else:
		return false
	return true


func _card(lesson_id: String) -> Control:
	var known := is_discovered(lesson_id)
	var lesson := Content.lesson(lesson_id)
	var panel := PanelContainer.new()
	var style := UiTheme.card_style(UiTheme.COLOR_TEAL)
	style.border_color = UiTheme.COLOR_TEAL if known else Color("#2a3a44")
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	if not known:
		var hidden := _label("???   Keep sorting and exploring to discover this one.", Color("#4a5a64"))
		hidden.custom_minimum_size = Vector2(380, 0)
		box.add_child(hidden)
		return panel
	box.add_child(_label(lesson["title"], UiTheme.COLOR_TEAL))
	var principle := _label(lesson["principle"], UiTheme.COLOR_TEXT)
	principle.custom_minimum_size = Vector2(380, 0)
	box.add_child(principle)
	var tip := _label("In real life: %s" % lesson["real_life"], UiTheme.COLOR_YELLOW)
	tip.custom_minimum_size = Vector2(380, 0)
	box.add_child(tip)
	return panel


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_header = _label("", UiTheme.COLOR_ORANGE)
	_header.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_header)
	_progress = Meter.new()
	_progress.custom_minimum_size = Vector2(0, 5)
	_progress.fill_color = UiTheme.COLOR_TEAL
	column.add_child(_progress)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(410, 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	_scroll.add_child(_list)
