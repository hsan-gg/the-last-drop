extends GutTest
## Runes: owning them, energy, and what each one does to the Spoiled.

const PLAYER_SCENE := preload("res://player/player.tscn")

var _player: Player


func before_each() -> void:
	Runes.reset()
	Survival.set_process(false)
	Survival.reset()
	Combat.enemies_enabled = true
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	Runes.reset()
	Survival.reset()
	Survival.set_process(true)
	Combat.enemies_enabled = false


func _zombie(at: Vector2) -> Enemy:
	var enemy: Enemy = preload("res://world/enemy.tscn").instantiate()
	enemy.position = at
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	return enemy


func test_runes_fill_slots_in_the_order_found() -> void:
	assert_true(Runes.grant("scatter"))
	assert_true(Runes.grant("ember"))
	assert_false(Runes.grant("ember"), "only once")
	assert_eq(Runes.in_slot(1), "scatter")
	assert_eq(Runes.in_slot(2), "ember")
	assert_eq(Runes.in_slot(3), "")


func test_energy_is_spent_and_refused_when_empty() -> void:
	Runes.grant("scatter")
	Runes.energy = 10.0
	assert_false(Runes.spend(24.0))
	Runes.energy = 50.0
	assert_true(Runes.spend(24.0))
	assert_eq(Runes.energy, 26.0)


func test_kills_refill_energy() -> void:
	Runes.grant("ember")
	Runes.energy = 10.0
	EventBus.enemy_killed.emit("walker")
	assert_gt(Runes.energy, 10.0)


func test_the_scatter_blast_hurts_and_throws_zombies_back() -> void:
	Runes.grant("scatter")
	_player.facing = Vector2.RIGHT
	var enemy := _zombie(Vector2(40, 0))
	var before := enemy.hp()
	var caster := _player.get_node("RuneCaster") as RuneCaster
	assert_true(caster.fire_scatter())
	assert_lt(enemy.hp(), before)
	assert_false(caster.fire_scatter(), "a short cooldown between blasts")


func test_fire_sets_zombies_burning_and_it_spreads() -> void:
	var first := _zombie(Vector2(20, 0))
	var second := _zombie(Vector2(30, 0))
	first.ignite(3.0)
	assert_true(first.is_burning())
	var before := first.hp()
	for _i in 10:
		first._tick_burn(0.1)
	assert_lt(first.hp(), before, "burning hurts over time")
	assert_true(second.is_burning(), "the fire jumped to its neighbour")


func test_the_tide_heals_and_puts_out_fires() -> void:
	Runes.grant("tide")
	Survival.damage(40.0)
	var enemy := _zombie(Vector2(30, 0))
	enemy.ignite(3.0)
	var caster := _player.get_node("RuneCaster") as RuneCaster
	var before := Survival.health()
	assert_true(caster.cast_tide())
	assert_gt(Survival.health(), before)
	assert_false(enemy.is_burning())


func test_the_rune_bar_stays_hidden_until_a_rune_is_used() -> void:
	Runes.reset()
	var bar := RuneBar.new()
	add_child_autofree(bar)
	assert_false(bar.visible, "nothing to show without a rune")
	Runes.grant("ember")
	assert_true(bar.is_shown(), "a new rune is shown off")
	bar._clock += 60.0
	assert_false(bar.is_shown(), "then it gets out of the way")
	bar.show_for()
	assert_true(bar.is_shown(), "using a rune brings it back")
	Runes.reset()
