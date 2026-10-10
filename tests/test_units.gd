extends "res://tests/test_base.gd"
## Levels and movement types, mounted units, classes, weapon effectiveness, races, generic names, kills and biography moments, the Dragon.


# --- Levels and movement types ------------------------------------------------


func test_all_levels_are_valid() -> void:
	for id in Levels.ORDER:
		var level := Levels.get_level(id)
		var layout: Array = level.layout
		for row in layout:
			check_eq(row.length(), layout[0].length(), "%s: rows have equal length" % id)
			for key in row:
				check(BattleMap.TERRAIN.has(key), "%s: unknown terrain '%s'" % [id, key])
		var taken := {}
		for data in level.players + level.enemies:
			var cell: Vector2i = data.cell
			check(Classes.DATA.has(data.get("class", "")), "%s: %s has a known class" % [id, data.name])
			if not Classes.DATA.has(data.get("class", "")):
				continue
			var cls := Classes.get_data(data["class"])
			for item_name in data.get("items", []):
				if Weapons.DATA.has(item_name):
					check(cls.weapons.has(Weapons.DATA[item_name].type),
						"%s: %s (%s) can wield its %s" % [id, data.name, data["class"], item_name])
			var race: String = data.get("race", "Human")
			check(Races.DATA.has(race), "%s: %s has a known race" % [id, data.name])
			if not Races.DATA.has(race):
				continue
			check(Races.allows(race, data["class"]), "%s: %s can be a %s" % [id, race, data["class"]])
			var move_type := Races.move_type(race, data["class"])
			var key: String = layout[cell.y][cell.x]
			check(BattleMap.cost_for(key, move_type) >= 0,
				"%s: %s (%s) can stand on its start tile '%s'" % [id, data.name, move_type, key])
			check(not taken.has(cell), "%s: %s shares a start tile" % [id, data.name])
			taken[cell] = true


func test_level_select_loads_coastal_raid() -> void:
	Levels.selected = "coastal_raid"
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"  # restore before any check can bail out
	check_eq(b.map.terrain_key(Vector2i(13, 4)), "T", "island fort loaded")
	var pegasus := unit_named("Pegasus")
	var siren := unit_named("Siren")
	var lord := unit_named("Lord")
	check(pegasus != null and pegasus.move_type == "flying", "roster loaded with move types")
	check(pegasus.is_mounted() and pegasus.unit_class == "Flier", "and classes")
	var galley: Unit = unit_named("Galley")
	check(galley != null and galley.is_ship(), "player Galley is a ship")
	# The island is out of reach on foot (sea costs 6 > MOV 5), but not for fliers and mermaids.
	check(b.map.move_cost(Vector2i(11, 4), "foot") > lord.mov, "foot units can never step into the sea")
	check(b.map.cost_field(Vector2i(13, 4), "flying").has(pegasus.cell), "fliers can")
	check(b.map.cost_field(Vector2i(12, 5), "mermaid").has(siren.cell), "mermaids can (via the river mouth)")


func test_move_type_costs() -> void:
	var fighter := unit_named("Fighter")
	isolate([fighter])
	var m: BattleMap = b.map
	# The full terrain spec: MOV cost per move type, in this column order.
	var types := ["foot", "heavy", "horse", "mermaid", "ship", "flying", "spirit"]
	var x := -1.0
	var spec := {
		".": [1, 1, 1, 3, 6, 1, 1],
		"=": [0.7, 0.7, 0.7, 1.5, 5, 1, 1],
		"H": [1, 1, 1.2, 1, 10, 1, 1],
		"T": [1.5, 1.5, 1.5, 1.5, 1.5, 1, 1],
		"S": [1, 1, 1.5, 2, 5, 1, 1],
		"D": [1.5, 1.5, 3, 2, 4, 1, 1],
		"F": [2, 2, 4, 3, 10, 1, 1],
		"#": [10, 10, 20, 10, 20, 1, 1],
		"h": [4, 10, 10, 10, 20, 1, 1],
		"M": [7, 15, 15, 15, 20, 1, 1],
		"~": [6, 8, 8, 1, 1, 1, 1],
		"L": [6, 8, 8, 1, 1, 1, 1],
		"W": [6, 8, 8, 1, 1, 1, 1],
		"v": [20, 20, 20, 6, 8, 1, 1],
		"*": [1, 1, 1.5, 2, 5, 1, 1],
		"i": [1.5, 1, 2, 1, 4, 1, 1],
		"_": [1, 1, 1.5, 3, 10, 1.5, 1],
		"c": [1, 1, 1.5, 3, 10, 1.5, 1],
		"X": [x, x, x, x, x, x, 1],
		"I": [2, 2, 2, 2, 20, 1, 1],
		"O": [x, x, x, x, x, 1, 1],
		"|": [x, x, x, x, x, 1, 1],
		"x": [x, x, x, x, x, x, 1],
		"/": [x, x, x, x, x, 1, 1],
		"Y": [x, x, x, x, x, 1, 1],
		"+": [x, x, x, x, x, x, 1],
		"B": [1, 1, 1, 1, 1, 1, 1],
	}
	check_eq(spec.size(), BattleMap.TERRAIN.size(), "every terrain is covered by the spec")
	for key in spec:
		for i in types.size():
			var got := BattleMap.cost_for(key, types[i])
			check(is_equal_approx(got, float(spec[key][i])),
				"%s (%s) for %s: expected %s, got %s" % [BattleMap.TERRAIN[key].name, key, types[i], spec[key][i], got])
	# Only fliers and spirits ignore terrain bonuses.
	check_eq(BattleMap.NO_TERRAIN_BONUS, ["flying", "spirit"], "fliers and spirits get no terrain bonuses")
	# Reachability follows the unit's type: (8, 4) is across the river from (6, 4).
	fighter.set_cell(Vector2i(6, 4))
	fighter.mov = 2
	check(not m.get_reachable(fighter, b.units()).cells.has(Vector2i(8, 4)), "foot can't cross the river")
	fighter.move_type = "flying"
	check(m.get_reachable(fighter, b.units()).cells.has(Vector2i(8, 4)), "flier crosses it")
	fighter.move_type = "ship"
	fighter.set_cell(Vector2i(7, 4))
	var ship_cells: Dictionary = m.get_reachable(fighter, b.units()).cells
	check(ship_cells.keys().all(func(c): return m.terrain_key(c) == "~"), "ship stays on water")


