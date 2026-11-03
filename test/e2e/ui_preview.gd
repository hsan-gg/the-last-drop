extends Node
## Preview-only scene: cycles the quiz, puzzle and journal panels so they can be
## screenshotted in a real build. Each state lasts three seconds.

const STEP_SECONDS := 3.0

var _quiz := QuizPanel.new()
var _puzzle := PuzzlePanel.new()
var _journal := QuestJournal.new()
var _equipment := EquipmentPanel.new()
var _step := 0


func _ready() -> void:
	for panel: OverlayPanel in [_quiz, _puzzle, _journal, _equipment]:
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
			Gear.grant("rusty_sword")
			Gear.grant("scrap_blade")
			Gear.grant("hard_hat")
			Gear.grant("tire_vest")
			Progress.add_xp(150)
			GameState.add_to_counter("kills", 3)
			_equipment.toggle()
		1:
			_equipment.next_slot()
		2:
			_equipment.toggle()
			_journal.toggle()
		3:
			_journal._show_all = true
			_journal.refresh()
	_step += 1
