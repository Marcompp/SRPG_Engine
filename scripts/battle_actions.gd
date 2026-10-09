class_name BattleActions
extends Node
## What units do: target queries ("who can this unit shove?") and the
## actions themselves, with their animations, for both the player and the enemy
## AI, including combat resolution and EXP.

var battle: Battle


# --- Who can do what ----------------------------------------------------------

func enemies_in_range(u: Unit, w: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	for e in battle.units_of(Unit.Team.ENEMY):
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
		if Spells.can_afford(u, s) and Spells.has_targets(u, s, battle.units(), battle.map):
			result.append(s)
	return result


## Adjacent units on the same team; trading is allowed even if they already acted.
func trade_partners(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for ally in battle.units_of(u.team):
		if ally != u and BattleMap.distance(u.cell, ally.cell) == 1 \
				and not (u.items.is_empty() and ally.items.is_empty()):
			result.append(ally)
	return result


## Adjacent allies who have already acted this phase.
func dance_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not Skills.commands(u).has("dance"):
		return result
	for ally in battle.units_of(u.team):
		if ally != u and ally.has_acted and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


## Inspire: every adjacent ally gets +STR/DEF (Classes.inspire_bonus, growing with
## the user's level) until the start of its side's next phase. Ends the user's turn.
func inspire_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not Skills.commands(u).has("inspire"):
		return result
	for ally in battle.units_of(u.team):
		if ally != u and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


# --- Map objectives and objects (see Objectives) ------------------------------

func do_seize(u: Unit) -> void:
	u.popup("Seize!", Color.GOLD)
	u.biography.append("Seized %s." % Levels.get_level(Levels.selected).name.get_slice(": ", 1))
	battle.objective_done = true
	await get_tree().create_timer(0.5).timeout


## The unit (and whoever it carries) leaves the map for good; the Lord leaving wins.
func do_escape(u: Unit) -> void:
	u.popup("Escape", Color.PALE_GREEN)
	await get_tree().create_timer(0.4).timeout
	u.escaped = true
	u.visible = false
	if u.is_lord:
		battle.objective_done = true


func do_visit(u: Unit) -> void:
	var village := battle.map.object_at(u.cell)
	village.state = "visited"
	battle.map.queue_redraw()
	u.popup(give_item(u, village.item), Color.GOLD)
	await get_tree().create_timer(0.7).timeout


## Rogue-movement units open chests freely; anyone else needs a Chest Key.
func can_open_chest(u: Unit) -> bool:
	return u.move_type == "rogue" or u.items.any(func(it): return it.name == "Chest Key")


func do_open(u: Unit) -> void:
	var chest := battle.map.object_at(u.cell)
	_spend_key(u)
	chest.state = "opened"
	battle.map.queue_redraw()
	u.popup(give_item(u, chest.item), Color.GOLD)
	await get_tree().create_timer(0.7).timeout


## Rogues open chests and doors freely; anyone else uses up a Chest Key.
func _spend_key(u: Unit) -> void:
	if u.move_type == "rogue":
		return
	var key := u.items.find(u.items.filter(func(it): return it.name == "Chest Key")[0])
	u.items[key].uses -= 1
	if u.items[key].uses <= 0:
		u.items.remove_at(key)


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
	battle.map.queue_redraw()
	await get_tree().create_timer(0.6).timeout


# --- Breakable tiles and doors (see BattleMap breakable terrain) --------------

## Damage dealt to a breakable tile: the unit's Attack (STR + weapon might). Always
## hits, never crits, no counter, no EXP.
func tile_damage(u: Unit) -> int:
	return Combat.base_attack(u) if not u.weapon.is_empty() else 0


## Breakable tiles `w` can reach from where `u` stands.
func breakable_cells(u: Unit, w: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in battle.map.tile_hp:
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
		if battle.map.is_door(u.cell + d):
			result.append(u.cell + d)
	return result


func do_break(u: Unit, cell: Vector2i) -> void:
	battle.map.clear_ranges()
	var amount := tile_damage(u)
	var tile_name: String = battle.map.terrain_at(cell).name
	await u.lunge(cell)
	u.popup("%s -%d" % [tile_name, amount], Color.WHITE)
	if u.use_weapon():
		u.popup("Broke!", Color.LIGHT_GRAY)
	var broke := battle.map.damage_tile(cell, amount, u.cell)
	if broke:
		await get_tree().create_timer(0.3).timeout
		u.popup(tile_name + " broken!", Color.GOLD)
	await get_tree().create_timer(0.5).timeout


func do_open_door(u: Unit, cell: Vector2i) -> void:
	battle.map.clear_ranges()
	_spend_key(u)
	battle.map.set_terrain(cell, battle.map.breakable_info(cell).becomes)
	u.popup("Door opened", Color.GOLD)
	await get_tree().create_timer(0.5).timeout


# --- Shove --------------------------------------------------------------------

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
	return battle.can_stand_on(target, dest) and battle.unit_at(dest) == null


func shove_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for ally in battle.units_of(u.team):
		if ally != u and can_shove(u, ally):
			result.append(ally)
	return result


func do_shove(shover: Unit, target: Unit) -> void:
	var dest := shove_destination(shover, target)
	battle.map.clear_ranges()
	shover.popup("Shove", Color.WHITE)
	await shover.lunge(target.cell)
	var path: Array[Vector2i] = [target.cell, dest]
	await target.move_along(path)
	await get_tree().create_timer(0.2).timeout


# --- Rescue and drop ----------------------------------------------------------

## Rescue (Thracia 776 style): a mounted unit (or a Centaur) picks up an adjacent
## ally that can be carried (see Unit.can_be_carried) and carries it off the map. Carrying halves the rescuer's DEX and AGI
## (Unit.combat_dex/agi). Rescuing and dropping each end the rescuer's turn; the
## carried unit keeps its own action, so a dropped ally that hasn't acted yet can
## still move. That's what lets mounted units ferry others.
func rescue_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not u.can_carry() or u.carrying:
		return result
	for ally in battle.units_of(u.team):
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
		if battle.can_stand_on(passenger, c) and battle.unit_at(c) == null:
			result.append(c)
	return result


func do_rescue(rescuer: Unit, ally: Unit) -> void:
	battle.map.clear_ranges()
	rescuer.popup("Rescue", Color.WHITE)
	var path: Array[Vector2i] = [ally.cell, rescuer.cell]
	await ally.move_along(path)
	ally.visible = false
	ally.carried_by = rescuer
	rescuer.carrying = ally
	rescuer.queue_redraw()
	await get_tree().create_timer(0.2).timeout


func do_drop(carrier: Unit, cell: Vector2i) -> void:
	battle.map.clear_ranges()
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


# --- Ships --------------------------------------------------------------------

## Ships: an adjacent ally Boards a ship with room (ending the boarder's turn, like
## being rescued, but initiated by the passenger). The ship can then Unload
## passengers onto adjacent cells they can stand on without ending its own turn,
## and a passenger that hasn't acted can still move. Ships can't board ships, and a
## rescuer that is carrying someone can't board.
func board_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if u.is_ship() or u.carrying:
		return result
	for ally in battle.units_of(u.team):
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


func do_board(u: Unit, ship: Unit) -> void:
	battle.map.clear_ranges()
	u.popup("Board", Color.WHITE)
	var path: Array[Vector2i] = [u.cell, ship.cell]
	await u.move_along(path)
	u.visible = false
	u.carried_by = ship
	ship.passengers.append(u)
	ship.queue_redraw()
	await get_tree().create_timer(0.2).timeout


func do_unload(ship: Unit, passenger: Unit, cell: Vector2i) -> void:
	battle.map.clear_ranges()
	ship.passengers.erase(passenger)
	ship.queue_redraw()
	passenger.carried_by = null
	passenger.set_cell(ship.cell)
	passenger.visible = true
	var path: Array[Vector2i] = [ship.cell, cell]
	await passenger.move_along(path)
	await get_tree().create_timer(0.2).timeout


# --- Support ------------------------------------------------------------------

func do_inspire(u: Unit) -> void:
	var bonus := Classes.inspire_bonus(u.level)
	var allies := inspire_targets(u)
	battle.map.clear_ranges()
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


# --- Combat -------------------------------------------------------------------

func do_combat(attacker: Unit, defender: Unit) -> void:
	# A unit whose weapon breaks makes no further strikes this combat (as in GBA FE),
	# even though its next item is equipped right away.
	var broke: Array[Unit] = []
	var dealt: Array[Unit] = []
	defender.notify_attacked()
	for pair in Combat.strike_order(attacker, defender, battle.map):
		var a: Unit = pair[0]
		var d: Unit = pair[1]
		if a.hp <= 0 or d.hp <= 0:
			break
		if a.weapon.is_empty() or broke.has(a):
			continue
		var result := Combat.strike(a, d, battle.map, attacker)
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
	var result := Combat.spell_strike(caster, target, spell, battle.map)
	await caster.lunge(target.cell)
	_apply_strike(caster, target, result, dealt)
	await get_tree().create_timer(0.45).timeout
	if target.hp > 0 and Combat.can_counter(caster, target, battle.map):
		var counter := Combat.strike(target, caster, battle.map, caster)
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
	var victims := Spells.area_targets(caster, spell_name, center, battle.units(), battle.map)
	for v in victims:
		v.notify_attacked()
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	await caster.lunge(center)
	battle.map.show_area([], Spells.area_cells(spell_name, center, battle.map))
	var damaged: Array[Unit] = []
	for v in victims:
		var result := Combat.spell_strike(caster, v, spell, battle.map)
		var dealt: Array[Unit] = []
		_apply_strike(caster, v, result, dealt)
		if not dealt.is_empty():
			damaged.append(v)
	if spell.has("terraform"):
		battle.map.set_terrain(center, spell.terraform)
	await get_tree().create_timer(0.6).timeout
	battle.map.clear_ranges()
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
	for proc in result.get("procs", []):
		if not Skills.is_hidden(proc[1]):
			proc[0].popup(proc[1] + "!", Color.GOLD, 10.0)
	if result.get("heal", 0) > 0:
		a.heal(result.heal)
		a.popup("+%d" % result.heal, Color.PALE_GREEN)
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
			battle.campaign_deaths.append({"name": u.unit_name, "turn": battle.turn})
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
				var land := battle.nearest_free_cell(p, cell)
				if land == Vector2i(-1, -1):
					p.hp = 0
					p.queue_free()
					continue
				p.set_cell(land)
				p.visible = true
	for award in awards:
		await gain_exp(award[0], award[1])


func gain_exp(u: Unit, amount: int) -> void:
	amount = roundi(amount * Skills.exp_multiplier(u))
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
		await battle.ui.show_level_up(u, before, gains)
		for skill in u.skills_learned_at(u.level):
			await learn_skill(u, skill)
	if u.level >= Experience.LEVEL_CAP:
		u.exp_points = 0


## Teaches `u` a skill for good (Unit.learned). With Skills.LEARNED_CAP already
## learned, a player unit picks one to forget, or not to learn the new one; an
## enemy doesn't learn it. Returns whether it was learned.
func learn_skill(u: Unit, skill: String) -> bool:
	if Skills.has(u, skill):
		return false
	if u.learned.size() >= Skills.LEARNED_CAP:
		if u.team != Unit.Team.PLAYER:
			return false
		var options: Array[String] = []
		options.assign(u.learned)
		options.append("Don't learn")
		var index: int = await battle.input.choose(options, "%s: learn %s? Forget:" % [u.unit_name, skill])
		if index >= u.learned.size():
			return false
		u.popup("Forgot " + u.learned[index], Color.LIGHT_GRAY)
		u.learned.remove_at(index)
		await get_tree().create_timer(0.4).timeout
	u.learned.append(skill)
	if not Skills.is_hidden(skill):
		u.popup("Learned " + skill, Color.GOLD)
		await get_tree().create_timer(0.6).timeout
	return true
