extends Node
## Global combat switches. Enemies only exist while a real run is under way:
## SceneManager.new_game() turns them on, so tests and tools that load an area
## directly never get chased.

var enemies_enabled := false
