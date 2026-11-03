class_name MenuTab
extends Control
## One page of the game menu. Subclasses build their own children, fill
## themselves in `refresh()`, and may react to keys in `tab_input()`.


## Called each time the tab is shown.
func refresh() -> void:
	pass


## Return true when the event was used.
func tab_input(_event: InputEvent) -> bool:
	return false


## True while the tab is waiting for a key press (rebinding), so the menu does not steal it.
func is_capturing() -> bool:
	return false


func _label(text: String, color: Color = UiTheme.COLOR_TEXT, size: int = 8) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label


func _rich(min_height: float = 0.0) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.fit_content = min_height <= 0.0
	rich.custom_minimum_size = Vector2(0, min_height)
	return rich
