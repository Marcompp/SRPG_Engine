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
	# Never touch a real suspend file.
	SaveGame.path = "user://test_suspend.save"
	SaveGame.delete_suspend()
	# ...or real settings: tests run with the defaults.
	Settings.path = "user://test_settings.cfg"
	DirAccess.remove_absolute(Settings.path)
	Settings.reload()
	# ...or a real campaign.
	Campaign.path = "user://test_campaign.save"
	Campaign.delete_save()
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
		"test_ether_restores_mp",
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
		"test_mounted_units_cannot_shove",
		"test_rescue_rules",
		"test_rescue_and_drop_ferry",
		"test_fallen_carrier_drops_passenger",
		"test_class_data_is_consistent",
		"test_class_weapon_restrictions",
		"test_swim_and_climb_costs",
		"test_inspire_buffs_adjacent_allies",
		"test_ship_board_and_unload",
		"test_sunk_ship_sets_passengers_ashore",
		"test_arrow_follows_cursor_trail",
		"test_status_screen",
		"test_status_screen_detail_mode",
		"test_stat_caps",
		"test_mp_bar_grays_when_no_spell_affordable",
		"test_jump_to_next_unit",
		"test_fast_forward_enemy_phase",
		"test_level_up_waits_for_confirm",
		"test_end_turn_warning",
		"test_effectiveness_triples_might",
		"test_spirits_resist_non_silver_weapons",
		"test_forecast_shows_effectiveness",
		"test_ai_prefers_effective_weapon",
		"test_race_class_bans",
		"test_race_movement_and_tags",
		"test_race_weaknesses_and_resistances",
		"test_race_spell_elements",
		"test_race_carry_and_shove",
		"test_race_regen_and_exp",
		"test_info_panel_terrain_bonus",
		"test_unit_list",
		"test_objective_screen",
		"test_suspend_round_trip",
		"test_level_select_offers_resume",
		"test_suspend_discarded_when_map_ends",
		"test_restart_asks_first",
		"test_options_screen_saves",
		"test_option_danger_zone_at_start",
		"test_option_auto_end_turn_off",
		"test_option_level_up_auto",
		"test_level_select_has_options",
		"test_all_chapters_are_valid",
		"test_seize_objective",
		"test_boss_objective",
		"test_defend_objective",
		"test_escape_objective",
		"test_villages_visit_and_loot",
		"test_chests",
		"test_reinforcements",
		"test_campaign_army_carries_over",
		"test_promotion",
		"test_prep_screen",
		"test_campaign_suspend_resume",
		"test_chapters_enemy_phases_run",
		"test_marked_enemy_freed",
		"test_quit_to_level_select_asks_first",
		"test_end_turn_last_and_warning_option",
		"test_break_wall_through_menu",
		"test_break_fence_and_trunk_bridge",
		"test_doors_open_or_break",
		"test_tile_hp_survives_suspend",
		"test_enemies_break_and_open_obstacles",
		"test_ruined_fort_phases_run_without_errors",
		"test_enemy_phases_run_without_errors",
		"test_coastal_raid_phases_run_without_errors",
	]
	for t in tests:
		current_test = t
		# Every test starts on the default test map, outside the campaign.
		Levels.selected = "river_crossing"
		Campaign.active = false
		Campaign.deployed = []
		await _fresh_battle()
		var before := failures.size()
		await call(t)
		print(("PASS  " if failures.size() == before else "FAIL  ") + t)
		b.queue_free()
		await process_frame
	SaveGame.delete_suspend()
	DirAccess.remove_absolute(Settings.path)
	Campaign.delete_save()
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
	# Nobody presses Z in tests: level-ups time out instead (see test_level_up_waits_for_confirm).
	b.get_node("UI").level_up_waits = false
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
	b.input._unhandled_input(e)
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
	await b.actions.do_combat(lord, brig)
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
	await b.actions.gain_exp(lord, 33)
	check_eq(lord.level, 2, "level after 95 + 36 EXP (33 x1.1 for Humans)")
	check_eq(lord.exp_points, 31, "leftover EXP")


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
	check_eq(cleric.exp_points, 12, "Heal gives 11 EXP, 12 for a Human")
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
	check(not f.can_counter, "Iron Spear can't counter at range 2")
	sold.equip(1)
	f = Combat.spell_forecast(mage, sold, fire, b.map)
	check(f.can_counter, "Javelin counters at range 2")
	await b.actions.do_spell_attack(mage, sold, "Fire")
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
	await b.actions.cast_area(mage, Vector2i(8, 2), "Firestorm")
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
	await b.actions.cast_area(lord, Vector2i(3, 4), "Earth Spike")
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
	check_eq(dancer.exp_points, roundi(Experience.DANCE_EXP * 1.1), "Dance EXP (Human x1.1)")


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


func test_ether_restores_mp() -> void:
	var mage := unit_named("Mage")
	clear_board([mage])
	mage.set_cell(Vector2i(4, 2))
	b.cursor.cell = mage.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Items")
	await pick("Ether  3")
	check(not mage.has_acted, "Ether at full MP is refused")
	await press(KEY_X)
	await press(KEY_X)
	await press(KEY_X)
	mage.mp = 1
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Items")
	await pick("Ether  3")
	check_eq(mage.mp, mini(16, mage.max_mp), "Ether restores 15 MP, capped at max")
	check(mage.has_acted, "using an Ether ends the turn")
	var ether: Dictionary = mage.items.filter(func(i): return i.name == "Ether")[0]
	check_eq(ether.uses, 2, "one use spent")


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
	check_eq(b.input.trade_cursor, Vector2i(1, 1), "cursor jumps to the same row on the partner's side")
	await press(KEY_Z)
	check_eq(dancer.items.map(func(i): return i.name), ["Potion", "Knife"], "Knife handed over")
	check_eq(lord.items.map(func(i): return i.name), ["Iron Sword", "Potion"], "Lord lost the Knife")
	# Swap the Dancer's Potion (right slot 0) with the Lord's Iron Sword (left slot 0).
	await press(KEY_UP)
	await press(KEY_Z)
	check_eq(b.input.trade_cursor, Vector2i(0, 0), "cursor jumps back to the Lord's row 0")
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
		while b.input.targets[b.input.target_index] != partner:
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
		b.phases.end_player_phase()
		while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
			await process_frame
	check(b.state == b.State.IDLE or b.state == b.State.GAME_OVER, "battle loop settles")


func test_coastal_raid_phases_run_without_errors() -> void:
	Levels.selected = "coastal_raid"
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"
	await test_enemy_phases_run_without_errors()


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
	var ranges: Array[Vector2i] = b.offense_ranges(e_mage, true)
	check(ranges.size() == 1 and ranges[0] == Vector2i(1, 1), "Mage with 0 MP only threatens with its staff")
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
	check(b.input.hovered == sold, "hovering an enemy tracks it")
	check(not b.map.move_cells.is_empty() and not b.map.attack_cells.is_empty(), "hover shows its ranges")
	await press(KEY_LEFT)
	check(b.input.hovered == null and b.map.move_cells.is_empty(), "moving off clears the ranges")
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
	var screen: StatusScreen = b.ui.status_screen
	b.cursor.cell = lord.cell
	await press(KEY_D)
	check_eq(b.state, b.State.STATUS, "D opens the status screen")
	check(screen.visible and screen.unit == lord, "shows the unit under the cursor")
	check_eq(screen.page, 0, "starts on the Stats page")
	var texts := _texts(screen)
	for expected in ["Lord", "Swordsman", "Human", "Lv 1", "Exp 0", "HP 18/18", "MP 8/8"]:
		check(texts.has(expected), "left column shows '%s'" % expected)
	# Pages: Right flips, Left flips back; the Items page lists weapons, numbers, spells.
	await press(KEY_RIGHT)
	check_eq(screen.page, 1, "Right: Items page")
	texts = _texts(screen)
	check(texts.has("E") and texts.has("Iron Sword"), "equipped weapon marked")
	check(texts.has(str(Combat.base_attack(lord))), "Atk from the combat formula")
	check(texts.has("Earth Spike"), "spells listed")
	await press(KEY_RIGHT)
	await press(KEY_RIGHT)
	check_eq(screen.page, 3, "players have a 4th page (Bio)")
	check(_texts(screen).any(func(t): return t.contains("river crossing")), "biography events shown")
	await press(KEY_RIGHT)
	check_eq(screen.page, 0, "pages wrap around")
	# Up/Down changes unit and keeps the page.
	await press(KEY_RIGHT)
	await press(KEY_DOWN)
	check(screen.unit != lord and screen.unit.team == Unit.Team.PLAYER, "Down shows the next ally")
	check_eq(screen.page, 1, "and stays on the same page")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X closes it")
	check(not screen.visible, "screen hidden")


func test_status_screen_detail_mode() -> void:
	var lord := unit_named("Lord")
	var screen: StatusScreen = b.ui.status_screen
	b.cursor.cell = lord.cell
	await press(KEY_D)
	await press(KEY_D)
	check(screen.detail, "D again enters detail mode")
	check_eq(screen.highlighted_text(), Glossary.stat("str", lord), "starts on the page's first entry (STR)")
	check(screen.highlighted_text().contains("Cap: 20"), "stat help mentions the cap")
	await press(KEY_DOWN)
	check_eq(screen.highlighted_text(), Glossary.stat("int", lord), "Down moves to the next entry")
	await press(KEY_LEFT)
	check_eq(screen.highlighted_text(), Glossary.unit_class(lord), "Left jumps to the left column (class)")
	await press(KEY_DOWN)
	check(screen.highlighted_text().begins_with("Human"), "then race")
	await press(KEY_D)
	check(not screen.detail and b.state == b.State.STATUS, "D leaves detail mode, screen stays open")
	await press(KEY_RIGHT)
	await press(KEY_D)
	check(screen.highlighted_text().begins_with("Iron Sword (Sword)"), "Items page: weapon details")
	await press(KEY_X)
	check(not screen.detail and b.state == b.State.STATUS, "X also leaves detail mode first")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "a second X closes the screen")
	# Enemies have no Bio page.
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	b.cursor.cell = brig.cell
	await press(KEY_D)
	check_eq(screen.page_count(), 3, "enemies: Stats, Items, Skills only")
	await press(KEY_X)


