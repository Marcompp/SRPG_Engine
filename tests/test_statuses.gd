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
	check_eq(lord.statuses.Poison, 3, "turns go down at the end of the phase...")
	await b.phases.count_down_statuses(Unit.Team.PLAYER)
	check_eq(lord.statuses.Poison, 2, "...not the start")
	lord.hp = 3
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	check_eq(lord.hp, 1, "never below 1")
	await b.phases.count_down_statuses(Unit.Team.PLAYER)
	lord.hp = 10
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	await b.phases.count_down_statuses(Unit.Team.PLAYER)
	check(lord.statuses.is_empty(), "wears off after its 3 phases")
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


func test_paralyse_and_sleep() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	Statuses.inflict(lord, "Paralyse")
	check_eq(b.map.get_reachable(lord, b.units()).cells.keys(), [lord.cell], "Paralyse: can't move")
	await open_menu_in_place(lord)
	check(b.ui.menu_options.has("Attack"), "but can still act")
	await press(KEY_X)
	await press(KEY_X)
	Statuses.cure(lord)
	# Sleep: starts its phase as having acted, can't be selected or counter.
	Statuses.inflict(lord, "Sleep")
	await b.phases.tick_statuses(Unit.Team.PLAYER)
	check(lord.has_acted, "Sleep: it can't act this phase")
	lord.has_acted = false
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	check(b.state != b.State.SELECTED, "and can't be selected")
	b.input.browse()
	check(not Combat.can_counter(brig, lord, b.map), "nor counter")
	lord.take_damage(1)
	check(lord.statuses.is_empty(), "taking damage wakes it")
	# A sleeping enemy threatens nothing.
	Statuses.inflict(brig, "Sleep")
	check(b.enemy_threat(brig).is_empty(), "a sleeping enemy isn't in the danger zone")


func test_paralyse_lasts_the_enemy_phase() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([lord, brig])
	await process_frame
	lord.set_cell(Vector2i(3, 6))
	brig.set_cell(Vector2i(6, 6))
	var start := brig.cell
	Statuses.inflict(brig, "Paralyse")
	b.phases.end_player_phase()
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	check_eq(brig.cell, start, "inflicted in the player phase, it holds through the enemy phase")
	check(brig.statuses.is_empty(), "then wears off")


func test_silence() -> void:
	var mage := unit_named("Mage")
	mage.mp = mage.max_mp
	Statuses.inflict(mage, "Silence")
	check(mage.attack_spells().is_empty(), "Silence: no spells")
	check(b.actions.castable_spells(mage).is_empty(), "nothing to cast")
	check(b.offense_ranges(mage).all(func(r): return mage.weapon_ranges().has(r)), "only weapon ranges count")
	var cleric := unit_named("Cleric")
	Statuses.inflict(cleric, "Silence")
	var lord := unit_named("Lord")
	lord.hp = 1
	lord.set_cell(cleric.cell + Vector2i(1, 0))
	check(not b.actions.castable_spells(cleric).has("Heal"), "no healing either")


func test_petrify() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	var def_before := lord.combat_def()
	Statuses.inflict(lord, "Petrify")
	check_eq(lord.statuses.Petrify, -1, "until cured")
	check_eq(lord.combat_def(), def_before + 10, "DEF +10")
	check_eq(Combat.avoid(lord, brig, b.map, brig), 0, "no Avoid")
	check_eq(Combat.base_avoid(lord), 0, "(on the status screen too)")
	check(not Combat.can_counter(brig, lord, b.map), "no counter")
	check_eq(b.map.get_reachable(lord, b.units()).cells.size(), 1, "no moving")
	await b.phases.count_down_statuses(Unit.Team.PLAYER)
	check(lord.statuses.has("Petrify"), "doesn't wear off")
	Statuses.clear_for_next_map(lord)
	check(lord.statuses.has("Petrify"), "and lingers between chapters")
	lord.take_damage(1)
	check(lord.statuses.has("Petrify"), "and hits don't break it")


## Lord vs a Brigand that can't dodge (so every hit lands) and won't die quickly.
func _sure_hit_duel() -> Array[Unit]:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.dexterity = 60
	brig.agility = 0
	brig.luck = 0
	brig.base_max_hp = 80
	brig.hp = brig.max_hp
	return pair


func test_status_weapon() -> void:
	var pair := await _sure_hit_duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	give_weapon(lord, "Venom Edge")
	var f := Combat.forecast(lord, brig, b.map)
	check_eq(f.atk.inflict, {"status": "Poison", "chance": 100}, "the forecast knows the weapon poisons")
	b.ui.show_forecast(lord, brig, f, lord.cell)
	check(b.ui._forecast_cells[7][1].visible, "a Status row appears")
	check_eq(b.ui._forecast_cells[7][1].text, "Poison 100", "with the status and its odds")
	check_eq(BattleUI.inflict_text(f.atk.inflict, unit_named("Lord")), "Poison 100", "(text helper)")
	b.ui.show_forecast(brig, lord, Combat.forecast(brig, lord, b.map), lord.cell)
	check_eq([b.ui._forecast_cells[7][1].text, b.ui._forecast_cells[7][2].text], ["--", "Poison 100"],
		"the defender's counter can inflict too")
	lord.equip(lord.items.find(lord.items.filter(func(it): return it.name == "Iron Sword")[0]))
	b.ui.show_forecast(lord, brig, Combat.forecast(lord, brig, b.map), lord.cell)
	check(not b.ui._forecast_cells[7][1].visible, "no Status row when nobody inflicts")
	give_weapon(lord, "Venom Edge")
	await b.actions.do_combat(lord, brig)
	check(brig.hp > 0 and brig.statuses.has("Poison"), "a hit poisons")
	var immune := brig
	Statuses.cure(immune)
	immune.personal_skills.assign(["Poison Immunity"])
	check_eq(BattleUI.inflict_text(f.atk.inflict, immune), "Immune", "the forecast shows immunity")
	await b.actions.do_combat(lord, immune)
	check(immune.statuses.is_empty(), "and it holds")


func test_status_spell() -> void:
	var pair := await _sure_hit_duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.spells.assign(["Sleep"])
	lord.mp = 20
	var f := Combat.spell_forecast(lord, brig, Spells.get_spell("Sleep"), b.map)
	check_eq(f.atk.dmg, 0, "a status spell deals no damage")
	check(not f.can_counter, "and can't be countered")
	var brig_hp := brig.hp
	var lord_hp := lord.hp
	await b.actions.do_spell_attack(lord, brig, "Sleep")
	check(brig.statuses.has("Sleep"), "a hit puts it to sleep")
	check_eq(brig.hp, brig_hp, "without waking it with damage")
	check_eq(lord.hp, lord_hp, "no counter")
	check(Glossary.spell("Sleep").contains("inflicts Sleep"), "described as a status spell")


func test_envenom_after_combat() -> void:
	var pair := await _sure_hit_duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.personal_skills.assign(["Envenom"])
	await b.actions.do_combat(lord, brig)
	check(brig.hp > 0 and brig.statuses.has("Poison"), "Envenom: the foe it attacked is poisoned after combat")
