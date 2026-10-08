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
		"test_potion_heals_and_ends_turn",
		"test_equipped_weapon_skips_items",
		"test_trade_swap_and_give",
		"test_trade_repeatable_and_keeps_action",
		"test_enemy_mage_uses_firestorm_on_cluster",
		"test_danger_zone_toggle_and_coverage",
		"test_hover_and_mark_enemy",
		"test_hover_own_units",
		"test_shove_pushes_ally",
		"test_shove_blocked_cases",
		"test_ai_profiles_resolve",
		"test_ai_hold_attacks_only_from_its_tile",
		"test_ai_in_range_waits_until_reachable",
		"test_ai_guard_stays_in_area",
		"test_ai_wake_conditions",
		"test_ai_retreat_to_healer_then_fort",
		"test_ai_targeting_weakest_and_priority",
		"test_ai_goto_without_attacking",
		"test_fort_heal_and_boss_threat",
		"test_ai_enemy_killed_by_counter_on_its_turn",
		"test_all_levels_are_valid",
		"test_level_select_loads_coastal_raid",
		"test_move_type_costs",
		"test_flying_gets_no_terrain_bonus",
		"test_arrow_follows_cursor_trail",
		"test_status_screen",
		"test_mp_bar_grays_when_no_spell_affordable",
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
	check(lord.items.all(func(i): return i.name != "Iron Sword"), "broken weapon removed")


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
	check_eq(lord.hp, 18, "healed INT 5 + 10, capped at max HP")
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
	check_eq(f.atk.dmg, 10, "Fire damage: INT 6 + 5 - MP 1")
	sold.mp = 0
	check_eq(Combat.spell_damage(mage, sold, fire, b.map), 11, "current MP is magic defense")
	sold.mp = 1
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
	brig.max_hp = 99  # survives even a crit, so it's still there to check afterwards
	brig.hp = 99
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


func test_potion_heals_and_ends_turn() -> void:
	var lord := unit_named("Lord")
	clear_board([lord])
	lord.set_cell(Vector2i(4, 2))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Items")
	await pick("Potion  3")
	check(not lord.has_acted, "Potion at full HP is refused")
	check_eq(b.state, b.State.MENU, "still in the items menu")
	await press(KEY_X)
	await press(KEY_X)
	await press(KEY_X)
	lord.hp = 2
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Items")
	await pick("Potion  3")
	check_eq(lord.hp, 17, "Potion heals 15")
	check(lord.has_acted, "using an item ends the turn")
	var potion: Dictionary = lord.items.filter(func(i): return i.name == "Potion")[0]
	check_eq(potion.uses, 2, "one use spent")
	potion.uses = 1
	lord.hp = 2
	lord.use_item(lord.items.find(potion))
	check(lord.items.all(func(i): return i.name != "Potion"), "empty Potion removed")


func test_equipped_weapon_skips_items() -> void:
	var lord := unit_named("Lord")
	var potion := Items.make("Potion")
	lord.items.push_front(potion)
	check_eq(lord.weapon.name, "Iron Sword", "equipped = first weapon, not first item")
	lord.equip(0)
	check(lord.items[0] == potion, "equip() ignores consumables")
	check_eq(lord.weapon_ranges().size(), 2, "ranges come from weapons only")