func test_stat_caps() -> void:
	var lord := unit_named("Lord")
	check_eq(lord.stat_cap("str"), 20, "default cap 20")
	check_eq(lord.stat_cap("hp"), 80, "HP cap 80")
	check_eq(lord.stat_cap("mp"), 40, "MP cap 40")
	lord.strength = 20
	check(lord.is_capped("str"), "STR 20 is capped")
	# A capped stat never grows, even at a 100% growth.
	lord.growths = {"str": 100, "dex": 100}
	for i in 20:
		var gains := Experience.roll_level_up(lord)
		check(not gains.has("str"), "capped STR doesn't roll")
	Experience.apply_level_up(lord, {"str": 1})
	check_eq(lord.strength, 20, "applying a gain never passes the cap")
	# The status screen draws capped stats in the glowing color.
	b.cursor.cell = lord.cell
	await press(KEY_D)
	var screen: StatusScreen = b.ui.status_screen
	check(not screen._glow.is_empty(), "capped stat glows")
	await press(KEY_X)


func _texts(screen: StatusScreen) -> Array:
	var result := []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label and node.is_visible_in_tree():
			result.append(node.text)
		stack.append_array(node.get_children())
	return result


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
	check(b.input.hovered == lord, "hovering your own unit tracks it")
	var lord_reach: Dictionary = b.map.get_reachable(lord, b.units())
	check_eq(b.map.move_cells.size(), lord_reach.cells.size(), "hover shows its move range")
	check(not b.map.attack_cells.is_empty(), "and its attack range")
	# Units that already acted still show their ranges.
	lord.has_acted = true
	await press(KEY_UP)
	await press(KEY_DOWN)
	check(not b.map.move_cells.is_empty(), "acted units show ranges too")
	lord.has_acted = false
	# Healers show their support range (green) where it reaches past their weapon
	# (red wins where both reach, and a staff covers Heal's range 1).
	cleric.items.clear()
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
	check(not b.actions.can_shove(lord, knight), "can't shove into a mountain")
	# Into a river: (7, 5) is water.
	lord.set_cell(Vector2i(5, 5))
	knight.set_cell(Vector2i(6, 5))
	check(not b.actions.can_shove(lord, knight), "can't shove into a river")
	# Into another unit.
	lord.set_cell(Vector2i(4, 2))
	knight.set_cell(Vector2i(5, 2))
	archer.set_cell(Vector2i(6, 2))
	check(not b.actions.can_shove(lord, knight), "can't shove into an occupied cell")
	# Enemies can't be shoved; neither can non-adjacent allies.
	brig.set_cell(Vector2i(4, 3))
	check(not b.actions.can_shove(lord, brig), "enemies can't be shoved")
	archer.set_cell(Vector2i(4, 0))
	check(not b.actions.can_shove(lord, archer), "ally must be adjacent")
	# Off a raised mountain is fine.
	b.map.set_terrain(Vector2i(4, 3), "M")
	brig.set_cell(Vector2i(10, 9))
	knight.set_cell(Vector2i(4, 3))
	lord.set_cell(Vector2i(4, 4))
	check(b.actions.can_shove(lord, knight), "a unit standing on a mountain can be shoved off it")
	check_eq(b.actions.shove_targets(lord), [knight], "shove_targets lists only valid allies")


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
			check(Classes.DATA.has(data.get("class", "")), "%s: %s has a known class" % [id, data.name])
			if not Classes.DATA.has(data.get("class", "")):
				continue
			var cls := Classes.get_data(data["class"])
			for item_name in data.get("items", []):
				if Weapons.DATA.has(item_name):
					check(cls.weapons.has(Weapons.DATA[item_name].type),
						"%s: %s (%s) can wield its %s" % [id, data.name, data["class"], item_name])
			var race: String = data.get("race", "Human")
			check(Races.DATA.has(race), "%s: %s has a known race" % [id, data.name])
			if not Races.DATA.has(race):
				continue
			check(Races.allows(race, data["class"]), "%s: %s can be a %s" % [id, race, data["class"]])
			var move_type := Races.move_type(race, data["class"])
			var key: String = layout[cell.y][cell.x]
			check(BattleMap.cost_for(key, move_type) >= 0,
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
	check(pegasus.is_mounted() and pegasus.unit_class == "Flier", "and classes")
	var galley: Unit = unit_named("Galley")
	check(galley != null and galley.is_ship(), "player Galley is a ship")
	# The island is out of reach on foot (sea costs 6 > MOV 5), but not for fliers and mermaids.
	check(b.map.move_cost(Vector2i(11, 4), "foot") > lord.mov, "foot units can never step into the sea")
	check(b.map.cost_field(Vector2i(13, 4), "flying").has(pegasus.cell), "fliers can")
	check(b.map.cost_field(Vector2i(12, 5), "mermaid").has(siren.cell), "mermaids can (via the river mouth)")


func test_move_type_costs() -> void:
	var fighter := unit_named("Fighter")
	isolate([fighter])
	var m: BattleMap = b.map
	# The full terrain spec: MOV cost per move type, in this column order.
	var types := ["foot", "heavy", "horse", "rogue", "climb", "swim", "mermaid", "ship", "flying", "spirit"]
	var x := -1.0
	var spec := {
		".": [1, 1, 1, 1, 1, 1, 3, 6, 1, 1],
		"=": [0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 1.5, 5, 1, 1],
		"H": [1, 1, 1.2, 1, 1, 1, 1, 10, 1, 1],
		"T": [1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1, 1],
		"S": [1, 1, 1.5, 1, 1, 1, 2, 5, 1, 1],
		"D": [1.5, 1.5, 3, 1.5, 1.5, 1.5, 2, 4, 1, 1],
		"F": [2, 2, 4, 1.5, 2, 2, 3, 10, 1, 1],
		"#": [10, 10, 20, 6, 10, 10, 10, 20, 1, 1],
		"h": [4, 10, 10, 4, 2, 4, 10, 20, 1, 1],
		"M": [7, 15, 15, 7, 4, 7, 15, 20, 1, 1],
		"~": [6, 8, 8, 6, 6, 2, 1, 1, 1, 1],
		"L": [6, 8, 8, 6, 6, 2, 1, 1, 1, 1],
		"W": [6, 8, 8, 6, 6, 2, 1, 1, 1, 1],
		"v": [20, 20, 20, 20, 20, 6, 6, 8, 1, 1],
		"*": [1, 1, 1.5, 1, 1, 1, 2, 5, 1, 1],
		"i": [1.5, 1, 2, 1.5, 1.5, 1.5, 1, 4, 1, 1],
		"_": [1, 1, 1.5, 1, 1, 1, 3, 10, 1.5, 1],
		"c": [1, 1, 1.5, 1, 1, 1, 3, 10, 1.5, 1],
		"X": [x, x, x, x, x, x, x, x, x, 1],
		"I": [2, 2, 2, 2, 2, 2, 2, 20, 1, 1],
		"O": [x, x, x, x, x, x, x, x, 1, 1],
		"|": [x, x, x, x, x, x, x, x, 1, 1],
		"x": [x, x, x, x, x, x, x, x, x, 1],
		"/": [x, x, x, x, x, x, x, x, 1, 1],
		"Y": [x, x, x, x, x, x, x, x, 1, 1],
		"+": [x, x, x, x, x, x, x, x, x, 1],
		"B": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	}
	check_eq(spec.size(), BattleMap.TERRAIN.size(), "every terrain is covered by the spec")
	for key in spec:
		for i in types.size():
			var got := BattleMap.cost_for(key, types[i])
			check(is_equal_approx(got, float(spec[key][i])),
				"%s (%s) for %s: expected %s, got %s" % [BattleMap.TERRAIN[key].name, key, types[i], spec[key][i], got])
	# Only fliers and spirits ignore terrain bonuses.
	check_eq(BattleMap.NO_TERRAIN_BONUS, ["flying", "spirit"], "fliers and spirits get no terrain bonuses")
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


# --- Mounted units: no Shove, Rescue/Drop ------------------------------------------------

func test_mounted_units_cannot_shove() -> void:
	var fighter := unit_named("Fighter")
	var knight := unit_named("Knight")
	isolate([fighter, knight])
	fighter.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	check(b.actions.can_shove(fighter, knight), "two foot units can shove")
	fighter.set_class("Cavalry")
	check(not b.actions.can_shove(fighter, knight), "a mounted unit can't shove")
	check(not b.actions.can_shove(knight, fighter), "a mounted unit can't be shoved")
	knight.set_class("Flier")
	fighter.set_class("Axeman")
	check(not b.actions.can_shove(fighter, knight), "Fliers are mounted")
	knight.set_race("Harpy")
	knight.set_class("Archer")
	check(knight.move_type == "flying" and b.actions.can_shove(fighter, knight),
		"Harpies fly but aren't mounted, so they can be shoved")


func test_rescue_rules() -> void:
	var fighter := unit_named("Fighter")
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	isolate([fighter, knight, archer])
	fighter.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	archer.set_cell(Vector2i(3, 6))
	check(b.actions.rescue_targets(fighter).is_empty(), "foot units can't rescue")
	fighter.set_class("Cavalry")
	check_eq(b.actions.rescue_targets(fighter).size(), 2, "a mounted unit can rescue adjacent foot allies")
	archer.set_class("Flier")
	check_eq(b.actions.rescue_targets(fighter), [knight], "mounted allies can't be rescued")
	archer.set_race("Harpy")
	archer.set_class("Archer")
	check(b.actions.rescue_targets(fighter).has(archer), "unmounted fliers (Harpy) can be rescued")
	archer.set_class("Galley")
	check(not b.actions.rescue_targets(fighter).has(archer), "ships can't be rescued")


func test_rescue_and_drop_ferry() -> void:
	var fighter := unit_named("Fighter")
	var lord := unit_named("Lord")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	# An idle Archer keeps the player phase open; the Brigand avoids an instant Victory.
	isolate([fighter, lord, archer, brig])
	archer.set_cell(Vector2i(0, 0))
	brig.set_cell(Vector2i(14, 9))
	fighter.set_class("Cavalry")
	fighter.mov = 7
	fighter.set_cell(Vector2i(4, 6))
	lord.set_cell(Vector2i(5, 6))
	var as_before := Combat.attack_speed(fighter)
	# Rescue: select the Fighter, stay in place, Rescue the Lord.
	b.cursor.cell = fighter.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Rescue")
	check_eq(b.map.area_cells, [lord.cell], "rescue target previewed")
	await press(KEY_Z)
	check(fighter.carrying == lord and lord.carried_by == fighter, "Lord is being carried")
	check(not b.units().has(lord), "carried units are off the map")
	check(not lord.visible, "and hidden")
	check(fighter.has_acted, "rescuing ends the rescuer's turn")
	check_eq(b.state, b.State.IDLE, "a carried Lord isn't a defeat")
	check(Combat.attack_speed(fighter) < as_before, "carrying halves AGI (attack speed drops)")
	# Next turn: ride east and drop the Lord, who can still act.
	fighter.has_acted = false
	b.cursor.cell = fighter.cell
	await press(KEY_Z)
	for i in 4:
		await press(KEY_RIGHT)
	await press(KEY_Z)
	check_eq(fighter.cell, Vector2i(8, 6), "carrier moved (across the river ford)")
	await pick("Drop")
	var drop_cell: Vector2i = b.input.target_cells[0]
	await press(KEY_Z)
	check(fighter.carrying == null and lord.carried_by == null, "dropped")
	check_eq(lord.cell, drop_cell, "Lord set down on the chosen cell")
	check(b.units().has(lord) and lord.visible, "back on the map")
	check(fighter.has_acted, "dropping ends the carrier's turn")
	check(not lord.has_acted, "the dropped Lord can still act")
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	check_eq(b.state, b.State.SELECTED, "and can be selected to move on")


func test_fallen_carrier_drops_passenger() -> void:
	var fighter := unit_named("Fighter")
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([fighter, lord, brig])
	fighter.set_class("Cavalry")
	fighter.set_cell(Vector2i(4, 6))
	lord.set_cell(Vector2i(5, 6))
	await b.actions.do_rescue(fighter, lord)
	brig.set_cell(Vector2i(4, 5))
	fighter.hp = 1
	brig.dexterity = 60  # guaranteed hit
	await b.actions.do_combat(brig, fighter)
	check(not is_instance_valid(fighter) or fighter.hp <= 0, "carrier fell")
	check_eq(lord.cell, Vector2i(4, 6), "passenger set down where the carrier fell")
	check(b.units().has(lord) and lord.visible and lord.carried_by == null, "passenger back on the map")


# --- Classes ----------------------------------------------------------------------------

func test_class_data_is_consistent() -> void:
	for id in Classes.DATA:
		var c: Dictionary = Classes.DATA[id]
		check(BattleMap.MOVE_TYPES.has(c.move), "%s: known move type %s" % [id, c.move])
		check(not c.weapons.is_empty(), "%s: wields something" % id)
		for t in c.weapons:
			check(Weapons.DATA.values().any(func(w): return w.type == t), "%s: weapon type %s exists" % [id, t])
		for p in Classes.promotions(id):
			check(Classes.DATA.has(p) and Classes.DATA[p].get("promoted", false),
				"%s: promotes into a promoted class (%s)" % [id, p])
	check_eq(Classes.promotions("Guard"), ["Juggernaut"], "Guard -> Juggernaut")
	check_eq(Classes.promotions("Turret"), ["Juggernaut"], "Turret -> Juggernaut")
	var lord := unit_named("Lord")
	lord.level = 7
	lord.set_class("Swordsmaster")
	check_eq(lord.level, 7, "changing class keeps the level")


func test_class_weapon_restrictions() -> void:
	var lord := unit_named("Lord")
	var mage := unit_named("Mage")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	lord.items.push_front(Items.make("Iron Axe"))
	check_eq(lord.weapon.name, "Iron Sword", "a Swordsman skips the axe it can't wield")
	lord.equip(0)
	check_eq(lord.items[0].name, "Iron Axe", "equip() refuses weapons the class can't wield")
	check(lord.weapons().all(func(w): return w.type == "sword"), "weapons() lists only wieldable ones")
	check_eq(mage.weapon.name, "Quarterstaff", "Mages wield staves")
	clear_board([mage, brig])
	mage.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(6, 2))
	check_eq(Combat.triangle(mage, brig), 0, "staves sit outside the triangle")
	check(Combat.can_counter(brig, mage), "a staff counters in melee")
	# The items menu marks the axe as unusable.
	lord.set_cell(Vector2i(4, 4))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Items")
	check(b.ui.menu_options[0].ends_with("(x)"), "unusable weapon is marked (x)")


