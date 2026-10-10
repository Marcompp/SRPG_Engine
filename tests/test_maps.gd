extends "res://tests/test_base.gd"
## Breakable tiles and doors, the camera and maps bigger than the screen.


# --- Breakable tiles and doors (Ruined Fort) ----------------------------------


func test_break_wall_through_menu() -> void:
	await start_level("ruined_fort")
	var wall := Vector2i(6, 2)
	var fighter := unit_named("Fighter")
	check_eq(b.map.tile_hp.get(wall), 20, "a cracked wall starts at 20 HP")
	check_eq(b.map.cost_for("x", "flying"), BattleMap.IMPASSABLE, "fliers can't cross walls, cracked or not")
	fighter.set_cell(Vector2i(2, 7))
	await open_menu_in_place(fighter)
	check(not b.ui.menu_options.has("Break"), "nothing breakable in reach, no Break")
	await press(KEY_X)
	await press(KEY_X)
	fighter.set_cell(Vector2i(7, 2))
	await open_menu_in_place(fighter)
	await pick("Break")
	check_eq(b.ui.menu_options.size(), 2, "both axes reach the wall")
	await press(KEY_Z)  # Iron Axe
	check_eq(b.input.target_mode, "break", "then pick the tile")
	check_eq(b.cursor.cell, wall, "the cursor jumps to it")
	check(b.ui._spell_label.text.contains("Cracked Wall  HP 20 -> 5"), "forecast: STR 7 + Mt 8 = 15 damage")
	await press(KEY_Z)
	check_eq(b.map.tile_hp.get(wall), 5, "the wall takes the damage")
	b.cursor.cell = wall
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Cracked Wall  HP 5/20"), "hovering shows its remaining HP")
	check(not b.ui._info_label.text.contains("AVO"), "instead of terrain bonuses")
	check_eq(b.map.terrain_key(wall), "x", "and still stands")
	check(fighter.has_acted, "breaking ends the unit's turn")
	check_eq(fighter.items[0].uses, 44, "and uses the weapon")
	await b.actions.do_break(fighter, wall)
	check_eq(b.map.terrain_key(wall), "_", "broken: it becomes floor")
	check(not b.map.tile_hp.has(wall), "and has no HP left to track")
	check(b.can_stand_on(fighter, wall), "units can walk through")


func test_break_fence_and_trunk_bridge() -> void:
	await start_level("ruined_fort")
	var archer := unit_named("Archer")
	# A cracked fence becomes plain; bows break it from range.
	var fence := Vector2i(8, 5)
	archer.set_cell(Vector2i(6, 5))
	check(b.actions.breakable_in_reach(archer).has(fence), "the bow reaches the fence at range 2")
	await b.actions.do_break(archer, fence)
	check_eq(b.map.terrain_key(fence), ".", "10 HP: one shot (STR 5 + Mt 6) breaks it into a plain")
	# A trunk falls into the river next to it, away from the attacker if possible.
	var trunk := Vector2i(11, 2)
	archer.set_cell(Vector2i(9, 2))
	b.map.tile_hp[trunk] = 1
	await b.actions.do_break(archer, trunk)
	check_eq(b.map.terrain_key(trunk), ".", "the trunk leaves a plain")
	check_eq(b.map.terrain_key(Vector2i(10, 2)), "B", "and bridges the river")
	check_eq(b.map.terrain_key(Vector2i(9, 2)), ".", "the bridge stops at dry land")
	check_eq(BattleMap.cost_for("B", "mermaid"), 1.0, "water units pass under the bridge")
	# With water on both sides, it falls away from whoever broke it.
	var trunk2 := Vector2i(11, 5)
	for x in [12, 13, 14]:
		b.map.set_terrain(Vector2i(x, 5), "~")
	archer.set_cell(Vector2i(9, 5))
	b.map.tile_hp[trunk2] = 1
	await b.actions.do_break(archer, trunk2)
	check_eq(b.map.terrain_key(Vector2i(10, 5)), "~", "not toward the archer")
	for x in [12, 13, 14]:
		check_eq(b.map.terrain_key(Vector2i(x, 5)), "B", "away from it, up to 3 tiles (%d)" % x)


