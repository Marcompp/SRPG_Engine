extends "res://tests/test_base.gd"
## Skills.


# --- Skills -------------------------------------------------------------------


func test_skill_sources_and_stats() -> void:
	var lord := unit_named("Lord")
	var base_str := lord.combat_str()
	var base_lck := lord.combat_lck()
	var base_mov := lord.mov
	check(Skills.has(lord, "Adaptable"), "Humans get their racial skill")
	check(Skills.has(unit_named("Dancer"), "Dance"), "Performers get Dance from their class")
	lord.personal_skills.assign(["Luck +4"])
	lord.learned.assign(["Celerity"])
	lord.items.append(Items.make("Power Ring"))
	lord.items[0]["skills"] = ["Skill +2"]  # the equipped Iron Sword
	var expected := [["Luck +4", "Personal"], ["Adaptable", "Race"], ["Celerity", "Learned"],
		["Skill +2", "Iron Sword"], ["Strength +2", "Power Ring"]]
	check_eq(Skills.sources(lord), expected, "every source, in order")
	check_eq(lord.combat_str(), base_str + 2, "held ring: +2 STR")
	check_eq(lord.combat_lck(), base_lck + 4, "personal: +4 LCK")
	check_eq(lord.mov, base_mov + 1, "learned Celerity: +1 MOV")
	check_eq(lord.combat_dex(), lord.dexterity + 2, "equipped weapon: +2 DEX")
	lord.equip(1)  # the Knife: the sword's skill only works while equipped
	check_eq(lord.combat_dex(), lord.dexterity, "unequipped weapon skills stop")
	lord.items.pop_back()
	check_eq(lord.combat_str(), base_str, "dropping the ring removes its skill")
	# Racial traits now come from skills.
	check_eq(Skills.exp_multiplier(lord), 1.1, "Adaptable: +10% EXP")
	lord.set_race("Troll")
	check_eq(Skills.turn_heal(lord), 0.1, "Trolls regenerate")
	check(Skills.is_immune(lord, "poison"), "and are immune to poison")


func test_scroll_learning_and_cap() -> void:
	var lord := unit_named("Lord")
	lord.learned.assign(["Luck +4", "Skill +2", "Speed +2", "Defense +2", "Magic +2"])
	lord.items.assign([Items.make("Iron Sword"), Items.make("Vigor Scroll"), Items.make("Celerity Scroll")])
	lord.equip(0)
	# Full: it asks which to forget; "Don't learn" (or X) keeps the scroll and the turn.
	await open_menu_in_place(lord)
	await pick("Items")
	await pick("Vigor Scroll  1")
	check_eq(b.state, b.State.CHOICE, "learning a sixth skill asks first")
	check_eq(b.ui.menu_options[-1], "Don't learn", "with an option not to")
	await press(KEY_X)
	check_eq(lord.learned.size(), 5, "nothing learned")
	check(lord.items.any(func(it): return it.name == "Vigor Scroll"), "the scroll is kept")
	check(not lord.has_acted, "and the turn isn't used")
	check_eq(b.input.menu_context, "items", "back in the items menu")
	# Forget the first one instead.
	await pick("Vigor Scroll  1")
	await press(KEY_Z)
	check(not lord.learned.has("Luck +4"), "the picked skill is forgotten")
	check_eq(lord.learned[-1], "Strength +2", "the new one learned")
	check(not lord.items.any(func(it): return it.name == "Vigor Scroll"), "the scroll is used up")
	check(lord.has_acted, "reading it ends the turn")
	# A skill it already has can't be learned again.
	check(not Items.can_use(lord, Items.make("Vigor Scroll")), "no scroll for a skill it has")
	# Enemies that are full don't learn.
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	brig.learned.assign(["Luck +4", "Skill +2", "Speed +2", "Defense +2", "Magic +2"])
	check(not await b.actions.learn_skill(brig, "Celerity"), "a full enemy doesn't learn")


