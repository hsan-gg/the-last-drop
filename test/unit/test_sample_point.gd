extends GutTest
## Water test points: each strip is a new sample once, and three finish the set.

const POINT_SCENE := preload("res://world/sample_point.tscn")


func before_each() -> void:
	GameState.reset()


func _point(sample_id: String) -> SamplePoint:
	var point: SamplePoint = POINT_SCENE.instantiate()
	point.sample_id = sample_id
	point.dialogue_id = "sample_%s" % sample_id
	add_child_autofree(point)
	return point


func test_testing_a_point_counts_once() -> void:
	var point := _point("a")
	point.interact(null)
	point.interact(null)
	assert_eq(GameState.get_counter("samples"), 1)
	assert_true(point.is_tested())
	assert_eq(point.prompt_text, "Read the strip again")


func test_three_points_finish_the_set() -> void:
	for sample_id in ["a", "b"]:
		_point(sample_id).interact(null)
	assert_false(GameState.has_flag(SamplePoint.ALL_DONE_FLAG))
	_point("c").interact(null)
	assert_true(GameState.has_flag(SamplePoint.ALL_DONE_FLAG))


func test_each_point_plays_its_own_dialogue() -> void:
	watch_signals(EventBus)
	_point("b").interact(null)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["sample_b"])
