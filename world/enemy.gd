class_name Enemy
extends CharacterBody2D
## A zombie. Stats and loot come from data/enemies.json, art from the pack.
## It idles until the player is close, chases, telegraphs a strike (the windup,
## which can be blocked, parried or dodged), then recovers before trying again.

enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }

const SPRITE_DATA_PATH := "res://data/enemy_sprites.json"
const KNOCKBACK_DRAG := 520.0
const STRIKE_FORGIVENESS := 8.0
const PARRY_STAGGER_SECONDS := 1.3
const HIT_STAGGER_SECONDS := 0.3
const POISE_BREAK_DAMAGE := 20.0
const SEPARATION_RADIUS := 12.0
const PHYSICS_LAYER := 4
## A zombie stops this far short of its reach instead of pressing into the player.
const STANDOFF := 0.65
const DEATH_LINGER_SECONDS := 1.1
const HEALTH_BAR_WIDTH := 16.0
const BODY_OFFSET := Vector2(0, -6)
const TELEGRAPH_COLOR := Color(2.0, 0.85, 0.85)

static var _sprite_data: Dictionary = {}
static var _frames_cache: Dictionary = {}

@export var enemy_id: String = "walker"
## Set by GameArea from the map cell so a defeated enemy stays defeated.
@export var spawn_key: String = ""

var _def: Dictionary = {}
var _hp := 0.0
var _state := State.IDLE
var _timer := 0.0
var _knockback := Vector2.ZERO
var _facing := "down"
var _player: Node2D
var _sprite: AnimatedSprite2D
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _alert: Label
var _burn := 0.0
var _burn_tick := 0.0
var _fire: CPUParticles2D


func _ready() -> void:
	if not Combat.enemies_enabled or (not spawn_key.is_empty() and GameState.has_flag(_slain_flag())) \
			or (enemy_id == "sentinel" and GameState.has_flag("sanctuary_powered")):
		queue_free()
		return
	_def = Content.enemy(enemy_id)
	if _def.is_empty():
		push_error("Enemy: no data for '%s' in data/enemies.json" % enemy_id)
		queue_free()
		return
	_apply_difficulty()
	_hp = float(_def["hp"])
	collision_layer = PHYSICS_LAYER
	collision_mask = 1 | Player.PHYSICS_LAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	_build_body()


## Starts chasing the player wherever they are (the generator calls them).
func hunt() -> void:
	if _state == State.DEAD:
		return
	_def["leash"] = maxf(float(_def["leash"]), 2000.0)
	_state = State.CHASE


## Forgets the player (after a collapse the player is back at the start).
func reset_aggro() -> void:
	if _state != State.DEAD:
		_state = State.IDLE
		_set_alert(false)


## Scales this zombie's stats by the run's difficulty (Medium changes nothing).
func _apply_difficulty() -> void:
	_def["hp"] = float(_def["hp"]) * Difficulty.value("enemy_hp")
	_def["damage"] = float(_def["damage"]) * Difficulty.value("enemy_damage")
	_def["speed"] = float(_def["speed"]) * Difficulty.value("enemy_speed")
	_def["windup"] = float(_def["windup"]) * Difficulty.value("enemy_windup")
	_def["aggro"] = float(_def["aggro"]) * Difficulty.value("enemy_aggro")
	_def["leash"] = float(_def["leash"]) * Difficulty.value("enemy_aggro")


func is_dead() -> bool:
	return _state == State.DEAD


func state() -> State:
	return _state


func hp() -> float:
	return _hp


func definition() -> Dictionary:
	return _def


func _slain_flag() -> String:
	return "slain_%s" % spawn_key


# ---------------------------------------------------------------- combat

## The player's sword lands. `knockback` is the push away from `from_position`.
func take_hit(damage: float, from_position: Vector2, knockback: float) -> void:
	if is_dead():
		return
	damage = damage_taken(damage)
	_hp -= damage
	_knockback = (global_position - from_position).normalized() * knockback * float(_def.get("knockback_factor", 1.0))
	FloatingText.spawn(get_parent(), str(roundi(damage)), global_position, Color("#ffe27a"))
	_flash_white()
	_update_bar()
	if _hp <= 0.0:
		_die()
		return
	var poise: bool = _def.get("poise", false)
	if not poise or damage >= POISE_BREAK_DAMAGE:
		_enter(State.STAGGER, HIT_STAGGER_SECONDS)


# ---------------------------------------------------------------- specials

var _special_time := 0.0
var _phase_two := false