func test_level_up_learns_skills() -> void:
	var lord := unit_named("Lord")
	lord.learn_table = {2: "Celerity"}
	lord.exp_points = 0
	await b.actions.gain_exp(lord, 100)
	check_eq(lord.level, 2, "level up")
	check(lord.learned.has("Celerity"), "learns its level-2 skill")
	# Units created above level 1 already know what their tables taught.
	var data := {"class": "Swordsman", "items": ["Iron Sword"], "lv": 6, "hp": 20, "str": 5, "dex": 5,
		"agi": 5, "lck": 5, "def": 5, "mov": 5, "learn": {3: "Celerity", 5: "Luck +4", 7: "Speed +2"}}
	var u := Unit.create("Vet", Unit.Team.PLAYER, Vector2i.ZERO, data)
	check_eq(u.learned, ["Celerity", "Luck +4"] as Array[String], "skills up to its level, not beyond")
	u.free()


func test_skill_data_valid() -> void:
	check_eq(Skills.validate(), [] as Array[String], "skill data problems")
	# Every skill named anywhere exists.
	var named: Array = []
	for c in Classes.DATA.values():
		named.append_array(c.get("skills", []))
		named.append_array(c.get("learn", {}).values())
	for r in Races.DATA.values():
		named.append_array(r.get("skills", []))
	for it in Items.CONSUMABLES.values():
		named.append_array(it.get("skills", []))
		if it.has("skill"):
			named.append(it.skill)
	for w in Weapons.DATA.values():
		named.append_array(w.get("skills", []))
	for level in Levels.DATA.values() + Chapters.DATA.values():
		for data in level.get("players", []) + level.get("enemies", []):
			named.append_array(data.get("skills", []))
			named.append_array(data.get("learn", {}).values())
	for skill in named:
		check(Skills.DATA.has(skill), "unknown skill %s" % skill)


func test_battle_modifier_skills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	var base := Combat.forecast(lord, brig, b.map)
	var base_counter := Combat.forecast(brig, lord, b.map)
	lord.personal_skills.assign(["Death Blow"])
	check_eq(Combat.forecast(lord, brig, b.map).atk.dmg, base.atk.dmg + 6, "Death Blow: +6 Atk when attacking")
	check_eq(Combat.forecast(brig, lord, b.map).def.dmg, base_counter.def.dmg, "but not when attacked")
	lord.personal_skills.assign(["Wrath"])
	check_eq(Combat.forecast(lord, brig, b.map).atk.crit, base.atk.crit, "Wrath: nothing at full HP")
	lord.hp = lord.max_hp / 2
	check_eq(Combat.forecast(lord, brig, b.map).atk.crit, mini(base.atk.crit + 30, 100), "+30 Crit at half HP")
	lord.hp = lord.max_hp
	lord.personal_skills.assign(["Axebreaker"])
	var f := Combat.forecast(lord, brig, b.map)
	check_eq(f.atk.hit, mini(base.atk.hit + 50, 100), "Axebreaker: +50 Hit against axes")
	check_eq(f.def.hit, maxi(base.def.hit - 50, 0), "and +50 Avo")
	lord.personal_skills.assign(["Steady Stance"])
	check_eq(Combat.forecast(brig, lord, b.map).atk.dmg, maxi(base_counter.atk.dmg - 4, 0), "Steady Stance: +4 DEF when attacked")
	check_eq(Combat.forecast(lord, brig, b.map).def.dmg, base.def.dmg, "but not when attacking")


func test_strike_order_skills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.agility = 20  # the Lord doubles, the Brigand doesn't
	var L := [lord, brig]
	var B := [brig, lord]
	check_eq(Combat.strike_order(lord, brig, b.map), [L, B, L], "normal: attack, counter, follow-up")
	lord.personal_skills.assign(["Desperation"])
	check_eq(Combat.strike_order(lord, brig, b.map), [L, B, L], "Desperation needs half HP")
	lord.hp = 1
	check_eq(Combat.strike_order(lord, brig, b.map), [L, L, B], "Desperation: follow-up before the counter")
	lord.personal_skills.assign(["Vantage"])
	check_eq(Combat.strike_order(brig, lord, b.map), [L, B, L], "Vantage: strikes first when attacked")
	lord.hp = lord.max_hp
	lord.personal_skills.assign(["Wary Fighter"])
	check_eq(Combat.strike_order(lord, brig, b.map), [L, B], "Wary Fighter: nobody doubles")
	lord.agility = 0
	lord.personal_skills.assign(["Quick Riposte"])
	check_eq(Combat.strike_order(brig, lord, b.map), [B, L, L], "Quick Riposte: doubles when attacked at high HP")
	check(Combat.forecast(brig, lord, b.map).def.double, "and the forecast shows it")
	lord.personal_skills.assign(["Dazzle"])
	check(not Combat.can_counter(lord, brig, b.map), "Dazzle: no counter")
	check_eq(Combat.strike_order(lord, brig, b.map), [L], "so the Lord strikes alone")
	lord.personal_skills.clear()
	brig.set_cell(Vector2i(7, 6))
	brig.equip(brig.items.find(brig.items.filter(func(it): return it.name == "Iron Axe")[0]))
	brig.items.assign([brig.weapon])  # melee only
	check(not Combat.can_counter(lord, brig, b.map), "an axe can't counter at range 2")
	brig.personal_skills.assign(["Close Counter"])
	check(Combat.can_counter(lord, brig, b.map), "Close Counter: it can")


