extends "res://tests/test_base.gd"
## Gold: prices, funds, income, repair costs (docs/economy.md).


func test_prices() -> void:
	var sword := Items.make("Iron Sword")
	check_eq(Items.value(sword), 460, "a fresh item is worth its price")
	check_eq(Items.sell_price(sword), 230, "and sells for half")
	sword.uses = 23
	check_eq(Items.value(sword), 230, "a worn one by its uses left")
	check_eq(Items.repair_cost(sword), 230, "repairing pays for the missing uses")
	sword.uses = 0
	check_eq(Items.sell_price(sword), 0, "a broken weapon sells for nothing")
	check_eq(Items.value(Items.make("Power Ring")), 2500, "items that never run out keep their price")
	for name in Weapons.DATA.keys() + Items.CONSUMABLES.keys():
		check(Items.cost(name) > 0, "%s has a price" % name)


func test_funds_and_income() -> void:
	check_eq(b.gold, 0, "a test map with no gold starts at 0")
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.dexterity = 60
	brig.agility = 0
	brig.luck = 0
	brig.hp = 1
	brig.gold = 500
	await b.actions.do_combat(lord, brig)
	check_eq(b.gold, 500, "defeating a unit takes the gold it carried")
	# Steal can take it instead.
	var thief := _spawn_enemy(Vector2i(6, 7))
	thief.gold = 300
	lord.set_cell(Vector2i(5, 7))
	lord.personal_skills.assign(["Steal"])
	lord.agility = 30
	check(b.actions.steal_targets(lord).has(thief), "a foe with only gold can be stolen from")
	await b.actions.do_steal(lord, thief, -1)
	check_eq(b.gold, 800, "stealing its gold")
	check_eq(thief.gold, 0, "(it's gone)")
	# Green allies don't fill your purse.
	var ally := Unit.create("Ally", Unit.Team.ALLY, Vector2i(9, 9), {"class": "Brigand", "items": ["Iron Axe"],
		"hp": 30, "str": 9, "dex": 60, "agi": 3, "lck": 0, "def": 3, "mov": 5})
	b.units_root.add_child(ally)
	thief.set_cell(Vector2i(9, 8))
	thief.hp = 1
	thief.gold = 200
	await b.actions.do_combat(ally, thief)
	check_eq(b.gold, 800, "a green ally's kill brings no gold")
	# Saved with the battle.
	var data := SaveGame.capture(b)
	b.gold = 0
	SaveGame.restore(b, data)
	check_eq(b.gold, 800, "funds come back with a save")


func test_village_and_chest_gold() -> void:
	await start_chapter(0)
	check_eq(b.gold, Campaign.START_GOLD, "a campaign battle starts from the campaign's funds")
	var village: Dictionary = b.map.object_at(Vector2i(5, 0))
	village.gold = 250
	var lord := unit_named("Lord")
	lord.set_cell(Vector2i(5, 0))
	await b.actions.do_visit(lord)
	check_eq(b.gold, Campaign.START_GOLD + 250, "a village's gold")
	# Winning the chapter keeps the funds (plus the chapter's reward).
	b.gold = 1234
	Campaign.finish_chapter(b)
	check_eq(Campaign.gold, 1234 + Chapters.DATA[Chapters.ORDER[0]].get("reward", 0), "carried to the next chapter")
	check(Campaign.load_save() and Campaign.gold == 1234 + Chapters.DATA[Chapters.ORDER[0]].get("reward", 0),
		"and saved")


func test_repair_costs_gold() -> void:
	await start_chapter(1)
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	var lord := Campaign.army_unit("Lord")
	var sword: Dictionary = lord.items[0]
	sword.uses = 23
	var price := Items.repair_cost(sword)
	Campaign.gold = price - 1
	prep._enter("repair")
	prep.index = 0
	prep._repair()
	check(sword.uses == 23 and Campaign.gold == price - 1, "not enough gold: no repair")
	Campaign.gold = price + 10
	prep._repair()
	check_eq(sword.uses, Weapons.max_uses(sword), "repaired")
	check_eq(Campaign.gold, 10, "for the price of its missing uses")
	prep.queue_free()


func test_prep_shop() -> void:
	await start_chapter(1)
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	check(prep.MENU.has("Shop"), "prep has a Shop")
	Campaign.gold = 500
	Campaign.convoy.clear()
	prep.column = 0
	prep._enter("shop")
	var stock := Shop.stock_for(Campaign.chapter_data())
	prep.index = stock.find("Iron Sword")
	prep._shop()
	check_eq(Campaign.gold, 40, "buying costs its price")
	check(Campaign.convoy.size() == 1 and Campaign.convoy[0].name == "Iron Sword", "into the convoy")
	prep._shop()
	check_eq(Campaign.convoy.size(), 1, "not without the gold")
	prep.column = 1
	prep.index = 0
	prep._shop()
	check_eq(Campaign.gold, 270, "selling pays half")
	check(Campaign.convoy.is_empty(), "and takes it from the convoy")
	Campaign.convoy.append({"name": "Old Letter", "kind": "key"})
	prep._shop()
	check_eq(Campaign.convoy.size(), 1, "items with no price can't be sold")
	check(Campaign.load_save() and Campaign.gold == 270, "saved at once")
	prep.queue_free()


func test_map_shop() -> void:
	var lord := unit_named("Lord")
	var shop_cell := Vector2i(4, 2)
	b.map.objects.append({"type": "shop", "cell": shop_cell, "stock": ["Potion", "Silver Sword"], "state": "intact"})
	check(not b.map.lootable_objects().any(func(o): return o.type == "shop"), "enemies don't loot shops")
	b.gold = 500
	lord.set_cell(shop_cell)
	lord.items.assign([Items.make("Iron Sword")])
	# Just looking doesn't use up the turn.
	await open_menu_in_place(lord)
	await pick("Shop")
	await pick("Buy")
	check(b.ui.menu_options.has("Silver Sword  1500G  (x)"), "what you can't afford is marked")
	await press(KEY_X)
	await press(KEY_X)
	check_eq(b.input.menus.context, "unit", "leaving without buying: back to the unit menu")
	# Buying, then selling.
	await pick("Shop")
	await pick("Buy")
	await pick("Potion  300G")
	check_eq(b.gold, 200, "bought")
	check(lord.items.any(func(it): return it.name == "Potion"), "into the unit's inventory")
	await press(KEY_X)
	await pick("Sell")
	await pick("Iron Sword 46  230G")
	check_eq(b.gold, 430, "sold")
	await press(KEY_X)
	await press(KEY_X)
	check(lord.has_acted, "shopping ends the turn")


func test_campaign_economy_data() -> void:
	for id in Chapters.ORDER:
		var ch: Dictionary = Chapters.DATA[id]
		check(ch.get("reward", 0) > 0, "%s has a reward" % id)
		for item_name: String in Shop.stock_for(ch):
			check(Items.cost(item_name) > 0, "%s's shop: %s has a price" % [id, item_name])
		for o: Dictionary in ch.get("objects", []):
			for item_name: String in o.get("stock", []):
				check(Items.cost(item_name) > 0, "%s's map shop: %s has a price" % [id, item_name])
	await start_chapter(2)
	var lord := unit_named("Lord")
	lord.set_cell(Vector2i(6, 7))
	await open_menu_in_place(lord)
	check(b.ui.menu_options.has("Shop"), "chapter 3 has a shop on the map")
	check_eq(unit_named("Bandit King", Unit.Team.ENEMY).gold, 2500, "and a Bandit King worth robbing")
