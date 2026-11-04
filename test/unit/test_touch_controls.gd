extends GutTest
## The on-screen controls for phones: the stick, the buttons, the way they
## step in for the keyboard, and every puzzle board answering a tap.

var _saved_choice: int


func before_each() -> void:
	_saved_choice = int(Settings.value("touch_controls"))
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	TouchControls.release_all()
	TouchControls._seen_touch = false
	Settings.set_value("touch_controls", _saved_choice)
	TouchControls.refresh_active()
	Survival.reset()
	Survival.set_process(true)
	get_tree().paused = false


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	TouchControls._input(event)
	Input.flush_buffered_events()


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	TouchControls._input(event)


func _play_layout() -> void:
	Settings.set_value("touch_controls", TouchControls.ALWAYS)
	TouchControls.mode = TouchControls.Mode.PLAY
	TouchControls._layout()


func _button(id: String) -> Dictionary:
	for button in TouchControls.buttons:
		if button["id"] == id:
			return button
	return {}


# ------------------------------------------------------------------ stick maths

func test_a_resting_or_barely_touched_stick_does_not_walk() -> void:
	for action: String in TouchStick.MOVES:
		assert_eq(TouchStick.strengths(Vector2.ZERO, 24.0)[action], 0.0)
		assert_eq(TouchStick.strengths(Vector2(3, 0), 24.0)[action], 0.0, "inside the dead zone")


func test_a_stick_pushed_to_the_rim_walks_at_full_speed() -> void:
	var push := TouchStick.strengths(Vector2(40, 0), 24.0)
	assert_almost_eq(float(push["move_right"]), 1.0, 0.001)
	assert_eq(push["move_left"], 0.0)


func test_half_a_push_walks_at_about_half_speed_despite_the_action_dead_zone() -> void:
	# get_vector() drops the first 0.5 of a press and rescales the rest.
	var radius := 24.0
	var offset := Vector2(0, -radius * (TouchStick.DEAD_ZONE + (1.0 - TouchStick.DEAD_ZONE) * 0.5))
	var push := TouchStick.strengths(offset, radius)
	var raw := float(push["move_up"])
	var speed := (raw - TouchStick.ACTION_DEAD_ZONE) / (1.0 - TouchStick.ACTION_DEAD_ZONE)
	assert_almost_eq(speed, 0.5, 0.01)


func test_a_diagonal_push_keeps_its_direction() -> void:
	var push := TouchStick.strengths(Vector2(30, 30), 24.0)
	assert_almost_eq(float(push["move_right"]), float(push["move_down"]), 0.001)
	assert_gt(float(push["move_right"]), 0.6)


# ------------------------------------------------------------------ turning on and off

func test_turning_the_controls_on_frees_the_mouse_click_from_the_sword() -> void:
	Settings.set_value("touch_controls", TouchControls.ALWAYS)
	assert_true(TouchControls.active)
	for event in InputMap.action_get_events("attack"):
		assert_false(event is InputEventMouseButton, "a tap must not swing the sword")
	assert_eq(get_tree().root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND, "the picture widens to the phone")
	Settings.set_value("touch_controls", TouchControls.NEVER)
	assert_false(TouchControls.active)
	var has_click := false
	for event in InputMap.action_get_events("attack"):
		has_click = has_click or event is InputEventMouseButton
	assert_true(has_click, "the mouse click comes back for desktop play")


func test_hints_speak_of_buttons_while_touch_is_on() -> void:
	Settings.set_value("touch_controls", TouchControls.ALWAYS)
	assert_eq(Settings.key_label("interact"), "USE")
	assert_true(Tutorial.text_for("move").contains("thumb"))
	Settings.set_value("touch_controls", TouchControls.NEVER)
	assert_ne(Settings.key_label("interact"), "USE")


func test_a_real_key_press_hides_the_controls_in_auto() -> void:
	Settings.set_value("touch_controls", TouchControls.AUTO)
	TouchControls._seen_touch = true
	TouchControls.refresh_active()
	assert_true(TouchControls.active)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W  # a real key press carries both
	key.pressed = true
	TouchControls._input(key)
	assert_false(TouchControls.active, "a keyboard player gets the screen back")
	var touch_key := TouchControls.key_event(KEY_ENTER, true)
	TouchControls._seen_touch = true
	TouchControls.refresh_active()
	TouchControls._input(touch_key)
	assert_true(TouchControls.active, "the controls' own key presses do not count")


