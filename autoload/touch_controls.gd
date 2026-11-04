extends CanvasLayer
## On-screen controls for phones and tablets.
##
## They appear once the screen is touched (or always / never, from Options),
## and hide again in "auto" when a real key is pressed. Out in the world they
## are a floating stick on the left half and a cluster of buttons on the right
## (sword, guard, use, the runes, a bandage and water, map, tasks and menu).
## Over a panel, a quiz, a puzzle or a conversation they become OK and Back,
## plus arrows or numbered keys when the open panel asks for them.
##
## Every button speaks the game's own language: it sends the same input
## actions and keys the keyboard does, so no screen needs a touch path of its
## own. Each finger is tracked separately, so you can walk, block and swing at
## once. While the controls are up the window also widens to the phone's shape
## and scales smoothly to fill it, and the mouse-click bindings of attack and
## block step aside (a tap anywhere would otherwise swing the sword).

signal active_changed(is_active: bool)

enum Mode { HIDDEN, PLAY, PANEL }

const AUTO := 0
const ALWAYS := 1
const NEVER := 2
## The key presses the buttons send come from "the keyboard" (the built-in ui_*
## actions only match keys from that device), and carry this mark so they are
## never mistaken for a real keyboard being picked up.
const KEYBOARD_DEVICE := 16
const SENT_BY_TOUCH := &"sent_by_touch"
const STICK_RADIUS := 24.0
const STICK_TOP_MARGIN := 34.0
const SIZES: Array[float] = [0.85, 1.0, 1.2]
const MOUSE_FREE_ACTIONS: Array[String] = ["attack", "block"]
const TAP_BUZZ_MS := 12
## Buttons whose action already makes a sound (a swing, a guard, a rune, a
## bandage); every other button clicks like the menu buttons do.
const SOUNDS_OF_THEIR_OWN: Array[String] = ["attack", "block", "interact", "rune_1", "rune_2", "rune_3", "quick_heal", "quick_drink", "menu", "map"]
const HIT_BUZZ_MS := 60
## What a hint calls each action when it is a button rather than a key.
const LABELS := {
	"interact": "USE", "attack": "SWORD", "block": "GUARD", "tracker": "TASKS",
	"map": "MAP", "equipment": "MENU", "journal": "MENU", "menu": "MENU",
	"quick_heal": "+", "quick_drink": "WATER", "rune_1": "RUNE 1", "rune_2": "RUNE 2", "rune_3": "RUNE 3",
	"move_up": "STICK", "move_down": "STICK", "move_left": "STICK", "move_right": "STICK",
}

var active := false
var mode := Mode.HIDDEN
## The buttons on screen this frame: {id, kind ("action"/"key"), target, hold, label, icon, center, radius}.
var buttons: Array[Dictionary] = []

var _seen_touch := false
var _pad: TouchPad
var _held: Dictionary = {}  # finger index -> button id
var _held_buttons: Dictionary = {}  # button id -> button (as pressed)
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_offset := Vector2.ZERO
var _set_aside_events: Dictionary = {}  # action -> Array[InputEvent]
var _prompt := ""
var _insets := Vector4.ZERO
var _default_aspect := Window.CONTENT_SCALE_ASPECT_KEEP
var _default_stretch := Window.CONTENT_SCALE_STRETCH_INTEGER


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pad = TouchPad.new()
	_pad.controls = self
	add_child(_pad)
	var root := get_tree().root
	_default_aspect = root.content_scale_aspect
	_default_stretch = root.content_scale_stretch
	_seen_touch = DisplayServer.is_touchscreen_available()
	EventBus.prompt_changed.connect(func(text: String) -> void: _prompt = text)
	EventBus.player_hit.connect(_on_player_hit)
	Settings.changed.connect(_on_setting_changed)
	refresh_active()


## Whether the on-screen controls should be up, from the setting and from
## whether this device has been touched.
func refresh_active() -> void:
	var choice := int(Settings.value("touch_controls"))
	var want := choice == ALWAYS or (choice == AUTO and _seen_touch)
	if want == active:
		return
	active = want
	release_all()
	_set_mouse_bindings(not active)
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if active else _default_aspect
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL if active else _default_stretch
	active_changed.emit(active)


