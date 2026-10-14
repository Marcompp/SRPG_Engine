extends "res://tests/test_base.gd"
## Factions: green allies, purple third army, yellow neutrals, relations, phases.


## A Brigand on `side` at `cell` (named after the side unless `unit_name` is given).
func _spawn(side: Unit.Team, cell: Vector2i, unit_name := "") -> Unit:
	var u := Unit.create(unit_name if unit_name else Factions.NAMES[side], side, cell, {"class": "Brigand",
		"items": ["Iron Axe"], "hp": 30, "str": 6, "dex": 4, "agi": 3, "lck": 0, "def": 3, "mov": 5})
	b.units_root.add_child(u)
	return u


func test_default_relations() -> void:
	var P := Unit.Team.PLAYER
	check(Factions.hostile(P, Unit.Team.ENEMY) and Factions.hostile(Unit.Team.ENEMY, P), "player and enemy fight")
	check(Factions.friendly(P, Unit.Team.ALLY), "green is friendly")
	check(Factions.hostile(Unit.Team.OTHER, Unit.Team.ENEMY) and Factions.hostile(Unit.Team.ENEMY, Unit.Team.OTHER),
		"purple and red fight each other")
	check(Factions.hostile(P, Unit.Team.NEUTRAL) and not Factions.hostile(Unit.Team.NEUTRAL, P),
		"you can attack neutrals, they don't attack you")
	Factions.reset({"relations": {"other": ["enemy"]}})
	check(not Factions.hostile(Unit.Team.OTHER, P) and Factions.hostile(Unit.Team.OTHER, Unit.Team.ENEMY),
		"a level can override a side's foes")
	Factions.reset()


func test_targets_and_movement() -> void:
	var lord := unit_named("Lord")
	clear_board([lord])
	lord.set_cell(Vector2i(4, 2))
	var ally := _spawn(Unit.Team.ALLY, Vector2i(5, 2))
	var other := _spawn(Unit.Team.OTHER, Vector2i(4, 3))
	var neutral := _spawn(Unit.Team.NEUTRAL, Vector2i(3, 2))
	var foes: Array[Unit] = b.actions.enemies_in_range(lord, lord.weapon)
	check(foes.has(other) and foes.has(neutral) and not foes.has(ally), "you can attack purple and yellow, not green")
	var reach: Dictionary = b.map.get_reachable(lord, b.units())
	check(reach.parents.has(Vector2i(6, 2)) and reach.parents[Vector2i(6, 2)] == ally.cell,
		"you move through green units")
	check(not reach.parents.values().has(neutral.cell), "but not through neutrals")
	check(not reach.cells.has(ally.cell), "and can't stop on them")


func test_ai_phases() -> void:
	var lord := unit_named("Lord")
	isolate([lord])
	await process_frame
	lord.set_cell(Vector2i(0, 0))
	var ally := _spawn(Unit.Team.ALLY, Vector2i(10, 6))
	var red := _spawn(Unit.Team.ENEMY, Vector2i(11, 6))
	var purple := _spawn(Unit.Team.OTHER, Vector2i(11, 7))
	var neutral := _spawn(Unit.Team.NEUTRAL, Vector2i(13, 9))
	var neutral_cell := neutral.cell
	b.phases.end_player_phase()
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	check(red.was_attacked, "green attacks red on its phase")
	check(ally.was_attacked, "red or purple attack green")
	check_eq(neutral.cell, neutral_cell, "neutrals stay out of it")
	check_eq(b.state, b.State.IDLE, "back to the player phase")


func test_rout_and_danger_zone() -> void:
	var lord := unit_named("Lord")
	isolate([lord])
	await process_frame
	var purple := _spawn(Unit.Team.OTHER, Vector2i(10, 6))
	_spawn(Unit.Team.ALLY, Vector2i(12, 6))
	_spawn(Unit.Team.NEUTRAL, Vector2i(13, 9))
	b.danger_on = true
	b.refresh_threat()
	check(not b.map.danger_cells.is_empty(), "purple is in the danger zone")
	check_eq(Objectives.result(b), "", "no rout while purple stands")
	remove_unit(purple)
	b.refresh_threat()
	check_eq(Objectives.result(b), "victory", "green and neutral units don't count for a rout")


func test_relations_saved() -> void:
	Factions.set_hostile(Unit.Team.OTHER, Unit.Team.PLAYER, false)
	var data := SaveGame.capture(b)
	Factions.reset()
	SaveGame.restore(b, data)
	check(not Factions.hostile(Unit.Team.OTHER, Unit.Team.PLAYER), "relations come back with a save")
	Factions.reset()
	check(Factions.hostile(Unit.Team.OTHER, Unit.Team.PLAYER), "(reset)")
	var r: Dictionary = EventScript.parse("== turn 2, green ==\nAlly: Hi.\n== turn 2, sideways ==\n")
	check_eq(r.events[0].args, [2, "ally"], "turn events can name any side's phase, by color too")
	check_eq(r.errors.size(), 1, "unknown phases are reported")