func test_doors_open_or_break() -> void:
	await start_level("ruined_fort")
	var door := Vector2i(3, 4)
	var scout := unit_named("Scout")
	var knight := unit_named("Knight")
	check(b.map.is_door(door), "a locked door")
	# Anyone without a key can only break it.
	knight.set_cell(Vector2i(3, 5))
	await open_menu_in_place(knight)
	check(not b.ui.menu_options.has("Open Door"), "no key, no Open Door")
	check(b.ui.menu_options.has("Break"), "but it can be broken")
	await press(KEY_X)
	await press(KEY_X)
	# A rogue opens it freely.
	knight.set_cell(Vector2i(4, 7))
	scout.set_cell(Vector2i(3, 5))
	await open_menu_in_place(scout)
	await pick("Open Door")
	check(b.ui._spell_label.text.contains("Open Door"), "forecast")
	await press(KEY_Z)
	check_eq(b.map.terrain_key(door), "_", "the door opens onto floor")
	check(scout.has_acted, "opening ends the turn")
	check(not b.map.tile_hp.has(door), "an open door has nothing left to break")
	# A Chest Key works too, and is used up.
	b.map.set_terrain(door, "+")
	check_eq(b.map.tile_hp.get(door), 20, "a fresh door has full HP")
	scout.set_cell(Vector2i(5, 7))
	knight.set_cell(Vector2i(3, 5))
	knight.items.append(Items.make("Chest Key"))
	await open_menu_in_place(knight)
	await pick("Open Door")
	await press(KEY_Z)
	check_eq(b.map.terrain_key(door), "_", "opened with a key")
	check(not knight.items.any(func(it): return it.name == "Chest Key"), "the key is used up")


func test_tile_hp_survives_suspend() -> void:
	await start_level("ruined_fort")
	b.map.damage_tile(Vector2i(6, 2), 7, Vector2i(7, 2))
	b.map.damage_tile(Vector2i(8, 5), 10, Vector2i(7, 5))
	SaveGame.write_suspend(b)
	Levels.selected = "ruined_fort"
	Levels.resume = true
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 13, "damaged wall keeps its HP")
	check_eq(b.map.terrain_key(Vector2i(8, 5)), ".", "broken fence stays broken")
	check_eq(b.map.tile_hp.get(Vector2i(3, 4)), 20, "untouched door at full HP")
	SaveGame.delete_suspend()


func test_ruined_fort_phases_run_without_errors() -> void:
	await start_level("ruined_fort")
	await run_enemy_phases()


func test_enemies_break_and_open_obstacles() -> void:
	await start_level("ruined_fort")
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([lord, brig])
	await process_frame
	brig.ai = AIProfiles.resolve({})  # a charger
	brig.items.assign([Items.make("Iron Axe")])
	brig.equip(0)
	lord.set_cell(Vector2i(2, 2))  # walled in
	# The cracked wall is the short way in: it walks up and hits it (STR 5 + Mt 8).
	brig.set_cell(Vector2i(7, 2))
	await EnemyAI.take_turn(brig, b)
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 7, "a charger breaks the wall in its way")
	# Units that don't break things leave it alone.
	b.map.set_terrain(Vector2i(6, 2), "x")
	brig.has_acted = false
	brig.ai = AIProfiles.resolve({"breaks": false})
	await EnemyAI.take_turn(brig, b)
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 20, "breaks: false leaves the wall alone")
	# With a Chest Key, a door is quicker: it walks up and opens it.
	brig.has_acted = false
	brig.ai = AIProfiles.resolve({})
	brig.items.append(Items.make("Chest Key"))
	lord.set_cell(Vector2i(3, 2))
	brig.set_cell(Vector2i(3, 7))
	await EnemyAI.take_turn(brig, b)
	check_eq(brig.cell, Vector2i(3, 5), "it walks to the door")
	check_eq(b.map.terrain_key(Vector2i(3, 4)), "_", "and opens it")
	check(not brig.items.any(func(it): return it.name == "Chest Key"), "using up its key")
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 20, "the wall is left alone")


