class_name BattleActions
extends Node
## What units do: target queries ("who can this unit shove?") and the
## actions themselves, with their animations, for both the player and the enemy
## AI, including combat resolution and EXP.

var battle: Battle
## Player units that already got a close-call biography entry this battle.
var _close_calls := {}


# --- Who can do what ----------------------------------------------------------

func enemies_in_range(u: Unit, w: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	for e in battle.foes_of(u):
		if u.reaches(w, BattleMap.distance(u.cell, e.cell)):
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
	if not u.can_use_magic():
		return result
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


## Units on sides friendly to `u`'s (its own, and green allies for the player's): the
## ones it can support (Heal, Rescue). Trade, Shove, Inspire and Dance stay within
## its own side.
func friendly_units(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for o in battle.units():
		if Factions.friendly(u.team, o.team):
			result.append(o)
	return result


## Provoking: the player's side attacking a neutral turns all neutrals hostile to
## the player (they fight back on their phase).
func provoke(attacker: Unit, target: Unit) -> void:
	if attacker.team != Unit.Team.PLAYER or target.team != Unit.Team.NEUTRAL \
			or Factions.hostile(Unit.Team.NEUTRAL, Unit.Team.PLAYER):
		return
	Factions.set_hostile(Unit.Team.NEUTRAL, Unit.Team.PLAYER, true)
	target.popup(tr("Provoked!"), Color.ORANGE_RED, 10.0)
	battle.refresh_threat()


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
	u.popup(tr("Seize!"), Color.GOLD)
	u.biography.append(Text.entry("Seized {map}.", {"map": map_title()}))
	battle.objective_done = true
	await get_tree().create_timer(0.5).timeout


## The unit (and whoever it carries) leaves the map for good; the Lord leaving wins.
func do_escape(u: Unit) -> void:
	u.popup(tr("Escape"), Color.PALE_GREEN)
	await get_tree().create_timer(0.4).timeout
	u.escaped = true
	u.visible = false
	if u.is_lord:
		battle.objective_done = true


func do_visit(u: Unit) -> void:
	await battle.events.on_visit(u.cell)
	var village := battle.map.object_at(u.cell)
	village.state = "visited"
	battle.map.queue_redraw()
	if village.has("item"):
		u.popup(give_item(u, village.item), Color.GOLD)
	battle.add_gold(village.get("gold", 0), u)
	await get_tree().create_timer(0.7).timeout


## Units with Lockpick open chests freely; anyone else needs a Chest Key.
func can_open_chest(u: Unit) -> bool:
	return Skills.has(u, "Lockpick") or u.items.any(func(it): return it.name == "Chest Key")


func do_open(u: Unit) -> void:
	var chest := battle.map.object_at(u.cell)
	_spend_key(u)
	chest.state = "opened"
	battle.map.queue_redraw()
	if chest.has("item"):
		u.popup(give_item(u, chest.item), Color.GOLD)
	battle.add_gold(chest.get("gold", 0), u)
	await get_tree().create_timer(0.7).timeout


## Lockpick opens chests and doors freely; anyone else uses up a Chest Key.
func _spend_key(u: Unit) -> void:
	if Skills.has(u, "Lockpick"):
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
		return tr("Got {item}").format({"item": item_name})
	if Campaign.active:
		Campaign.convoy.append(Items.make(item_name))
		return tr("{item} to convoy").format({"item": item_name})
	return tr("No room: {item}").format({"item": item_name})


## An enemy on a village burns it (its reward is lost); on a chest, takes the item
## and the gold.
func loot(enemy: Unit, object: Dictionary) -> void:
	if object.type == "village":
		object.state = "looted"
		enemy.popup(tr("Looted!"), Color.ORANGE_RED)
	else:
		object.state = "opened"
		if object.has("item"):
			if enemy.items.size() < Unit.MAX_ITEMS:
				enemy.items.append(Items.make(object.item))
			enemy.popup(tr("Stole {item}").format({"item": object.item}), Color.ORANGE_RED)
		# The chest's gold goes with the looter: defeat it to get it back.
		enemy.gold += object.get("gold", 0)
	battle.map.queue_redraw()
	await get_tree().create_timer(0.6).timeout


# --- Repair -----------------------------------------------------------------------

## Weapons `u` carries that have used up some of their uses (indices in u.items).
func repairable_weapons(u: Unit) -> Array[int]:
	var result: Array[int] = []
	for i in u.items.size():
		var it := u.items[i]
		if Items.is_weapon(it) and it.uses < Weapons.max_uses(it):
			result.append(i)
	return result


## Uses the repair item at `kit` to restore the weapon at `weapon` to full uses.
func repair_weapon(u: Unit, kit: int, weapon: int) -> void:
	var w := u.items[weapon]
	w.uses = Weapons.max_uses(w)
	u.popup(tr("Repaired {item}").format({"item": w.name}), Color.PALE_GREEN)
	u.items[kit].uses -= 1
	if u.items[kit].uses <= 0:
		u.items.remove_at(kit)
	await get_tree().create_timer(0.5).timeout


# --- Steal ------------------------------------------------------------------------

## Items `target` carries that can be stolen: anything but weapons (as in GBA FE).
func stealable_items(target: Unit) -> Array[int]:
	var result: Array[int] = []
	for i in target.items.size():
		if not Items.is_weapon(target.items[i]):
			result.append(i)
	return result


## Adjacent foes `u` can steal from: it needs the Steal skill, room for the item (or
## the campaign convoy) and more AGI than the foe.
func steal_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not Skills.commands(u).has("steal") or (u.items.size() >= Unit.MAX_ITEMS and not Campaign.active):
		return result
	for foe in battle.units():
		if Factions.hostile(u.team, foe.team) and BattleMap.distance(u.cell, foe.cell) == 1 \
				and u.combat_agi() > foe.combat_agi() and (not stealable_items(foe).is_empty() or foe.gold > 0):
			result.append(foe)
	return result


## `index`: the item in foe.items, or -1 for its gold.
func do_steal(u: Unit, foe: Unit, index: int) -> void:
	provoke(u, foe)
	if index < 0:
		await u.lunge(foe.cell)
		battle.add_gold(foe.gold, u)
		foe.gold = 0
		await get_tree().create_timer(0.5).timeout
		if gains_exp(u):
			await gain_exp(u, Experience.STEAL_EXP)
		return
	var item: Dictionary = foe.items[index]
	foe.items.remove_at(index)
	await u.lunge(foe.cell)
	if u.items.size() < Unit.MAX_ITEMS:
		u.items.append(item)
		u.popup(tr("Stole {item}").format({"item": item.name}), Color.GOLD)
	else:
		Campaign.convoy.append(item)
		u.popup(tr("{item} to convoy").format({"item": item.name}), Color.GOLD)
	await get_tree().create_timer(0.5).timeout
	if gains_exp(u):
		await gain_exp(u, Experience.STEAL_EXP)


# --- Breakable tiles and doors (see BattleMap breakable terrain) --------------

## Damage dealt to a breakable tile: the unit's Attack (STR + weapon might). Always
## hits, never crits, no counter, no EXP.
func tile_damage(u: Unit) -> int:
	return Combat.base_attack(u) if not u.weapon.is_empty() else 0


## Breakable tiles `w` can reach from where `u` stands.
func breakable_cells(u: Unit, w: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in battle.map.tile_hp:
		if u.reaches(w, BattleMap.distance(u.cell, cell)):
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
	u.popup(tr("{tile} -{damage}").format({"tile": tile_name, "damage": amount}), Color.WHITE)
	if u.use_weapon():
		u.popup(tr("Broke!"), Color.LIGHT_GRAY)
	var broke := battle.map.damage_tile(cell, amount, u.cell)
	if broke:
		await get_tree().create_timer(0.3).timeout
		u.popup(tr("{tile} broken!").format({"tile": tile_name}), Color.GOLD)
	await get_tree().create_timer(0.5).timeout


func do_open_door(u: Unit, cell: Vector2i) -> void:
	battle.map.clear_ranges()
	_spend_key(u)
	battle.map.set_terrain(cell, battle.map.breakable_info(cell).becomes)
	u.popup(tr("Door opened"), Color.GOLD)
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
	shover.popup(tr("Shove"), Color.WHITE)
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
	for ally in friendly_units(u):
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
	rescuer.popup(tr("Rescue"), Color.WHITE)
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
	u.popup(tr("Board"), Color.WHITE)
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
	u.popup(tr("Inspire"), Color.GOLD)
	await get_tree().create_timer(0.3).timeout
	for ally in allies:
		ally.inspire_bonus = maxi(ally.inspire_bonus, bonus)
		ally.popup(tr("STR/DEF +%d") % bonus, Color.GOLD)
	await get_tree().create_timer(0.5).timeout
	if gains_exp(u):
		await gain_exp(u, Experience.INSPIRE_EXP)


## Duet: Dancing an ally that can Dance too. The troupe is the two of them plus
## every dancer chained to them by adjacency; the other allies next to any troupe
## member who have acted are refreshed. The troupe isn't, so dancers can't loop.
## {"troupe": Array[Unit], "refreshed": Array[Unit]}, or {} for a plain Dance.
func duet(dancer: Unit, target: Unit) -> Dictionary:
	if not Skills.commands(target).has("dance"):
		return {}
	var allies := battle.units_of(dancer.team)
	var troupe: Array[Unit] = [dancer, target]
	var i := 0
	while i < troupe.size():
		for ally in allies:
			if not troupe.has(ally) and Skills.commands(ally).has("dance") \
					and BattleMap.distance(troupe[i].cell, ally.cell) == 1:
				troupe.append(ally)
		i += 1
	var refreshed: Array[Unit] = []
	for ally in allies:
		if ally.has_acted and not troupe.has(ally) and troupe.any(func(t: Unit) -> bool:
				return BattleMap.distance(t.cell, ally.cell) == 1):
			refreshed.append(ally)
	return {"troupe": troupe, "refreshed": refreshed}


## Refreshes the target so it can move and act again this phase, or performs a
## Duet when the target can Dance too.
func do_dance(dancer: Unit, target: Unit) -> void:
	var d := duet(dancer, target)
	dancer.popup(tr("Duet") if d else tr("Dance"), Color.PINK)
	await dancer.lunge(target.cell)
	if d:
		for t: Unit in d.troupe:
			if t != dancer:
				t.popup(tr("Duet"), Color.PINK)
		for ally: Unit in d.refreshed:
			ally.has_acted = false
			ally.popup(tr("Refreshed"), Color.PINK)
	else:
		target.has_acted = false
		target.popup(tr("Refreshed"), Color.PINK)
	await get_tree().create_timer(0.5).timeout
	if earns_exp(dancer):
		await gain_exp(dancer, Experience.DANCE_EXP)


func cast_heal(caster: Unit, target: Unit, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var amount := Spells.heal_amount(caster, spell, target)
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	await caster.lunge(target.cell)
	if spell.get("cures", false):
		Statuses.cure(target)
		target.popup(tr("Cured"), Color.PALE_GREEN)
	else:
		target.heal(amount)
		target.popup("+%d" % amount, Color.PALE_GREEN)
	await get_tree().create_timer(0.5).timeout
	if gains_exp(caster):
		await gain_exp(caster, spell.exp)


# --- Combat -------------------------------------------------------------------

func do_combat(attacker: Unit, defender: Unit) -> void:
	provoke(attacker, defender)
	await battle.events.before_battle(attacker, defender)
	# A weapon that breaks stays equipped, weakened, for the rest of the fight.
	var dealt: Array[Unit] = []
	defender.notify_attacked()
	for pair in Combat.strike_order(attacker, defender, battle.map):
		var a: Unit = pair[0]
		var d: Unit = pair[1]
		if a.hp <= 0 or d.hp <= 0:
			break
		if a.weapon.is_empty():
			continue
		var result := Combat.strike(a, d, battle.map, attacker)
		result["counter"] = a != attacker
		await a.lunge(d.cell, result.crit)
		_apply_strike(a, d, result, dealt)
		if result.hit and a.use_weapon():
			a.popup(tr("Broke!"), Color.LIGHT_GRAY)
		await get_tree().create_timer(0.45).timeout
	await _finish_exchange(attacker, defender, dealt)


## Single-target damage spell: one cast (never doubles), then the target may counter once.
func do_spell_attack(caster: Unit, target: Unit, spell_name: String) -> void:
	provoke(caster, target)
	await battle.events.before_battle(caster, target)
	var spell := Spells.get_spell(spell_name)
	var dealt: Array[Unit] = []
	target.notify_attacked()
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	var result := Combat.spell_strike(caster, target, spell, battle.map)
	await caster.lunge(target.cell, result.crit)
	_apply_strike(caster, target, result, dealt)
	await get_tree().create_timer(0.45).timeout
	if target.hp > 0 and not spell.get("status_only", false) and Combat.can_counter(caster, target, battle.map):
		var counter := Combat.strike(target, caster, battle.map, caster)
		counter["counter"] = true
		await target.lunge(caster.cell, counter.crit)
		_apply_strike(target, caster, counter, dealt)
		if counter.hit and target.use_weapon():
			target.popup(tr("Broke!"), Color.LIGHT_GRAY)
		await get_tree().create_timer(0.45).timeout
	await _finish_exchange(caster, target, dealt)


## Area spell: separate hit roll per enemy in the blast, no counters.
## Terraforming spells then change the target cell, hit or miss.
func cast_area(caster: Unit, center: Vector2i, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var victims := Spells.area_targets(caster, spell_name, center, battle.units(), battle.map)
	for v in victims:
		provoke(caster, v)
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
	if gains_exp(caster) and not victims.is_empty():
		var total := 0
		for v in victims:
			total += Experience.combat_exp(caster, v, damaged.has(v), v.hp <= 0)
		var mount_total := 0
		if not caster.mount.is_empty():
			for v in victims:
				mount_total += Experience.mount_combat_exp(caster.mount, v, damaged.has(v), v.hp <= 0)
		awards.append([caster, mini(total, Experience.EXP_PER_LEVEL), mini(mount_total, Experience.EXP_PER_LEVEL)])
	await _remove_dead_and_award(victims, awards)


## Applies one strike's result with popups; records the striker in `dealt` if it did damage.
func _apply_strike(a: Unit, d: Unit, result: Dictionary, dealt: Array[Unit]) -> void:
	var saved_by := ""
	for proc in result.get("procs", []):
		if not Skills.is_hidden(proc[1]):
			proc[0].popup(proc[1] + "!", Color.GOLD, 10.0)
		if proc[0] == d and Skills.get_data(proc[1]).proc.effect == "survive":
			saved_by = proc[1]
	if result.get("heal", 0) > 0:
		a.heal(result.heal)
		a.popup("+%d" % result.heal, Color.PALE_GREEN)
	if result.hit and result.get("no_damage", false):
		pass
	elif result.hit:
		d.take_damage(result.dmg)
		if result.dmg > 0 and not dealt.has(a):
			dealt.append(a)
		d.popup((tr("Crit! %d") if result.crit else "%d") % result.dmg,
			Color.ORANGE if result.crit else Color.WHITE, 0.0, result.crit)
		if result.dmg > 0:
			d.recoil(a.cell, result.crit)
		if result.crit or d.hp <= 0:
			battle.camera.shake(3.0 if result.crit else 2.0)
		if d.hp <= 0 and d.mount.get("skills", []).has("Loyal"):
			_loyal_save(d)
		elif d.hp <= 0:
			_record_kill(a, d, result)
		elif saved_by != "":
			_note(d, Text.entry("Survived a lethal blow from {foe} at {map}, thanks to {skill}.",
				{"foe": foe_label(a), "map": map_title(), "skill": saved_by}))
		elif result.dmg > 0:
			_record_close_call(d, a)
	else:
		d.popup(tr("Miss"), Color.LIGHT_GRAY)
		d.dodge(a.cell)
	# After the damage, so a sleep-inducing hit isn't undone by its own damage.
	if result.hit and result.get("inflict", "") != "" and d.hp > 0:
		inflict(d, result.inflict)


## Loyal: the mount takes the fatal blow and falls; the rider stays, on foot, at 1 HP.
func _loyal_save(d: Unit) -> void:
	var lost := d.dismount()
	d.hp = 1
	d.popup(tr("{mount} fell!").format({"mount": lost.name}), Color.LIGHT_GRAY, 10.0)
	_note(d, Text.entry("Lost {mount}, their {species}, at {map}.",
		{"mount": lost.name, "species": str(lost.species).to_lower(), "map": map_title()}))
	d.queue_redraw()
	battle.refresh_threat()


## The map's name for biographies: "Border Village" for "Chapter 1: Border Village".
func map_title() -> String:
	var title: String = Levels.get_level(Levels.selected).name
	return title.get_slice(": ", 1) if title.contains(": ") else title


## How a biography names a foe: "Garret the Brigand" for generics (a Text entry).
func foe_label(u: Unit) -> Variant:
	return Text.entry("{name} the {class}", {"name": u.unit_name, "class": u.unit_class}) if u.generic else u.unit_name


## Adds a biography entry (a Text entry) for player units (enemies have no Biography page).
func _note(u: Unit, entry: Dictionary) -> void:
	if u.team == Unit.Team.PLAYER:
		u.biography.append(entry)


## Kill counts (unit and weapon) and kill biography moments: a boss (noting a
## critical finishing blow) or a unit's first kill.
func _record_kill(a: Unit, d: Unit, result: Dictionary) -> void:
	# The player's side takes the gold a defeated unit carried.
	if a.team == Unit.Team.PLAYER and d.gold > 0:
		battle.add_gold(d.gold, a)
		d.gold = 0
	if a.team == d.team:
		var text := "Struck down {foe}, an ally, while berserk at {map}." if Statuses.is_berserk(a) \
			else "Struck down {foe}, an ally gone berserk, at {map}."  # i18n
		_note(a, Text.entry(text, {"foe": foe_label(d), "map": map_title()}))
		return
	a.kills += 1
	if not result.get("spell", false) and not a.weapon.is_empty():
		var alone := not battle.units().any(func(o: Unit) -> bool:
			return o != a and o.team == a.team and BattleMap.distance(o.cell, a.cell) == 1)
		var weapon_name: String = a.weapon.name
		var earned := WeaponTraits.record_kill(a.weapon, a, d, result, alone)
		if earned != "":
			a.popup(tr("{weapon}: {trait}!").format({"weapon": weapon_name, "trait": tr(earned)}), Color.GOLD, 20.0)
			_note(a, Text.entry("Their {weapon} earned {trait} at {map}, after {kills} kills.",
				{"weapon": weapon_name, "trait": earned, "map": map_title(), "kills": WeaponTraits.KILLS_FOR_TRAIT}))
	if d.is_boss:
		var text := "Defeated {foe} with a critical hit at {map}." if result.crit else "Defeated {foe} at {map}."  # i18n
		_note(a, Text.entry(text, {"foe": foe_label(d), "map": map_title()}))
	elif a.kills == 1:
		_note(a, Text.entry("Felled their first foe, {foe}, at {map}.", {"foe": foe_label(d), "map": map_title()}))


## A player unit left at 10% HP or less (at least 1) by a hit: once per battle.
func _record_close_call(d: Unit, a: Unit) -> void:
	if d.team != Unit.Team.PLAYER or _close_calls.has(d) or d.hp > maxi(1, d.max_hp / 10):
		return
	_close_calls[d] = true
	_note(d, Text.entry("Barely survived {foe} at {map}, with {hp} HP left.",
		{"foe": foe_label(a), "map": map_title(), "hp": d.hp}))


## EXP for both sides of a one-on-one exchange, then deaths.
func _finish_exchange(attacker: Unit, defender: Unit, dealt: Array[Unit]) -> void:
	# Work out EXP before dead units are freed.
	var awards: Array = []
	for pair in [[attacker, defender], [defender, attacker]]:
		var u: Unit = pair[0]
		var foe: Unit = pair[1]
		# No EXP for fighting a side that's no foe either way (your own, when Berserk).
		if gains_exp(u) and not Factions.friendly(u.team, foe.team) and u.hp > 0:
			var mount_exp := 0 if u.mount.is_empty() \
				else Experience.mount_combat_exp(u.mount, foe, dealt.has(u), foe.hp <= 0)
			awards.append([u, Experience.combat_exp(u, foe, dealt.has(u), foe.hp <= 0), mount_exp])
	# After-combat skills, also decided before the dead are freed.
	var after := []
	for pair in [[attacker, defender], [defender, attacker]]:
		var u: Unit = pair[0]
		var foe: Unit = pair[1]
		if u.hp > 0:
			for effect in Skills.after_combat(u, foe, battle.map, u == attacker, foe.hp <= 0):
				after.append([u, foe, foe.cell, effect])
	var involved: Array[Unit] = [attacker, defender]
	await _remove_dead_and_award(involved, awards)
	for entry in after:
		await _after_combat(entry[0], entry[1], entry[2], entry[3])


## Applies one after_combat skill effect (see Skills) for `u`, whose foe stood at
## `foe_cell`. Untyped units on purpose: either may have died and been freed, and
## a typed parameter rejects freed objects before the checks below run.
func _after_combat(u, foe, foe_cell: Vector2i, effect: Dictionary) -> void:
	if not is_instance_valid(u) or u.hp <= 0:
		return
	var shown := not Skills.is_hidden(effect.skill)
	match effect.effect:
		"heal":
			var amount := mini(ceili(u.max_hp * effect.value), u.max_hp - u.hp)
			if amount <= 0:
				return
			u.heal(amount)
			u.popup("+%d" % amount, Color.PALE_GREEN)
		"refresh":
			if u.refreshed:
				return
			u.refreshed = true
			u.refresh_pending = true
		"inflict":
			if not is_instance_valid(foe) or foe.hp <= 0:
				return
			inflict(foe, effect.value)
		"damage_foe", "damage_near_foe":
			var victims: Array[Unit] = []
			if effect.effect == "damage_foe":
				if is_instance_valid(foe) and foe.hp > 0:
					victims.append(foe)
			else:
				for o in battle.units():
					if Factions.hostile(u.team, o.team) and o != foe and BattleMap.distance(o.cell, foe_cell) <= 2:
						victims.append(o)
			if victims.is_empty():
				return
			for v in victims:
				var amount := mini(ceili(v.max_hp * effect.value), v.hp - 1)
				if amount > 0:
					v.take_damage(amount)
					v.popup("-%d" % amount, Color.MEDIUM_PURPLE)
	if shown:
		u.popup(effect.skill + "!", Color.GOLD, 10.0)
	await get_tree().create_timer(0.4).timeout


## Gives `u` a status (for `turns`; 0: its default), with a popup: its name, or
## "Immune". Returns whether it took.
func inflict(u: Unit, status: String, turns := 0) -> bool:
	var took := Statuses.inflict(u, status, turns)
	u.popup(status if took else tr("Immune"), Statuses.get_data(status).color if took else Color.LIGHT_GRAY)
	return took


## Removes units killed outside a fight (e.g. by poison): no EXP for anyone. `how`
## starts their campaign biography's last line ("Succumbed to poison in ...").
func remove_dead(units: Array[Unit], how := "Fell") -> void:
	await _remove_dead_and_award(units, [], how)


func _remove_dead_and_award(involved: Array[Unit], awards: Array, how := "Fell") -> void:
	for u in involved:
		if u.hp <= 0 and u.team == Unit.Team.PLAYER:
			battle.campaign_deaths.append({"name": u.unit_name, "turn": battle.turn, "how": how})
		if u.hp <= 0:
			await battle.events.on_death(u)
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
		await gain_exp(award[0], award[1], award[2])


## Whether `u` still gets anything from EXP: its own levels, or its mount's (a
## level-20 rider's mount keeps learning).
## The player's units and green allies earn EXP (allies level up without the
## level-up window), if they still can (see earns_exp).
func gains_exp(u: Unit) -> bool:
	return (u.team == Unit.Team.PLAYER or u.team == Unit.Team.ALLY) and earns_exp(u)


func earns_exp(u: Unit) -> bool:
	return u.level < Experience.LEVEL_CAP or (not u.mount.is_empty() and u.mount.level < Mounts.LEVEL_CAP)


## `mount_amount`: what its mount earns, worked out separately (see
## Experience.mount_combat_exp); -1 (non-combat EXP): `amount` times the species rate.
func gain_exp(u: Unit, amount: int, mount_amount := -1) -> void:
	if mount_amount < 0 and not u.mount.is_empty():
		mount_amount = roundi(amount * Mounts.species_data(u.mount.species).exp_rate)
	amount = roundi(amount * Skills.exp_multiplier(u))
	if u.level >= Experience.LEVEL_CAP:
		await _mount_exp(u, mount_amount)
		return
	u.popup(tr("+%d EXP") % amount, Color.AQUAMARINE)
	await get_tree().create_timer(0.5).timeout
	u.exp_points += amount
	while u.exp_points >= Experience.EXP_PER_LEVEL and u.level < Experience.LEVEL_CAP:
		u.exp_points -= Experience.EXP_PER_LEVEL
		var gains := Experience.roll_level_up(u)
		var before := {}
		for key in Experience.STATS:
			before[key] = u.get(Experience.STATS[key])
		Experience.apply_level_up(u, gains)
		if u.team == Unit.Team.PLAYER:
			await battle.ui.show_level_up(u, before, gains)
		else:
			u.popup(tr("Level %d!") % u.level, Color.AQUAMARINE, 10.0)
			await get_tree().create_timer(0.5).timeout
		for skill in u.skills_learned_at(u.level):
			await learn_skill(u, skill)
	if u.level >= Experience.LEVEL_CAP:
		u.exp_points = 0
	await _mount_exp(u, mount_amount)


## The mount's own EXP and level-ups (shown in a small panel).
func _mount_exp(u: Unit, amount: int) -> void:
	if u.mount.is_empty() or amount <= 0:
		return
	for gains in Mounts.gain_exp(u.mount, amount):
		var parts: Array[String] = []
		for s in gains:
			parts.append("%s+1" % tr(Experience.STAT_LABELS[s]))
		battle.ui.show_cell_forecast(tr("{mount} reached Lv {level}!").format({"mount": u.mount.name, "level": u.mount.level})
			+ "\n" + ("  ".join(parts) if not parts.is_empty() else tr("No gains")), u.cell)
		await get_tree().create_timer(1.2).timeout
		battle.ui.hide_forecast()


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
		options.append("Don't learn")  # i18n
		var index: int = await battle.input.choose(options,
			tr("{unit}: learn {skill}? Forget:").format({"unit": u.unit_name, "skill": skill}))
		if index >= u.learned.size():
			return false
		u.popup(tr("Forgot {skill}").format({"skill": u.learned[index]}), Color.LIGHT_GRAY)
		u.learned.remove_at(index)
		await get_tree().create_timer(0.4).timeout
	u.learned.append(skill)
	if not Skills.is_hidden(skill):
		u.popup(tr("Learned {skill}").format({"skill": skill}), Color.GOLD)
		await get_tree().create_timer(0.6).timeout
	return true
