class_name GearVisuals
extends Node2D
## Shows what the player is wearing and carrying. Helmets and armour are drawn
## by tools/assets_worn_gear.py as overlays that match the player sheet pixel
## for pixel (one 16x18 frame per facing), so they hug the head and torso. The
## overlays ride on the player's sprite: they turn with it, squash with it when
## guarding and bob with its idle and walk frames. The sword hangs at the hip
## when it is not in use.

const SWORD_TEXTURE := preload("res://assets/sprites/sword.png")
const WORN_PATH := "res://assets/sprites/worn/%s.png"
const FRAME := Vector2(16, 18)
const FACINGS: Array[String] = ["down", "up", "left", "right"]
const HIP_SWORD_SCALE := 0.8

var _head: Sprite2D
var _body: Sprite2D
var _sword: Sprite2D
var _player: Player
var _player_sprite: AnimatedSprite2D
var _rest_top := -1
var _tops: Dictionary = {}


func _ready() -> void:
	_player = get_parent() as Player
	_player_sprite = _player.get_node_or_null("Sprite") as AnimatedSprite2D
	var holder: Node = _player_sprite if _player_sprite != null else self
	_body = _make_overlay()
	_head = _make_overlay()
	holder.add_child.call_deferred(_body)
	holder.add_child.call_deferred(_head)
	_sword = Sprite2D.new()
	_sword.texture = SWORD_TEXTURE
	_sword.scale = Vector2(HIP_SWORD_SCALE, HIP_SWORD_SCALE)
	add_child(_sword)
	EventBus.gear_changed.connect(refresh)
	refresh()


## Rebuilds the worn pieces from the equipped gear.
func refresh() -> void:
	_head.texture = worn_texture(Gear.equipped("head"))
	_body.texture = worn_texture(Gear.equipped("body"))
	_sword.modulate = Gear.weapon_color()
	_sword.visible = Gear.equipped("weapon") != Gear.FISTS
	_update_overlays()


func head_visible() -> bool:
	return _head.texture != null


func body_visible() -> bool:
	return _body.texture != null


func sword_at_hip() -> bool:
	return _sword.visible


## The strip of four facings for a piece, or null if it has none (or nothing is worn).
static func worn_texture(gear_id: String) -> Texture2D:
	if gear_id.is_empty():
		return null
	var path := WORN_PATH % gear_id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _process(_delta: float) -> void:
	_update_overlays()
	var facing := _player.facing
	var drawn := _player.combat != null and _player.combat.state != PlayerCombat.State.IDLE
	_sword.visible = Gear.equipped("weapon") != Gear.FISTS and not drawn
	if absf(facing.x) > absf(facing.y):
		var side := 1.0 if facing.x > 0.0 else -1.0
		_sword.position = Vector2(-5.0 * side, -6)  # on the far hip
		_sword.rotation = 0.9 * side
		_sword.z_index = -1
	elif facing.y < 0.0:  # facing away: the sword shows on the back
		_sword.position = Vector2(4, -9)
		_sword.rotation = -0.8
		_sword.z_index = 1
	else:
		_sword.position = Vector2(6, -5)
		_sword.rotation = 1.1
		_sword.z_index = 0


func _make_overlay() -> Sprite2D:
	var overlay := Sprite2D.new()
	overlay.region_enabled = true
	overlay.region_rect = Rect2(Vector2.ZERO, FRAME)
	return overlay


## Picks the facing from the sprite's animation and follows its frame's bob.
func _update_overlays() -> void:
	var facing := "down"
	var bob := 0.0
	if _player_sprite != null and _player_sprite.sprite_frames != null:
		var animation := String(_player_sprite.animation)
		for name in FACINGS:
			if animation.ends_with(name):
				facing = name
		bob = _bob_for(animation, _player_sprite.frame)
	var region := Rect2(Vector2(FACINGS.find(facing) * FRAME.x, 0), FRAME)
	for overlay in [_head, _body]:
		overlay.region_rect = region
		overlay.position = Vector2(0, bob)


## How far this frame's head sits from the resting frame's (the idle breath and walk bounce).
func _bob_for(animation: StringName, frame: int) -> float:
	if String(animation).begins_with("attack"):
		return 0.0
	var texture := _player_sprite.sprite_frames.get_frame_texture(animation, frame) as AtlasTexture
	if texture == null:
		return 0.0
	var key := texture.region
	if not _tops.has(key):
		_tops[key] = _top_row(texture)
	if _rest_top < 0:
		var rest := _player_sprite.sprite_frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
		_rest_top = _top_row(rest) if rest != null else 0
	return float(int(_tops[key]) - _rest_top)


static func _top_row(texture: AtlasTexture) -> int:
	var image := texture.atlas.get_image()
	var region := Rect2i(texture.region)
	for y in region.size.y:
		for x in region.size.x:
			if image.get_pixel(region.position.x + x, region.position.y + y).a > 0.0:
				return y
	return 0