## Per-type behaviour: wraiths fade in and out of the smog, sentinels stand
## down once the Sanctuary has power, the boss reports its health.
func _tick_special(delta: float) -> void:
	_special_time += delta
	match _def.get("special", ""):
		"fade":
			_sprite.self_modulate.a = 0.25 + 0.75 * (0.5 + 0.5 * sin(_special_time * 1.6))
		"sentinel":
			if GameState.has_flag("sanctuary_powered"):
				_state = State.IDLE
				_sprite.self_modulate = Color("#9affd0")
		"boss":  # the bar shows only while it is fighting you
			EventBus.boss_changed.emit(_def.get("name", "Boss") if _state != State.IDLE else "", _hp / float(_def["hp"]))
			if not _phase_two and _hp < float(_def["hp"]) * 0.5:
				_phase_two = true
				_def["speed"] = float(_def["speed"]) * 1.35
				_def["windup"] = float(_def["windup"]) * 0.75
				FloatingText.spawn(get_parent(), "ENRAGED", global_position + Vector2(0, -40), Color("#ff6a3a"))


## How much of a blow lands: a wraith deep in the smog is hard to hit,
## armour soaks some of it until fire melts it.
func damage_taken(amount: float) -> float:
	var dealt := amount
	if _def.get("special", "") == "fade" and _sprite.self_modulate.a < 0.5:
		dealt *= 0.3
	var armour := float(_def.get("armour", 0.0)) * (0.3 if is_burning() else 1.0)
	return maxf(dealt - armour, amount * 0.2)


## The Slag Golem's slam: everything close is hit, and burning slag is left behind.
func _slam() -> void:
	EventBus.sfx_requested.emit("hit")
	Juicee.shake_camera(self, 3.0, 0.25)
	var radius := float(_def.get("slam_radius", 44.0))
	if _player != null and _distance() <= radius and _player.has_method("receive_hit"):
		_player.receive_hit(float(_def["damage"]) * 0.6, global_position)
	for index in 3:
		var hazard := GroundHazard.new()
		hazard.kind = "slag"
		hazard.position = position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, radius)
		get_parent().add_child(hazard)


func _drop_spores() -> void:
	if _def.get("special", "") != "spores" or is_burning():
		return  # fire burns the spores away before they can spread
	var cloud := GroundHazard.new()
	cloud.kind = "spores"
	cloud.position = position
	get_parent().add_child.call_deferred(cloud)


## Fire: sets the zombie burning for `seconds` (refreshing a shorter burn).
func ignite(seconds: float) -> void:
	if is_dead():
		return
	_burn = maxf(_burn, seconds * float(_def.get("burn_factor", 1.0)))
	if _fire != null:
		_fire.emitting = _burn > 0.0


func is_burning() -> bool:
	return _burn > 0.0


func extinguish() -> void:
	_burn = 0.0
	if _fire != null:
		_fire.emitting = false


## Damage that does not push or stagger (fire, poison).
func burn_damage(amount: float) -> void:
	if is_dead():
		return
	var armour := float(_def.get("armour", 0.0)) * (0.3 if is_burning() else 1.0)  # fire melts armour
	var dealt := maxf(amount - armour * 0.25, amount * 0.3)
	_hp -= dealt
	FloatingText.spawn(get_parent(), str(maxi(roundi(dealt), 1)), global_position + Vector2(randf_range(-4, 4), -8), Color("#ffa040"))
	_update_bar()
	if _hp <= 0.0:
		_die()


func _tick_burn(delta: float) -> void:
	if _burn <= 0.0:
		return
	if _state != State.WINDUP:  # a flickering orange glow while it burns
		_sprite.modulate = Color(1.6, 0.9 + 0.2 * sin(Time.get_ticks_msec() * 0.03), 0.5)
	_burn -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.4
		burn_damage(3.0)
		for node in get_tree().get_nodes_in_group("enemies"):  # the fire spreads
			var other := node as Enemy
			if other != null and other != self and not other.is_burning() and other.global_position.distance_to(global_position) < 18.0:
				other.ignite(maxf(_burn * 0.6, 1.0))
	if _burn <= 0.0:
		_sprite.modulate = Color.WHITE
		if _fire != null:
			_fire.emitting = false


func _die() -> void:
	_state = State.DEAD
	collision_layer = 0
	if _alert != null:
		_alert.visible = false
	_drop_spores()
	if _fire != null:
		_fire.emitting = false
	if _def.get("special", "") == "boss":
		EventBus.boss_changed.emit("", 0.0)
		GameState.set_flag("boss_%s_defeated" % enemy_id)
	EventBus.sfx_requested.emit("enemy_die")
	if not spawn_key.is_empty():
		GameState.set_flag(_slain_flag())
	GameState.add_to_counter("kills")
	GameState.add_to_counter("%s_kills" % enemy_id)
	if enemy_id == "husk" and is_burning():
		GameState.add_to_counter("husk_burned")
	Progress.add_xp(int(_def["xp"]))
	FloatingText.spawn(get_parent(), "+%d XP" % int(_def["xp"]), global_position + Vector2(0, -10), Color("#9be04a"))
	_roll_drops()
	EventBus.enemy_killed.emit(enemy_id)
	_play("death", false)
	var tween := create_tween()
	tween.tween_interval(DEATH_LINGER_SECONDS)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _roll_drops() -> void:
	for drop: Dictionary in _def.get("drops", []):
		if randf() > float(drop["chance"]) * Difficulty.value("drops"):
			continue
		if drop.has("gear"):
			if Gear.grant(drop["gear"]):
				EventBus.loot_found.emit("Found: %s" % Gear.definition(drop["gear"])["name"])
		elif Inventory.add(drop["item"]):
			EventBus.loot_found.emit("Found: %s" % ItemDB.display_name(drop["item"]))
			EventBus.sfx_requested.emit("pickup")