func test_trade_swap_and_give() -> void:
	var lord := unit_named("Lord")
	var dancer := unit_named("Dancer")
	clear_board([lord, dancer])
	lord.set_cell(Vector2i(4, 2))
	dancer.set_cell(Vector2i(5, 2))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Trade")
	check_eq(b.state, b.State.TARGETING, "choosing a trade partner")
	await press(KEY_Z)
	check_eq(b.state, b.State.TRADE, "trade screen open")
	# Lord: Iron Sword, Knife, Potion. Dancer: Potion.
	# Give the Knife (slot 1) to the Dancer's empty slot 1.
	await press(KEY_DOWN)
	await press(KEY_Z)
	check_eq(b.trade_cursor, Vector2i(1, 1), "cursor jumps to the same row on the partner's side")
	await press(KEY_Z)
	check_eq(dancer.items.map(func(i): return i.name), ["Potion", "Knife"], "Knife handed over")
	check_eq(lord.items.map(func(i): return i.name), ["Iron Sword", "Potion"], "Lord lost the Knife")
	# Swap the Dancer's Potion (right slot 0) with the Lord's Iron Sword (left slot 0).
	await press(KEY_UP)
	await press(KEY_Z)
	check_eq(b.trade_cursor, Vector2i(0, 0), "cursor jumps back to the Lord's row 0")
	await press(KEY_Z)
	check_eq(lord.items.map(func(i): return i.name), ["Potion", "Potion"], "swap: Lord")
	check_eq(dancer.items.map(func(i): return i.name), ["Iron Sword", "Knife"], "swap: Dancer")
	check(lord.weapon.is_empty(), "Lord is now unarmed")
	await press(KEY_X)
	check_eq(b.state, b.State.MENU, "leaving the trade screen returns to the unit menu")
	check(not b.ui.menu_options.has("Attack"), "unarmed Lord has no Attack")


func test_trade_repeatable_and_keeps_action() -> void:
	var lord := unit_named("Lord")
	var knight := unit_named("Knight")
	var dancer := unit_named("Dancer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([lord, knight, dancer, brig])
	lord.set_cell(Vector2i(4, 2))
	knight.set_cell(Vector2i(4, 3))
	dancer.set_cell(Vector2i(4, 1))
	brig.set_cell(Vector2i(5, 2))
	knight.has_acted = true
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_RIGHT)
	await press(KEY_LEFT)
	await press(KEY_Z)
	for partner in [knight, dancer, knight]:
		await pick("Trade")
		while b.targets[b.target_index] != partner:
			await press(KEY_RIGHT)
		await press(KEY_Z)
		# Give the Lord's last item to the partner (or swap if full).
		await press(KEY_Z)
		await press(KEY_Z)
		await press(KEY_X)
		check_eq(b.state, b.State.MENU, "back in the unit menu after trading with " + partner.unit_name)
		check(not lord.has_acted, "trading doesn't use the action")
	check(knight.has_acted, "trading doesn't refresh an ally that already acted")
	var cell := lord.cell
	await press(KEY_X)
	check_eq(lord.cell, cell, "after a trade, cancel no longer undoes the move")
	check_eq(b.state, b.State.MENU, "cancel keeps the unit menu open")
	await pick("Attack")
	check_eq(b.state, b.State.MENU, "can still attack after trading")


func test_enemy_mage_uses_firestorm_on_cluster() -> void:
	var e_mage := unit_named("Mage", Unit.Team.ENEMY)
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	var fighter := unit_named("Fighter")
	# isolate, not clear_board: parked units (e.g. the Dancer, on this Mage's
	# priority list) would otherwise be tempting single targets.
	isolate([e_mage, knight, archer, fighter])
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


func test_danger_zone_toggle_and_coverage() -> void:
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var e_mage := unit_named("Mage", Unit.Team.ENEMY)
	clear_board([brig])
	brig.set_cell(Vector2i(10, 2))
	check(b.map.danger_cells.is_empty(), "danger zone starts hidden")
	await press(KEY_C)
	check(b.danger_on, "C toggles the danger zone on")
	# Brigand: MOV 5 plus a Hatchet (range 1-2) reaches 7 tiles out along row 2.
	check(b.map.danger_cells.has(Vector2i(3, 2)), "cell 7 tiles from the Brigand is threatened")
	check(not b.map.danger_cells.has(Vector2i(0, 0)), "far corner is safe")
	# Enemy spells only count while the caster can afford them.
	e_mage.mp = 0
	check(b.offense_ranges(e_mage, true).is_empty(), "Mage with 0 MP threatens nothing")
	await press(KEY_C)
	check(b.map.danger_cells.is_empty(), "C again hides it")