# ------------------------------------------------------------------ buttons and stick

func test_holding_the_sword_button_presses_attack_until_lifted() -> void:
	_play_layout()
	var sword := _button("attack")
	assert_false(sword.is_empty(), "the play layout has a sword button")
	_touch(0, sword["center"], true)
	assert_true(Input.is_action_pressed("attack"))
	_touch(0, sword["center"], false)
	assert_false(Input.is_action_pressed("attack"))


func test_walking_and_guarding_at_once_with_two_fingers() -> void:
	_play_layout()
	var guard := _button("block")
	var start := Vector2(60, 200)
	_touch(0, start, true)
	_drag(0, start + Vector2(40, 0))
	_touch(1, guard["center"], true)
	assert_true(Input.is_action_pressed("block"), "the second finger guards")
	assert_gt(Input.get_vector("move_left", "move_right", "move_up", "move_down").x, 0.9, "the first finger still walks")
	_touch(0, start, false)
	assert_eq(Input.get_vector("move_left", "move_right", "move_up", "move_down"), Vector2.ZERO, "lifting the thumb stops")
	_touch(1, guard["center"], false)


func test_a_tap_beside_the_buttons_on_the_right_does_not_start_the_stick() -> void:
	_play_layout()
	var view := TouchControls.get_viewport().get_visible_rect().size
	_touch(0, Vector2(view.x * 0.6, view.y * 0.3), true)
	assert_eq(TouchControls._stick_finger, -1)
	_touch(0, Vector2(view.x * 0.6, view.y * 0.3), false)


func test_rune_buttons_appear_only_for_runes_you_carry() -> void:
	_play_layout()
	for slot in range(1, 4):
		assert_eq(_button("rune_%d" % slot).is_empty(), Runes.in_slot(slot).is_empty())


func test_left_handed_mirrors_the_layout() -> void:
	_play_layout()
	var right_handed: Vector2 = _button("attack")["center"]
	Settings.set_value("touch_left_handed", true)
	TouchControls._layout()
	var left_handed: Vector2 = _button("attack")["center"]
	Settings.set_value("touch_left_handed", false)
	assert_lt(left_handed.x, right_handed.x / 2.0)


func test_over_a_panel_the_buttons_become_ok_and_back_with_the_panels_extras() -> void:
	Settings.set_value("touch_controls", TouchControls.ALWAYS)
	var game := ConveyorGame.new()
	add_child_autofree(game)
	game.open_game("dump_line")
	TouchControls.mode = TouchControls.Mode.PANEL
	TouchControls._layout()
	assert_false(_button("ok").is_empty())
	assert_false(_button("back").is_empty())
	assert_false(_button("digit_4").is_empty(), "the conveyor's four bins get numbered buttons")
	assert_true(_button("up").is_empty(), "no arrows where none are needed")
	game.leave()


# ------------------------------------------------------------------ boards answer taps

func _open(game: MiniGame, puzzle_id: String) -> MiniGame:
	add_child_autofree(game)
	game.open_game(puzzle_id)
	await wait_process_frames(2)
	return game


func test_tapping_a_memory_card_turns_it() -> void:
	var game: MemoryGame = await _open(MemoryGame.new(), "hazmat_pairs")
	var rows := ceili(game.board.cards.size() / float(MemoryGame.COLUMNS))
	var total := Vector2(MemoryGame.COLUMNS * (MemoryGame.CARD.x + 4) - 4, rows * (MemoryGame.CARD.y + 4) - 4)
	var origin := ((game._board.size - total) / 2.0).floor()
	assert_eq(game.card_at(origin + Vector2(3, 3)), 0)
	game._board_tap(origin + Vector2(MemoryGame.CARD.x + 8, 3))
	assert_eq(game.cursor, 1)
	assert_true(game.board.cards[1]["up"], "the tapped card is face up")


