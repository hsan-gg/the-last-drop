class_name ControlsTab
extends MenuTab
## Every key in the game, and a way to change them: click an action, press the
## new key. A key already in use swaps with the action that had it.

const ACTION_NAMES := {
	"move_up": "Move up", "move_down": "Move down", "move_left": "Move left", "move_right": "Move right",
	"attack": "Attack", "block": "Block / parry", "interact": "Interact",
	"tracker": "Tasks", "equipment": "Inventory", "journal": "Quests", "map": "Map",
	"quick_heal": "Bandage", "quick_drink": "Drink water",
}
const FIXED_KEYS := [
	["Menu / back", "Esc"],
	["Next menu page", "Tab or PgDn"],
	["Sort into bins", "1 to 4"],
	["Attack / block (mouse)", "left / right click"],
]
const NAME_WIDTH := 76
const KEY_WIDTH := 38

var _capturing := ""
var _buttons: Dictionary = {}
var _status: Label


func _ready() -> void:
	_build()
	Settings.changed.connect(_update_labels.unbind(1))


func refresh() -> void:
	_capturing = ""
	_update_labels()


func is_capturing() -> bool:
	return not _capturing.is_empty()


func begin_capture(action: String) -> void:
	_capturing = action
	_update_labels()


func tab_input(event: InputEvent) -> bool:
	if not is_capturing():
		return false
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return true
	if key.physical_keycode == KEY_ESCAPE:
		_capturing = ""
	else:
		Settings.rebind(_capturing, key.physical_keycode)
		_capturing = ""
	_update_labels()
	return true


func _update_labels() -> void:
	for action: String in _buttons:
		var button: Button = _buttons[action]
		button.text = "press a key..." if action == _capturing else Settings.key_label(action)
	_status.text = "Press the new key, or Esc to cancel." if is_capturing() else "Click an action to change its key."


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_status = _label("", UiTheme.COLOR_MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	for action in Settings.REBINDABLE:
		grid.add_child(_name_cell(ACTION_NAMES.get(action, action), UiTheme.COLOR_TEXT))
		var button := Button.new()
		button.custom_minimum_size = Vector2(KEY_WIDTH, 0)
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(begin_capture.bind(action))
		_buttons[action] = button
		grid.add_child(button)
	column.add_child(_label("ALSO", UiTheme.COLOR_TEAL))
	var fixed := GridContainer.new()
	fixed.columns = 2
	fixed.add_theme_constant_override("h_separation", 10)
	fixed.add_theme_constant_override("v_separation", 2)
	column.add_child(fixed)
	for pair in FIXED_KEYS:
		var name_cell := _name_cell(pair[0], UiTheme.COLOR_MUTED)
		name_cell.custom_minimum_size = Vector2(NAME_WIDTH * 1.5, 0)
		fixed.add_child(name_cell)
		fixed.add_child(_name_cell(pair[1], UiTheme.COLOR_YELLOW))
	var reset := Button.new()
	reset.text = "Reset keys to default"
	reset.add_theme_font_size_override("font_size", 8)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(Settings.reset_controls)
	column.add_child(reset)


func _name_cell(text: String, color: Color) -> Label:
	var cell := _label(text, color)
	cell.autowrap_mode = TextServer.AUTOWRAP_OFF
	cell.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return cell
