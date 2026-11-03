extends CanvasLayer
## Screen-level game feel: a soft vignette over every scene, plus camera shake
## and a red edge pulse when the player takes damage. Effects come from the
## Juicee addon (runtime only), which honours its own reduced-motion toggles.

const VIGNETTE_SHADER := preload("res://assets/shaders/vignette.gdshader")
const HURT_SHAKE_INTENSITY := 3.0
const HURT_SHAKE_SECONDS := 0.25
const HURT_PULSE_INTENSITY := 0.5
const HURT_PULSE_SECONDS := 0.5
const HURT_PULSE_COLOR := Color("#a3261c")

const ASH_AMOUNT := 34
const ASH_COLOR := Color(0.92, 0.86, 0.8, 0.4)

var _vignette: ColorRect


func _ready() -> void:
	layer = 5
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = VIGNETTE_SHADER
	_vignette.material = vignette_material
	add_child(_ash())
	add_child(_vignette)
	EventBus.damage_taken.connect(_on_damage_taken.unbind(1))


func _on_damage_taken() -> void:
	Juicee.shake_camera(self, HURT_SHAKE_INTENSITY, HURT_SHAKE_SECONDS)
	Juicee.vignette(self, HURT_PULSE_INTENSITY, HURT_PULSE_SECONDS, HURT_PULSE_COLOR)


## Pale flakes drifting across every screen, so the air is never still.
func _ash() -> CPUParticles2D:
	var ash := CPUParticles2D.new()
	ash.name = "Ash"
	ash.position = Vector2(240, 135)
	ash.amount = ASH_AMOUNT
	ash.lifetime = 8.0
	ash.preprocess = 8.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(270, 150)
	ash.direction = Vector2(-1.0, 0.35)
	ash.spread = 25.0
	ash.gravity = Vector2.ZERO
	ash.initial_velocity_min = 6.0
	ash.initial_velocity_max = 14.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 1.5
	ash.color = ASH_COLOR
	return ash
