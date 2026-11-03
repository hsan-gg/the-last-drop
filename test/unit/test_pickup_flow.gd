extends GutTest

const PICKUP_SCENE := preload("res://world/item_pickup.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")


func before_each() -> void:
	Inventory.clear()


func test_interacting_with_a_pickup_moves_it_into_the_inventory() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item_id = "battery"
	add_child_autofree(pickup)
	player.global_position = Vector2.ZERO
	pickup.global_position = Vector2.ZERO
	await wait_physics_frames(3)

	player.get_node("Interactor").interact()
	await wait_physics_frames(2)

	assert_eq(Inventory.count("battery"), 1)
	assert_freed(pickup, "pickup")


func test_prompt_is_published_when_near_and_cleared_when_gone() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item_id = "plastic_bottle"
	add_child_autofree(pickup)
	watch_signals(EventBus)
	player.global_position = Vector2.ZERO
	pickup.global_position = Vector2.ZERO
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(EventBus, "prompt_changed", ["Pick up Plastic Bottle"])

	pickup.global_position = Vector2(500, 500)
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(EventBus, "prompt_changed", [""])
