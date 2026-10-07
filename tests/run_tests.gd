extends SceneTree
## Headless test suite. Run from the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 0 if every test passes, 1 otherwise.
##
## Each test gets a fresh battle scene (waiting out the opening banner) and should
## place the units it uses explicitly, since the starting map is crowded.

const MAIN_SCENE := "res://scenes/main.tscn"

var b: Node
var failures: Array[String] = []
var current_test := ""


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var tests := [
		"test_combat_formulas",
		"test_true_hit_distribution",
		"test_bow_and_thrown_ranges",
		"test_weapon_break_ends_strikes",
		"test_exp_formula_and_level_up",
		"test_cancel_move_restores_unit",
		"test_heal_spell",
		"test_fire_forecast_and_counter",
		"test_firestorm_targets_and_cast",
		"test_earth_spike_raises_mountain",
		"test_dance_refreshes_ally",
		"test_enemy_mage_uses_firestorm_on_cluster",
		"test_enemy_phases_run_without_errors",
	]
	for t in tests:
		current_test = t
		await _fresh_battle()
		var before := failures.size()
		await call(t)
		print(("PASS  " if failures.size() == before else "FAIL  ") + t)
		b.queue_free()
		await process_frame
	print("")
	if failures.is_empty():
		print("All %d tests passed." % tests.size())
		quit(0)
	else:
		print("%d failure(s):" % failures.size())
		for f in failures:
			print("  " + f)
		quit(1)


# --- Helpers -------------------------------------------------------------------

func _fresh_battle() -> void:
	b = load(MAIN_SCENE).instantiate()
	root.add_child(b)
	while b.state != b.State.IDLE:
		await process_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])


func unit_named(unit_name: String, team: int = Unit.Team.PLAYER) -> Unit:
	for u in b.units():
		if u.unit_name == unit_name and u.team == team:
			return u
	return null


## Moves every unit except `keep` far out of the way (bottom-right open cells).
func clear_board(keep: Array) -> void:
	var parking := [Vector2i(14, 9), Vector2i(13, 9), Vector2i(12, 9), Vector2i(11, 9), Vector2i(10, 9),
		Vector2i(9, 9), Vector2i(8, 9), Vector2i(14, 8), Vector2i(13, 8), Vector2i(14, 6), Vector2i(13, 6),
		Vector2i(12, 6), Vector2i(14, 4), Vector2i(13, 4), Vector2i(12, 4), Vector2i(14, 3), Vector2i(14, 2),
		Vector2i(13, 2)]
	var i := 0
	for u in b.units():
		if not keep.has(u):
			u.set_cell(parking[i])
			i += 1


func press(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	b._unhandled_input(e)
	await process_frame
	while b.state == b.State.BUSY:
		await process_frame


func pick(option: String) -> void:
	if not b.ui.menu_options.has(option):
		check(false, "menu has no '%s' (options: %s)" % [option, b.ui.menu_options])
		return
	while b.ui.menu_choice() != option:
		await press(KEY_DOWN)
	await press(KEY_Z)


# --- Tests ---------------------------------------------------------------------

func test_combat_formulas() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([lord, brig])
	lord.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(6, 2))
	var f := Combat.forecast(lord, brig, b.map)
	# Lord: STR 5 + Iron Sword 5 + triangle 1 - DEF 3 = 8; doubles (AS 9 vs -1).
	check_eq(f.atk.dmg, 8, "lord damage")
	check_eq(f.atk.hit, 100, "lord hit")
	check_eq(f.atk.triangle, 1, "lord triangle")
	check(f.atk.double, "lord should double")
	# Brigand: STR 5 + Iron Axe 8 - 1 - DEF 4 = 8; hit 75 + 2 - 15 - avoid 25 = 37.
	check_eq(f.def.dmg, 8, "brigand damage")
	check_eq(f.def.hit, 37, "brigand hit")
	check(f.can_counter, "brigand should counter at range 1")


