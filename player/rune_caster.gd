class_name RuneCaster
extends Node2D
## The player's runes in action (keys 1, 2, 3; see autoload/runes.gd).
## - Ember: hold to breathe a cone of fire. The Spoiled catch fire, burn for a
##   while, and the fire jumps to their neighbours.
## - Scatter: a shotgun blast of pellets that hurts and hurls the Spoiled back.
## - Tide: a ring of clean water that heals you and pushes everything away.

const FLAME_RANGE := 50.0
const FLAME_HALF_ANGLE := 28.0
const FLAME_TICK := 0.15
const FLAME_DAMAGE := 4.0
const BURN_SECONDS := 3.0
const SCATTER_PELLETS := 7
const SCATTER_SPREAD := 0.5
const SCATTER_RANGE := 104.0
const SCATTER_DAMAGE := 9.0
const SCATTER_KNOCKBACK := 260.0
const SCATTER_COOLDOWN := 0.7
const TIDE_RADIUS := 76.0
const TIDE_HEAL := 25.0
const TIDE_KNOCKBACK := 320.0
const TIDE_COOLDOWN := 1.5
const BODY_OFFSET := Vector2(0, -6)

var _player: Player
var _flames: CPUParticles2D
var _flame_light: PointLight2D
var _flame_tick := 0.0
var _cooldowns := {}
var _tracers: Array[Dictionary] = []
var _rings: Array[Dictionary] = []


func _ready() -> void:
	_player = get_parent() as Player
	position = BODY_OFFSET
	z_index = 6
	_flames = _make_flames()
	add_child(_flames)
	_flame_light = AreaLighting.make_light({"color": "#ff9a40", "energy": 0.0, "radius": 60.0})
	add_child(_flame_light)


