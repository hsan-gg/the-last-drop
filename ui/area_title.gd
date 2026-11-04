class_name AreaTitle
extends VBoxContainer
## The name of the place you just walked into, large and quiet, with a line
## beneath it, fading in and out: like turning to a new chapter of a book.

const TITLES := {
	"outpost": ["The Forgotten Outpost", "where you woke"],
	"factory": ["The Battery Factory", "it never stopped leaking"],
	"dump": ["The Great Dump", "a city's rubbish, piled into mountains"],
	"river": ["The Dead River", "clear is not the same as clean"],
	"fields": ["The Silent Fields", "the soil forgot how to live"],
	"industry": ["The Forgotten Industry", "read the labels"],
	"sanctuary": ["The Last Sanctuary", "the end of the pipeline"],
}

var _title: Label
var _line: Label


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -170.0
	offset_right = 170.0
	offset_top = 74.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	_title = _make(16, Color("#f6ecd6"))
	_line = _make(8, Color("#c8b890"))
	modulate.a = 0.0


func show_area(area_id: String) -> void:
	var entry: Array = TITLES.get(area_id, [area_id.capitalize(), ""])
	_title.text = entry[0]
	_line.text = "~ %s ~" % entry[1] if not String(entry[1]).is_empty() else ""
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(2.2)
	tween.tween_property(self, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


func _make(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#120a18"))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label
