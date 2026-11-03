class_name EquipmentPanel
extends OverlayPanel
## Press I: your level and stats, and the gear you own for each slot. Tab picks
## the slot, 1 to 6 (or a click) wears the item.

const RARITY_COLORS := {"common": "#c8d0d8", "uncommon": "#7bc043", "rare": "#4aa8ff", "epic": "#f2a030"}
const SLOT_LABELS := {"weapon": "WEAPON", "head": "HEAD", "body": "BODY"}
const MAX_LISTED := 6
const NUMBER_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]

var _slot_index := 0
var _stats: RichTextLabel
var _slot_title: Label
var _buttons: Array[Button] = []
var _listed: Array[String] = []


func _ready() -> void:
	_build_shell(Vector2(440, 214), UiTheme.COLOR_YELLOW)
	_box.add_child(_label("EQUIPMENT", UiTheme.COLOR_YELLOW))
	_stats = _rich(50)
	_box.add_child(_stats)
	_slot_title = _label("", UiTheme.COLOR_TEAL)
	_box.add_child(_slot_title)
	for index in MAX_LISTED:
		var button := _button("", _equip_listed.bind(index))
		_buttons.append(button)
		_box.add_child(button)
	_box.add_child(_label("Tab: next slot   1-6: wear   I: close", UiTheme.COLOR_MUTED))
	EventBus.gear_changed.connect(refresh)


func slot() -> String:
	return Gear.SLOTS[_slot_index]


func toggle() -> void:
	if visible:
		_hide_panel()
	elif not get_tree().paused:
		refresh()
		_show_panel()


func next_slot() -> void:
	_slot_index = (_slot_index + 1) % Gear.SLOTS.size()
	refresh()


func listed() -> Array[String]:
	return _listed.duplicate()


## Owned gear for the selected slot, strongest first, fists last.
func owned_for_slot(slot_name: String) -> Array[String]:
	var owned := Gear.owned_in_slot(slot_name)
	owned.sort_custom(func(a: String, b: String) -> bool:
		return _power(Gear.definition(a)) > _power(Gear.definition(b)))
	return owned


func refresh() -> void:
	if _stats == null:
		return
	var damage := CombatRules.player_damage(Gear.weapon_damage(), Progress.level)
	_stats.text = "[color=#f2c94c]LEVEL %d[/color]   XP %d / %d\nHealth %d   Attack %d   Defence %d\nWeapon: %s   Head: %s   Body: %s" % [
		Progress.level, Progress.xp, Progress.xp_needed(), int(Survival.max_health()), damage, Gear.armor(),
		_name_in(Gear.equipped("weapon")), _name_in(Gear.equipped("head")), _name_in(Gear.equipped("body"))]
	_slot_title.text = "%s  (%d owned)" % [SLOT_LABELS[slot()], owned_for_slot(slot()).size()]
	_listed = owned_for_slot(slot())
	if _listed.size() > MAX_LISTED:
		_listed.resize(MAX_LISTED)
	for index in _buttons.size():
		var button := _buttons[index]
		button.visible = index < _listed.size()
		if index < _listed.size():
			var item := Gear.definition(_listed[index])
			var worn := " [worn]" if Gear.equipped(slot()) == _listed[index] else ""
			button.text = "%d  %s  %s%s" % [index + 1, item["name"], _stat_text(item), worn]
			button.add_theme_color_override("font_color", Color(RARITY_COLORS.get(item.get("rarity", "common"), "#c8d0d8")))
	if _listed.is_empty():
		_slot_title.text += "  nothing yet: find chests, defeat zombies"


func equip_listed(index: int) -> void:
	if index >= 0 and index < _listed.size():
		Gear.equip(_listed[index])
		EventBus.sfx_requested.emit("click")


func _equip_listed(index: int) -> void:
	equip_listed(index)


func _name_in(gear_id: String) -> String:
	return Gear.definition(gear_id).get("name", "none") if not gear_id.is_empty() else "none"


func _stat_text(item: Dictionary) -> String:
	return "ATK %d" % item["damage"] if item.has("damage") else "DEF %d" % item["armor"]


func _power(item: Dictionary) -> int:
	return int(item.get("damage", 0)) + int(item.get("armor", 0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("equipment"):
		get_viewport().set_input_as_handled()
		toggle()
		return
	if not visible or _just_opened():
		return
	var key := event as InputEventKey
	if event.is_action_pressed("ui_focus_next"):
		get_viewport().set_input_as_handled()
		next_slot()
	elif key != null and key.pressed and not key.echo and NUMBER_KEYS.has(key.keycode):
		get_viewport().set_input_as_handled()
		equip_listed(NUMBER_KEYS.find(key.keycode))
