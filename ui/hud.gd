class_name Hud
extends CanvasLayer
## In-game overlay: survival meters, inventory, current objective, interaction
## prompt, and the dialogue and sorting screens.

const DIALOGUE_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")
const SORTING_SCENE := preload("res://ui/sorting/sorting_challenge.tscn")
const DROP_ICON := preload("res://assets/sprites/ui_drop.png")
const HEART_ICON := preload("res://assets/sprites/ui_heart.png")
const LOW_THRESHOLD := 0.2
const DAMAGE_FLASH_ALPHA := 0.35
const DAMAGE_FLASH_SECONDS := 0.3

## Which area's objectives to show; set by the area scene.
@export var area_id: String = "outpost"

var _water_meter: Meter
var _health_meter: Meter
var _inventory_box: VBoxContainer
var _objective_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _damage_flash: ColorRect
var _objective_panel: PanelContainer
var _banner: Label
var _last_objective_text := ""
var _banner_tween: Tween
var _level_label: Label
var _xp_meter: Meter
var _stats_label: Label
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	_build()
	_start_objective_pulse()
	add_child(DIALOGUE_SCENE.instantiate())
	add_child(SORTING_SCENE.instantiate())
	add_child(ObjectiveBeacon.new())
	add_child(QuizPanel.new())
	add_child(PuzzlePanel.new())
	add_child(QuestJournal.new())
	add_child(EquipmentPanel.new())

	EventBus.prompt_changed.connect(_on_prompt_changed)
	EventBus.inventory_changed.connect(_refresh_inventory)
	EventBus.flag_changed.connect(_refresh_objective.unbind(2))
	EventBus.survival_changed.connect(_on_survival_changed)
	EventBus.damage_taken.connect(_flash_damage)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.level_up.connect(_on_level_up)
	EventBus.gear_changed.connect(_refresh_stats)
	EventBus.loot_found.connect(_show_toast.bind(UiTheme.COLOR_GREEN))

	_on_prompt_changed("")
	_refresh_inventory()
	_refresh_objective()
	_on_survival_changed(Survival.water(), Survival.health())
	_on_xp_changed(Progress.level, Progress.xp, Progress.xp_needed())
	_refresh_stats()


func _start_objective_pulse() -> void:
	var pulse := create_tween().set_loops()
	pulse.tween_property(_objective_panel, "self_modulate", Color(1.35, 1.15, 0.85), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_objective_panel, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


func set_area(new_area_id: String) -> void:
	area_id = new_area_id
	_refresh_objective()


func _flash_damage(amount: float) -> void:
	# A scratch barely tints the screen; a heavy hit washes it red.
	_damage_flash.modulate.a = clampf(amount / 45.0, 0.06, DAMAGE_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_damage_flash, "modulate:a", 0.0, DAMAGE_FLASH_SECONDS)


func _on_prompt_changed(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_label.text = "[E] %s" % text


func _on_survival_changed(water: float, health: float) -> void:
	_water_meter.ratio = water / Survival.MAX_VALUE
	_health_meter.ratio = health / Survival.max_health()
	_water_meter.fill_color = UiTheme.COLOR_RED if _water_meter.ratio < LOW_THRESHOLD else UiTheme.COLOR_WATER
	_health_meter.fill_color = UiTheme.COLOR_RED if _health_meter.ratio < LOW_THRESHOLD else UiTheme.COLOR_GREEN


func _on_xp_changed(level: int, xp: int, needed: int) -> void:
	_level_label.text = "LV %d" % level
	_xp_meter.ratio = float(xp) / float(maxi(needed, 1))
	_refresh_stats()


func _refresh_stats() -> void:
	var damage := CombatRules.player_damage(Gear.weapon_damage(), Progress.level)
	_stats_label.text = "ATK %d  DEF %d" % [damage, Gear.armor()]


func _on_level_up(level: int) -> void:
	_show_toast("LEVEL UP!  You are level %d" % level, UiTheme.COLOR_YELLOW)
	var flash := create_tween()
	_damage_flash.color = UiTheme.COLOR_YELLOW
	_damage_flash.modulate.a = 0.45
	flash.tween_property(_damage_flash, "modulate:a", 0.0, 0.6)
	flash.tween_callback(func() -> void: _damage_flash.color = UiTheme.COLOR_RED)


## A line of text that appears under the banner and fades: loot, level ups.
func _show_toast(text: String, color: Color) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast_label.visible = false)


func _refresh_objective() -> void:
	var objective := ObjectivesTracker.current(area_id)
	var text: String = objective.get("text", "Explore, and decide what to do with what you learned.")
	_objective_label.text = text
	if text != _last_objective_text and not _last_objective_text.is_empty() and not objective.is_empty():
		_announce(text)
	_last_objective_text = text


## A short banner and a bright pulse so a new goal is noticed without reading.
func _announce(text: String) -> void:
	_banner.text = "NEW OBJECTIVE\n%s" % text
	_banner.visible = true
	_banner.modulate.a = 1.0
	EventBus.sfx_requested.emit("reveal")
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(2.4)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)
	var flash := create_tween()
	_objective_panel.modulate = Color(2.2, 1.8, 1.2)
	flash.tween_property(_objective_panel, "modulate", Color.WHITE, 0.8)


