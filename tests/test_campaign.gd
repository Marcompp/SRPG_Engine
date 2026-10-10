extends "res://tests/test_base.gd"
## Campaign: objectives, map objects, reinforcements, the army, the prep screen, Check Map.


# --- Campaign: objectives, map objects, reinforcements, army, prep ------------


func test_all_chapters_are_valid() -> void:
	for id in Chapters.ORDER:
		var level := Levels.get_level(id)
		var layout: Array = level.layout
		var at := func(c: Vector2i) -> String: return layout[c.y][c.x]
		var inside := func(c: Vector2i) -> bool:
			return c.x >= 0 and c.y >= 0 and c.y < layout.size() and c.x < layout[0].length()
		for row in layout:
			check_eq(row.length(), layout[0].length(), "%s: rows have equal length" % id)
		var taken := {}
		for c in level.deploy:
			check(inside.call(c) and BattleMap.cost_for(at.call(c), "foot") >= 0, "%s: deploy cell %s usable" % [id, c])
			check(not taken.has(c), "%s: deploy cell %s listed once" % [id, c])
			taken[c] = true
		var all_units: Array = level.enemies + level.recruits
		for wave in level.get("reinforcements", []):
			all_units += wave.units
		for data in all_units:
			check(Classes.DATA.has(data.get("class", "")), "%s: %s has a known class" % [id, data.name])
			var cls := Classes.get_data(data["class"])
			for item_name in data.get("items", []):
				if Weapons.DATA.has(item_name):
					check(cls.weapons.has(Weapons.DATA[item_name].type), "%s: %s can wield %s" % [id, data.name, item_name])
				else:
					check(Items.CONSUMABLES.has(item_name), "%s: %s carries a known item %s" % [id, data.name, item_name])
		for data in level.enemies:
			var move_type := Races.move_type(data.get("race", "Human"), data["class"])  # races can change movement
			check(inside.call(data.cell) and BattleMap.cost_for(at.call(data.cell), move_type) >= 0,
				"%s: %s can stand on its start tile" % [id, data.name])
			check(not taken.has(data.cell), "%s: %s shares a tile" % [id, data.name])
			taken[data.cell] = true
		for o in level.get("objects", []):
			check(inside.call(o.cell), "%s: object at %s on the map" % [id, o.cell])
			check(Items.CONSUMABLES.has(o.item) or Weapons.DATA.has(o.item), "%s: reward %s exists" % [id, o.item])
		var obj := Objectives.of(level)
		for c in Objectives.marked_cells(obj):
			check(inside.call(c) and BattleMap.cost_for(at.call(c), "foot") >= 0, "%s: objective tile %s reachable" % [id, c])
		if obj.type == "boss":
			check(level.enemies.any(func(e): return e.name == obj.boss), "%s: the boss is on the map" % id)


func test_seize_objective() -> void:
	await start_chapter(1)
	var lord := unit_named("Lord")
	remove_unit(unit_named("Commander", Unit.Team.ENEMY))
	lord.set_cell(Vector2i(7, 0))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	check(b.ui.menu_options.has("Seize"), "the Lord on the throne can Seize")
	await pick("Seize")
	check_eq(b.battle_result, "victory", "seizing wins")
	check(lord.biography.any(func(e): return e.begins_with("Seized")), "logged in the Lord's biography")


func test_boss_objective() -> void:
	await start_chapter(2)
	check(not b.phases.check_game_over(), "boss alive: battle goes on")
	remove_unit(unit_named("Bandit King", Unit.Team.ENEMY))
	check(b.phases.check_game_over(), "boss down: it's over...")
	check_eq(b.battle_result, "victory", "...and won, though other enemies remain")


func test_defend_objective() -> void:
	await start_chapter(3)
	b.turn = 6
	check(not b.phases.check_game_over(true), "turn 6 of 7: not yet")
	b.turn = 7
	check(b.phases.check_game_over(true), "after enemy phase 7: over")
	check_eq(b.battle_result, "victory", "held out: victory")
	await start_chapter(3)
	var soldier: Unit = b.units_of(Unit.Team.ENEMY)[0]
	soldier.set_cell(Vector2i(6, 3))
	b.phases.check_game_over()
	check_eq(b.battle_result, "defeat", "an enemy on the town hall: defeat")