func test_tapping_a_circuit_tile_turns_it() -> void:
	var game: CircuitGame = await _open(CircuitGame.new(), "shed_fusebox")
	var origin := ((game._board.size - Vector2(game.board.width, game.board.height) * CircuitGame.CELL) / 2.0).floor()
	var cell := Vector2i(1, 1)
	var before := game.board.piece(cell)
	game._board_tap(origin + Vector2(cell) * CircuitGame.CELL + Vector2(5, 5))
	assert_eq(game.cursor, cell)
	assert_true(game.board.piece(cell) != before or game.phase() == MiniGame.Phase.WON, "the tile turned")


func test_tapping_the_bottom_of_a_lock_dial_counts_up() -> void:
	var game: LockGame = await _open(LockGame.new(), "halden_safe")
	var total := Vector2(game.digits.size() * (LockGame.DIAL.x + 8) - 8, LockGame.DIAL.y)
	var origin := ((game._board.size - total) / 2.0).floor() - Vector2(0, 8)
	var second := origin + Vector2(LockGame.DIAL.x + 8, 0)
	game._board_tap(second + Vector2(10, LockGame.DIAL.y - 4))
	assert_eq(game.selected, 1)
	assert_eq(game.digits[1], 1)
	game._board_tap(second + Vector2(10, 4))
	game._board_tap(second + Vector2(10, 4))
	assert_eq(game.digits[1], 9, "the top half counts down, and wraps")


func test_tapping_a_signal_light_presses_it() -> void:
	var game: SignalGame = await _open(SignalGame.new(), "radio_handshake")
	assert_eq(game.light_at(game._board.size / 2.0 + Vector2(42, 0)), 1)
	assert_eq(game.light_at(Vector2(2, 2)), -1)


func test_tapping_a_mix_box_sets_the_amount() -> void:
	var game: MixGame = await _open(MixGame.new(), "compost_mix")
	var first: Dictionary = game.ingredients[0]
	game._board_tap(Vector2(190 + 2 * (MixGame.BLOCK.x + 2) + 3, 6 + 4))
	assert_eq(int(game.amounts[first["id"]]), 3)
	game._board_tap(Vector2(190 + 2 * (MixGame.BLOCK.x + 2) + 3, 6 + 4))
	assert_eq(int(game.amounts[first["id"]]), 2, "tapping the top box again takes one off")


# ------------------------------------------------------------------ the buttons reach the panels

func test_the_panel_buttons_speak_to_the_built_in_ui_actions_too() -> void:
	# Regression: sent from a made-up device, the keys never matched the
	# built-in ui_cancel and ui_ arrows, so BACK and the arrows did nothing on
	# puzzle boards.
	var back := TouchControls.key_event(KEY_ESCAPE, true)
	assert_true(back.is_action_pressed("ui_cancel"), "BACK leaves a board")
	assert_true(back.is_action_pressed("menu"), "BACK closes the menu")
	var up := TouchControls.key_event(KEY_UP, true)
	assert_true(up.is_action_pressed("ui_up"), "the arrows steer boards and menus")
	var one := TouchControls.key_event(KEY_1, true)
	assert_eq(one.keycode, KEY_1, "numbered panels read the key itself")
	assert_true(TouchControls.action_event("interact", true).is_action_pressed("interact"), "OK confirms")


# ------------------------------------------------------------------ phone comforts

func test_battery_saver_caps_the_frame_rate() -> void:
	Settings.set_value("battery_saver", true)
	assert_eq(Engine.max_fps, Settings.BATTERY_SAVER_FPS)
	Settings.set_value("battery_saver", false)
	assert_eq(Engine.max_fps, 0, "uncapped again")


func test_putting_the_app_away_saves_mutes_and_coming_back_restores_the_sound() -> void:
	var master := AudioServer.get_bus_index("Master")
	WebPlatform.on_page_hidden()
	assert_true(WebPlatform.is_hidden())
	assert_true(AudioServer.is_bus_mute(master), "quiet while away")
	WebPlatform.on_page_shown()
	assert_false(WebPlatform.is_hidden())
	assert_eq(AudioServer.is_bus_mute(master), bool(Settings.value("muted")), "the player's own mute choice comes back")


