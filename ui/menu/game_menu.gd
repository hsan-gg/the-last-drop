class_name GameMenu
extends OverlayPanel
## The pause menu, in tabs: Inventory, Quests, Map, Options and Controls. Esc
## opens it; I, Q and M open it on their tab; Tab cycles the tabs. On the
## title screen it shows only Options and Controls.

const INVENTORY := "inventory"
const QUESTS := "quests"
const MAP := "map"
const CODEX := "codex"
const OPTIONS := "options"
const CONTROLS := "controls"
const ALL_TABS: Array[Dictionary] = [
	{"id": INVENTORY, "label": "ITEMS"},
	{"id": QUESTS, "label": "QUESTS"},
	{"id": CODEX, "label": "CODEX"},
	{"id": MAP, "label": "MAP"},
	{"id": OPTIONS, "label": "OPTIONS"},
	{"id": CONTROLS, "label": "KEYS"},
]

## The title screen shows Options and Controls only, and never pauses.
var title_mode := false

var _tab_ids: Array[String] = []
var _tab_buttons: Array[Button] = []
var _tabs: Array[MenuTab] = []
var _index := 0
var _content: MarginContainer
var _built := false


func _ready() -> void:
	layer = 40
	_build_shell(Vector2(468, 254), UiTheme.COLOR_TEAL)
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 3)
	_box.add_child(bar)
	_content = MarginContainer.new()
	_content.custom_minimum_size = Vector2(448, 190)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_content)
	for entry in ALL_TABS:
		if title_mode and entry["id"] not in [OPTIONS, CONTROLS]:
			continue
		var tab := _make_tab(entry["id"])
		tab.visible = false
		_content.add_child(tab)
		_tabs.append(tab)
		_tab_ids.append(entry["id"])
		var button := Button.new()
		button.text = entry["label"]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_switch.bind(_tabs.size() - 1))
		bar.add_child(button)
		_tab_buttons.append(button)
	var footer := HBoxContainer.new()
	_box.add_child(footer)
	var hint := _label("Esc: close   Tab: next page", UiTheme.COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	if not title_mode:
		var quit := Button.new()
		quit.text = "QUIT TO TITLE"
		quit.focus_mode = Control.FOCUS_NONE
		quit.pressed.connect(_quit_to_title)
		footer.add_child(quit)
	var resume := Button.new()
	resume.text = "RESUME"
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(close)
	footer.add_child(resume)
	_switch(0)


func current_tab_id() -> String:
	return _tab_ids[_index] if _index < _tab_ids.size() else ""


func tab(tab_id: String) -> MenuTab:
	var index := _tab_ids.find(tab_id)
	return _tabs[index] if index >= 0 else null


func is_open() -> bool:
	return visible


func open(tab_id: String = "") -> void:
	_ensure_built()
	if not tab_id.is_empty() and _tab_ids.has(tab_id):
		_switch(_tab_ids.find(tab_id))
	elif visible:
		return
	if not visible:
		_show_panel()
		_tabs[_index].refresh()


func close() -> void:
	if visible:
		_hide_panel()
		Settings.save()


func toggle(tab_id: String = "") -> void:
	if visible and (tab_id.is_empty() or tab_id == current_tab_id()):
		close()
	elif visible:
		_switch(_tab_ids.find(tab_id))
	elif title_mode or not get_tree().paused:
		open(tab_id)


func next_tab() -> void:
	_switch((_index + 1) % _tabs.size())


func _switch(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_index = index
	for tab_index in _tabs.size():
		_tabs[tab_index].visible = tab_index == index
		_tab_buttons[tab_index].add_theme_color_override("font_color", UiTheme.COLOR_YELLOW if tab_index == index else UiTheme.COLOR_TEXT)
	_tabs[index].refresh()


func _make_tab(tab_id: String) -> MenuTab:
	match tab_id:
		INVENTORY:
			return InventoryTab.new()
		QUESTS:
			return QuestsTab.new()
		CODEX:
			return CodexTab.new()
		MAP:
			return MapTab.new()
		OPTIONS:
			return OptionsTab.new()
	return ControlsTab.new()


func _quit_to_title() -> void:
	close()
	SceneManager.go_to_title()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _tabs[_index].is_capturing():
		if _tabs[_index].tab_input(event):
			get_viewport().set_input_as_handled()
		return
	var hotkeys := {"equipment": INVENTORY, "journal": QUESTS, "map": MAP}
	if not title_mode:
		for action: String in hotkeys:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				toggle(hotkeys[action])
				return
	if event.is_action_pressed("menu") and (visible or not get_tree().paused):
		get_viewport().set_input_as_handled()
		toggle()
		return
	if not visible or _just_opened():
		return
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_page_down"):
		get_viewport().set_input_as_handled()
		next_tab()
	elif _tabs[_index].tab_input(event):
		get_viewport().set_input_as_handled()