func test_escape_objective() -> void:
	await start_chapter(4)
	var lord := unit_named("Lord")
	var other: Unit = b.units_of(Unit.Team.PLAYER).filter(func(u): return not u.is_lord)[0]
	other.set_cell(Vector2i(6, 9))
	b.cursor.cell = other.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Escape")
	check(other.escaped and not b.units().has(other), "a unit escapes off the map")
	check(b.all_units().has(other), "but stays in the army")
	check_eq(b.battle_result, "", "only the Lord escaping wins")
	lord.set_cell(Vector2i(7, 9))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Escape")
	check_eq(b.battle_result, "victory", "the Lord escaping wins")


func test_villages_visit_and_loot() -> void:
	await start_chapter(0)
	var lord := unit_named("Lord")
	var items_before := lord.items.size()
	lord.set_cell(Vector2i(5, 0))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Visit")
	check_eq(b.map.object_at(Vector2i(5, 0)).state, "visited", "village visited")
	check_eq(lord.items.size(), items_before + 1, "its reward is added")
	check_eq(lord.items[-1].name, "Potion", "the village's item")
	# Campaign enemies are generics with random names: find the thief by class.
	var thief: Unit = b.units_of(Unit.Team.ENEMY).filter(func(u): return u.unit_class == "Rogue")[0]
	thief.set_cell(Vector2i(11, 2))  # one step from the other village
	await EnemyAI.take_turn(thief, b)
	check_eq(b.map.object_at(Vector2i(11, 3)).state, "looted", "the thief burns the other village")


func test_chests() -> void:
	await start_chapter(1)
	var scout := unit_named("Scout")
	var lord := unit_named("Lord")
	scout.set_cell(Vector2i(3, 2))
	b.cursor.cell = scout.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Open")
	check_eq(scout.items[-1].name, "Silver Sword", "a rogue opens chests without a key")
	check_eq(b.map.object_at(Vector2i(3, 2)).state, "opened", "chest opened")
	# Anyone else needs a Chest Key, which is used up.
	lord.set_cell(Vector2i(11, 2))
	check(not b.actions.can_open_chest(lord), "no key, no Open")
	lord.items.append(Items.make("Chest Key"))
	check(b.actions.can_open_chest(lord), "with a key: Open")
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Open")
	check(not lord.items.any(func(it): return it.name == "Chest Key"), "the key is used up")
	check(lord.items.any(func(it): return it.name == "Hammer"), "and the chest's item received")


func test_reinforcements() -> void:
	await start_chapter(3)
	var before: int = b.units_of(Unit.Team.ENEMY).size()
	b.turn = 2
	await b.phases.spawn_reinforcements()
	var arrived: Array = b.units_of(Unit.Team.ENEMY).filter(func(u): return u.has_acted)
	check_eq(b.units_of(Unit.Team.ENEMY).size(), before + 2, "turn 2: two reinforcements arrive")
	check_eq(arrived.size(), 2, "and wait until the next phase to act")


func test_campaign_army_carries_over() -> void:
	await start_chapter(0)
	check_eq(Campaign.army.size(), 5, "starting army")
	var lord := unit_named("Lord")
	var fighter := unit_named("Fighter")
	lord.exp_points = 60
	lord.items.append(Items.make("Chest Key"))
	fighter.hp = 0
	var involved: Array[Unit] = [fighter]
	await b.actions._remove_dead_and_award(involved, [])
	b.battle_result = "victory"
	Campaign.finish_chapter(b)
	check_eq(Campaign.chapter, 1, "on to chapter 2")
	check(Campaign.army_unit("Fighter").is_empty(), "the fallen Fighter left the army (permadeath)")
	check_eq(Campaign.fallen.size(), 1, "kept among the fallen")
	check(Campaign.fallen[0].unit.biography[-1].begins_with("Fell in Chapter 1"), "with the event in its biography")
	check_eq(Campaign.army_unit("Lord").exp_points, 60, "EXP carried over")
	check(Campaign.army_unit("Lord").items.any(func(it): return it.name == "Chest Key"), "items carried over")
	check(not Campaign.army_unit("Scout").is_empty(), "chapter 2's recruit joined")
	check(Campaign.army_unit("Scout").biography[-1].begins_with("Joined the army in Chapter 2"), "and logged it")
	# Saved: a reload gets the same campaign back.
	var army_before := var_to_str(Campaign.army)
	Campaign.army = []
	check(Campaign.load_save(), "campaign saved")
	check_eq(var_to_str(Campaign.army), army_before, "and loads back unchanged")


