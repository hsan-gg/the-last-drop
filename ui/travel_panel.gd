class_name TravelPanel
extends OverlayPanel
## The rail cart network: once a region's lights are on, its cart can take you
## to any other lit region you have been to. Pick a stop with the arrow keys or
## the number keys; Esc stays put.

const ORDER: Array[String] = ["outpost", "factory", "dump", "river", "fields", "industry", "sanctuary"]
const NAMES := {"outpost": "Forgotten Outpost", "factory": "Battery Factory", "dump": "Great Dump", "river": "Dead River",
	"fields": "Silent Fields", "industry": "Forgotten Industry", "sanctuary": "Last Sanctuary"}
const SCENE_FORMAT := "res://world/%s.tscn"
## The cart's map marker: you arrive next to the cart at your destination.
const CART_MARKER := "4"

var _here := ""
var _stops: Array[String] = []
var _index := 0
var _list: VBoxContainer


func _ready() -> void:
	_build_shell(Vector2(240, 190), UiTheme.COLOR_YELLOW)
	_box.add_child(_label("RAIL CART", UiTheme.COLOR_YELLOW))
	_box.add_child(_label("Where to? Only lit regions have power for the cart.", UiTheme.COLOR_MUTED))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_box.add_child(_list)
	_box.add_child(_label("Up/Down or 1-7: choose   E: go   Esc: stay", UiTheme.COLOR_MUTED))


## The regions the cart can reach from `here`: lit, visited, and not here.
static func stops_from(here: String) -> Array[String]:
	var stops: Array[String] = []
	for area_id in ORDER:
		if area_id != here and MapMemory.has_visited(area_id) and GameState.has_flag(RegionGenerator.lit_flag(area_id)):
			stops.append(area_id)
	return stops


func open_from(here: String) -> void:
	_here = here
	_stops = stops_from(here)
	_index = 0
	_refresh()
	_show_panel()


func travel(area_id: String) -> void:
	if not _stops.has(area_id):
		return
	_hide_panel()
	EventBus.sfx_requested.emit("click")
	SceneManager.arrival_marker = CART_MARKER
	SceneManager.change_scene(SCENE_FORMAT % area_id)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	if _stops.is_empty():
		_list.add_child(_label("No other region has power yet.", UiTheme.COLOR_TEXT))
		return
	for i in _stops.size():
		var chosen := i == _index
		var line := _label("%s %d  %s" % [">" if chosen else " ", i + 1, NAMES.get(_stops[i], _stops[i])], UiTheme.COLOR_YELLOW if chosen else UiTheme.COLOR_TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		_list.add_child(line)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _just_opened():
		return
	var key := event as InputEventKey
	if event.is_action_pressed("ui_up") and not _stops.is_empty():
		_index = posmod(_index - 1, _stops.size())
		_refresh()
	elif event.is_action_pressed("ui_down") and not _stops.is_empty():
		_index = posmod(_index + 1, _stops.size())
		_refresh()
	elif (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")) and not _stops.is_empty():
		travel(_stops[_index])
	elif event.is_action_pressed("menu"):
		_hide_panel()
	elif key != null and key.pressed and key.keycode >= KEY_1 and key.keycode <= KEY_7:
		var pick := key.keycode - KEY_1
		if pick < _stops.size():
			travel(_stops[pick])
	else:
		return
	get_viewport().set_input_as_handled()
