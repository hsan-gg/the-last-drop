class_name InventoryTab
extends MenuTab
## The inventory board, Stardew style: your character and what they wear on the
## left, a grid of everything you carry on the right. Arrows move, E or a click
## wears or uses the selected item.

const COLUMNS := 8
const ROWS := 5
const SLOT_SIZE := 24
const SLOT_ORDER := ["weapon", "head", "body"]
const SLOT_NAMES := {"weapon": "WEAPON", "head": "HEAD", "body": "BODY"}
const RARITY_COLORS := {"common": "#c8d0d8", "uncommon": "#7bc043", "rare": "#4aa8ff", "epic": "#f2a030"}

var _entries: Array[Dictionary] = []
var _cursor := 0
var _slots: Array[Button] = []
var _counts: Array[Label] = []
var _worn_buttons: Dictionary = {}
var _stats: RichTextLabel
var _detail: RichTextLabel
var _portrait: TextureRect


func _ready() -> void:
	_build()
	EventBus.gear_changed.connect(refresh)
	EventBus.inventory_changed.connect(refresh)


func entries() -> Array[Dictionary]:
	return _entries.duplicate()


func cursor() -> int:
	return _cursor


## Everything carried, in grid order: gear (weapons, head, body; strongest first),
## then consumables, then materials.
func build_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for slot in SLOT_ORDER:
		var owned := Gear.owned_in_slot(slot)
		owned.sort_custom(func(a: String, b: String) -> bool: return _power(a) > _power(b))
		for gear_id in owned:
			if gear_id != Gear.FISTS:
				list.append({"kind": "gear", "id": gear_id, "count": 1})
	var counts := Inventory.snapshot()
	var consumables: Array[String] = []
	var materials: Array[String] = []
	for item_id: String in counts:
		(consumables if ItemDB.is_consumable(item_id) else materials).append(item_id)
	consumables.sort()
	materials.sort()
	for item_id in consumables + materials:
		list.append({"kind": "item", "id": item_id, "count": counts[item_id]})
	return list


func refresh() -> void:
	if _stats == null:
		return
	_entries = build_entries()
	_cursor = clampi(_cursor, 0, maxi(_entries.size() - 1, 0))
	for index in _slots.size():
		_paint_slot(index)
	for slot: String in _worn_buttons:
		_paint_worn(slot)
	var damage := CombatRules.player_damage(Gear.weapon_damage(), Progress.level)
	_stats.text = "[color=#f2c94c]LEVEL %d[/color]  XP %d/%d\nHealth %d   Lives %d\nAttack %d   Defence %d" % [
		Progress.level, Progress.xp, Progress.xp_needed(), int(Survival.max_health()), Lives.lives, damage, Gear.armor()]
	_show_detail()


func select(index: int) -> void:
	_cursor = clampi(index, 0, maxi(_entries.size() - 1, 0))
	for slot_index in _slots.size():
		_paint_slot(slot_index)
	_show_detail()


func move_cursor(dx: int, dy: int) -> void:
	var column := _cursor % COLUMNS + dx
	var row := _cursor / COLUMNS + dy
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return
	select(row * COLUMNS + column)


## Wears gear, takes off worn gear, or uses a consumable. Returns what happened.
func activate(index: int = -1) -> String:
	var picked := _cursor if index < 0 else index
	if picked < 0 or picked >= _entries.size():
		return "none"
	var entry := _entries[picked]
	if entry["kind"] == "gear":
		var slot: String = Gear.definition(entry["id"])["slot"]
		if Gear.equipped(slot) == entry["id"]:
			if slot == "weapon":
				return "kept"
			Gear.unequip(slot)
			EventBus.sfx_requested.emit("click")
			return "unequipped"
		Gear.equip(entry["id"])
		EventBus.sfx_requested.emit("click")
		return "equipped"
	if ItemDB.is_consumable(entry["id"]):
		return "used" if Consumables.use(entry["id"]) else "unused"
	return "material"


