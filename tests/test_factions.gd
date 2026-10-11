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
	var r: Dictionary = EventScript.parse("== turn 2, ally ==\nAlly: Hi.\n== turn 2, purple ==\n")
	check_eq(r.events[0].args, [2, "ally"], "turn events can name any side's phase")
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
