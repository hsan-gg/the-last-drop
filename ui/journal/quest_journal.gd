class_name QuestJournal
extends OverlayPanel
## Press Q for the journal: the main goal and every side quest with its
## progress. Also shows a short banner whenever a side quest is completed.

const TOAST_SECONDS := 3.2

var _body: RichTextLabel
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	_build_shell(Vector2(420, 224))
	_box.add_child(_label("JOURNAL", UiTheme.COLOR_ORANGE))
	_body = _rich(150)
	_box.add_child(_body)
	_box.add_child(_label("Press Q to close", UiTheme.COLOR_MUTED))
	_build_toast()
	EventBus.quest_completed.connect(_on_quest_completed)


func toggle() -> void:
	if visible:
		_hide_panel()
	elif not get_tree().paused:
		refresh()
		_show_panel()


func refresh() -> void:
	_body.text = text_for(_area())


## The journal text for an area: main goal, then side quests with progress.
func text_for(area: String) -> String:
	var lines: Array[String] = []
	var goal := ObjectivesTracker.current(area)
	lines.append("[color=#f08a24]MAIN GOAL[/color]")
	lines.append(goal.get("text", "Nothing left here. Look for the way on.") if not goal.is_empty() else "Nothing left here. Look for the way on.")
	lines.append("")
	lines.append("[color=#5fd0c4]SIDE QUESTS[/color]")
	var here: Array[Dictionary] = []
	var done := 0
	var total := 0
	for quest in QuestRules.visible_quests():
		total += 1
		done += 1 if QuestRules.is_done(quest["id"]) else 0
		if quest["area"] == area:
			here.append(quest)
	if here.is_empty():
		lines.append("None here.")
	for quest in here:
		lines.append(_quest_line(quest))
	lines.append("")
	lines.append("[color=#9fb0bb]%d of %d side quests done[/color]" % [done, total])
	return "\n".join(lines)


func _quest_line(quest: Dictionary) -> String:
	if QuestRules.is_done(quest["id"]):
		return "[color=#7bc043]DONE[/color]  %s" % quest["title"]
	var progress := QuestRules.progress(quest)
	return "[color=#f2c94c]%d/%d[/color]  %s: %s" % [progress["current"], progress["target"], quest["title"], quest["text"]]


func _area() -> String:
	var hud := get_parent() as Hud
	return hud.area_id if hud != null else "outpost"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		toggle()


func _build_toast() -> void:
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 30
	add_child(toast_layer)
	_toast = PanelContainer.new()
	_toast.theme = UiTheme.get_theme()
	_toast.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.COLOR_GREEN))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 36.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	toast_layer.add_child(_toast)
	_toast_label = _label("", UiTheme.COLOR_TEXT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)


func _on_quest_completed(quest_id: String) -> void:
	var quest := _find(quest_id)
	if quest.is_empty():
		return
	var reward: Dictionary = quest.get("reward", {})
	var parts: Array[String] = []
	if reward.get("water", 0) > 0:
		parts.append("+%d water" % reward["water"])
	if reward.get("health", 0) > 0:
		parts.append("+%d health" % reward["health"])
	_toast_label.text = "QUEST COMPLETE\n%s\n%s" % [quest["title"], ", ".join(parts)]
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _find(quest_id: String) -> Dictionary:
	for quest: Dictionary in Content.quests():
		if quest["id"] == quest_id:
			return quest
	return {}
