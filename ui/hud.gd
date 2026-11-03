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


func _ready() -> void:
	layer = 10
	_build()
	add_child(DIALOGUE_SCENE.instantiate())
	add_child(SORTING_SCENE.instantiate())
	add_child(QuizPanel.new())
	add_child(PuzzlePanel.new())
	add_child(QuestJournal.new())

	EventBus.prompt_changed.connect(_on_prompt_changed)
	EventBus.inventory_changed.connect(_refresh_inventory)
	EventBus.flag_changed.connect(_refresh_objective.unbind(2))
	EventBus.survival_changed.connect(_on_survival_changed)
	EventBus.damage_taken.connect(_flash_damage.unbind(1))

	_on_prompt_changed("")
	_refresh_inventory()
	_refresh_objective()
	_on_survival_changed(Survival.water(), Survival.health())


func set_area(new_area_id: String) -> void:
	area_id = new_area_id
	_refresh_objective()


func _flash_damage() -> void:
	_damage_flash.modulate.a = DAMAGE_FLASH_ALPHA
	var tween := create_tween()
	tween.tween_property(_damage_flash, "modulate:a", 0.0, DAMAGE_FLASH_SECONDS)


func _on_prompt_changed(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_label.text = "[E] %s" % text


func _on_survival_changed(water: float, health: float) -> void:
	_water_meter.ratio = water / Survival.MAX_VALUE
	_health_meter.ratio = health / Survival.MAX_VALUE
	_water_meter.fill_color = UiTheme.COLOR_RED if _water_meter.ratio < LOW_THRESHOLD else UiTheme.COLOR_WATER
	_health_meter.fill_color = UiTheme.COLOR_RED if _health_meter.ratio < LOW_THRESHOLD else UiTheme.COLOR_GREEN


func _refresh_objective() -> void:
	var objective := ObjectivesTracker.current(area_id)
	_objective_label.text = objective.get("text", "Explore, and decide what to do with what you learned.")


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
	_inventory_box = VBoxContainer.new()
	_inventory_box.add_theme_constant_override("separation", 1)
	_inventory_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_inventory_box)

	var objective_panel := PanelContainer.new()
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
