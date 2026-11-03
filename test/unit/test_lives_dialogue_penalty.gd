extends GutTest
## Three lives, conversations that do not freeze the world, and a Field Check
## that bites back, and clear-the-area quests.

const DIALOGUE_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")


func before_each() -> void:
	Survival.set_process(false)
	Survival.reset()
	Gear.reset()
	Progress.reset()
	GameState.reset()
	Lives.reset()


func after_each() -> void:
	Lives.reset()
	Survival.reset()
	Survival.set_process(true)
	Progress.reset()
	get_tree().paused = false


func test_a_run_starts_with_three_lives() -> void:
	Lives.start_run()
	assert_eq(Lives.lives, 3)


func test_collapsing_costs_a_life_and_announces_it() -> void:
	Lives.start_run()
	watch_signals(EventBus)
	Survival.damage(1000.0)
	assert_eq(Lives.lives, 2)
	assert_signal_emitted_with_parameters(EventBus, "life_lost", [2])
	assert_signal_not_emitted(EventBus, "game_over")


func test_losing_the_last_life_ends_the_run() -> void:
	Lives.start_run()
	watch_signals(EventBus)
	for _i in 3:
		Survival.damage(1000.0)
		Survival._grace_until = 0.0  # each collapse is a separate moment
	assert_eq(Lives.lives, 0)
	assert_signal_emitted(EventBus, "game_over")
	assert_false(Lives.active)


func test_lives_do_not_run_out_unless_a_run_has_started() -> void:
	watch_signals(EventBus)
	for _i in 5:
		Survival.damage(1000.0)
		Survival._grace_until = 0.0  # each collapse is a separate moment
	assert_eq(Lives.lives, 3, "tests and tools never lose lives")
	assert_signal_not_emitted(EventBus, "game_over")


func test_a_new_run_restores_the_lives() -> void:
	Lives.start_run()
	Survival.damage(1000.0)
	Lives.start_run()
	assert_eq(Lives.lives, 3)


func _dialogue() -> DialogueBox:
	var box: DialogueBox = DIALOGUE_SCENE.instantiate()
	add_child_autofree(box)
	return box


func test_a_conversation_does_not_pause_the_game() -> void:
	var box := _dialogue()
	box.show_lines(["Hello."] as Array[String], "t")
	assert_true(box.is_open())
	assert_false(get_tree().paused, "the world keeps moving during a conversation")


func test_being_hit_cuts_a_conversation_short() -> void:
	var box := _dialogue()
	watch_signals(EventBus)
	box.show_lines(["Hello.", "More."] as Array[String], "t")
	EventBus.damage_taken.emit(5.0)
	assert_false(box.is_open())
	assert_signal_emitted(EventBus, "dialogue_interrupted")
	assert_signal_not_emitted(EventBus, "dialogue_finished", "an interrupted talk never finishes")


func test_a_wrong_field_check_costs_health() -> void:
	var panel := QuizPanel.new()
	panel.pauses_game = false
	add_child_autofree(panel)
	panel.open_quiz(QuizRules.pick(["battery_leak"]))
	var wrong := (int(panel.current_quiz()["answer"]) + 1) % 3
	var before := Survival.health()
	panel.answer(wrong)
	assert_eq(Survival.health(), before - QuizPanel.WRONG_DAMAGE)


func test_a_right_field_check_costs_nothing() -> void:
	var panel := QuizPanel.new()
	panel.pauses_game = false
	add_child_autofree(panel)
	panel.open_quiz(QuizRules.pick(["battery_leak"]))
	var before := Survival.health()
	panel.answer(int(panel.current_quiz()["answer"]))
	assert_eq(Survival.health(), before)


func test_the_clear_quests_count_the_zombies_in_each_area() -> void:
	for area_id in ["outpost", "factory", "dump", "river"]:
		assert_gt(Content.enemy_count(area_id), 0, area_id)


func test_clearing_an_area_completes_its_quest() -> void:
	var total := Content.enemy_count("outpost")
	for index in total - 1:
		GameState.set_flag("slain_outpost_%d_0" % index)
	assert_false(QuestRules.is_done("clear_outpost"))
	GameState.set_flag("slain_outpost_99_0")
	assert_true(QuestRules.is_done("clear_outpost"))
	assert_false(QuestRules.is_done("clear_factory"), "another area's zombies do not count")


func test_a_pile_always_holds_what_the_repair_needs_and_something_hazardous() -> void:
	ItemDB._ready()
	var guaranteed: Array[String] = ["scrap_metal", "pipe_section"]
	var pool: Array[String] = ["battery", "chemical_can", "tin_can", "cardboard", "glass_jar", "phone", "food_scraps"]
	for seed_value in 25:
		var items := PileBuilder.build(guaranteed, pool, 6, 1, seed_value)
		assert_eq(items.size(), 6)
		assert_true(items.has("scrap_metal") and items.has("pipe_section"), "guaranteed items stay")
		var hazards := 0
		for item_id in items:
			hazards += 1 if ItemDB.is_hazardous(item_id) else 0
		assert_gte(hazards, 1, "a hazard to handle with care")


func test_piles_vary_between_runs_but_not_within_one() -> void:
	var guaranteed: Array[String] = ["scrap_metal"]
	var pool: Array[String] = ["battery", "chemical_can", "tin_can", "cardboard", "glass_jar", "phone", "food_scraps", "paint_tin", "textile_scrap"]
	var first := PileBuilder.build(guaranteed, pool, 6, 1, PileBuilder.seed_for("outpost", 11))
	var again := PileBuilder.build(guaranteed, pool, 6, 1, PileBuilder.seed_for("outpost", 11))
	assert_eq(first, again, "the same run sees the same pile")
	var different := false
	for run_seed in range(12, 40):
		if PileBuilder.build(guaranteed, pool, 6, 1, PileBuilder.seed_for("outpost", run_seed)) != first:
			different = true
	assert_true(different, "another run draws different rubbish")


func test_every_configured_pile_has_a_pool_big_enough() -> void:
	for area_id in ["outpost", "factory", "dump", "river"]:
		for definition: Dictionary in Content.area(area_id)["entities"].values():
			if definition["scene"] != "scrap_pile":
				continue
			var props: Dictionary = definition["props"]
			assert_gte(props["guaranteed"].size() + props["pool"].size(), int(props["count"]), "%s pile is too small" % props["pile_id"])


func test_one_bad_moment_costs_one_life_not_several() -> void:
	Lives.start_run()
	Survival.damage(1000.0)
	Survival.damage(1000.0)
	Survival.damage(1000.0)
	assert_eq(Lives.lives, 2, "the grace after a collapse absorbs the rest")


func test_collapsing_mid_sort_closes_the_pile() -> void:
	Lives.start_run()
	var sorting = preload("res://ui/sorting/sorting_challenge.tscn").instantiate()
	sorting.pauses_game = false
	add_child_autofree(sorting)
	var items: Array[String] = ["battery", "scrap_metal"]
	sorting.open("pile", items)
	Survival.damage(1000.0)
	assert_false(sorting.visible, "knocked out: the sorting screen closes")
	assert_eq(Lives.lives, 2)