func test_flying_gets_no_terrain_bonus() -> void:
	var fighter := unit_named("Fighter")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([fighter, brig])
	brig.set_cell(Vector2i(4, 0))  # forest: DEF +1, AVO +20
	fighter.set_cell(Vector2i(3, 0))
	var grounded := Combat.damage(fighter, brig, b.map)
	var grounded_hit := Combat.hit_chance(fighter, brig, b.map)
	brig.move_type = "flying"
	check_eq(Combat.damage(fighter, brig, b.map), grounded + 1, "flier loses the forest's DEF +1")
	check(Combat.hit_chance(fighter, brig, b.map) > grounded_hit, "and its avoid bonus")


# --- Mounted units: no Shove, Rescue/Drop -------------------------------------


func test_mounted_units_cannot_shove() -> void:
	var fighter := unit_named("Fighter")
	var knight := unit_named("Knight")
	isolate([fighter, knight])
	fighter.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	check(b.actions.can_shove(fighter, knight), "two foot units can shove")
	fighter.set_class("Cavalry")
	check(not b.actions.can_shove(fighter, knight), "a mounted unit can't shove")
	check(not b.actions.can_shove(knight, fighter), "a mounted unit can't be shoved")
	knight.set_class("Flier")
	fighter.set_class("Axeman")
	check(not b.actions.can_shove(fighter, knight), "Fliers are mounted")
	knight.set_race("Harpy")
	knight.set_class("Archer")
	check(knight.move_type == "flying" and b.actions.can_shove(fighter, knight),
		"Harpies fly but aren't mounted, so they can be shoved")


func test_rescue_rules() -> void:
	var fighter := unit_named("Fighter")
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	isolate([fighter, knight, archer])
	fighter.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	archer.set_cell(Vector2i(3, 6))
	check(b.actions.rescue_targets(fighter).is_empty(), "foot units can't rescue")
	fighter.set_class("Cavalry")
	check_eq(b.actions.rescue_targets(fighter).size(), 2, "a mounted unit can rescue adjacent foot allies")
	archer.set_class("Flier")
	check_eq(b.actions.rescue_targets(fighter), [knight], "mounted allies can't be rescued")
	archer.set_race("Harpy")
	archer.set_class("Archer")
	check(b.actions.rescue_targets(fighter).has(archer), "unmounted fliers (Harpy) can be rescued")
	archer.set_class("Galley")
	check(not b.actions.rescue_targets(fighter).has(archer), "ships can't be rescued")


func test_rescue_and_drop_ferry() -> void:
	var fighter := unit_named("Fighter")
	var lord := unit_named("Lord")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	# An idle Archer keeps the player phase open; the Brigand avoids an instant Victory.
	isolate([fighter, lord, archer, brig])
	archer.set_cell(Vector2i(0, 0))
	brig.set_cell(Vector2i(14, 9))
	fighter.set_class("Cavalry")
	fighter.mov = 7
	fighter.set_cell(Vector2i(4, 6))
	lord.set_cell(Vector2i(5, 6))
	var as_before := Combat.attack_speed(fighter)
	# Rescue: select the Fighter, stay in place, Rescue the Lord.
	b.cursor.cell = fighter.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Rescue")
	check_eq(b.map.area_cells, [lord.cell], "rescue target previewed")
	await press(KEY_Z)
	check(b.input.canto_move, "Cavalry has Canto")
	await press(KEY_X)  # stay put
	check(fighter.carrying == lord and lord.carried_by == fighter, "Lord is being carried")
	check(not b.units().has(lord), "carried units are off the map")
	check(not lord.visible, "and hidden")
	check(fighter.has_acted, "rescuing ends the rescuer's turn")
	check_eq(b.state, b.State.IDLE, "a carried Lord isn't a defeat")
	check(Combat.attack_speed(fighter) < as_before, "carrying halves AGI (attack speed drops)")
	# Next turn: ride east and drop the Lord, who can still act.
	fighter.has_acted = false
	b.cursor.cell = fighter.cell
	await press(KEY_Z)
	for i in 4:
		await press(KEY_RIGHT)
	await press(KEY_Z)
	check_eq(fighter.cell, Vector2i(8, 6), "carrier moved (across the river ford)")
	await pick("Drop")
	var drop_cell: Vector2i = b.input.target_cells[0]
	await press(KEY_Z)
	await press(KEY_X)  # no Canto move
	check(fighter.carrying == null and lord.carried_by == null, "dropped")
	check_eq(lord.cell, drop_cell, "Lord set down on the chosen cell")
	check(b.units().has(lord) and lord.visible, "back on the map")
	check(fighter.has_acted, "dropping ends the carrier's turn")
	check(not lord.has_acted, "the dropped Lord can still act")
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	check_eq(b.state, b.State.SELECTED, "and can be selected to move on")