func test_hover_and_mark_enemy() -> void:
	var sold := unit_named("Soldier", Unit.Team.ENEMY)
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([sold, brig])
	sold.set_cell(Vector2i(10, 4))
	brig.set_cell(Vector2i(10, 8))
	b.cursor.cell = Vector2i(9, 4)
	await press(KEY_RIGHT)
	check(b.hovered == sold, "hovering an enemy tracks it")
	check(not b.map.move_cells.is_empty() and not b.map.attack_cells.is_empty(), "hover shows its ranges")
	await press(KEY_LEFT)
	check(b.hovered == null and b.map.move_cells.is_empty(), "moving off clears the ranges")
	await press(KEY_RIGHT)
	await press(KEY_Z)
	check(b.marked.has(sold), "Z marks the enemy")
	check_eq(b.map.marked_cells, b.enemy_threat(sold), "red overlay is the enemy's threat")
	check_eq(b.state, b.State.IDLE, "marking keeps browsing")
	await press(KEY_LEFT)
	check(not b.map.marked_cells.is_empty(), "red overlay stays after moving away")
	# A second mark adds to the overlay.
	b.cursor.cell = Vector2i(9, 8)
	await press(KEY_RIGHT)
	await press(KEY_Z)
	var both: Dictionary = b.enemy_threat(sold)
	both.merge(b.enemy_threat(brig))
	check_eq(b.map.marked_cells, both, "overlay covers every marked enemy")
	# Z again unmarks; a dead enemy's mark is dropped.
	await press(KEY_Z)
	check(not b.marked.has(brig), "Z again unmarks")
	sold.hp = 0
	b.refresh_threat()
	check(b.marked.is_empty() and b.map.marked_cells.is_empty(), "dead enemy's mark is removed")


func test_arrow_follows_cursor_trail() -> void:
	var lord := unit_named("Lord")
	clear_board([lord])
	lord.set_cell(Vector2i(4, 2))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	for k in [KEY_RIGHT, KEY_DOWN, KEY_RIGHT, KEY_UP]:
		await press(k)
	var trail: Array[Vector2i] = [Vector2i(4, 2), Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 3), Vector2i(6, 2)]
	check_eq(b.map.arrow_path, trail, "arrow follows the cursor's detour")
	await press(KEY_DOWN)
	check_eq(b.map.arrow_path, trail.slice(0, 4), "backtracking shortens the arrow")
	await press(KEY_UP)
	# (9, 2) is exactly MOV 5 away; (10, 2) is out of range.
	for i in 4:
		await press(KEY_RIGHT)
	check(b.map.arrow_path.is_empty(), "arrow hides when the cursor leaves the move range")
	await press(KEY_LEFT)
	check_eq(b.map.arrow_path.size(), 6, "back in range: shortest path to (9, 2)")
	await press(KEY_Z)
	check_eq(lord.cell, Vector2i(9, 2), "unit moves to the arrow's end")
	check_eq(b.state, b.State.MENU, "then the action menu opens")


func test_status_screen() -> void:
	var lord := unit_named("Lord")
	b.cursor.cell = lord.cell
	await press(KEY_R)
	check_eq(b.state, b.State.STATUS, "R opens the stats screen")
	check(b.ui._status.visible, "stats screen visible")
	check(b.ui._status_title.text.begins_with("Lord"), "shows the unit under the cursor")
	check(b.ui._status_items.text.contains("E Iron Sword"), "equipped weapon is marked")
	check(b.ui._status_items.text.contains("Earth Spike"), "spells are listed")
	var atk_value: Label = b.ui._status_combat.get_child(1)
	check_eq(atk_value.text, str(Combat.base_attack(lord)), "Atk matches the combat formula")
	await press(KEY_DOWN)
	check(b.status_unit != lord and b.status_unit.team == Unit.Team.PLAYER, "Down shows the next ally")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X closes it")
	check(not b.ui._status.visible, "stats screen hidden")


func test_mp_bar_grays_when_no_spell_affordable() -> void:
	var lord := unit_named("Lord")
	var mage := unit_named("Mage")
	check(lord.can_cast_any(), "Lord with 8 MP can cast Earth Spike (5)")
	lord.mp = 4
	check(not lord.can_cast_any(), "Lord with 4 MP can't cast anything: bar goes gray")
	mage.mp = 3
	check(mage.can_cast_any(), "Mage with 3 MP can still cast Fire (3)")
	mage.mp = 2
	check(not mage.can_cast_any(), "Mage with 2 MP can't cast anything")