# ---------------------------------------------------------------- behaviour

func _physics_process(delta: float) -> void:
	if _state == State.DEAD or _def.is_empty():
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DRAG * delta)
	_tick_burn(delta)
	if _state == State.DEAD:
		return
	_tick_special(delta)
	_timer -= delta
	match _state:
		State.IDLE:
			_do_idle()
		State.CHASE:
			_do_chase()
		State.WINDUP:
			_do_windup()
		State.RECOVER, State.STAGGER:
			_do_wait()
	_move()


func _do_idle() -> void:
	_play("idle")
	if _player != null and _distance() <= float(_def["aggro"]):
		_state = State.CHASE
		EventBus.enemy_alerted.emit()


func _do_chase() -> void:
	if _player == null or _distance() > float(_def["leash"]):
		_state = State.IDLE
		return
	_face_player()
	if _distance() <= float(_def["reach"]):
		_enter(State.WINDUP, float(_def["windup"]))
		_set_alert(true)
		EventBus.enemy_windup.emit()
		_play("attack", false, 7.0 / (float(_def["windup"]) + 0.25))
		return
	_play("walk")


func _do_windup() -> void:
	_sprite.modulate = TELEGRAPH_COLOR if int(_timer * 16.0) % 2 == 0 else Color.WHITE
	if _timer <= 0.0:
		_strike()


func _do_wait() -> void:
	_sprite.modulate = Color.WHITE
	_play("idle")
	if _timer <= 0.0:
		_state = State.CHASE


func _strike() -> void:
	_state = State.STRIKE
	_set_alert(false)
	_sprite.modulate = Color.WHITE
	var outcome := "whiff"
	if _def.get("special", "") == "boss":
		_slam()
	if _player != null and _distance() <= float(_def["reach"]) + STRIKE_FORGIVENESS and _player.has_method("receive_hit"):
		outcome = _player.receive_hit(float(_def["damage"]), global_position).get("outcome", "hit")
	if outcome == CombatRules.OUTCOME_PARRIED:
		_knockback = (global_position - _player.global_position).normalized() * 140.0
		_enter(State.STAGGER, PARRY_STAGGER_SECONDS)
		FloatingText.spawn(get_parent(), "STUNNED", global_position + Vector2(0, -12), Color("#7fe0ff"))
	else:
		_enter(State.RECOVER, float(_def["cooldown"]))


func _move() -> void:
	var desired := Vector2.ZERO
	if _state == State.CHASE and _player != null and _distance() > float(_def["reach"]) * STANDOFF:
		desired = (_player.global_position - global_position).normalized() * float(_def["speed"])
		desired += _separation() * float(_def["speed"]) * 0.6
	elif _state == State.RECOVER and _player != null and _distance() < float(_def["reach"]) * STANDOFF:
		# step back after a swing so it never stays glued to the player
		desired = (global_position - _player.global_position).normalized() * float(_def["speed"]) * 0.5
	velocity = desired + _knockback
	move_and_slide()


## A gentle push away from other enemies so a pack spreads out instead of stacking.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other: Node in get_tree().get_nodes_in_group("enemies"):
		if other == self or not other is Node2D:
			continue
		var offset := global_position - (other as Node2D).global_position
		if offset.length() < SEPARATION_RADIUS and offset.length() > 0.01:
			push += offset.normalized() * (1.0 - offset.length() / SEPARATION_RADIUS)
	return push


func _enter(next: State, seconds: float) -> void:
	_state = next
	_timer = seconds
	if next != State.WINDUP:
		_set_alert(false)


func _distance() -> float:
	return global_position.distance_to(_player.global_position) if _player != null else INF


func _face_player() -> void:
	if _player == null:
		return
	var offset := _player.global_position - global_position
	if absf(offset.x) > absf(offset.y):
		_facing = "right" if offset.x > 0.0 else "left"
	else:
		_facing = "down" if offset.y > 0.0 else "up"


# ---------------------------------------------------------------- body