func _refresh_inventory() -> void:
	for row in _inventory_box.get_children():
		row.queue_free()
	var counts := Inventory.snapshot()
	for item_id: String in counts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.texture = ItemDB.icon(item_id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s x%d" % [ItemDB.display_name(item_id), counts[item_id]]
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		_inventory_box.add_child(row)


func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_damage_flash = ColorRect.new()
	_damage_flash.color = UiTheme.COLOR_RED
	_damage_flash.modulate.a = 0.0
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_damage_flash)

	var left := VBoxContainer.new()
	left.position = Vector2(6, 6)
	left.add_theme_constant_override("separation", 3)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	_water_meter = _add_meter_row(left, DROP_ICON)
	_health_meter = _add_meter_row(left, HEART_ICON)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 4)
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	level_row.add_child(_level_label)
	_xp_meter = Meter.new()
	_xp_meter.fill_color = UiTheme.COLOR_YELLOW
	_xp_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_meter.custom_minimum_size = Vector2(54, 5)
	level_row.add_child(_xp_meter)
	left.add_child(level_row)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 8)
	_stats_label.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	left.add_child(_stats_label)
	_inventory_box = VBoxContainer.new()
	_inventory_box.add_theme_constant_override("separation", 1)
	_inventory_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_inventory_box)

	var objective_panel := PanelContainer.new()
	_objective_panel = objective_panel
	objective_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.COLOR_ORANGE))
	objective_panel.anchor_left = 1.0
	objective_panel.anchor_right = 1.0
	objective_panel.offset_left = -176.0
	objective_panel.offset_right = -6.0
	objective_panel.offset_top = 6.0
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective_panel)
	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation", 3)
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(objective_box)
	var heading := Label.new()
	heading.text = "OBJECTIVE"
	heading.add_theme_color_override("font_color", UiTheme.COLOR_ORANGE)
	objective_box.add_child(heading)
	_objective_label = Label.new()
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(150, 0)
	objective_box.add_child(_objective_label)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	_banner.add_theme_color_override("font_outline_color", Color("#1a1008"))
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -120.0
	_banner.offset_right = 120.0
	_banner.offset_top = 40.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_outline_color", Color("#1a1008"))
	_toast_label.add_theme_constant_override("outline_size", 4)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -150.0
	_toast_label.offset_right = 150.0
	_toast_label.offset_top = 78.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.visible = false
	root.add_child(_toast_label)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -130.0
	_prompt_panel.offset_right = 130.0
	_prompt_panel.offset_top = -32.0
	_prompt_panel.offset_bottom = -8.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)


func _add_meter_row(parent: Control, icon: Texture2D) -> Meter:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_rect)
	var meter := Meter.new()
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.custom_minimum_size = Vector2(72, 7)
	row.add_child(meter)
	parent.add_child(row)
	return meter
