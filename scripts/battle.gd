extends Node2D
## Battle controller: spawns units, runs the turn loop and routes input.

enum State { IDLE, SELECTED, MENU, TARGETING, AREA_TARGET, TRADE, STATUS, UNIT_LIST, OBJECTIVE, OPTIONS, BUSY, GAME_OVER }

@onready var map: BattleMap = $Map
@onready var units_root: Node2D = $Units
@onready var cursor: Cursor = $Cursor
@onready var ui: BattleUI = $UI

var state := State.BUSY
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
## "rescue", "drop", "board", "unload" or "inspire".
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
## Cells the carried unit can be dropped on, while target_mode is "drop" or "unload".
var drop_cells: Array[Vector2i] = []
## Passenger a ship is unloading, and the passengers behind the Unload menu's entries.
var unload_passenger: Unit
var passenger_choices: Array[Unit] = []
## Whether the enemy danger zone overlay is shown (toggled with danger_zone).
var danger_on := false
## Unit (either side) under the cursor while browsing, whose ranges are shown, or null.
var hovered: Unit
## Enemies the player marked (Z); their threat is drawn as a red overlay.
var marked: Array[Unit] = []
## Planned path for the selected unit; follows the cursor's trail when it can.
var arrow: Array[Vector2i] = []
## Unit shown on the stats screen, and the state to return to when it closes.
var status_unit: Unit
var status_return_state := State.IDLE
## Current turn number (a turn is one player phase plus one enemy phase).
var turn := 0
## True during the enemy phase, when holding cancel fast-forwards.
var enemy_phase := false
## Set by Seize, or by the Lord's Escape: wins seize/escape objectives.
var objective_done := false
## Player units that fell this battle ({"name", "turn"}), for campaign permadeath.
var campaign_deaths: Array = []
## "victory" or "defeat" once the battle has ended.
var battle_result := ""


const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"


func _ready() -> void:
	if Levels.resume:
		Levels.resume = false
		resume_suspended()
		return
	danger_on = Settings.value("danger_zone_default")
	var level := Levels.get_level(Levels.selected)
	map.load_layout(level.layout)
	map.load_objects(level.get("objects", []), Objectives.of(level))
	if level.has("deploy"):
		deploy_army(level)
	else:
		for data in level.players:
			units_root.add_child(Unit.create(data.name, Unit.Team.PLAYER, data.cell, data))
	for data in level.enemies:
		units_root.add_child(Unit.create(data.name, Unit.Team.ENEMY, data.cell, data))
	var players := units_of(Unit.Team.PLAYER)
	cursor.cell = players[0].cell if not players.is_empty() else Vector2i.ZERO
	start_player_phase()


## Campaign chapter: the units picked in the prep screen, on the chapter's deploy
## cells in order (the Lord first).
func deploy_army(level: Dictionary) -> void:
	var cells: Array = level.deploy
	var names: Array = Campaign.deployed if not Campaign.deployed.is_empty() else Campaign.default_deployment()
	var i := 0
	for unit_name in names:
		var data := Campaign.army_unit(unit_name)
		if data.is_empty() or i >= cells.size():
			continue
		var u := SaveGame.unit_from_dict(data)
		u.team = Unit.Team.PLAYER
		u.set_cell(cells[i])
		units_root.add_child(u)
		i += 1


# --- Queries -----------------------------------------------------------------

## Every living unit, including carried and boarded ones (which are off the map).
func all_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for child in units_root.get_children():
		if child is Unit and child.hp > 0:
			result.append(child)
	return result


## Units on the map (carried units are off the map and excluded).
func units() -> Array[Unit]:
	var result: Array[Unit] = []
	for child in units_root.get_children():
		if child is Unit and child.hp > 0 and child.carried_by == null and not child.escaped:
			result.append(child)
	return result


func units_of(team: Unit.Team) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units():
		if u.team == team:
			result.append(u)
	return result


func unit_at(cell: Vector2i) -> Unit:
	for u in units():
		if u.cell == cell:
			return u
	return null


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state == State.BUSY:
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
	if state == State.IDLE or state == State.SELECTED:
		if danger:
			danger_on = not danger_on
			refresh_threat()
			return
		if info:
			var u := unit_at(cursor.cell)
			if u:
				open_status(u)
			return

	match state:
		State.IDLE:
			if next:
				jump_to_next_unit()
			elif dir != Vector2i.ZERO:
				move_cursor(dir)
			elif accept:
				var u := unit_at(cursor.cell)
				if u and u.team == Unit.Team.PLAYER and not u.has_acted:
					select(u)
				elif u and u.team != Unit.Team.PLAYER:
					toggle_mark(u)
				elif u == null:
					ui.hide_info()
					var options: Array[String] = ["Units", "Objective", "Options", "Suspend", "Restart", "Level Select", "End Turn"]
					_open_menu("map", options)
		State.SELECTED:
			if dir != Vector2i.ZERO:
				move_cursor(dir)
				update_arrow(cursor.cell)
			elif accept and reach.cells.has(cursor.cell):
				move_selected(cursor.cell)
			elif cancel:
				map.clear_ranges()
				cursor.cell = selected.cell
				selected = null
				state = State.IDLE
				refresh_info()
		State.UNIT_LIST:
			var list := ui.unit_list
			if dir.y != 0:
				list.move(dir.y)
			elif dir.x != 0:
				list.change_sort(dir.x)
			elif accept and list.selected_unit():
				var target := list.selected_unit()
				close_unit_list()
				cursor.cell = target.cell
				refresh_info()
			elif info and list.selected_unit():
				open_status(list.selected_unit())
			elif cancel:
				close_unit_list()
		State.OPTIONS:
			if dir.y != 0:
				ui.options_screen.move(dir.y)
			elif dir.x != 0:
				ui.options_screen.change(dir.x)
			elif accept or cancel:
				ui.options_screen.close()
				state = State.IDLE
				refresh_info()
		State.OBJECTIVE:
			if accept or cancel:
				ui.hide_objective()
				state = State.IDLE
				refresh_info()
		State.STATUS:
			# Browsing: Up/Down = unit, Left/Right = page, D = detail mode, X = close.
			# Detail mode: arrows move the highlight, D or X go back to browsing.
			var screen := ui.status_screen
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
		State.MENU:
			if dir.y != 0:
				ui.menu_move(dir.y)
			elif accept:
				ui.hide_menu()
				menu_accept()
			elif cancel:
				ui.hide_menu()
				menu_cancel()
		State.TARGETING:
			if dir != Vector2i.ZERO:
				var step := 1 if dir.x + dir.y > 0 else -1
				var count := drop_cells.size() if target_mode in ["drop", "unload", "break", "door"] else targets.size()
				target_index = wrapi(target_index + step, 0, count)
				show_target()
			elif accept:
				ui.hide_forecast()
				if target_mode == "trade":
					open_trade(targets[target_index])
					return
				state = State.BUSY
				if target_mode == "unload":
					# Unloading doesn't end the ship's turn, but commits its move.
					await do_unload(selected, unload_passenger, drop_cells[target_index])
					move_committed = true
					open_unit_menu()
					return
				if target_mode == "drop":
					await do_drop(selected, drop_cells[target_index])
				elif target_mode == "break":
					await do_break(selected, drop_cells[target_index])
				elif target_mode == "door":
					await do_open_door(selected, drop_cells[target_index])
				elif target_mode == "rescue":
					await do_rescue(selected, targets[target_index])
				elif target_mode == "dance":
					await do_dance(selected, targets[target_index])
				elif target_mode == "board":
					await do_board(selected, targets[target_index])
				elif target_mode == "inspire":
					await do_inspire(selected)
				elif target_mode == "shove":
					await do_shove(selected, targets[target_index])
				elif active_spell and Spells.is_support(active_spell):
					await cast_heal(selected, targets[target_index], active_spell)
				elif active_spell:
					await do_spell_attack(selected, targets[target_index], active_spell)
				else:
					await do_combat(selected, targets[target_index])
				finish_action()
			elif cancel:
				ui.hide_forecast()
				map.clear_ranges()
				cursor.cell = selected.cell
				if target_mode in ["dance", "trade", "shove", "rescue", "drop", "board", "unload", "inspire", "break", "door"]:
					open_unit_menu()
				elif active_spell:
					open_magic_menu()
				else:
					open_attack_menu()
		State.AREA_TARGET:
			if dir != Vector2i.ZERO:
				if area_centers.has(cursor.cell + dir):
					cursor.cell += dir
					show_area_preview()
			elif accept:
				if Spells.can_cast_at(selected, active_spell, cursor.cell, units(), map):
					ui.hide_forecast()
					state = State.BUSY
					await cast_area(selected, cursor.cell, active_spell)
					finish_action()
			elif cancel:
				ui.hide_forecast()
				map.clear_ranges()
				cursor.cell = selected.cell
				open_magic_menu()
		State.TRADE:
			if dir != Vector2i.ZERO:
				trade_move(dir)
			elif accept:
				trade_accept()
			elif cancel:
				trade_cancel()
		State.GAME_OVER:
			if Campaign.active:
				if accept:
					continue_campaign()
				elif cancel:
					Campaign.active = false
					get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
			elif accept:
				get_tree().reload_current_scene()
			elif cancel:
				get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


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
	cursor.cell = (cursor.cell + dir).clamp(Vector2i.ZERO, Vector2i(map.cols - 1, map.rows - 1))
	refresh_info()


