class_name BossBar
extends VBoxContainer
## A boss's name and health across the top of the screen while it fights.

var _name: Label
var _meter: Meter


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -110.0
	offset_right = 110.0
	offset_top = 8.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_color", Color("#ff9a5a"))
	_name.add_theme_color_override("font_outline_color", Color("#1a1018"))
	_name.add_theme_constant_override("outline_size", 3)
	add_child(_name)
	_meter = Meter.new()
	_meter.custom_minimum_size = Vector2(220, 6)
	_meter.fill_color = Color("#e0582a")
	add_child(_meter)
	visible = false
	EventBus.boss_changed.connect(show_boss)


func show_boss(boss_name: String, ratio: float) -> void:
	visible = not boss_name.is_empty() and ratio > 0.0
	_name.text = boss_name.to_upper()
	_meter.ratio = clampf(ratio, 0.0, 1.0)
