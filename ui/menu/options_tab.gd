class_name OptionsTab
extends MenuTab
## Sound, display, gameplay and accessibility options. Every change applies at
## once and is saved. Rows are grouped under headings, like most games' menus.

const HINT_NAMES := ["Off", "Subtle", "Strong"]
const SPEED_NAMES := ["Slow", "Normal", "Fast"]
const VOLUME_STEP := 0.1

var _rows: Array[Dictionary] = []
var _list: VBoxContainer
var _difficulty_label: Label


func _ready() -> void:
	_build()
	Settings.changed.connect(_update_labels.unbind(1))


func refresh() -> void:
	_update_labels()


func volume_text(key: String) -> String:
	return "%d%%" % roundi(float(Settings.value(key)) * 100.0)


func step_volume(key: String, direction: int) -> void:
	var next := clampf(snappedf(float(Settings.value(key)) + VOLUME_STEP * direction, VOLUME_STEP), 0.0, 1.0)
	Settings.set_value(key, next)


func toggle(key: String) -> void:
	Settings.set_value(key, not bool(Settings.value(key)))


func cycle(key: String, count: int) -> void:
	Settings.set_value(key, (int(Settings.value(key)) + 1) % count)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)

	_heading("DIFFICULTY")
	_difficulty_label = _label("", UiTheme.COLOR_YELLOW)
	_list.add_child(_difficulty_label)
	_heading("AUDIO")
	_volume_row("Master volume", "master")
	_volume_row("Music", "music")
	_volume_row("Sound effects", "sfx")
	_toggle_row("Mute everything", "muted")
	_heading("DISPLAY")
	_toggle_row("Fullscreen", "fullscreen")
	_heading("GAMEPLAY")
	_cycle_row("Objective hints", "objective_hints", HINT_NAMES)
	_cycle_row("Text speed", "text_speed", SPEED_NAMES)
	_toggle_row("Damage numbers", "damage_numbers")
	_toggle_row("Show tips", "tips")
	_heading("ACCESSIBILITY")
	_toggle_row("Screen shake", "screen_shake")
	_toggle_row("Reduce flashing", "reduce_flashing")
	var reset := Button.new()
	reset.text = "Reset all options"
	reset.pressed.connect(Settings.reset_all)
	_list.add_child(reset)


func _heading(text: String) -> void:
	_list.add_child(_label(text, UiTheme.COLOR_TEAL))


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := _label(label_text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	_list.add_child(row)
	return row


func _volume_row(label_text: String, key: String) -> void:
	var row := _row(label_text)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(18, 0)
	minus.pressed.connect(step_volume.bind(key, -1))
	row.add_child(minus)
	var value := _label("")
	value.custom_minimum_size = Vector2(36, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(18, 0)
	plus.pressed.connect(step_volume.bind(key, 1))
	row.add_child(plus)
	_rows.append({"kind": "volume", "key": key, "label": value})


func _toggle_row(label_text: String, key: String) -> void:
	var row := _row(label_text)
	var button := Button.new()
	button.custom_minimum_size = Vector2(60, 0)
	button.pressed.connect(toggle.bind(key))
	row.add_child(button)
	_rows.append({"kind": "toggle", "key": key, "button": button})


func _cycle_row(label_text: String, key: String, names: Array) -> void:
	var row := _row(label_text)
	var button := Button.new()
	button.custom_minimum_size = Vector2(60, 0)
	button.pressed.connect(cycle.bind(key, names.size()))
	row.add_child(button)
	_rows.append({"kind": "cycle", "key": key, "button": button, "names": names})


func _update_labels() -> void:
	var level := Difficulty.current()
	_difficulty_label.text = "%s  (chosen on the title screen, fixed for a run)" % level.get("name", "MEDIUM")
	_difficulty_label.add_theme_color_override("font_color", Color(level.get("color", "#f2c94c")))
	for row in _rows:
		match row["kind"]:
			"volume":
				(row["label"] as Label).text = volume_text(row["key"])
			"toggle":
				(row["button"] as Button).text = "ON" if Settings.value(row["key"]) else "OFF"
			"cycle":
				(row["button"] as Button).text = row["names"][clampi(int(Settings.value(row["key"])), 0, row["names"].size() - 1)]