## The word a hint should use for an action: a button name on touch, else the key.
func label_for(action: String) -> String:
	return LABELS.get(action, action.to_upper())


## A key hint for the keyboard, or its wording for the on-screen buttons.
func hint(keyboard: String, touch: String) -> String:
	return touch if active else keyboard


func stick_vector() -> Vector2:
	return TouchStick.knob(_stick_offset, STICK_RADIUS * _scale()) if _stick_finger >= 0 else Vector2.ZERO


func stick_origin() -> Vector2:
	return _stick_origin if _stick_finger >= 0 else _stick_rest()


func is_held(button_id: String) -> bool:
	return _held_buttons.has(button_id)


func prompt_ready() -> bool:
	return not _prompt.is_empty()


func button_at(point: Vector2) -> Dictionary:
	for button in buttons:
		var reach: float = button["radius"] + 4.0
		if point.distance_to(button["center"]) <= reach:
			return button
	return {}


## Lets go of every held button and the stick (a panel opened, the app was put away).
func release_all() -> void:
	for finger: int in _held.keys():
		_release_finger(finger)
	_held.clear()
	_held_buttons.clear()
	_end_stick()


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.has_meta(SENT_BY_TOUCH):
		_on_real_key()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_finger_down(touch)
		else:
			_on_finger_up(touch)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _stick_finger:
		_stick_offset = drag.position - _stick_origin
		_apply_stick()
		get_viewport().set_input_as_handled()


func _on_finger_down(touch: InputEventScreenTouch) -> void:
	if not _seen_touch:
		_seen_touch = true
		refresh_active()
		_layout()
	if not active:
		return
	var button := button_at(touch.position)
	if not button.is_empty():
		_held[touch.index] = button["id"]
		_held_buttons[button["id"]] = button
		_press(button)
		get_viewport().set_input_as_handled()
	elif mode == Mode.PLAY and _stick_finger < 0 and _in_stick_zone(touch.position):
		_stick_finger = touch.index
		_stick_origin = touch.position
		_stick_offset = Vector2.ZERO
		get_viewport().set_input_as_handled()


func _on_finger_up(touch: InputEventScreenTouch) -> void:
	if _held.has(touch.index):
		_release_finger(touch.index)
		_held.erase(touch.index)
		get_viewport().set_input_as_handled()
	elif touch.index == _stick_finger:
		_end_stick()
		get_viewport().set_input_as_handled()


func _on_real_key() -> void:
	if int(Settings.value("touch_controls")) == AUTO and _seen_touch:
		_seen_touch = false
		refresh_active()


func _press(button: Dictionary) -> void:
	_buzz(TAP_BUZZ_MS)
	if not SOUNDS_OF_THEIR_OWN.has(button["id"]):
		EventBus.sfx_requested.emit("click")
	if button["kind"] == "action":
		_send_action(button["target"], true)
	else:
		_send_key(button["target"], true)


func _release_finger(finger: int) -> void:
	var id: String = _held.get(finger, "")
	var button: Dictionary = _held_buttons.get(id, {})
	_held_buttons.erase(id)
	if button.is_empty():
		return
	if button["kind"] == "action":
		_send_action(button["target"], false)
	else:
		_send_key(button["target"], false)


func _send_action(action: String, pressed: bool) -> void:
	Input.parse_input_event(action_event(action, pressed))


func _send_key(keycode: Key, pressed: bool) -> void:
	Input.parse_input_event(key_event(keycode, pressed))


