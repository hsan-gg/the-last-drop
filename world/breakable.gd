class_name Breakable
extends StaticBody2D
## Something you break by hitting it: a cracked wall that hides a room, or a
## vein of ore in a mine. Walls stay broken (a flag remembers them); ore grows
## back each time you come down, so a mine is worth revisiting.
## Ore needs a pickaxe; a cracked wall gives way to anything heavy enough.

const SPRITE_FORMAT := "res://assets/sprites/breakables/%s.png"

@export var sprite_name: String = "cracked_cave_top"
@export var hits: int = 3
## An item you must carry to make a dent (the pickaxe for ore); "" for none.
@export var needs_item: String = ""
## What it drops when it breaks: {item_id: count}.
@export var drops: Dictionary = {}
## A hidden room: breaking it is a discovery (sound, banner, counter, XP).
@export var secret: bool = false
## Broken stays broken (walls). Ore leaves this off and grows back.
@export var persist: bool = true
@export var xp: int = 4
## Map cells [x0, y0, x1, y1] of the room behind a secret wall: kept in
## darkness until the wall breaks, so a hidden room is actually hidden.
@export var hides: Array = []
@export var spawn_key: String = ""

var _left := 0
var _sprite: Sprite2D
var _cover: ColorRect


func _ready() -> void:
	if persist and GameState.has_flag(_broken_flag()):
		queue_free()
		return
	collision_layer = 1
	collision_mask = 0
	add_to_group("breakables")
	_left = hits
	_sprite = Sprite2D.new()
	_sprite.texture = load(SPRITE_FORMAT % sprite_name)
	if _sprite.texture != null:
		_sprite.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - _sprite.texture.get_height() / 2.0)
	add_child(_sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16) if secret or sprite_name.begins_with("cracked") else Vector2(12, 8)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - shape.size.y / 2.0)
	add_child(collider)
	if hides.size() == 4:
		call_deferred("_cover_hidden_room")


## Darkness over the room behind the wall, drawn above everything in it.
func _cover_hidden_room() -> void:
	var tile := float(MapBuilder.TILE_SIZE)
	_cover = ColorRect.new()
	_cover.color = Color("#0a0808")
	_cover.position = Vector2(float(hides[0]), float(hides[1])) * tile
	_cover.size = Vector2(float(hides[2]) - float(hides[0]) + 1.0, float(hides[3]) - float(hides[1]) + 1.0) * tile
	_cover.z_index = 20
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().get_parent().add_child(_cover)


func is_ore() -> bool:
	return sprite_name.begins_with("vein_")


func hits_left() -> int:
	return _left


## A blow from the sword (or anything else heavy). Damage does not matter:
## every proper hit chips one piece off.
func take_hit(_damage: float, _from: Vector2, _knockback: float) -> void:
	if _left <= 0:
		return
	if not needs_item.is_empty() and not Inventory.has(needs_item):
		EventBus.sfx_requested.emit("block")
		FloatingText.spawn(get_parent(), "Too hard: need a %s" % ItemDB.display_name(needs_item).to_lower(), global_position + Vector2(0, -12), Color("#c8c0b0"))
		return
	_left -= 1
	EventBus.sfx_requested.emit("mine_hit")
	_chips()
	var tween := create_tween()
	tween.tween_property(_sprite, "position:x", 1.5, 0.03)
	tween.tween_property(_sprite, "position:x", -1.5, 0.03)
	tween.tween_property(_sprite, "position:x", 0.0, 0.03)
	if _left <= 0:
		_break()


func _break() -> void:
	EventBus.sfx_requested.emit("rock_break")
	if persist:
		GameState.set_flag(_broken_flag())
	var found: Array[String] = []
	for item_id: String in drops:
		var count := int(drops[item_id])
		if is_ore():
			count = randi_range(maxi(count - 1, 1), count + 1)
		for _i in count:
			Inventory.add(item_id)
		found.append("%s x%d" % [ItemDB.display_name(item_id), count])
	if is_ore():
		GameState.add_to_counter("ore_mined")
	if not found.is_empty():
		EventBus.loot_found.emit(", ".join(found))
	if _cover != null:
		var reveal := _cover.create_tween()
		reveal.tween_property(_cover, "modulate:a", 0.0, 0.8)
		reveal.tween_callback(_cover.queue_free)
	if secret:
		GameState.add_to_counter("secrets_found")
		EventBus.sfx_requested.emit("secret")
		EventBus.banner_requested.emit("A HIDDEN ROOM", "The wall gave way. Somebody walled this up on purpose.", Color("#c8a0ff"))
	if xp > 0:
		Progress.add_xp(xp)
	_chips(14)
	queue_free()


func _broken_flag() -> String:
	return "broken_%s" % spawn_key


func _chips(count: int = 5) -> void:
	var chips := CPUParticles2D.new()
	chips.position = position + Vector2(0, -4)
	chips.one_shot = true
	chips.emitting = true
	chips.amount = count
	chips.lifetime = 0.45
	chips.explosiveness = 1.0
	chips.spread = 180.0
	chips.gravity = Vector2(0, 200)
	chips.initial_velocity_min = 30.0
	chips.initial_velocity_max = 70.0
	chips.scale_amount_min = 1.0
	chips.scale_amount_max = 2.0
	chips.color = _sprite.texture.get_image().get_pixel(8, 8) if _sprite.texture != null else Color("#8a7e72")
	chips.finished.connect(chips.queue_free)
	get_parent().add_child(chips)
