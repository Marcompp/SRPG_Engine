extends "res://tests/test_base.gd"
## Quality of life, info panel, unit list, objective, suspend/resume/restart, options, auto save, turn rewind.


# --- Quality of life ----------------------------------------------------------


func test_jump_to_next_unit() -> void:
	var waiting: Array = b.units_of(Unit.Team.PLAYER)
	b.cursor.cell = Vector2i(5, 5)  # empty tile
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[0].cell, "from an empty tile: first unit that hasn't acted")
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[1].cell, "then the next one")
	waiting[2].has_acted = true
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[3].cell, "units that already acted are skipped")
	b.cursor.cell = waiting[-1].cell
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[0].cell, "wraps around to the first")


func test_fast_forward_enemy_phase() -> void:
	Input.action_press("cancel")
	await process_frame
	check_eq(Engine.time_scale, 1.0, "holding X on the player phase does nothing")
	b.enemy_phase = true
	await process_frame
	check_eq(Engine.time_scale, Settings.value("fast_forward_speed"), "holding X on the enemy phase speeds up the game")
	check(b.ui._fast_forward.visible, "with an on-screen indicator")
	Input.action_release("cancel")
	await process_frame
	check_eq(Engine.time_scale, 1.0, "back to normal when released")
	check(not b.ui._fast_forward.visible, "indicator hidden")
	b.enemy_phase = false


func test_level_up_waits_for_confirm() -> void:
	var lord := unit_named("Lord")
	b.ui.level_up_waits = true
	lord.exp_points = 95
	var done := [false]
	var run := func():
		await b.actions.gain_exp(lord, 33)
		done[0] = true
	run.call()
	await create_timer(2.6).timeout
	check(b.ui._level_up.visible, "level-up window still up after the old 2 s timeout")
	check(not done[0], "and the game waits")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_Z
	e.keycode = KEY_Z
	e.pressed = true
	b.ui._unhandled_input(e)
	await process_frame
	await process_frame
	check(not b.ui._level_up.visible, "Z closes it")
	check(done[0], "and the game carries on")


func test_end_turn_warning() -> void:
	var waiting: int = b.units_of(Unit.Team.PLAYER).size()
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("End Turn")
	check_eq(b.input.menu_context, "end_turn", "End Turn with units waiting asks first")
	check_eq(b.ui.menu_options, ["Cancel", "End Turn"], "Cancel is listed (and selected) first")
	check(b.ui._menu_label.text.contains("%d units haven't acted" % waiting), "the prompt says how many")
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Z right away cancels")
	check(not b.enemy_phase, "turn not ended")
	await press(KEY_Z)
	await pick("End Turn")
	await pick("End Turn")
	check(b.enemy_phase or b.turn == 2, "confirming ends the turn")
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame


# --- Info panel, unit list, objective -----------------------------------------


func test_info_panel_terrain_bonus() -> void:
	var lord := unit_named("Lord")
	lord.set_cell(Vector2i(4, 0))  # forest: DEF +1, AVO +20
	b.cursor.cell = lord.cell
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Forest  DEF+1 AVO+20"), "foot unit sees the forest bonus")
	lord.move_type = "flying"
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Forest  no bonus (Flying)"), "a flier gets no terrain bonus")
	lord.move_type = "foot"
	b.map.set_terrain(Vector2i(5, 2), "=")
	b.cursor.cell = Vector2i(5, 2)
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Path  DEF+0 AVO-20"), "negative bonuses read AVO-20, not AVO+-20")


func test_unit_list() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Units")
	var list: UnitListScreen = b.ui.unit_list
	check_eq(b.state, b.State.UNIT_LIST, "map menu > Units opens the list")
	check(list.visible, "list shown")
	check_eq(list.units.size(), b.units().size(), "lists every unit on the map")
	# Sort by level (column 2): highest first.
	await press(KEY_RIGHT)
	await press(KEY_RIGHT)
	check_eq(list.COLUMNS[list.sort_col].key, "lv", "Right twice: sort by level")
	var levels: Array = list.units.map(func(u): return u.level)
	var sorted_levels := levels.duplicate()
	sorted_levels.sort()
	sorted_levels.reverse()
	check_eq(levels, sorted_levels, "sorted high to low")
	# D opens the status screen; closing it comes back to the list.
	await press(KEY_DOWN)
	var picked := list.selected_unit()
	await press(KEY_D)
	check(b.state == b.State.STATUS and b.ui.status_screen.unit == picked, "D shows the unit's status")
	await press(KEY_X)
	check_eq(b.state, b.State.UNIT_LIST, "closing the status screen returns to the list")
	# Z jumps the cursor to the unit.
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Z closes the list")
	check_eq(b.cursor.cell, picked.cell, "and puts the cursor on the unit")
	check(not list.visible, "list hidden")


