class_name GroundHazard
extends Node2D
## Something nasty on the ground for a while: a Blight Husk's spore cloud or a
## Slag Golem's burning slag. Standing in it hurts; fire clears spores, and the
## Tide rune washes both away.

const SETTINGS := {
	"spores": {"radius": 24.0, "damage": 5.0, "seconds": 6.0, "color": Color(0.7, 0.5, 0.9)},
	"slag": {"radius": 12.0, "damage": 8.0, "seconds": 4.0, "color": Color(1.0, 0.45, 0.15)},
}

var kind := "spores"
var _age := 0.0
var _tick := 0.0


func _ready() -> void:
	add_to_group("ground_hazards")
	z_index = -1


func clear() -> void:
	queue_free()


func _process(delta: float) -> void:
	var spec: Dictionary = SETTINGS[kind]
	_age += delta
	if _age >= float(spec["seconds"]):
		queue_free()
		return
	_tick -= delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _tick <= 0.0 and player != null and player.global_position.distance_to(global_position) < float(spec["radius"]):
		_tick = 0.5
		Survival.damage(float(spec["damage"]) * 0.5)
	queue_redraw()


func _draw() -> void:
	var spec: Dictionary = SETTINGS[kind]
	var color: Color = spec["color"]
	var fade := clampf(1.0 - _age / float(spec["seconds"]), 0.0, 1.0)
	var radius := float(spec["radius"])
	for puff in 7:
		var angle := puff * TAU / 7.0 + _age * (0.6 if kind == "spores" else 0.0)
		var offset := Vector2.from_angle(angle) * radius * 0.55
		var size := radius * (0.45 + 0.1 * sin(_age * 3.0 + puff))
		draw_circle(offset, size, Color(color.r, color.g, color.b, 0.22 * fade))
	if kind == "slag":
		draw_circle(Vector2.ZERO, radius * 0.6, Color(1.0, 0.75, 0.3, 0.6 * fade))
