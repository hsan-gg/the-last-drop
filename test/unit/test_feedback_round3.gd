extends GutTest
## Leaving the sorting screen, conversations that end when you walk off, and
## zombies that stand their ground.

const SORTING_SCENE := preload("res://ui/sorting/sorting_challenge.tscn")
const DIALOGUE_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")


func before_each() -> void:
	Survival.set_process(false)
	Survival.reset()
	GameState.reset()
	Inventory.clear()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)
	Combat.enemies_enabled = false
	get_tree().paused = false


func test_esc_leaves_the_pile_and_keeps_the_rest_for_later() -> void:
	var sorting = SORTING_SCENE.instantiate()
	sorting.pauses_game = false
	add_child_autofree(sorting)
	var items: Array[String] = ["scrap_metal", "battery", "cardboard"]
	sorting.open("test_pile", items)
	sorting.choose_bin(SortingRules.correct_bin("scrap_metal"))
	watch_signals(EventBus)
	sorting.leave()
	assert_false(sorting.visible)
	assert_signal_emitted_with_parameters(EventBus, "sorting_left", ["test_pile", ["battery", "cardboard"]])
	assert_signal_not_emitted(EventBus, "sorting_finished")
	assert_eq(Inventory.count("scrap_metal"), 1, "what was recovered is kept")
	assert_false(GameState.has_flag("pile_sorted_test_pile"))


func test_a_left_pile_offers_only_what_is_left() -> void:
	var pile: ScrapPile = preload("res://world/scrap_pile.tscn").instantiate()
	pile.pile_id = "test_pile"
	pile.item_ids.assign(["scrap_metal", "battery", "cardboard"])
	add_child_autofree(pile)
	EventBus.sorting_left.emit("test_pile", ["battery"])
	assert_eq(pile.item_ids, ["battery"] as Array[String])


func test_walking_away_ends_the_conversation() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var box = DIALOGUE_SCENE.instantiate()
	add_child_autofree(box)
	box.show_lines(["Hello there.", "And more."] as Array[String], "")
	assert_true(box.is_open())
	player.global_position += Vector2(30, 0)
	await wait_frames(2)
	assert_true(box.is_open(), "a small step is fine")
	watch_signals(EventBus)
	player.global_position += Vector2(80, 0)
	await wait_frames(2)
	assert_false(box.is_open(), "walking off closes it")
	assert_signal_emitted(EventBus, "dialogue_interrupted")


func test_the_player_cannot_shove_a_zombie() -> void:
	Combat.enemies_enabled = true
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var enemy: Enemy = preload("res://world/enemy.tscn").instantiate()
	enemy.position = Vector2(14, 0)
	add_child_autofree(enemy)
	await wait_physics_frames(2)
	assert_true(player.collision_mask & enemy.collision_layer != 0, "the player collides with zombies")
	var start := enemy.global_position
	for _i in 30:
		player.velocity = Vector2(80, 0)
		player.move_and_slide()
		await wait_physics_frames(1)
	assert_lt(enemy.global_position.distance_to(start), 3.0, "the zombie was not pushed")


func test_keys_pressed_while_a_scene_fades_in_are_ignored() -> void:
	SceneManager._settle_until = Time.get_ticks_msec() / 1000.0 + 0.3
	assert_true(SceneManager.is_settling(), "an Esc mashed to skip a cutscene must not open the menu")
	SceneManager._settle_until = 0.0
	assert_false(SceneManager.is_settling())
