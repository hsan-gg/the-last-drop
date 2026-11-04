extends GutTest
## Every kind of hands-on puzzle, played to the end the way a player would.

func before_each() -> void:
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()
	Inventory.clear()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)
	Inventory.clear()
	get_tree().paused = false


func _open(game: MiniGame, puzzle_id: String) -> MiniGame:
	add_child_autofree(game)
	game.open_game(puzzle_id)
	assert_eq(game.phase(), MiniGame.Phase.PLAYING, "%s opened" % puzzle_id)
	return game


func test_a_circuit_board_always_has_a_solution_and_starts_unsolved() -> void:
	for seed_value in 20:
		var board := CircuitBoard.new(5, 4, seed_value)
		assert_false(board.is_solved())
		for index in board._solution.size():
			var cell := Vector2i(index % board.width, index / board.width)
			while board.piece(cell) != board._solution[index]:
				board.rotate(cell)
		assert_true(board.is_solved(), "seed %d solves" % seed_value)


func test_the_circuit_game_wins_when_everything_is_joined() -> void:
	var game: CircuitGame = _open(CircuitGame.new(), "shed_fusebox")
	var board := game.board
	for index in board._solution.size():
		var cell := Vector2i(index % board.width, index / board.width)
		while board.piece(cell) != board._solution[index] and game.phase() == MiniGame.Phase.PLAYING:
			game.turn(cell)
	assert_eq(game.phase(), MiniGame.Phase.WON)
	assert_true(GameState.has_flag("puzzle_shed_fusebox_solved"))


func test_a_lock_wants_its_code_and_a_wrong_one_hurts() -> void:
	var game: LockGame = _open(LockGame.new(), "halden_safe")
	var before := Survival.health()
	game.try_code()
	assert_lt(Survival.health(), before, "a wrong code sparks")
	game.digits.assign([1, 4, 7])
	game.try_code()
	assert_eq(game.phase(), MiniGame.Phase.WON)


func test_the_lock_shows_its_clue_only_once_you_have_read_it() -> void:
	var game: LockGame = _open(LockGame.new(), "halden_safe")
	assert_false(game._feedback.text.contains("1-4-7"))
	game.leave()
	GameState.set_flag("note_osei_ledger_read")
	game.open_game("halden_safe")
	assert_true(game._feedback.text.contains("1-4-7"), "the ledger's code is shown")


func test_matching_every_pair_wins_the_memory_game() -> void:
	var game: MemoryGame = _open(MemoryGame.new(), "dump_pairs")
	var by_pair := {}
	for index in game.board.cards.size():
		by_pair.get_or_add(game.board.cards[index]["pair"], []).append(index)
	for pair: Array in by_pair.values():
		game.turn(pair[0])
		game.turn(pair[1])
	assert_eq(game.phase(), MiniGame.Phase.WON)


func test_a_bad_compost_mix_explains_itself_and_a_good_one_works() -> void:
	var game: MixGame = _open(MixGame.new(), "compost_mix")
	game.set_amount("browns", 1)
	game.set_amount("greens", 4)
	game.test_mix()
	assert_true(game._feedback.text.contains("rot"), "too many greens: it rots")
	game.set_amount("browns", 4)
	game.set_amount("greens", 2)
	game.set_amount("water", 1)
	game.set_amount("soil", 1)
	game.test_mix()
	assert_eq(game.phase(), MiniGame.Phase.WON)


func test_sorting_the_conveyor_right_wins_it() -> void:
	var game: ConveyorGame = _open(ConveyorGame.new(), "dump_line")
	while not game.queue.is_empty():
		game.positions[0] = ConveyorGame.BELT_START + 1.0
		game.sort_front(SortingRules.correct_bin(game.queue[0]))
	assert_eq(game.phase(), MiniGame.Phase.WON)


func test_a_missed_conveyor_item_costs_health() -> void:
	var game: ConveyorGame = _open(ConveyorGame.new(), "dump_line")
	var before := Survival.health()
	game.positions[0] = ConveyorGame.BELT_END + 1.0
	game._process(0.01)
	assert_lt(Survival.health(), before)


