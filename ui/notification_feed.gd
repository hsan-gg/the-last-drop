class_name NotificationFeed
extends Control
## Small, friendly messages in the bottom-left corner, in the spirit of Stardew
## Valley's HUD messages: an icon, a short headline and one readable line.
##
## At most two are on screen, stacked; each slides in, stays a moment and slides
## out on its own, and the next waits for a free slot. Things that happen
## together are told in a sensible order: what you finished, then the XP it
## paid, then what to do next. XP from one moment is added up into one line,
## and keeps adding to a visible XP card. A level up does not queue: it shows at
## once on its own calm card at the top. Nothing plays while you talk.

const SHOW_SECONDS := 2.4
const XP_SHOW_SECONDS := 1.8
const GATHER_SECONDS := 0.15
## A second card may join the first this soon after it, so two can stack.
const STAGGER_SECONDS := 0.3
const MAX_ENTRIES := 2
## Lower comes first.
const PRIORITY := {"objective_done": 0, "quest": 1, "xp": 2, "loot": 3, "objective_new": 5, "info": 6}
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

var reward_card: RewardCard

var _stack: VBoxContainer
var _queue: Array[Dictionary] = []
var _sequence := 0
var _showing: Array[Control] = []
var _next_slot_at := 0.0
var _xp_card: Control
var _talking := false
var _gather_until := 0.0
var _last_xp_sound := -10.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_stack = VBoxContainer.new()
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.anchor_top = 1.0
	_stack.anchor_bottom = 1.0
	_stack.offset_left = 6.0
	_stack.offset_right = 6.0 + WIDTH
	_stack.offset_top = -120.0
	_stack.offset_bottom = -8.0
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	EventBus.dialogue_opened.connect(_set_talking.bind(true))
	EventBus.dialogue_finished.connect(_set_talking.bind(false).unbind(1))
	EventBus.dialogue_interrupted.connect(_set_talking.bind(false))
	EventBus.reward_requested.connect(func(kind: String, title: String, line: String) -> void:
		Notices.run(func() -> void:
			if reward_card != null:
				reward_card.present(kind, title, line)))


## Queues a message (after any open conversation).
func notify(kind: String, headline: String, line: String) -> void:
	Notices.run(_enqueue.bind({"kind": kind, "headline": headline, "line": line}))


## Adds XP; XP waiting in the queue is added up into one line.
func add_xp(amount: int) -> void:
	if amount > 0:
		Notices.run(_enqueue.bind({"kind": "xp", "amount": amount}))


## Messages waiting plus the one on screen.
func count() -> int:
	return _queue.size() + _showing.size()


## Cards on screen right now.
func showing() -> int:
	_showing = _showing.filter(func(card) -> bool: return is_instance_valid(card))
	return _showing.size()


## Every message waiting, in the order it will be shown (for tests and tools).
func pending_kinds() -> Array[String]:
	_sort()
	var kinds: Array[String] = []
	for entry in _queue:
		kinds.append(entry["kind"])
	return kinds


func _enqueue(entry: Dictionary) -> void:
	if entry["kind"] == "xp" and is_instance_valid(_xp_card) and not _xp_card.get_meta("leaving", false):
		var total := int(_xp_card.get_meta("amount")) + int(entry["amount"])
		_xp_card.set_meta("amount", total)
		(_xp_card.get_meta("line") as Label).text = "+%d XP" % total
		return
	if entry["kind"] == "xp":
		for waiting in _queue:
			if waiting["kind"] == "xp":
				waiting["amount"] = int(waiting["amount"]) + int(entry["amount"])
				return
	_sequence += 1
	entry["order"] = _sequence
	_queue.append(entry)
	if showing() == 0:
		_gather_until = maxf(_gather_until, _now() + GATHER_SECONDS)


func _sort() -> void:
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = PRIORITY.get(a["kind"], 6)
		var pb: int = PRIORITY.get(b["kind"], 6)
		return pa < pb if pa != pb else int(a["order"]) < int(b["order"]))


func _process(_delta: float) -> void:
	if _talking or _queue.is_empty() or _now() < _gather_until or _now() < _next_slot_at:
		return
	if showing() >= MAX_ENTRIES:
		return
	_sort()
	_show(_queue.pop_front())
	_next_slot_at = _now() + STAGGER_SECONDS


func _show(entry: Dictionary) -> void:
	var kind: String = entry["kind"]
	var spec: Dictionary = KINDS.get(kind, KINDS["info"])
	var line: String = "+%d XP" % int(entry["amount"]) if kind == "xp" else entry["line"]
	var headline: String = "" if kind == "xp" else entry["headline"]
	var card := _make_entry(spec, headline, line)
	_stack.add_child(card)
	_showing.append(card)
	if kind == "xp":
		card.set_meta("amount", int(entry["amount"]))
		_xp_card = card
	if kind != "xp" or _now() - _last_xp_sound > XP_SOUND_GAP:
		_last_xp_sound = _now()
		EventBus.sfx_requested.emit(spec["sound"])
	var body := card.get_child(0) as Control
	card.modulate.a = 0.0
	body.position.x = -SLIDE
	var tween := card.create_tween()
	tween.set_parallel()
	tween.tween_property(card, "modulate:a", 1.0, 0.15)
	tween.tween_property(body, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(XP_SHOW_SECONDS if kind == "xp" else SHOW_SECONDS)
	tween.chain().tween_callback(func() -> void: card.set_meta("leaving", true))
	tween.chain().tween_property(card, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(body, "position:x", -SLIDE * 0.5, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(card.queue_free)


func _set_talking(talking: bool) -> void:
	_talking = talking
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