func test_swim_and_climb_costs() -> void:
	# Exact costs are in test_move_type_costs; this checks what they mean on a map.
	var m: BattleMap = b.map
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	check_eq(brig.move_type, "climb", "Brigands climb")
	isolate([brig])
	brig.set_cell(Vector2i(1, 3))  # next to the (2, 3) mountain
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(2, 3)), "a MOV 5 climber can scale a mountain (4)")
	brig.move_type = "foot"
	check(not m.get_reachable(brig, b.units()).cells.has(Vector2i(2, 3)), "a MOV 5 foot unit can't (7)")
	brig.set_cell(Vector2i(6, 0))  # next to the river at (7, 0)
	brig.move_type = "swim"
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(7, 0)), "a swimmer wades into the river (2)")
	# Berserkers keep the best of both on every terrain.
	check_eq(Classes.get_data("Berserker").move, "swim_climb", "Berserkers swim and climb")
	for key in BattleMap.TERRAIN:
		var swim := BattleMap.cost_for(key, "swim")
		var climb := BattleMap.cost_for(key, "climb")
		var best := minf(swim, climb) if swim >= 0 and climb >= 0 else maxf(swim, climb)
		check(is_equal_approx(BattleMap.cost_for(key, "swim_climb"), best),
			"swim_climb on '%s': expected %s, got %s" % [key, best, BattleMap.cost_for(key, "swim_climb")])
	check_eq(BattleMap.cost_for("M", "swim_climb"), 4.0, "climbs mountains like a climber")
	check_eq(BattleMap.cost_for("~", "swim_climb"), 2.0, "swims rivers like a swimmer")
	brig.move_type = "swim_climb"
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(7, 0)), "a Berserker wades into the river")
	brig.set_cell(Vector2i(1, 3))
	check(m.get_reachable(brig, b.units()).cells.has(Vector2i(2, 3)), "and scales the mountain")


func test_inspire_buffs_adjacent_allies() -> void:
	var banner := unit_named("Bannerman")
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	clear_board([banner, knight, fighter, archer, brig])
	banner.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	fighter.set_cell(Vector2i(4, 7))
	archer.set_cell(Vector2i(6, 6))
	brig.set_cell(Vector2i(5, 5))
	var dmg_before := Combat.damage(knight, brig, b.map)
	var taken_before := Combat.damage(brig, knight, b.map)
	b.cursor.cell = banner.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Inspire")
	check_eq(b.map.area_cells.size(), 2, "both adjacent allies are previewed")
	await press(KEY_Z)
	check_eq(knight.inspire_bonus, 1, "Lv 1 Inspire: +1")
	check_eq(fighter.inspire_bonus, 1, "every adjacent ally is inspired")
	check_eq(archer.inspire_bonus, 0, "allies 2 tiles away are not")
	check_eq(Combat.damage(knight, brig, b.map), dmg_before + 1, "+1 STR")
	check_eq(Combat.damage(brig, knight, b.map), maxi(0, taken_before - 1), "+1 DEF")
	check(banner.has_acted, "Inspire ends the Bannerman's turn")
	check_eq(banner.exp_points, roundi(Experience.INSPIRE_EXP * 1.1), "Inspire EXP (Human x1.1)")
	check_eq(Classes.inspire_bonus(5), 2, "Lv 5: +2")
	check_eq(Classes.inspire_bonus(20), 5, "Lv 20: +5")
	b.phases.clear_inspire(Unit.Team.ENEMY)
	check_eq(knight.inspire_bonus, 1, "lasts through the enemy phase")
	b.phases.clear_inspire(Unit.Team.PLAYER)
	check_eq(knight.inspire_bonus, 0, "gone at the next player phase")


