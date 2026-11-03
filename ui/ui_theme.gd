class_name UiTheme
extends RefCounted
## One shared look for every screen: pixel font, dark teal panels, orange accents.

const FONT_FILE := preload("res://assets/fonts/PressStart2P-Regular.ttf")

const COLOR_TEXT := Color("#e8eef2")
const COLOR_MUTED := Color("#9fb0bb")
const COLOR_TEAL := Color("#5fd0c4")
const COLOR_ORANGE := Color("#f08a24")
const COLOR_RED := Color("#e0584a")
const COLOR_GREEN := Color("#7bc043")
const COLOR_YELLOW := Color("#f2c94c")
const COLOR_WATER := Color("#3aa0e0")
const COLOR_PANEL := Color(0.07, 0.11, 0.14, 0.94)
const COLOR_BORDER := Color("#1b8f86")
const COLOR_BUTTON := Color("#173540")
const COLOR_BUTTON_HOVER := Color("#1f4a58")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func panel_style(border: Color = COLOR_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_border_width_all(2)
	style.border_color = border
	style.set_content_margin_all(8)
	return style


## A header strip for popups: darker, with a bright top edge.
static func banner_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.11, 0.96)
	style.set_border_width_all(1)
	style.border_color = Color("#31505c")
	style.border_width_top = 2
	style.set_content_margin_all(5)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 3
	return style


## An inventory slot: dark well, brighter edge when selected, gold when worn.
static func slot_style(selected: bool, worn: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c161c") if not selected else Color("#183444")
	style.set_border_width_all(1)
	style.border_color = COLOR_YELLOW if worn else (COLOR_ORANGE if selected else Color("#2a4350"))
	if selected or worn:
		style.set_border_width_all(2)
	style.set_content_margin_all(1)
	return style


## A list card (quests): dark body with a coloured bar down the left edge.
static func card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0e1c24")
	style.set_border_width_all(1)
	style.border_color = Color("#223844")
	style.border_width_left = 3
	style.border_color = Color("#223844")
	style.set_content_margin_all(5)
	style.content_margin_left = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 2
	return style


static func button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func _build() -> Theme:
	var font: FontFile = FONT_FILE.duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 8

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_constant("line_spacing", "Label", 3)

	theme.set_font("normal_font", "RichTextLabel", font)
	theme.set_font_size("normal_font_size", "RichTextLabel", 8)
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	theme.set_constant("line_separation", "RichTextLabel", 3)

	theme.set_stylebox("panel", "PanelContainer", panel_style())

	theme.set_stylebox("normal", "Button", button_style(COLOR_BUTTON, COLOR_BORDER))
	theme.set_stylebox("hover", "Button", button_style(COLOR_BUTTON_HOVER, COLOR_TEAL))
	theme.set_stylebox("pressed", "Button", button_style(COLOR_BORDER, COLOR_TEXT))
	theme.set_stylebox("focus", "Button", button_style(COLOR_BUTTON_HOVER, COLOR_ORANGE))
	theme.set_stylebox("disabled", "Button", button_style(Color("#101c22"), Color("#2a3a42")))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT)
	theme.set_color("font_focus_color", "Button", COLOR_TEXT)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT)
	theme.set_color("font_disabled_color", "Button", Color("#5a6a72"))
	return theme