func tab_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left"):
		move_cursor(-1, 0)
	elif event.is_action_pressed("ui_right"):
		move_cursor(1, 0)
	elif event.is_action_pressed("ui_up"):
		move_cursor(0, -1)
	elif event.is_action_pressed("ui_down"):
		move_cursor(0, 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		activate()
	else:
		return false
	return true


func _power(gear_id: String) -> int:
	var item := Gear.definition(gear_id)
	return int(item.get("damage", 0)) + int(item.get("armor", 0))


func _paint_slot(index: int) -> void:
	var button := _slots[index]
	var entry: Dictionary = _entries[index] if index < _entries.size() else {}
	var worn: bool = not entry.is_empty() and entry["kind"] == "gear" and Gear.equipped(Gear.definition(entry["id"])["slot"]) == entry["id"]
	button.add_theme_stylebox_override("normal", UiTheme.slot_style(index == _cursor, worn))
	button.add_theme_stylebox_override("hover", UiTheme.slot_style(true, worn))
	button.add_theme_stylebox_override("pressed", UiTheme.slot_style(true, worn))
	button.add_theme_stylebox_override("focus", UiTheme.slot_style(index == _cursor, worn))
	if entry.is_empty():
		button.icon = null
		_counts[index].text = ""
		return
	button.icon = Gear.icon(entry["id"]) if entry["kind"] == "gear" else ItemDB.icon(entry["id"])
	_counts[index].text = str(entry["count"]) if entry["count"] > 1 else ""


func _paint_worn(slot: String) -> void:
	var button: Button = _worn_buttons[slot]
	var gear_id := Gear.equipped(slot)
	button.icon = Gear.icon(gear_id) if not gear_id.is_empty() else null
	button.add_theme_stylebox_override("normal", UiTheme.slot_style(false, not gear_id.is_empty() and gear_id != Gear.FISTS))


func _show_detail() -> void:
	if _cursor >= _entries.size():
		_detail.text = "[color=#9fb0bb]Nothing here yet. Open chests, defeat zombies and sort waste.[/color]"
		return
	var entry := _entries[_cursor]
	if entry["kind"] == "gear":
		var item := Gear.definition(entry["id"])
		var stat := "Attack %d" % int(item["damage"]) if item.has("damage") else "Defence %d" % int(item["armor"])
		var worn: bool = Gear.equipped(item["slot"]) == entry["id"]
		var action := "worn" if worn else TouchControls.hint("[E] wear", "tap again: wear")
		_detail.text = "[color=%s]%s[/color]  %s  [color=#9fb0bb](%s)[/color]\n[color=#9fb0bb]%s[/color]\n[color=#f2c94c]%s[/color]" % [RARITY_COLORS.get(item["rarity"], "#c8d0d8"), item["name"], stat, item["rarity"], item["description"], action]
		return
	var action_hint := TouchControls.hint("[E] use", "tap again: use") if ItemDB.is_consumable(entry["id"]) else ("Someone in another area needs this" if ItemDB.get_item(entry["id"]).get("category", "") == "keepsake" else "Material for repairs")
	var description := ItemDB.description(entry["id"])
	_detail.text = "[color=#e8eef2]%s[/color] x%d\n[color=#9fb0bb]%s[/color]\n[color=#f2c94c]%s[/color]" % [ItemDB.display_name(entry["id"]), entry["count"], description, action_hint]


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	left.add_child(_label("CHARACTER", UiTheme.COLOR_TEAL))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	left.add_child(body)
	_portrait = TextureRect.new()
	var frame := AtlasTexture.new()
	frame.atlas = PlayerSprite.SHEET
	frame.region = Rect2(0, 0, PlayerSprite.FRAME_WIDTH, PlayerSprite.SHEET.get_height() / PlayerSprite.DIRECTIONS.size())
	_portrait.texture = frame
	_portrait.custom_minimum_size = Vector2(48, 54)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(_portrait)
	var worn_column := VBoxContainer.new()
	worn_column.add_theme_constant_override("separation", 2)
	body.add_child(worn_column)
	for slot in SLOT_ORDER:
		var worn_row := HBoxContainer.new()
		worn_row.add_theme_constant_override("separation", 4)
		var button := Button.new()
		button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.expand_icon = true
		button.pressed.connect(_on_worn_pressed.bind(slot))
		_worn_buttons[slot] = button
		worn_row.add_child(button)
		var slot_name := _label(SLOT_NAMES[slot], UiTheme.COLOR_MUTED)
		slot_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		slot_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		worn_row.add_child(slot_name)
		worn_column.add_child(worn_row)
	_stats = _rich()
	left.add_child(_stats)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)
	right.add_child(_label("BACKPACK", UiTheme.COLOR_TEAL))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	right.add_child(grid)
	for index in COLUMNS * ROWS:
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_button.expand_icon = true
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.pressed.connect(_on_slot_pressed.bind(index))
		slot_button.mouse_entered.connect(select.bind(index))
		var count := Label.new()
		count.add_theme_font_size_override("font_size", 8)
		count.add_theme_color_override("font_outline_color", Color("#120a18"))
		count.add_theme_constant_override("outline_size", 3)
		count.position = Vector2(SLOT_SIZE - 10, SLOT_SIZE - 11)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(count)
		_slots.append(slot_button)
		_counts.append(count)
		grid.add_child(slot_button)
	_detail = _rich(40)
	right.add_child(_detail)


func _on_slot_pressed(index: int) -> void:
	select(index)
	activate(index)


func _on_worn_pressed(slot: String) -> void:
	if slot != "weapon" and not Gear.equipped(slot).is_empty():
		Gear.unequip(slot)