func test_purple_fights_red() -> void:
	var lord := unit_named("Lord")
	isolate([lord])
	await process_frame
	lord.set_cell(Vector2i(0, 0))
	var red := _spawn(Unit.Team.ENEMY, Vector2i(11, 6))
	var purple := _spawn(Unit.Team.OTHER, Vector2i(11, 7))
	for u in [red, purple]:
		u.base_max_hp = 80
		u.hp = 80
	b.phases.end_player_phase()
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	check(red.was_attacked and purple.was_attacked, "red and purple attack each other on their phases")
	check_eq(lord.hp, lord.max_hp, "the Lord, out of reach, is left alone")


func test_supporting_green_allies() -> void:
	var cleric := unit_named("Cleric")
	var fighter := unit_named("Fighter")
	clear_board([cleric, fighter])
	cleric.set_cell(Vector2i(4, 2))
	cleric.mp = 20
	var ally := _spawn(Unit.Team.ALLY, Vector2i(5, 2))
	ally.hp = 5
	check(Spells.targets_for(cleric, "Heal", b.units()).has(ally), "you can heal green allies")
	await b.actions.cast_heal(cleric, ally, "Heal")
	check(ally.hp > 5, "healed")
	fighter.set_cell(Vector2i(4, 3))
	check(not b.actions.trade_partners(cleric).has(ally), "but not trade with them")
	ride(fighter, "Horse")
	ally.set_cell(Vector2i(5, 3))
	check(b.actions.rescue_targets(fighter).has(ally), "and you can rescue them")
	check(not b.actions.shove_targets(fighter).has(ally), "not shove them")
	var neutral := _spawn(Unit.Team.NEUTRAL, Vector2i(3, 3))
	neutral.hp = 5
	check(not Spells.targets_for(cleric, "Heal", b.units()).has(neutral), "neutrals aren't your allies")


func test_provoking_neutrals() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	var villager := _spawn(Unit.Team.NEUTRAL, Vector2i(5, 7))
	villager.max_hp = 60  # so no crit can fell it mid-test
	villager.hp = 60
	brig.set_cell(Vector2i(6, 7))
	await b.actions.do_combat(brig, villager)
	check(not Factions.hostile(Unit.Team.NEUTRAL, Unit.Team.PLAYER), "red attacking neutrals doesn't provoke them")
	await b.actions.do_combat(lord, villager)
	check(Factions.hostile(Unit.Team.NEUTRAL, Unit.Team.PLAYER), "your attack does: neutrals turn on you")
	check(b.threats_to(Unit.Team.PLAYER).has(villager), "they're a threat now")
	check(not Factions.hostile(Unit.Team.NEUTRAL, Unit.Team.ENEMY), "only to you")


func test_green_allies_gain_exp() -> void:
	var lord := unit_named("Lord")
	isolate([lord])
	await process_frame
	var ally := _spawn(Unit.Team.ALLY, Vector2i(5, 6))
	var red := _spawn(Unit.Team.ENEMY, Vector2i(6, 6))
	ally.dexterity = 60
	red.agility = 0
	red.luck = 0
	red.hp = 1
	var before := ally.exp_points + ally.level * Experience.EXP_PER_LEVEL
	await b.actions.do_combat(ally, red)
	check(ally.exp_points + ally.level * Experience.EXP_PER_LEVEL > before, "green allies earn EXP for kills")
	check_eq(b.state, b.State.IDLE, "with no level-up window to wait on")
	check(Objectives.defeat_text({"type": "rout", "protect": ["Elder"]}).contains("or Elder falls"),
		"a protect list is part of the defeat conditions")


func test_faction_event_commands() -> void:
	var r: Dictionary = EventScript.parse("== start ==\n@hostile other, player\n@peace purple, red\n@side Lord, green\n"
		+ "@hostile purple\n@side Lord, sideways")
	check_eq(r.errors.size(), 2, "bad commands are reported: %s" % [r.errors])
	check_eq(r.events[0].script, [["hostile", Unit.Team.OTHER, Unit.Team.PLAYER], ["peace", Unit.Team.OTHER, Unit.Team.ENEMY],
		["side", "Lord", Unit.Team.ALLY]], "sides by name or color")
	var archer := unit_named("Archer")
	await b.events.run([["peace", Unit.Team.PLAYER, Unit.Team.ENEMY], ["side", "Archer", Unit.Team.OTHER]])
	check(not Factions.hostile(Unit.Team.PLAYER, Unit.Team.ENEMY) and not Factions.hostile(Unit.Team.ENEMY, Unit.Team.PLAYER),
		"@peace works both ways")
	check_eq(archer.team, Unit.Team.OTHER, "@side moves a unit to a side")
	Factions.reset()