func test_ship_board_and_unload() -> void:
	var ship := unit_named("Archer")
	var lord := unit_named("Lord")
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	# An idle Fighter keeps the player phase open; the Brigand avoids an instant Victory.
	isolate([ship, lord, knight, fighter, brig])
	ship.set_class("Galley")
	ship.set_cell(Vector2i(7, 4))
	lord.set_cell(Vector2i(6, 4))
	knight.set_cell(Vector2i(6, 5))
	fighter.set_cell(Vector2i(0, 0))
	brig.set_cell(Vector2i(14, 9))
	check(not b.actions.can_shove(lord, ship), "ships can't be shoved")
	# The Lord boards without moving.
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Board")
	check_eq(b.map.area_cells, [ship.cell], "ship previewed")
	await press(KEY_Z)
	check(lord.carried_by == ship and ship.passengers == [lord], "Lord is aboard")
	check(not b.units().has(lord) and not lord.visible, "passengers are off the map")
	check(lord.has_acted, "boarding ends the boarder's turn")
	check_eq(b.state, b.State.IDLE, "a Lord aboard isn't a defeat")
	# The Knight walks up to the ship and boards: now it's full.
	b.cursor.cell = knight.cell
	await press(KEY_Z)
	await press(KEY_UP)
	await press(KEY_Z)
	await pick("Board")
	await press(KEY_Z)
	check_eq(ship.passengers.size(), 2, "two aboard")
	fighter.set_cell(Vector2i(8, 4))
	check(b.actions.board_targets(fighter).is_empty(), "a full ship takes nobody else")
	fighter.set_cell(Vector2i(0, 0))
	# New phase: passengers are refreshed even while aboard.
	await b.phases.start_player_phase()
	check(not lord.has_acted and not knight.has_acted, "passengers get their action back")
	# The ship sails one tile and unloads the Lord, then the Knight, without ending its turn.
	b.cursor.cell = ship.cell
	await press(KEY_Z)
	await press(KEY_DOWN)
	await press(KEY_Z)
	check_eq(ship.cell, Vector2i(7, 5), "ship moved")
	await pick("Unload")
	check_eq(b.state, b.State.MENU, "two passengers: pick who to unload")
	await pick("Lord")
	var lord_cell: Vector2i = b.input.target_cells[0]
	await press(KEY_Z)
	check(lord.carried_by == null and lord.visible and b.units().has(lord), "Lord unloaded")
	check_eq(lord.cell, lord_cell, "onto the chosen cell")
	check(not ship.has_acted, "unloading doesn't end the ship's turn")
	check_eq(b.state, b.State.MENU, "the ship's menu reopens")
	await press(KEY_X)
	check_eq(ship.cell, Vector2i(7, 5), "after unloading, cancel no longer undoes the move")
	await pick("Unload")
	await press(KEY_Z)
	check(ship.passengers.is_empty() and b.units().has(knight), "Knight unloaded too")
	check(not b.ui.menu_options.has("Unload"), "nothing left to unload")
	await pick("Wait")
	check(ship.has_acted, "Wait ends the ship's turn")
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	check_eq(b.state, b.State.SELECTED, "the unloaded Lord can act")


func test_sunk_ship_sets_passengers_ashore() -> void:
	var ship := unit_named("Archer")
	var knight := unit_named("Knight")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([ship, knight, brig])
	ship.set_class("Galley")
	ship.set_cell(Vector2i(7, 4))
	knight.set_cell(Vector2i(6, 4))
	await b.actions.do_board(knight, ship)
	brig.set_cell(Vector2i(8, 4))
	ship.hp = 1
	brig.dexterity = 60  # guaranteed hit
	await b.actions.do_combat(brig, ship)
	check(not is_instance_valid(ship) or ship.hp <= 0, "ship sank")
	check(b.units().has(knight) and knight.visible and knight.carried_by == null, "passenger back on the map")
	check_eq(b.map.move_cost(knight.cell, knight.move_type) >= 0, true, "on a cell it can stand on")
	check_eq(BattleMap.distance(knight.cell, Vector2i(7, 4)), 1, "next to where the ship sank")


# --- Quality of life ----------------------------------------------------------------------

func test_jump_to_next_unit() -> void:
	var waiting: Array = b.units_of(Unit.Team.PLAYER)
	b.cursor.cell = Vector2i(5, 5)  # empty tile
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[0].cell, "from an empty tile: first unit that hasn't acted")
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[1].cell, "then the next one")
	waiting[2].has_acted = true
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[3].cell, "units that already acted are skipped")
	b.cursor.cell = waiting[-1].cell
	await press(KEY_A)
	check_eq(b.cursor.cell, waiting[0].cell, "wraps around to the first")


func test_fast_forward_enemy_phase() -> void:
	Input.action_press("cancel")
	await process_frame
	check_eq(Engine.time_scale, 1.0, "holding X on the player phase does nothing")
	b.enemy_phase = true
	await process_frame
	check_eq(Engine.time_scale, Settings.value("fast_forward_speed"), "holding X on the enemy phase speeds up the game")
	check(b.ui._fast_forward.visible, "with an on-screen indicator")
	Input.action_release("cancel")
	await process_frame
	check_eq(Engine.time_scale, 1.0, "back to normal when released")
	check(not b.ui._fast_forward.visible, "indicator hidden")
	b.enemy_phase = false


func test_level_up_waits_for_confirm() -> void:
	var lord := unit_named("Lord")
	b.ui.level_up_waits = true
	lord.exp_points = 95
	var done := [false]
	var run := func():
		await b.actions.gain_exp(lord, 33)
		done[0] = true
	run.call()
	await create_timer(2.6).timeout
	check(b.ui._level_up.visible, "level-up window still up after the old 2 s timeout")
	check(not done[0], "and the game waits")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_Z
	e.keycode = KEY_Z
	e.pressed = true
	b.ui._unhandled_input(e)
	await process_frame
	await process_frame
	check(not b.ui._level_up.visible, "Z closes it")
	check(done[0], "and the game carries on")


func test_end_turn_warning() -> void:
	var waiting: int = b.units_of(Unit.Team.PLAYER).size()
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("End Turn")
	check_eq(b.input.menu_context, "end_turn", "End Turn with units waiting asks first")
	check_eq(b.ui.menu_options, ["Cancel", "End Turn"], "Cancel is listed (and selected) first")
	check(b.ui._menu_label.text.contains("%d units haven't acted" % waiting), "the prompt says how many")
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Z right away cancels")
	check(not b.enemy_phase, "turn not ended")
	await press(KEY_Z)
	await pick("End Turn")
	await pick("End Turn")
	check(b.enemy_phase or b.turn == 2, "confirming ends the turn")
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame


# --- Weapon effectiveness --------------------------------------------------------------

## Puts a fresh copy of `weapon_name` first in `u`'s inventory (equipped).
func give_weapon(u: Unit, weapon_name: String) -> void:
	u.items.push_front(Items.make(weapon_name))


func test_effectiveness_triples_might() -> void:
	# Each weapon goes to a class that can wield it (classes restrict weapon types).
	var archer := unit_named("Archer")
	var knight := unit_named("Knight")
	var fighter := unit_named("Fighter")
	var target := unit_named("Cleric")
	isolate([archer, knight, fighter, target])
	target.set_cell(Vector2i(6, 2))  # plain: no terrain DEF
	var cases := [
		["Iron Bow", "flying", archer], ["Pike", "horse", knight],
		["Hammer", "heavy", fighter], ["Woodcutter", "ship", fighter],
	]
	for c in cases:
		var attacker: Unit = c[2]
		attacker.set_cell(Vector2i(4, 2) if c[0] == "Iron Bow" else Vector2i(5, 2))
		give_weapon(attacker, c[0])
		check_eq(attacker.weapon.name, c[0], "%s equipped" % c[0])
		var mt: int = Weapons.DATA[c[0]].mt
		var tri := Combat.triangle(attacker, target)
		target.tags.assign(["foot"])
		var normal := Combat.damage(attacker, target, b.map)
		check_eq(normal, maxi(0, attacker.strength + mt + tri - target.defense), "%s vs foot: normal damage" % c[0])
		target.tags.assign([c[1]])
		check(Combat.is_effective(attacker.weapon, target), "%s is effective vs %s" % [c[0], c[1]])
		check_eq(Combat.damage(attacker, target, b.map), attacker.strength + mt * 3 + tri - target.defense,
			"%s vs %s: might x3" % [c[0], c[1]])
		attacker.items.remove_at(0)
		attacker.set_cell(Vector2i(0, 9 - cases.find(c)))
	# Effectiveness counts on counters too: an archer's bow shoots down a flier at range 2.
	target.tags.assign(["flying"])
	archer.set_cell(Vector2i(8, 2))
	check_eq(Combat.forecast(target, archer, b.map).def.multiplier, 3, "counter forecast flags effectiveness")


func test_spirits_resist_non_silver_weapons() -> void:
	var blade := unit_named("Fighter")
	var wraith := unit_named("Archer")
	var mage := unit_named("Mage")
	isolate([blade, wraith, mage])
	blade.set_cell(Vector2i(5, 2))
	wraith.set_cell(Vector2i(6, 2))
	blade.strength = 15  # enough to hurt through DEF either way
	give_weapon(blade, "Iron Axe")
	var full := Combat.damage(blade, wraith, b.map)
	wraith.tags.assign(["spirit"])
	check_eq(Combat.damage(blade, wraith, b.map), floori(full / 2.0), "non-silver weapon: half damage")
	check(Combat.side_stats(blade, wraith, b.map).resisted, "forecast flags the resistance")
	# Silver: not resisted, and effective (x3 might).
	blade.items.remove_at(0)
	give_weapon(blade, "Silver Axe")
	var mt: int = Weapons.DATA["Silver Axe"].mt
	check_eq(Combat.damage(blade, wraith, b.map), blade.strength + mt * 3 - wraith.defense,
		"silver weapon: full damage, might x3")
	check(not Combat.side_stats(blade, wraith, b.map).resisted, "silver isn't resisted")
	# Magic isn't a physical weapon: spirits take it normally.
	var fire := Spells.get_spell("Fire")
	mage.set_cell(Vector2i(4, 2))
	var vs_spirit := Combat.spell_damage(mage, wraith, fire, b.map)
	wraith.tags.assign(["foot"])
	check_eq(vs_spirit, Combat.spell_damage(mage, wraith, fire, b.map), "spells ignore spirit resistance")


func test_forecast_shows_effectiveness() -> void:
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([archer, brig])
	archer.set_cell(Vector2i(5, 2))
	brig.set_cell(Vector2i(7, 2))
	brig.tags.assign(["flying"])
	b.ui.show_forecast(archer, brig, Combat.forecast(archer, brig, b.map), archer.cell)
	var weapon_label: Label = b.ui._forecast_cells[1][1]
	check(weapon_label.text.ends_with("x3"), "attacker's weapon tagged x3 (got '%s')" % weapon_label.text)


func test_ai_prefers_effective_weapon() -> void:
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var knight := unit_named("Knight")
	isolate([brig, knight])
	check_eq(knight.move_type, "heavy", "the Knight (Guard) wears heavy armor")
	brig.items.assign([Items.make("Iron Axe"), Items.make("Hammer")])
	brig.set_cell(Vector2i(5, 2))
	knight.set_cell(Vector2i(6, 2))
	var plan: Dictionary = EnemyAI._best_attack(brig, b, {brig.cell: 0})
	check_eq(plan.get("weapon", {}).get("name", ""), "Hammer", "AI picks the Hammer vs armor")


