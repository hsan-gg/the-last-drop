extends GutTest
## Sorting, puzzles and field checks happen in the world: time does not stop,
## your health is on the panel, and a zombie's blow knocks you away from it.

const SORTING_SCENE := preload("res://ui/sorting/sorting_challenge.tscn")


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


func test_sorting_does_not_stop_time() -> void:
	var sorting = SORTING_SCENE.instantiate()
	add_child_autofree(sorting)
	var items: Array[String] = ["scrap_metal", "battery"]
	sorting.open("pile", items)
	assert_true(sorting.visible)
	assert_false(get_tree().paused, "zombies keep coming while you sort")


func test_a_blow_from_outside_knocks_you_off_the_pile() -> void:
	var sorting = SORTING_SCENE.instantiate()
	add_child_autofree(sorting)
	var items: Array[String] = ["scrap_metal", "battery", "cardboard"]
	sorting.open("pile", items)
	sorting.choose_bin(SortingRules.correct_bin("scrap_metal"))
	EventBus.player_hit.emit("hit", 8)
	assert_false(sorting.visible, "the pile is left")
	assert_eq(Inventory.count("scrap_metal"), 1, "what you sorted is kept")


func test_a_wrong_bin_does_not_knock_you_off() -> void:
	var sorting = SORTING_SCENE.instantiate()
	add_child_autofree(sorting)
	var items: Array[String] = ["battery", "cardboard"]
	sorting.open("pile", items)
	sorting.choose_bin(SortingRules.BIN_COMPOST)
	assert_true(sorting.visible, "your own mistake costs health, not the pile")


func test_puzzles_do_not_stop_time_and_show_health() -> void:
	var panel := PuzzlePanel.new()
	add_child_autofree(panel)
	panel.open_puzzle("compost_layers")
	assert_true(panel.visible)
	assert_false(get_tree().paused)
	assert_not_null(panel._health_meter, "health is shown on the panel")
	EventBus.player_hit.emit("hit", 8)
	assert_false(panel.visible, "a blow closes it")


func test_the_player_stands_still_while_a_panel_is_open() -> void:
	var panel := PuzzlePanel.new()
	add_child_autofree(panel)
	assert_false(Modal.any_open(get_tree()))
	panel.open_puzzle("compost_layers")
	assert_true(Modal.any_open(get_tree()))
	panel.leave()
	assert_false(Modal.any_open(get_tree()))