func test_three_armies_map() -> void:
	await start_level("three_armies")
	var lord := unit_named("Lord")
	var varga := unit_named("Varga", Unit.Team.OTHER)
	check(Factions.hostile(Unit.Team.OTHER, Unit.Team.ENEMY) and not Factions.hostile(Unit.Team.OTHER, Unit.Team.PLAYER),
		"the mercenaries start out hunting only the raiders")
	check(Objectives.defeat_text(Objectives.of(Levels.get_level("three_armies"))).contains("Elder falls"), "protect the Elder")
	# The betrayal on turn 3's enemy phase.
	await b.events.on_turn(3, "enemy")
	check(Factions.hostile(Unit.Team.OTHER, Unit.Team.PLAYER) and not Factions.hostile(Unit.Team.OTHER, Unit.Team.ENEMY),
		"turn 3: the mercenaries turn on you")
	# Talking to Varga brings them over.
	lord.set_cell(varga.cell + Vector2i(0, 1))
	check(b.events.talk_targets(lord).has(varga), "the Lord can talk to Varga")
	b.input.selected = lord
	await b.events.run_talk(lord, varga)
	check_eq(varga.team, Unit.Team.ALLY, "Varga joins as an ally")
	check_eq(unit_named("Kett", Unit.Team.ALLY).team, Unit.Team.ALLY, "with the whole band")
	# Losing the Elder loses the map.
	Levels.selected = "three_armies"  # (start_level points it back at the default map)
	check_eq(Objectives.result(b), "", "(still going)")
	var elder := unit_named("Elder", Unit.Team.NEUTRAL)
	elder.hp = 0
	var dead: Array[Unit] = [elder]
	await b.actions.remove_dead(dead)
	check_eq(Objectives.result(b), "defeat", "the Elder falls: defeat")
	Levels.selected = "river_crossing"


func test_three_armies_phases_run() -> void:
	await start_level("three_armies")
	await run_enemy_phases()


# --- The Royal Guard (objective "caught_by", AI preset "pursuer") ------------

func test_royal_guard_catches_the_lord() -> void:
	Levels.selected = "royal_pursuit"
	b.queue_free()
	await process_frame
	await _fresh_battle()
	var obj := Objectives.of(Levels.get_level(Levels.selected))
	check(Objectives.defeat_text(obj).contains("Neutral"), "the defeat text names the side")
	await b.events.on_turn(3, "player")
	var pell := unit_named("Pell", Unit.Team.NEUTRAL)
	var rosalind := unit_named("Rosalind")
	check(pell != null and unit_named("Captain Thorne", Unit.Team.NEUTRAL) != null, "the Guard arrives on turn 3")
	# The danger zone shows where they could catch her.
	await press(KEY_C)
	check(not b.catch_zone().is_empty(), "a catch zone")
	check(b.catch_zone().keys().all(func(c: Vector2i) -> bool: return b.map.danger_cells.has(c)),
		"inside the danger zone")
	# A pursuer heads for the Lord even though its side has no foes, and never attacks.
	pell.set_cell(Vector2i(6, 4))
	var hp := rosalind.hp
	check_eq(Objectives.result(b), "", "four tiles away isn't caught")
	await EnemyAI.take_turn(pell, b)
	check_eq(BattleMap.distance(pell.cell, rosalind.cell), 1, "Pell walks up to her (%s)" % pell.cell)
	check_eq(rosalind.hp, hp, "without attacking")
	check_eq(Objectives.result(b), "defeat", "and catches her")
	pell.set_cell(rosalind.cell + Vector2i(2, 0))
	check_eq(Objectives.result(b), "", "two tiles away isn't caught")
	# Nor is she while an ally carries her.
	var bex := unit_named("Bex")
	bex.set_class("Cavalry")
	bex.set_cell(rosalind.cell + Vector2i.DOWN)
	await b.actions.do_rescue(bex, rosalind)
	pell.set_cell(bex.cell + Vector2i.LEFT)
	check_eq(Objectives.result(b), "", "a carried Lord can't be caught")
	Levels.selected = "river_crossing"


