extends Node
## Player options, saved to user://settings.cfg: audio levels, display, the
## gameplay and accessibility toggles, and remapped keys. Applying a value
## takes effect at once, so the options menu needs no "apply" button.

signal changed(key: String)

const DEFAULT_PATH := "user://settings.cfg"
const DEFAULTS := {
	"master": 1.0,
	"music": 0.6,
	"sfx": 0.9,
	"muted": false,
	"fullscreen": false,
	"screen_shake": true,
	"reduce_flashing": false,
	"damage_numbers": true,
	"objective_hints": 1,
	"text_speed": 1,
	"difficulty": "medium",
	"tips": true,
	"tips_seen": "",
	"touch_controls": 0,
	"touch_size": 1,
	"touch_opacity": 0.6,
	"touch_left_handed": false,
	"vibration": true,
	"battery_saver": false,
}
const HINTS_OFF := 0
const HINTS_SUBTLE := 1
const HINTS_STRONG := 2
const TEXT_SPEEDS: Array[float] = [0.6, 1.0, 1.8]
const BATTERY_SAVER_FPS := 30
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## Actions the player can rebind, in the order the controls tab lists them.
const REBINDABLE: Array[String] = [
	"move_up", "move_down", "move_left", "move_right", "attack", "block",
	"interact", "tracker", "equipment", "journal", "map", "quick_heal", "quick_drink", "rune_1", "rune_2", "rune_3",
]

var path := DEFAULT_PATH

var _values: Dictionary = DEFAULTS.duplicate()
var _keys: Dictionary = {}
var _default_keys: Dictionary = {}


func _ready() -> void:
	_remember_default_keys()
	_ensure_buses()
	load_settings()
	apply_all()


func value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, new_value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	_values[key] = new_value
	_apply(key)
	save()
	changed.emit(key)


func text_speed_multiplier() -> float:
	return TEXT_SPEEDS[clampi(int(value("text_speed")), 0, TEXT_SPEEDS.size() - 1)]


func apply_audio() -> void:
	for key in ["master", "muted", "music", "sfx"]:
		_apply(key)


func apply_all() -> void:
	for key: String in DEFAULTS:
		_apply(key)
	for action: String in _keys:
		_apply_key(action, _keys[action])


# ------------------------------------------------------------------ controls

## A readable name for the key bound to an action ("W", "Space", "Tab").
func key_label(action: String) -> String:
	if TouchControls.active:
		return TouchControls.label_for(action)
	var code := key_for(action)
	return OS.get_keycode_string(code) if code != 0 else "(unbound)"


func key_for(action: String) -> int:
	if _keys.has(action):
		return _keys[action]
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode if key.physical_keycode != 0 else key.keycode
	return 0


## Binds a keyboard key to an action. A key already used by another rebindable
## action is swapped onto the old one, so no two actions ever share a key.
func rebind(action: String, physical_keycode: int) -> void:
	if not REBINDABLE.has(action) or physical_keycode == 0:
		return
	var previous := key_for(action)
	for other in REBINDABLE:
		if other != action and key_for(other) == physical_keycode:
			_keys[other] = previous
			_apply_key(other, previous)
	_keys[action] = physical_keycode
	_apply_key(action, physical_keycode)
	save()
	changed.emit("controls")


func reset_controls() -> void:
	_keys.clear()
	for action: String in _default_keys:
		_apply_key(action, _default_keys[action])
	save()
	changed.emit("controls")


func reset_all() -> void:
	_values = DEFAULTS.duplicate()
	apply_all()
	reset_controls()
	changed.emit("all")


# ------------------------------------------------------------------ files

func save() -> void:
	var file := ConfigFile.new()
	for key: String in _values:
		file.set_value("options", key, _values[key])
	for action: String in _keys:
		file.set_value("keys", action, _keys[action])
	file.save(path)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: String in DEFAULTS:
		if file.has_section_key("options", key):
			_values[key] = file.get_value("options", key)
	if file.has_section("keys"):
		for action: String in file.get_section_keys("keys"):
			if REBINDABLE.has(action):
				_keys[action] = int(file.get_value("keys", action))


# ------------------------------------------------------------------ applying

func _apply(key: String) -> void:
	match key:
		"master", "muted":
			var db := linear_to_db(maxf(float(value("master")), 0.0001))
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), bool(value("muted")) or float(value("master")) <= 0.001)
		"music":
			_set_bus_volume(MUSIC_BUS, float(value("music")))
		"sfx":
			_set_bus_volume(SFX_BUS, float(value("sfx")))
		"fullscreen":
			# The phone app is always fullscreen (status and navigation bars hidden);
			# the option is for desktop and browser windows.
			if OS.has_feature("mobile"):
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			elif DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)
		"screen_shake":
			Juicee.accessibility.no_screenshake = not bool(value("screen_shake"))
		"reduce_flashing":
			Juicee.accessibility.no_flash = bool(value("reduce_flashing"))
		"battery_saver":
			# 30 frames a second halves the work: cooler phones, longer batteries.
			Engine.max_fps = BATTERY_SAVER_FPS if bool(value("battery_saver")) else 0


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)


func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _remember_default_keys() -> void:
	for action in REBINDABLE:
		if InputMap.has_action(action):
			_default_keys[action] = key_for(action)


func _apply_key(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)