func test_hidden_gender() -> void:
	var data := {"class": "Brigand", "items": ["Iron Axe"], "hp": 20, "str": 5, "dex": 1, "agi": 4,
		"lck": 0, "def": 3, "mov": 5}
	# Generics get a random gender.
	var seen := {}
	for i in 40:
		var u := Unit.create("Brigand", Unit.Team.ENEMY, Vector2i.ZERO, data)
		check(Unit.GENDERS.has(u.gender), "a valid gender (%s)" % u.gender)
		seen[u.gender] = true
		u.free()
	check_eq(seen.size(), Unit.GENDERS.size(), "both genders show up among generics")
	# A roster "gender" fixes it.
	data["gender"] = "female"
	for i in 10:
		var u := Unit.create("Rider", Unit.Team.PLAYER, Vector2i.ZERO, data)
		check_eq(u.gender, "female", "roster gender is kept")
		u.free()
	# It's saved with the unit, so suspends and the campaign army keep it.
	var lord := unit_named("Lord")
	lord.gender = "female"
	var copy := SaveGame.unit_from_dict(SaveGame.unit_to_dict(lord))
	check_eq(copy.gender, "female", "gender survives saving")
	copy.free()


# --- Bigger maps (BattleCamera) -----------------------------------------------


func test_camera_on_small_and_big_maps() -> void:
	# One-screen maps never scroll.
	b.cursor.cell = Vector2i(14, 9)
	await process_frame
	check_eq(b.camera.origin, Vector2i.ZERO, "a 15x10 map doesn't scroll")
	await start_level("great_valley")
	check_eq(b.camera.view, Vector2i(15, 10), "the view is 15x10 tiles")
	check_eq(b.camera.origin, Vector2i(0, 10), "starts on the Lord (bottom-left)")
	check(b.camera.is_settled(), "without scrolling there")
	# Moving the cursor right scrolls once it's within 2 tiles of the edge.
	for i in 12:
		await press(KEY_RIGHT)
	check_eq(b.cursor.cell.x, 14, "cursor moved")
	check_eq(b.camera.origin.x, 2, "the view scrolled to keep 2 tiles of margin")
	check_eq(b.camera.screen_cell(b.cursor.cell).x, 12, "cursor 2 tiles from the right edge")
	for i in 20:
		await press(KEY_RIGHT)
	check_eq(b.cursor.cell.x, 29, "cursor at the map's right edge")
	check_eq(b.camera.origin.x, 15, "the view stops at the map edge")
	# Panels go to the side of the screen away from the cursor, not the map.
	b.cursor.cell = Vector2i(17, 15)
	await process_frame
	check(b.ui._away_right(b.cursor.cell), "cursor on the left of the screen: panels on the right")
	await b.camera.settle()
	check_eq(b.camera.position, Vector2(b.camera.origin * BattleMap.TILE), "scrolling finishes")
	# A moving unit is followed instead of the cursor.
	var lord := unit_named("Lord")
	b.cursor.cell = lord.cell
	await process_frame
	lord.moving = true
	lord.position = Vector2(Vector2i(10, 4) * BattleMap.TILE)
	check_eq(b.camera_focus(), Vector2i(10, 4), "the camera follows a moving unit")
	lord.moving = false
	lord.set_cell(lord.cell)


func test_great_valley_phases_run_without_errors() -> void:
	await start_level("great_valley")
	await run_enemy_phases()