## Game speed comes from Options; holding cancel during the enemy phase multiplies
## it by the fast-forward speed (also from Options).
func _process(_delta: float) -> void:
	var ff: float = Settings.value("fast_forward_speed") if enemy_phase and Input.is_action_pressed("cancel") else 1.0
	var speed: float = Settings.value("game_speed") * ff
	if Engine.time_scale != speed:
		Engine.time_scale = speed
		ui.show_fast_forward(ff)


func _exit_tree() -> void:
	# Leaving mid-fast-forward (restart, level select) must not keep the game sped up.
	Engine.time_scale = 1.0


## Moves the cursor to the next player unit that hasn't acted, in roster order,
## wrapping around (FE's L button).
func jump_to_next_unit() -> void:
	var waiting: Array[Unit] = []
	for u in units_of(Unit.Team.PLAYER):
		if not u.has_acted:
			waiting.append(u)
	if waiting.is_empty():
		return
	var i := waiting.find(unit_at(cursor.cell))
	cursor.cell = waiting[(i + 1) % waiting.size()].cell
	refresh_info()


## End Turn with units still waiting asks first; Cancel is selected by default.
func confirm_end_turn() -> void:
	var waiting := 0
	for u in units_of(Unit.Team.PLAYER):
		if not u.has_acted:
			waiting += 1
	if waiting == 0 or not Settings.value("end_turn_warning"):
		end_player_phase()
		return
	var options: Array[String] = ["Cancel", "End Turn"]
	_open_menu("end_turn", options, "End turn? %d unit%s %s acted" % [
		waiting, "" if waiting == 1 else "s", "hasn't" if waiting == 1 else "haven't"])


func refresh_info() -> void:
	ui.update_info(unit_at(cursor.cell), map.terrain_at(cursor.cell), cursor.cell,
		map.tile_hp.get(cursor.cell, -1))
	update_hover()


# --- Player actions ----------------------------------------------------------

## Weapon ranges plus offensive spell reach. Spells the unit can't afford are
## skipped when `affordable_only` (used for enemy threat, which must be accurate).
func offense_ranges(u: Unit, affordable_only := false) -> Array[Vector2i]:
	var offense := u.weapon_ranges()
	for s in u.spells:
		if Spells.is_support(s) or (affordable_only and not Spells.can_afford(u, s)):
			continue
		var r := Spells.reach_ranges(s)
		if not offense.has(r):
			offense.append(r)
	return offense


## Shows a unit's move (blue), attack (red) and support (green) ranges.
func show_unit_ranges(u: Unit, unit_reach: Dictionary) -> void:
	map.show_ranges(unit_reach.cells.keys(), map.get_attack_cells(unit_reach.cells, offense_ranges(u)),
		map.get_attack_cells(unit_reach.cells, u.spell_ranges(true)))


func select(u: Unit) -> void:
	selected = u
	move_committed = false
	origin_cell = u.cell
	reach = map.get_reachable(u, units())
	show_unit_ranges(u, reach)
	arrow = [u.cell]
	map.arrow_path = arrow.duplicate()
	state = State.SELECTED
	refresh_info()


## Extends the arrow along the cursor's trail if that stays a legal path within
## MOV; otherwise falls back to the shortest path. Hidden while out of range.
func update_arrow(target: Vector2i) -> void:
	if target != selected.cell and not reach.parents.has(target):
		arrow = []
	elif arrow.has(target):
		arrow = arrow.slice(0, arrow.find(target) + 1)
	elif not arrow.is_empty() and BattleMap.distance(arrow[-1], target) == 1 \
			and path_cost(arrow) + map.move_cost(target, selected.move_type) <= selected.mov:
		arrow.append(target)
	else:
		arrow = map.build_path(reach.parents, selected.cell, target)
	map.arrow_path = arrow.duplicate()


func path_cost(path: Array[Vector2i]) -> float:
	var total := 0.0
	for c in path.slice(1):
		total += map.move_cost(c, selected.move_type)
	return total


func move_selected(dest: Vector2i) -> void:
	state = State.BUSY
	map.clear_ranges()
	ui.hide_info()
	var path := arrow if not arrow.is_empty() and arrow[-1] == dest \
		else map.build_path(reach.parents, selected.cell, dest)
	await selected.move_along(path)
	open_unit_menu()


