extends GutTest
## The end-of-region generator and the lamps that come on with it, toxic
## puddles, and difficulty-scaled spawns.

const GENERATOR_SCENE := preload("res://world/region_generator.tscn")
const AREA_SCENE := preload("res://world/outpost.tscn")
const DUMP_SCENE := preload("res://world/dump.tscn")


func before_each() -> void:
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()
	Progress.reset()
	Settings.reset_all()
	Difficulty.current_id = Difficulty.DEFAULT_ID


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)
	Progress.reset()
	Difficulty.current_id = Difficulty.DEFAULT_ID
	Settings.reset_all()
	Combat.enemies_enabled = false
	get_tree().paused = false


func _generator() -> RegionGenerator:
	var generator: RegionGenerator = GENERATOR_SCENE.instantiate()
	generator.region_id = "outpost"
	add_child_autofree(generator)
	return generator


func test_it_will_not_start_while_zombies_remain() -> void:
	var generator := _generator()
	generator.interact(null)
	assert_false(generator.is_lit())
	assert_gt(RegionGenerator.zombies_left("outpost"), 0)


func test_it_starts_once_the_region_is_clear_and_pays_out() -> void:
	for index in Content.enemy_count("outpost"):
		GameState.set_flag("slain_outpost_%d_0" % index)
	Survival.damage(40.0)
	watch_signals(EventBus)
	var generator := _generator()
	generator.interact(null)
	assert_true(generator.is_lit())
	assert_signal_emitted_with_parameters(EventBus, "region_lit", ["outpost"])
	assert_eq(Survival.health(), Survival.max_health(), "fully healed")
	assert_gt(Progress.xp + (Progress.level - 1) * 100, 0, "XP awarded")
	assert_true(GameState.has_flag("region_lit_outpost"))


func test_starting_it_twice_pays_once() -> void:
	for index in Content.enemy_count("outpost"):
		GameState.set_flag("slain_outpost_%d_0" % index)
	var generator := _generator()
	generator.interact(null)
	var xp_after := Progress.xp + Progress.level
	generator.interact(null)
	assert_eq(Progress.xp + Progress.level, xp_after)


func test_lamps_come_on_when_the_region_lights_up() -> void:
	Combat.enemies_enabled = false
	var area: Node = add_child_autofree(AREA_SCENE.instantiate())
	await wait_physics_frames(2)
	var lamps := area.find_children("*", "Lamp", true, false)
	assert_gt(lamps.size(), 0)
	for lamp: Lamp in lamps:
		assert_false(lamp.is_on())
	EventBus.region_lit.emit("outpost")
	await wait_seconds(2.4)
	for lamp: Lamp in lamps:
		assert_true(lamp.is_on())


func test_a_region_that_is_already_lit_loads_lit() -> void:
	GameState.set_flag("region_lit_outpost")
	var area: Node = add_child_autofree(AREA_SCENE.instantiate())
	await wait_physics_frames(2)
	for lamp: Lamp in area.find_children("*", "Lamp", true, false):
		assert_true(lamp.is_on())


func test_every_region_has_a_generator_and_lamps() -> void:
	for area_id in ["outpost", "factory", "dump", "river"]:
		var entities: Dictionary = Content.area(area_id)["entities"]
		assert_eq(entities["N"]["scene"], "region_generator", area_id)
		assert_eq(entities["N"]["props"]["region_id"], area_id)
		assert_eq(entities["L"]["scene"], "lamp", area_id)
		assert_true(Content.area(area_id).has("lit_tint"), area_id)


func test_harder_difficulties_bring_bigger_packs() -> void:
	Combat.enemies_enabled = true
	var counts := {}
	for level in ["easy", "medium", "hard", "hardcore"]:
		Difficulty.current_id = level
		GameState.reset()
		GameState.run_seed = 4242
		var area: Node = DUMP_SCENE.instantiate()
		add_child(area)
		await wait_physics_frames(2)
		counts[level] = GameState.get_counter("spawned_dump")
		area.queue_free()
		await wait_physics_frames(2)
	assert_eq(counts["medium"], Content.enemy_count("dump"))
	assert_gt(counts["hard"], counts["medium"])
	assert_gt(counts["hardcore"], counts["hard"])
	assert_gte(counts["medium"], counts["easy"])