func test_fallen_carrier_drops_passenger() -> void:
	var fighter := unit_named("Fighter")
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([fighter, lord, brig])
	fighter.set_class("Cavalry")
	fighter.set_cell(Vector2i(4, 6))
	lord.set_cell(Vector2i(5, 6))
	await b.actions.do_rescue(fighter, lord)
	brig.set_cell(Vector2i(4, 5))
	fighter.hp = 1
	brig.dexterity = 60  # guaranteed hit
	await b.actions.do_combat(brig, fighter)
	check(not is_instance_valid(fighter) or fighter.hp <= 0, "carrier fell")
	check_eq(lord.cell, Vector2i(4, 6), "passenger set down where the carrier fell")
	check(b.units().has(lord) and lord.visible and lord.carried_by == null, "passenger back on the map")


# --- Classes ------------------------------------------------------------------


func test_class_data_is_consistent() -> void:
	for id in Classes.DATA:
		var c: Dictionary = Classes.DATA[id]
		check(BattleMap.MOVE_TYPES.has(c.move), "%s: known move type %s" % [id, c.move])
		check(not c.weapons.is_empty(), "%s: wields something" % id)
		for t in c.weapons:
			check(Weapons.DATA.values().any(func(w): return w.type == t), "%s: weapon type %s exists" % [id, t])
		for p in Classes.promotions(id):
			check(Classes.DATA.has(p) and Classes.DATA[p].get("promoted", false),
				"%s: promotes into a promoted class (%s)" % [id, p])
	check_eq(Classes.promotions("Guard"), ["Juggernaut"], "Guard -> Juggernaut")
	check_eq(Classes.promotions("Turret"), ["Juggernaut"], "Turret -> Juggernaut")
	var lord := unit_named("Lord")
	lord.level = 7
	lord.set_class("Swordsmaster")
	check_eq(lord.level, 7, "changing class keeps the level")


func test_class_weapon_restrictions() -> void:
	var lord := unit_named("Lord")
	var mage := unit_named("Mage")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	lord.items.push_front(Items.make("Iron Axe"))
	check_eq(lord.weapon.name, "Iron Sword", "a Swordsman skips the axe it can't wield")
	lord.equip(0)
	check_eq(lord.items[0].name, "Iron Axe", "equip() refuses weapons the class can't wield")
	check(lord.weapons().all(func(w): return w.type == "sword"), "weapons() lists only wieldable ones")
	check_eq(mage.weapon.name, "Quarterstaff", "Mages wield staves")
	clear_board([mage, brig])
	mage.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(6, 2))
	check_eq(Combat.triangle(mage, brig), 0, "staves sit outside the triangle")
	check(Combat.can_counter(brig, mage), "a staff counters in melee")
	# The items menu marks the axe as unusable.
	lord.set_cell(Vector2i(4, 4))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Items")
	check(b.ui.menu_options[0].ends_with("(x)"), "unusable weapon is marked (x)")


func test_swim_and_climb_costs() -> void:
	# Exact costs are in test_move_type_costs; this checks what they mean on a map.
	var m: BattleMap = b.map
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	check(brig.move_type == "foot" and Skills.has(brig, "Climbing"), "Brigands are foot units that climb")
	isolate([brig])
	brig.set_cell(Vector2i(1, 3))  # next to the (2, 3) mountain
	check_eq(m.unit_cost(brig, Vector2i(2, 3)), 4.0, "Climbing: mountains cost 4")
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(2, 3)), "a MOV 5 climber can scale a mountain")
	brig.set_class("Axeman")
	check(not m.get_reachable(brig, b.units()).cells.has(Vector2i(2, 3)), "a MOV 5 foot unit can't (7)")
	brig.set_cell(Vector2i(6, 0))  # next to the river at (7, 0)
	brig.set_class("Corsair")
	check_eq(m.unit_cost(brig, Vector2i(7, 0)), 2.0, "Swimming: rivers cost 2")
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(7, 0)), "a swimmer wades into the river")
	check_eq(m.unit_cost(brig, Vector2i(4, 5)), 2.0, "but forests cost what they cost any foot unit")
	# Berserkers have both.
	brig.set_class("Berserker")
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(7, 0)), "a Berserker wades into the river")
	brig.set_cell(Vector2i(1, 3))
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(2, 3)), "and scales the mountain")
	# Scouts: Forester.
	brig.set_class("Rogue")
	check_eq(m.unit_cost(brig, Vector2i(4, 5)), 1.5, "Forester: forests cost 1.5")
	# Terrain skills only lower costs: a horse with Swimming still pays 4 in forests.
	brig.set_class("Cavalry")
	brig.learned.assign(["Swimming"])
	check_eq(m.unit_cost(brig, Vector2i(4, 5)), 4.0, "a swimming horse is still slow in forests")
	check_eq(m.unit_cost(brig, Vector2i(7, 0)), 2.0, "but swims")


