class_name BattleInput
extends Node
## Player input: the browse/select/menu/targeting state machine (Battle.state),
## the menus, targeting and forecasts, the trade screen and the info screens. Owns
## the state of whatever the player is doing with the selected unit. What actually
## happens when a unit acts lives in BattleActions.

## Targeting modes that pick a cell (target_cells) rather than a unit (targets).
const CELL_MODES: Array[String] = ["drop", "unload", "break", "door"]

var battle: Battle

var selected: Unit
var origin_cell := Vector2i.ZERO
var reach := {}
var menu_context := ""
var targets: Array[Unit] = []
var target_index := 0
## Inventory indices behind each entry of the attack weapon menu.
var weapon_choices: Array[int] = []
## Spell names behind each entry of the magic menu.
var spell_choices: Array[String] = []
## Spell being targeted, or "" when targeting an attack.
var active_spell := ""
## What TARGETING is picking for: "attack", "spell", "dance", "trade", "shove",
## "rescue", "board", "inspire", or one of CELL_MODES.
var target_mode := "attack"
## Set once the selected unit trades or unloads; its move can no longer be undone.
var move_committed := false
## Trade screen state: the partner, cursor (x = side: 0 selected / 1 partner,
## y = slot), and the picked-up item's (side, slot), or (-1, -1) when none.
var trade_partner: Unit
var trade_cursor := Vector2i.ZERO
var trade_held := Vector2i(-1, -1)
## Cells an area spell may be centered on while in AREA_TARGET.
var area_centers: Array[Vector2i] = []
## Cells to pick from while target_mode is one of CELL_MODES.
var target_cells: Array[Vector2i] = []
## Passenger a ship is unloading, and the passengers behind the Unload menu's entries.
var unload_passenger: Unit
var passenger_choices: Array[Unit] = []
## Unit (either side) under the cursor while browsing, whose ranges are shown, or null.
var hovered: Unit
## Planned path for the selected unit; follows the cursor's trail when it can.
var arrow: Array[Vector2i] = []
## Unit shown on the stats screen, and the state to return to when it closes.
var status_unit: Unit
var status_return_state := Battle.State.IDLE


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if battle.state == Battle.State.BUSY:
		return
	var dir := _dir_from(event)
	var accept := event.is_action_pressed("confirm")
	var cancel := event.is_action_pressed("cancel")
	var danger := event.is_action_pressed("danger_zone")
	var info := event.is_action_pressed("unit_info")
	var next := event.is_action_pressed("next_unit")
	if dir == Vector2i.ZERO and not accept and not cancel and not danger and not info and not next:
		return
	get_viewport().set_input_as_handled()

	# Map-view shortcuts, available while browsing or choosing where to move.
	if battle.state == Battle.State.IDLE or battle.state == Battle.State.SELECTED:
		if danger:
			battle.danger_on = not battle.danger_on
			battle.refresh_threat()
			return
		if info:
			var u := battle.unit_at(battle.cursor.cell)
			if u:
				open_status(u)
			return

	match battle.state:
		Battle.State.IDLE:
			if next:
				jump_to_next_unit()
			elif dir != Vector2i.ZERO:
				move_cursor(dir)
			elif accept:
				var u := battle.unit_at(battle.cursor.cell)
				if u and u.team == Unit.Team.PLAYER and not u.has_acted:
					select(u)
				elif u and u.team != Unit.Team.PLAYER:
					toggle_mark(u)
				elif u == null:
					battle.ui.hide_info()
					var options: Array[String] = ["Units", "Objective", "Options", "Suspend", "Restart", "Level Select", "End Turn"]
					_open_menu("map", options)
		Battle.State.SELECTED:
			if dir != Vector2i.ZERO:
				move_cursor(dir)
				update_arrow(battle.cursor.cell)
			elif accept and reach.cells.has(battle.cursor.cell):
				move_selected(battle.cursor.cell)
			elif cancel:
				battle.map.clear_ranges()
				battle.cursor.cell = selected.cell
				selected = null
				battle.state = Battle.State.IDLE
				refresh_info()
		Battle.State.UNIT_LIST:
			var list := battle.ui.unit_list
			if dir.y != 0:
				list.move(dir.y)
			elif dir.x != 0:
				list.change_sort(dir.x)
			elif accept and list.selected_unit():
				var target := list.selected_unit()
				close_unit_list()
				battle.cursor.cell = target.cell
				refresh_info()
			elif info and list.selected_unit():
				open_status(list.selected_unit())
			elif cancel:
				close_unit_list()
		Battle.State.OPTIONS:
			if dir.y != 0:
				battle.ui.options_screen.move(dir.y)
			elif dir.x != 0:
				battle.ui.options_screen.change(dir.x)
			elif accept or cancel:
				battle.ui.options_screen.close()
				battle.state = Battle.State.IDLE
				refresh_info()
		Battle.State.OBJECTIVE:
			if accept or cancel:
				battle.ui.hide_objective()
				battle.state = Battle.State.IDLE
				refresh_info()
		Battle.State.STATUS:
			# Browsing: Up/Down = unit, Left/Right = page, D = detail mode, X = close.
			# Detail mode: arrows move the highlight, D or X go back to browsing.
			var screen := battle.ui.status_screen
			if screen.detail:
				if dir != Vector2i.ZERO:
					screen.move_detail(dir)
				elif info or cancel:
					screen.exit_detail()
			elif dir.y != 0:
				cycle_status(dir.y)
			elif dir.x != 0:
				screen.change_page(dir.x)
			elif info:
				screen.enter_detail()
			elif cancel:
				close_status()
		Battle.State.MENU:
			if dir.y != 0:
				battle.ui.menu_move(dir.y)
			elif accept:
				battle.ui.hide_menu()
				menu_accept()
			elif cancel:
				battle.ui.hide_menu()
				menu_cancel()
		Battle.State.TARGETING:
			if dir != Vector2i.ZERO:
				var step := 1 if dir.x + dir.y > 0 else -1
				var count := target_cells.size() if target_mode in CELL_MODES else targets.size()
				target_index = wrapi(target_index + step, 0, count)
				show_target()
			elif accept:
				battle.ui.hide_forecast()
				if target_mode == "trade":
					open_trade(targets[target_index])
					return
				battle.state = Battle.State.BUSY
				if target_mode == "unload":
					# Unloading doesn't end the ship's turn, but commits its move.
					await battle.actions.do_unload(selected, unload_passenger, target_cells[target_index])
					move_committed = true
					open_unit_menu()
					return
				if target_mode == "drop":
					await battle.actions.do_drop(selected, target_cells[target_index])
				elif target_mode == "break":
					await battle.actions.do_break(selected, target_cells[target_index])
				elif target_mode == "door":
					await battle.actions.do_open_door(selected, target_cells[target_index])
				elif target_mode == "rescue":
					await battle.actions.do_rescue(selected, targets[target_index])
				elif target_mode == "dance":
					await battle.actions.do_dance(selected, targets[target_index])
				elif target_mode == "board":
					await battle.actions.do_board(selected, targets[target_index])
				elif target_mode == "inspire":
					await battle.actions.do_inspire(selected)
				elif target_mode == "shove":
					await battle.actions.do_shove(selected, targets[target_index])
				elif active_spell and Spells.is_support(active_spell):
					await battle.actions.cast_heal(selected, targets[target_index], active_spell)
				elif active_spell:
					await battle.actions.do_spell_attack(selected, targets[target_index], active_spell)
				else:
					await battle.actions.do_combat(selected, targets[target_index])
				finish_action()
			elif cancel:
				battle.ui.hide_forecast()
				battle.map.clear_ranges()
				battle.cursor.cell = selected.cell
				match target_mode:
					"attack":
						open_attack_menu()
					"spell":
						open_magic_menu()
					_:
						open_unit_menu()
		Battle.State.AREA_TARGET:
			if dir != Vector2i.ZERO:
				if area_centers.has(battle.cursor.cell + dir):
					battle.cursor.cell += dir
					show_area_preview()
			elif accept:
				if Spells.can_cast_at(selected, active_spell, battle.cursor.cell, battle.units(), battle.map):
					battle.ui.hide_forecast()
					battle.state = Battle.State.BUSY
					await battle.actions.cast_area(selected, battle.cursor.cell, active_spell)
					finish_action()
			elif cancel:
				battle.ui.hide_forecast()
				battle.map.clear_ranges()
				battle.cursor.cell = selected.cell
				open_magic_menu()
		Battle.State.TRADE:
			if dir != Vector2i.ZERO:
				trade_move(dir)
			elif accept:
				trade_accept()
			elif cancel:
				trade_cancel()
		Battle.State.GAME_OVER:
			if Campaign.active:
				if accept:
					battle.phases.continue_campaign()
				elif cancel:
					Campaign.active = false
					get_tree().change_scene_to_file(Battle.LEVEL_SELECT_SCENE)
			elif accept:
				get_tree().reload_current_scene()
			elif cancel:
				get_tree().change_scene_to_file(Battle.LEVEL_SELECT_SCENE)