func test_proc_skills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	lord.dexterity = 100  # 100%+ activation and hit
	brig.dexterity = 100
	brig.max_hp = 99  # room for the HP the checks below give it
	var plain := Combat.damage(lord, brig, b.map)
	var def := brig.combat_def()
	lord.personal_skills.assign(["Luna"])
	var hit := Combat.strike(lord, brig, b.map)
	check_eq(hit.procs, [[lord, "Luna"]], "Luna fires")
	check_eq(hit.dmg / (3 if hit.crit else 1), plain + floori(def * 0.5), "ignoring half the foe's DEF")
	check_eq(Combat.forecast(lord, brig, b.map).atk.dmg, plain, "procs aren't in the forecast")
	lord.personal_skills.assign(["Sol"])
	brig.hp = 99
	hit = Combat.strike(lord, brig, b.map)
	check_eq(hit.heal, hit.dmg, "Sol heals the damage dealt")
	lord.personal_skills.assign(["Lethality"])
	lord.dexterity = 400
	hit = Combat.strike(lord, brig, b.map)
	check(hit.dmg >= brig.hp, "Lethality kills")
	lord.dexterity = 100
	lord.personal_skills.clear()
	brig.personal_skills.assign(["Pavise"])
	hit = Combat.strike(lord, brig, b.map)
	var full: int = plain * (3 if hit.crit else 1)
	check_eq(hit.procs, [[brig, "Pavise"]], "Pavise fires in melee")
	check_eq(hit.dmg, full - floori(full * 0.5), "halving the damage")
	brig.personal_skills.assign(["Miracle"])
	brig.luck = 100
	brig.hp = 2
	hit = Combat.strike(lord, brig, b.map)
	check_eq(hit.dmg, 1, "Miracle leaves 1 HP")
	brig.hp = 99
	hit = Combat.strike(lord, brig, b.map)
	check_eq(hit.procs, [], "Miracle only on a lethal blow")
	# A whole fight with a proc: popups and healing go through.
	brig.personal_skills.clear()
	brig.hp = 99
	lord.personal_skills.assign(["Sol"])
	lord.hp = 5
	await b.actions.do_combat(lord, brig)
	check(lord.hp > 5 or lord.hp <= 0, "Sol healed the Lord during the fight")


func test_after_combat_skills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	_spawn_enemy(Vector2i(14, 9))  # keeps the map from ending
	lord.dexterity = 100
	brig.agility = 0
	brig.luck = 0
	# Lifetaker: heal half max HP after a kill it started.
	lord.personal_skills.assign(["Lifetaker"])
	lord.hp = 3
	brig.hp = 1
	await b.actions.do_combat(lord, brig)
	check_eq(lord.hp, mini(3 + ceili(lord.max_hp * 0.5), lord.max_hp), "Lifetaker heals after the kill")
	# Galeforce: act again, once per turn.
	lord.personal_skills.assign(["Galeforce"])
	b.input.selected = lord
	await b.actions.do_combat(lord, _spawn_enemy(Vector2i(6, 6), 1))
	check(lord.refresh_pending, "Galeforce after a kill")
	b.input.finish_action()
	check(not lord.has_acted, "the Lord can act again")
	await b.actions.do_combat(lord, _spawn_enemy(Vector2i(6, 6), 1))
	check(not lord.refresh_pending, "but only once per turn")
	# Poison Strike / Savage Blow: non-lethal damage after combat.
	var target := _spawn_enemy(Vector2i(6, 6), 99)
	var bystander := _spawn_enemy(Vector2i(7, 7), 2)
	lord.personal_skills.assign(["Poison Strike", "Savage Blow"])
	lord.hp = lord.max_hp
	var before := target.hp
	await b.actions.do_combat(lord, target)
	check(target.hp <= before - ceili(99 * 0.2), "Poison Strike takes 20% of max HP after combat")
	check_eq(bystander.hp, 1, "Savage Blow hits a nearby foe, never below 1")