func test_tapping_the_map_switches_between_the_area_and_the_world() -> void:
	var map := MapTab.new()
	add_child_autofree(map)
	var before: int = map.page
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map._gui_input(click)
	assert_ne(map.page, before)


func test_the_android_back_button_is_the_games_back_not_quit() -> void:
	assert_false(bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "back must not kill the app")
	var back := TouchControls.key_event(KEY_ESCAPE, true)
	assert_true(back.is_action_pressed("menu"), "it opens or closes the menu")
	assert_true(back.is_action_pressed("ui_cancel"), "it leaves a panel")


func test_panel_buttons_stand_beside_the_panel_not_over_it() -> void:
	# Regression: on a phone the buttons covered the menu's map and footer.
	Settings.set_value("touch_controls", TouchControls.ALWAYS)
	var game := ConveyorGame.new()
	add_child_autofree(game)
	game.open_game("dump_line")
	await wait_process_frames(2)
	TouchControls.mode = TouchControls.Mode.PANEL
	TouchControls._layout()
	var frame := game.panel_rect()
	assert_gt(frame.size.x, 0.0)
	for button in TouchControls.buttons:
		var centre: Vector2 = button["center"]
		var reach: float = button["radius"]
		assert_true(centre.x - reach >= frame.end.x - 0.5 or centre.x + reach <= frame.position.x + 0.5, "%s is clear of the panel" % button["id"])
	game.leave()


func test_play_buttons_do_not_overlap_each_other_or_the_use_prompt() -> void:
	_play_layout()
	var view := TouchControls.get_viewport().get_visible_rect().size
	var lane := TouchControls.bottom_lane()
	var prompt := Rect2(lane.x, view.y - 32.0, view.x - lane.x - lane.y, 24.0)  # the HUD's "USE: ..." strip
	var list := TouchControls.buttons
	for i in list.size():
		var a: Dictionary = list[i]
		var box := Rect2(a["center"] - Vector2.ONE * a["radius"], Vector2.ONE * a["radius"] * 2.0)
		assert_false(box.intersects(prompt), "%s is clear of the prompt" % a["id"])
		for j in range(i + 1, list.size()):
			var b: Dictionary = list[j]
			assert_gt((a["center"] as Vector2).distance_to(b["center"]), float(a["radius"]) + float(b["radius"]), "%s and %s apart" % [a["id"], b["id"]])


# ------------------------------------------------------------------ tap anywhere to move on

func _click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func test_a_conversation_has_no_buttons_and_moves_on_with_a_tap_anywhere() -> void:
	Settings.set_value("touch_controls", TouchControls.ALWAYS)
	var box := DialogueBox.new()
	add_child_autofree(box)
	box.show_lines(["One.", "Two."] as Array[String], "")
	await wait_process_frames(2)
	TouchControls.mode = TouchControls.Mode.PANEL
	TouchControls._layout()
	assert_eq(TouchControls.buttons.size(), 0, "no OK or SKIP over a conversation")
	box._typing.kill()
	box._text.visible_characters = -1
	box._on_panel_gui_input(_click())  # the full-screen catcher feeds the same handler
	assert_true(box.current_text().contains("Two"), "the tap moved it on")


func test_a_solved_board_continues_with_a_tap_anywhere() -> void:
	var game: CircuitGame = await _open(CircuitGame.new(), "shed_fusebox")
	game._win()
	assert_true(game.waiting_to_continue())
	game._on_background_input(_click())
	assert_eq(game.phase(), MiniGame.Phase.IDLE, "tapping the screen continued")


func test_the_phones_volume_buttons_do_not_hide_the_touch_controls() -> void:
	# Regression: a volume press counted as a keyboard and switched the screen
	# to desktop scaling (black borders, lower resolution).
	Settings.set_value("touch_controls", TouchControls.AUTO)
	TouchControls._seen_touch = true
	TouchControls.refresh_active()
	for code in [KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_VOLUMEMUTE, KEY_MEDIAPLAY]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		TouchControls._input(key)
	assert_true(TouchControls.active, "still on touch")
	assert_eq(get_tree().root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND, "still filling the phone's screen")
