class_name QuestsTab
extends MenuTab
## The quest board: the main goal on top, then cards sorted easiest first, each
## with its difficulty bar, XP badge and progress. HERE, ALL and DONE filter the list.

enum Filter { HERE, ALL, DONE }

const FILTER_NAMES := ["HERE", "ALL", "DONE"]

var _filter := Filter.HERE
var _goal: RichTextLabel
var _list: VBoxContainer
var _scroll: ScrollContainer
var _summary: Label
var _filter_buttons: Array[Button] = []


func _ready() -> void:
	_build()


func filter() -> Filter:
	return _filter


func set_filter(value: Filter) -> void:
	_filter = value
	refresh()


func cycle_filter() -> void:
	set_filter(((_filter + 1) % FILTER_NAMES.size()) as Filter)


## The quests the current filter shows, easiest first.
func quests_to_show(area: String) -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for quest in QuestRules.visible_quests():
		var done := QuestRules.is_done(quest["id"])
		match _filter:
			Filter.HERE:
				if quest["area"] == area and not done:
					shown.append(quest)
			Filter.ALL:
				if not done:
					shown.append(quest)
			Filter.DONE:
				if done:
					shown.append(quest)
	return QuestRules.sorted_by_difficulty(shown)


func refresh() -> void:
	if _list == null:
		return
	var area := _area()
	var goal := ObjectivesTracker.current(area)
	_goal.text = "[color=#f08a24]MAIN GOAL[/color]  %s" % (goal.get("text", "Nothing left here. Look for the way on.") if not goal.is_empty() else "Nothing left here. Look for the way on.")
	for child in _list.get_children():
		child.queue_free()
	var shown := quests_to_show(area)
	if shown.is_empty():
		_list.add_child(_label("Nothing in this list yet.", UiTheme.COLOR_MUTED))
	for quest in shown:
		_list.add_child(_card(quest))
	var done := 0
	var total := 0
	for quest in QuestRules.visible_quests():
		total += 1
		done += 1 if QuestRules.is_done(quest["id"]) else 0
	_summary.text = "%d of %d side quests done" % [done, total]
	for index in _filter_buttons.size():
		_filter_buttons[index].add_theme_color_override("font_color", UiTheme.COLOR_YELLOW if index == _filter else UiTheme.COLOR_TEXT)


func tab_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 28
	elif event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= 28
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("interact"):
		cycle_filter()
	else:
		return false
	return true


func _area() -> String:
	var scene := get_tree().current_scene
	return (scene as GameArea).area_id if scene is GameArea else "outpost"


func _card(quest: Dictionary) -> Control:
	var difficulty: String = quest.get("difficulty", "easy")
	var color := Color(QuestRules.DIFFICULTY_COLORS[difficulty])
	var done := QuestRules.is_done(quest["id"])
	var panel := PanelContainer.new()
	var style := UiTheme.card_style(color)
	style.border_color = color if not done else Color("#2a4a2a")
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label(quest["title"], UiTheme.COLOR_TEXT if not done else Color("#7bc043"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label(QuestRules.DIFFICULTY_TAGS[difficulty], color))
	head.add_child(_label("  +%d XP" % int(quest.get("reward", {}).get("xp", 0)), Color("#9be04a")))
	box.add_child(_label(quest["text"], UiTheme.COLOR_MUTED))
	var progress := QuestRules.progress(quest)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	box.add_child(bar_row)
	var bar := Meter.new()
	bar.custom_minimum_size = Vector2(150, 5)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.ratio = 1.0 if done else float(progress["current"]) / float(maxi(progress["target"], 1))
	bar.fill_color = color
	bar_row.add_child(bar)
	bar_row.add_child(_label("DONE" if done else "%d/%d" % [progress["current"], progress["target"]], UiTheme.COLOR_YELLOW))
	return panel


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_goal = _rich()
	column.add_child(_goal)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	column.add_child(filters)
	for index in FILTER_NAMES.size():
		var button := Button.new()
		button.text = FILTER_NAMES[index]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(set_filter.bind(index as Filter))
		_filter_buttons.append(button)
		filters.add_child(button)
	_summary = _label("", UiTheme.COLOR_MUTED)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	filters.add_child(_summary)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	_scroll.add_child(_list)
