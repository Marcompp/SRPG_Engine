class_name BattleInput
extends Node
## Player input: the browse/select/menu/targeting state machine (Battle.state),
## the cursor, selecting and moving units, and the info screens. Owns the state of
## whatever the player is doing with the selected unit. Its parts, in their own
## files: the menus (BattleMenus), targeting (BattleTargeting), the trade screen
## (BattleTrade) and the prep screen's Check Map (BattleFormation). What actually
## happens when a unit acts lives in BattleActions.

## Emitted with the picked index when a `choose` prompt is answered.
signal choice_made(index: int)

var battle: Battle

var menus := BattleMenus.new(self)
var targeting := BattleTargeting.new(self)
var trade := BattleTrade.new(self)
var formation := BattleFormation.new(self)

var selected: Unit
var origin_cell := Vector2i.ZERO
var reach := {}
## Set once the selected unit trades or unloads; its move can no longer be undone.
var move_committed := false
## Unit (either side) under the cursor while browsing, whose ranges are shown, or null.
var hovered: Unit
## MOV the selected unit may spend on this move (its MOV, or what's left for Canto),
## and what its last move cost.
var move_budget := 0.0
var moved_cost := 0.0
## True while the selected unit is on its Canto move (picking where to go, or at
## the Wait menu after it): it can only wait afterwards.
var canto_move := false
## The last targeted action confirmed ("dance", "attack"...), for Footwork.
var last_action := ""
## Planned path for the selected unit; follows the cursor's trail when it can.
var arrow: Array[Vector2i] = []
## The last cell in the selected unit's reach the cursor was on: where it stands to
## act on a unit picked straight from the map, if it can from there.
var last_reach_cell := Vector2i.ZERO
## Unit picked from the map while moving (Z on an enemy or a hurt ally): after the
## move, the menu for acting on it opens with it as the target.
var quick_target: Unit
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
	var skip := event.is_action_pressed("skip")
	if dir == Vector2i.ZERO and not accept and not cancel and not danger and not info and not next and not skip:
		return
	get_viewport().set_input_as_handled()

	# Map-view shortcuts, available while browsing or choosing where to move.
	if battle.state in [Battle.State.IDLE, Battle.State.SELECTED, Battle.State.FORMATION]:
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
				if u and u.team == Unit.Team.PLAYER and not u.has_acted and not Statuses.restricts(u, "act") \
						and not Statuses.is_berserk(u):
					select(u)
				elif u and Factions.hostile(u.team, Unit.Team.PLAYER):
					toggle_mark(u)
				else:
					# An empty tile, a unit that already acted, or one that's no threat.
					open_map_menu()
		Battle.State.FORMATION:
			if next:
				jump_to_next_unit()
			elif dir != Vector2i.ZERO:
				move_cursor(dir)
			elif accept:
				formation.accept()
			elif cancel and formation.held:
				formation.drop_held()
			elif cancel:
				formation.leave()
		Battle.State.SELECTED:
			if dir != Vector2i.ZERO:
				move_cursor(dir)
				update_arrow(battle.cursor.cell)
				if reach.cells.has(battle.cursor.cell):
					last_reach_cell = battle.cursor.cell
			elif accept and reach.cells.has(battle.cursor.cell):
				move_selected(battle.cursor.cell)
			elif accept:
				var u := battle.unit_at(battle.cursor.cell)
				if u and not canto_move:
					move_to_act_on(u)
			elif cancel and canto_move:
				finish_action(true)
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
				close_unit_list()
			elif info and list.selected_unit():
				open_status(list.selected_unit())
			elif cancel:
				close_unit_list()
		Battle.State.DIALOGUE:
			if skip:
				battle.events.skip()
			elif accept:
				battle.ui.dialogue.advance()
		Battle.State.CHOICE:
			if dir.y != 0:
				battle.ui.menu_move(dir.y)
			elif accept or cancel:
				battle.ui.hide_menu()
				choice_made.emit(battle.ui.menu_index if accept else battle.ui.menu_options.size() - 1)
		Battle.State.OPTIONS:
			if dir.y != 0:
				battle.ui.options_screen.move(dir.y)
			elif dir.x != 0:
				battle.ui.options_screen.change(dir.x)
			elif accept or cancel:
				battle.ui.options_screen.close()
				browse()
		Battle.State.OBJECTIVE:
			if accept or cancel:
				battle.ui.hide_objective()
				browse()
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
				menus.accept()
			elif cancel:
				battle.ui.hide_menu()
				menus.cancel()
		Battle.State.TARGETING:
			if dir != Vector2i.ZERO:
				targeting.step(dir)
			elif accept:
				targeting.accept()
			elif cancel:
				targeting.cancel()
		Battle.State.AREA_TARGET:
			if dir != Vector2i.ZERO:
				targeting.area_move(dir)
			elif accept:
				targeting.area_accept()
			elif cancel:
				targeting.area_cancel()
		Battle.State.TRADE:
			if dir != Vector2i.ZERO:
				trade.move(dir)
			elif accept:
				trade.accept()
			elif cancel:
				trade.cancel()
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
## wrapping around (FE's L button). On another side's unit, goes to the next unit
## of that side instead.
func jump_to_next_unit() -> void:
	var here := battle.unit_at(battle.cursor.cell)
	var units: Array[Unit] = []
	if here and here.team != Unit.Team.PLAYER:
		units = battle.units_of(here.team)
	else:
		for u in battle.units_of(Unit.Team.PLAYER):
			if not u.has_acted:
				units.append(u)
	if units.is_empty():
		return
	var i := units.find(here)
	battle.cursor.cell = units[(i + 1) % units.size()].cell
	refresh_info()


