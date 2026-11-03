class_name OverlayPanel
extends CanvasLayer
## Shared shell for full-screen modal panels (quiz, puzzle, journal): a dimmed
## backdrop, a centred panel with a vertical box, and pause handling.

## Tests turn this off so the tree keeps running.
@export var pauses_game: bool = true

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
	dim.color = Color(0, 0, 0, 0.62)
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
