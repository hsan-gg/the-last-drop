class_name Npc
extends Interactable
## A person you can talk to (data/npcs.json). They potter about near home,
## turn to face you, and say what fits the story so far: each "talk" has
## conditions (story flags, items you carry, counters) and may take items or
## give rewards (items, gear, runes, XP). A gold "!" floats above them while
## they have something new to say. Repeatable chatter fills the rest.

const SHEET_FORMAT := "res://assets/sprites/npcs/%s.png"
const WALK_SPEED := 16.0
const FACE_DISTANCE := 44.0

@export var npc_id: String = ""

var _def: Dictionary = {}
var _sprite: PlayerSprite
var _bubble: Label
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _pause := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	blocker_size = Vector2(8, 5)
	blocker_offset = Vector2(0, -2)
	super()
	_def = Content.npc(npc_id)
	if _def.is_empty() or not _present():
		queue_free()
		return
	_rng.seed = hash(npc_id)
	_home = position
	_target = position
	_build()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func display_name() -> String:
	return _def.get("name", npc_id)


## Some people only appear once the story brings them (e.g. Tobi at the Sanctuary).
func _present() -> bool:
	for flag: String in _def.get("appears_after", []):
		if not GameState.has_flag(flag):
			return false
	return true


## The talk that fits right now: the first new one whose conditions hold,
## otherwise the repeatable chatter. {} if they have nothing to say.
func current_talk() -> Dictionary:
	var chatter := {}
	for talk: Dictionary in _def.get("talks", []):
		if not NpcRules.conditions_met(talk):
			continue
		if talk.get("repeat", false):
			if chatter.is_empty():
				chatter = talk
			continue
		if not GameState.has_flag(NpcRules.done_flag(npc_id, talk)):
			return talk
	return chatter


func has_news() -> bool:
	var talk := current_talk()
	return not talk.is_empty() and not talk.get("repeat", false)


func _on_interacted(_by: Node) -> void:
	var talk := current_talk()
	if talk.is_empty():
		return
	_face(get_tree().get_first_node_in_group("player") as Node2D)
	var lines: Array = talk["lines"]
	if talk.get("repeat", false):
		lines = [lines[_rng.randi_range(0, lines.size() - 1)]]
	else:
		NpcRules.apply(npc_id, talk)
	EventBus.speech_requested.emit(lines, {"name": display_name(), "color": Color(_def.get("color", "#f6ecd6")), "portrait": portrait()})
	EventBus.npc_talked.emit(npc_id, talk.get("id", ""))
	_refresh()


## Their face, cut from the idle frame, for the dialogue box.
func portrait() -> Texture2D:
	var face := AtlasTexture.new()
	face.atlas = load(SHEET_FORMAT % _def.get("sprite", npc_id))
	face.region = Rect2(3, 2, 10, 10)
	return face


func _refresh() -> void:
	if _bubble != null:
		_bubble.visible = has_news()
	set_prompt("Talk to %s" % display_name())


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_time += delta
	_bubble.position.y = -34 + roundf(sin(_time * 4.0) * 1.5)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(global_position) < FACE_DISTANCE:
		_face(player)
		return
	_wander(delta)


func _wander(delta: float) -> void:
	var radius := float(_def.get("wander", 0))
	if radius <= 0.0:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var offset := _target - position
	if offset.length() < 1.0:
		_pause = _rng.randf_range(1.5, 4.0)
		_sprite.face(Vector2.ZERO, false)
		var next := _home + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))
		var area := get_tree().current_scene as GameArea
		_target = next if area == null or area.is_open_ground(next) else _home
		return
	var step := offset.normalized() * minf(WALK_SPEED * delta, offset.length())
	position += step
	_sprite.face(step, true)


func _face(target: Node2D) -> void:
	if target != null:
		_sprite.face(target.global_position - global_position, false)
		_sprite.face(Vector2.ZERO, false)


func _build() -> void:
	_sprite = PlayerSprite.new()
	_sprite.sheet = load(SHEET_FORMAT % _def.get("sprite", npc_id))
	_sprite.with_attacks = false
	_sprite.name = "Sprite"
	add_child(_sprite)
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, -6)
	add_child(collider)
	_bubble = Label.new()
	_bubble.text = "!"
	_bubble.add_theme_font_override("font", UiTheme.FONT_FILE)
	_bubble.add_theme_font_size_override("font_size", 10)
	_bubble.add_theme_color_override("font_color", Color("#f2c94c"))
	_bubble.add_theme_color_override("font_outline_color", Color("#1a1220"))
	_bubble.add_theme_constant_override("outline_size", 3)
	_bubble.position = Vector2(-3, -34)
	add_child(_bubble)
