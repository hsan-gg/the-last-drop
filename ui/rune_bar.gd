class_name RuneBar
extends HBoxContainer
## The runes on the HUD: a purple energy bar and a slot per rune, showing its
## key and its picture, dimmed while you cannot afford it. Hidden until you own one.

const SLOT := Vector2(14, 14)

var _energy: Meter
var _slots: Array[Control] = []


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy = Meter.new()
	_energy.custom_minimum_size = Vector2(40, 5)
	_energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy.fill_color = Color("#b070f0")
	add_child(_energy)
	for slot in 3:
		var view := RuneSlot.new()
		view.slot = slot + 1
		view.custom_minimum_size = SLOT
		_slots.append(view)
		add_child(view)
	EventBus.runes_changed.connect(_refresh)
	EventBus.energy_changed.connect(func(value: float, maximum: float) -> void: _energy.ratio = value / maximum)
	_refresh()


func _refresh() -> void:
	visible = not Runes.owned.is_empty()
	_energy.ratio = Runes.energy / Runes.MAX_ENERGY
	for view in _slots:
		view.visible = not Runes.in_slot((view as RuneSlot).slot).is_empty()
		view.queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		for view in _slots:
			view.queue_redraw()