func test_promotion() -> void:
	Campaign.start_new()
	var lord: Dictionary = Campaign.army_unit("Lord")
	check(not Campaign.can_promote(lord), "Lv 1 can't promote")
	lord.level = 15
	check(Campaign.can_promote(lord), "Lv 15 can")
	var str_before: int = lord.strength
	var gains := Campaign.promote("Lord", "Swordsmaster")
	var promoted := Campaign.army_unit("Lord")
	check_eq(promoted.unit_class, "Swordsmaster", "new class")
	check_eq(promoted.level, 15, "level kept")
	check_eq(promoted.strength, str_before + Classes.promotion_bonus("Swordsmaster").str, "class bonus applied")
	check_eq(gains.str, Classes.promotion_bonus("Swordsmaster").str, "gains reported")
	check(promoted.biography[-1].begins_with("Promoted to Swordsmaster"), "logged")


func test_prep_screen() -> void:
	Campaign.start_new()
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	await process_frame
	check_eq(prep.picked.size(), 5, "default deployment: everyone (5 of 6 slots)")
	prep._enter("pick")
	prep._toggle_pick("Lord")
	check(prep.picked.has("Lord"), "the Lord can't be benched")
	prep._toggle_pick("Archer")
	check(not prep.picked.has("Archer"), "others can")
	# Items: Lord's Potion to the convoy and back.
	prep.current_unit = "Lord"
	prep.mode = "items"
	prep.column = 0
	prep.index = 1
	prep._move_item()
	check_eq(Campaign.convoy.size(), 1, "item stored in the convoy")
	prep.column = 1
	prep.index = 0
	prep._move_item()
	check(Campaign.convoy.is_empty() and Campaign.army_unit("Lord").items.size() == 2, "and taken back")
	prep.queue_free()


func test_check_map_formation() -> void:
	Campaign.start_new()
	Campaign.active = true
	Campaign.deployed = Campaign.default_deployment()
	Campaign.checking_map = true
	Levels.selected = Chapters.ORDER[0]
	b.queue_free()
	await process_frame
	await _fresh_battle(Battle.State.FORMATION)
	var cells: Array = Campaign.chapter_data().deploy
	check_eq(b.turn, 0, "Check Map doesn't start the battle")
	check_eq(b.map.deploy_cells.size(), cells.size(), "deploy cells shown")
	var lord: Unit = b.unit_at(cells[0])
	var second: Unit = b.unit_at(cells[1])
	check(lord != null and lord.is_lord, "the Lord starts on the first deploy cell")
	check(b.unit_at(cells[5]) == null, "5 units, 6 cells: the last is free")
	# Z on the Lord, Z on the second unit: they swap.
	b.cursor.cell = cells[0]
	b.input.formation.accept()
	check(b.input.formation.held == lord, "Lord picked up")
	b.cursor.cell = cells[1]
	b.input.formation.accept()
	check(lord.cell == cells[1] and second.cell == cells[0], "swapped")
	check(b.input.formation.held == null, "put down")
	# Onto an empty deploy cell, and not off the deploy cells.
	b.cursor.cell = cells[1]
	b.input.formation.accept()
	b.cursor.cell = cells[5]
	b.input.formation.accept()
	check_eq(lord.cell, cells[5], "moved to a free deploy cell")
	b.cursor.cell = cells[5]
	b.input.formation.accept()
	b.cursor.cell = Vector2i(10, 2)
	b.input.formation.accept()
	check_eq(lord.cell, cells[5], "not off the deploy cells")
	check(b.input.formation.held == lord, "still held")
	b.input.formation.drop_held()
	check_eq(Campaign.placement.get(lord.unit_name), cells[5], "placement saved")
	# Fight!: the battle starts with that layout.
	b.input.formation.end()
	b.begin()
	while b.state != Battle.State.IDLE:
		await process_frame
	check_eq(b.turn, 1, "battle started")
	check(not Campaign.checking_map and b.map.deploy_cells.is_empty(), "Check Map over")
	check_eq(lord.cell, cells[5], "layout kept")
	# A restart (or a retry) deploys the same layout; stale cells are ignored.
	var lord_name: String = lord.unit_name
	var second_name: String = second.unit_name
	Campaign.placement[second_name] = Vector2i(10, 2)
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check_eq(b.unit_at(cells[5]).unit_name, lord_name, "placement used")
	check_eq(b.unit_at(cells[0]).unit_name, second_name, "a unit placed off the deploy cells takes a free one")
	# The prep screen keeps picks made before Check Map.
	Campaign.deployed = ["Lord", "Archer"]
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	await process_frame
	check_eq(prep.picked, ["Lord", "Archer"], "picks kept")
	prep.queue_free()
	Campaign.clear_deployment()