func test_true_hit_distribution() -> void:
	var hits := 0
	for i in 20000:
		if Combat.roll_hit(80):
			hits += 1
	var rate := hits / 200.0
	check(rate > 89.0 and rate < 95.0, "displayed 80%% should land ~92%%, got %.1f%%" % rate)
	check(Combat.roll_hit(100), "100% must always hit")
	check(not Combat.roll_hit(0), "0% must never hit")


func test_bow_and_thrown_ranges() -> void:
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([archer, brig])
	archer.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(6, 2))
	check(not archer.can_attack_at(1), "bow can't hit at range 1")
	check(not Combat.can_counter(brig, archer), "archer can't counter adjacent")
	brig.set_cell(Vector2i(7, 2))
	check(not Combat.can_counter(archer, brig), "Iron Axe can't counter at range 2")
	brig.equip(brig.items.find(brig.items.filter(func(w): return w.name == "Hatchet")[0]))
	check(Combat.can_counter(archer, brig), "Hatchet counters at range 2")
	check_eq(Combat.triangle(archer, brig), 1, "bow wins the triangle at range")
	check_eq(Combat.triangle(brig, archer), -1, "thrown axe loses to bow at range")


func test_weapon_break_ends_strikes() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([lord, brig])
	lord.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(6, 2))
	lord.items[0].uses = 1
	await b.do_combat(lord, brig)
	check_eq(lord.weapon.get("name", ""), "Knife", "next weapon equipped after break")
	check_eq(lord.weapon.get("uses", 0), 30, "no follow-up strike with the new weapon")
	check_eq(lord.items.size(), 1, "broken weapon removed")


func test_exp_formula_and_level_up() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	check_eq(Experience.combat_exp(lord, brig, true, false), 10, "hit EXP vs Lv2")
	check_eq(Experience.combat_exp(lord, brig, true, true), 33, "kill EXP vs Lv2")
	check_eq(Experience.combat_exp(lord, brig, false, false), 1, "no-damage EXP")
	lord.exp_points = 95
	await b.gain_exp(lord, 33)
	check_eq(lord.level, 2, "level after 128 EXP")
	check_eq(lord.exp_points, 28, "leftover EXP")


func test_cancel_move_restores_unit() -> void:
	var lord := unit_named("Lord")
	b.cursor.cell = lord.cell
	var start := lord.cell
	await press(KEY_Z)
	check_eq(b.state, b.State.SELECTED, "Z selects")
	await press(KEY_DOWN)
	await press(KEY_Z)
	check_eq(b.state, b.State.MENU, "moving opens the menu")
	check(lord.cell != start, "unit moved")
	await press(KEY_X)
	check_eq(lord.cell, start, "X undoes the move")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X again deselects")


func test_heal_spell() -> void:
	var cleric := unit_named("Cleric")
	var lord := unit_named("Lord")
	clear_board([cleric, lord])
	cleric.set_cell(Vector2i(4, 2))
	lord.set_cell(Vector2i(5, 2))
	lord.hp = 6
	b.cursor.cell = cleric.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Magic")
	await pick("Heal  4MP")
	await press(KEY_Z)
	check_eq(lord.hp, 18, "healed MAG 5 + 10, capped at max HP")
	check_eq(cleric.mp, 8, "Heal costs 4 MP")
	check_eq(cleric.exp_points, 11, "Heal gives 11 EXP")
	check(cleric.has_acted, "casting ends the turn")


func test_fire_forecast_and_counter() -> void:
	var mage := unit_named("Mage")
	var sold := unit_named("Soldier", Unit.Team.ENEMY)
	clear_board([mage, sold])
	mage.set_cell(Vector2i(5, 2))
	sold.set_cell(Vector2i(7, 2))
	var fire := Spells.get_spell("Fire")
	var f := Combat.spell_forecast(mage, sold, fire, b.map)
	check_eq(f.atk.dmg, 10, "Fire damage: MAG 6 + 5 - RES 1")
	check(not f.can_counter, "Iron Lance can't counter at range 2")
	sold.equip(1)
	f = Combat.spell_forecast(mage, sold, fire, b.map)
	check(f.can_counter, "Javelin counters at range 2")
	await b.do_spell_attack(mage, sold, "Fire")
	check_eq(mage.mp, 11, "Fire costs 3 MP")