func _build_body() -> void:
	var look: String = _def.get("sprite", enemy_id)
	var data := _data_for(look)
	var canvas: Array = data["canvas"]
	var body_scale := float(_def.get("scale", 1.0))
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _frames_for(look)
	_sprite.scale = Vector2(body_scale, body_scale)
	_sprite.position = Vector2(0, -float(canvas[1]) * body_scale / 2.0)
	if _def.has("tint"):
		_sprite.self_modulate = Color(_def["tint"])
	add_child(_sprite)
	_play("idle")

	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 5)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, -2.5)
	add_child(collider)

	var top := -float(canvas[1]) - 5.0
	_bar_back = ColorRect.new()
	_bar_back.color = Color("#1a1018")
	_bar_back.size = Vector2(HEALTH_BAR_WIDTH + 2, 4)
	_bar_back.position = Vector2(-HEALTH_BAR_WIDTH / 2.0 - 1, top)
	_bar_back.visible = false
	add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("#e0584a")
	_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, 2)
	_bar_fill.position = Vector2(1, 1)
	_bar_back.add_child(_bar_fill)

	_fire = CPUParticles2D.new()
	_fire.emitting = false
	_fire.amount = 36
	_fire.lifetime = 0.7
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fire.material = glow
	_fire.position = Vector2(0, -float(canvas[1]) * 0.45)
	_fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fire.emission_rect_extents = Vector2(5, float(canvas[1]) * 0.35)
	_fire.direction = Vector2.UP
	_fire.spread = 20.0
	_fire.gravity = Vector2(0, -60)
	_fire.initial_velocity_min = 10.0
	_fire.initial_velocity_max = 30.0
	_fire.scale_amount_min = 2.0
	_fire.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("#fff0a0"), Color("#ff9a30"), Color("#e04a1a"), Color(0.2, 0.15, 0.15, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	_fire.color_ramp = ramp
	_fire.z_index = 3
	add_child(_fire)

	_alert = Label.new()
	_alert.text = "!"
	_alert.add_theme_font_override("font", UiTheme.FONT_FILE)
	_alert.add_theme_font_size_override("font_size", 10)
	_alert.add_theme_color_override("font_color", Color("#ff5040"))
	_alert.add_theme_color_override("font_outline_color", Color("#120a18"))
	_alert.add_theme_constant_override("outline_size", 3)
	_alert.position = Vector2(-3, top - 10)
	_alert.visible = false
	add_child(_alert)


func _set_alert(visible_now: bool) -> void:
	if _alert != null:
		_alert.visible = visible_now


func _update_bar() -> void:
	_bar_back.visible = _hp < float(_def["hp"]) and _hp > 0.0
	_bar_fill.size.x = HEALTH_BAR_WIDTH * clampf(_hp / float(_def["hp"]), 0.0, 1.0)


func _flash_white() -> void:
	_sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _play(anim: String, loop_hint: bool = true, speed: float = -1.0) -> void:
	var direction := _facing
	if anim == "death":
		direction = "left" if _facing == "left" else "right"
	var animation_name := "%s_%s" % [anim, direction]
	if not _sprite.sprite_frames.has_animation(animation_name):
		return
	if _sprite.animation != animation_name or (not loop_hint and not _sprite.is_playing()):
		if speed > 0.0:
			_sprite.sprite_frames.set_animation_speed(animation_name, speed)
		_sprite.play(animation_name)


static func _data_for(id: String) -> Dictionary:
	if _sprite_data.is_empty():
		var loaded: Variant = DataLoader.load_json(SPRITE_DATA_PATH)
		_sprite_data = loaded if typeof(loaded) == TYPE_DICTIONARY else {}
	return _sprite_data.get(id, {})


## One SpriteFrames per enemy type, shared by every instance. Every frame is
## padded to a common canvas so animations of different sizes line up at the feet.
static func _frames_for(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var data := _data_for(id)
	var canvas_w: int = data["canvas"][0]
	var canvas_h: int = data["canvas"][1]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation_name: String in data["animations"]:
		var info: Dictionary = data["animations"][animation_name]
		var texture := load(info["file"]) as Texture2D
		frames.add_animation(animation_name)
		var looping := animation_name.begins_with("idle") or animation_name.begins_with("walk")
		frames.set_animation_loop(animation_name, looping)
		frames.set_animation_speed(animation_name, 8.0 if looping else 10.0)
		var frame_w: int = info["frame_w"]
		var frame_h: int = info["frame_h"]
		for index in int(info["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(index * frame_w, 0, frame_w, frame_h)
			atlas.margin = Rect2((canvas_w - frame_w) / 2, canvas_h - frame_h, canvas_w - frame_w, canvas_h - frame_h)
			frames.add_frame(animation_name, atlas)
	_frames_cache[id] = frames
	return frames
