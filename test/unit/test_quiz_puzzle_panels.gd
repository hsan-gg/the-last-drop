extends GutTest
## The Field Check and puzzle panels, driven the way the player drives them.

var _quiz_panel: QuizPanel
var _puzzle_panel: PuzzlePanel


func before_each() -> void:
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()
	_quiz_panel = QuizPanel.new()
	_quiz_panel.pauses_game = false
	add_child_autofree(_quiz_panel)
	_puzzle_panel = PuzzlePanel.new()
	_puzzle_panel.pauses_game = false
	add_child_autofree(_puzzle_panel)


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)
	get_tree().paused = false


func _wrong_index(quiz: Dictionary) -> int:
	return (int(quiz["answer"]) + 1) % 3


func test_a_correct_answer_refreshes_water_and_counts() -> void:
	Survival.tick(200.0)
	var water_before := Survival.water()
	_quiz_panel.open_quiz(QuizRules.pick(["battery_leak"]))
	assert_eq(_quiz_panel.phase(), QuizPanel.Phase.ASKING)
	_quiz_panel.answer(int(_quiz_panel.current_quiz()["answer"]))
	assert_eq(_quiz_panel.phase(), QuizPanel.Phase.FEEDBACK)
	assert_gt(Survival.water(), water_before)
	assert_eq(GameState.get_counter("quiz_correct"), 1)


func test_a_wrong_answer_teaches_without_a_penalty() -> void:
	_quiz_panel.open_quiz(QuizRules.pick(["battery_leak"]))
	var health := Survival.health()
	_quiz_panel.answer(_wrong_index(_quiz_panel.current_quiz()))
	assert_eq(GameState.get_counter("quiz_wrong"), 1)
	assert_eq(GameState.get_counter("quiz_correct"), 0)
	assert_eq(Survival.health(), health, "no damage for a wrong answer")


func test_a_question_is_asked_only_once() -> void:
	_quiz_panel.open_quiz(QuizRules.pick(["battery_leak"]))
	_quiz_panel.answer(0)
	_quiz_panel.continue_flow()
	assert_eq(_quiz_panel.phase(), QuizPanel.Phase.IDLE)
	EventBus.quiz_requested.emit(["battery_leak"])
	assert_eq(_quiz_panel.phase(), QuizPanel.Phase.IDLE, "already answered")


func test_finishing_reports_whether_the_answer_was_right() -> void:
	watch_signals(EventBus)
	_quiz_panel.open_quiz(QuizRules.pick(["battery_leak"]))
	_quiz_panel.answer(_wrong_index(_quiz_panel.current_quiz()))
	_quiz_panel.continue_flow()
	assert_signal_emitted_with_parameters(EventBus, "quiz_finished", [false])


func test_the_request_signal_opens_a_quiz_for_those_lessons() -> void:
	EventBus.quiz_requested.emit(["tube_mercury"])
	assert_eq(_quiz_panel.current_quiz()["lesson_id"], "tube_mercury")


func test_a_puzzle_is_solved_by_the_right_order() -> void:
	_puzzle_panel.open_puzzle("waste_hierarchy", 4)
	assert_eq(_puzzle_panel.phase(), PuzzlePanel.Phase.SOLVING)
	for step: String in Content.puzzle("waste_hierarchy")["steps"]:
		_puzzle_panel.choose(step)
	assert_eq(_puzzle_panel.phase(), PuzzlePanel.Phase.SOLVED)
	assert_true(GameState.has_flag("puzzle_waste_hierarchy_solved"))


func test_a_wrong_step_restarts_and_counts_a_mistake() -> void:
	_puzzle_panel.open_puzzle("hazard_route", 4)
	var steps: Array = Content.puzzle("hazard_route")["steps"]
	_puzzle_panel.choose(steps[0])
	_puzzle_panel.choose(steps[2])
	assert_eq(GameState.get_counter("puzzle_mistakes"), 1)
	assert_eq(_puzzle_panel.phase(), PuzzlePanel.Phase.SOLVING)
	assert_false(GameState.has_flag("puzzle_hazard_route_solved"))


func test_leaving_a_puzzle_reports_unsolved() -> void:
	watch_signals(EventBus)
	_puzzle_panel.open_puzzle("hazard_route", 4)
	_puzzle_panel.leave()
	assert_signal_emitted_with_parameters(EventBus, "puzzle_finished", ["hazard_route", false])
	assert_eq(_puzzle_panel.phase(), PuzzlePanel.Phase.IDLE)


func test_finishing_a_solved_puzzle_reports_success() -> void:
	watch_signals(EventBus)
	_puzzle_panel.open_puzzle("hazard_route", 4)
	for step: String in Content.puzzle("hazard_route")["steps"]:
		_puzzle_panel.choose(step)
	_puzzle_panel.continue_flow()
	assert_signal_emitted_with_parameters(EventBus, "puzzle_finished", ["hazard_route", true])


func test_the_journal_lists_the_goal_and_side_quests() -> void:
	GameState.set_flag("area_outpost_reached")
	var journal := QuestJournal.new()
	journal.pauses_game = false
	add_child_autofree(journal)
	var text := journal.text_for("outpost")
	assert_string_contains(text, "MAIN GOAL")
	assert_string_contains(text, "Sharp Eye")
	assert_string_contains(text, "0/6")
	GameState.add_to_counter("sort_correct", 6)
	assert_string_contains(journal.text_for("outpost"), "DONE")
