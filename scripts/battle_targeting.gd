class_name BattleTargeting
extends RefCounted
## Picking a target (part of BattleInput, as `input.targeting`): a unit (TARGETING
## with `targets`), a cell (TARGETING with `cells`, for CELL_MODES) or an area
## spell's center (AREA_TARGET), with the forecast for each. Confirming runs the
## action in BattleActions.

## Targeting modes that pick a cell (`cells`) rather than a unit (`targets`).
const CELL_MODES: Array[String] = ["drop", "unload", "break", "door"]

var input: BattleInput
var battle: Battle:
	get: return input.battle
var selected: Unit:
	get: return input.selected

## What TARGETING is picking for: "attack", "spell", "ability", "dance", "trade",
## "steal", "talk", "shove", "rescue", "board", "inspire", or one of CELL_MODES.
var mode := "attack"
var targets: Array[Unit] = []
## Cells to pick from while `mode` is one of CELL_MODES.
var cells: Array[Vector2i] = []
var index := 0
## Spell (or racial attack) being targeted, or "".
var active_spell := ""
## Cells an area spell may be centered on while in AREA_TARGET.
var area_centers: Array[Vector2i] = []
## Passenger a ship is unloading.
var unload_passenger: Unit
## Unit the next unit targeting starts on, when it's among the targets (the
## player picked it from the map before moving). Used once.
var preferred: Unit


func _init(owner: BattleInput) -> void:
	input = owner


## Picks one of `units` for `target_mode` ("attack", "dance", "trade", "steal",
## "shove", "rescue", "board" or "inspire").
func start_units(target_mode: String, units: Array[Unit]) -> void:
	active_spell = ""
	_start(target_mode, units)


func start_spell(spell_name: String) -> void:
	active_spell = spell_name
	if Spells.get_spell(spell_name).target == "area":
		mode = "spell"
		start_area()
		return
	_start("spell", Spells.targets_for(selected, spell_name, battle.units()))


## A racial attack (Fire Breath...): targeted like a single-target spell, but X goes
## back to the unit menu.
func start_ability(ability: String) -> void:
	active_spell = ability
	_start("ability", Spells.targets_for(selected, ability, battle.units()))


func _start(target_mode: String, units: Array[Unit]) -> void:
	mode = target_mode
	targets = units
	index = maxi(0, targets.find(preferred)) if preferred else 0
	preferred = null
	battle.state = Battle.State.TARGETING
	show_target()


## Picks one of `choices` for `target_mode` ("drop", "unload", "break" or "door").
func start_cells(target_mode: String, choices: Array[Vector2i]) -> void:
	active_spell = ""
	mode = target_mode
	cells = choices
	index = 0
	battle.state = Battle.State.TARGETING
	show_target()


func start_unload(passenger: Unit) -> void:
	unload_passenger = passenger
	start_cells("unload", battle.actions.landing_cells(selected, passenger))


# --- Input (TARGETING) ----------------------------------------------------------

func step(dir: Vector2i) -> void:
	var count := cells.size() if mode in CELL_MODES else targets.size()
	index = wrapi(index + (1 if dir.x + dir.y > 0 else -1), 0, count)
	show_target()


func accept() -> void:
	battle.ui.hide_forecast()
	if mode == "trade":
		input.trade.open(targets[index])
		return
	if mode == "steal":
		input.menus.open_steal_menu(targets[index])
		return
	battle.state = Battle.State.BUSY
	input.last_action = mode
	var actions := battle.actions
	match mode:
		"unload":
			# Unloading doesn't end the ship's turn, but commits its move.
			await actions.do_unload(selected, unload_passenger, cells[index])
			input.move_committed = true
			input.menus.open_unit_menu()
			return
		"talk":
			await battle.events.run_talk(selected, targets[index])
		"drop":
			await actions.do_drop(selected, cells[index])
		"break":
			await actions.do_break(selected, cells[index])
		"door":
			await actions.do_open_door(selected, cells[index])
		"rescue":
			await actions.do_rescue(selected, targets[index])
		"dance":
			await actions.do_dance(selected, targets[index])
		"board":
			await actions.do_board(selected, targets[index])
		"inspire":
			await actions.do_inspire(selected)
		"shove":
			await actions.do_shove(selected, targets[index])
		_:
			if active_spell and Spells.is_support(active_spell):
				await actions.cast_heal(selected, targets[index], active_spell)
			elif active_spell:
				await actions.do_spell_attack(selected, targets[index], active_spell)
			else:
				await actions.do_combat(selected, targets[index])
	input.finish_action()


func cancel() -> void:
	battle.ui.hide_forecast()
	battle.map.clear_ranges()
	battle.cursor.cell = selected.cell
	match mode:
		"attack":
			input.menus.open_attack_menu()
		"spell":
			input.menus.open_magic_menu()
		_:
			input.menus.open_unit_menu()


