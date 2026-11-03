extends Node
## Global combat switches. Enemies only exist while a real run is under way:
## SceneManager.new_game() turns them on, so tests and tools that load an area
## directly never get chased.

var enemies_enabled := false


## How many zombies are actively after the player (chasing or about to strike).
func hunters() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.state() in [Enemy.State.CHASE, Enemy.State.WINDUP, Enemy.State.STRIKE]:
			count += 1
	return count
