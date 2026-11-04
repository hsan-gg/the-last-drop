class_name OverlayPanel
extends CanvasLayer
## Shared shell for full-screen modal panels (quiz, puzzle, journal): a dimmed
## backdrop, a centred panel with a vertical box, and pause handling.

## Tests turn this off so the tree keeps running.
@export var pauses_game: bool = true
## An in-world panel (a puzzle at a terminal, a quiz in the field) does not
## stop time: zombies keep coming, the backdrop stays light enough to see them,
## your health is on the panel, and a blow from outside knocks you away from it.
var in_world := false

var _health_meter: Meter
var _health_label: Label

var _root: Control
var _box: VBoxContainer
var _opened_on_frame := -1


func _init() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS


## Builds the backdrop and panel. Call from _ready of the subclass.
func _build_shell(panel_size: Vector2, border: Color = UiTheme.COLOR_BORDER) -> void:
	add_to_group("modal")
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.32 if in_world else 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(border))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_size.x / 2.0
	panel.offset_right = panel_size.x / 2.0
	panel.offset_top = -panel_size.y / 2.0
	panel.offset_bottom = panel_size.y / 2.0
	_root.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	panel.add_child(_box)
	visible = false
	if in_world:
		pauses_game = false
		EventBus.player_hit.connect(_on_struck)
		EventBus.survival_changed.connect(_on_survival_changed)


## Something hit you while you were busy here: the panel closes (what you had
## done is kept) so you can fight back. Panels override `leave`.
func _on_struck(_outcome: String, _damage: Variant) -> void:
	if visible:
		leave()
		EventBus.tip_requested.emit("Attacked! You were knocked away from the panel.")


func leave() -> void:
	pass


## Your health on the panel, as on the sorting screen: in-world panels can hurt.
func _add_health_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var heart := _label("HEALTH", UiTheme.COLOR_RED, 8)
	row.add_child(heart)
	_health_meter = Meter.new()
	_health_meter.custom_minimum_size = Vector2(90, 6)
	_health_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_health_meter)
	_health_label = _label("", UiTheme.COLOR_TEXT, 8)
	row.add_child(_health_label)
	_box.add_child(row)
	_on_survival_changed(Survival.water(), Survival.health())
	return row


func _on_survival_changed(_water: float, health: float) -> void:
	if _health_meter == null:
		return
	_health_meter.ratio = health / Survival.max_health()
	_health_meter.fill_color = UiTheme.COLOR_RED if _health_meter.ratio < 0.3 else UiTheme.COLOR_GREEN
	_health_label.text = "%d / %d" % [roundi(health), roundi(Survival.max_health())]


## A mistake cost health: the number flashes so the loss is felt.
func _flash_health(amount: float) -> void:
	if _health_label == null:
		return
	_health_label.add_theme_color_override("font_color", UiTheme.COLOR_RED)
	_health_label.text = "-%d" % roundi(amount)
	get_tree().create_timer(0.6, true).timeout.connect(func() -> void:
		_health_label.add_theme_color_override("font_color", UiTheme.COLOR_TEXT)
		_on_survival_changed(Survival.water(), Survival.health()))


func _show_panel() -> void:
	_opened_on_frame = Engine.get_process_frames()
	visible = true
	if pauses_game:
		get_tree().paused = true


func _hide_panel() -> void:
	visible = false
	if pauses_game:
		get_tree().paused = false


## True on the frame the panel opened, so the key that opened it is not re-read.
func _just_opened() -> bool:
	return Engine.get_process_frames() == _opened_on_frame


func _label(text: String, color: Color = UiTheme.COLOR_TEXT, size: int = 8) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label


func _rich(min_height: float) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.fit_content = false
	rich.custom_minimum_size = Vector2(0, min_height)
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return rich


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_constant_override("h_separation", 4)
	button.custom_minimum_size = Vector2(0, 14)
	button.pressed.connect(handler)
	return button
