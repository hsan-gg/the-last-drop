extends GutTest
## The four difficulty levels and what they change.


func before_each() -> void:
	Settings.reset_all()
	Difficulty.current_id = Difficulty.DEFAULT_ID


func after_each() -> void:
	Settings.reset_all()
	Difficulty.current_id = Difficulty.DEFAULT_ID
	Lives.reset()
	Survival.reset()


func test_there_are_four_levels_and_medium_is_the_default() -> void:
	var ids: Array[String] = []
	for level: Dictionary in Difficulty.all():
		ids.append(level["id"])
	assert_eq(ids, ["easy", "medium", "hard", "hardcore"] as Array[String])
	assert_eq(Difficulty.current()["id"], "medium")


func test_medium_changes_nothing() -> void:
	for key in ["enemy_hp", "enemy_damage", "enemy_speed", "enemy_windup", "spawn", "penalty", "xp", "water_decay", "regen", "drops"]:
		assert_eq(Difficulty.value(key), 1.0, key)
	assert_eq(Difficulty.value("lives"), 3.0)


func test_each_step_up_is_harder() -> void:
	var order := ["easy", "medium", "hard", "hardcore"]
	for key in ["enemy_hp", "enemy_damage", "enemy_speed", "spawn", "penalty", "water_decay"]:
		var last := 0.0
		for id in order:
			var value := float(Difficulty.definition(id)[key])
			assert_gt(value, last, "%s should rise at %s" % [key, id])
			last = value
	var lives := 99.0
	for id in order:
		assert_lt(float(Difficulty.definition(id)["lives"]), lives, "lives fall at %s" % id)
		lives = float(Difficulty.definition(id)["lives"])


func test_hardcore_is_brutal() -> void:
	var hardcore := Difficulty.definition("hardcore")
	assert_eq(int(hardcore["lives"]), 1)
	assert_eq(float(hardcore["regen"]), 0.0, "no healing over time")
	assert_gte(float(hardcore["enemy_hp"]), 3.0)
	assert_gte(float(hardcore["enemy_damage"]), 3.0)
	assert_gte(float(hardcore["spawn"]), 2.0)
	assert_lte(float(hardcore["parry_window"]), 0.1)


func test_choosing_a_level_is_remembered() -> void:
	Difficulty.select("hard")
	assert_eq(Settings.value("difficulty"), "hard")
	Difficulty.current_id = "medium"
	Difficulty.begin_run()
	assert_eq(Difficulty.current_id, "hard")


func test_an_unknown_level_is_ignored() -> void:
	Difficulty.select("impossible")
	assert_eq(Difficulty.current_id, "medium")


func test_lives_follow_the_difficulty() -> void:
	Difficulty.select("hardcore")
	Lives.start_run()
	assert_eq(Lives.lives, 1)
	Difficulty.select("easy")
	Lives.start_run()
	assert_eq(Lives.lives, 5)
	assert_eq(Lives.max_lives, 5)


func test_xp_is_scaled_by_difficulty() -> void:
	Progress.reset()
	Difficulty.select("easy")
	Difficulty.begin_run()
	Progress.add_xp(40)
	assert_eq(Progress.xp, 50, "Easy pays 25% more XP")
	Progress.reset()


func test_hardcore_stops_passive_healing() -> void:
	Survival.set_process(false)
	Difficulty.select("hardcore")
	Difficulty.begin_run()
	Survival.reset()
	Survival.damage(40.0)
	var before := Survival.health()
	Survival.tick(30.0)
	assert_eq(Survival.health(), before)
	Survival.set_process(true)


func test_hard_zombies_are_stronger_than_medium_ones() -> void:
	Combat.enemies_enabled = true
	var medium: Enemy = preload("res://world/enemy.tscn").instantiate()
	medium.enemy_id = "brute"
	add_child_autofree(medium)
	Difficulty.select("hard")
	Difficulty.begin_run()
	var hard: Enemy = preload("res://world/enemy.tscn").instantiate()
	hard.enemy_id = "brute"
	add_child_autofree(hard)
	Combat.enemies_enabled = false
	assert_gt(hard.hp(), medium.hp())
	assert_gt(float(hard.definition()["damage"]), float(medium.definition()["damage"]))


func test_the_picker_defaults_to_the_saved_level_and_confirms_it() -> void:
	Settings.set_value("difficulty", "hard")
	var picker := DifficultyPicker.new()
	picker.pauses_game = false
	add_child_autofree(picker)
	assert_eq(picker.selected_id(), "hard")
	watch_signals(picker)
	picker.select(3)
	picker.confirm()
	assert_signal_emitted_with_parameters(picker, "chosen", ["hardcore"])