func _physics_process(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(float(_cooldowns[key]) - delta, 0.0)
	var breathing := false
	if not _blocked():
		for slot in [1, 2, 3]:
			var rune := Runes.in_slot(slot)
			var action := "rune_%d" % slot
			if rune == "ember" and Input.is_action_pressed(action):
				breathing = _breathe_fire(delta)
			elif rune == "scatter" and Input.is_action_just_pressed(action):
				fire_scatter()
			elif rune == "tide" and Input.is_action_just_pressed(action):
				cast_tide()
	_flames.emitting = breathing
	_flame_light.energy = lerpf(_flame_light.energy, 2.2 if breathing else 0.0, 0.25)
	if breathing:
		_aim_flames()
	_age_effects(delta)
	queue_redraw()


## True while a menu, quiz, puzzle or the sorting screen is open.
func _blocked() -> bool:
	for node in get_tree().get_nodes_in_group("modal"):
		if (node as CanvasItem).visible if node is CanvasItem else (node as CanvasLayer).visible:
			return true
	return false


# ------------------------------------------------------------------ ember

func _breathe_fire(delta: float) -> bool:
	if not Runes.spend(float(Runes.DEFINITIONS["ember"]["cost"]) * delta):
		return false
	_flame_tick -= delta
	if _flame_tick <= 0.0:
		_flame_tick = FLAME_TICK
		for enemy in _enemies_in_cone(FLAME_RANGE, FLAME_HALF_ANGLE):
			enemy.burn_damage(FLAME_DAMAGE)
			enemy.ignite(BURN_SECONDS)
		for hazard: GroundHazard in get_tree().get_nodes_in_group("ground_hazards"):
			if hazard.kind == "spores" and CombatRules.in_arc(global_position, _player.facing, hazard.global_position, FLAME_RANGE + 10.0, FLAME_HALF_ANGLE + 10.0):
				hazard.clear()
		if int(Time.get_ticks_msec() / 150) % 2 == 0:
			EventBus.sfx_requested.emit("flame")
	return true


func _aim_flames() -> void:
	var facing := _player.facing
	_flames.direction = facing
	_flames.position = facing * 8.0
	_flame_light.position = facing * 24.0


func _make_flames() -> CPUParticles2D:
	var flames := CPUParticles2D.new()
	flames.emitting = false
	flames.amount = 160
	flames.lifetime = 0.55
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flames.material = glow
	flames.spread = FLAME_HALF_ANGLE * 0.7
	flames.gravity = Vector2(0, -40)
	flames.initial_velocity_min = 100.0
	flames.initial_velocity_max = 150.0
	flames.damping_min = 40.0
	flames.damping_max = 80.0
	flames.scale_amount_min = 2.0
	flames.scale_amount_max = 6.0
	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0, 0.4))
	size_curve.add_point(Vector2(0.4, 1.0))
	size_curve.add_point(Vector2(1, 0.2))
	flames.scale_amount_curve = size_curve
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("#fff6c0"), Color("#ffb030"), Color("#ff5a1a"), Color(0.25, 0.2, 0.2, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	flames.color_ramp = ramp
	return flames


# ------------------------------------------------------------------ scatter

func fire_scatter() -> bool:
	if float(_cooldowns.get("scatter", 0.0)) > 0.0 or not Runes.spend(float(Runes.DEFINITIONS["scatter"]["cost"])):
		return false
	_cooldowns["scatter"] = SCATTER_COOLDOWN
	EventBus.sfx_requested.emit("shotgun")
	Juicee.hit_stop(self, 0.04)
	var origin := global_position
	var base := _player.facing.angle()
	var hits := {}
	for pellet in SCATTER_PELLETS:
		var angle := base + lerpf(-SCATTER_SPREAD, SCATTER_SPREAD, float(pellet) / (SCATTER_PELLETS - 1)) + randf_range(-0.05, 0.05)
		var direction := Vector2.from_angle(angle)
		var victim := _first_along(origin, direction)
		var end := origin + direction * SCATTER_RANGE
		if victim != null:
			end = victim.global_position + BODY_OFFSET
			hits[victim] = int(hits.get(victim, 0)) + 1
		_tracers.append({"from": _player.facing * 8.0, "to": end - origin, "age": 0.0})
	for victim: Enemy in hits:
		victim.take_hit(SCATTER_DAMAGE * int(hits[victim]), origin, SCATTER_KNOCKBACK)
	_rings.append({"radius": 4.0, "age": 0.0, "color": Color("#fff2a0"), "grow": 14.0, "life": 0.12, "at": _player.facing * 10.0, "fill": true})
	return true


func _first_along(origin: Vector2, direction: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance := SCATTER_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position + BODY_OFFSET - origin
		var along := offset.dot(direction)
		if along <= 0.0 or along > best_distance:
			continue
		if absf(offset.cross(direction)) <= 8.0:
			best = enemy
			best_distance = along
	return best


# ------------------------------------------------------------------ tide

func cast_tide() -> bool:
	if float(_cooldowns.get("tide", 0.0)) > 0.0 or not Runes.spend(float(Runes.DEFINITIONS["tide"]["cost"])):
		return false
	_cooldowns["tide"] = TIDE_COOLDOWN
	EventBus.sfx_requested.emit("tide")
	Survival.heal(TIDE_HEAL)
	FloatingText.spawn(_player.get_parent(), "+%d" % int(TIDE_HEAL), _player.global_position, Color("#7fe0ff"))
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= TIDE_RADIUS:
			enemy.take_hit(4.0, global_position, TIDE_KNOCKBACK)
			enemy.extinguish()
	for hazard: GroundHazard in get_tree().get_nodes_in_group("ground_hazards"):
		if hazard.global_position.distance_to(global_position) <= TIDE_RADIUS:
			hazard.clear()
	for wave in 3:
		_rings.append({"radius": 4.0 + wave * 6.0, "age": -wave * 0.1, "color": Color("#7fe0ff"), "grow": TIDE_RADIUS, "life": 0.75, "at": Vector2.ZERO, "width": 4.0})
	add_child(_splash())
	return true


func _splash() -> CPUParticles2D:
	var splash := CPUParticles2D.new()
	splash.one_shot = true
	splash.emitting = true
	splash.amount = 40
	splash.lifetime = 0.7
	splash.explosiveness = 0.9
	splash.spread = 180.0
	splash.gravity = Vector2(0, 120)
	splash.initial_velocity_min = 60.0
	splash.initial_velocity_max = 120.0
	splash.scale_amount_min = 1.0
	splash.scale_amount_max = 2.5
	splash.color = Color("#bff4ff")
	splash.finished.connect(splash.queue_free)
	return splash


# ------------------------------------------------------------------ shared

func _enemies_in_cone(reach: float, half_angle: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead() and CombatRules.in_arc(global_position, _player.facing, enemy.global_position + BODY_OFFSET, reach, half_angle):
			found.append(enemy)
	return found


func _age_effects(delta: float) -> void:
	for tracer in _tracers:
		tracer["age"] = float(tracer["age"]) + delta
	_tracers = _tracers.filter(func(tracer: Dictionary) -> bool: return float(tracer["age"]) < 0.14)
	for ring in _rings:
		ring["age"] = float(ring["age"]) + delta
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return float(ring["age"]) < float(ring["life"]))


func _draw() -> void:
	for tracer in _tracers:
		var fade := 1.0 - float(tracer["age"]) / 0.14
		draw_line(tracer["from"], tracer["to"], Color(1.0, 0.85, 0.4, fade * 0.5), 3.0)
		draw_line(tracer["from"], tracer["to"], Color(1.0, 1.0, 0.8, fade), 1.0)
	for ring in _rings:
		var age := float(ring["age"])
		if age < 0.0:
			continue
		var progress := age / float(ring["life"])
		var color: Color = ring["color"]
		var radius := float(ring["radius"]) + float(ring["grow"]) * progress
		if ring.get("fill", false):
			draw_circle(ring["at"], radius, Color(color.r, color.g, color.b, 1.0 - progress))
		else:
			draw_arc(ring["at"], radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, (1.0 - progress) * 0.9), float(ring.get("width", 2.0)))
			draw_circle(ring["at"], radius, Color(color.r, color.g, color.b, (1.0 - progress) * 0.12))
