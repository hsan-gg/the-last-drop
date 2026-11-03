class_name FloatingText
extends RefCounted
## A short-lived number or word that rises from a point in the world: damage,
## XP, "PARRY!". Fire and forget.

const RISE_PIXELS := 16.0
const LIFETIME := 0.7
const FONT_SIZE := 8


static func spawn(host: Node, text: String, world_position: Vector2, color: Color = Color.WHITE) -> void:
	if host == null or not host.is_inside_tree() or not Settings.value("damage_numbers"):
		return
	var label := Label.new()
	label.text = text
	label.z_index = 100
	label.position = world_position - Vector2(label.text.length() * 2.5, 12)
	label.add_theme_font_override("font", UiTheme.FONT_FILE)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#120a18"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - RISE_PIXELS, LIFETIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_delay(LIFETIME * 0.4)
	tween.chain().tween_callback(label.queue_free)
