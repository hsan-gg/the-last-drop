class_name DifficultyPicker
extends OverlayPanel
## Choose a difficulty before a run: Easy, Medium (the default), Hard or
## Hardcore. Each shows plainly what it changes, so nothing is hidden.

signal chosen(difficulty_id: String)

const SHOWN_KEYS := [
	["Zombie health", "enemy_hp", "x%.2f"], ["Zombie damage", "enemy_damage", "x%.2f"],
	["Zombie speed", "enemy_speed", "x%.2f"], ["Zombie packs", "spawn", "x%.2f"],
	["Mistake penalty", "penalty", "x%.2f"], ["Lives", "lives", "%d"],
	["XP", "xp", "x%.2f"], ["Thirst", "water_decay", "x%.2f"],
]

var _index := 1
var _buttons: Array[Button] = []
var _description: Label
var _stats: RichTextLabel
var _levels: Array = []


func _ready() -> void:
	layer = 45
	_levels = Difficulty.all()
	_build_shell(Vector2(440, 214), UiTheme.COLOR_ORANGE)
	_box.add_child(_label("CHOOSE YOUR DIFFICULTY", UiTheme.COLOR_ORANGE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_box.add_child(row)
	for index in _levels.size():
		var button := Button.new()
		button.text = _levels[index]["name"]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 24)
		button.add_theme_color_override("font_color", Color(_levels[index]["color"]))
		button.pressed.connect(confirm.bind(index))
		button.mouse_entered.connect(select.bind(index))
		_buttons.append(button)
		row.add_child(button)
	_description = _label("", UiTheme.COLOR_TEXT)
	_description.custom_minimum_size = Vector2(0, 40)
	_box.add_child(_description)
	_stats = _rich(70)
	_box.add_child(_stats)
	_box.add_child(_label("Left / Right: choose   E or Enter: start   Esc: back", UiTheme.COLOR_MUTED))
	select(_levels.find(Difficulty.definition(str(Settings.value("difficulty")))) if not Difficulty.definition(str(Settings.value("difficulty"))).is_empty() else 1)


func open_picker() -> void:
	_show_panel()
	select(_index)


func selected_id() -> String:
	return _levels[_index]["id"]


func select(index: int) -> void:
	_index = clampi(index, 0, _levels.size() - 1)
	var level: Dictionary = _levels[_index]
	for button_index in _buttons.size():
		_buttons[button_index].add_theme_stylebox_override("normal", UiTheme.slot_style(button_index == _index))
	_description.text = level["description"]
	var lines: Array[String] = []
	for entry in SHOWN_KEYS:
		var value: float = float(level[entry[1]])
		lines.append("%s %s" % [entry[0], entry[2] % value])
	_stats.text = "[color=%s]%s[/color]   %s" % [level["color"], level["name"], "   ".join(lines)]


func confirm(index: int = -1) -> void:
	if index >= 0:
		select(index)
	_hide_panel()
	chosen.emit(selected_id())


func back() -> void:
	_hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _just_opened():
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		select(_index - 1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		select(_index + 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		confirm()
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		back()
