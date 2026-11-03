class_name RewardCard
extends Control
## The big good-news moment (a level up, a region lit again), shown calmly: a
## soft card fades in near the top with a gentle chime and a few motes of light
## drifting up. Nothing shakes or flashes. It waits for any conversation.

const HOLD_SECONDS := 3.2
const WIDTH := 210.0
const KINDS := {
	"level": {"color": Color("#f2d16b"), "glow": Color("#ffe9a8"), "sound": "note_level"},
	"region": {"color": Color("#7fe0d0"), "glow": Color("#c8fff4"), "sound": "note_region"},
}

var _card: PanelContainer
var _title: Label
var _line: Label
var _motes: CPUParticles2D
var _queue: Array[Dictionary] = []
var _showing := false
var _on_done: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_build()



## Shows one reward card, then calls `done` once it has faded away.
func present(kind: String, title: String, line: String, done: Callable = Callable()) -> void:
	_enqueue(kind, title, line)
	_on_done = done


func is_showing() -> bool:
	return _showing


func _enqueue(kind: String, title: String, line: String) -> void:
	_queue.append({"kind": kind, "title": title, "line": line})
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		_card.visible = false
		if _on_done.is_valid():
			var done := _on_done
			_on_done = Callable()
			done.call()
		return
	_showing = true
	var reward: Dictionary = _queue.pop_front()
	var spec: Dictionary = KINDS.get(reward["kind"], KINDS["level"])
	_title.text = reward["title"]
	_title.add_theme_color_override("font_color", spec["color"])
	_line.text = reward["line"]
	var style := _card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = (spec["color"] as Color).darkened(0.1)
	_motes.color = spec["glow"]
	_motes.restart()
	_card.visible = true
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	EventBus.sfx_requested.emit(spec["sound"])
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_card, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(HOLD_SECONDS)
	tween.chain().tween_property(_card, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(_next)


func _build() -> void:
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.16, 0.9)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	_card.add_theme_stylebox_override("panel", style)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -WIDTH / 2.0
	_card.offset_right = WIDTH / 2.0
	_card.offset_top = 30.0
	_card.pivot_offset = Vector2(WIDTH / 2.0, 20.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_card.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	column.add_child(_title)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(WIDTH - 16.0, 0)
	_line.add_theme_color_override("font_color", Color("#f6ecd6"))
	_line.add_theme_font_size_override("font_size", 8)
	column.add_child(_line)
	_motes = CPUParticles2D.new()
	_motes.position = Vector2(WIDTH / 2.0, 30.0)
	_motes.one_shot = true
	_motes.emitting = false
	_motes.amount = 18
	_motes.lifetime = 2.2
	_motes.explosiveness = 0.6
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(WIDTH / 2.0, 8.0)
	_motes.direction = Vector2.UP
	_motes.spread = 25.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 6.0
	_motes.initial_velocity_max = 16.0
	_motes.scale_amount_min = 1.0
	_motes.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	_motes.color_ramp = fade
	_card.add_child(_motes)
