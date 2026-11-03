extends Control
## The ending: choose what to do with the archive, read how the world answers
## (shaped by how carefully the player sorted), then the closing message.

const DIALOGUE_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")
const DROP_ICON := preload("res://assets/sprites/ui_drop.png")
const EPILOGUE_ID := "ending"
const FINAL_QUOTE := "The world wasn't destroyed in a single day.\nAnd it won't be rebuilt in one either."
const CHOICES := {
	EndingRules.CHOICE_PRESERVE: {
		"title": "PRESERVE THE DISCOVERY",
		"body": "Keep the facility and its knowledge for your own community. A small group is protected in the near term, but the wider world keeps waiting.",
	},
	EndingRules.CHOICE_SHARE: {
		"title": "SHARE THE KNOWLEDGE",
		"body": "Release the findings and invite other communities to cooperate. Wider restoration becomes possible, but the knowledge could be misused or contested.",
	},
}

var _content: VBoxContainer
var _dialogue: DialogueBox
var _drop: TextureRect


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("#0d1c24")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var horizon := ColorRect.new()
	horizon.color = Color("#3a2418")
	horizon.anchor_top = 0.72
	horizon.anchor_right = 1.0
	horizon.anchor_bottom = 1.0
	add_child(horizon)

	_drop = TextureRect.new()
	_drop.texture = DROP_ICON
	_drop.custom_minimum_size = Vector2(54, 66)
	_drop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drop.anchor_left = 0.5
	_drop.anchor_right = 0.5
	_drop.offset_left = -27.0
	_drop.offset_right = 27.0
	_drop.offset_top = 40.0
	_drop.offset_bottom = 106.0
	_drop.visible = false
	add_child(_drop)

	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 12)
	add_child(_content)

	_dialogue = DIALOGUE_SCENE.instantiate()
	_dialogue.pauses_game = false
	add_child(_dialogue)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)

	_show_choice()


func _show_choice() -> void:
	_reset_content()
	_content.add_child(_label("THE FINAL CHOICE", 16, UiTheme.COLOR_ORANGE))
	var question := _label("The archive holds what is needed to begin restoring the world. What do you do with it?", 8, UiTheme.COLOR_TEXT)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(380, 0)
	question.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(question)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var first: Button
	for choice: String in CHOICES:
		var card := _choice_card(choice)
		row.add_child(card)
		if first == null:
			first = card
	first.grab_focus()


## A button holding a coloured title and a wrapped description.
func _choice_card(choice: String) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(212, 132)
	card.pressed.connect(_choose.bind(choice))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var title := _label(CHOICES[choice]["title"], 8, UiTheme.COLOR_ORANGE)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var body := _label(CHOICES[choice]["body"], 8, UiTheme.COLOR_TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)
	return card


func _choose(choice: String) -> void:
	_reset_content()
	_drop.visible = true
	GameState.set_flag("ending_%s" % choice)
	var lines := EndingRules.epilogue_lines(choice, GameState.get_counter("sort_mistakes"))
	_dialogue.show_lines(lines, EPILOGUE_ID)


func _on_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id == EPILOGUE_ID:
		_show_final()


func _show_final() -> void:
	_reset_content()
	var quote := _label(FINAL_QUOTE, 16, UiTheme.COLOR_ORANGE)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(420, 0)
	quote.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(quote)

	var stats := "Sorted correctly: %d    Mistakes: %d" % [GameState.get_counter("sort_correct"), GameState.get_counter("sort_mistakes")]
	_content.add_child(_label(stats, 8, UiTheme.COLOR_MUTED))

	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.custom_minimum_size = Vector2(140, 24)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(SceneManager.go_to_title)
	_content.add_child(again)
	again.grab_focus()


func _reset_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