func test_inspire_buffs_adjacent_allies() -> void:
	var banner := unit_named("Bannerman")
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([banner, knight, fighter, archer, brig])
	banner.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	fighter.set_cell(Vector2i(4, 7))
	archer.set_cell(Vector2i(6, 6))
	brig.set_cell(Vector2i(5, 5))
	var dmg_before := Combat.damage(knight, brig, b.map)
	var taken_before := Combat.damage(brig, knight, b.map)
	b.cursor.cell = banner.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Inspire")
	check_eq(b.map.area_cells.size(), 2, "both adjacent allies are previewed")
	await press(KEY_Z)
	check_eq(knight.inspire_bonus, 1, "Lv 1 Inspire: +1")
	check_eq(fighter.inspire_bonus, 1, "every adjacent ally is inspired")
	check_eq(archer.inspire_bonus, 0, "allies 2 tiles away are not")
	check_eq(Combat.damage(knight, brig, b.map), dmg_before + 1, "+1 STR")
	check_eq(Combat.damage(brig, knight, b.map), maxi(0, taken_before - 1), "+1 DEF")
	check(banner.has_acted, "Inspire ends the Bannerman's turn")
	check_eq(banner.exp_points, roundi(Experience.INSPIRE_EXP * 1.1), "Inspire EXP (Human x1.1)")
	check_eq(Classes.inspire_bonus(5), 2, "Lv 5: +2")
	check_eq(Classes.inspire_bonus(20), 5, "Lv 20: +5")
	b.phases.clear_inspire(Unit.Team.ENEMY)
	check_eq(knight.inspire_bonus, 1, "lasts through the enemy phase")
	b.phases.clear_inspire(Unit.Team.PLAYER)
	check_eq(knight.inspire_bonus, 0, "gone at the next player phase")


func test_ship_board_and_unload() -> void:
	var ship := unit_named("Archer")
	var lord := unit_named("Lord")
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	# An idle Fighter keeps the player phase open; the Brigand avoids an instant Victory.
	isolate([ship, lord, knight, fighter, brig])
	ship.set_class("Galley")
	ship.set_cell(Vector2i(7, 4))
	lord.set_cell(Vector2i(6, 4))
	knight.set_cell(Vector2i(6, 5))
	fighter.set_cell(Vector2i(0, 0))
	brig.set_cell(Vector2i(14, 9))
	check(not b.actions.can_shove(lord, ship), "ships can't be shoved")
	# The Lord boards without moving.
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Board")
	check_eq(b.map.area_cells, [ship.cell], "ship previewed")
	await press(KEY_Z)
	check(lord.carried_by == ship and ship.passengers == [lord], "Lord is aboard")
	check(not b.units().has(lord) and not lord.visible, "passengers are off the map")
	check(lord.has_acted, "boarding ends the boarder's turn")
	check_eq(b.state, b.State.IDLE, "a Lord aboard isn't a defeat")
	# The Knight walks up to the ship and boards: now it's full.
	b.cursor.cell = knight.cell
	await press(KEY_Z)
	await press(KEY_UP)
	await press(KEY_Z)
	await pick("Board")
	await press(KEY_Z)
	check_eq(ship.passengers.size(), 2, "two aboard")
	fighter.set_cell(Vector2i(8, 4))
	check(b.actions.board_targets(fighter).is_empty(), "a full ship takes nobody else")
	fighter.set_cell(Vector2i(0, 0))
	# New phase: passengers are refreshed even while aboard.
	await b.phases.start_player_phase()
	check(not lord.has_acted and not knight.has_acted, "passengers get their action back")
	# The ship sails one tile and unloads the Lord, then the Knight, without ending its turn.
	b.cursor.cell = ship.cell
	await press(KEY_Z)
	await press(KEY_DOWN)
	await press(KEY_Z)
	check_eq(ship.cell, Vector2i(7, 5), "ship moved")
	await pick("Unload")
	check_eq(b.state, b.State.MENU, "two passengers: pick who to unload")
	await pick("Lord")
	var lord_cell: Vector2i = b.input.target_cells[0]
	await press(KEY_Z)
	check(lord.carried_by == null and lord.visible and b.units().has(lord), "Lord unloaded")
	check_eq(lord.cell, lord_cell, "onto the chosen cell")
	check(not ship.has_acted, "unloading doesn't end the ship's turn")
	check_eq(b.state, b.State.MENU, "the ship's menu reopens")
	await press(KEY_X)
	check_eq(ship.cell, Vector2i(7, 5), "after unloading, cancel no longer undoes the move")
	await pick("Unload")
	await press(KEY_Z)
	check(ship.passengers.is_empty() and b.units().has(knight), "Knight unloaded too")
	check(not b.ui.menu_options.has("Unload"), "nothing left to unload")
	await pick("Wait")
	check(ship.has_acted, "Wait ends the ship's turn")
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	check_eq(b.state, b.State.SELECTED, "the unloaded Lord can act")


