extends "res://tests/test_base.gd"
## Status effects: inflicting, immunity, ticks, cures, events, saving.


func test_status_data() -> void:
	check_eq(Statuses.validate(), [] as Array[String], "status data problems")
	check_eq(Skills.validate(), [] as Array[String], "skill data problems (immunities name real statuses)")


func test_inflict_and_immunity() -> void:
	var lord := unit_named("Lord")
	check(b.actions.inflict(lord, "Poison"), "Poison takes")
	check_eq(lord.statuses, {"Poison": 3}, "for its default 3 turns")
	Statuses.inflict(lord, "Poison", 1)
	check_eq(lord.statuses.Poison, 3, "again: keeps the longer duration")
	Statuses.inflict(lord, "Poison", 5)
	check_eq(lord.statuses.Poison, 5, "or takes the new one if longer")
	check(Skills.of(lord).has("Poison"), "its effects work like a skill's")
	check(Skills.visible_sources(lord).all(func(pair): return pair[0] != "Poison"), "but it isn't on the Skills page")
	check(BattleUI.unit_notes(lord).has("Status: Poison (5)"), "it's in the info panel")
	b.cursor.cell = lord.cell
	await press(KEY_D)
	var texts: Array = b.ui.status_screen._entries.map(func(e): return e.text)
	check(texts.any(func(t: String): return t.begins_with("Poison (5 turns): ")),
		"and a highlightable square on the Stats page (entries: %s)" % [texts])
	await press(KEY_X)
	var fighter := unit_named("Fighter")
	fighter.personal_skills.assign(["Poison Immunity"])
	check(not b.actions.inflict(fighter, "Poison"), "Poison Immunity blocks it")
	check(fighter.statuses.is_empty(), "nothing inflicted")


func test_poison_ticks() -> void:
	var lord := unit_named("Lord")
	lord.hp = lord.max_hp
	Statuses.inflict(lord, "Poison")
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	var lost := lord.max_hp - lord.hp
	check(lost >= 4 and lost <= 6, "loses 4-6 HP (lost %d)" % lost)
	check_eq(lord.statuses.Poison, 2, "a turn goes by")
	lord.hp = 3
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	check_eq(lord.hp, 1, "never below 1")
	lord.hp = 10
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	check(lord.statuses.is_empty(), "wears off after its turns")
	# Already at 1 HP: it kills, with no EXP for anyone.
	var fighter := unit_named("Fighter")
	fighter.hp = 1
	Statuses.inflict(fighter, "Poison")
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	check(not b.units().has(fighter), "at 1 HP, poison kills")
	check_eq(b.campaign_deaths[-1].get("how", ""), "Succumbed to poison", "remembered as a poison death")


func test_poison_through_phases() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([lord, brig])
	await process_frame
	lord.set_cell(Vector2i(0, 0))
	brig.set_cell(Vector2i(14, 9))
	Statuses.inflict(lord, "Poison")
	Statuses.inflict(brig, "Poison")
	var lord_hp := lord.hp
	var brig_hp := brig.hp
	b.phases.end_player_phase()
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	check(brig.hp < brig_hp, "the enemy is poisoned at the start of its phase")
	check(lord.hp < lord_hp, "the player unit at the start of the player phase")
	check_eq(lord.statuses.Poison, 2, "each side counts down on its own phase")


func test_cures() -> void:
	var lord := unit_named("Lord")
	lord.items.append(Items.make("Antitoxin"))
	check(not Items.can_use(lord, lord.items[-1]), "Antitoxin: only when poisoned")
	Statuses.inflict(lord, "Poison")
	check(Items.can_use(lord, lord.items[-1]), "usable when poisoned")
	await open_menu_in_place(lord)
	await pick("Items")
	await pick("Antitoxin  3")
	check(lord.statuses.is_empty(), "Antitoxin cures Poison")
	check(lord.has_acted, "using it ends the turn")
	# Restore: an ally-target spell that cures every status and heals nothing.
	var cleric := unit_named("Cleric")
	cleric.spells.append("Restore")
	cleric.mp = 20
	var fighter := unit_named("Fighter")
	fighter.set_cell(cleric.cell + Vector2i(1, 0))
	fighter.hp = fighter.max_hp - 5
	check(not Spells.targets_for(cleric, "Restore", b.units()).has(fighter), "Restore: not for a unit with no status")
	Statuses.inflict(fighter, "Poison")
	check(Spells.targets_for(cleric, "Restore", b.units()).has(fighter), "but for a poisoned one")
	await b.actions.cast_heal(cleric, fighter, "Restore")
	check(fighter.statuses.is_empty(), "cured")
	check_eq(fighter.hp, fighter.max_hp - 5, "and not healed")


func test_status_event_commands() -> void:
	var r: Dictionary = EventScript.parse("== start ==\n@status Lord, Poison, 5\n@status Fighter, Poison\n@cure Fighter\n"
		+ "@status Lord, Sneezing\n@cure Lord, Sneezing")
	check_eq(r.errors.size(), 2, "unknown statuses are reported: %s" % [r.errors])
	check_eq(r.events[0].script, [["status", "Lord", "Poison", 5], ["status", "Fighter", "Poison", 0],
		["cure", "Fighter", ""]], "parsed")
	await b.events.run(r.events[0].script)
	check_eq(unit_named("Lord").statuses, {"Poison": 5}, "@status")
	check(unit_named("Fighter").statuses.is_empty(), "@cure")


func test_statuses_saved_and_cleared() -> void:
	var lord := unit_named("Lord")
	Statuses.inflict(lord, "Poison", 2)
	var copy := SaveGame.unit_from_dict(SaveGame.unit_to_dict(lord))
	check_eq(copy.statuses, {"Poison": 2}, "saved with the unit (suspend, rewind, campaign)")
	copy.free()
	Statuses.clear_for_next_map(lord)
	check(lord.statuses.is_empty(), "cleared between chapters (Poison doesn't linger)")
