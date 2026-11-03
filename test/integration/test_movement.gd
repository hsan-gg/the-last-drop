extends GutTest
## Walls and machines must actually stop the player.

const OUTPOST := preload("res://world/outpost.tscn")
const WALK_FRAMES := 90

var _area: Node
var _player: Player


func before_each() -> void:
	Inventory.clear()
	GameState.reset()
	GameState.set_flag("arrival_outpost_seen")
	Survival.set_process(false)
	Survival.reset()
	_area = add_child_autofree(OUTPOST.instantiate())
	await wait_physics_frames(2)
	_player = _area.find_child("Player", true, false)


func after_each() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Survival.set_process(true)


func _walk(action: String) -> void:
	Input.action_press(action)
	await wait_physics_frames(WALK_FRAMES)
	Input.action_release(action)


func test_the_player_moves_when_a_direction_is_held() -> void:
	var start := _player.global_position
	await _walk("move_right")
	assert_gt(_player.global_position.x, start.x + 10.0)


func test_a_wall_stops_the_player() -> void:
	# The shelter's west wall is tile column 3, so its inner face is at x = 64.
	await _walk("move_left")
	assert_gt(_player.global_position.x, 64.0, "stayed inside the shelter")
	assert_lt(_player.global_position.x, 80.0, "and did reach the wall")


func test_the_map_border_stops_the_player() -> void:
	_player.global_position = Vector2(120, 40)
	await _walk("move_up")
	assert_gt(_player.global_position.y, 16.0, "the top wall row ends at y = 16")


func test_a_solid_machine_stops_the_player() -> void:
	var pile: ScrapPile = _area.find_children("*", "ScrapPile", true, false)[0]
	var blocker_left := pile.global_position.x - pile.blocker_size.x / 2.0
	_player.global_position = Vector2(pile.global_position.x - 40.0, pile.global_position.y + 6.0)
	await wait_physics_frames(2)
	await _walk("move_right")
	assert_lt(_player.global_position.x, blocker_left, "stopped before walking through the pile")


func test_exhaustion_slows_the_player() -> void:
	var start := _player.global_position
	await _walk("move_right")
	var fresh := _player.global_position.x - start.x

	_player.global_position = start
	Survival.tick(100000.0)
	await wait_physics_frames(2)
	await _walk("move_right")
	var tired := _player.global_position.x - start.x
	assert_lt(tired, fresh * 0.8)


func test_the_nearest_interactable_is_highlighted_and_its_prompt_shown() -> void:
	var pile: ScrapPile = _area.find_children("*", "ScrapPile", true, false)[0]
	watch_signals(EventBus)
	_player.global_position = pile.global_position + Vector2(0, 14)
	await wait_physics_frames(4)
	assert_signal_emitted_with_parameters(EventBus, "prompt_changed", ["Sort the scrap pile"])
	assert_eq((pile.get_node("Sprite") as Sprite2D).modulate, Interactable.FOCUS_TINT)

	_player.global_position = pile.global_position + Vector2(200, 0)
	await wait_physics_frames(4)
	assert_eq((pile.get_node("Sprite") as Sprite2D).modulate, Color.WHITE)