func test_sunk_ship_sets_passengers_ashore() -> void:
	var ship := unit_named("Archer")
	var knight := unit_named("Knight")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([ship, knight, brig])
	ship.set_class("Galley")
	ship.set_cell(Vector2i(7, 4))
	knight.set_cell(Vector2i(6, 4))
	await b.actions.do_board(knight, ship)
	brig.set_cell(Vector2i(8, 4))
	ship.hp = 1
	brig.dexterity = 60  # guaranteed hit
	await b.actions.do_combat(brig, ship)
	check(not is_instance_valid(ship) or ship.hp <= 0, "ship sank")
	check(b.units().has(knight) and knight.visible and knight.carried_by == null, "passenger back on the map")
	check_eq(b.map.move_cost(knight.cell, knight.move_type) >= 0, true, "on a cell it can stand on")
	check_eq(BattleMap.distance(knight.cell, Vector2i(7, 4)), 1, "next to where the ship sank")


# --- Weapon effectiveness -----------------------------------------------------


func test_effectiveness_triples_might() -> void:
	# Each weapon goes to a class that can wield it (classes restrict weapon types).
	var archer := unit_named("Archer")
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	var target := unit_named("Cleric")
	isolate([archer, knight, fighter, target])
	target.set_cell(Vector2i(6, 2))  # plain: no terrain DEF
	var cases := [
		["Iron Bow", "flying", archer], ["Pike", "horse", knight],
		["Hammer", "heavy", fighter], ["Woodcutter", "ship", fighter],
	]
	for c in cases:
		var attacker: Unit = c[2]
		attacker.set_cell(Vector2i(4, 2) if c[0] == "Iron Bow" else Vector2i(5, 2))
		give_weapon(attacker, c[0])
		check_eq(attacker.weapon.name, c[0], "%s equipped" % c[0])
		var mt: int = Weapons.DATA[c[0]].mt
		var tri := Combat.triangle(attacker, target)
		target.tags.assign(["foot"])
		var normal := Combat.damage(attacker, target, b.map)
		check_eq(normal, maxi(0, attacker.strength + mt + tri - target.defense), "%s vs foot: normal damage" % c[0])
		target.tags.assign([c[1]])
		check(Combat.is_effective(attacker.weapon, target), "%s is effective vs %s" % [c[0], c[1]])
		check_eq(Combat.damage(attacker, target, b.map), attacker.strength + mt * 3 + tri - target.defense,
			"%s vs %s: might x3" % [c[0], c[1]])
		attacker.items.remove_at(0)
		attacker.set_cell(Vector2i(0, 9 - cases.find(c)))
	# Effectiveness counts on counters too: an archer's bow shoots down a flier at range 2.
	target.tags.assign(["flying"])
	archer.set_cell(Vector2i(8, 2))
	check_eq(Combat.forecast(target, archer, b.map).def.multiplier, 3, "counter forecast flags effectiveness")


func test_spirits_resist_non_silver_weapons() -> void:
	var blade := unit_named("Fighter")
	var wraith := unit_named("Archer")
	var mage := unit_named("Mage")
	isolate([blade, wraith, mage])
	blade.set_cell(Vector2i(5, 2))
	wraith.set_cell(Vector2i(6, 2))
	blade.strength = 15  # enough to hurt through DEF either way
	give_weapon(blade, "Iron Axe")
	var full := Combat.damage(blade, wraith, b.map)
	wraith.tags.assign(["spirit"])
	check_eq(Combat.damage(blade, wraith, b.map), floori(full / 2.0), "non-silver weapon: half damage")
	check(Combat.side_stats(blade, wraith, b.map).resisted, "forecast flags the resistance")
	# Silver: not resisted, and effective (x3 might).
	blade.items.remove_at(0)
	give_weapon(blade, "Silver Axe")
	var mt: int = Weapons.DATA["Silver Axe"].mt
	check_eq(Combat.damage(blade, wraith, b.map), blade.strength + mt * 3 - wraith.defense,
		"silver weapon: full damage, might x3")
	check(not Combat.side_stats(blade, wraith, b.map).resisted, "silver isn't resisted")
	# Magic isn't a physical weapon: spirits take it normally.
	var fire := Spells.get_spell("Fire")
	mage.set_cell(Vector2i(4, 2))
	var vs_spirit := Combat.spell_damage(mage, wraith, fire, b.map)
	wraith.tags.assign(["foot"])
	check_eq(vs_spirit, Combat.spell_damage(mage, wraith, fire, b.map), "spells ignore spirit resistance")


func test_forecast_shows_effectiveness() -> void:
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([archer, brig])
	archer.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(7, 2))
	brig.tags.assign(["flying"])
	b.ui.show_forecast(archer, brig, Combat.forecast(archer, brig, b.map), archer.cell)
	var weapon_label: Label = b.ui._forecast_cells[1][1]
	check(weapon_label.text.ends_with("x3"), "attacker's weapon tagged x3 (got '%s')" % weapon_label.text)


func test_ai_prefers_effective_weapon() -> void:
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var knight := unit_named("Knight")
	isolate([brig, knight])
	check_eq(knight.move_type, "heavy", "the Knight (Guard) wears heavy armor")
	brig.items.assign([Items.make("Iron Axe"), Items.make("Hammer")])
	brig.set_cell(Vector2i(5, 2))
	knight.set_cell(Vector2i(6, 2))
	var plan: Dictionary = EnemyAI._best_attack(brig, b, {brig.cell: 0})
	check_eq(plan.get("weapon", {}).get("name", ""), "Hammer", "AI picks the Hammer vs armor")


# --- Races --------------------------------------------------------------------


