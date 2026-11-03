extends GutTest
## The equipment screen lists what you own and wears what you pick.

var _panel: EquipmentPanel


func before_each() -> void:
	Gear.reset()
	Progress.reset()
	GameState.reset()
	_panel = EquipmentPanel.new()
	_panel.pauses_game = false
	add_child_autofree(_panel)
	_panel.refresh()


func after_each() -> void:
	Gear.reset()
	Progress.reset()


func test_it_starts_on_the_weapon_slot_with_fists_only() -> void:
	assert_eq(_panel.slot(), "weapon")
	assert_eq(_panel.listed(), ["fists"] as Array[String])


func test_owned_gear_is_listed_strongest_first() -> void:
	Gear.grant("scrap_blade")
	Gear.grant("rusty_sword")
	_panel.refresh()
	assert_eq(_panel.listed(), ["scrap_blade", "rusty_sword", "fists"] as Array[String])


func test_picking_an_item_wears_it() -> void:
	Gear.grant("scrap_blade")
	Gear.grant("rusty_sword")
	_panel.refresh()
	_panel.equip_listed(1)
	assert_eq(Gear.equipped("weapon"), "rusty_sword")
	assert_eq(Gear.weapon_damage(), 8)


func test_tab_cycles_through_the_slots() -> void:
	Gear.grant("hard_hat")
	_panel.next_slot()
	assert_eq(_panel.slot(), "head")
	assert_eq(_panel.listed(), ["hard_hat"] as Array[String])
	_panel.next_slot()
	assert_eq(_panel.slot(), "body")
	_panel.next_slot()
	assert_eq(_panel.slot(), "weapon")


func test_picking_a_slot_beyond_the_list_does_nothing() -> void:
	_panel.equip_listed(5)
	assert_eq(Gear.equipped("weapon"), "fists")