# --- Map info: enemy ranges, danger zone, stats screen -----------------------

## While browsing, shows the move/attack ranges of whichever unit is under the cursor.
func update_hover() -> void:
	if state != State.IDLE:
		return
	hovered = unit_at(cursor.cell)
	if not hovered:
		map.clear_ranges()
	elif hovered.team == Unit.Team.ENEMY:
		# Enemies show where their behavior lets them act (a boss: just its tile).
		var parents: Dictionary = map.get_reachable(hovered, units()).parents
		show_unit_ranges(hovered, {"cells": EnemyAI.movement_cells(hovered, self), "parents": parents})
	else:
		show_unit_ranges(hovered, map.get_reachable(hovered, units()))


## Z on an enemy adds/removes its threat from the red overlay.
func toggle_mark(u: Unit) -> void:
	if marked.has(u):
		marked.erase(u)
	else:
		marked.append(u)
	refresh_threat()


## Every cell an enemy could attack next phase: where it can move, plus what its
## weapons and affordable damage spells reach from there.
func enemy_threat(e: Unit) -> Dictionary:
	return EnemyAI.threat_from(e, self, EnemyAI.movement_cells(e, self))


func threat_of(enemies: Array[Unit]) -> Dictionary:
	var cells := {}
	for e in enemies:
		cells.merge(enemy_threat(e))
	return cells


## Recomputes the purple (all enemies) and red (marked enemies) overlays. Called
## whenever positions may have changed, and drops marks on enemies that died.
func refresh_threat() -> void:
	# A plain loop, not filter(): a marked enemy that died has been freed, and a
	# lambda with a `Unit` parameter can't even be called with a freed object.
	var alive: Array[Unit] = []
	for e in marked:
		if is_instance_valid(e) and e.hp > 0:
			alive.append(e)
	marked = alive
	map.danger_cells = threat_of(units_of(Unit.Team.ENEMY)) if danger_on else {}
	map.marked_cells = threat_of(marked)


func open_status(u: Unit) -> void:
	status_return_state = state
	status_unit = u
	state = State.STATUS
	ui.hide_info()
	ui.show_status(u)


## Up/Down flips through the shown unit's side, in roster order.
func cycle_status(step: int) -> void:
	var side := units_of(status_unit.team)
	status_unit = side[wrapi(side.find(status_unit) + step, 0, side.size())]
	ui.show_status(status_unit)


# --- Objectives, map objects, reinforcements (see Objectives) ----------------------

## "Turn N", or "Turn N / M" on maps with a turn limit.
func turn_text() -> String:
	var objective := Objectives.of(Levels.get_level(Levels.selected))
	if objective.type in ["survive", "defend"]:
		return "Turn %d / %d" % [turn, objective.turns]
	return "Turn %d" % turn


func do_seize() -> void:
	state = State.BUSY
	selected.popup("Seize!", Color.GOLD)
	selected.biography.append("Seized %s." % Levels.get_level(Levels.selected).name.get_slice(": ", 1))
	objective_done = true
	await get_tree().create_timer(0.5).timeout
	finish_action()


## The unit (and whoever it carries) leaves the map for good; the Lord leaving wins.
func do_escape() -> void:
	state = State.BUSY
	var u := selected
	u.popup("Escape", Color.PALE_GREEN)
	await get_tree().create_timer(0.4).timeout
	u.escaped = true
	u.visible = false
	if u.is_lord:
		objective_done = true
	finish_action()


func do_visit() -> void:
	state = State.BUSY
	var village := map.object_at(selected.cell)
	village.state = "visited"
	map.queue_redraw()
	selected.popup(give_item(selected, village.item), Color.GOLD)
	await get_tree().create_timer(0.7).timeout
	finish_action()


## Rogue-movement units open chests freely; anyone else needs a Chest Key.
func can_open_chest(u: Unit) -> bool:
	return u.move_type == "rogue" or u.items.any(func(it): return it.name == "Chest Key")


func do_open() -> void:
	state = State.BUSY
	var chest := map.object_at(selected.cell)
	_spend_key(selected)
	chest.state = "opened"
	map.queue_redraw()
	selected.popup(give_item(selected, chest.item), Color.GOLD)
	await get_tree().create_timer(0.7).timeout
	finish_action()


## Rogues open chests and doors freely; anyone else uses up a Chest Key.
func _spend_key(u: Unit) -> void:
	if u.move_type == "rogue":
		return
	var key := u.items.find(u.items.filter(func(it): return it.name == "Chest Key")[0])
	u.items[key].uses -= 1
	if u.items[key].uses <= 0:
		u.items.remove_at(key)


# --- Breakable tiles and doors (see BattleMap breakable terrain) ---------------------

## Damage dealt to a breakable tile: the unit's Attack (STR + weapon might). Always
## hits, never crits, no counter, no EXP.
func tile_damage(u: Unit) -> int:
	return Combat.base_attack(u) if not u.weapon.is_empty() else 0