func test_movement_skills() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([lord, brig])
	await process_frame
	lord.set_cell(Vector2i(5, 6))
	brig.set_cell(Vector2i(6, 6))
	check(not b.map.get_reachable(lord, b.units()).parents.has(Vector2i(6, 6)), "enemies block the way")
	lord.personal_skills.assign(["Pass"])
	var reach: Dictionary = b.map.get_reachable(lord, b.units())
	check(reach.parents.has(Vector2i(6, 6)), "Pass: through enemies")
	check(not reach.cells.has(Vector2i(6, 6)), "but not onto them")
	# Pathfinder: forests cost 1. (4, 5) is a forest.
	lord.personal_skills.clear()
	check_eq(b.map.unit_cost(lord, Vector2i(4, 5)), 2.0, "a forest costs a foot unit 2")
	lord.personal_skills.assign(["Pathfinder"])
	check_eq(b.map.unit_cost(lord, Vector2i(4, 5)), 1.0, "Pathfinder: 1")
	check_eq(b.map.unit_cost(lord, Vector2i(7, 0)), 1.0, "even rivers")
	check(b.can_stand_on(lord, Vector2i(7, 0)), "so it can be set down there")


func test_canto() -> void:
	var lord := unit_named("Lord")
	lord.personal_skills.assign(["Canto"])
	lord.hp = 5
	lord.set_cell(Vector2i(4, 2))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_RIGHT)
	await press(KEY_Z)  # move 1 tile
	await pick("Items")
	await pick("Potion  3")
	check_eq(b.state, b.State.SELECTED, "Canto: after acting, it can move again")
	check(b.input.canto_move, "a Canto move")
	check(not lord.has_acted, "not done yet")
	var left: float = lord.mov - 1
	check(b.input.reach.cells.values().all(func(c): return c <= left + 0.001), "with the MOV it has left")
	await press(KEY_RIGHT)
	await press(KEY_Z)
	check_eq(lord.cell, Vector2i(6, 2), "it moves")
	check(lord.has_acted, "and its turn ends")
	# Waiting doesn't give a Canto move.
	var fighter := unit_named("Fighter")
	fighter.personal_skills.assign(["Canto"])
	b.cursor.cell = fighter.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Wait")
	check(fighter.has_acted, "Wait ends the turn")
	check_eq(b.state, b.State.IDLE, "no Canto after waiting")


func test_aura_adjacency_and_growth_skills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	var base := Combat.forecast(lord, brig, b.map)
	# Solo Fighter: +10 Hit/Avo with no ally adjacent.
	lord.personal_skills.assign(["Solo Fighter"])
	check_eq(Combat.forecast(lord, brig, b.map).atk.hit, mini(base.atk.hit + 10, 100), "alone: +10 Hit")
	lord.personal_skills.clear()
	# Charisma: an ally within 3 gives +10 Hit and Avo.
	var fighter := Unit.create("Ally", Unit.Team.PLAYER, Vector2i(3, 6), {"class": "Axeman", "items": ["Iron Axe"],
		"hp": 20, "str": 5, "dex": 5, "agi": 5, "lck": 5, "def": 5, "mov": 5, "skills": ["Charisma"]})
	b.units_root.add_child(fighter)
	var f := Combat.forecast(lord, brig, b.map)
	check_eq(f.atk.hit, mini(base.atk.hit + 10, 100), "Charisma: +10 Hit to allies in range")
	check_eq(f.def.hit, maxi(base.def.hit - 10, 0), "and +10 Avo")
	fighter.set_cell(Vector2i(0, 0))
	check_eq(Combat.forecast(lord, brig, b.map).atk.hit, base.atk.hit, "out of range: nothing")
	# Anathema on an enemy: the Lord nearby loses Avo.
	brig.personal_skills.assign(["Anathema"])
	check_eq(Combat.forecast(lord, brig, b.map).def.hit, mini(base.def.hit + 10, 100), "Anathema: foes lose 10 Avo")
	check_eq(Combat.forecast(lord, brig, b.map).atk.hit, base.atk.hit, "the owner itself isn't affected")
	# Growths and EXP.
	lord.personal_skills.assign(["Aptitude", "Paragon"])
	check_eq(Skills.growth_bonus(lord, "str"), 20, "Aptitude: +20% growths")
	check(is_equal_approx(Skills.exp_multiplier(lord), 2.2), "Paragon doubles EXP (and Adaptable stacks)")
	lord.personal_skills.assign(["Renewal"])
	check(is_equal_approx(Skills.turn_heal(lord), 0.3), "Renewal: 30% each turn")


