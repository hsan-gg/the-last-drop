class_name ObjectiveTracker
extends Control
## The task list, out of the way until you want it. Press Tab to show or hide it;
## it also slides in for a few seconds whenever the objective changes.

const AUTO_SHOW_SECONDS := 5.0
const MAX_SIDE_QUESTS := 3
const PANEL_WIDTH := 178.0

var _panel: PanelContainer
var _body: RichTextLabel
var _chip: Label
var _shown := false
var _auto_timer := 0.0
var _hud: Hud


func _ready() -> void:
	_hud = get_parent() as Hud
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.counter_changed.connect(refresh.unbind(2))
	EventBus.quest_completed.connect(refresh.unbind(1))
	refresh()


func is_shown() -> bool:
	return _shown


func toggle() -> void:
	_shown = not _shown
	_auto_timer = 0.0
	_apply()


## Shows the list briefly, e.g. when the objective changes.
func flash() -> void:
	_auto_timer = AUTO_SHOW_SECONDS
	_apply()


func refresh() -> void:
	if _body != null:
		_body.text = text_for(_hud.area_id if _hud != null else "outpost")


## The tracker text: the main objective, then the side quests in progress here.
func text_for(area: String) -> String:
	var lines: Array[String] = []
	var goal := ObjectivesTracker.current(area)
	lines.append("[color=#f08a24]OBJECTIVE[/color]")
	lines.append(goal.get("text", "Look for the way on.") if not goal.is_empty() else "Look for the way on.")
	var open: Array[Dictionary] = []
	for quest in QuestRules.visible_quests():
		if quest["area"] == area and not QuestRules.is_done(quest["id"]):
			open.append(quest)
	if not open.is_empty():
		lines.append("")
		lines.append("[color=#5fd0c4]TASKS[/color]")
		var listed := 0
		for quest in QuestRules.sorted_by_difficulty(open):
			if listed >= MAX_SIDE_QUESTS:
				break
			var progress := QuestRules.progress(quest)
			lines.append("[color=%s]%s[/color] %s [color=#f2c94c]%d/%d[/color]" % [
				QuestRules.DIFFICULTY_COLORS[quest["difficulty"]], QuestRules.DIFFICULTY_TAGS[quest["difficulty"]],
				quest["title"], progress["current"], progress["target"]])
			listed += 1
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _auto_timer > 0.0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_apply()


func _apply() -> void:
	var visible_now := _shown or _auto_timer > 0.0
	refresh()
	_panel.visible = visible_now
	_chip.visible = not visible_now


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tracker"):
		get_viewport().set_input_as_handled()
		toggle()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.COLOR_ORANGE))
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
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
	_panel.add_child(_body)
	_chip = Label.new()
	_chip.text = "TAB  tasks"
	_chip.theme = UiTheme.get_theme()
	_chip.add_theme_font_size_override("font_size", 8)
	_chip.add_theme_color_override("font_color", Color(0.62, 0.69, 0.73, 0.7))
	_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_chip.offset_left = -72.0
	_chip.offset_right = -6.0
	_chip.offset_top = 6.0
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_chip)