func test_race_class_bans() -> void:
	for c in [
		["Naga", "Cavalry", false], ["Naga", "Flier", false], ["Naga", "Footman", true],
		["Centaur", "Flier", false], ["Centaur", "Guard", true], ["Minotaur", "Nomad", false],
		["Harpy", "Guard", false], ["Harpy", "Cavalry", true], ["Ent", "Equestrian", false],
		["Stoneborn", "Rogue", false], ["Stoneborn", "Cavalry", false], ["Stoneborn", "Guard", true],
		["Stoneborn", "Axeman", true], ["Human", "Flier", true],
	]:
		check_eq(Races.allows(c[0], c[1]), c[2], "%s %s allowed" % [c[0], c[1]])
	for r in Races.DATA:
		check(Races.DATA[r].has("description"), "%s has a description" % r)


func test_race_movement_and_tags() -> void:
	var fighter := unit_named("Fighter")  # Axeman
	var knight := unit_named("Knight")  # Guard
	var thief := unit_named("Thief", Unit.Team.ENEMY)  # Rogue
	var galley := unit_named("Archer")
	check_eq(fighter.tags, ["foot"] as Array[String], "a Human's tags are its class's")
	fighter.set_race("Naga")
	check_eq(fighter.move_type, "mermaid", "Nagas always move as aquatic")
	check(fighter.tags.has("foot") and fighter.tags.has("aquatic") and fighter.tags.has("reptile"),
		"and keep the class tag next to their own")
	knight.set_race("Centaur")
	check_eq(knight.move_type, "horse", "Centaur Guard moves as a horse")
	check(knight.tags.has("heavy") and knight.tags.has("horse"), "but is still a heavy target")
	check_eq(knight.mov_bonus, 0, "no MOV bonus outside foot and scout classes")
	var base := knight.mov
	knight.set_class("Footman")
	check_eq(knight.mov, base + 1, "+1 MOV in a foot class")
	knight.set_race("Lizal")
	check(Skills.has(knight, "Swimming") and Skills.has(knight, "Climbing"), "Lizal on foot swims and climbs")
	check_eq(knight.mov, base, "bonus gone with the race")
	thief.set_race("Lizal")
	check(Skills.has(thief, "Forester") and Skills.has(thief, "Swimming"), "a Lizal scout keeps scout movement too")
	check(is_equal_approx(b.map.unit_cost(thief, Vector2i(4, 5)), 1.5)
		and is_equal_approx(b.map.unit_cost(thief, Vector2i(7, 0)), 2.0)
		and is_equal_approx(b.map.unit_cost(thief, Vector2i(2, 3)), 4.0), "cheapest of the three")
	knight.set_class("Cavalry")
	check(knight.move_type == "horse" and not Skills.has(knight, "Swimming"), "a Lizal rider just rides")
	fighter.set_race("Harpy")
	check_eq(fighter.move_type, "flying", "Harpies fly")
	fighter.set_class("Cavalry")
	check_eq(fighter.move_type, "horse", "unless mounted")
	check(fighter.tags.has("flying"), "but still count as fliers")
	fighter.set_race("Ghost")
	check_eq(fighter.move_type, "spirit", "Ghosts always move as spirits")
	fighter.set_class("Axeman")
	fighter.set_race("Stoneborn")
	check(fighter.move_type == "heavy" and fighter.tags.has("heavy"), "Stoneborn move and count as heavy")
	fighter.set_race("Ent")
	check(fighter.move_type == "heavy" and not fighter.tags.has("heavy"), "Ents only move as heavy")
	galley.set_class("Galley")
	galley.set_race("Ghost")
	check_eq(galley.move_type, "ship", "ships keep sailing whatever the crew")


func test_race_weaknesses_and_resistances() -> void:
	var fighter := unit_named("Fighter")  # Axeman
	var soldier := unit_named("Knight")  # Guard (spears)
	var target := unit_named("Cleric")
	isolate([fighter, soldier, target])
	target.set_cell(Vector2i(6, 2))  # plain: no terrain DEF
	soldier.set_cell(Vector2i(5, 2))
	fighter.set_cell(Vector2i(7, 2))
	fighter.strength = 15
	soldier.strength = 15
	var spear := Items.make("Iron Spear")
	var axe := Items.make("Iron Axe")
	# Weak (x2): spears vs aquatic, axes vs wooden.
	var human_dmg := Combat.damage(soldier, target, b.map)
	target.set_race("Naga")
	check_eq(Combat.multiplier(spear, target), 2, "spears are x2 vs aquatic")
	check_eq(Combat.damage(soldier, target, b.map), human_dmg + spear.mt, "spear might doubled vs Naga")
	target.set_race("Ent")
	check_eq(Combat.multiplier(axe, target), 2, "axes are x2 vs wooden")
	check_eq(Combat.multiplier(Items.make("Hammer"), target), 2, "the Hammer is just an axe vs Ents")
	# Effective (x3) beats Weak and isn't stacked with it.
	soldier.set_race("Centaur")
	check_eq(Combat.multiplier(Items.make("Hammer"), soldier), 3, "Hammer effective vs a Centaur Guard")
	check_eq(Combat.multiplier(Items.make("Pike"), soldier), 3, "and so is the Pike")
	# Undead: silver is x2; a Ghost's spirit tag makes it x3 instead (no stacking).
	var silver := Items.make("Silver Axe")
	target.set_race("Skeleton")
	check_eq(Combat.multiplier(silver, target), 2, "silver x2 vs Skeletons")
	check(not Combat.resists(target, axe), "Skeletons don't resist iron")
	target.set_race("Ghost")
	check_eq(Combat.multiplier(silver, target), 3, "silver x3 vs Ghosts (spirit), not x6")
	check(Combat.resists(target, axe), "Ghosts resist iron like any spirit")
	check(not Combat.resists(target, silver), "but not silver")


