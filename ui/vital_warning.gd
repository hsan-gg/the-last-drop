class_name VitalWarning
extends Control
## The banner that tells you that you are thirsty and slowed (no water left),
## or out of breath (no stamina to swing or guard). It pulses so it is
## hard to miss, makes a cue once when a warning first appears, and sits above
## the top of the screen.

const PULSE_HZ := 2.2
const BREATH_TEXT := "OUT OF BREATH: wait a moment"

var rules := VitalWarnings.new()
var _panel: PanelContainer
var _label: Label
var _breath_left := 0.0
var _shown := VitalWarnings.Kind.NONE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # anchors alone leave it 0 x 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.panel_style(UiTheme.COLOR_RED)
	style.bg_color = Color(0.16, 0.05, 0.05, 0.92)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_color_override("font_color", Color("#ffd6c8"))
	_label.add_theme_font_size_override("font_size", 8)
	_panel.add_child(_label)
	EventBus.survival_changed.connect(_on_survival_changed)
	EventBus.stamina_denied.connect(_on_out_of_breath)
	TouchControls.active_changed.connect(_on_touch_changed)
	_place()
	_on_survival_changed(Survival.water(), Survival.health())


## What the banner says right now ("" when nothing is wrong).
func message() -> String:
	if rules.current != VitalWarnings.Kind.NONE:
		return VitalWarnings.text_for(rules.current, Settings.key_label("quick_drink"))
	return BREATH_TEXT if _breath_left > 0.0 else ""


func is_warning() -> bool:
	return not message().is_empty()


func _on_survival_changed(water: float, _health: float) -> void:
	var before := rules.current
	rules.update(water)
	if rules.current != before and rules.current != VitalWarnings.Kind.NONE and rules.current > _shown:
		EventBus.sfx_requested.emit("warn")  # a cue when it first appears
	_shown = rules.current
	_refresh()


func _on_out_of_breath() -> void:
	_breath_left = VitalWarnings.BREATH_SECONDS
	_refresh()


func _on_touch_changed(_active: bool) -> void:
	_place()


func _process(delta: float) -> void:
	if _breath_left > 0.0:
		_breath_left = maxf(_breath_left - delta, 0.0)
		_refresh()
	if _panel.visible:
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * TAU * PULSE_HZ)
		_panel.modulate.a = pulse if rules.current == VitalWarnings.Kind.EXHAUSTED else lerpf(0.8, 1.0, pulse)


func _refresh() -> void:
	var text := message()
	_panel.visible = not text.is_empty()
	_label.text = text


## Top centre, between the stats and the map/menu buttons, where tips and
## prompts never go.
func _place() -> void:
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -120.0
	_panel.offset_right = 120.0
	_panel.offset_top = 6.0
	_panel.offset_bottom = 28.0
