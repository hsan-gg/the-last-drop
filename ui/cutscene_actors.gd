class_name CutsceneActors
extends Node2D
## The cast of a cutscene scene, played by the game's own sprites, so the story
## looks like the game (the way Stardew Valley stages its scenes with the real
## characters). Each actor walks from one point to another, then settles into a
## pose. Points are fractions of the scene, so they follow the stage layout.

const SCALE := 2.0
const SCENE_SIZE := Vector2(480, 196)
## scene kind -> actors. "who": "player" or an enemy id. "from"/"to": fractions.
const CASTS := {
	"ruins": [
		{"who": "player", "from": Vector2(-0.05, 0.9), "to": Vector2(0.42, 0.9), "seconds": 5.5, "walk": "walk_right", "rest": "idle_right", "tint": Color(0.25, 0.18, 0.28)},
	],
	"outpost": [
		{"who": "player", "from": Vector2(0.36, 0.86), "to": Vector2(0.6, 0.86), "seconds": 2.6, "delay": 1.0, "walk": "walk_right", "rest": "idle_right"},
	],
	"factory": [
		{"who": "player", "from": Vector2(0.02, 0.86), "to": Vector2(0.22, 0.86), "seconds": 2.4, "walk": "walk_right", "rest": "idle_up"},
		{"who": "walker", "from": Vector2(0.86, 0.86), "to": Vector2(0.72, 0.86), "seconds": 6.0, "delay": 1.2, "walk": "walk_left", "rest": "idle_left"},
	],
	"dump": [
		{"who": "walker", "from": Vector2(1.05, 0.88), "to": Vector2(0.7, 0.88), "seconds": 7.0, "walk": "walk_left", "rest": "idle_left"},
		{"who": "runner", "from": Vector2(1.1, 0.84), "to": Vector2(0.84, 0.84), "seconds": 4.0, "delay": 2.0, "walk": "walk_left", "rest": "idle_left"},
		{"who": "player", "from": Vector2(0.12, 0.88), "to": Vector2(0.28, 0.88), "seconds": 2.0, "walk": "walk_right", "rest": "idle_right"},
	],
	"river": [
		{"who": "player", "from": Vector2(0.2, 0.52), "to": Vector2(0.44, 0.52), "seconds": 3.2, "walk": "walk_right", "rest": "idle_down"},
	],
	"spring": [
		{"who": "player", "from": Vector2(0.5, 1.02), "to": Vector2(0.5, 0.82), "seconds": 2.6, "walk": "walk_up", "rest": "idle_up"},
	],
}

var _time := 0.0
var _cast: Array = []


## Replaces the cast with the one for `kind` (no cast for other visuals).
func stage(kind: String) -> void:
	for child in get_children():
		child.queue_free()
	_time = 0.0
	_cast = []
	for spec: Dictionary in CASTS.get(kind, []):
		var sprite := _sprite_for(spec["who"])
		if sprite == null:
			continue
		sprite.scale = Vector2.ONE * SCALE
		sprite.modulate = spec.get("tint", Color.WHITE)
		sprite.position = _point(spec["from"])
		add_child(sprite)
		_cast.append({"spec": spec, "sprite": sprite})
		_pose(sprite, spec["walk"] if float(spec.get("delay", 0.0)) <= 0.0 else spec["rest"])


func actor_count() -> int:
	return _cast.size()


func _process(delta: float) -> void:
	_time += delta
	for actor: Dictionary in _cast:
		var spec: Dictionary = actor["spec"]
		var sprite: AnimatedSprite2D = actor["sprite"]
		if not is_instance_valid(sprite):
			continue
		var progress := clampf((_time - float(spec.get("delay", 0.0))) / float(spec["seconds"]), 0.0, 1.0)
		sprite.position = _point(spec["from"]).lerp(_point(spec["to"]), progress)
		if progress <= 0.0:
			_pose(sprite, spec["rest"])
		elif progress < 1.0:
			_pose(sprite, spec["walk"])
		else:
			_pose(sprite, spec["rest"])


func _point(fraction: Vector2) -> Vector2:
	return (fraction * SCENE_SIZE).floor()


func _pose(sprite: AnimatedSprite2D, animation: String) -> void:
	if sprite.sprite_frames.has_animation(animation) and sprite.animation != animation:
		sprite.play(animation)


func _sprite_for(who: String) -> AnimatedSprite2D:
	if who == "player":
		var player := PlayerSprite.new()
		return player
	var frames := Enemy._frames_for(who)
	if frames == null:
		return null
	var zombie := AnimatedSprite2D.new()
	zombie.sprite_frames = frames
	var data := Enemy._data_for(who)
	zombie.offset = Vector2(0, -float(data["canvas"][1]) / 2.0)
	return zombie