## The event a button sends for an action.
static func action_event(action: String, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	event.set_meta(SENT_BY_TOUCH, true)
	return event


## The event a button sends for a key (Esc, the arrows, the numbers).
static func key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.device = KEYBOARD_DEVICE
	event.set_meta(SENT_BY_TOUCH, true)
	return event


func _apply_stick() -> void:
	var push := TouchStick.strengths(_stick_offset, STICK_RADIUS * _scale())
	for action: String in push:
		if push[action] > 0.0:
			Input.action_press(action, push[action])
		else:
			Input.action_release(action)


func _end_stick() -> void:
	if _stick_finger < 0:
		return
	_stick_finger = -1
	_stick_offset = Vector2.ZERO
	for action: String in TouchStick.MOVES:
		Input.action_release(action)


# ------------------------------------------------------------------ frame

func _process(_delta: float) -> void:
	var new_mode := _current_mode()
	if new_mode != mode:
		release_all()
		mode = new_mode
	_layout()
	_pad.visible = mode != Mode.HIDDEN
	_pad.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		press_back()


## Android's back button (or gesture) is the game's BACK: it closes the open
## panel or opens the pause menu, instead of quitting the app on the spot.
func press_back() -> void:
	Input.parse_input_event(key_event(KEY_ESCAPE, true))
	Input.parse_input_event(key_event(KEY_ESCAPE, false))


func _current_mode() -> Mode:
	if not active:
		return Mode.HIDDEN
	var tree := get_tree()
	if tree.current_scene == null:
		return Mode.HIDDEN
	if _any_visible("dialogue_ui") or _any_visible("cutscene_ui") or Modal.any_open(tree) or tree.paused:
		return Mode.PANEL
	if tree.get_first_node_in_group("player") != null:
		return Mode.PLAY
	return Mode.HIDDEN


func _any_visible(group: String) -> bool:
	for node in get_tree().get_nodes_in_group(group):
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
			return true
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return true
	return false


## The open panel that wants extra buttons (arrows, numbers), if any.
func _open_panel() -> Node:
	var best: Node = null
	var best_layer := -1000
	for node in get_tree().get_nodes_in_group("modal"):
		var shown := (node is CanvasLayer and (node as CanvasLayer).visible) or (node is CanvasItem and (node as CanvasItem).visible)
		if shown and node is CanvasLayer and (node as CanvasLayer).layer > best_layer:
			best = node
			best_layer = (node as CanvasLayer).layer
	return best


func _layout() -> void:
	buttons.clear()
	var view := get_viewport().get_visible_rect().size
	_insets = _safe_insets(view)
	var s := _scale()
	if mode == Mode.PLAY:
		_layout_play(view, s)
	elif mode == Mode.PANEL:
		_layout_panel(view, s)
	# A button that moved or vanished while held keeps its press until lifted.


## How far the screen's notch and rounded corners reach in, in game pixels
## (left, top, right, bottom). A browser already keeps the page clear of them;
## the Android app runs edge to edge and has to step around them itself.
func _safe_insets(view: Vector2) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window := Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	if window.size.x <= 0.0 or window.size.y <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := view / window.size
	return Vector4(
		maxf(safe.position.x - window.position.x, 0.0) * k.x,
		maxf(safe.position.y - window.position.y, 0.0) * k.y,
		maxf(window.end.x - safe.end.x, 0.0) * k.x,
		maxf(window.end.y - safe.end.y, 0.0) * k.y)


func _layout_play(view: Vector2, s: float) -> void:
	var right := func(dx: float, dy: float) -> Vector2: return _side(Vector2(view.x - dx * s, view.y - dy * s), view)
	_add("attack", "action", "attack", true, "", "sword", right.call(36, 38), 20 * s)
	_add("block", "action", "block", true, "", "shield", right.call(80, 22), 13 * s)
	_add("interact", "action", "interact", false, "USE", "", right.call(80, 62), 13 * s)
	var rune_spots := [Vector2(20, 80), Vector2(46, 88), Vector2(72, 100)]
	for slot in range(1, 4):
		if not Runes.in_slot(slot).is_empty():
			_add("rune_%d" % slot, "action", "rune_%d" % slot, true, "", "rune", right.call(rune_spots[slot - 1].x, rune_spots[slot - 1].y), 10 * s)
	_add("quick_heal", "action", "quick_heal", false, "", "bandage", right.call(116, 14), 8 * s)
	_add("quick_drink", "action", "quick_drink", false, "", "drop", right.call(136, 14), 8 * s)
	# Up top, left of the task list (which opens with a tap of its own).
	var top := func(dx: float) -> Vector2: return _side(Vector2(view.x - dx, 14 * s), view)
	_add("menu", "action", "menu", false, "", "bars", top.call(104 + 10 * s), 9 * s)
	_add("map", "action", "map", false, "", "map", top.call(104 + 32 * s), 9 * s)


func _layout_panel(view: Vector2, s: float) -> void:
	var panel := _open_panel()
	var right := func(dx: float, dy: float) -> Vector2: return _side(Vector2(view.x - dx * s, view.y - dy * s), view)
	var left := func(dx: float, dy: float) -> Vector2: return _side(Vector2(dx * s, view.y - dy * s), view)
	# OK is "interact", which every panel takes as confirm (Enter would be
	# swallowed by whichever menu button happens to hold the focus).
	_add("ok", "action", "interact", false, "OK", "", right.call(26, 28), 15 * s)
	var back_label := "SKIP" if _any_visible("cutscene_ui") else "BACK"
	if not _any_visible("dialogue_ui") or panel != null:
		_add("back", "key", KEY_ESCAPE, false, back_label, "", right.call(24, 68), 13 * s)
	if panel != null and bool(panel.get("touch_dpad")):
		_add("up", "key", KEY_UP, false, "", "up", left.call(36, 64), 11 * s)
		_add("down", "key", KEY_DOWN, false, "", "down", left.call(36, 20), 11 * s)
		_add("left", "key", KEY_LEFT, false, "", "left", left.call(14, 42), 11 * s)
		_add("right", "key", KEY_RIGHT, false, "", "right", left.call(58, 42), 11 * s)
	var digits := int(panel.get("touch_digits")) if panel != null and panel.get("touch_digits") != null else 0
	for i in digits:
		_add("digit_%d" % (i + 1), "key", KEY_1 + i, false, str(i + 1), "", right.call(22, 98 + 24 * i), 10 * s)


func _add(id: String, kind: String, target: Variant, hold: bool, label: String, icon: String, center: Vector2, radius: float) -> void:
	buttons.append({"id": id, "kind": kind, "target": target, "hold": hold, "label": label, "icon": icon, "center": center, "radius": radius})


## Mirrors a position for left-handed players, then steps it in from any notch.
func _side(point: Vector2, view: Vector2) -> Vector2:
	var placed := Vector2(view.x - point.x, point.y) if bool(Settings.value("touch_left_handed")) else point
	placed.x += _insets.x if placed.x < view.x / 2.0 else -_insets.z
	placed.y += _insets.y if placed.y < view.y / 2.0 else -_insets.w
	return placed


func _stick_rest() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	return _side(Vector2(50.0 * _scale(), view.y - 50.0 * _scale()), view)


func _in_stick_zone(point: Vector2) -> bool:
	var view := get_viewport().get_visible_rect().size
	if point.y < STICK_TOP_MARGIN:
		return false
	var on_left := point.x < view.x * 0.5
	return on_left != bool(Settings.value("touch_left_handed"))


func _scale() -> float:
	return SIZES[clampi(int(Settings.value("touch_size")), 0, SIZES.size() - 1)]


# ------------------------------------------------------------------ settings and feel

func _on_setting_changed(key: String) -> void:
	if key == "touch_controls":
		refresh_active()


func _on_player_hit(outcome: String, _damage: int) -> void:
	if active:
		_buzz(HIT_BUZZ_MS if outcome == "hit" else TAP_BUZZ_MS * 2)


func _buzz(ms: int) -> void:
	if bool(Settings.value("vibration")):
		Input.vibrate_handheld(ms)


## Takes the mouse-click bindings off attack and block while touch is on (an
## emulated click from every tap would swing the sword) and puts them back after.
func _set_mouse_bindings(enabled: bool) -> void:
	for action in MOUSE_FREE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if enabled:
			for event: InputEvent in _set_aside_events.get(action, []):
				InputMap.action_add_event(action, event)
			_set_aside_events.erase(action)
		else:
			var taken: Array = []
			for event in InputMap.action_get_events(action):
				if event is InputEventMouseButton:
					taken.append(event)
					InputMap.action_erase_event(action, event)
			_set_aside_events[action] = taken
