class_name BattleMenus
extends RefCounted
## The command menus (part of BattleInput, as `input.menus`): the map menu, the
## unit menu and the menus it opens (weapons, magic, items, repair, steal, unload,
## rewind), and the confirmation prompts. Picking an entry opens the next menu,
## starts targeting (input.targeting) or runs the action (BattleActions).

var input: BattleInput
var battle: Battle:
	get: return input.battle
var selected: Unit:
	get: return input.selected

## Which menu is open ("map", "unit", "attack", "items"...): decides what accept and cancel do.
var context := ""
## Inventory indices behind each entry of the attack weapon menu.
var weapon_choices: Array[int] = []
## Spell names behind each entry of the magic menu.
var spell_choices: Array[String] = []
## Repair Kit: its inventory index, and the weapon indices behind the Repair menu's entries.
var repair_kit := -1
var repair_choices: Array[int] = []
## Steal: the foe picked, and the item indices behind the Steal menu's entries.
var steal_target: Unit
var steal_choices: Array[int] = []
## Passengers behind the Unload menu's entries.
var passenger_choices: Array[Unit] = []


func _init(owner: BattleInput) -> void:
	input = owner


func open(menu: String, options: Array[String], title := "") -> void:
	context = menu
	battle.ui.show_menu(options, selected.cell if selected else battle.cursor.cell, title)
	battle.state = Battle.State.MENU


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
	for ability in Skills.abilities(selected):
		if selected.can_use_magic() and Spells.has_targets(selected, ability, battle.units(), battle.map):
			options.append(ability)
	if not battle.actions.dance_targets(selected).is_empty():
		options.append("Dance")
	if not battle.actions.inspire_targets(selected).is_empty():
		options.append("Inspire")
	if not battle.actions.steal_targets(selected).is_empty():
		options.append("Steal")
	if not battle.events.talk_targets(selected).is_empty():
		options.append("Talk")
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
	open("unit", options)


## After a Canto move: only Wait, and X takes the move back.
func open_canto_menu() -> void:
	var options: Array[String] = ["Wait"]
	open("canto", options)


## Weapon choice for Attack: only weapons that can reach an enemy are listed.
func open_attack_menu() -> void:
	var options: Array[String] = []
	weapon_choices = []
	for i in selected.items.size():
		if selected.can_wield(selected.items[i]) and not battle.actions.enemies_in_range(selected, selected.items[i]).is_empty():
			options.append(Items.label(selected.items[i]))
			weapon_choices.append(i)
	open("attack", options)


## Break: pick a weapon that reaches a breakable tile, then the tile.
func open_break_menu() -> void:
	var options: Array[String] = []
	weapon_choices = []
	for i in selected.items.size():
		var it := selected.items[i]
		if Items.is_weapon(it) and selected.can_wield(it) and not battle.actions.breakable_cells(selected, it).is_empty():
			options.append(Items.label(it))
			weapon_choices.append(i)
	open("break", options)


func open_magic_menu() -> void:
	spell_choices = battle.actions.castable_spells(selected)
	var options: Array[String] = []
	for s in spell_choices:
		options.append("%s  %dMP" % [s, Spells.get_spell(s).mp])
	open("magic", options)


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
		options.append(Items.label(item) + mark)
	open("items", options)


## Map menu > Rewind: pick an earlier turn start (this turn's included), newest first.
func open_rewind_menu() -> void:
	var options: Array[String] = []
	for i in range(battle.turn_history.size() - 1, -1, -1):
		options.append("Turn %d" % battle.turn_history[i].turn)
	var uses := "unlimited" if battle.rewinds_left < 0 else "%d left" % battle.rewinds_left
	open("rewind", options, "Rewind to the start of (%s):" % uses)


## Which weapon the Repair Kit at `kit` should restore.
func open_repair_menu(kit: int) -> void:
	repair_kit = kit
	repair_choices = battle.actions.repairable_weapons(selected)
	var options: Array[String] = []
	for i in repair_choices:
		var w := selected.items[i]
		options.append("%s  %d/%d" % [w.name, w.uses, Weapons.max_uses(w)])
	open("repair", options, "Repair which weapon?")


## Which item to take from `foe`.
func open_steal_menu(foe: Unit) -> void:
	steal_target = foe
	steal_choices = battle.actions.stealable_items(foe)
	var options: Array[String] = []
	for i in steal_choices:
		options.append(Items.label(foe.items[i]))
	battle.map.clear_ranges()
	battle.cursor.cell = selected.cell
	open("steal", options, "Steal from " + foe.unit_name)


## Picks which passenger to unload (skipped when there's only one).
func open_unload_menu() -> void:
	passenger_choices = battle.actions.unloadable(selected)
	if passenger_choices.size() == 1:
		input.targeting.start_unload(passenger_choices[0])
		return
	var options: Array[String] = []
	for p in passenger_choices:
		options.append(p.unit_name)
	open("unload", options)


