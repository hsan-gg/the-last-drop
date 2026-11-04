class_name ChallengeTimer
extends Label
## The countdown for a timed challenge, top centre, red in the last ten seconds.


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -100.0
	offset_right = 100.0
	offset_top = 34.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_color_override("font_outline_color", Color("#120a18"))
	add_theme_constant_override("outline_size", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	EventBus.challenge_changed.connect(_on_changed)


func _on_changed(label_text: String, seconds: float) -> void:
	visible = not label_text.is_empty()
	text = "%s  %d:%02d" % [label_text.to_upper(), int(seconds) / 60, int(seconds) % 60]
	add_theme_color_override("font_color", Color("#ff6a5a") if seconds <= 10.0 else Color("#f2d16b"))
