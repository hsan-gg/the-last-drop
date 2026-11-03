extends Node
## Browser test hook, added to a throwaway build only (scripts/playthrough.sh).
## Exposes window.godotDrive(command, argument) to the Playwright script: it can
## report the game's state and move the player next to an object. Everything else
## (interacting, sorting, answering) goes through real keyboard events.

const SORT_KEYS := {"general": "1", "hazardous": "2", "recovery": "3", "compost": "4"}

var _callback: JavaScriptObject


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	_callback = JavaScriptBridge.create_callback(_on_command)
	JavaScriptBridge.get_interface("window").godotDrive = _callback
	_publish({"ready": true})


func _on_command(args: Array) -> void:
	var command := str(args[0])
	var argument := str(args[1]) if args.size() > 1 else ""
	match command:
		"state":
			_publish(_state())
		"goto":
			_publish({"moved": _goto(argument)})
		"damage":
			Survival.damage(float(argument))
			_publish({"damaged": true})
		"peace":
			_peace()
			_publish({"peace": true})
		_:
			_publish({"error": "unknown command %s" % command})


func _publish(data: Dictionary) -> void:
	JavaScriptBridge.eval("window.driveResult = " + JSON.stringify(JSON.stringify(data)))


## Removes every zombie and stops new ones, so scripted runs are deterministic.
func _peace() -> void:
	Combat.enemies_enabled = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()


func _find_all(type_name: String) -> Array:
	return get_tree().root.find_children("*", type_name, true, false)


func _first_visible(type_name: String) -> Node:
	for node in _find_all(type_name):
		if node.visible:
			return node
	return null


func _goto(argument: String) -> bool:
	var parts := argument.split(":")
	var matches := get_tree().current_scene.find_children("*", "AreaExit" if parts[0] == "OnwardGate" else parts[0], true, false)
	if parts[0] == "OnwardGate":
		matches = matches.filter(func(gate: Node) -> bool: return not (gate as AreaExit).required_flag.is_empty())
	var index := int(parts[1]) if parts.size() > 1 else 0
	var players := _find_all("Player")
	if matches.size() <= index or players.is_empty():
		return false
	var target := matches[index] as Node2D
	(players[0] as Node2D).global_position = target.global_position + Vector2(0, 16)
	return true


func _audio_state() -> Dictionary:
	var players := Music.find_children("*", "AudioStreamPlayer", false, false)
	var info := {"players": []}
	for player: AudioStreamPlayer in players:
		info["players"].append({"playing": player.playing, "pos": player.get_playback_position(), "db": player.volume_db, "bus": player.bus, "stream": player.stream != null})
	for bus in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		info[bus] = {"index": index, "db": AudioServer.get_bus_volume_db(index) if index >= 0 else -999.0, "mute": AudioServer.is_bus_mute(index) if index >= 0 else true, "peak": AudioServer.get_bus_peak_volume_left_db(index, 0) if index >= 0 else -999.0}
	info["mix_rate"] = AudioServer.get_mix_rate()
	info["driver"] = AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else ""
	return info


func _state() -> Dictionary:
	var scene := get_tree().current_scene
	var state := {
		"scene": scene.name,
		"area": scene.get("area_id") if scene is GameArea else "",
		"music": Music.current(),
		"audio": _audio_state(),
		"difficulty": Difficulty.current_id,
		"flags": GameState.get("_flags"),
		"counters": GameState.get("_counters"),
		"health": Survival.health(),
		"water": Survival.water(),
		"inventory": Inventory.snapshot(),
		"dialogue_open": false,
		"sorting": {},
		"quiz": {},
		"puzzle": {},
		"player": _player_state(),
		"enemies": _enemies_state(),
	}
	var dialogue := _first_visible("DialogueBox")
	state["dialogue_open"] = dialogue != null
	state["menu_open"] = _first_visible("GameMenu") != null
	state["paused"] = get_tree().paused
	if dialogue != null:
		state["dialogue_text"] = (dialogue as DialogueBox).current_text()
	var sorting := _first_visible("SortingChallenge") as SortingChallenge
	if sorting != null:
		state["sorting"] = _sorting_state(sorting)
	var quiz := _first_visible("QuizPanel") as QuizPanel
	if quiz != null:
		state["quiz"] = {"phase": QuizPanel.Phase.keys()[quiz.phase()], "answer_key": str(int(quiz.current_quiz().get("answer", 0)) + 1)}
	var puzzle := _first_visible("PuzzlePanel") as PuzzlePanel
	if puzzle != null:
		state["puzzle"] = _puzzle_state(puzzle)
	return state


func _sorting_state(sorting: SortingChallenge) -> Dictionary:
	var info := {"phase": SortingChallenge.Phase.keys()[sorting.phase()], "item": "", "key": ""}
	var session: SortingSession = sorting.get("_session")
	if session != null and not session.current_item().is_empty():
		info["item"] = session.current_item()
		info["key"] = SORT_KEYS[SortingRules.correct_bin(session.current_item())]
	return info


func _puzzle_state(puzzle: PuzzlePanel) -> Dictionary:
	var info := {"phase": PuzzlePanel.Phase.keys()[puzzle.phase()], "keys": []}
	var data := Content.puzzle(str(puzzle.get("_puzzle_id")))
	var options := puzzle.options()
	for step: String in data.get("steps", []):
		info["keys"].append(str(options.find(step) + 1))
	return info


func _player_state() -> Dictionary:
	var players := _find_all("Player")
	var position := (players[0] as Node2D).global_position if not players.is_empty() else Vector2.ZERO
	return {
		"x": position.x, "y": position.y,
		"health": Survival.health(), "max_health": Survival.max_health(),
		"level": Progress.level, "xp": Progress.xp, "lives": Lives.lives,
		"weapon": Gear.equipped("weapon"), "armor": Gear.armor(),
	}


func _enemies_state() -> Array:
	var list := []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null:
			list.append({"id": enemy.enemy_id, "x": enemy.global_position.x, "y": enemy.global_position.y,
				"hp": enemy.hp(), "state": Enemy.State.keys()[enemy.state()]})
	return list