func test_steal_and_lockpick() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	_spawn_enemy(Vector2i(14, 9))
	# An idle ally keeps the player phase open after the Lord acts.
	b.units_root.add_child(Unit.create("Idle", Unit.Team.PLAYER, Vector2i(0, 0), {"class": "Axeman", "items": [],
		"hp": 20, "str": 5, "dex": 5, "agi": 5, "lck": 5, "def": 5, "mov": 5}))
	lord.set_class("Rogue")
	check(Skills.has(lord, "Lockpick") and b.actions.can_open_chest(lord), "Rogues pick locks")
	brig.items.append(Items.make("Potion"))
	lord.agility = brig.combat_agi()
	check(b.actions.steal_targets(lord).is_empty(), "no Steal without more AGI")
	lord.agility = brig.combat_agi() + 1
	check_eq(b.actions.stealable_items(brig), [brig.items.size() - 1] as Array[int], "only non-weapons")
	var exp_before := lord.exp_points
	await open_menu_in_place(lord)
	await pick("Steal")
	check(b.ui._spell_label.text.contains("Potion"), "the forecast lists what it can take")
	await press(KEY_Z)
	check_eq(b.input.menu_context, "steal", "then pick the item")
	await press(KEY_Z)
	check(lord.items.any(func(it): return it.name == "Potion"), "stolen")
	check(not brig.items.any(func(it): return it.name == "Potion"), "and gone from the foe")
	check(lord.has_acted, "stealing ends the turn")
	check(lord.exp_points != exp_before or lord.level > 1, "and gives EXP")


func test_range_skills() -> void:
	var archer := unit_named("Archer")
	check_eq(archer.max_range, 2, "an Iron Bow reaches 2")
	archer.personal_skills.assign(["Bow Range +1"])
	check_eq(archer.max_range, 3, "Bow Range +1: 3")
	check(archer.can_attack_at(3) and not archer.can_attack_at(4), "attacks at 3")
	check(archer.weapon_ranges().has(Vector2i(2, 3)), "and its threat range grows")
	var lord := unit_named("Lord")
	lord.personal_skills.assign(["Bow Range +1"])
	check(not lord.can_attack_at(2), "only bows")
	var mage := unit_named("Mage")
	var fire_max: int = Spells.get_spell("Fire").max_rng
	check(not Spells.reaches("Fire", fire_max + 1, mage), "Fire's normal range")
	mage.personal_skills.assign(["Spell Range +1"])
	check(Spells.reaches("Fire", fire_max + 1, mage), "Spell Range +1")