func test_race_spell_elements() -> void:
	var mage := unit_named("Mage")
	var target := unit_named("Cleric")
	isolate([mage, target])
	target.set_cell(Vector2i(6, 2))
	mage.set_cell(Vector2i(5, 2))
	mage.intelligence = 20
	target.mp = 0
	var fire := Spells.get_spell("Fire")
	var spike := Spells.get_spell("Earth Spike")
	var full := Combat.spell_damage(mage, target, fire, b.map)
	target.set_race("Naga")
	check_eq(Combat.spell_damage(mage, target, fire, b.map), floori(full / 2.0),
		"Nagas resist Fire once, though both Aquatic and Reptile resist it")
	check(Combat.spell_forecast(mage, target, fire, b.map).atk.resisted, "forecast flags it")
	target.set_race("Ent")
	check_eq(Combat.spell_damage(mage, target, fire, b.map), full + fire.power, "Ents take x2 Fire power")
	check_eq(Combat.spell_forecast(mage, target, fire, b.map).atk.multiplier, 2, "forecast shows x2")
	var spike_full: int = mage.intelligence + spike.power
	check_eq(Combat.spell_damage(mage, target, spike, b.map), floori(spike_full / 2.0), "and resist Earth")
	target.set_race("Ghost")
	check_eq(Combat.spell_damage(mage, target, fire, b.map), full + fire.power, "the undead burn too")


func test_race_carry_and_shove() -> void:
	var fighter := unit_named("Fighter")
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	isolate([fighter, knight, archer])
	fighter.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	archer.set_cell(Vector2i(3, 6))
	fighter.set_race("Centaur")
	check(b.actions.can_shove(fighter, knight), "Centaurs can shove")
	check(not b.actions.can_shove(knight, fighter), "but can't be shoved")
	check_eq(b.actions.rescue_targets(fighter).size(), 2, "and can carry allies on foot")
	archer.set_class("Cavalry")
	check(not b.actions.rescue_targets(archer).has(fighter), "but can't be carried")
	fighter.set_race("Human")
	fighter.set_class("Cavalry")
	knight.set_race("Ent")
	check(not b.actions.rescue_targets(fighter).has(knight), "Ents can't be carried")
	fighter.set_class("Axeman")
	check(not b.actions.can_shove(fighter, knight), "or shoved")
	knight.set_race("Stoneborn")
	check(not b.actions.can_shove(fighter, knight), "nor can the Stoneborn")
	archer.set_cell(Vector2i(0, 0))  # clear the landing cell
	check(b.actions.can_shove(knight, fighter), "though they can shove others")


func test_race_regen_and_exp() -> void:
	var lord := unit_named("Lord")
	var mage := unit_named("Mage")
	isolate([lord, mage])
	lord.set_cell(Vector2i(6, 2))  # plain: no tile healing
	lord.set_race("Troll")
	lord.hp = 5
	await b.phases.heal_on_tiles(Unit.Team.PLAYER)
	check_eq(lord.hp, 5 + ceili(lord.max_hp * 0.1), "Trolls regenerate 10% HP")
	check_eq(mage.mp_regen(), Spells.MP_REGEN, "normal MP regen")
	mage.set_race("Fairy")
	check_eq(mage.mp_regen(), Spells.MP_REGEN + 1, "Fairies recover 1 more")
	lord.exp_points = 0
	await b.actions.gain_exp(lord, 10)
	check_eq(lord.exp_points, 10, "Trolls earn plain EXP")
	lord.set_race("Human")
	await b.actions.gain_exp(lord, 10)
	check_eq(lord.exp_points, 21, "Humans earn 10% more")


func test_generic_names() -> void:
	var data := {"class": "Brigand", "items": ["Iron Axe"], "hp": 20, "str": 5, "dex": 1, "agi": 4,
		"lck": 0, "def": 3, "mov": 5, "generic": true, "gender": "female"}
	var u := Unit.create("Brigand", Unit.Team.ENEMY, Vector2i.ZERO, data)
	check(u.generic, "marked generic")
	check(Names.DEFAULT.female.has(u.unit_name), "a random name for its gender (%s)" % u.unit_name)
	check_eq(u.token_letter(), "B", "its map token shows the class's initial")
	u.free()
	data.erase("generic")
	u = Unit.create("Brigand", Unit.Team.ENEMY, Vector2i.ZERO, data)
	check_eq(u.unit_name, "Brigand", "named units keep their roster name")
	u.free()
	# Campaign generics; bosses keep their names.
	await start_chapter(1)
	var enemies: Array[Unit] = b.units_of(Unit.Team.ENEMY)
	check(enemies.filter(func(e): return e.generic).size() >= 5, "chapter enemies are generics")
	check(unit_named("Commander", Unit.Team.ENEMY) != null, "the boss keeps its name")
	check(unit_named("Commander", Unit.Team.ENEMY).is_boss, "and is a boss")


