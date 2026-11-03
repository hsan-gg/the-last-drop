class_name NotificationFeed
extends Control
## Small, friendly messages in the bottom-left corner, in the spirit of Stardew
## Valley's HUD messages: an icon, a short headline and one readable line. They
## slide in, stack upward, and drift away after a few seconds. XP gains merge
## into one running line instead of spamming. Each kind has its own soft chime.
## The feed steps aside while a conversation is open.

const SHOW_SECONDS := 4.2
const XP_SHOW_SECONDS := 2.6
const MAX_ENTRIES := 4
const WIDTH := 212.0
const SLIDE := 24.0
const XP_SOUND_GAP := 0.6
const PAPER := Color(0.13, 0.11, 0.15, 0.93)
const INK := Color("#f6ecd6")
## kind -> headline colour, icon, chime
const KINDS := {
	"objective_new": {"color": Color("#f2b45a"), "icon": "flag", "sound": "note_new"},
	"objective_done": {"color": Color("#8fd27a"), "icon": "check", "sound": "note_quest"},
	"quest": {"color": Color("#f2d16b"), "icon": "star", "sound": "note_quest"},
	"loot": {"color": Color("#7fd0e8"), "icon": "bag", "sound": "note_loot"},
	"xp": {"color": Color("#b9e07a"), "icon": "spark", "sound": "note_xp"},
	"info": {"color": Color("#c8b8e8"), "icon": "dot", "sound": "note_new"},
}

var _stack: VBoxContainer
var _xp_entry: Control
var _xp_total := 0
var _last_xp_sound := -10.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_stack = VBoxContainer.new()
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.add_theme_constant_override("separation", 3)
	_stack.anchor_top = 1.0
	_stack.anchor_bottom = 1.0
	_stack.offset_left = 6.0
	_stack.offset_right = 6.0 + WIDTH
	_stack.offset_top = -170.0
	_stack.offset_bottom = -8.0
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	EventBus.dialogue_opened.connect(_step_aside.bind(true))
	EventBus.dialogue_finished.connect(_step_aside.bind(false).unbind(1))
	EventBus.dialogue_interrupted.connect(_step_aside.bind(false))


## Shows a message (after any open conversation).
func notify(kind: String, headline: String, line: String) -> void:
	Notices.run(_present.bind(kind, headline, line))


## Adds XP to the running "+N XP" line.
func add_xp(amount: int) -> void:
	if amount > 0:
		Notices.run(_present_xp.bind(amount))


func count() -> int:
	return _stack.get_child_count()


func _present(kind: String, headline: String, line: String) -> void:
	var spec: Dictionary = KINDS.get(kind, KINDS["info"])
	var entry := _make_entry(spec, headline, line)
	_stack.add_child(entry)
	_trim()
	_animate_in(entry, SHOW_SECONDS)
	EventBus.sfx_requested.emit(spec["sound"])


func _present_xp(amount: int) -> void:
	if is_instance_valid(_xp_entry) and not _xp_entry.is_queued_for_deletion():
		_xp_total += amount
		(_xp_entry.get_meta("line") as Label).text = "+%d XP" % _xp_total
		_xp_entry.set_meta("expires", _now() + XP_SHOW_SECONDS)
		var pop := create_tween()
		pop.tween_property(_xp_entry, "modulate", Color(1.25, 1.25, 1.1), 0.08)
		pop.tween_property(_xp_entry, "modulate", Color.WHITE, 0.25)
	else:
		_xp_total = amount
		_xp_entry = _make_entry(KINDS["xp"], "", "+%d XP" % amount)
		_stack.add_child(_xp_entry)
		_trim()
		_animate_in(_xp_entry, XP_SHOW_SECONDS)
	if _now() - _last_xp_sound > XP_SOUND_GAP:
		_last_xp_sound = _now()
		EventBus.sfx_requested.emit("note_xp")


func _process(_delta: float) -> void:
	for entry in _stack.get_children():
		if entry.has_meta("expires") and _now() >= float(entry.get_meta("expires")) and not entry.get_meta("leaving", false):
			_animate_out(entry)


func _trim() -> void:
	while _stack.get_child_count() > MAX_ENTRIES:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()


func _animate_in(entry: Control, seconds: float) -> void:
	entry.set_meta("expires", _now() + seconds)
	entry.modulate.a = 0.0
	var body := entry.get_child(0) as Control
	body.position.x = -SLIDE
	var tween := create_tween().set_parallel()
	tween.tween_property(entry, "modulate:a", 1.0, 0.25)
	tween.tween_property(body, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _animate_out(entry: Control) -> void:
	entry.set_meta("leaving", true)
	var tween := create_tween()
	tween.tween_property(entry, "modulate:a", 0.0, 0.5)
	tween.tween_callback(entry.queue_free)


func _step_aside(talking: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_stack, "modulate:a", 0.0 if talking else 1.0, 0.2)


## One message: a holder (so the card can slide inside the stack) with a card.
func _make_entry(spec: Dictionary, headline: String, line: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = spec["color"]
	style.set_border_width_all(0)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 2
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	var icon := NoticeIcon.new()
	icon.kind = spec["icon"]
	icon.color = spec["color"]
	icon.custom_minimum_size = Vector2(12, 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	if not headline.is_empty():
		var title := Label.new()
		title.text = headline
		title.add_theme_color_override("font_color", spec["color"])
		title.add_theme_font_size_override("font_size", 8)
		column.add_child(title)
	var text := Label.new()
	text.text = line
	text.add_theme_color_override("font_color", INK)
	text.add_theme_font_size_override("font_size", 8)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - 34.0, 0)
	column.add_child(text)
	holder.set_meta("line", text)
	# the holder takes the card's size so the stack lays it out
	card.resized.connect(func() -> void: holder.custom_minimum_size = card.size)
	holder.custom_minimum_size = card.get_combined_minimum_size()
	return holder


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
