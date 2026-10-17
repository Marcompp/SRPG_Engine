extends "res://tests/test_base.gd"
## Music and sound effects (Sound, data/sounds.cfg). Tests can't hear, so these check
## what the game asks for: the names, the tracks and the volumes.


func test_sound_names_exist() -> void:
	# Every name the scripts play is in data/sounds.cfg.
	var re := RegEx.create_from_string("Sound\\.(play|music)\\(\"([a-z_]+)\"")
	for file in DirAccess.get_files_at("res://scripts/"):
		if not file.ends_with(".gd"):
			continue
		for m in re.search_all(FileAccess.get_file_as_string("res://scripts/" + file)):
			var table: Dictionary = Sound.EFFECTS if m.get_string(1) == "play" else Sound.MUSIC
			check(table.has(m.get_string(2)), "%s: \"%s\" is in data/sounds.cfg" % [file, m.get_string(2)])
	# ...and so are the tracks the game makes up from names.
	for side in Factions.KEYS:
		check(Sound.MUSIC.has(Factions.key(side) + "_phase"), "a track for the %s phase" % Factions.key(side))
	for track in ["victory", "defeat"]:
		check(Sound.MUSIC.has(track), "a %s track" % track)


func test_phase_music() -> void:
	check_eq(Sound.track, "player_phase", "the player phase has its track")
	Sound.played.clear()
	await b.phases.end_player_phase()
	while b.state != Battle.State.IDLE:
		await process_frame
	check(Sound.played.count("phase") >= 2, "each phase start sounds: %s" % [Sound.played])
	check_eq(Sound.track, "player_phase", "back to the player phase's track")
	check_eq(b.phases.phase_track(Unit.Team.ENEMY), "enemy_phase", "no \"music\" on the map: the default tracks")


func test_event_music_and_sound() -> void:
	var r: Dictionary = EventScript.parse("== start ==\n@music victory\n@sound item\n@music stop\n")
	check_eq(r.errors, [], "no errors")
	check_eq(r.events[0].script, [["music", "victory"], ["sound", "item"], ["music", ""]], "commands parsed")
	r = EventScript.parse("== start ==\n@music no_such_track\n@sound\n@sound boom\n")
	check_eq(r.errors.size(), 3, "unknown tracks and effects are reported: %s" % [r.errors])
	Sound.played.clear()
	await b.events.run([["music", "victory"], ["sound", "item"]])
	check_eq(Sound.track, "victory", "@music switches tracks")
	check(Sound.played.has("item"), "@sound plays")
	await b.events.run([["music", ""]])
	check_eq(Sound.track, "", "@music stop")


func test_combat_sounds() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([lord, brig])
	lord.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(6, 2))
	Sound.played.clear()
	await b.actions.do_combat(lord, brig)
	check(Sound.played.any(func(e): return e in ["hit", "crit", "miss"]), "strikes sound: %s" % [Sound.played])


func test_volume_options() -> void:
	check_eq(Settings.value("music_volume"), 1.0, "music at full by default")
	check_eq(Settings.value("effects_volume"), 1.0, "effects at full by default")
	var music := AudioServer.get_bus_index("Music")
	check(music != -1 and AudioServer.get_bus_index("Effects") != -1, "the buses exist")
	Settings.set_value("music_volume", 0.0)
	Sound.apply_volumes()
	check(AudioServer.is_bus_mute(music), "Off mutes the music")
	Settings.set_value("music_volume", 0.5)
	Sound.apply_volumes()
	check(not AudioServer.is_bus_mute(music) and absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.5)) < 0.01,
		"50% sets the bus volume")
	Settings.reload()
	Sound.apply_volumes()


func test_confirm_sounds() -> void:
	# Confirm picks on the map ("select"), chooses in menus ("confirm"), and sounds
	# "invalid" where it does nothing.
	var lord := unit_named("Lord")
	clear_board([lord])
	lord.set_cell(Vector2i(2, 2))
	b.cursor.cell = lord.cell
	Sound.played.clear()
	await press(KEY_Z)
	check_eq(b.state, Battle.State.SELECTED, "the Lord is selected")
	check_eq(Sound.played, ["select"] as Array[String], "picking a unit")
	# An empty tile out of the Lord's reach.
	var far := Vector2i(-1, -1)
	for y in b.map.rows:
		for x in b.map.cols:
			var c := Vector2i(x, y)
			if not b.input.reach.cells.has(c) and b.unit_at(c) == null:
				far = c
	b.cursor.cell = far
	Sound.played.clear()
	await press(KEY_Z)
	check_eq(b.state, Battle.State.SELECTED, "nothing happens out of reach")
	check_eq(Sound.played, ["invalid"] as Array[String], "out of reach")
	await press(KEY_X)
	b.cursor.cell = far
	await press(KEY_Z)
	check_eq(b.state, Battle.State.MENU, "an empty tile opens the map menu")
	Sound.played.clear()
	await pick("Objective")
	check(Sound.played.has("confirm"), "a menu choice: %s" % [Sound.played])


func test_effect_variations() -> void:
	# An effect listed as an array plays one of its files; each is in the project.
	var miss: Variant = Sound.EFFECTS["miss"]
	check(miss is Array and miss.size() > 1, "miss has variations")
	for entry in miss:
		check(ResourceLoader.exists(Sound.DIR + entry), "%s is there" % entry)
