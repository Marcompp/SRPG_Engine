extends "res://tests/test_base.gd"
## Map events: dialogue and cutscenes.


# --- Events: dialogue and cutscenes -------------------------------------------


func test_event_script_parsing() -> void:
	var r: Dictionary = EventScript.parse("""
# a comment
== start ==
Lord: Hello there.
@narrate Dawn.
@move Bandit King (10, 4)
@give Lord, Silver Sword
@camera (3, 4)
@wait 0.5
== turn 3, enemy | repeat | if seen | unless gone ==
Messenger: Hurry!
== talk Lord, Thief ==
@recruit Thief
== battle Lord, Bandit King ==
== death Rider ==
""")
	check_eq(r.errors, [], "no errors")
	check_eq(r.events.size(), 5, "five events")
	var start: Dictionary = r.events[0]
	check_eq(start.script, [["say", "Lord", "Hello there."], ["narrate", "Dawn."],
		["move", "Bandit King", Vector2i(10, 4)], ["give", "Lord", "Silver Sword"], ["camera", Vector2i(3, 4)],
		["wait", 0.5]], "commands parsed")
	var turn: Dictionary = r.events[1]
	check_eq(turn.args, [3, "enemy"], "turn and phase")
	check(turn.repeat and turn["if"] == ["seen"] and turn.unless == ["gone"], "options")
	check_eq(r.events[3].args, ["Lord", "Bandit King"], "names with spaces")
	# Mistakes are reported with line numbers.
	r = EventScript.parse("Lord: no header\n== dance ==\n== start ==\n@fly away\nno colon here\n@move Thief")
	check_eq(r.errors.size(), 5, "every mistake reported: %s" % [r.errors])
	check(r.errors[0].begins_with("line 1:"), "with its line number")
	# Every event file in the project parses cleanly.
	for file in DirAccess.get_files_at(BattleEvents.EVENTS_DIR):
		if file.ends_with(".txt"):
			var result: Dictionary = EventScript.parse(FileAccess.get_file_as_string(BattleEvents.EVENTS_DIR + file))
			check_eq(result.errors, [], "events/%s parses" % file)


func test_events_run_on_triggers() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var errors: Array = b.events.load_text("""
== talk Lord, Brigand ==
Lord: Put the axe down.
Brigand: ...Alright.
@recruit Brigand
@flag talked
== battle Brigand ==
Brigand: You'll regret this!
@flag quote
== death Thief ==
Thief: Ugh...
@flag thief_fell
== turn 2 | if talked ==
@flag turn_two
== turn 2 | unless talked ==
@flag never
""")
	check_eq(errors, [], "test events parse")
	# Talk: a menu command next to the Brigand, which recruits it.
	lord.set_cell(Vector2i(11, 2))
	await open_menu_in_place(lord)
	check(b.ui.menu_options.has("Talk"), "Talk next to the Brigand")
	await pick("Talk")
	check(b.ui._spell_label.text.contains("Talk to Brigand"), "forecast")
	await press(KEY_Z)
	check_eq(brig.team, Unit.Team.PLAYER, "recruited")
	check(brig.has_acted, "it can't act this turn")
	check(lord.has_acted, "talking ends the turn")
	check(b.events.flags.has("talked"), "flag set")
	check(b.events.talk_targets(lord).is_empty(), "the talk runs once")
	check(brig.biography[-1].begins_with("Joined the army"), "biography entry")
	# Battle quote, once.
	var other := unit_named("Brigand", Unit.Team.ENEMY)
	await b.events.before_battle(lord, other)
	check(b.events.flags.has("quote"), "the quote runs before a fight with a unit of that name")
	b.events.flags.erase("quote")
	await b.events.before_battle(lord, other)
	check(not b.events.flags.has("quote"), "once")
	# Death quote.
	var thief := unit_named("Thief", Unit.Team.ENEMY)
	thief.hp = 0
	var none: Array = []
	await b.actions._remove_dead_and_award([thief] as Array[Unit], none)
	check(b.events.flags.has("thief_fell"), "death quote ran")
	# Turn events with conditions.
	await b.events.on_turn(2, "player")
	check(b.events.flags.has("turn_two") and not b.events.flags.has("never"), "if/unless")
	# Fired events and flags are saved.
	var saved: Dictionary = SaveGame.capture(b)
	check_eq(saved.event_flags, b.events.flags, "flags saved")
	check_eq(saved.events_fired.size(), b.events.fired.size(), "fired events saved")
	# Speakers: a unit keeps its side, the next one takes the other.
	check_eq(b.ui.dialogue.slots[0].get("name", ""), "", "the box is cleared after a scene")


func test_great_valley_events() -> void:
	await start_level("great_valley")
	check(b.events.events.size() >= 5, "events/great_valley.txt loaded")
	check(b.events.fired.has(0), "the opening scene ran")
	check_eq(b.state, b.State.IDLE, "and the player phase started after it")
	var ember := unit_named("Ember")
	var wyrm := unit_named("Wyrm", Unit.Team.ENEMY)
	ember.set_cell(wyrm.cell + Vector2i(0, 1))
	check_eq(b.events.talk_targets(ember), [wyrm] as Array[Unit], "Ember can talk to the Wyrm")
	b.input.selected = ember
	await b.events.run_talk(ember, wyrm)
	check_eq(wyrm.team, Unit.Team.PLAYER, "the Wyrm joins")
	check(b.events.flags.has("wyrm_joined"), "flag for the General's other quote")


func test_area_visit_and_end_events() -> void:
	var r: Dictionary = EventScript.parse("== area (1, 1)-(2, 2), (5, 5), Lord ==
== visit (3, 3) ==
== victory ==
== defeat ==")
	check_eq(r.errors, [], "headers parse")
	check_eq(r.events[0].args[0], [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(5, 5)],
		"rectangles and single cells")
	check_eq(r.events[0].args[1], "Lord", "who")
	check_eq(EventScript.parse("== visit ==").errors.size(), 1, "visit needs a cell")
	var errors: Array = b.events.load_text("""
== area (3, 2)-(4, 2), player ==
@flag reached
== area (10, 5), enemy ==
@flag enemy_reached
== victory ==
@flag won
""")
	check_eq(errors, [], "test events parse")
	# A player unit ending its move in the area: the scene plays and commits the move.
	var lord := unit_named("Lord")
	lord.set_cell(Vector2i(2, 2))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_RIGHT)
	await press(KEY_Z)
	check(b.events.flags.has("reached"), "area event on the move")
	check(b.input.move_committed, "the move can't be undone after the scene")
	await press(KEY_X)
	check_eq(lord.cell, Vector2i(3, 2), "X doesn't take the move back")
	await pick("Wait")
	# Enemies trigger area events at the end of their turn.
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	brig.set_cell(Vector2i(10, 5))
	check(await b.events.on_area(brig), "an enemy in the area")
	check(b.events.flags.has("enemy_reached"), "enemy area event")
	# Victory: the scene plays before the end screen.
	for e in b.units_of(Unit.Team.ENEMY):
		e.hp = 0
	b.phases.check_game_over()
	while b.state != b.State.GAME_OVER or not b.events.flags.has("won"):
		await process_frame
	check(b.events.flags.has("won"), "victory scene ran")
	check_eq(b.battle_result, "victory", "and the map is won")
