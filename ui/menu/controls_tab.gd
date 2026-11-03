class_name ControlsTab
extends MenuTab
## Every key in the game, and a way to change them: click an action, press the
## new key. A key already in use swaps with the action that had it.

const ACTION_NAMES := {
	"move_up": "Move up", "move_down": "Move down", "move_left": "Move left", "move_right": "Move right",
	"attack": "Attack with the sword", "block": "Block (hold) / parry", "interact": "Interact, continue",
	"tracker": "Show or hide tasks", "equipment": "Inventory", "journal": "Quests", "map": "Map",
	"quick_heal": "Use a bandage", "quick_drink": "Drink purified water",
}
const FIXED_KEYS := [
	["Attack / block", "left / right mouse button"],
	["Open the menu", "Esc"],
	["Switch menu tab", "Tab"],
	["Sort waste", "1 to 4"],
	["Leave a puzzle", "Esc"],
]

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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	_status = _label("", UiTheme.COLOR_MUTED)
	list.add_child(_status)
	for action in Settings.REBINDABLE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := _label(ACTION_NAMES.get(action, action))
		label.custom_minimum_size = Vector2(200, 0)
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 0)
		button.pressed.connect(begin_capture.bind(action))
		_buttons[action] = button
		row.add_child(button)
		list.add_child(row)
	list.add_child(_label("FIXED", UiTheme.COLOR_TEAL))
	for pair in FIXED_KEYS:
		var row := HBoxContainer.new()
		var name_label := _label(pair[0], UiTheme.COLOR_MUTED)
		name_label.custom_minimum_size = Vector2(200, 0)
		row.add_child(name_label)
		row.add_child(_label(pair[1], UiTheme.COLOR_MUTED))
		list.add_child(row)
	var reset := Button.new()
	reset.text = "Reset keys to default"
	reset.pressed.connect(Settings.reset_controls)
	list.add_child(reset)