func accept() -> void:
	var targeting := input.targeting
	match context:
		"end_turn":
			if battle.ui.menu_choice() == "End Turn":
				battle.phases.end_player_phase()
			else:
				input.browse()
		"restart":
			if battle.ui.menu_choice() == "Restart":
				input.get_tree().reload_current_scene()
			else:
				input.browse()
		"quit":
			if battle.ui.menu_choice() == "Quit":
				Campaign.active = false
				input.get_tree().change_scene_to_file(Battle.LEVEL_SELECT_SCENE)
			else:
				input.browse()
		"map":
			match battle.ui.menu_choice():
				"End Turn":
					input.confirm_end_turn()
				"Units":
					input.open_unit_list()
				"Objective":
					input.open_objective()
				"Options":
					battle.state = Battle.State.OPTIONS
					battle.ui.options_screen.open()
				"Rewind":
					open_rewind_menu()
				"Suspend":
					battle.phases.suspend()
				"Restart":
					var options: Array[String] = ["Cancel", "Restart"]
					open("restart", options, "Restart this map?")
				"Level Select":
					var options: Array[String] = ["Cancel", "Quit"]
					var note := "You can resume from the start of this turn." if Settings.value("auto_save") \
						else "Progress on this map is lost."
					open("quit", options, "Quit to the level select?\n" + note)
		"formation":
			match battle.ui.menu_choice():
				"Fight!":
					input.formation.end()
					battle.begin()
				"Units":
					input.open_unit_list()
				"Objective":
					input.open_objective()
				"Options":
					battle.state = Battle.State.OPTIONS
					battle.ui.options_screen.open()
				"Back to Prep":
					input.formation.leave()
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
					targeting.start_cells("door", battle.actions.adjacent_doors(selected))
				"Magic":
					open_magic_menu()
				"Dance":
					targeting.start_units("dance", battle.actions.dance_targets(selected))
				"Inspire":
					targeting.start_units("inspire", [selected])
				"Board":
					targeting.start_units("board", battle.actions.board_targets(selected))
				"Unload":
					open_unload_menu()
				"Trade":
					targeting.start_units("trade", battle.actions.trade_partners(selected))
				"Steal":
					targeting.start_units("steal", battle.actions.steal_targets(selected))
				"Talk":
					targeting.start_units("talk", battle.events.talk_targets(selected))
				"Shove":
					targeting.start_units("shove", battle.actions.shove_targets(selected))
				"Rescue":
					targeting.start_units("rescue", battle.actions.rescue_targets(selected))
				"Drop":
					targeting.start_cells("drop", battle.actions.drop_cells_for(selected))
				"Items":
					open_items_menu()
				"Wait":
					input.finish_action(true)
				var choice:
					if Skills.abilities(selected).has(choice):
						targeting.start_ability(choice)
		"canto":
			input.finish_action(true)
		"attack":
			selected.equip(weapon_choices[battle.ui.menu_index])
			targeting.start_units("attack", battle.actions.enemies_in_range(selected, selected.weapon))
		"break":
			selected.equip(weapon_choices[battle.ui.menu_index])
			targeting.start_cells("break", battle.actions.breakable_cells(selected, selected.weapon))
		"magic":
			targeting.start_spell(spell_choices[battle.ui.menu_index])
		"unload":
			targeting.start_unload(passenger_choices[battle.ui.menu_index])
		"steal":
			_act(battle.actions.do_steal.bind(selected, steal_target, steal_choices[battle.ui.menu_index]))
		"repair":
			_act(battle.actions.repair_weapon.bind(selected, repair_kit, repair_choices[battle.ui.menu_index]))
		"rewind":
			# Newest turn first.
			battle.phases.rewind_to(battle.turn_history.size() - 1 - battle.ui.menu_index)
		"items":
			var item := selected.items[battle.ui.menu_index]
			if selected.can_wield(item):
				selected.equip(battle.ui.menu_index)
				open_items_menu()
			elif item.get("kind", "") == "scroll" and Items.can_use(selected, item):
				_read_scroll(battle.ui.menu_index)
			elif item.get("kind", "") == "repair" and Items.can_use(selected, item):
				open_repair_menu(battle.ui.menu_index)
			elif Items.can_use(selected, item):
				_act(_use_item.bind(battle.ui.menu_index))
			else:
				selected.popup("Can't use", Color.LIGHT_GRAY)
				open_items_menu()


func cancel() -> void:
	match context:
		"map", "end_turn", "restart", "quit", "rewind", "formation":
			input.browse()
		"unit":
			if input.move_committed:
				# Trading commits the move, as in GBA FE (and so does unloading a ship).
				open_unit_menu()
				return
			input.undo_move()
		"canto":
			if input.move_committed:
				open_canto_menu()
				return
			input.undo_move()
		"attack", "magic", "items", "unload", "break":
			open_unit_menu()
		"steal":
			input.targeting.start_units("steal", battle.actions.steal_targets(selected))
		"repair":
			open_items_menu()


## A scroll is used up (and ends the turn) only if the skill was learned.
func _read_scroll(index: int) -> void:
	battle.state = Battle.State.BUSY
	var scroll := selected.items[index]
	if await battle.actions.learn_skill(selected, scroll.skill):
		selected.items.erase(scroll)
		await input.get_tree().create_timer(0.3).timeout
		input.finish_action()
	else:
		open_items_menu()


## Runs an action that ends the selected unit's turn.
func _act(action: Callable) -> void:
	battle.state = Battle.State.BUSY
	await action.call()
	input.finish_action()


func _use_item(index: int) -> void:
	selected.use_item(index)
	await input.get_tree().create_timer(0.5).timeout
