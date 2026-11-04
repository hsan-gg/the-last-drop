class_name RuneBar
extends HBoxContainer
## The runes on the HUD: a slot per rune, each with its pixel icon, key, and
## energy filling it from below. It stays out of the way: it fades in when you
## use a rune (or find a new one) and fades out a moment after you stop.

const SLOT := Vector2(16, 16)
const LINGER_SECONDS := 2.2
const FADE_SECONDS := 0.35

var _slots: Array[RuneSlot] = []
var _shown_until := -1.0
var _clock := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	for slot in 3:
		var view := RuneSlot.new()
		view.slot = slot + 1
		view.custom_minimum_size = SLOT
		_slots.append(view)
		add_child(view)
	EventBus.runes_changed.connect(_on_runes_changed)
	_refresh()


func is_shown() -> bool:
	return _clock < _shown_until


## Brings the bar up for a while (used when a rune key is pressed or one is found).
func show_for(seconds: float = LINGER_SECONDS) -> void:
	_shown_until = maxf(_shown_until, _clock + seconds)


func _on_runes_changed() -> void:
	_refresh()
	if not Runes.owned.is_empty():
		show_for(LINGER_SECONDS * 2.0)


func _refresh() -> void:
	visible = not Runes.owned.is_empty()
	for view in _slots:
		view.visible = not Runes.in_slot(view.slot).is_empty()
		view.queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if not visible:
		return
	for view in _slots:
		view.active = Input.is_action_pressed("rune_%d" % view.slot) and not Runes.in_slot(view.slot).is_empty()
		if view.active:
			show_for()
		view.queue_redraw()
	var target := 1.0 if is_shown() else 0.0
	modulate.a = move_toward(modulate.a, target, delta / FADE_SECONDS)