func _dir_from(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_left", true):
		return Vector2i.LEFT
	if event.is_action_pressed("ui_right", true):
		return Vector2i.RIGHT
	if event.is_action_pressed("ui_up", true):
		return Vector2i.UP
	if event.is_action_pressed("ui_down", true):
		return Vector2i.DOWN
	return Vector2i.ZERO


func move_cursor(dir: Vector2i) -> void:
	battle.cursor.cell = (battle.cursor.cell + dir).clamp(Vector2i.ZERO, Vector2i(battle.map.cols - 1, battle.map.rows - 1))
	refresh_info()


## Moves the cursor to the next player unit that hasn't acted, in roster order,
## wrapping around (FE's L button).
func jump_to_next_unit() -> void:
	var waiting: Array[Unit] = []
	for u in battle.units_of(Unit.Team.PLAYER):
		if not u.has_acted:
			waiting.append(u)
	if waiting.is_empty():
		return
	var i := waiting.find(battle.unit_at(battle.cursor.cell))
	battle.cursor.cell = waiting[(i + 1) % waiting.size()].cell
	refresh_info()


## End Turn with units still waiting asks first; Cancel is selected by default.
func confirm_end_turn() -> void:
	var waiting := 0
	for u in battle.units_of(Unit.Team.PLAYER):
		if not u.has_acted:
			waiting += 1
	if waiting == 0 or not Settings.value("end_turn_warning"):
		battle.phases.end_player_phase()
		return
	var options: Array[String] = ["Cancel", "End Turn"]
	_open_menu("end_turn", options, "End turn? %d unit%s %s acted" % [
		waiting, "" if waiting == 1 else "s", "hasn't" if waiting == 1 else "haven't"])


func refresh_info() -> void:
	battle.ui.update_info(battle.unit_at(battle.cursor.cell), battle.map.terrain_at(battle.cursor.cell), battle.cursor.cell,
		battle.map.tile_hp.get(battle.cursor.cell, -1))
	update_hover()


# --- Selecting and moving -----------------------------------------------------

func select(u: Unit) -> void:
	selected = u
	move_committed = false
	origin_cell = u.cell
	reach = battle.map.get_reachable(u, battle.units())
	show_unit_ranges(u, reach)
	arrow = [u.cell]
	battle.map.arrow_path = arrow.duplicate()
	battle.state = Battle.State.SELECTED
	refresh_info()


## Shows a unit's move (blue), attack (red) and support (green) ranges.
func show_unit_ranges(u: Unit, unit_reach: Dictionary) -> void:
	battle.map.show_ranges(unit_reach.cells.keys(), battle.map.get_attack_cells(unit_reach.cells, battle.offense_ranges(u)),
		battle.map.get_attack_cells(unit_reach.cells, u.spell_ranges(true)))


## Extends the arrow along the cursor's trail if that stays a legal path within
## MOV; otherwise falls back to the shortest path. Hidden while out of range.
func update_arrow(target: Vector2i) -> void:
	if target != selected.cell and not reach.parents.has(target):
		arrow = []
	elif arrow.has(target):
		arrow = arrow.slice(0, arrow.find(target) + 1)
	elif not arrow.is_empty() and BattleMap.distance(arrow[-1], target) == 1 \
			and path_cost(arrow) + battle.map.move_cost(target, selected.move_type) <= selected.mov:
		arrow.append(target)
	else:
		arrow = battle.map.build_path(reach.parents, selected.cell, target)
	battle.map.arrow_path = arrow.duplicate()


func path_cost(path: Array[Vector2i]) -> float:
	var total := 0.0
	for c in path.slice(1):
		total += battle.map.move_cost(c, selected.move_type)
	return total


func move_selected(dest: Vector2i) -> void:
	battle.state = Battle.State.BUSY
	battle.map.clear_ranges()
	battle.ui.hide_info()
	var path := arrow if not arrow.is_empty() and arrow[-1] == dest \
		else battle.map.build_path(reach.parents, selected.cell, dest)
	await selected.move_along(path)
	open_unit_menu()


func finish_action() -> void:
	if is_instance_valid(selected) and selected.hp > 0:
		selected.has_acted = true
		battle.cursor.cell = selected.cell
	selected = null
	battle.map.clear_ranges()
	battle.refresh_threat()
	if battle.phases.check_game_over():
		return
	var all_acted := battle.units_of(Unit.Team.PLAYER).all(func(u: Unit) -> bool: return u.has_acted)
	if all_acted and Settings.value("auto_end_turn"):
		battle.phases.end_player_phase()
		return
	battle.state = Battle.State.IDLE
	refresh_info()


# --- Map info: unit ranges, marks, stats screen, unit list, objective ---------

## While browsing, shows the move/attack ranges of whichever unit is under the cursor.
func update_hover() -> void:
	if battle.state != Battle.State.IDLE:
		return
	hovered = battle.unit_at(battle.cursor.cell)
	if not hovered:
		battle.map.clear_ranges()
	elif hovered.team == Unit.Team.ENEMY:
		# Enemies show where their behavior lets them act (a boss: just its tile).
		var parents: Dictionary = battle.map.get_reachable(hovered, battle.units()).parents
		show_unit_ranges(hovered, {"cells": EnemyAI.movement_cells(hovered, battle), "parents": parents})
	else:
		show_unit_ranges(hovered, battle.map.get_reachable(hovered, battle.units()))


## Z on an enemy adds/removes its threat from the red overlay.
func toggle_mark(u: Unit) -> void:
	if battle.marked.has(u):
		battle.marked.erase(u)
	else:
		battle.marked.append(u)
	battle.refresh_threat()


func open_status(u: Unit) -> void:
	status_return_state = battle.state
	status_unit = u
	battle.state = Battle.State.STATUS
	battle.ui.hide_info()
	battle.ui.show_status(u)


## Up/Down flips through the shown unit's side, in roster order.
func cycle_status(step: int) -> void:
	var side := battle.units_of(status_unit.team)
	status_unit = side[wrapi(side.find(status_unit) + step, 0, side.size())]
	battle.ui.show_status(status_unit)


func close_status() -> void:
	battle.ui.hide_status()
	battle.state = status_return_state
	refresh_info()


func open_unit_list() -> void:
	battle.state = Battle.State.UNIT_LIST
	battle.ui.hide_info()
	battle.ui.unit_list.open(battle.units())


func close_unit_list() -> void:
	battle.ui.unit_list.close()
	battle.state = Battle.State.IDLE
	refresh_info()


## Map menu > Objective: win/lose conditions (levels can override the text with
## "objective" / "defeat"), the turn and how many units each side has left.
func open_objective() -> void:
	var level := Levels.get_level(Levels.selected)
	var objective := Objectives.of(level)
	var lines: Array[String] = [
		level.name,
		"Victory: " + Objectives.victory_text(objective),
		"Defeat: " + Objectives.defeat_text(objective),
		battle.turn_text(),
		"Allies %d   Enemies %d" % [battle.units_of(Unit.Team.PLAYER).size(), battle.units_of(Unit.Team.ENEMY).size()],
		"Z/X: close",
	]
	battle.state = Battle.State.OBJECTIVE
	battle.ui.show_objective(lines)


# --- Menus --------------------------------------------------------------------

func weapon_label(w: Dictionary) -> String:
	return "%s  %d" % [w.name, w.uses]


func open_unit_menu() -> void:
	var options: Array[String] = []
	var objective := Objectives.of(Levels.get_level(Levels.selected))
	if Objectives.can_seize(objective, selected):
		options.append("Seize")
	if Objectives.can_escape(objective, selected):
		options.append("Escape")
	var here := battle.map.object_at(selected.cell)
	if here.get("type", "") == "village" and here.state == "intact":
		options.append("Visit")
	if here.get("type", "") == "chest" and here.state == "intact" and battle.actions.can_open_chest(selected):
		options.append("Open")
	if not battle.actions.adjacent_doors(selected).is_empty() and battle.actions.can_open_chest(selected):
		options.append("Open Door")
	if battle.actions.can_attack_any(selected):
		options.append("Attack")
	if not battle.actions.breakable_in_reach(selected).is_empty():
		options.append("Break")
	if not battle.actions.castable_spells(selected).is_empty():
		options.append("Magic")
	if not battle.actions.dance_targets(selected).is_empty():
		options.append("Dance")
	if not battle.actions.inspire_targets(selected).is_empty():
		options.append("Inspire")
	if not battle.actions.trade_partners(selected).is_empty():
		options.append("Trade")
	if not battle.actions.shove_targets(selected).is_empty():
		options.append("Shove")
	if not battle.actions.rescue_targets(selected).is_empty():
		options.append("Rescue")
	if not battle.actions.drop_cells_for(selected).is_empty():
		options.append("Drop")
	if not battle.actions.board_targets(selected).is_empty():
		options.append("Board")
	if not battle.actions.unloadable(selected).is_empty():
		options.append("Unload")
	if not selected.items.is_empty():
		options.append("Items")
	options.append("Wait")
	_open_menu("unit", options)


## Weapon choice for Attack: only weapons that can reach an enemy are listed.
func open_attack_menu() -> void:
	var options: Array[String] = []
	weapon_choices = []
	for i in selected.items.size():
		if selected.can_wield(selected.items[i]) and not battle.actions.enemies_in_range(selected, selected.items[i]).is_empty():
			options.append(weapon_label(selected.items[i]))
			weapon_choices.append(i)
	_open_menu("attack", options)


## Break: pick a weapon that reaches a breakable tile, then the tile.
func open_break_menu() -> void:
	var options: Array[String] = []
	weapon_choices = []
	for i in selected.items.size():
		var it := selected.items[i]
		if Items.is_weapon(it) and selected.can_wield(it) and not battle.actions.breakable_cells(selected, it).is_empty():
			options.append(weapon_label(it))
			weapon_choices.append(i)
	_open_menu("break", options)


func open_magic_menu() -> void:
	spell_choices = battle.actions.castable_spells(selected)
	var options: Array[String] = []
	for s in spell_choices:
		options.append("%s  %dMP" % [s, Spells.get_spell(s).mp])
	_open_menu("magic", options)


## Inventory view. Picking a weapon equips it (does not end the unit's turn);
## picking a usable consumable uses it (ends the turn). Weapons the unit's class
## can't wield are marked (x).
func open_items_menu() -> void:
	var options: Array[String] = []
	var equipped := selected.equipped_index()
	for i in selected.items.size():
		var item := selected.items[i]
		var mark := ""
		if i == equipped:
			mark = "  (E)"
		elif Items.is_weapon(item) and not selected.can_wield(item):
			mark = "  (x)"
		options.append(weapon_label(item) + mark)
	_open_menu("items", options)


## Picks which passenger to unload (skipped when there's only one).
func open_unload_menu() -> void:
	passenger_choices = battle.actions.unloadable(selected)
	if passenger_choices.size() == 1:
		start_unload_targeting(passenger_choices[0])
		return
	var options: Array[String] = []
	for p in passenger_choices:
		options.append(p.unit_name)
	_open_menu("unload", options)


func _open_menu(context: String, options: Array[String], title := "") -> void:
	menu_context = context
	battle.ui.show_menu(options, selected.cell if selected else battle.cursor.cell, title)
	battle.state = Battle.State.MENU


func menu_accept() -> void:
	match menu_context:
		"end_turn":
			if battle.ui.menu_choice() == "End Turn":
				battle.phases.end_player_phase()
			else:
				battle.state = Battle.State.IDLE
				refresh_info()
		"restart":
			if battle.ui.menu_choice() == "Restart":
				get_tree().reload_current_scene()
			else:
				battle.state = Battle.State.IDLE
				refresh_info()
		"quit":
			if battle.ui.menu_choice() == "Quit":
				Campaign.active = false
				get_tree().change_scene_to_file(Battle.LEVEL_SELECT_SCENE)
			else:
				battle.state = Battle.State.IDLE
				refresh_info()
		"map":
			match battle.ui.menu_choice():
				"End Turn":
					confirm_end_turn()
				"Units":
					open_unit_list()
				"Objective":
					open_objective()
				"Options":
					battle.state = Battle.State.OPTIONS
					battle.ui.options_screen.open()
				"Suspend":
					battle.phases.suspend()
				"Restart":
					var options: Array[String] = ["Cancel", "Restart"]
					_open_menu("restart", options, "Restart this map?")
				"Level Select":
					var options: Array[String] = ["Cancel", "Quit"]
					_open_menu("quit", options, "Quit to the level select?\nProgress on this map is lost.")
		"unit":
			match battle.ui.menu_choice():
				"Seize":
					_act(battle.actions.do_seize.bind(selected))
				"Escape":
					_act(battle.actions.do_escape.bind(selected))
				"Visit":
					_act(battle.actions.do_visit.bind(selected))
				"Open":
					_act(battle.actions.do_open.bind(selected))
				"Attack":
					open_attack_menu()
				"Break":
					open_break_menu()
				"Open Door":
					start_cell_targeting("door", battle.actions.adjacent_doors(selected))
				"Magic":
					open_magic_menu()
				"Dance":
					start_unit_targeting("dance", battle.actions.dance_targets(selected))
				"Inspire":
					start_unit_targeting("inspire", [selected])
				"Board":
					start_unit_targeting("board", battle.actions.board_targets(selected))
				"Unload":
					open_unload_menu()
				"Trade":
					start_unit_targeting("trade", battle.actions.trade_partners(selected))
				"Shove":
					start_unit_targeting("shove", battle.actions.shove_targets(selected))
				"Rescue":
					start_unit_targeting("rescue", battle.actions.rescue_targets(selected))
				"Drop":
					start_cell_targeting("drop", battle.actions.drop_cells_for(selected))
				"Items":
					open_items_menu()
				"Wait":
					finish_action()
		"attack":
			selected.equip(weapon_choices[battle.ui.menu_index])
			start_unit_targeting("attack", battle.actions.enemies_in_range(selected, selected.weapon))
		"break":
			selected.equip(weapon_choices[battle.ui.menu_index])
			start_cell_targeting("break", battle.actions.breakable_cells(selected, selected.weapon))
		"magic":
			start_spell_targeting(spell_choices[battle.ui.menu_index])
		"unload":
			start_unload_targeting(passenger_choices[battle.ui.menu_index])
		"items":
			var item := selected.items[battle.ui.menu_index]
			if selected.can_wield(item):
				selected.equip(battle.ui.menu_index)
				open_items_menu()
			elif Items.can_use(selected, item):
				_act(_use_item.bind(battle.ui.menu_index))
			else:
				selected.popup("Can't use", Color.LIGHT_GRAY)
				open_items_menu()


## Runs an action that ends the selected unit's turn.
func _act(action: Callable) -> void:
	battle.state = Battle.State.BUSY
	await action.call()
	finish_action()


func _use_item(index: int) -> void:
	selected.use_item(index)
	await get_tree().create_timer(0.5).timeout


func menu_cancel() -> void:
	match menu_context:
		"map", "end_turn", "restart", "quit":
			battle.state = Battle.State.IDLE
			refresh_info()
		"unit":
			if move_committed:
				# Trading commits the move, as in GBA FE (and so does unloading a ship).
				open_unit_menu()
				return
			selected.set_cell(origin_cell)
			battle.cursor.cell = origin_cell
			select(selected)
		"attack", "magic", "items", "unload", "break":
			open_unit_menu()


# --- Targeting ----------------------------------------------------------------

## Picks one of `units` for `mode` ("attack", "dance", "trade", "shove", "rescue",
## "board" or "inspire").
func start_unit_targeting(mode: String, units: Array[Unit]) -> void:
	active_spell = ""
	target_mode = mode
	targets = units
	target_index = 0
	battle.state = Battle.State.TARGETING
	show_target()


func start_spell_targeting(spell_name: String) -> void:
	active_spell = spell_name
	target_mode = "spell"
	if Spells.get_spell(spell_name).target == "area":
		start_area_targeting()
		return
	targets = Spells.targets_for(selected, spell_name, battle.units())
	target_index = 0
	battle.state = Battle.State.TARGETING
	show_target()


## Picks one of `cells` for `mode` ("drop", "unload", "break" or "door").
func start_cell_targeting(mode: String, cells: Array[Vector2i]) -> void:
	active_spell = ""
	target_mode = mode
	target_cells = cells
	target_index = 0
	battle.state = Battle.State.TARGETING
	show_target()


func start_unload_targeting(passenger: Unit) -> void:
	unload_passenger = passenger
	start_cell_targeting("unload", battle.actions.landing_cells(selected, passenger))


func show_target() -> void:
	if target_mode in ["break", "door"]:
		var cell := target_cells[target_index]
		battle.cursor.cell = cell
		battle.map.show_area([], [cell])
		var tile_name: String = battle.map.terrain_at(cell).name
		if target_mode == "door":
			battle.ui.show_cell_forecast("Open Door", battle.cursor.cell)
		else:
			var hp: int = battle.map.tile_hp.get(cell, 0)
			battle.ui.show_cell_forecast("%s  HP %d -> %d" % [tile_name, hp, maxi(0, hp - battle.actions.tile_damage(selected))], battle.cursor.cell)
		return
	if target_mode in ["drop", "unload"]:
		var cell := target_cells[target_index]
		battle.cursor.cell = cell
		battle.map.show_area([], [cell])
		var passenger := selected.carrying if target_mode == "drop" else unload_passenger
		battle.ui.show_drop_forecast(passenger, battle.map.terrain_at(cell).name, battle.cursor.cell,
			"Drop" if target_mode == "drop" else "Unload")
		return
	if target_mode == "inspire":
		var allies := battle.actions.inspire_targets(selected)
		battle.cursor.cell = selected.cell
		battle.map.show_area([], allies.map(func(a: Unit) -> Vector2i: return a.cell))
		battle.ui.show_inspire_forecast(allies, Classes.inspire_bonus(selected.level), battle.cursor.cell)
		return
	var target := targets[target_index]
	battle.cursor.cell = target.cell
	if target_mode == "rescue":
		battle.map.show_area([], [target.cell])
		battle.ui.show_rescue_forecast(target, battle.cursor.cell)
	elif target_mode == "dance":
		battle.ui.show_dance_forecast(target, battle.cursor.cell)
	elif target_mode == "board":
		battle.map.show_area([], [target.cell])
		battle.ui.show_board_forecast(target, battle.cursor.cell)
	elif target_mode == "shove":
		var dest := battle.actions.shove_destination(selected, target)
		battle.map.show_area([], [dest])
		battle.ui.show_shove_forecast(target, battle.map.terrain_at(dest).name, battle.cursor.cell)
	elif target_mode == "trade":
		battle.ui.show_trade_preview(target, battle.cursor.cell)
	elif active_spell and Spells.is_support(active_spell):
		var spell := Spells.get_spell(active_spell)
		battle.ui.show_heal_forecast(selected, target, active_spell, Spells.heal_amount(selected, spell, target), battle.cursor.cell)
	elif active_spell:
		var spell := Spells.get_spell(active_spell)
		battle.ui.show_forecast(selected, target, Combat.spell_forecast(selected, target, spell, battle.map), battle.cursor.cell,
			active_spell, true)
	else:
		battle.ui.show_forecast(selected, target, Combat.forecast(selected, target, battle.map), battle.cursor.cell)


## Free cursor limited to the spell's cast range; starts on the center hitting the most enemies.
func start_area_targeting() -> void:
	area_centers = Spells.area_centers(selected, active_spell, battle.map, battle.units())
	var best := selected.cell
	var best_count := -1
	for c in area_centers:
		var count := Spells.area_targets(selected, active_spell, c, battle.units(), battle.map).size()
		if count > best_count:
			best = c
			best_count = count
	battle.cursor.cell = best
	battle.state = Battle.State.AREA_TARGET
	show_area_preview()


func current_area_victims() -> Array[Unit]:
	return Spells.area_targets(selected, active_spell, battle.cursor.cell, battle.units(), battle.map)


func show_area_preview() -> void:
	battle.map.show_area(area_centers, Spells.area_cells(active_spell, battle.cursor.cell, battle.map))
	var spell := Spells.get_spell(active_spell)
	var rows: Array = []
	for v in current_area_victims():
		rows.append([v.unit_name, v.hp, Combat.spell_damage(selected, v, spell, battle.map),
			Combat.spell_hit_chance(selected, v, spell, battle.map)])
	var note := ""
	if spell.has("terraform"):
		note = "%s -> %s" % [battle.map.terrain_at(battle.cursor.cell).name, BattleMap.TERRAIN[spell.terraform].name]
	battle.ui.show_area_forecast(selected, active_spell, rows, battle.cursor.cell, note)


# --- Trade screen -------------------------------------------------------------
# Pick an item on either side, then a slot on the other side: an occupied slot
# swaps the two items, an empty slot hands the item over. Trading never uses up
# the unit's action, so it can trade repeatedly and with several partners.

func open_trade(partner: Unit) -> void:
	trade_partner = partner
	trade_held = Vector2i(-1, -1)
	trade_cursor = Vector2i(0 if not selected.items.is_empty() else 1, 0)
	battle.cursor.cell = selected.cell
	battle.state = Battle.State.TRADE
	_refresh_trade()


func _trade_side(side: int) -> Unit:
	return selected if side == 0 else trade_partner


## Highest slot the cursor may sit on for a side: only filled slots, plus the
## first empty one when it is the drop target for a held item.
func _trade_max_slot(side: int) -> int:
	var count := _trade_side(side).items.size()
	if trade_held.x >= 0 and side != trade_held.x:
		return mini(count, Unit.MAX_ITEMS - 1)
	return count - 1


func trade_move(dir: Vector2i) -> void:
	if dir.y != 0:
		var top := _trade_max_slot(trade_cursor.x)
		trade_cursor.y = wrapi(trade_cursor.y + dir.y, 0, top + 1)
	elif trade_held.x < 0:
		var other := 1 - trade_cursor.x
		if _trade_max_slot(other) >= 0:
			trade_cursor = Vector2i(other, mini(trade_cursor.y, _trade_max_slot(other)))
	_refresh_trade()


func trade_accept() -> void:
	if trade_held.x < 0:
		# Pick up the item under the cursor and jump to the other side.
		trade_held = trade_cursor
		var other := 1 - trade_cursor.x
		trade_cursor = Vector2i(other, mini(trade_cursor.y, _trade_max_slot(other)))
	else:
		var from := _trade_side(trade_held.x).items
		var to := _trade_side(trade_cursor.x).items
		var item := from[trade_held.y]
		if trade_cursor.y < to.size():
			from[trade_held.y] = to[trade_cursor.y]
			to[trade_cursor.y] = item
		else:
			from.remove_at(trade_held.y)
			to.append(item)
		move_committed = true
		trade_held = Vector2i(-1, -1)
		# Stay on this side if it still has items, otherwise hop back.
		if _trade_max_slot(trade_cursor.x) < 0:
			trade_cursor.x = 1 - trade_cursor.x
		trade_cursor.y = mini(trade_cursor.y, _trade_max_slot(trade_cursor.x))
	_refresh_trade()


func trade_cancel() -> void:
	if trade_held.x >= 0:
		trade_cursor = trade_held
		trade_held = Vector2i(-1, -1)
		_refresh_trade()
		return
	battle.ui.hide_trade()
	selected.queue_redraw()
	trade_partner.queue_redraw()
	open_unit_menu()


func _refresh_trade() -> void:
	battle.ui.show_trade(selected, trade_partner, trade_cursor, trade_held)