func test_campaign_suspend_resume() -> void:
	await start_chapter(0)
	b.map.object_at(Vector2i(5, 0)).state = "visited"
	SaveGame.write_suspend(b)
	Campaign.active = false
	Levels.resume = true
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check(Campaign.active, "resuming a chapter reactivates the campaign")
	check_eq(b.map.object_at(Vector2i(5, 0)).state, "visited", "map objects restored")
	check_eq(Levels.selected, "ch1", "on the right chapter")
	SaveGame.delete_suspend()


func test_chapters_enemy_phases_run() -> void:
	# Three full rounds of enemy phases on every chapter (looting, reinforcements,
	# goto/defend AI...), sped up. Runtime errors here fail the run via run_tests.sh.
	for i in Chapters.ORDER.size():
		await start_chapter(i)
		Settings.set_value("game_speed", 2.0)
		for round in 3:
			if b.state == b.State.GAME_OVER:
				break
			b.phases.end_player_phase()
			while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
				Engine.time_scale = 8.0
				await process_frame
		check(b.state == b.State.IDLE or b.state == b.State.GAME_OVER, "%s: enemy phases settle" % Chapters.ORDER[i])
	reset_settings()
	Engine.time_scale = 1.0


func test_marked_enemy_freed() -> void:
	# Regression: killing a marked enemy froze the game. Dead units are freed, and
	# refresh_threat() crashed rebuilding the mark list.
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var sold := unit_named("Soldier", Unit.Team.ENEMY)
	b.marked.assign([brig, sold])
	b.refresh_threat()
	remove_unit(brig)
	b.refresh_threat()
	check_eq(b.marked.size(), 1, "the freed enemy's mark is dropped")
	check(b.marked[0] == sold, "the other mark stays")
	check_eq(b.map.marked_cells, b.enemy_threat(sold), "overlay shows only the survivor's threat")


func test_quit_to_level_select_asks_first() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Level Select")
	check_eq(b.input.menu_context, "quit", "Level Select asks for confirmation")
	check_eq(b.ui.menu_choice(), "Cancel", "Cancel is selected first")
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Cancel returns to the map")
	check(is_instance_valid(b) and b.is_inside_tree(), "still in the battle")


func test_end_turn_last_and_warning_option() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	check_eq(b.ui.menu_options[-1], "End Turn", "End Turn is the last map menu entry")
	await press(KEY_UP)
	check_eq(b.ui.menu_choice(), "End Turn", "so Up from the top reaches it")
	await press(KEY_X)
	Settings.set_value("end_turn_warning", false)
	await press(KEY_Z)
	await pick("End Turn")
	check(b.enemy_phase or b.turn == 2, "warning off: End Turn ends it right away, units still waiting")
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	reset_settings()


func test_prep_screen_repair() -> void:
	await start_chapter(0)
	var lord_data := Campaign.army_unit("Lord")
	lord_data.items[0].uses = 0
	Campaign.convoy.append(Weapons.make("Iron Axe"))
	Campaign.convoy[-1].uses = 5
	Campaign.save()  # the prep screen loads the campaign from its save
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	await process_frame
	lord_data = Campaign.army_unit("Lord")
	check(prep.MENU.has("Repair"), "prep has Repair")
	prep._enter("repair")
	check_eq(prep._row_count(), 2, "a broken weapon and a worn one in the convoy")
	prep._repair()
	check_eq(lord_data.items[0].uses, Weapons.max_uses(lord_data.items[0]), "the Lord's weapon repaired")
	prep.index = 0
	prep._repair()
	check_eq(Campaign.convoy[-1].uses, Weapons.max_uses(Campaign.convoy[-1]), "and the convoy's")
	check_eq(prep._row_count(), 0, "nothing left to repair")
	prep.queue_free()