# --- Races -------------------------------------------------------------------------

func test_race_class_bans() -> void:
	for c in [
		["Naga", "Cavalry", false], ["Naga", "Flier", false], ["Naga", "Footman", true],
		["Centaur", "Flier", false], ["Centaur", "Guard", true], ["Minotaur", "Nomad", false],
		["Harpy", "Guard", false], ["Harpy", "Cavalry", true], ["Ent", "Equestrian", false],
		["Stoneborn", "Rogue", false], ["Stoneborn", "Cavalry", false], ["Stoneborn", "Guard", true],
		["Stoneborn", "Axeman", true], ["Human", "Flier", true],
	]:
		check_eq(Races.allows(c[0], c[1]), c[2], "%s %s allowed" % [c[0], c[1]])
	for r in Races.DATA:
		check(Races.DATA[r].has("description"), "%s has a description" % r)


func test_race_movement_and_tags() -> void:
	var fighter := unit_named("Fighter")  # Axeman
	var knight := unit_named("Knight")  # Guard
	var thief := unit_named("Thief", Unit.Team.ENEMY)  # Rogue
	var galley := unit_named("Archer")
	check_eq(fighter.tags, ["foot"] as Array[String], "a Human's tags are its class's")
	fighter.set_race("Naga")
	check_eq(fighter.move_type, "mermaid", "Nagas always move as aquatic")
	check(fighter.tags.has("foot") and fighter.tags.has("aquatic") and fighter.tags.has("reptile"),
		"and keep the class tag next to their own")
	knight.set_race("Centaur")
	check_eq(knight.move_type, "horse", "Centaur Guard moves as a horse")
	check(knight.tags.has("heavy") and knight.tags.has("horse"), "but is still a heavy target")
	check_eq(knight.mov_bonus, 0, "no MOV bonus outside foot and scout classes")
	var base := knight.mov
	knight.set_class("Footman")
	check_eq(knight.mov, base + 1, "+1 MOV in a foot class")
	knight.set_race("Lizal")
	check_eq(knight.move_type, "swim_climb", "Lizal on foot swims and climbs")
	check_eq(knight.mov, base, "bonus gone with the race")
	thief.set_race("Lizal")
	check_eq(thief.move_type, "rogue_swim_climb", "a Lizal scout keeps scout movement too")
	check(is_equal_approx(BattleMap.cost_for("#", "rogue_swim_climb"), 6.0)
		and is_equal_approx(BattleMap.cost_for("W", "rogue_swim_climb"), 2.0)
		and is_equal_approx(BattleMap.cost_for("M", "rogue_swim_climb"), 4.0), "cheapest of the three")
	knight.set_class("Cavalry")
	check_eq(knight.move_type, "horse", "a Lizal rider just rides")
	fighter.set_race("Harpy")
	check_eq(fighter.move_type, "flying", "Harpies fly")
	fighter.set_class("Cavalry")
	check_eq(fighter.move_type, "horse", "unless mounted")
	check(fighter.tags.has("flying"), "but still count as fliers")
	fighter.set_race("Ghost")
	check_eq(fighter.move_type, "spirit", "Ghosts always move as spirits")
	fighter.set_class("Axeman")
	fighter.set_race("Stoneborn")
	check(fighter.move_type == "heavy" and fighter.tags.has("heavy"), "Stoneborn move and count as heavy")
	fighter.set_race("Ent")
	check(fighter.move_type == "heavy" and not fighter.tags.has("heavy"), "Ents only move as heavy")
	galley.set_class("Galley")
	galley.set_race("Ghost")
	check_eq(galley.move_type, "ship", "ships keep sailing whatever the crew")


func test_race_weaknesses_and_resistances() -> void:
	var fighter := unit_named("Fighter")  # Axeman
	var soldier := unit_named("Knight")  # Guard (spears)
	var target := unit_named("Cleric")
	isolate([fighter, soldier, target])
	target.set_cell(Vector2i(6, 2))  # plain: no terrain DEF
	soldier.set_cell(Vector2i(5, 2))
	fighter.set_cell(Vector2i(7, 2))
	fighter.strength = 15
	soldier.strength = 15
	var spear := Items.make("Iron Spear")
	var axe := Items.make("Iron Axe")
	# Weak (x2): spears vs aquatic, axes vs wooden.
	var human_dmg := Combat.damage(soldier, target, b.map)
	target.set_race("Naga")
	check_eq(Combat.multiplier(spear, target), 2, "spears are x2 vs aquatic")
	check_eq(Combat.damage(soldier, target, b.map), human_dmg + spear.mt, "spear might doubled vs Naga")
	target.set_race("Ent")
	check_eq(Combat.multiplier(axe, target), 2, "axes are x2 vs wooden")
	check_eq(Combat.multiplier(Items.make("Hammer"), target), 2, "the Hammer is just an axe vs Ents")
	# Effective (x3) beats Weak and isn't stacked with it.
	soldier.set_race("Centaur")
	check_eq(Combat.multiplier(Items.make("Hammer"), soldier), 3, "Hammer effective vs a Centaur Guard")
	check_eq(Combat.multiplier(Items.make("Pike"), soldier), 3, "and so is the Pike")
	# Undead: silver is x2; a Ghost's spirit tag makes it x3 instead (no stacking).
	var silver := Items.make("Silver Axe")
	target.set_race("Skeleton")
	check_eq(Combat.multiplier(silver, target), 2, "silver x2 vs Skeletons")
	check(not Combat.resists(target, axe), "Skeletons don't resist iron")
	target.set_race("Ghost")
	check_eq(Combat.multiplier(silver, target), 3, "silver x3 vs Ghosts (spirit), not x6")
	check(Combat.resists(target, axe), "Ghosts resist iron like any spirit")
	check(not Combat.resists(target, silver), "but not silver")


func test_race_spell_elements() -> void:
	var mage := unit_named("Mage")
	var target := unit_named("Cleric")
	isolate([mage, target])
	target.set_cell(Vector2i(6, 2))
	mage.set_cell(Vector2i(5, 2))
	mage.intelligence = 20
	target.mp = 0
	var fire := Spells.get_spell("Fire")
	var spike := Spells.get_spell("Earth Spike")
	var full := Combat.spell_damage(mage, target, fire, b.map)
	target.set_race("Naga")
	check_eq(Combat.spell_damage(mage, target, fire, b.map), floori(full / 2.0),
		"Nagas resist Fire once, though both Aquatic and Reptile resist it")
	check(Combat.spell_forecast(mage, target, fire, b.map).atk.resisted, "forecast flags it")
	target.set_race("Ent")
	check_eq(Combat.spell_damage(mage, target, fire, b.map), full + fire.power, "Ents take x2 Fire power")
	check_eq(Combat.spell_forecast(mage, target, fire, b.map).atk.multiplier, 2, "forecast shows x2")
	var spike_full: int = mage.intelligence + spike.power
	check_eq(Combat.spell_damage(mage, target, spike, b.map), floori(spike_full / 2.0), "and resist Earth")
	target.set_race("Ghost")
	check_eq(Combat.spell_damage(mage, target, fire, b.map), full + fire.power, "the undead burn too")


func test_race_carry_and_shove() -> void:
	var fighter := unit_named("Fighter")
	var knight := unit_named("Knight")
	var archer := unit_named("Archer")
	isolate([fighter, knight, archer])
	fighter.set_cell(Vector2i(4, 6))
	knight.set_cell(Vector2i(5, 6))
	archer.set_cell(Vector2i(3, 6))
	fighter.set_race("Centaur")
	check(b.actions.can_shove(fighter, knight), "Centaurs can shove")
	check(not b.actions.can_shove(knight, fighter), "but can't be shoved")
	check_eq(b.actions.rescue_targets(fighter).size(), 2, "and can carry allies on foot")
	archer.set_class("Cavalry")
	check(not b.actions.rescue_targets(archer).has(fighter), "but can't be carried")
	fighter.set_race("Human")
	fighter.set_class("Cavalry")
	knight.set_race("Ent")
	check(not b.actions.rescue_targets(fighter).has(knight), "Ents can't be carried")
	fighter.set_class("Axeman")
	check(not b.actions.can_shove(fighter, knight), "or shoved")
	knight.set_race("Stoneborn")
	check(not b.actions.can_shove(fighter, knight), "nor can the Stoneborn")
	archer.set_cell(Vector2i(0, 0))  # clear the landing cell
	check(b.actions.can_shove(knight, fighter), "though they can shove others")


func test_race_regen_and_exp() -> void:
	var lord := unit_named("Lord")
	var mage := unit_named("Mage")
	isolate([lord, mage])
	lord.set_cell(Vector2i(6, 2))  # plain: no tile healing
	lord.set_race("Troll")
	lord.hp = 5
	await b.phases.heal_on_tiles(Unit.Team.PLAYER)
	check_eq(lord.hp, 5 + ceili(lord.max_hp * 0.1), "Trolls regenerate 10% HP")
	check_eq(mage.mp_regen(), Spells.MP_REGEN, "normal MP regen")
	mage.set_race("Fairy")
	check_eq(mage.mp_regen(), Spells.MP_REGEN + 1, "Fairies recover 1 more")
	lord.exp_points = 0
	await b.actions.gain_exp(lord, 10)
	check_eq(lord.exp_points, 10, "Trolls earn plain EXP")
	lord.set_race("Human")
	await b.actions.gain_exp(lord, 10)
	check_eq(lord.exp_points, 21, "Humans earn 10% more")


# --- Info panel, unit list, objective ------------------------------------------------------

