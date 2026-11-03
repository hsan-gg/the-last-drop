extends Node
## Preview-only scene: cycles the quiz, puzzle and journal panels so they can be
## screenshotted in a real build. Each state lasts three seconds.

const STEP_SECONDS := 3.0

var _quiz := QuizPanel.new()
var _puzzle := PuzzlePanel.new()
var _journal := QuestJournal.new()
var _step := 0


func _ready() -> void:
	for panel: OverlayPanel in [_quiz, _puzzle, _journal]:
		panel.pauses_game = false
		add_child(panel)
	for area_id in ["outpost", "factory", "dump"]:
		GameState.set_flag("area_%s_reached" % area_id)
	GameState.add_to_counter("sort_correct", 4)
	GameState.add_to_counter("hazard_correct", 2)
	GameState.set_flag("quest_quick_learner_done")
	var timer := Timer.new()
	timer.wait_time = STEP_SECONDS
	timer.timeout.connect(_advance)
	add_child(timer)
	timer.start()
	_advance()


func _advance() -> void:
	match _step:
		0:
			_quiz.open_quiz(QuizRules.pick(["battery_leak"]))
		1:
			_quiz.answer(0)
		2:
			_quiz.continue_flow()
			_puzzle.open_puzzle("waste_hierarchy", 3)
			var steps: Array = Content.puzzle("waste_hierarchy")["steps"]
			_puzzle.choose(steps[0])
			_puzzle.choose(steps[1])
		3:
			_puzzle.leave()
			_journal.toggle()
	_step += 1