func open_map_menu() -> void:
	battle.ui.hide_info()
	var options: Array[String] = ["Units", "Objective", "Options", "Suspend", "Restart", "Level Select", "End Turn"]
	if battle.phases.can_rewind():
		options.insert(3, "Rewind")
	menus.open("map", options)


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
	menus.open("end_turn", options, "End turn? %d unit%s %s acted" % [
		waiting, "" if waiting == 1 else "s", "hasn't" if waiting == 1 else "haven't"])


## Asks the player to pick one of `options` mid-action (e.g. which skill to forget)
## and returns its index. Cancel picks the last option, so make that the safe one.
func choose(options: Array[String], title: String) -> int:
	var previous := battle.state
	battle.state = Battle.State.CHOICE
	battle.ui.show_menu(options, battle.cursor.cell, title)
	var index: int = await choice_made
	battle.state = previous
	return index


func refresh_info() -> void:
	battle.ui.update_info(battle.unit_at(battle.cursor.cell), battle.map.terrain_at(battle.cursor.cell), battle.cursor.cell,
		battle.map.tile_hp.get(battle.cursor.cell, -1))
	update_hover()


# --- Selecting and moving -----------------------------------------------------

func select(u: Unit) -> void:
	selected = u
	move_committed = false
	quick_target = null
	origin_cell = u.cell
	move_budget = u.mov
	moved_cost = 0.0
	reach = battle.map.get_reachable(u, battle.units())
	show_unit_ranges(u, reach)
	_start_path()


## Shows a unit's move (blue), attack (red) and support (green) ranges.
func show_unit_ranges(u: Unit, unit_reach: Dictionary) -> void:
	battle.map.show_ranges(unit_reach.cells.keys(), battle.map.get_attack_cells(unit_reach.cells, battle.offense_ranges(u)),
		battle.map.get_attack_cells(unit_reach.cells, u.spell_ranges(true)))


## Starts picking where the selected unit moves (SELECTED), from where it stands.
func _start_path() -> void:
	arrow = [selected.cell]
	battle.map.arrow_path = arrow.duplicate()
	last_reach_cell = selected.cell
	battle.cursor.cell = selected.cell
	battle.state = Battle.State.SELECTED
	refresh_info()