func test_info_panel_terrain_bonus() -> void:
	var lord := unit_named("Lord")
	lord.set_cell(Vector2i(4, 0))  # forest: DEF +1, AVO +20
	b.cursor.cell = lord.cell
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Forest  DEF+1 AVO+20"), "foot unit sees the forest bonus")
	lord.move_type = "flying"
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Forest  no bonus (Flying)"), "a flier gets no terrain bonus")
	lord.move_type = "foot"
	b.map.set_terrain(Vector2i(5, 2), "=")
	b.cursor.cell = Vector2i(5, 2)
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Path  DEF+0 AVO-20"), "negative bonuses read AVO-20, not AVO+-20")


func test_unit_list() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Units")
	var list: UnitListScreen = b.ui.unit_list
	check_eq(b.state, b.State.UNIT_LIST, "map menu > Units opens the list")
	check(list.visible, "list shown")
	check_eq(list.units.size(), b.units().size(), "lists every unit on the map")
	# Sort by level (column 2): highest first.
	await press(KEY_RIGHT)
	await press(KEY_RIGHT)
	check_eq(list.COLUMNS[list.sort_col].key, "lv", "Right twice: sort by level")
	var levels: Array = list.units.map(func(u): return u.level)
	var sorted_levels := levels.duplicate()
	sorted_levels.sort()
	sorted_levels.reverse()
	check_eq(levels, sorted_levels, "sorted high to low")
	# D opens the status screen; closing it comes back to the list.
	await press(KEY_DOWN)
	var picked := list.selected_unit()
	await press(KEY_D)
	check(b.state == b.State.STATUS and b.ui.status_screen.unit == picked, "D shows the unit's status")
	await press(KEY_X)
	check_eq(b.state, b.State.UNIT_LIST, "closing the status screen returns to the list")
	# Z jumps the cursor to the unit.
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Z closes the list")
	check_eq(b.cursor.cell, picked.cell, "and puts the cursor on the unit")
	check(not list.visible, "list hidden")


func test_objective_screen() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Objective")
	check_eq(b.state, b.State.OBJECTIVE, "map menu > Objective opens it")
	var text: String = b.ui._objective_label.text
	check(text.contains("River Crossing"), "names the map")
	check(text.contains("Victory: Defeat every enemy."), "victory condition")
	check(text.contains("Defeat: Your Lord falls."), "defeat condition")
	check(text.contains("Turn 1"), "turn number")
	check(text.contains("Enemies %d" % b.units_of(Unit.Team.ENEMY).size()), "enemy count")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X closes it")


# --- Suspend / resume / restart ---------------------------------------------------------

func test_suspend_round_trip() -> void:
	var lord := unit_named("Lord")
	var fighter := unit_named("Fighter")
	var archer := unit_named("Archer")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	# Change a bit of everything.
	lord.set_cell(Vector2i(5, 2))
	lord.hp = 7
	lord.luck = 13
	lord.items[0].uses = 10
	lord.has_acted = true
	lord.biography.append("Suspended mid-battle.")
	fighter.set_cell(Vector2i(4, 6))
	archer.set_cell(Vector2i(5, 6))
	await b.actions.do_rescue(fighter, archer)
	brig.ai_awake = true
	brig.was_attacked = true
	b.map.set_terrain(Vector2i(3, 4), "M")
	b.turn = 3
	b.danger_on = true
	b.marked.assign([brig])
	var before := SaveGame.capture(b)
	SaveGame.write_suspend(b)
	# Resume into a fresh battle scene.
	Levels.resume = true
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check_eq(var_to_str(SaveGame.capture(b)), var_to_str(before), "resumed battle captures identically")
	lord = unit_named("Lord")
	fighter = unit_named("Fighter")
	check_eq(lord.cell, Vector2i(5, 2), "unit position")
	check_eq(lord.hp, 7, "HP")
	check_eq(lord.items[0].uses, 10, "item uses")
	check(lord.has_acted, "acted units stay acted")
	check_eq(lord.position, Vector2(Vector2i(5, 2) * BattleMap.TILE), "drawn where it stands")
	check(fighter.carrying != null and fighter.carrying.unit_name == "Archer", "carried unit restored")
	check(not b.units().has(fighter.carrying) and not fighter.carrying.visible, "and still off the map")
	check_eq(b.map.terrain_key(Vector2i(3, 4)), "M", "terrain changes restored")
	check_eq(b.turn, 3, "turn")
	check_eq(b.state, b.State.IDLE, "resumes on the player phase, ready for input")
	check(b.marked.size() == 1 and b.marked[0].unit_name == "Brigand", "marked enemies restored")
	SaveGame.delete_suspend()


func test_level_select_offers_resume() -> void:
	SaveGame.write_suspend(b)
	var select: Node = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check(select.choices[0].resume, "a Resume entry comes first")
	check_eq(select.choices[0].label, "Resume: River Crossing, Turn 1", "it names the map and turn")
	check_eq(select.index, 0, "and is preselected")
	select.queue_free()
	SaveGame.delete_suspend()
	select = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check(not select.choices[0].get("resume", false), "no suspend, no Resume entry")
	select.queue_free()


func test_suspend_discarded_when_map_ends() -> void:
	SaveGame.write_suspend(b)
	for e in b.units_of(Unit.Team.ENEMY):
		e.hp = 0
	b.phases.check_game_over()
	check_eq(b.state, b.State.GAME_OVER, "victory")
	check(not SaveGame.has_suspend(), "the finished map's suspend is deleted")


func test_restart_asks_first() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Restart")
	check_eq(b.input.menu_context, "restart", "Restart asks for confirmation")
	check_eq(b.ui.menu_options, ["Cancel", "Restart"], "Cancel first")
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Z right away cancels")


# --- Options ----------------------------------------------------------------------------

## Back to default options (removes the test settings file).
func reset_settings() -> void:
	DirAccess.remove_absolute(Settings.path)
	Settings.reload()


func test_options_screen_saves() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Options")
	check_eq(b.state, b.State.OPTIONS, "map menu > Options opens it")
	check(b.ui.options_screen.visible, "options screen shown")
	await press(KEY_RIGHT)  # Game speed: Normal -> Fast
	check_eq(Settings.value("game_speed"), 1.5, "Right changes the highlighted option")
	await press(KEY_DOWN)
	await press(KEY_DOWN)
	await press(KEY_RIGHT)  # Danger zone at start: Off -> On
	check_eq(Settings.value("danger_zone_default"), true, "Down + Right changes another option")
	await press(KEY_X)
	check_eq(b.state, b.State.IDLE, "X closes it")
	await process_frame
	check_eq(Engine.time_scale, 1.5, "game speed applies right away")
	Settings.reload()
	check_eq(Settings.value("game_speed"), 1.5, "saved to disk and read back")
	check_eq(Settings.value("danger_zone_default"), true, "every changed option is saved")
	reset_settings()
	await process_frame
	check_eq(Engine.time_scale, 1.0, "back to normal speed")


func test_option_danger_zone_at_start() -> void:
	Settings.set_value("danger_zone_default", true)
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check(b.danger_on and not b.map.danger_cells.is_empty(), "battle starts with the danger zone on")
	reset_settings()


func test_option_auto_end_turn_off() -> void:
	Settings.set_value("auto_end_turn", false)
	var lord := unit_named("Lord")
	for u in b.units_of(Unit.Team.PLAYER):
		if u != lord:
			u.has_acted = true
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Wait")
	check(not b.enemy_phase and b.state == b.State.IDLE, "everyone acted, but the turn waits for End Turn")
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("End Turn")
	check(b.enemy_phase or b.turn == 2, "End Turn with nobody waiting ends it without asking")
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	reset_settings()


func test_option_level_up_auto() -> void:
	Settings.set_value("level_up_wait", false)
	b.ui.level_up_waits = true  # the window itself would wait...
	var lord := unit_named("Lord")
	lord.exp_points = 95
	await b.actions.gain_exp(lord, 33)  # ...but the option says Auto, so this returns on its own
	check(not b.ui._level_up.visible, "Auto: the level-up window closes by itself")
	reset_settings()


func test_level_select_has_options() -> void:
	var select: Node = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check(select.choices[-1].get("options", false), "Options is the last entry")
	select.queue_free()


# --- Campaign: objectives, map objects, reinforcements, army, prep -----------------------

## Starts campaign chapter `index` with a fresh campaign whose army has every
## recruit up to it, deployed by default.
func start_chapter(index: int) -> void:
	Campaign.start_new()
	for i in range(1, index + 1):
		Campaign.chapter = i
		Campaign.add_recruits()
	Campaign.active = true
	Campaign.deployed = Campaign.default_deployment()
	Levels.selected = Chapters.ORDER[index]
	b.queue_free()
	await process_frame
	await _fresh_battle()


func remove_unit(u: Unit) -> void:
	u.get_parent().remove_child(u)
	u.free()


func test_all_chapters_are_valid() -> void:
	for id in Chapters.ORDER:
		var level := Levels.get_level(id)
		var layout: Array = level.layout
		var at := func(c: Vector2i) -> String: return layout[c.y][c.x]
		var inside := func(c: Vector2i) -> bool:
			return c.x >= 0 and c.y >= 0 and c.y < layout.size() and c.x < layout[0].length()
		for row in layout:
			check_eq(row.length(), layout[0].length(), "%s: rows have equal length" % id)
		var taken := {}
		for c in level.deploy:
			check(inside.call(c) and BattleMap.cost_for(at.call(c), "foot") >= 0, "%s: deploy cell %s usable" % [id, c])
			check(not taken.has(c), "%s: deploy cell %s listed once" % [id, c])
			taken[c] = true
		var all_units: Array = level.enemies + level.recruits
		for wave in level.get("reinforcements", []):
			all_units += wave.units
		for data in all_units:
			check(Classes.DATA.has(data.get("class", "")), "%s: %s has a known class" % [id, data.name])
			var cls := Classes.get_data(data["class"])
			for item_name in data.get("items", []):
				if Weapons.DATA.has(item_name):
					check(cls.weapons.has(Weapons.DATA[item_name].type), "%s: %s can wield %s" % [id, data.name, item_name])
				else:
					check(Items.CONSUMABLES.has(item_name), "%s: %s carries a known item %s" % [id, data.name, item_name])
		for data in level.enemies:
			var move_type := Races.move_type(data.get("race", "Human"), data["class"])  # races can change movement
			check(inside.call(data.cell) and BattleMap.cost_for(at.call(data.cell), move_type) >= 0,
				"%s: %s can stand on its start tile" % [id, data.name])
			check(not taken.has(data.cell), "%s: %s shares a tile" % [id, data.name])
			taken[data.cell] = true
		for o in level.get("objects", []):
			check(inside.call(o.cell), "%s: object at %s on the map" % [id, o.cell])
			check(Items.CONSUMABLES.has(o.item) or Weapons.DATA.has(o.item), "%s: reward %s exists" % [id, o.item])
		var obj := Objectives.of(level)
		for c in Objectives.marked_cells(obj):
			check(inside.call(c) and BattleMap.cost_for(at.call(c), "foot") >= 0, "%s: objective tile %s reachable" % [id, c])
		if obj.type == "boss":
			check(level.enemies.any(func(e): return e.name == obj.boss), "%s: the boss is on the map" % id)


