extends Control
## Title screen: the game's name, its premise, and a start button.

const SHEET := preload("res://assets/sprites/player.png")
const TAGLINE := "A survival adventure in a world buried by its own waste."
const CONTROLS := "WASD move   E act   Q quests   M mute"

var _start: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_start.grab_focus()


func _on_start_pressed() -> void:
	EventBus.sfx_requested.emit("click")
	SceneManager.new_game()


func _build() -> void:
	add_child(TitleBackdrop.new())

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var hero := AtlasTexture.new()
	hero.atlas = SHEET
	hero.region = Rect2(0, 0, PlayerSprite.FRAME_WIDTH, SHEET.get_height() / PlayerSprite.DIRECTIONS.size())
	var portrait := TextureRect.new()
	portrait.texture = hero
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(portrait)

	column.add_child(_label("THE LAST", 24, UiTheme.COLOR_TEXT))
	column.add_child(_label("DROP", 24, UiTheme.COLOR_ORANGE))

	var tagline := _label(TAGLINE, 8, UiTheme.COLOR_MUTED)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(300, 0)
	tagline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tagline)

	_start = Button.new()
	_start.text = "START"
	_start.custom_minimum_size = Vector2(120, 24)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(_on_start_pressed)
	column.add_child(_start)

	column.add_child(_label(CONTROLS, 8, UiTheme.COLOR_MUTED))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#120a18"))
	label.add_theme_constant_override("outline_size", 3)
	return label
