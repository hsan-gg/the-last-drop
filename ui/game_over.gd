extends Control
## All three lives are gone. A short pause to take it in, then the run restarts.

const RESTART_SECONDS := 6.0

var _countdown: Label
var _remaining := RESTART_SECONDS


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#14080c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	column.add_child(_label("YOU DIED", 24, UiTheme.COLOR_RED))
	column.add_child(_label("All three lives are gone.\nThe world resets, and you start again.", 8, UiTheme.COLOR_TEXT))
	var stats := "Level %d   Zombies defeated: %d   Sorted correctly: %d" % [Progress.level, GameState.get_counter("kills"), GameState.get_counter("sort_correct")]
	column.add_child(_label(stats, 8, UiTheme.COLOR_MUTED))
	_countdown = _label("", 8, UiTheme.COLOR_ORANGE)
	column.add_child(_countdown)
	var again := Button.new()
	again.text = "TRY AGAIN"
	again.custom_minimum_size = Vector2(140, 24)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(_restart)
	column.add_child(again)
	again.grab_focus()
	var title := Button.new()
	title.text = "TITLE"
	title.custom_minimum_size = Vector2(140, 20)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.pressed.connect(SceneManager.go_to_title)
	column.add_child(title)
	EventBus.sfx_requested.emit("collapse")


func _process(delta: float) -> void:
	_remaining -= delta
	_countdown.text = "Restarting in %d" % maxi(ceili(_remaining), 0)
	if _remaining <= 0.0:
		set_process(false)
		_restart()


func _restart() -> void:
	set_process(false)
	SceneManager.new_game(true)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