func test_seize_objective() -> void:
	await start_chapter(1)
	var lord := unit_named("Lord")
	remove_unit(unit_named("Commander", Unit.Team.ENEMY))
	lord.set_cell(Vector2i(7, 0))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	check(b.ui.menu_options.has("Seize"), "the Lord on the throne can Seize")
	await pick("Seize")
	check_eq(b.battle_result, "victory", "seizing wins")
	check(lord.biography.any(func(e): return e.begins_with("Seized")), "logged in the Lord's biography")


func test_boss_objective() -> void:
	await start_chapter(2)
	check(not b.phases.check_game_over(), "boss alive: battle goes on")
	remove_unit(unit_named("Bandit King", Unit.Team.ENEMY))
	check(b.phases.check_game_over(), "boss down: it's over...")
	check_eq(b.battle_result, "victory", "...and won, though other enemies remain")


func test_defend_objective() -> void:
	await start_chapter(3)
	b.turn = 6
	check(not b.phases.check_game_over(true), "turn 6 of 7: not yet")
	b.turn = 7
	check(b.phases.check_game_over(true), "after enemy phase 7: over")
	check_eq(b.battle_result, "victory", "held out: victory")
	await start_chapter(3)
	var soldier: Unit = b.units_of(Unit.Team.ENEMY)[0]
	soldier.set_cell(Vector2i(6, 3))
	b.phases.check_game_over()
	check_eq(b.battle_result, "defeat", "an enemy on the town hall: defeat")


func test_escape_objective() -> void:
	await start_chapter(4)
	var lord := unit_named("Lord")
	var other: Unit = b.units_of(Unit.Team.PLAYER).filter(func(u): return not u.is_lord)[0]
	other.set_cell(Vector2i(6, 9))
	b.cursor.cell = other.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Escape")
	check(other.escaped and not b.units().has(other), "a unit escapes off the map")
	check(b.all_units().has(other), "but stays in the army")
	check_eq(b.battle_result, "", "only the Lord escaping wins")
	lord.set_cell(Vector2i(7, 9))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Escape")
	check_eq(b.battle_result, "victory", "the Lord escaping wins")


func test_villages_visit_and_loot() -> void:
	await start_chapter(0)
	var lord := unit_named("Lord")
	var items_before := lord.items.size()
	lord.set_cell(Vector2i(5, 0))
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Visit")
	check_eq(b.map.object_at(Vector2i(5, 0)).state, "visited", "village visited")
	check_eq(lord.items.size(), items_before + 1, "its reward is added")
	check_eq(lord.items[-1].name, "Potion", "the village's item")
	var thief := unit_named("Thief", Unit.Team.ENEMY)
	thief.set_cell(Vector2i(11, 2))  # one step from the other village
	await EnemyAI.take_turn(thief, b)
	check_eq(b.map.object_at(Vector2i(11, 3)).state, "looted", "the thief burns the other village")


func test_chests() -> void:
	await start_chapter(1)
	var scout := unit_named("Scout")
	var lord := unit_named("Lord")
	scout.set_cell(Vector2i(3, 2))
	b.cursor.cell = scout.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Open")
	check_eq(scout.items[-1].name, "Silver Sword", "a rogue opens chests without a key")
	check_eq(b.map.object_at(Vector2i(3, 2)).state, "opened", "chest opened")
	# Anyone else needs a Chest Key, which is used up.
	lord.set_cell(Vector2i(11, 2))
	check(not b.actions.can_open_chest(lord), "no key, no Open")
	lord.items.append(Items.make("Chest Key"))
	check(b.actions.can_open_chest(lord), "with a key: Open")
	b.cursor.cell = lord.cell
	await press(KEY_Z)
	await press(KEY_Z)
	await pick("Open")
	check(not lord.items.any(func(it): return it.name == "Chest Key"), "the key is used up")
	check(lord.items.any(func(it): return it.name == "Hammer"), "and the chest's item received")


func test_reinforcements() -> void:
	await start_chapter(3)
	var before: int = b.units_of(Unit.Team.ENEMY).size()
	b.turn = 2
	await b.phases.spawn_reinforcements()
	var arrived: Array = b.units_of(Unit.Team.ENEMY).filter(func(u): return u.has_acted)
	check_eq(b.units_of(Unit.Team.ENEMY).size(), before + 2, "turn 2: two reinforcements arrive")
	check_eq(arrived.size(), 2, "and wait until the next phase to act")


func test_campaign_army_carries_over() -> void:
	await start_chapter(0)
	check_eq(Campaign.army.size(), 5, "starting army")
	var lord := unit_named("Lord")
	var fighter := unit_named("Fighter")
	lord.exp_points = 60
	lord.items.append(Items.make("Chest Key"))
	fighter.hp = 0
	var involved: Array[Unit] = [fighter]
	await b.actions._remove_dead_and_award(involved, [])
	b.battle_result = "victory"
	Campaign.finish_chapter(b)
	check_eq(Campaign.chapter, 1, "on to chapter 2")
	check(Campaign.army_unit("Fighter").is_empty(), "the fallen Fighter left the army (permadeath)")
	check_eq(Campaign.fallen.size(), 1, "kept among the fallen")
	check(Campaign.fallen[0].unit.biography[-1].begins_with("Fell in Chapter 1"), "with the event in its biography")
	check_eq(Campaign.army_unit("Lord").exp_points, 60, "EXP carried over")
	check(Campaign.army_unit("Lord").items.any(func(it): return it.name == "Chest Key"), "items carried over")
	check(not Campaign.army_unit("Scout").is_empty(), "chapter 2's recruit joined")
	check(Campaign.army_unit("Scout").biography[-1].begins_with("Joined the army in Chapter 2"), "and logged it")
	# Saved: a reload gets the same campaign back.
	var army_before := var_to_str(Campaign.army)
	Campaign.army = []
	check(Campaign.load_save(), "campaign saved")
	check_eq(var_to_str(Campaign.army), army_before, "and loads back unchanged")


func test_promotion() -> void:
	Campaign.start_new()
	var lord: Dictionary = Campaign.army_unit("Lord")
	check(not Campaign.can_promote(lord), "Lv 1 can't promote")
	lord.level = 15
	check(Campaign.can_promote(lord), "Lv 15 can")
	var str_before: int = lord.strength
	var gains := Campaign.promote("Lord", "Swordsmaster")
	var promoted := Campaign.army_unit("Lord")
	check_eq(promoted.unit_class, "Swordsmaster", "new class")
	check_eq(promoted.level, 15, "level kept")
	check_eq(promoted.strength, str_before + Classes.promotion_bonus("Swordsmaster").str, "class bonus applied")
	check_eq(gains.str, Classes.promotion_bonus("Swordsmaster").str, "gains reported")
	check(promoted.biography[-1].begins_with("Promoted to Swordsmaster"), "logged")


func test_prep_screen() -> void:
	Campaign.start_new()
	var prep: Control = load("res://scenes/prep.tscn").instantiate()
	root.add_child(prep)
	await process_frame
	check_eq(prep.picked.size(), 5, "default deployment: everyone (5 of 6 slots)")
	prep._enter("pick")
	prep._toggle_pick("Lord")
	check(prep.picked.has("Lord"), "the Lord can't be benched")
	prep._toggle_pick("Archer")
	check(not prep.picked.has("Archer"), "others can")
	# Items: Lord's Potion to the convoy and back.
	prep.current_unit = "Lord"
	prep.mode = "items"
	prep.column = 0
	prep.index = 1
	prep._move_item()
	check_eq(Campaign.convoy.size(), 1, "item stored in the convoy")
	prep.column = 1
	prep.index = 0
	prep._move_item()
	check(Campaign.convoy.is_empty() and Campaign.army_unit("Lord").items.size() == 2, "and taken back")
	prep.queue_free()


func test_campaign_suspend_resume() -> void:
	await start_chapter(0)
	b.map.object_at(Vector2i(5, 0)).state = "visited"
	SaveGame.write_suspend(b)
	Campaign.active = false
	Levels.resume = true
	b.queue_free()
	await process_frame
	await _fresh_battle()
	check(Campaign.active, "resuming a chapter reactivates the campaign")
	check_eq(b.map.object_at(Vector2i(5, 0)).state, "visited", "map objects restored")
	check_eq(Levels.selected, "ch1", "on the right chapter")
	SaveGame.delete_suspend()


func test_chapters_enemy_phases_run() -> void:
	# Three full rounds of enemy phases on every chapter (looting, reinforcements,
	# goto/defend AI...), sped up. Runtime errors here fail the run via run_tests.sh.
	for i in Chapters.ORDER.size():
		await start_chapter(i)
		Settings.set_value("game_speed", 2.0)
		for round in 3:
			if b.state == b.State.GAME_OVER:
				break
			b.phases.end_player_phase()
			while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
				Engine.time_scale = 8.0
				await process_frame
		check(b.state == b.State.IDLE or b.state == b.State.GAME_OVER, "%s: enemy phases settle" % Chapters.ORDER[i])
	reset_settings()
	Engine.time_scale = 1.0


