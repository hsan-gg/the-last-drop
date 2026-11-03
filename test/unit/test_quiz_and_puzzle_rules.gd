extends GutTest
## Rules and data for Field Check quizzes and ordering puzzles.


func before_each() -> void:
	GameState.reset()


func test_every_quiz_is_well_formed() -> void:
	var seen := {}
	for quiz: Dictionary in Content.quizzes():
		assert_false(seen.has(quiz["id"]), "duplicate quiz id %s" % quiz["id"])
		seen[quiz["id"]] = true
		assert_false(Content.lesson(quiz["lesson_id"]).is_empty(), "%s: no lesson %s" % [quiz["id"], quiz["lesson_id"]])
		assert_eq(quiz["options"].size(), 3, quiz["id"])
		var answer := int(quiz["answer"])
		assert_true(answer >= 0 and answer < 3, "%s answer out of range" % quiz["id"])
		assert_false(String(quiz["explanation"]).is_empty(), quiz["id"])


func test_correct_answers_are_not_always_the_same_position() -> void:
	var positions := {}
	for quiz: Dictionary in Content.quizzes():
		positions[int(quiz["answer"])] = true
	assert_eq(positions.size(), 3, "answers should use all three positions")


func test_pick_returns_a_question_about_the_given_lessons() -> void:
	var quiz := QuizRules.pick(["battery_leak"])
	assert_eq(quiz["lesson_id"], "battery_leak")


func test_pick_skips_answered_questions_and_unknown_lessons() -> void:
	GameState.set_flag(QuizRules.ANSWERED_FLAG_FORMAT % "q_battery")
	assert_eq(QuizRules.pick(["battery_leak"]), {})
	assert_eq(QuizRules.pick(["no_such_lesson"]), {})
	assert_eq(QuizRules.pick([]), {})


func test_is_correct_checks_the_answer_index() -> void:
	var quiz := QuizRules.pick(["battery_leak"])
	assert_true(QuizRules.is_correct(quiz, int(quiz["answer"])))
	assert_false(QuizRules.is_correct(quiz, (int(quiz["answer"]) + 1) % 3))
	assert_false(QuizRules.is_correct({}, 0))


func test_every_puzzle_is_well_formed() -> void:
	for puzzle_id in ["hazard_route", "waste_hierarchy"]:
		var puzzle := Content.puzzle(puzzle_id)
		assert_false(puzzle.is_empty(), puzzle_id)
		assert_between(puzzle["steps"].size(), 3, 5, puzzle_id)
		for key in ["title", "prompt", "explanation"]:
			assert_false(String(puzzle[key]).is_empty(), "%s missing %s" % [puzzle_id, key])


func test_terminals_name_real_puzzles() -> void:
	for area_id in ["factory", "dump"]:
		var props: Dictionary = Content.area(area_id)["entities"]["K"]["props"]
		assert_false(Content.puzzle(props["puzzle_id"]).is_empty(), area_id)


func _steps() -> Array[String]:
	return ["one", "two", "three", "four"]


func test_options_are_shuffled_but_complete() -> void:
	var puzzle := OrderPuzzle.new(_steps(), 7)
	var options := puzzle.options()
	assert_ne(options, _steps(), "never hand over the answer")
	options.sort()
	var expected := _steps()
	expected.sort()
	assert_eq(options, expected)


func test_the_same_seed_shuffles_the_same_way() -> void:
	assert_eq(OrderPuzzle.new(_steps(), 5).options(), OrderPuzzle.new(_steps(), 5).options())


func test_the_right_order_solves_it() -> void:
	var puzzle := OrderPuzzle.new(_steps(), 3)
	for step in _steps():
		assert_true(puzzle.choose(step)["correct"])
	assert_true(puzzle.is_solved())
	assert_eq(puzzle.mistakes(), 0)


func test_a_wrong_pick_starts_over_and_counts_a_mistake() -> void:
	var puzzle := OrderPuzzle.new(_steps(), 3)
	puzzle.choose("one")
	puzzle.choose("two")
	assert_eq(puzzle.placed(), ["one", "two"] as Array[String])
	var result := puzzle.choose("four")
	assert_false(result["correct"])
	assert_eq(puzzle.placed(), [] as Array[String])
	assert_eq(puzzle.mistakes(), 1)
	assert_false(puzzle.is_solved())