func test_firestorm_targets_and_cast() -> void:
	var mage := unit_named("Mage")
	var sold := unit_named("Soldier", Unit.Team.ENEMY)
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var thief := unit_named("Thief", Unit.Team.ENEMY)
	clear_board([mage, sold, brig, thief])
	mage.set_cell(Vector2i(5, 2))
	sold.set_cell(Vector2i(7, 2))
	brig.set_cell(Vector2i(8, 2))
	thief.set_cell(Vector2i(8, 3))
	check_eq(Spells.area_targets(mage, "Firestorm", Vector2i(8, 2), b.units(), b.map).size(), 3, "blast hits 3")
	var centers := Spells.area_centers(mage, "Firestorm", b.map, b.units())
	check(not centers.has(Vector2i(9, 2)), "center beyond range 3 not allowed")
	await b.cast_area(mage, Vector2i(8, 2), "Firestorm")
	check_eq(mage.mp, 6, "Firestorm costs 8 MP")
	check(mage.exp_points >= 3, "EXP awarded per target")


func test_earth_spike_raises_mountain() -> void:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var knight := unit_named("Knight")
	clear_board([lord, brig, knight])
	lord.set_cell(Vector2i(1, 4))
	knight.set_cell(Vector2i(2, 6))
	brig.set_cell(Vector2i(3, 4))
	var centers := Spells.area_centers(lord, "Earth Spike", b.map, b.units())
	check(not centers.has(Vector2i(2, 4)), "can't target an existing mountain")
	check(centers.has(Vector2i(3, 4)), "can target an enemy's tile")
	await b.cast_area(lord, Vector2i(3, 4), "Earth Spike")
	check_eq(b.map.terrain_key(Vector2i(3, 4)), "M", "tile became a mountain")
	check_eq(lord.mp, 3, "Earth Spike costs 5 MP")
	check(b.map.get_reachable(brig, b.units()).cells.size() > 1, "unit on the mountain can still leave")
	check(not b.map.get_reachable(knight, b.units()).cells.has(Vector2i(3, 4)), "nobody can enter the mountain")


func test_dance_refreshes_ally() -> void:
	var dancer := unit_named("Dancer")
	var knight := unit_named("Knight")
	clear_board([dancer, knight])
	knight.set_cell(Vector2i(4, 6))
	dancer.set_cell(Vector2i(3, 6))
	knight.has_acted = true
	b.cursor.cell = dancer.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Dance")
	await press(KEY_Z)
	check(not knight.has_acted, "danced ally can act again")
	check(dancer.has_acted, "dancer's turn ends")
	check_eq(dancer.exp_points, Experience.DANCE_EXP, "Dance EXP")


func test_enemy_mage_uses_firestorm_on_cluster() -> void:
	var e_mage := unit_named("Mage", Unit.Team.ENEMY)
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	var fighter := unit_named("Fighter")
	clear_board([e_mage, knight, archer, fighter])
	knight.set_cell(Vector2i(4, 6))
	archer.set_cell(Vector2i(5, 6))
	fighter.set_cell(Vector2i(4, 7))
	e_mage.set_cell(Vector2i(10, 6))
	await EnemyAI.take_turn(e_mage, b)
	check_eq(e_mage.mp, 4, "enemy Mage spent 8 MP on Firestorm")


func test_enemy_phases_run_without_errors() -> void:
	for turn in 3:
		if b.state == b.State.GAME_OVER:
			break
		b.end_player_phase()
		while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
			await process_frame
	check(b.state == b.State.IDLE or b.state == b.State.GAME_OVER, "battle loop settles")