func test_marked_enemy_freed() -> void:
	# Regression: killing a marked enemy froze the game. Dead units are freed, and
	# refresh_threat() crashed rebuilding the mark list.
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	var sold := unit_named("Soldier", Unit.Team.ENEMY)
	b.marked.assign([brig, sold])
	b.refresh_threat()
	remove_unit(brig)
	b.refresh_threat()
	check_eq(b.marked.size(), 1, "the freed enemy's mark is dropped")
	check(b.marked[0] == sold, "the other mark stays")
	check_eq(b.map.marked_cells, b.enemy_threat(sold), "overlay shows only the survivor's threat")


func test_quit_to_level_select_asks_first() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	await pick("Level Select")
	check_eq(b.input.menu_context, "quit", "Level Select asks for confirmation")
	check_eq(b.ui.menu_choice(), "Cancel", "Cancel is selected first")
	await press(KEY_Z)
	check_eq(b.state, b.State.IDLE, "Cancel returns to the map")
	check(is_instance_valid(b) and b.is_inside_tree(), "still in the battle")


func test_end_turn_last_and_warning_option() -> void:
	b.cursor.cell = Vector2i(5, 5)
	await press(KEY_Z)
	check_eq(b.ui.menu_options[-1], "End Turn", "End Turn is the last map menu entry")
	await press(KEY_UP)
	check_eq(b.ui.menu_choice(), "End Turn", "so Up from the top reaches it")
	await press(KEY_X)
	Settings.set_value("end_turn_warning", false)
	await press(KEY_Z)
	await pick("End Turn")
	check(b.enemy_phase or b.turn == 2, "warning off: End Turn ends it right away, units still waiting")
	while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
		await process_frame
	reset_settings()


# --- Breakable tiles and doors (Ruined Fort) ------------------------------------

func start_level(id: String) -> void:
	Levels.selected = id
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"


## Selects `u` and opens its menu without moving it.
func open_menu_in_place(u: Unit) -> void:
	b.cursor.cell = u.cell
	await press(KEY_Z)
	await press(KEY_Z)


func test_break_wall_through_menu() -> void:
	await start_level("ruined_fort")
	var wall := Vector2i(6, 2)
	var fighter := unit_named("Fighter")
	check_eq(b.map.tile_hp.get(wall), 20, "a cracked wall starts at 20 HP")
	check_eq(b.map.cost_for("x", "flying"), BattleMap.IMPASSABLE, "fliers can't cross walls, cracked or not")
	fighter.set_cell(Vector2i(2, 7))
	await open_menu_in_place(fighter)
	check(not b.ui.menu_options.has("Break"), "nothing breakable in reach, no Break")
	await press(KEY_X)
	await press(KEY_X)
	fighter.set_cell(Vector2i(7, 2))
	await open_menu_in_place(fighter)
	await pick("Break")
	check_eq(b.ui.menu_options.size(), 2, "both axes reach the wall")
	await press(KEY_Z)  # Iron Axe
	check_eq(b.input.target_mode, "break", "then pick the tile")
	check_eq(b.cursor.cell, wall, "the cursor jumps to it")
	check(b.ui._spell_label.text.contains("Cracked Wall  HP 20 -> 5"), "forecast: STR 7 + Mt 8 = 15 damage")
	await press(KEY_Z)
	check_eq(b.map.tile_hp.get(wall), 5, "the wall takes the damage")
	b.cursor.cell = wall
	b.input.refresh_info()
	check(b.ui._info_label.text.contains("Cracked Wall  HP 5/20"), "hovering shows its remaining HP")
	check(not b.ui._info_label.text.contains("AVO"), "instead of terrain bonuses")
	check_eq(b.map.terrain_key(wall), "x", "and still stands")
	check(fighter.has_acted, "breaking ends the unit's turn")
	check_eq(fighter.items[0].uses, 44, "and uses the weapon")
	await b.actions.do_break(fighter, wall)
	check_eq(b.map.terrain_key(wall), "_", "broken: it becomes floor")
	check(not b.map.tile_hp.has(wall), "and has no HP left to track")
	check(b.can_stand_on(fighter, wall), "units can walk through")


func test_break_fence_and_trunk_bridge() -> void:
	await start_level("ruined_fort")
	var archer := unit_named("Archer")
	# A cracked fence becomes plain; bows break it from range.
	var fence := Vector2i(8, 5)
	archer.set_cell(Vector2i(6, 5))
	check(b.actions.breakable_in_reach(archer).has(fence), "the bow reaches the fence at range 2")
	await b.actions.do_break(archer, fence)
	check_eq(b.map.terrain_key(fence), ".", "10 HP: one shot (STR 5 + Mt 6) breaks it into a plain")
	# A trunk falls into the river next to it, away from the attacker if possible.
	var trunk := Vector2i(11, 2)
	archer.set_cell(Vector2i(9, 2))
	b.map.tile_hp[trunk] = 1
	await b.actions.do_break(archer, trunk)
	check_eq(b.map.terrain_key(trunk), ".", "the trunk leaves a plain")
	check_eq(b.map.terrain_key(Vector2i(10, 2)), "B", "and bridges the river")
	check_eq(b.map.terrain_key(Vector2i(9, 2)), ".", "the bridge stops at dry land")
	check_eq(BattleMap.cost_for("B", "mermaid"), 1.0, "water units pass under the bridge")
	# With water on both sides, it falls away from whoever broke it.
	var trunk2 := Vector2i(11, 5)
	for x in [12, 13, 14]:
		b.map.set_terrain(Vector2i(x, 5), "~")
	archer.set_cell(Vector2i(9, 5))
	b.map.tile_hp[trunk2] = 1
	await b.actions.do_break(archer, trunk2)
	check_eq(b.map.terrain_key(Vector2i(10, 5)), "~", "not toward the archer")
	for x in [12, 13, 14]:
		check_eq(b.map.terrain_key(Vector2i(x, 5)), "B", "away from it, up to 3 tiles (%d)" % x)


func test_doors_open_or_break() -> void:
	await start_level("ruined_fort")
	var door := Vector2i(3, 4)
	var scout := unit_named("Scout")
	var knight := unit_named("Knight")
	check(b.map.is_door(door), "a locked door")
	# Anyone without a key can only break it.
	knight.set_cell(Vector2i(3, 5))
	await open_menu_in_place(knight)
	check(not b.ui.menu_options.has("Open Door"), "no key, no Open Door")
	check(b.ui.menu_options.has("Break"), "but it can be broken")
	await press(KEY_X)
	await press(KEY_X)
	# A rogue opens it freely.
	knight.set_cell(Vector2i(4, 7))
	scout.set_cell(Vector2i(3, 5))
	await open_menu_in_place(scout)
	await pick("Open Door")
	check(b.ui._spell_label.text.contains("Open Door"), "forecast")
	await press(KEY_Z)
	check_eq(b.map.terrain_key(door), "_", "the door opens onto floor")
	check(scout.has_acted, "opening ends the turn")
	check(not b.map.tile_hp.has(door), "an open door has nothing left to break")
	# A Chest Key works too, and is used up.
	b.map.set_terrain(door, "+")
	check_eq(b.map.tile_hp.get(door), 20, "a fresh door has full HP")
	scout.set_cell(Vector2i(5, 7))
	knight.set_cell(Vector2i(3, 5))
	knight.items.append(Items.make("Chest Key"))
	await open_menu_in_place(knight)
	await pick("Open Door")
	await press(KEY_Z)
	check_eq(b.map.terrain_key(door), "_", "opened with a key")
	check(not knight.items.any(func(it): return it.name == "Chest Key"), "the key is used up")


func test_tile_hp_survives_suspend() -> void:
	await start_level("ruined_fort")
	b.map.damage_tile(Vector2i(6, 2), 7, Vector2i(7, 2))
	b.map.damage_tile(Vector2i(8, 5), 10, Vector2i(7, 5))
	SaveGame.write_suspend(b)
	Levels.selected = "ruined_fort"
	Levels.resume = true
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 13, "damaged wall keeps its HP")
	check_eq(b.map.terrain_key(Vector2i(8, 5)), ".", "broken fence stays broken")
	check_eq(b.map.tile_hp.get(Vector2i(3, 4)), 20, "untouched door at full HP")
	SaveGame.delete_suspend()


func test_ruined_fort_phases_run_without_errors() -> void:
	await start_level("ruined_fort")
	await test_enemy_phases_run_without_errors()


func test_enemies_break_and_open_obstacles() -> void:
	await start_level("ruined_fort")
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([lord, brig])
	await process_frame
	brig.ai = AIProfiles.resolve({})  # a charger
	brig.items.assign([Items.make("Iron Axe")])
	brig.equip(0)
	lord.set_cell(Vector2i(2, 2))  # walled in
	# The cracked wall is the short way in: it walks up and hits it (STR 5 + Mt 8).
	brig.set_cell(Vector2i(7, 2))
	await EnemyAI.take_turn(brig, b)
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 7, "a charger breaks the wall in its way")
	# Units that don't break things leave it alone.
	b.map.set_terrain(Vector2i(6, 2), "x")
	brig.has_acted = false
	brig.ai = AIProfiles.resolve({"breaks": false})
	await EnemyAI.take_turn(brig, b)
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 20, "breaks: false leaves the wall alone")
	# With a Chest Key, a door is quicker: it walks up and opens it.
	brig.has_acted = false
	brig.ai = AIProfiles.resolve({})
	brig.items.append(Items.make("Chest Key"))
	lord.set_cell(Vector2i(3, 2))
	brig.set_cell(Vector2i(3, 7))
	await EnemyAI.take_turn(brig, b)
	check_eq(brig.cell, Vector2i(3, 5), "it walks to the door")
	check_eq(b.map.terrain_key(Vector2i(3, 4)), "_", "and opens it")
	check(not brig.items.any(func(it): return it.name == "Chest Key"), "using up its key")
	check_eq(b.map.tile_hp.get(Vector2i(6, 2)), 20, "the wall is left alone")
