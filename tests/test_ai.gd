extends "res://tests/test_base.gd"
## Enemy behaviors (AIProfiles, EnemyAI).


# --- Enemy behaviors ----------------------------------------------------------


func test_ai_profiles_resolve() -> void:
	var ai := AIProfiles.resolve({"preset": "boss", "guard_radius": 5})
	check_eq(ai.move, "hold", "preset sets move")
	check_eq(ai.caution, 0.0, "preset sets caution")
	check_eq(ai.guard_radius, 5, "per-unit override wins")
	check_eq(ai.targeting, "damage", "unset keys keep defaults")
	check_eq(AIProfiles.resolve({}).move, "charge", "no ai entry = charger")


func test_ai_hold_attacks_only_from_its_tile() -> void:
	var merc := unit_named("Mercenary", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([merc, fighter])
	merc.set_cell(Vector2i(8, 6))
	fighter.set_cell(Vector2i(10, 6))
	await EnemyAI.take_turn(merc, b)
	check_eq(merc.cell, Vector2i(8, 6), "boss never moves")
	check(not fighter.was_attacked, "target 2 tiles away is out of a sword's reach")
	merc.has_acted = false
	fighter.set_cell(Vector2i(9, 6))
	await EnemyAI.take_turn(merc, b)
	check_eq(merc.cell, Vector2i(8, 6), "still on its tile")
	check(fighter.was_attacked, "attacks an adjacent target")


func test_ai_in_range_waits_until_reachable() -> void:
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([brig, fighter])
	brig.ai = AIProfiles.resolve({"preset": "ambusher"})
	brig.set_cell(Vector2i(12, 2))
	fighter.set_cell(Vector2i(3, 2))
	await EnemyAI.take_turn(brig, b)
	check_eq(brig.cell, Vector2i(12, 2), "nothing reachable: stays put")
	brig.has_acted = false
	fighter.set_cell(Vector2i(8, 2))
	await EnemyAI.take_turn(brig, b)
	check(brig.cell != Vector2i(12, 2) and fighter.was_attacked, "target reachable: moves in and attacks")


func test_ai_guard_stays_in_area() -> void:
	var sold := unit_named("Soldier", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([sold, fighter])
	var anchor: Vector2i = sold.anchor
	fighter.set_cell(Vector2i(0, 0))
	await EnemyAI.take_turn(sold, b)
	check_eq(sold.cell, anchor, "idle sentry stays on its post")
	sold.has_acted = false
	fighter.set_cell(Vector2i(10, 2))
	await EnemyAI.take_turn(sold, b)
	check(BattleMap.distance(sold.cell, anchor) <= sold.ai.guard_radius, "attacks without leaving its area")
	check(fighter.was_attacked, "attacks an intruder it can reach")
	sold.has_acted = false
	fighter.set_cell(Vector2i(0, 0))
	sold.set_cell(Vector2i(8, 2))
	var before := BattleMap.distance(sold.cell, anchor)
	await EnemyAI.take_turn(sold, b)
	check(BattleMap.distance(sold.cell, anchor) < before, "displaced sentry heads back to its post")


func test_ai_wake_conditions() -> void:
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var sleeper: Unit = b.units().filter(func(u): return u.unit_name == "Brigand" and u.ai.move == "hold")[0]
	var e_cleric := unit_named("Cleric", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([brig, sleeper, e_cleric, fighter])
	brig.set_cell(Vector2i(14, 0))
	# in_threat (+ group): asleep while the player is far, wakes when inside its reach.
	fighter.set_cell(Vector2i(1, 2))
	await EnemyAI.take_turn(sleeper, b)
	check_eq(sleeper.cell, Vector2i(12, 6), "sleeper does not move while asleep")
	check(not sleeper.ai_awake, "still asleep")
	fighter.set_cell(Vector2i(8, 6))
	EnemyAI.update_all_wake(b)
	check(sleeper.ai_awake, "player inside its threat wakes it")
	check(e_cleric.ai_awake, "its group wakes with it")
	check_eq(EnemyAI.current_move(sleeper), "charge", "awake units use awake_move")
	# attacked
	brig.ai = AIProfiles.resolve({"move": "hold", "wake": {"attacked": true}})
	EnemyAI.update_wake(brig, b)
	check(not brig.ai_awake, "not attacked yet")
	brig.notify_attacked()
	EnemyAI.update_wake(brig, b)
	check(brig.ai_awake, "being attacked wakes it")
	# turn
	brig.ai = AIProfiles.resolve({"preset": "reinforcement"})
	brig.ai_awake = false
	b.turn = 2
	EnemyAI.update_wake(brig, b)
	check(not brig.ai_awake, "reinforcement waits for turn 3")
	b.turn = 3
	EnemyAI.update_wake(brig, b)
	check(brig.ai_awake, "wakes on turn 3")
	# radius
	brig.ai = AIProfiles.resolve({"move": "hold", "wake": {"radius": 3}})
	brig.ai_awake = false
	brig.set_cell(Vector2i(12, 2))
	fighter.set_cell(Vector2i(8, 2))
	EnemyAI.update_wake(brig, b)
	check(not brig.ai_awake, "4 tiles away: still asleep")
	fighter.set_cell(Vector2i(9, 2))
	EnemyAI.update_wake(brig, b)
	check(brig.ai_awake, "3 tiles away: wakes")


func test_ai_retreat_to_healer_then_fort() -> void:
	var thief := unit_named("Thief", Unit.Team.ENEMY)
	var e_cleric := unit_named("Cleric", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([thief, e_cleric, fighter])
	thief.set_cell(Vector2i(12, 2))
	fighter.set_cell(Vector2i(11, 2))
	thief.hp = 7
	var before := BattleMap.distance(thief.cell, e_cleric.cell)
	await EnemyAI.take_turn(thief, b)
	check(thief.retreating, "at or below 50% HP the coward retreats")
	check(BattleMap.distance(thief.cell, e_cleric.cell) < before, "heads for the healer")
	check(not fighter.was_attacked, "does not attack while retreating")
	# Healer out of MP: go for the Fort at (13, 0) instead.
	e_cleric.mp = 0
	thief.has_acted = false
	thief.set_cell(Vector2i(12, 2))
	await EnemyAI.take_turn(thief, b)
	check_eq(thief.cell, Vector2i(13, 0), "no usable healer: retreats onto the Fort")
	await b.phases.heal_on_tiles(Unit.Team.ENEMY)
	check_eq(thief.hp, 11, "Fort heals 20% of max HP (ceil 3.2 = 4)")
	thief.hp = thief.max_hp
	EnemyAI.update_retreat(thief)
	check(not thief.retreating, "back to normal once healed")


func test_ai_targeting_weakest_and_priority() -> void:
	var thief := unit_named("Thief", Unit.Team.ENEMY)
	var e_mage := unit_named("Mage", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	var archer := unit_named("Archer")
	var cleric := unit_named("Cleric")
	isolate([thief, e_mage, fighter, archer, cleric])
	# Weakest: the Thief goes for the 5-HP Archer, not the Fighter.
	e_mage.set_cell(Vector2i(14, 9))
	cleric.set_cell(Vector2i(0, 0))
	thief.set_cell(Vector2i(8, 2))
	fighter.set_cell(Vector2i(9, 2))
	archer.set_cell(Vector2i(8, 3))
	archer.hp = 5
	await EnemyAI.take_turn(thief, b)
	check(archer.was_attacked and not fighter.was_attacked, "weakest targeting picks the lowest HP")
	# Priority: Fire would hurt the Fighter more, but the Mage prefers the Cleric.
	fighter.was_attacked = false
	archer.set_cell(Vector2i(0, 9))
	thief.set_cell(Vector2i(14, 0))
	e_mage.set_cell(Vector2i(10, 6))
	cleric.set_cell(Vector2i(8, 6))
	cleric.mp = 2  # spent MP = low magic defense; at full MP, Fire would do nothing
	fighter.set_cell(Vector2i(10, 8))
	await EnemyAI.take_turn(e_mage, b)
	check(cleric.was_attacked and not fighter.was_attacked, "priority target chosen over a juicier one")


func test_ai_goto_without_attacking() -> void:
	var thief := unit_named("Thief", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([thief, fighter])
	thief.ai = AIProfiles.resolve({"preset": "thief", "destination": Vector2i(1, 9)})
	thief.set_cell(Vector2i(8, 6))
	fighter.set_cell(Vector2i(8, 7))  # adjacent, but not blocking the (7, 6) river crossing
	var before := BattleMap.distance(thief.cell, Vector2i(1, 9))
	await EnemyAI.take_turn(thief, b)
	check(BattleMap.distance(thief.cell, Vector2i(1, 9)) < before, "heads for its destination")
	check(not fighter.was_attacked, "attack: false never starts a fight")


func test_fort_heal_and_boss_threat() -> void:
	var merc := unit_named("Mercenary", Unit.Team.ENEMY)
	var lord := unit_named("Lord")
	check_eq(b.map.terrain_key(merc.cell), "T", "boss starts on a Fort")
	# Boss threat: its own tile plus the 4 neighbors (sword range 1), not its MOV.
	check_eq(b.enemy_threat(merc).size(), 5, "hold enemy threatens only from its tile")
	lord.set_cell(Vector2i(1, 9))
	lord.hp = 10
	await b.phases.heal_on_tiles(Unit.Team.PLAYER)
	check_eq(lord.hp, 14, "Fort heals ceil(18 * 0.2) = 4 at phase start")


func test_ai_enemy_killed_by_counter_on_its_turn() -> void:
	# Regression: an enemy dying to a counter mid-turn used to crash _finish().
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var fighter := unit_named("Fighter")
	isolate([brig, fighter])
	brig.set_cell(Vector2i(8, 2))
	fighter.set_cell(Vector2i(9, 2))
	brig.hp = 1
	brig.items.assign(brig.weapons().filter(func(w): return w.name == "Iron Axe"))  # melee only, so the counter reaches
	fighter.dexterity = 60  # guarantees the counter lands
	await EnemyAI.take_turn(brig, b)
	check(not is_instance_valid(brig) or brig.hp <= 0, "brigand died to the counter")
	check(fighter.was_attacked, "it attacked first")