func test_class_skill_effects() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	_spawn_enemy(Vector2i(14, 9))
	# Prayer: adjacent allies heal at the start of the phase.
	var cleric := Unit.create("Priest", Unit.Team.PLAYER, Vector2i(4, 6), {"class": "Cleric", "items": [],
		"hp": 16, "str": 1, "dex": 5, "agi": 5, "lck": 5, "def": 1, "mov": 5, "learn": {1: "Prayer"}})
	b.units_root.add_child(cleric)
	check(cleric.learned.has("Prayer"), "Prayer learned")
	lord.hp = 1
	await b.phases.heal_on_tiles(Unit.Team.PLAYER)
	check_eq(lord.hp, 1 + ceili(lord.max_hp * 0.1), "Prayer heals the adjacent Lord 10%")
	# Highlander: +15 Hit on mountains.
	var base: int = Combat.forecast(brig, lord, b.map).atk.hit
	brig.personal_skills.assign(["Highlander"])
	check_eq(Combat.forecast(brig, lord, b.map).atk.hit, base, "not on plains")
	brig.set_cell(Vector2i(3, 3))  # a mountain
	lord.set_cell(Vector2i(4, 3))
	var on_mountain: int = Combat.forecast(brig, lord, b.map).atk.hit
	brig.personal_skills.clear()
	check_eq(on_mountain, mini(Combat.forecast(brig, lord, b.map).atk.hit + 15, 100), "+15 Hit on a mountain")
	# Warding: +5 magic defense.
	var mage := Unit.create("Witch", Unit.Team.ENEMY, Vector2i(5, 4), {"class": "Mage", "items": [], "spells": ["Fire"],
		"hp": 16, "str": 1, "int": 8, "dex": 5, "agi": 5, "lck": 5, "def": 1, "mov": 5, "mp": 10})
	b.units_root.add_child(mage)
	var fire := Spells.get_spell("Fire")
	var plain := Combat.spell_damage(mage, lord, fire, b.map)
	lord.personal_skills.assign(["Warding"])
	check_eq(Combat.spell_damage(mage, lord, fire, b.map), maxi(plain - 5, 0), "Warding: -5 spell damage")
	# Footwork: Canto only after Dancing.
	lord.personal_skills.assign(["Footwork", "Dance"])
	cleric.set_cell(Vector2i(4, 2))
	cleric.has_acted = true
	lord.set_cell(Vector2i(5, 2))
	lord.has_acted = false
	await open_menu_in_place(lord)
	await pick("Dance")
	await press(KEY_Z)
	check(b.input.canto_move, "Footwork: it can move after Dancing")
	await press(KEY_X)
	lord.has_acted = false
	await open_menu_in_place(lord)
	await pick("Wait")
	check(not b.input.canto_move and lord.has_acted, "but not after other actions")
	# Races that only take plain foot classes can't be scouts.
	check(not Races.allows("Stoneborn", "Rogue"), "Stoneborn can't be Rogues")
	check(Races.allows("Stoneborn", "Footman"), "but can be Footmen")


func test_max_hp_weight_and_crit_skills() -> void:
	var pair := await _duel()
	var lord: Unit = pair[0]
	var brig: Unit = pair[1]
	# Max HP +5 raises max HP on top of the base; losing it caps current HP.
	var base := lord.max_hp
	lord.items.append(Items.make("Potion"))
	lord.learned.assign(["Max HP +5"])
	check_eq(lord.max_hp, base + 5, "Max HP +5")
	check_eq(lord.base_max_hp, base, "the base is untouched")
	lord.hp = lord.max_hp
	lord.learned.clear()
	check_eq(lord.hp, base, "HP never above max HP")
	# Level-ups and saves work on the base value.
	lord.learned.assign(["Max HP +5"])
	var copy := SaveGame.unit_from_dict(SaveGame.unit_to_dict(lord))
	check_eq(copy.max_hp, base + 5, "saved and restored with the bonus on top")
	check_eq(copy.base_max_hp, base, "and the same base")
	copy.free()
	# Brawn: weapons weigh 5 less.
	brig.items.assign([Items.make("Steel Axe")])
	brig.equip(0)
	brig.strength = 0
	var slow := Combat.attack_speed(brig)
	brig.personal_skills.assign(["Brawn"])
	check_eq(Combat.attack_speed(brig), mini(slow + 5, brig.combat_agi()), "Brawn: 5 less weight burden")
	# Impale: crit against mounted foes.
	brig.personal_skills.clear()
	lord.personal_skills.assign(["Impale"])
	brig.set_class("Cavalry")
	brig.items.assign([Items.make("Iron Spear")])
	brig.equip(0)
	var vs_horse: int = Combat.forecast(lord, brig, b.map).atk.crit
	lord.personal_skills.clear()
	check_eq(vs_horse, mini(Combat.forecast(lord, brig, b.map).atk.crit + 25, 100), "Impale: +25 Crit vs horses")
	# Class data: Bishops pray, Clerics learn Max MP +5.
	check(Classes.get_data("Bishop").skills.has("Prayer"), "Bishop: Prayer")
	check_eq(Classes.get_data("Cleric").learn[10], "Max MP +5", "Cleric Lv 10: Max MP +5")