func test_objective_screen() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Objective")
	check_eq(b.state, b.State.OBJECTIVE, "map menu > Objective opens it")
	var text: String = b.ui._objective_label.text
	check(text.contains("River Crossing"), "names the map")
	check(text.contains("Victory: Defeat every enemy."), "victory condition")
	check(text.contains("Defeat: Your Lord falls."), "defeat condition")
	check(text.contains("Turn 1"), "turn number")
	check(text.contains("Enemies %d" % b.units_of(Unit.Team.ENEMY).size()), "enemy count")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X closes it")


# --- Suspend / resume / restart -----------------------------------------------


func test_suspend_round_trip() -> void:
	var lord := unit_named("Lord")
	var fighter := unit_named("Fighter")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	# Change a bit of everything.
	lord.set_cell(Vector2i(5, 2))
	lord.hp = 7
	lord.luck = 13
	lord.items[0].uses = 10
	lord.has_acted = true
	lord.biography.append("Suspended mid-battle.")
	fighter.set_cell(Vector2i(4, 6))
	archer.set_cell(Vector2i(5, 6))
	await b.actions.do_rescue(fighter, archer)
	brig.ai_awake = true
	brig.was_attacked = true
	b.map.set_terrain(Vector2i(3, 4), "M")
	b.turn = 3
	b.danger_on = true
	b.marked.assign([brig])
	var before := SaveGame.capture(b)
	SaveGame.write_suspend(b)
	# Resume into a fresh battle scene.
	Levels.resume = true
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check_eq(var_to_str(SaveGame.capture(b)), var_to_str(before), "resumed battle captures identically")
	lord = unit_named("Lord")
	fighter = unit_named("Fighter")
	check_eq(lord.cell, Vector2i(5, 2), "unit position")
	check_eq(lord.hp, 7, "HP")
	check_eq(lord.items[0].uses, 10, "item uses")
	check(lord.has_acted, "acted units stay acted")
	check_eq(lord.position, Vector2(Vector2i(5, 2) * BattleMap.TILE), "drawn where it stands")
	check(fighter.carrying != null and fighter.carrying.unit_name == "Archer", "carried unit restored")
	check(not b.units().has(fighter.carrying) and not fighter.carrying.visible, "and still off the map")
	check_eq(b.map.terrain_key(Vector2i(3, 4)), "M", "terrain changes restored")
	check_eq(b.turn, 3, "turn")
	check_eq(b.state, b.State.IDLE, "resumes on the player phase, ready for input")
	check(b.marked.size() == 1 and b.marked[0].unit_name == "Brigand", "marked enemies restored")
	SaveGame.delete_suspend()


func test_level_select_offers_resume() -> void:
	SaveGame.write_suspend(b)
	var select: Node = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check(select.choices[0].resume, "a Resume entry comes first")
	check_eq(select.choices[0].label, "Resume: River Crossing, Turn 1", "it names the map and turn")
	check_eq(select.index, 0, "and is preselected")
	select.queue_free()
	SaveGame.delete_suspend()
	select = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check(not select.choices[0].get("resume", false), "no suspend, no Resume entry")
	select.queue_free()


func test_suspend_discarded_when_map_ends() -> void:
	SaveGame.write_suspend(b)
	for e in b.units_of(Unit.Team.ENEMY):
		e.hp = 0
	b.phases.check_game_over()
	check_eq(b.state, b.State.GAME_OVER, "victory")
	check(not SaveGame.has_suspend(), "the finished map's suspend is deleted")


func test_restart_asks_first() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Restart")
	check_eq(b.input.menu_context, "restart", "Restart asks for confirmation")
	check_eq(b.ui.menu_options, ["Cancel", "Restart"], "Cancel first")
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Z right away cancels")


# --- Options ------------------------------------------------------------------


func test_options_screen_saves() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Options")
	check_eq(b.state, b.State.OPTIONS, "map menu > Options opens it")
	check(b.ui.options_screen.visible, "options screen shown")
	await press(KEY_RIGHT)  # Game speed: Normal -> Fast
	check_eq(Settings.value("game_speed"), 1.5, "Right changes the highlighted option")
	await press(KEY_DOWN)
	await press(KEY_DOWN)
	await press(KEY_RIGHT)  # Danger zone at start: Off -> On
	check_eq(Settings.value("danger_zone_default"), true, "Down + Right changes another option")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X closes it")
	await process_frame
	check_eq(Engine.time_scale, 1.5, "game speed applies right away")
	Settings.reload()
	check_eq(Settings.value("game_speed"), 1.5, "saved to disk and read back")
	check_eq(Settings.value("danger_zone_default"), true, "every changed option is saved")
	reset_settings()
	await process_frame
	check_eq(Engine.time_scale, 1.0, "back to normal speed")