func show_target() -> void:
	if mode in ["break", "door"]:
		var cell := cells[index]
		battle.cursor.cell = cell
		battle.map.show_area([], [cell])
		var tile_name: String = battle.map.terrain_at(cell).name
		if mode == "door":
			battle.ui.show_cell_forecast("Open Door", battle.cursor.cell)
		else:
			var hp: int = battle.map.tile_hp.get(cell, 0)
			battle.ui.show_cell_forecast("%s  HP %d -> %d" % [tile_name, hp, maxi(0, hp - battle.actions.tile_damage(selected))], battle.cursor.cell)
		return
	if mode in ["drop", "unload"]:
		var cell := cells[index]
		battle.cursor.cell = cell
		battle.map.show_area([], [cell])
		var passenger := selected.carrying if mode == "drop" else unload_passenger
		battle.ui.show_drop_forecast(passenger, battle.map.terrain_at(cell).name, battle.cursor.cell,
			"Drop" if mode == "drop" else "Unload")
		return
	if mode == "inspire":
		var allies := battle.actions.inspire_targets(selected)
		battle.cursor.cell = selected.cell
		battle.map.show_area([], allies.map(func(a: Unit) -> Vector2i: return a.cell))
		battle.ui.show_inspire_forecast(allies, Classes.inspire_bonus(selected.level), battle.cursor.cell)
		return
	var target := targets[index]
	battle.cursor.cell = target.cell
	if mode == "rescue":
		battle.map.show_area([], [target.cell])
		battle.ui.show_rescue_forecast(target, battle.cursor.cell)
	elif mode == "dance":
		battle.ui.show_dance_forecast(target, battle.cursor.cell)
	elif mode == "board":
		battle.map.show_area([], [target.cell])
		battle.ui.show_board_forecast(target, battle.cursor.cell)
	elif mode == "shove":
		var dest := battle.actions.shove_destination(selected, target)
		battle.map.show_area([], [dest])
		battle.ui.show_shove_forecast(target, battle.map.terrain_at(dest).name, battle.cursor.cell)
	elif mode == "trade":
		battle.ui.show_trade_preview(target, battle.cursor.cell)
	elif mode == "talk":
		battle.map.show_area([], [target.cell])
		battle.ui.show_cell_forecast("Talk to %s" % target.unit_name, battle.cursor.cell)
	elif mode == "steal":
		var names: Array[String] = []
		for i in battle.actions.stealable_items(target):
			names.append(target.items[i].name)
		battle.ui.show_cell_forecast("Steal from %s\n%s" % [target.unit_name, ", ".join(names)], battle.cursor.cell)
	elif active_spell and Spells.is_support(active_spell):
		var spell := Spells.get_spell(active_spell)
		battle.ui.show_heal_forecast(selected, target, active_spell, Spells.heal_amount(selected, spell, target), battle.cursor.cell)
	elif active_spell:
		var spell := Spells.get_spell(active_spell)
		battle.ui.show_forecast(selected, target, Combat.spell_forecast(selected, target, spell, battle.map), battle.cursor.cell,
			active_spell, not spell.get("physical", false))  # MP is magic defense: shown for magic only
	else:
		battle.ui.show_forecast(selected, target, Combat.forecast(selected, target, battle.map), battle.cursor.cell)


# --- Area spells (AREA_TARGET) ------------------------------------------------

## Free cursor limited to the spell's cast range; starts on the center hitting the most enemies.
func start_area() -> void:
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


func area_move(dir: Vector2i) -> void:
	if area_centers.has(battle.cursor.cell + dir):
		battle.cursor.cell += dir
		show_area_preview()


func area_accept() -> void:
	if not Spells.can_cast_at(selected, active_spell, battle.cursor.cell, battle.units(), battle.map):
		return
	battle.ui.hide_forecast()
	battle.state = Battle.State.BUSY
	await battle.actions.cast_area(selected, battle.cursor.cell, active_spell)
	input.finish_action()


func area_cancel() -> void:
	battle.ui.hide_forecast()
	battle.map.clear_ranges()
	battle.cursor.cell = selected.cell
	input.menus.open_magic_menu()


func area_victims() -> Array[Unit]:
	return Spells.area_targets(selected, active_spell, battle.cursor.cell, battle.units(), battle.map)


func show_area_preview() -> void:
	battle.map.show_area(area_centers, Spells.area_cells(active_spell, battle.cursor.cell, battle.map))
	var spell := Spells.get_spell(active_spell)
	var rows: Array = []
	for v in area_victims():
		rows.append([v.unit_name, v.hp, Combat.spell_damage(selected, v, spell, battle.map),
			Combat.spell_hit_chance(selected, v, spell, battle.map)])
	var note := ""
	if spell.has("terraform"):
		note = "%s -> %s" % [battle.map.terrain_at(battle.cursor.cell).name, BattleMap.TERRAIN[spell.terraform].name]
	battle.ui.show_area_forecast(selected, active_spell, rows, battle.cursor.cell, note)
