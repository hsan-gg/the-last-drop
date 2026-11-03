class_name AreaLighting
extends RefCounted
## Dusk lighting: warm light pools around the player and the objects worth
## walking to, set against each area's darker ambient tint.

const TEXTURE_SIZE := 128
const PLAYER_LANTERN := {"color": "#ffd9a0", "energy": 0.85, "radius": 72.0}
const ENTITY_LIGHTS := {
	"repair_station": {"color": "#ffb36b", "energy": 0.7, "radius": 46.0},
	"archive_terminal": {"color": "#5fe0d0", "energy": 0.8, "radius": 44.0},
	"recording": {"color": "#ffd27a", "energy": 0.55, "radius": 28.0},
	"area_exit": {"color": "#ffb36b", "energy": 0.8, "radius": 40.0},
	"water_source": {"color": "#6fb8e8", "energy": 0.5, "radius": 38.0},
}

static var _texture: GradientTexture2D


static func light_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
	return _texture


static func make_light(spec: Dictionary) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = "DuskLight"
	light.texture = light_texture()
	light.color = Color(spec["color"])
	light.energy = spec["energy"]
	light.texture_scale = float(spec["radius"]) * 2.0 / TEXTURE_SIZE
	return light


## Gives the player a lantern, centred on the sprite rather than the feet.
static func add_player_lantern(player: Node2D) -> void:
	var lantern := make_light(PLAYER_LANTERN)
	lantern.name = "Lantern"
	lantern.position = Vector2(0, -8)
	player.add_child(lantern)


## Adds the light configured for an entity scene, if it has one.
static func decorate(entity: Node2D, scene_name: String) -> void:
	if ENTITY_LIGHTS.has(scene_name):
		entity.add_child(make_light(ENTITY_LIGHTS[scene_name]))