func test_blocking_the_guard() -> void:
	Levels.selected = "royal_pursuit"
	b.queue_free()
	await process_frame
	await _fresh_battle()
	await b.events.on_turn(3, "player")
	var thorne := unit_named("Captain Thorne", Unit.Team.NEUTRAL)
	var doran := unit_named("Doran")
	var rosalind := unit_named("Rosalind")
	# Rosalind across the river, Doran on the bridge: the only way over is blocked.
	rosalind.set_cell(Vector2i(10, 2))
	doran.set_cell(Vector2i(7, 2))
	thorne.set_cell(Vector2i(5, 2))
	unit_named("Ives", Unit.Team.NEUTRAL).set_cell(Vector2i(0, 9))
	unit_named("Pell", Unit.Team.NEUTRAL).set_cell(Vector2i(0, 0))
	for e in b.units_of(Unit.Team.ENEMY):
		remove_unit(e)
	await EnemyAI.take_turn(thorne, b)
	check(thorne.cell.x < 7, "the Guard can't pass a unit on the bridge (%s)" % thorne.cell)
	check_eq(doran.hp, doran.max_hp, "and doesn't fight it")
	Levels.selected = "river_crossing"


func test_royal_pursuit_phases_run() -> void:
	await start_level("royal_pursuit")
	Levels.selected = "royal_pursuit"  # (start_level points it back at the default map)
	await run_enemy_phases()
	check(not b.units_of(Unit.Team.NEUTRAL).is_empty(), "the Guard arrived")
	Levels.selected = "river_crossing"


# --- Sleeping watchmen (demo chapter 1: Over the Wall) -------------------------

func _start_over_the_wall() -> void:
	Campaign.select("princess")
	await start_chapter(0)
	Levels.selected = Chapters.ORDER[0]  # (start_chapter's battle loads it; keep it for Objectives)


func test_sleeping_watchmen() -> void:
	await _start_over_the_wall()
	var rosalind := unit_named("Rosalind")
	var hobb := unit_named("Watchman Hobb", Unit.Team.NEUTRAL)
	check(rosalind != null and rosalind.cell == Vector2i(2, 2), "Rosalind starts in her tower")
	check(EnemyAI.is_asleep(hobb), "the watch dozes")
	await press(KEY_C)
	check(b.catch_zone().has(Vector2i(11, 3)) and not b.catch_zone().has(Vector2i(12, 3)),
		"the danger zone shows a sleeper's wake radius, not its reach")
	rosalind.set_cell(hobb.cell + Vector2i.LEFT)
	check_eq(Objectives.result(b), "", "a sleeping watchman catches nobody")
	# Lingering near one wakes it (neutrals notice the player's units), with its group.
	var woke: Array = b.events.load_text("== wake Watchman Hobb ==\n@flag hobb_woke\n")
	check_eq(woke, [], "a wake event parses")
	rosalind.set_cell(Vector2i(7, 3))
	await b.phases.ai_phase(Unit.Team.NEUTRAL)
	check(not EnemyAI.is_asleep(hobb), "Hobb wakes")
	check(not EnemyAI.is_asleep(unit_named("Watchman Tull", Unit.Team.NEUTRAL)), "and wakes Tull too (same group)")
	check(EnemyAI.is_asleep(unit_named("Watchman Ede", Unit.Team.NEUTRAL)), "but not the gate watch")
	check(b.events.flags.has("hobb_woke"), "the wake event ran")
	check_eq(b.battle_result, "defeat", "then he walks up to her: caught")
	Levels.selected = "river_crossing"


func test_talking_to_doran_recruits_the_company() -> void:
	await _start_over_the_wall()
	var rosalind := unit_named("Rosalind")
	var doran := unit_named("Doran", Unit.Team.ALLY)
	check(doran != null, "the company starts green")
	rosalind.set_cell(Vector2i(12, 6))
	b.input.selected = rosalind
	check(b.events.talk_targets(rosalind).has(doran), "Rosalind can talk to Doran")
	await b.events.run_talk(rosalind, doran)
	for n in ["Doran", "Bex", "Fennick", "Mags"]:
		check(unit_named(n) != null, "%s joins" % n)
	Levels.selected = "river_crossing"


func test_over_the_wall_phases_run() -> void:
	await _start_over_the_wall()
	check_eq(Campaign.gold, 0, "the company is broke")
	await run_enemy_phases()
	Levels.selected = "river_crossing"


func test_honest_work_guard_arrives() -> void:
	Campaign.select("princess")
	await start_chapter(1)
	Levels.selected = Chapters.ORDER[1]
	check(unit_named("Juniper") != null, "Juniper joins for chapter 2")
	check(unit_named("Farmer Hal", Unit.Team.ALLY) != null, "the farmer is green, so he can't catch anyone")
	await run_enemy_phases()
	await b.events.on_turn(8, "player")
	check_eq(b.units_of(Unit.Team.NEUTRAL).size(), 3, "the Guard rides in on turn 8")
	check(b.events.flags.has("guard_here"), "and the ending knows")
	Levels.selected = "river_crossing"