## Breakable tiles `w` can reach from where `u` stands.
func breakable_cells(u: Unit, w: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in map.tile_hp:
		if Unit.weapon_reaches(w, BattleMap.distance(u.cell, cell)):
			result.append(cell)
	return result


func breakable_in_reach(u: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for w in u.weapons():
		for cell in breakable_cells(u, w):
			if not result.has(cell):
				result.append(cell)
	return result


func adjacent_doors(u: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in BattleMap.DIRS:
		if map.is_door(u.cell + d):
			result.append(u.cell + d)
	return result


## Break: pick a weapon that reaches a breakable tile, then the tile.
func open_break_menu() -> void:
	var options: Array[String] = []
	weapon_choices = []
	for i in selected.items.size():
		var it := selected.items[i]
		if Items.is_weapon(it) and selected.can_wield(it) and not breakable_cells(selected, it).is_empty():
			options.append(weapon_label(it))
			weapon_choices.append(i)
	_open_menu("break", options)


func start_cell_targeting(mode: String, cells: Array[Vector2i]) -> void:
	active_spell = ""
	target_mode = mode
	drop_cells = cells
	target_index = 0
	state = State.TARGETING
	show_target()


func do_break(u: Unit, cell: Vector2i) -> void:
	map.clear_ranges()
	var amount := tile_damage(u)
	var tile_name: String = map.terrain_at(cell).name
	await u.lunge(cell)
	u.popup("%s -%d" % [tile_name, amount], Color.WHITE)
	if u.use_weapon():
		u.popup("Broke!", Color.LIGHT_GRAY)
	var broke := map.damage_tile(cell, amount, u.cell)
	if broke:
		await get_tree().create_timer(0.3).timeout
		u.popup(tile_name + " broken!", Color.GOLD)
	await get_tree().create_timer(0.5).timeout


func do_open_door(u: Unit, cell: Vector2i) -> void:
	map.clear_ranges()
	_spend_key(u)
	map.set_terrain(cell, map.breakable_info(cell).becomes)
	u.popup("Door opened", Color.GOLD)
	await get_tree().create_timer(0.5).timeout


## Puts a new item in `u`'s inventory, or the convoy when it's full (campaign only).
## Returns the popup text.
func give_item(u: Unit, item_name: String) -> String:
	if u.items.size() < Unit.MAX_ITEMS:
		u.items.append(Items.make(item_name))
		return "Got " + item_name
	if Campaign.active:
		Campaign.convoy.append(Items.make(item_name))
		return item_name + " to convoy"
	return "No room: " + item_name


## An enemy on a village burns it (its reward is lost); on a chest, takes the item.
func loot(enemy: Unit, object: Dictionary) -> void:
	if object.type == "village":
		object.state = "looted"
		enemy.popup("Looted!", Color.ORANGE_RED)
	else:
		object.state = "opened"
		if enemy.items.size() < Unit.MAX_ITEMS:
			enemy.items.append(Items.make(object.item))
		enemy.popup("Stole " + object.item, Color.ORANGE_RED)
	map.queue_redraw()
	await get_tree().create_timer(0.6).timeout


## The level's reinforcements for this turn appear on their cell, or the nearest
## free cell they can stand on within 2 tiles (blocked otherwise), and wait a phase.
func spawn_reinforcements() -> void:
	var arrived := false
	for wave in Levels.get_level(Levels.selected).get("reinforcements", []):
		if wave.turn != turn:
			continue
		for data in wave.units:
			var u := Unit.create(data.name, Unit.Team.ENEMY, data.cell, data)
			var cell := _free_cell_near(u, data.cell)
			if cell == Vector2i(-1, -1):
				u.free()
				continue
			u.set_cell(cell)
			u.has_acted = true
			units_root.add_child(u)
			arrived = true
	if arrived:
		refresh_threat()
		await ui.show_banner("Reinforcements!", Color("b02828"))


func _free_cell_near(u: Unit, origin: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := origin + Vector2i(dx, dy)
			if absi(dx) + absi(dy) > 2 or unit_at(c) != null or not can_stand_on(u, c):
				continue
			if best == Vector2i(-1, -1) or BattleMap.distance(origin, c) < BattleMap.distance(origin, best):
				best = c
	return best


# --- Campaign flow (see Campaign) ----------------------------------------------------

const PREP_SCENE := "res://scenes/prep.tscn"

## End screen, Z: after a win, bank the chapter and move on; after a loss, retry it
## with the army as it was before (the last campaign save).
func continue_campaign() -> void:
	if battle_result == "victory":
		Campaign.finish_chapter(self)
	else:
		Campaign.load_save()
	if Campaign.is_complete():
		Campaign.active = false
		get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
	else:
		get_tree().change_scene_to_file(PREP_SCENE)


# --- Suspend / resume (see SaveGame) ---------------------------------------------

## Map menu > Suspend: save the battle and go back to the level select, which then
## offers to resume it.
func suspend() -> void:
	SaveGame.write_suspend(self)
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


## Rebuilds a suspended battle and picks the player phase up where it stopped.
func resume_suspended() -> void:
	var data := SaveGame.read_suspend()
	# A campaign chapter needs the campaign it belongs to (army, convoy, chapter).
	Campaign.active = data.get("campaign", false) and Campaign.load_save()
	SaveGame.restore(self, data)
	var players := units_of(Unit.Team.PLAYER)
	cursor.cell = players[0].cell if not players.is_empty() else Vector2i.ZERO
	enemy_phase = false
	refresh_threat()
	state = State.IDLE
	refresh_info()


## A map that ended can't be resumed.
func discard_suspend() -> void:
	var data := SaveGame.read_suspend()
	if not data.is_empty() and data.level == Levels.selected:
		SaveGame.delete_suspend()


func open_unit_list() -> void:
	state = State.UNIT_LIST
	ui.hide_info()
	ui.unit_list.open(units())


func close_unit_list() -> void:
	ui.unit_list.close()
	state = State.IDLE
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
		turn_text(),
		"Allies %d   Enemies %d" % [units_of(Unit.Team.PLAYER).size(), units_of(Unit.Team.ENEMY).size()],
		"Z/X: close",
	]
	state = State.OBJECTIVE
	ui.show_objective(lines)


func close_status() -> void:
	ui.hide_status()
	state = status_return_state
	refresh_info()


func enemies_in_range(u: Unit, w: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	for e in units_of(Unit.Team.ENEMY):
		if Unit.weapon_reaches(w, BattleMap.distance(u.cell, e.cell)):
			result.append(e)
	return result


func can_attack_any(u: Unit) -> bool:
	for w in u.weapons():
		if not enemies_in_range(u, w).is_empty():
			return true
	return false


## Spells the unit can afford and that have a valid target from its current cell.
func castable_spells(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for s in u.spells:
		if Spells.can_afford(u, s) and Spells.has_targets(u, s, units(), map):
			result.append(s)
	return result


func weapon_label(w: Dictionary) -> String:
	return "%s  %d" % [w.name, w.uses]


## Adjacent units on the same team; trading is allowed even if they already acted.
func trade_partners(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for ally in units_of(u.team):
		if ally != u and BattleMap.distance(u.cell, ally.cell) == 1 \
				and not (u.items.is_empty() and ally.items.is_empty()):
			result.append(ally)
	return result


func open_unit_menu() -> void:
	var options: Array[String] = []
	var objective := Objectives.of(Levels.get_level(Levels.selected))
	if Objectives.can_seize(objective, selected):
		options.append("Seize")
	if Objectives.can_escape(objective, selected):
		options.append("Escape")
	var here := map.object_at(selected.cell)
	if here.get("type", "") == "village" and here.state == "intact":
		options.append("Visit")
	if here.get("type", "") == "chest" and here.state == "intact" and can_open_chest(selected):
		options.append("Open")
	if not adjacent_doors(selected).is_empty() and can_open_chest(selected):
		options.append("Open Door")
	if can_attack_any(selected):
		options.append("Attack")
	if not breakable_in_reach(selected).is_empty():
		options.append("Break")
	if not castable_spells(selected).is_empty():
		options.append("Magic")
	if not dance_targets(selected).is_empty():
		options.append("Dance")
	if not inspire_targets(selected).is_empty():
		options.append("Inspire")
	if not trade_partners(selected).is_empty():
		options.append("Trade")
	if not shove_targets(selected).is_empty():
		options.append("Shove")
	if not rescue_targets(selected).is_empty():
		options.append("Rescue")
	if not drop_cells_for(selected).is_empty():
		options.append("Drop")
	if not board_targets(selected).is_empty():
		options.append("Board")
	if not unloadable(selected).is_empty():
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
		if selected.can_wield(selected.items[i]) and not enemies_in_range(selected, selected.items[i]).is_empty():
			options.append(weapon_label(selected.items[i]))
			weapon_choices.append(i)
	_open_menu("attack", options)


func open_magic_menu() -> void:
	spell_choices = castable_spells(selected)
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


func _open_menu(context: String, options: Array[String], title := "") -> void:
	menu_context = context
	ui.show_menu(options, selected.cell if selected else cursor.cell, title)
	state = State.MENU


func menu_accept() -> void:
	match menu_context:
		"end_turn":
			if ui.menu_choice() == "End Turn":
				end_player_phase()
			else:
				state = State.IDLE
				refresh_info()
		"restart":
			if ui.menu_choice() == "Restart":
				get_tree().reload_current_scene()
			else:
				state = State.IDLE
				refresh_info()
		"quit":
			if ui.menu_choice() == "Quit":
				Campaign.active = false
				get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
			else:
				state = State.IDLE
				refresh_info()
		"map":
			match ui.menu_choice():
				"End Turn":
					confirm_end_turn()
				"Units":
					open_unit_list()
				"Objective":
					open_objective()
				"Options":
					state = State.OPTIONS
					ui.options_screen.open()
				"Suspend":
					suspend()
				"Restart":
					var options: Array[String] = ["Cancel", "Restart"]
					_open_menu("restart", options, "Restart this map?")
				"Level Select":
					var options: Array[String] = ["Cancel", "Quit"]
					_open_menu("quit", options, "Quit to the level select?\nProgress on this map is lost.")
		"unit":
			match ui.menu_choice():
				"Seize":
					do_seize()
				"Escape":
					do_escape()
				"Visit":
					do_visit()
				"Open":
					do_open()
				"Attack":
					open_attack_menu()
				"Break":
					open_break_menu()
				"Open Door":
					start_cell_targeting("door", adjacent_doors(selected))
				"Magic":
					open_magic_menu()
				"Dance":
					start_dance_targeting()
				"Inspire":
					start_inspire_targeting()
				"Board":
					start_board_targeting()
				"Unload":
					open_unload_menu()
				"Trade":
					start_trade_targeting()
				"Shove":
					start_shove_targeting()
				"Rescue":
					start_rescue_targeting()
				"Drop":
					start_drop_targeting()
				"Items":
					open_items_menu()
				"Wait":
					finish_action()
		"attack":
			selected.equip(weapon_choices[ui.menu_index])
			start_targeting()
		"break":
			selected.equip(weapon_choices[ui.menu_index])
			start_cell_targeting("break", breakable_cells(selected, selected.weapon))
		"magic":
			start_spell_targeting(spell_choices[ui.menu_index])
		"unload":
			start_unload_targeting(passenger_choices[ui.menu_index])
		"items":
			var item := selected.items[ui.menu_index]
			if selected.can_wield(item):
				selected.equip(ui.menu_index)
				open_items_menu()
			elif Items.can_use(selected, item):
				state = State.BUSY
				selected.use_item(ui.menu_index)
				await get_tree().create_timer(0.5).timeout
				finish_action()
			else:
				selected.popup("Can't use", Color.LIGHT_GRAY)
				open_items_menu()


func menu_cancel() -> void:
	match menu_context:
		"map", "end_turn", "restart", "quit":
			state = State.IDLE
			refresh_info()
		"unit":
			if move_committed:
				# Trading commits the move, as in GBA FE (and so does unloading a ship).
				open_unit_menu()
				return
			selected.set_cell(origin_cell)
			cursor.cell = origin_cell
			select(selected)
		"attack", "magic", "items", "unload", "break":
			open_unit_menu()


func start_targeting() -> void:
	active_spell = ""
	target_mode = "attack"
	targets = enemies_in_range(selected, selected.weapon)
	target_index = 0
	state = State.TARGETING
	show_target()


func start_spell_targeting(spell_name: String) -> void:
	active_spell = spell_name
	target_mode = "spell"
	if Spells.get_spell(spell_name).target == "area":
		start_area_targeting()
		return
	targets = Spells.targets_for(selected, spell_name, units())
	target_index = 0
	state = State.TARGETING
	show_target()


func show_target() -> void:
	if target_mode in ["break", "door"]:
		var cell := drop_cells[target_index]
		cursor.cell = cell
		map.show_area([], [cell])
		var tile_name: String = map.terrain_at(cell).name
		if target_mode == "door":
			ui.show_cell_forecast("Open Door", cursor.cell)
		else:
			var hp: int = map.tile_hp.get(cell, 0)
			ui.show_cell_forecast("%s  HP %d -> %d" % [tile_name, hp, maxi(0, hp - tile_damage(selected))], cursor.cell)
		return
	if target_mode in ["drop", "unload"]:
		var cell := drop_cells[target_index]
		cursor.cell = cell
		map.show_area([], [cell])
		var passenger := selected.carrying if target_mode == "drop" else unload_passenger
		ui.show_drop_forecast(passenger, map.terrain_at(cell).name, cursor.cell,
			"Drop" if target_mode == "drop" else "Unload")
		return
	if target_mode == "inspire":
		var allies := inspire_targets(selected)
		cursor.cell = selected.cell
		map.show_area([], allies.map(func(a: Unit) -> Vector2i: return a.cell))
		ui.show_inspire_forecast(allies, Classes.inspire_bonus(selected.level), cursor.cell)
		return
	var target := targets[target_index]
	cursor.cell = target.cell
	if target_mode == "rescue":
		map.show_area([], [target.cell])
		ui.show_rescue_forecast(target, cursor.cell)
	elif target_mode == "dance":
		ui.show_dance_forecast(target, cursor.cell)
	elif target_mode == "board":
		map.show_area([], [target.cell])
		ui.show_board_forecast(target, cursor.cell)
	elif target_mode == "shove":
		var dest := shove_destination(selected, target)
		map.show_area([], [dest])
		ui.show_shove_forecast(target, map.terrain_at(dest).name, cursor.cell)
	elif target_mode == "trade":
		ui.show_trade_preview(target, cursor.cell)
	elif active_spell and Spells.is_support(active_spell):
		var spell := Spells.get_spell(active_spell)
		ui.show_heal_forecast(selected, target, active_spell, Spells.heal_amount(selected, spell, target), cursor.cell)
	elif active_spell:
		var spell := Spells.get_spell(active_spell)
		ui.show_forecast(selected, target, Combat.spell_forecast(selected, target, spell, map), cursor.cell,
			active_spell, true)
	else:
		ui.show_forecast(selected, target, Combat.forecast(selected, target, map), cursor.cell)


## Free cursor limited to the spell's cast range; starts on the center hitting the most enemies.
func start_area_targeting() -> void:
	area_centers = Spells.area_centers(selected, active_spell, map, units())
	var best := selected.cell
	var best_count := -1
	for c in area_centers:
		var count := Spells.area_targets(selected, active_spell, c, units(), map).size()
		if count > best_count:
			best = c
			best_count = count
	cursor.cell = best
	state = State.AREA_TARGET
	show_area_preview()


func current_area_victims() -> Array[Unit]:
	return Spells.area_targets(selected, active_spell, cursor.cell, units(), map)


func show_area_preview() -> void:
	map.show_area(area_centers, Spells.area_cells(active_spell, cursor.cell, map))
	var spell := Spells.get_spell(active_spell)
	var rows: Array = []
	for v in current_area_victims():
		rows.append([v.unit_name, v.hp, Combat.spell_damage(selected, v, spell, map),
			Combat.spell_hit_chance(selected, v, spell, map)])
	var note := ""
	if spell.has("terraform"):
		note = "%s -> %s" % [map.terrain_at(cursor.cell).name, BattleMap.TERRAIN[spell.terraform].name]
	ui.show_area_forecast(selected, active_spell, rows, cursor.cell, note)


## Adjacent allies who have already acted this phase.
func dance_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not u.has_ability("dance"):
		return result
	for ally in units_of(u.team):
		if ally != u and ally.has_acted and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


func start_dance_targeting() -> void:
	active_spell = ""
	target_mode = "dance"
	targets = dance_targets(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


func start_trade_targeting() -> void:
	active_spell = ""
	target_mode = "trade"
	targets = trade_partners(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


# --- Trade screen ---------------------------------------------------------------
# Pick an item on either side, then a slot on the other side: an occupied slot
# swaps the two items, an empty slot hands the item over. Trading never uses up
# the unit's action, so it can trade repeatedly and with several partners.

func open_trade(partner: Unit) -> void:
	trade_partner = partner
	trade_held = Vector2i(-1, -1)
	trade_cursor = Vector2i(0 if not selected.items.is_empty() else 1, 0)
	cursor.cell = selected.cell
	state = State.TRADE
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
	ui.hide_trade()
	selected.queue_redraw()
	trade_partner.queue_redraw()
	open_unit_menu()


func _refresh_trade() -> void:
	ui.show_trade(selected, trade_partner, trade_cursor, trade_held)


## Shove (FE9): push an adjacent ally one cell straight away from the shover.
## Every unit can Shove; it ends the shover's turn and leaves the target's
## action state alone.
func shove_destination(shover: Unit, target: Unit) -> Vector2i:
	return target.cell + (target.cell - shover.cell)


## The landing cell must be on the map, enterable by the target in one move, and empty.
## Mounted units can neither shove nor be shoved (they Rescue instead); neither can
## ships. Some races change this (see Unit.can_shove and can_be_shoved).
func can_shove(shover: Unit, target: Unit) -> bool:
	if target.team != shover.team or BattleMap.distance(shover.cell, target.cell) != 1:
		return false
	if not shover.can_shove() or not target.can_be_shoved():
		return false
	var dest := shove_destination(shover, target)
	return can_stand_on(target, dest) and unit_at(dest) == null


func shove_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for ally in units_of(u.team):
		if ally != u and can_shove(u, ally):
			result.append(ally)
	return result


func start_shove_targeting() -> void:
	active_spell = ""
	target_mode = "shove"
	targets = shove_targets(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


func do_shove(shover: Unit, target: Unit) -> void:
	var dest := shove_destination(shover, target)
	map.clear_ranges()
	shover.popup("Shove", Color.WHITE)
	await shover.lunge(target.cell)
	var path: Array[Vector2i] = [target.cell, dest]
	await target.move_along(path)
	await get_tree().create_timer(0.2).timeout


## Rescue (Thracia 776 style): a mounted unit (or a Centaur) picks up an adjacent
## ally that can be carried (see Unit.can_be_carried) and carries it off the map. Carrying halves the rescuer's DEX and AGI
## (Unit.combat_dex/agi). Rescuing and dropping each end the rescuer's turn; the
## carried unit keeps its own action, so a dropped ally that hasn't acted yet can
## still move. That's what lets mounted units ferry others.
func rescue_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not u.can_carry() or u.carrying:
		return result
	for ally in units_of(u.team):
		if ally != u and ally.can_be_carried() and not ally.carrying \
				and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


## Adjacent cells where the carried unit could be set down.
func drop_cells_for(u: Unit) -> Array[Vector2i]:
	if not u.carrying:
		return []
	return landing_cells(u, u.carrying)


## Empty cells next to `carrier` that `passenger` can stand on.
func landing_cells(carrier: Unit, passenger: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in BattleMap.DIRS:
		var c := carrier.cell + d
		if can_stand_on(passenger, c) and unit_at(c) == null:
			result.append(c)
	return result


func start_rescue_targeting() -> void:
	active_spell = ""
	target_mode = "rescue"
	targets = rescue_targets(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


func start_drop_targeting() -> void:
	active_spell = ""
	target_mode = "drop"
	drop_cells = drop_cells_for(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


func do_rescue(rescuer: Unit, ally: Unit) -> void:
	map.clear_ranges()
	rescuer.popup("Rescue", Color.WHITE)
	var path: Array[Vector2i] = [ally.cell, rescuer.cell]
	await ally.move_along(path)
	ally.visible = false
	ally.carried_by = rescuer
	rescuer.carrying = ally
	rescuer.queue_redraw()
	await get_tree().create_timer(0.2).timeout


func do_drop(carrier: Unit, cell: Vector2i) -> void:
	map.clear_ranges()
	var ally := carrier.carrying
	release(carrier, carrier.cell)
	var path: Array[Vector2i] = [carrier.cell, cell]
	await ally.move_along(path)
	await get_tree().create_timer(0.2).timeout


## Puts the carried unit back on the map at `cell` (no animation).
func release(carrier: Unit, cell: Vector2i) -> void:
	var ally := carrier.carrying
	carrier.carrying = null
	carrier.queue_redraw()
	ally.carried_by = null
	ally.set_cell(cell)
	ally.visible = true


## Ships: an adjacent ally Boards a ship with room (ending the boarder's turn, like
## being rescued, but initiated by the passenger). The ship can then Unload
## passengers onto adjacent cells they can stand on without ending its own turn,
## and a passenger that hasn't acted can still move. Ships can't board ships, and a
## rescuer that is carrying someone can't board.
func board_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if u.is_ship() or u.carrying:
		return result
	for ally in units_of(u.team):
		if ally.is_ship() and ally.cargo_space() > 0 and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


## Passengers that have somewhere to be unloaded.
func unloadable(ship: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for p in ship.passengers:
		if not landing_cells(ship, p).is_empty():
			result.append(p)
	return result


func start_board_targeting() -> void:
	active_spell = ""
	target_mode = "board"
	targets = board_targets(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


## Picks which passenger to unload (skipped when there's only one).
func open_unload_menu() -> void:
	passenger_choices = unloadable(selected)
	if passenger_choices.size() == 1:
		start_unload_targeting(passenger_choices[0])
		return
	var options: Array[String] = []
	for p in passenger_choices:
		options.append(p.unit_name)
	_open_menu("unload", options)


func start_unload_targeting(passenger: Unit) -> void:
	active_spell = ""
	target_mode = "unload"
	unload_passenger = passenger
	drop_cells = landing_cells(selected, passenger)
	target_index = 0
	state = State.TARGETING
	show_target()


func do_board(u: Unit, ship: Unit) -> void:
	map.clear_ranges()
	u.popup("Board", Color.WHITE)
	var path: Array[Vector2i] = [u.cell, ship.cell]
	await u.move_along(path)
	u.visible = false
	u.carried_by = ship
	ship.passengers.append(u)
	ship.queue_redraw()
	await get_tree().create_timer(0.2).timeout


func do_unload(ship: Unit, passenger: Unit, cell: Vector2i) -> void:
	map.clear_ranges()
	ship.passengers.erase(passenger)
	ship.queue_redraw()
	passenger.carried_by = null
	passenger.set_cell(ship.cell)
	passenger.visible = true
	var path: Array[Vector2i] = [ship.cell, cell]
	await passenger.move_along(path)
	await get_tree().create_timer(0.2).timeout


## Whether `u` may be placed on `cell` (shoved, dropped, unloaded): the cell must be
## enterable within one move, i.e. cost no more than its MOV. Rivers cost foot units
## 6, so a MOV 5 foot soldier can't be dropped into one.
func can_stand_on(u: Unit, cell: Vector2i) -> bool:
	var cost := map.move_cost(cell, u.move_type)
	return cost >= 0 and cost <= u.mov


## Nearest empty cell to `from` that `u` can stand on, or (-1, -1) if there's none.
func nearest_free_cell(u: Unit, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for y in map.rows:
		for x in map.cols:
			var c := Vector2i(x, y)
			if not can_stand_on(u, c) or unit_at(c) != null:
				continue
			if best == Vector2i(-1, -1) or BattleMap.distance(from, c) < BattleMap.distance(from, best):
				best = c
	return best


## Inspire: every adjacent ally gets +STR/DEF (Classes.inspire_bonus, growing with
## the user's level) until the start of its side's next phase. Ends the user's turn.
func inspire_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not u.has_ability("inspire"):
		return result
	for ally in units_of(u.team):
		if ally != u and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


func start_inspire_targeting() -> void:
	active_spell = ""
	target_mode = "inspire"
	targets = [selected]
	target_index = 0
	state = State.TARGETING
	show_target()


func do_inspire(u: Unit) -> void:
	var bonus := Classes.inspire_bonus(u.level)
	var allies := inspire_targets(u)
	map.clear_ranges()
	u.popup("Inspire", Color.GOLD)
	await get_tree().create_timer(0.3).timeout
	for ally in allies:
		ally.inspire_bonus = maxi(ally.inspire_bonus, bonus)
		ally.popup("STR/DEF +%d" % bonus, Color.GOLD)
	await get_tree().create_timer(0.5).timeout
	if u.team == Unit.Team.PLAYER and u.level < Experience.LEVEL_CAP:
		await gain_exp(u, Experience.INSPIRE_EXP)


## Refreshes the target so it can move and act again this phase.
func do_dance(dancer: Unit, target: Unit) -> void:
	dancer.popup("Dance", Color.PINK)
	await dancer.lunge(target.cell)
	target.has_acted = false
	target.popup("Refreshed", Color.PINK)
	await get_tree().create_timer(0.5).timeout
	if dancer.level < Experience.LEVEL_CAP:
		await gain_exp(dancer, Experience.DANCE_EXP)


func cast_heal(caster: Unit, target: Unit, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var amount := Spells.heal_amount(caster, spell, target)
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	await caster.lunge(target.cell)
	target.heal(amount)
	target.popup("+%d" % amount, Color.PALE_GREEN)
	await get_tree().create_timer(0.5).timeout
	if caster.team == Unit.Team.PLAYER and caster.level < Experience.LEVEL_CAP:
		await gain_exp(caster, spell.exp)


func do_combat(attacker: Unit, defender: Unit) -> void:
	# A unit whose weapon breaks makes no further strikes this combat (as in GBA FE),
	# even though its next item is equipped right away.
	var broke: Array[Unit] = []
	var dealt: Array[Unit] = []
	defender.notify_attacked()
	for pair in Combat.strike_order(attacker, defender):
		var a: Unit = pair[0]
		var d: Unit = pair[1]
		if a.hp <= 0 or d.hp <= 0:
			break
		if a.weapon.is_empty() or broke.has(a):
			continue
		var result := Combat.strike(a, d, map)
		await a.lunge(d.cell)
		_apply_strike(a, d, result, dealt)
		if result.hit and a.use_weapon():
			broke.append(a)
			a.popup("Broke!", Color.LIGHT_GRAY)
		await get_tree().create_timer(0.45).timeout
	await _finish_exchange(attacker, defender, dealt)


## Single-target damage spell: one cast (never doubles), then the target may counter once.
func do_spell_attack(caster: Unit, target: Unit, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var dealt: Array[Unit] = []
	target.notify_attacked()
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	var result := Combat.spell_strike(caster, target, spell, map)
	await caster.lunge(target.cell)
	_apply_strike(caster, target, result, dealt)
	await get_tree().create_timer(0.45).timeout
	if target.hp > 0 and Combat.can_counter(caster, target):
		var counter := Combat.strike(target, caster, map)
		await target.lunge(caster.cell)
		_apply_strike(target, caster, counter, dealt)
		if counter.hit and target.use_weapon():
			target.popup("Broke!", Color.LIGHT_GRAY)
		await get_tree().create_timer(0.45).timeout
	await _finish_exchange(caster, target, dealt)


## Area spell: separate hit roll per enemy in the blast, no counters.
## Terraforming spells then change the target cell, hit or miss.
func cast_area(caster: Unit, center: Vector2i, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var victims := Spells.area_targets(caster, spell_name, center, units(), map)
	for v in victims:
		v.notify_attacked()
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	await caster.lunge(center)
	map.show_area([], Spells.area_cells(spell_name, center, map))
	var damaged: Array[Unit] = []
	for v in victims:
		var result := Combat.spell_strike(caster, v, spell, map)
		var dealt: Array[Unit] = []
		_apply_strike(caster, v, result, dealt)
		if not dealt.is_empty():
			damaged.append(v)
	if spell.has("terraform"):
		map.set_terrain(center, spell.terraform)
	await get_tree().create_timer(0.6).timeout
	map.clear_ranges()
	# EXP: sum of what each target would give, capped at one level.
	var awards: Array = []
	if caster.team == Unit.Team.PLAYER and caster.level < Experience.LEVEL_CAP and not victims.is_empty():
		var total := 0
		for v in victims:
			total += Experience.combat_exp(caster, v, damaged.has(v), v.hp <= 0)
		awards.append([caster, mini(total, Experience.EXP_PER_LEVEL)])
	await _remove_dead_and_award(victims, awards)


## Applies one strike's result with popups; records the striker in `dealt` if it did damage.
func _apply_strike(a: Unit, d: Unit, result: Dictionary, dealt: Array[Unit]) -> void:
	if result.hit:
		d.take_damage(result.dmg)
		if result.dmg > 0 and not dealt.has(a):
			dealt.append(a)
		d.popup(("Crit! %d" if result.crit else "%d") % result.dmg,
			Color.ORANGE if result.crit else Color.WHITE)
	else:
		d.popup("Miss", Color.LIGHT_GRAY)


## EXP for both sides of a one-on-one exchange, then deaths.
func _finish_exchange(attacker: Unit, defender: Unit, dealt: Array[Unit]) -> void:
	# Work out EXP before dead units are freed.
	var awards: Array = []
	for pair in [[attacker, defender], [defender, attacker]]:
		var u: Unit = pair[0]
		var foe: Unit = pair[1]
		if u.team == Unit.Team.PLAYER and u.hp > 0 and u.level < Experience.LEVEL_CAP:
			awards.append([u, Experience.combat_exp(u, foe, dealt.has(u), foe.hp <= 0)])
	var involved: Array[Unit] = [attacker, defender]
	await _remove_dead_and_award(involved, awards)


func _remove_dead_and_award(involved: Array[Unit], awards: Array) -> void:
	for u in involved:
		if u.hp <= 0 and u.team == Unit.Team.PLAYER:
			campaign_deaths.append({"name": u.unit_name, "turn": turn})
		if u.hp <= 0:
			var cell := u.cell
			var carried := u.carrying
			var aboard := u.passengers.duplicate()
			await u.die()
			# A fallen carrier's passenger is set down where it fell.
			if carried:
				carried.carried_by = null
				carried.set_cell(cell)
				carried.visible = true
			# A sunk ship's passengers make for the nearest free cell they can stand on.
			for p: Unit in aboard:
				p.carried_by = null
				var land := nearest_free_cell(p, cell)
				if land == Vector2i(-1, -1):
					p.hp = 0
					p.queue_free()
					continue
				p.set_cell(land)
				p.visible = true
	for award in awards:
		await gain_exp(award[0], award[1])


func gain_exp(u: Unit, amount: int) -> void:
	amount = roundi(amount * u.race_data().get("exp_mult", 1.0))
	u.popup("+%d EXP" % amount, Color.AQUAMARINE)
	await get_tree().create_timer(0.5).timeout
	u.exp_points += amount
	while u.exp_points >= Experience.EXP_PER_LEVEL and u.level < Experience.LEVEL_CAP:
		u.exp_points -= Experience.EXP_PER_LEVEL
		var gains := Experience.roll_level_up(u)
		var before := {}
		for key in Experience.STATS:
			before[key] = u.get(Experience.STATS[key])
		Experience.apply_level_up(u, gains)
		await ui.show_level_up(u, before, gains)
	if u.level >= Experience.LEVEL_CAP:
		u.exp_points = 0


func finish_action() -> void:
	if is_instance_valid(selected) and selected.hp > 0:
		selected.has_acted = true
		cursor.cell = selected.cell
	selected = null
	map.clear_ranges()
	refresh_threat()
	if check_game_over():
		return
	var all_acted := units_of(Unit.Team.PLAYER).all(func(u: Unit) -> bool: return u.has_acted)
	if all_acted and Settings.value("auto_end_turn"):
		end_player_phase()
		return
	state = State.IDLE
	refresh_info()


# --- Phases ------------------------------------------------------------------

func start_player_phase() -> void:
	state = State.BUSY
	enemy_phase = false
	ui.hide_info()
	# Every unit, including carried ones, so passengers can act once set down.
	for u in units_root.get_children():
		if u is Unit:
			u.has_acted = false
	clear_inspire(Unit.Team.PLAYER)
	for u in units_of(Unit.Team.PLAYER):
		u.regen_mp(u.mp_regen())
	turn += 1
	await ui.show_banner("Player Phase\n" + turn_text(), Color("2850b0"))
	await heal_on_tiles(Unit.Team.PLAYER)
	var players := units_of(Unit.Team.PLAYER)
	if not players.is_empty():
		cursor.cell = players[0].cell
	refresh_threat()
	state = State.IDLE
	refresh_info()


## Inspire lasts until the start of the inspired side's next phase.
func clear_inspire(team: Unit.Team) -> void:
	for u in units_root.get_children():
		if u is Unit and u.team == team:
			u.inspire_bonus = 0


## Healing tiles (e.g. Forts) and regenerating races (Trolls) restore a share of
## max HP to `team`'s units at the start of that team's phase.
func heal_on_tiles(team: Unit.Team) -> void:
	var healed := false
	for u in units_of(team):
		var rate: float = map.terrain_heal(u.cell) + u.race_data().get("hp_regen", 0.0)
		if rate > 0.0 and u.hp < u.max_hp:
			var amount := mini(ceili(u.max_hp * rate), u.max_hp - u.hp)
			u.heal(amount)
			u.popup("+%d" % amount, Color.PALE_GREEN)
			healed = true
	if healed:
		await get_tree().create_timer(0.5).timeout


func end_player_phase() -> void:
	state = State.BUSY
	enemy_phase = true
	ui.hide_info()
	await ui.show_banner("Enemy Phase", Color("b02828"))
	clear_inspire(Unit.Team.ENEMY)
	for e in units_of(Unit.Team.ENEMY):
		e.regen_mp(e.mp_regen())
	await heal_on_tiles(Unit.Team.ENEMY)
	await spawn_reinforcements()
	EnemyAI.update_all_wake(self)
	for e in units_of(Unit.Team.ENEMY):
		# has_acted: reinforcements that just arrived wait for the next phase.
		if not is_instance_valid(e) or e.hp <= 0 or e.has_acted:
			continue
		await EnemyAI.take_turn(e, self)
		if check_game_over():
			return
	if check_game_over(true):
		return
	start_player_phase()


## Checks the map objective (see Objectives); `turn_over` is true right after an
## enemy phase ends, when survive/defend maps count a turn as done.
func check_game_over(turn_over := false) -> bool:
	if state == State.GAME_OVER:
		return true
	var result := Objectives.result(self, turn_over)
	if result == "":
		return false
	enemy_phase = false
	state = State.GAME_OVER
	battle_result = result
	discard_suspend()
	var won := result == "victory"
	var hint := "Z: restart   X: level select"
	if Campaign.active:
		var last := Campaign.chapter >= Chapters.ORDER.size() - 1
		hint = ("Z: continue" if not last else "Z: finish the campaign") if won \
			else "Z: retry the chapter   X: level select"
	ui.show_end("Victory!" if won else "Defeat...", Color("2850b0") if won else Color("602020"), hint)
	return true