func test_hover_own_units() -> void:
	var lord := unit_named("Lord")
	var cleric := unit_named("Cleric")
	b.cursor.cell = lord.cell + Vector2i.UP
	await press(KEY_DOWN)
	check(b.hovered == lord, "hovering your own unit tracks it")
	var lord_reach: Dictionary = b.map.get_reachable(lord, b.units())
	check_eq(b.map.move_cells.size(), lord_reach.cells.size(), "hover shows its move range")
	check(not b.map.attack_cells.is_empty(), "and its attack range")
	# Units that already acted still show their ranges.
	lord.has_acted = true
	await press(KEY_UP)
	await press(KEY_DOWN)
	check(not b.map.move_cells.is_empty(), "acted units show ranges too")
	lord.has_acted = false
	# Healers show their support range (green).
	b.cursor.cell = cleric.cell + Vector2i.UP
	await press(KEY_DOWN)
	check(not b.map.support_cells.is_empty(), "Cleric hover shows heal range")
	# Z on your own unit still selects it rather than marking.
	await press(KEY_Z)
	check_eq(b.state, b.State.SELECTED, "Z selects your unit")
	check(b.marked.is_empty(), "own units are never marked")


func test_shove_pushes_ally() -> void:
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	clear_board([knight, fighter])
	knight.set_cell(Vector2i(4, 6))
	fighter.set_cell(Vector2i(5, 6))
	b.cursor.cell = knight.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Shove")
	check_eq(b.state, b.State.TARGETING, "Shove asks for a target")
	check_eq(b.map.area_cells, [Vector2i(6, 6)], "landing cell is previewed")
	check(b.ui._spell_label.text.contains("Fighter"), "preview names the target")
	await press(KEY_Z)
	check_eq(fighter.cell, Vector2i(6, 6), "ally pushed one cell away")
	check_eq(knight.cell, Vector2i(4, 6), "shover stays put")
	check(knight.has_acted, "shoving ends the shover's turn")
	check(not fighter.has_acted, "the shoved ally can still act")
	check_eq(b.state, b.State.IDLE, "back to browsing")


func test_shove_blocked_cases() -> void:
	var lord := unit_named("Lord")
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([lord, knight, archer, brig])
	# Into a mountain: Knight at (3, 4) pushed toward (2, 4).
	lord.set_cell(Vector2i(4, 4))
	knight.set_cell(Vector2i(3, 4))
	check(not b.can_shove(lord, knight), "can't shove into a mountain")
	# Into a river: (7, 5) is water.
	lord.set_cell(Vector2i(5, 5))
	knight.set_cell(Vector2i(6, 5))
	check(not b.can_shove(lord, knight), "can't shove into a river")
	# Into another unit.
	lord.set_cell(Vector2i(4, 2))
	knight.set_cell(Vector2i(5, 2))
	archer.set_cell(Vector2i(6, 2))
	check(not b.can_shove(lord, knight), "can't shove into an occupied cell")
	# Enemies can't be shoved; neither can non-adjacent allies.
	brig.set_cell(Vector2i(4, 3))
	check(not b.can_shove(lord, brig), "enemies can't be shoved")
	archer.set_cell(Vector2i(4, 0))
	check(not b.can_shove(lord, archer), "ally must be adjacent")
	# Off a raised mountain is fine.
	b.map.set_terrain(Vector2i(4, 3), "M")
	brig.set_cell(Vector2i(10, 9))
	knight.set_cell(Vector2i(4, 3))
	lord.set_cell(Vector2i(4, 4))
	check(b.can_shove(lord, knight), "a unit standing on a mountain can be shoved off it")
	check_eq(b.shove_targets(lord), [knight], "shove_targets lists only valid allies")


# --- Enemy behaviors ---------------------------------------------------------------

## Removes every unit except `keep`, so AI tests only see the units they set up.
func isolate(keep: Array) -> void:
	for u in b.units():
		if not keep.has(u):
			u.get_parent().remove_child(u)
			u.queue_free()


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
	await b.heal_on_tiles(Unit.Team.ENEMY)
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
	await b.heal_on_tiles(Unit.Team.PLAYER)
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


# --- Levels and movement types -------------------------------------------------------