func test_kills_and_biography_moments() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	_spawn_enemy(Vector2i(14, 9))
	var dealt: Array[Unit] = []
	var bio := lord.biography.size()
	# First kill: unit and weapon kill counts, a biography entry.
	b.actions._apply_strike(lord, brig, {"hit": true, "crit": false, "dmg": 99}, dealt)
	check_eq(lord.kills, 1, "the kill counts")
	check_eq(lord.weapon.get("kills", 0), 1, "and so does the weapon's")
	check(Glossary.item(lord.weapon).contains("Kills: 1"), "shown in the weapon's description")
	check_eq(lord.biography.size(), bio + 1, "a biography entry")
	check(lord.biography[-1].begins_with("Felled their first foe, Brigand"), "for the first kill")
	# A boss, with a critical hit.
	var boss := _spawn_enemy(Vector2i(6, 6))
	boss.is_boss = true
	boss.unit_name = "Warlord"
	b.actions._apply_strike(lord, boss, {"hit": true, "crit": true, "dmg": 99}, dealt)
	check(lord.biography[-1].begins_with("Defeated Warlord with a critical hit"), "boss kill noted")
	# Spells don't count toward the equipped weapon's kills.
	var foe := _spawn_enemy(Vector2i(6, 6))
	b.actions._apply_strike(lord, foe, {"hit": true, "crit": false, "dmg": 99, "spell": true}, dealt)
	check_eq(lord.kills, 3, "spell kills count for the unit")
	check_eq(lord.weapon.kills, 2, "but not for its weapon")
	# A close call, once per battle.
	foe = _spawn_enemy(Vector2i(6, 6))
	bio = lord.biography.size()
	lord.hp = lord.max_hp
	b.actions._apply_strike(foe, lord, {"hit": true, "crit": false, "dmg": lord.max_hp - 1}, dealt)
	check(lord.biography[-1].begins_with("Barely survived"), "close call noted")
	lord.hp = lord.max_hp
	b.actions._apply_strike(foe, lord, {"hit": true, "crit": false, "dmg": lord.max_hp - 1}, dealt)
	check_eq(lord.biography.size(), bio + 1, "once per battle")
	# Saved by Miracle.
	lord.hp = 10
	b.actions._apply_strike(foe, lord, {"hit": true, "crit": false, "dmg": 9, "procs": [[lord, "Miracle"]]}, dealt)
	check(lord.biography[-1].contains("thanks to Miracle"), "Miracle saves are noted")
	# Enemies get no entries.
	var enemy_bio := foe.biography.size()
	b.actions._apply_strike(lord, foe, {"hit": true, "crit": false, "dmg": foe.max_hp - 1}, dealt)
	check_eq(foe.biography.size(), enemy_bio, "enemies have no biography")


func test_dragon_and_fire_breath() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	_spawn_enemy(Vector2i(14, 9))
	b.units_root.add_child(Unit.create("Idle", Unit.Team.PLAYER, Vector2i(0, 0), {"class": "Axeman", "items": [],
		"hp": 20, "str": 5, "dex": 5, "agi": 5, "lck": 5, "def": 5, "mov": 5}))
	# The race: flies, counts as a flier and a reptile, breathes fire.
	lord.spells.clear()  # this Lord knows Earth Spike
	lord.set_race("Dragon")
	check_eq(lord.move_type, "flying", "Dragons fly")
	check(lord.tags.has("flying") and lord.tags.has("reptile"), "flier and reptile tags")
	check_eq(Skills.abilities(lord), ["Fire Breath"] as Array[String], "Fire Breath")
	check(not lord.is_caster(), "not a caster (no MP bar, no Magic menu)")
	# STR + 6 against DEF, fire: a Brigand takes it plainly, a reptile resists it.
	var breath := Spells.get_spell("Fire Breath")
	var expected := maxi(0, lord.combat_str() + 6 - brig.combat_def())
	check_eq(Combat.spell_damage(lord, brig, breath, b.map), expected, "STR + 6 vs DEF")
	brig.set_race("Lizal")
	check_eq(Combat.spell_damage(lord, brig, breath, b.map), floori(expected / 2.0), "reptiles resist fire")
	brig.set_race("Human")
	# Threat range includes the breath (range 2).
	lord.items.clear()
	check(b.offense_ranges(lord).has(Vector2i(1, 2)), "breath reach shows in its ranges")
	# Used from its own unit menu entry, with a spell-style forecast; no MP spent.
	var mp := lord.mp
	await open_menu_in_place(lord)
	check(not b.ui.menu_options.has("Magic"), "no Magic menu")
	await pick("Fire Breath")
	check_eq(b.input.target_mode, "ability", "targeting the breath")
	await press(KEY_X)
	check_eq(b.input.menu_context, "unit", "X goes back to the unit menu")
	await pick("Fire Breath")
	brig.hp = 99
	brig.max_hp = 99
	await press(KEY_Z)
	check(lord.has_acted, "breathing ends the turn")
	check_eq(lord.mp, mp, "no MP spent")
	# The AI breathes too: an unarmed enemy Dragon attacks with it.
	brig.set_race("Dragon")
	brig.items.clear()
	brig.has_acted = false
	lord.hp = lord.max_hp
	var hp_before := lord.hp
	brig.set_cell(Vector2i(7, 6))  # range 2 from the Lord at (5, 6)
	brig.ai = AIProfiles.resolve({"move": "hold"})
	lord.agility = 0
	brig.dexterity = 100
	await EnemyAI.take_turn(brig, b)
	check(lord.hp < hp_before, "the enemy Dragon breathed on the Lord")