func test_repeating_the_signal_wins_and_a_slip_replays_it() -> void:
	var game: SignalGame = _open(SignalGame.new(), "radio_handshake")
	game._showing = false
	var wrong := (game.sequence.sequence[0] + 1) % 4
	game.press(wrong)
	assert_true(game._showing, "a wrong light plays the pattern again")
	while game.phase() == MiniGame.Phase.PLAYING:
		game._showing = false
		for light in game.sequence.sequence.duplicate():
			game.press(light)
			if game.phase() != MiniGame.Phase.PLAYING:
				break
	assert_eq(game.phase(), MiniGame.Phase.WON)


func test_a_mini_game_ignores_puzzles_of_another_kind() -> void:
	var game := CircuitGame.new()
	add_child_autofree(game)
	game.open_game("halden_safe")
	assert_eq(game.phase(), MiniGame.Phase.IDLE)


func test_winning_reports_through_puzzle_finished() -> void:
	var game: LockGame = _open(LockGame.new(), "barn_lock")
	watch_signals(EventBus)
	game.digits.assign([2, 2, 0, 8])
	game.try_code()
	game.leave()
	assert_signal_emitted_with_parameters(EventBus, "puzzle_finished", ["barn_lock", true])


func test_every_mini_game_draws_above_the_hud_like_other_panels() -> void:
	for game: MiniGame in [CircuitGame.new(), LockGame.new(), MemoryGame.new(), MixGame.new(), ConveyorGame.new(), SignalGame.new()]:
		assert_eq(game.layer, 16, "%s sits above the HUD" % game.kind)
		assert_eq(game.process_mode, Node.PROCESS_MODE_ALWAYS)
		game.free()


func test_every_memory_puzzle_fits_its_words_whole_at_full_size() -> void:
	# Regression: Jory's seed chart chopped words at eight letters, and the
	# water cycle's long words ("Precipitation") ran off the cards.
	for id in ["hazmat_pairs", "dump_pairs", "seed_pairs", "water_cycle_pairs"]:
		var game: MemoryGame = _open(MemoryGame.new(), id)
		await wait_process_frames(2)
		var grid := game.layout()
		var card: Vector2 = grid["card"]
		assert_eq(grid["text_size"], 8, "%s is drawn at full size" % id)
		assert_gt(card.y, 24.0, "%s cards are tall enough to read" % id)
		for entry: Dictionary in game.board.cards:
			var wrapped := MemoryGame.wrap_words(str(entry["text"]), card.x - MemoryGame.PADDING, grid["text_size"])
			assert_true(wrapped["whole"], "%s: every word of '%s' fits whole" % [id, entry["text"]])
			assert_eq(" ".join(PackedStringArray(wrapped["lines"])), str(entry["text"]))
			assert_lte(wrapped["lines"].size() * MemoryGame.LINE_HEIGHT, card.y, "%s: '%s' fits its card" % [id, entry["text"]])
		assert_true(game.panel_size.y <= 270.0, "the panel fits the screen")
		game.leave()


func test_free_tries_used_stay_used_when_you_leave_and_come_back() -> void:
	var game: MemoryGame = _open(MemoryGame.new(), "water_cycle_pairs")
	var before := game.free_tries_left()
	var first := -1
	var second := -1
	for a in game.board.cards.size():
		for b in range(a + 1, game.board.cards.size()):
			if game.board.cards[a]["text"] != game.board.cards[b]["text"] and not _is_pair(game, a, b):
				first = a
				second = b
				break
		if first >= 0:
			break
	game.turn(first)
	game.turn(second)  # a miss
	assert_eq(game.free_tries_left(), before - 1, "one try used")
	game.leave()
	var again: MemoryGame = _open(MemoryGame.new(), "water_cycle_pairs")
	assert_eq(again.free_tries_left(), before - 1, "still used after leaving: they do not reset")
	again.leave()


func _is_pair(game: MemoryGame, a: int, b: int) -> bool:
	return game.board.cards[a].get("pair") == game.board.cards[b].get("pair")