func test_all_levels_are_valid() -> void:
	for id in Levels.ORDER:
		var level := Levels.get_level(id)
		var layout: Array = level.layout
		for row in layout:
			check_eq(row.length(), layout[0].length(), "%s: rows have equal length" % id)
			for key in row:
				check(BattleMap.TERRAIN.has(key), "%s: unknown terrain '%s'" % [id, key])
		var taken := {}
		for data in level.players + level.enemies:
			var cell: Vector2i = data.cell
			var move_type: String = data.get("move", "foot")
			var key: String = layout[cell.y][cell.x]
			check(BattleMap.MOVE_COSTS[move_type][key] >= 0,
				"%s: %s (%s) can stand on its start tile '%s'" % [id, data.name, move_type, key])
			check(not taken.has(cell), "%s: %s shares a start tile" % [id, data.name])
			taken[cell] = true


func test_level_select_loads_coastal_raid() -> void:
	Levels.selected = "coastal_raid"
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"  # restore before any check can bail out
	check_eq(b.map.terrain_key(Vector2i(13, 4)), "T", "island fort loaded")
	var pegasus := unit_named("Pegasus")
	var siren := unit_named("Siren")
	var lord := unit_named("Lord")
	check(pegasus != null and pegasus.move_type == "flying", "roster loaded with move types")
	# The island is out of reach on foot, but not for fliers and mermaids.
	check(not b.map.cost_field(Vector2i(13, 4), "foot").has(lord.cell), "foot units can't reach the island")
	check(b.map.cost_field(Vector2i(13, 4), "flying").has(pegasus.cell), "fliers can")
	check(b.map.cost_field(Vector2i(12, 5), "mermaid").has(siren.cell), "mermaids can (via the river mouth)")


func test_move_type_costs() -> void:
	var fighter := unit_named("Fighter")
	isolate([fighter])
	var m: BattleMap = b.map
	check_eq(m.move_cost(Vector2i(4, 0), "foot"), 2, "foot: forest 2")
	check_eq(m.move_cost(Vector2i(4, 0), "horse"), 3, "horse: forest 3")
	check_eq(m.move_cost(Vector2i(4, 0), "rogue"), 1, "rogue: forest 1")
	check_eq(m.move_cost(Vector2i(7, 0), "flying"), 1, "flying: river 1")
	check_eq(m.move_cost(Vector2i(2, 3), "flying"), 1, "flying: mountain 1")
	check_eq(m.move_cost(Vector2i(0, 0), "ship"), -1, "ship: no land")
	check_eq(m.move_cost(Vector2i(7, 0), "ship"), 1, "ship: river 1")
	check_eq(m.move_cost(Vector2i(0, 0), "mermaid"), 2, "mermaid: plain 2")
	check_eq(m.move_cost(Vector2i(7, 0), "mermaid"), 1, "mermaid: river 1")
	# Reachability follows the unit's type: (8, 4) is across the river from (6, 4).
	fighter.set_cell(Vector2i(6, 4))
	fighter.mov = 2
	check(not m.get_reachable(fighter, b.units()).cells.has(Vector2i(8, 4)), "foot can't cross the river")
	fighter.move_type = "flying"
	check(m.get_reachable(fighter, b.units()).cells.has(Vector2i(8, 4)), "flier crosses it")
	fighter.move_type = "ship"
	fighter.set_cell(Vector2i(7, 4))
	var ship_cells: Dictionary = m.get_reachable(fighter, b.units()).cells
	check(ship_cells.keys().all(func(c): return m.terrain_key(c) == "~"), "ship stays on water")


func test_flying_gets_no_terrain_bonus() -> void:
	var fighter := unit_named("Fighter")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([fighter, brig])
	brig.set_cell(Vector2i(4, 0))  # forest: DEF +1, AVO +20
	fighter.set_cell(Vector2i(3, 0))
	var grounded := Combat.damage(fighter, brig, b.map)
	var grounded_hit := Combat.hit_chance(fighter, brig, b.map)
	brig.move_type = "flying"
	check_eq(Combat.damage(fighter, brig, b.map), grounded + 1, "flier loses the forest's DEF +1")
	check(Combat.hit_chance(fighter, brig, b.map) > grounded_hit, "and its avoid bonus")