## Extends the arrow along the cursor's trail if that stays a legal path within
## MOV; otherwise falls back to the shortest path. Hidden while out of range.
func update_arrow(target: Vector2i) -> void:
	if target != selected.cell and not reach.parents.has(target):
		arrow = []
	elif arrow.has(target):
		arrow = arrow.slice(0, arrow.find(target) + 1)
	elif not arrow.is_empty() and BattleMap.distance(arrow[-1], target) == 1 \
			and path_cost(arrow) + battle.map.unit_cost(selected, target) <= move_budget:
		arrow.append(target)
	else:
		arrow = battle.map.build_path(reach.parents, selected.cell, target)
	battle.map.arrow_path = arrow.duplicate()


func path_cost(path: Array[Vector2i]) -> float:
	var total := 0.0
	for c in path.slice(1):
		total += battle.map.unit_cost(selected, c)
	return total


func move_selected(dest: Vector2i) -> void:
	battle.state = Battle.State.BUSY
	battle.map.clear_ranges()
	battle.ui.hide_info()
	var path := arrow if not arrow.is_empty() and arrow[-1] == dest \
		else battle.map.build_path(reach.parents, selected.cell, dest)
	moved_cost = path_cost(path)
	await selected.move_along(path)
	# An area event's scene commits the move (it can't be undone after a cutscene).
	if await battle.events.on_area(selected):
		move_committed = true
		if not is_instance_valid(selected) or selected.hp <= 0 or selected.team != Unit.Team.PLAYER:
			finish_action(true)
			return
	if canto_move:
		menus.open_canto_menu()
	elif quick_target:
		_open_quick_menu()
	else:
		menus.open_unit_menu()


## X at the unit menu: back to where it started its move, picking where to go again.
func undo_move() -> void:
	selected.set_cell(origin_cell)
	if canto_move:
		_pick_canto_move()
	else:
		select(selected)


## Z on a unit while picking where to move: an enemy to attack, or a hurt ally
## to heal. Moves to a cell it can do that from (the last cell in its reach the
## cursor was on, if it can from there; otherwise the nearest one to it), then
## opens the menu for it with that unit as the target. Does nothing if no cell works.
func move_to_act_on(u: Unit) -> void:
	var cells := quick_cells(selected, u)
	if cells.is_empty():
		return
	var dest: Vector2i = cells[0]
	for c in cells:
		var closer := BattleMap.distance(c, last_reach_cell) < BattleMap.distance(dest, last_reach_cell)
		var as_close := BattleMap.distance(c, last_reach_cell) == BattleMap.distance(dest, last_reach_cell)
		if closer or (as_close and reach.cells[c] < reach.cells[dest]):
			dest = c
	quick_target = u
	update_arrow(dest)
	move_selected(dest)