func test_option_danger_zone_at_start() -> void:
	Settings.set_value("danger_zone_default", true)
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check(b.danger_on and not b.map.danger_cells.is_empty(), "battle starts with the danger zone on")
	reset_settings()


func test_option_auto_end_turn_off() -> void:
	Settings.set_value("auto_end_turn", false)
	var lord := unit_named("Lord")
	for u in b.units_of(Unit.Team.PLAYER):
		if u != lord:
			u.has_acted = true
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Wait")
	check(not b.enemy_phase and b.state == b.State.IDLE, "everyone acted, but the turn waits for End Turn")
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("End Turn")
	check(b.enemy_phase or b.turn == 2, "End Turn with nobody waiting ends it without asking")
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	reset_settings()


func test_option_level_up_auto() -> void:
	Settings.set_value("level_up_wait", false)
	b.ui.level_up_waits = true  # the window itself would wait...
	var lord := unit_named("Lord")
	lord.exp_points = 95
	await b.actions.gain_exp(lord, 33)  # ...but the option says Auto, so this returns on its own
	check(not b.ui._level_up.visible, "Auto: the level-up window closes by itself")
	reset_settings()


func test_level_select_has_options() -> void:
	var select: Node = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check(select.choices[-1].get("options", false), "Options is the last entry")
	select.queue_free()


func test_auto_save() -> void:
	SaveGame.delete_suspend()
	await b.phases.start_player_phase()
	var data := SaveGame.read_suspend()
	check(not data.is_empty(), "the player phase auto-saves")
	check_eq(data.get("turn", 0), b.turn, "at the current turn")
	SaveGame.delete_suspend()
	Settings.set_value("auto_save", false)
	await b.phases.start_player_phase()
	check(SaveGame.read_suspend().is_empty(), "unless turned off")
	Settings.set_value("auto_save", true)
	# The quit prompt says what's kept.
	b.cursor.cell = Vector2i(7, 9)
	await press(KEY_Z)
	await pick("Level Select")
	check(b.ui._menu_title.contains("resume from the start of this turn"), "quit prompt mentions the auto save")
	SaveGame.delete_suspend()


func test_turn_rewind() -> void:
	check_eq(b.turn_history.size(), 1, "a snapshot at the start of turn 1")
	check_eq(b.rewinds_left, 3, "3 rewinds per map by default")
	var lord := unit_named("Lord")
	var start_cell := lord.cell
	var brigands := func() -> int:
		return b.units_of(Unit.Team.ENEMY).filter(func(e): return e.unit_name == "Brigand").size()
	var brigands_before: int = brigands.call()
	remove_unit(unit_named("Brigand", Unit.Team.ENEMY))
	await b.phases.end_player_phase()
	while b.state != b.State.IDLE:
		await process_frame
	check_eq(b.turn, 2, "turn 2")
	check_eq(b.turn_history.size(), 2, "and its snapshot")
	lord = unit_named("Lord")
	lord.set_cell(Vector2i(5, 2))
	lord.hp = 3
	# Map menu > Rewind > Turn 1.
	b.cursor.cell = Vector2i(7, 9)
	await press(KEY_Z)
	await pick("Rewind")
	check_eq(b.ui.menu_options, ["Turn 2", "Turn 1"] as Array[String], "newest turn first")
	await pick("Turn 1")
	while b.state != b.State.IDLE:
		await process_frame
	lord = unit_named("Lord")
	check_eq(b.turn, 1, "back to turn 1")
	check_eq(lord.cell, start_cell, "units where they were")
	check_eq(lord.hp, lord.max_hp, "with their HP")
	check_eq(brigands.call(), brigands_before, "the fallen are back")
	check_eq(b.turn_history.size(), 1, "later snapshots dropped")
	check_eq(b.rewinds_left, 2, "a use spent")
	check(not lord.has_acted, "the player phase starts over")
	# History and uses survive suspend/resume.
	var saved: Dictionary = SaveGame.capture(b)
	check_eq(saved.history.size(), 1, "history is saved")
	check_eq(saved.rewinds_left, 2, "so are the uses")
	# Out of uses (or Off): no Rewind in the map menu.
	b.rewinds_left = 0
	await press(KEY_X)
	b.cursor.cell = Vector2i(7, 9)
	await press(KEY_Z)
	check(not b.ui.menu_options.has("Rewind"), "no uses left, no Rewind")
	await press(KEY_X)
	SaveGame.delete_suspend()
