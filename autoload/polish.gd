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

var _vignette: ColorRect


func _ready() -> void:
	layer = 5
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = VIGNETTE_SHADER
	_vignette.material = vignette_material
	add_child(_vignette)
	EventBus.damage_taken.connect(_on_damage_taken.unbind(1))


func _on_damage_taken() -> void:
	Juicee.shake_camera(self, HURT_SHAKE_INTENSITY, HURT_SHAKE_SECONDS)
	Juicee.vignette(self, HURT_PULSE_INTENSITY, HURT_PULSE_SECONDS, HURT_PULSE_COLOR)