## Cells in the selected unit's reach from which it could act on `target`: hit it
## with a weapon or an attack spell (a foe), or heal it (a hurt ally).
func quick_cells(u: Unit, target: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in reach.cells:
		if _can_act_on_from(u, target, BattleMap.distance(c, target.cell)):
			result.append(c)
	return result


func _can_act_on_from(u: Unit, target: Unit, dist: int) -> bool:
	var foe := Factions.hostile(u.team, target.team)
	if foe:
		for w in u.weapons():
			if u.reaches(w, dist):
				return true
	elif target.team != u.team or target.hp >= target.max_hp:
		return false
	for s in u.spells if u.can_use_magic() else []:
		var spell := Spells.get_spell(s)
		var wanted := "enemy" if foe else "ally"
		if spell.target == wanted and Spells.can_afford(u, s) and Spells.reaches(s, dist, u):
			return true
	return false


## After a move to act on `quick_target`: its weapon menu (a foe in weapon range)
## or the magic menu, which then target it first. The unit menu if neither fits now.
func _open_quick_menu() -> void:
	var target := quick_target
	quick_target = null
	targeting.preferred = target
	if not battle.units().has(target):
		menus.open_unit_menu()
	elif Factions.hostile(selected.team, target.team) and selected.weapons().any(func(w: Dictionary) -> bool:
			return selected.reaches(w, BattleMap.distance(selected.cell, target.cell))):
		menus.open_attack_menu()
	elif battle.actions.castable_spells(selected).any(func(s: String) -> bool:
			return Spells.targets_for(selected, s, battle.units()).has(target)):
		menus.open_magic_menu()
	else:
		menus.open_unit_menu()


## Ends the selected unit's action. Galeforce-style skills let it act again; Canto
## lets it move with the MOV it has left, unless `no_canto` (it waited, or that
## was its Canto move).
func finish_action(no_canto := false) -> void:
	if canto_move:
		no_canto = true
		canto_move = false
	if is_instance_valid(selected) and selected.hp > 0:
		if selected.refresh_pending:
			selected.refresh_pending = false
			battle.cursor.cell = selected.cell
		elif not no_canto and _start_canto():
			return
		else:
			selected.has_acted = true
			battle.cursor.cell = selected.cell
	selected = null
	quick_target = null
	targeting.preferred = null
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


## Canto: if the selected unit can still move somewhere with the MOV left, lets
## the player pick where (SELECTED, with only movement shown), then Wait. Returns
## whether it did.
func _start_canto() -> bool:
	var rules := Skills.map_rules(selected)
	var allowed := rules.has("canto") or (rules.has("footwork") and last_action == "dance")
	last_action = ""
	# Not once it has left the map (Escape) or been picked up.
	if not allowed or selected.escaped or selected.carried_by or battle.phases.check_game_over():
		return false
	var left := move_budget - moved_cost
	if battle.map.get_reachable(selected, battle.units(), left).cells.size() <= 1:
		return false
	canto_move = true
	move_committed = false
	move_budget = left
	origin_cell = selected.cell
	_pick_canto_move()
	selected.popup("Canto", Color.LIGHT_SKY_BLUE)
	return true


func _pick_canto_move() -> void:
	moved_cost = 0.0
	reach = battle.map.get_reachable(selected, battle.units(), move_budget)
	battle.map.show_ranges(reach.cells.keys(), [])
	_start_path()


# --- Map info: unit ranges, marks, stats screen, unit list, objective ---------

## Back to looking around the map: the player phase, or Check Map before the battle.
func browse() -> void:
	battle.state = Battle.State.FORMATION if formation.active else Battle.State.IDLE
	refresh_info()


## While browsing, shows the move/attack ranges of whichever unit is under the cursor.
func update_hover() -> void:
	if battle.state != Battle.State.IDLE and battle.state != Battle.State.FORMATION:
		return
	hovered = battle.unit_at(battle.cursor.cell)
	if not hovered:
		battle.map.clear_ranges()
	elif hovered.team != Unit.Team.PLAYER:
		# AI units show where their behavior lets them act (a boss: just its tile).
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


## Back to where the stats screen was opened from, on the unit it was flipped to
## (the cursor goes to it while browsing; the unit list selects it).
func close_status() -> void:
	battle.ui.hide_status()
	battle.state = status_return_state
	if status_return_state == Battle.State.UNIT_LIST:
		battle.ui.unit_list.select_unit(status_unit)
		return
	if status_return_state in [Battle.State.IDLE, Battle.State.FORMATION] and battle.units().has(status_unit):
		battle.cursor.cell = status_unit.cell
	refresh_info()


func open_unit_list() -> void:
	battle.state = Battle.State.UNIT_LIST
	battle.ui.hide_info()
	battle.ui.unit_list.open(battle.units())


## Closes the list with the cursor on the unit selected in it.
func close_unit_list() -> void:
	var list := battle.ui.unit_list
	var target := list.selected_unit()
	list.close()
	if target and battle.units().has(target):
		battle.cursor.cell = target.cell
	browse()


## "Player 5  Enemy 7  Ally 2": units left on each side that has any.
func _side_counts() -> String:
	var parts: Array[String] = []
	for side in Factions.PHASE_ORDER:
		var count := battle.units_of(side).size()
		if count > 0:
			parts.append("%s %d" % [Factions.NAMES[side], count])
	return "  ".join(parts)


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
		_side_counts(),
		"Z/X: close",
	]
	battle.state = Battle.State.OBJECTIVE
	battle.ui.show_objective(lines)
