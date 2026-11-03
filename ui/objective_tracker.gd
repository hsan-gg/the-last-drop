class_name ObjectiveTracker
extends Control
## The task list, out of the way until you want it: press T to show or hide it.
## It never pops up by itself; when there is something new, the small "T tasks"
## chip in the corner shows a gentle "!" (like Stardew's journal) until you look.

## A manual show also fades after a while, so the list never lingers.
const MANUAL_SHOW_SECONDS := 10.0
const MAX_SIDE_QUESTS := 3
const PANEL_WIDTH := 178.0
const INK := "#f6ecd6"

var _panel: PanelContainer
var _body: RichTextLabel
var _chip: Label
var _auto_timer := 0.0
var _has_news := false
var _talking := false
var _hud: Hud


func _ready() -> void:
	_hud = get_parent() as Hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.counter_changed.connect(refresh.unbind(2))
	EventBus.quest_completed.connect(refresh.unbind(1))
	EventBus.dialogue_opened.connect(_set_talking.bind(true))
	EventBus.dialogue_finished.connect(_set_talking.bind(false).unbind(1))
	EventBus.dialogue_interrupted.connect(_set_talking.bind(false))
	Settings.changed.connect(_update_chip.unbind(1))
	refresh()


func is_shown() -> bool:
	return _auto_timer > 0.0


func toggle() -> void:
	_auto_timer = 0.0 if is_shown() else MANUAL_SHOW_SECONDS
	_has_news = false
	_apply()


## Something changed: show a quiet "!" on the chip instead of popping the list open.
func mark_new() -> void:
	_has_news = true
	_update_chip()


func has_news() -> bool:
	return _has_news


## The list steps aside while a conversation is open.
func _set_talking(talking: bool) -> void:
	_talking = talking
	_apply()


func refresh() -> void:
	if _body != null:
		_body.text = text_for(_hud.area_id if _hud != null else "outpost")


## The tracker text: the main objective, then the side quests in progress here.
func text_for(area: String) -> String:
	var lines: Array[String] = []
	var goal := ObjectivesTracker.current(area)
	lines.append("[img=9x9]%s[/img] [color=#f2b45a]OBJECTIVE[/color]" % QuestRules.icon_path("goal"))
	lines.append("[color=%s]%s[/color]" % [INK, goal.get("text", "Look for the way on.") if not goal.is_empty() else "Look for the way on."])
	var open: Array[Dictionary] = []
	for quest in QuestRules.visible_quests():
		if quest["area"] == area and not QuestRules.is_done(quest["id"]):
			open.append(quest)
	if not open.is_empty():
		lines.append("")
		lines.append("[color=#7fd0e8]TASKS[/color]")
		var listed := 0
		for quest in QuestRules.sorted_by_difficulty(open):
			if listed >= MAX_SIDE_QUESTS:
				break
			var progress := QuestRules.progress(quest)
			lines.append("[img=9x9]%s[/img] [color=%s]%s[/color]  [color=%s]%d/%d[/color]" % [
				QuestRules.icon_path(quest.get("category", "goal")), INK,
				quest["title"], QuestRules.DIFFICULTY_COLORS[quest["difficulty"]], progress["current"], progress["target"]])
			listed += 1
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _auto_timer > 0.0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_apply()


func _update_chip() -> void:
	_chip.text = "%s  tasks%s" % [Settings.key_label("tracker"), "  !" if _has_news else ""]
	_chip.add_theme_color_override("font_color", Color("#f2b45a") if _has_news else Color(0.62, 0.69, 0.73, 0.7))


func _apply() -> void:
	var visible_now := _auto_timer > 0.0 and not _talking
	refresh()
	_panel.visible = visible_now
	_chip.visible = not visible_now
	_update_chip()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tracker"):
		get_viewport().set_input_as_handled()
		toggle()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	var style := UiTheme.panel_style(Color("#f2b45a"))
	style.bg_color = Color(0.11, 0.1, 0.14, 0.95)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -PANEL_WIDTH - 6.0
	_panel.offset_right = -6.0
	_panel.offset_top = 6.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size = Vector2(PANEL_WIDTH - 16.0, 0)
	_body.add_theme_constant_override("line_separation", 3)
	_panel.add_child(_body)
	_chip = Label.new()
	_chip.text = "%s  tasks" % Settings.key_label("tracker")
	_chip.theme = UiTheme.get_theme()
	_chip.add_theme_font_size_override("font_size", 8)
	_chip.add_theme_color_override("font_color", Color(0.62, 0.69, 0.73, 0.7))
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.anchor_top = 0.0
	_chip.anchor_bottom = 0.0
	_chip.offset_left = -90.0
	_chip.offset_right = -6.0
	_chip.offset_top = 6.0
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_chip)
