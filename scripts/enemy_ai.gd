class_name EnemyAI
extends RefCounted
## Enemy turns, driven by each unit's `ai` settings (see AIProfiles):
##   1. wake check (sleepers switch from `move` to `awake_move` for good)
##   2. retreat check (HP at or below `retreat_below` until back to `retreat_until`)
##   3. heal a wounded ally, if it has healing magic
##   4. retreating: head for a healer / healing tile / away from players
##      otherwise: make the best attack from the cells its move mode allows,
##      or fall back to that mode's movement (advance, stay, return, go to a tile)

## Casters only bother healing when it restores at least this much HP.
const MIN_USEFUL_HEAL := 5
## Score penalty per MP spent, so expensive spells are saved for worthwhile casts.
const MP_COST_WEIGHT := 20.0
## targeting "kill" multiplies the kill bonus by this.
const KILL_FOCUS := 4.0
## Bonus for damaging a target named in `priority`; large enough to dominate.
const PRIORITY_BONUS := 5000.0


# --- Behavior state ---------------------------------------------------------------

## The move mode in effect: sleeping units use `move`, woken ones `awake_move`.
static func current_move(u: Unit) -> String:
	if not u.ai.wake.is_empty() and u.ai_awake:
		return u.ai.awake_move
	return u.ai.move


## Checks a sleeping unit's wake conditions; waking also wakes the rest of its group.
static func update_wake(u: Unit, battle: Battle) -> void:
	var wake: Dictionary = u.ai.wake
	if wake.is_empty() or u.ai_awake:
		return
	var players: Array[Unit] = battle.units_of(Unit.Team.PLAYER)
	var woke := false
	if wake.get("attacked", false) and u.was_attacked:
		woke = true
	if wake.has("turn") and battle.turn >= wake.turn:
		woke = true
	if wake.has("radius"):
		for p in players:
			if BattleMap.distance(u.cell, p.cell) <= wake.radius:
				woke = true
	if wake.get("in_threat", false):
		var reach: Dictionary = battle.map.get_reachable(u, battle.units())
		var threat := threat_from(u, battle, reach.cells)
		for p in players:
			if threat.has(p.cell):
				woke = true
	if wake.has("group"):
		for ally in _group(u, battle):
			if ally.ai_awake:
				woke = true
	if woke:
		u.ai_awake = true
		for ally in _group(u, battle):
			ally.ai_awake = true


static func update_all_wake(battle: Battle) -> void:
	for e in battle.units_of(Unit.Team.ENEMY):
		update_wake(e, battle)


## Other units on the same side sharing this unit's wake group.
static func _group(u: Unit, battle: Battle) -> Array[Unit]:
	var result: Array[Unit] = []
	var group: String = u.ai.wake.get("group", "")
	if group == "":
		return result
	for ally in battle.units_of(u.team):
		if ally != u and ally.ai.wake.get("group", "") == group:
			result.append(ally)
	return result


## Updates `retreating` from HP. Returns true when a retreat just started.
static func update_retreat(u: Unit) -> bool:
	var frac := float(u.hp) / u.max_hp
	if u.retreating and frac >= u.ai.retreat_until:
		u.retreating = false
	elif not u.retreating and u.ai.retreat_below > 0.0 and frac <= u.ai.retreat_below:
		u.retreating = true
		return true
	return false


# --- Movement areas -----------------------------------------------------------------

## Cells (with move cost) a unit in `mode` may act from, out of its full reach.
static func allowed_cells(u: Unit, mode: String, reach_cells: Dictionary) -> Dictionary:
	match mode:
		"hold":
			return {u.cell: 0}
		"guard":
			var result := {u.cell: 0}
			for c in reach_cells:
				if BattleMap.distance(c, u.anchor) <= u.ai.guard_radius:
					result[c] = reach_cells[c]
			return result
	return reach_cells


## Where an enemy could act from next phase, for the danger zone and hover ranges.
## A sleeper counts as already awake (it could wake before it acts), so this
## never understates the threat.
static func movement_cells(u: Unit, battle: Battle) -> Dictionary:
	var reach: Dictionary = battle.map.get_reachable(u, battle.units())
	var mode := current_move(u)
	if not u.ai.wake.is_empty() and not u.ai_awake:
		mode = u.ai.awake_move
	if u.retreating:
		return reach.cells
	return allowed_cells(u, mode, reach.cells)


## Cells threatened from the given movement cells with the unit's weapons and
## affordable damage spells (the movement cells themselves included).
static func threat_from(u: Unit, battle: Battle, move_cells: Dictionary) -> Dictionary:
	var cells := {}
	var ranges: Array[Vector2i] = battle.offense_ranges(u, true)
	if ranges.is_empty() or not u.ai.attack:
		return cells
	for c in move_cells:
		cells[c] = true
	for c in battle.map.get_attack_cells(move_cells, ranges):
		cells[c] = true
	return cells


# --- Scoring ------------------------------------------------------------------------

## How much the attacker wants to hit `target` for `dmg` at `hit`%, per its targeting settings.
static func _target_score(attacker: Unit, dmg: int, hit: int, target: Unit) -> float:
	var score: float
	match attacker.ai.targeting:
		"weakest":
			# Lowest current HP first; expected damage only breaks ties.
			score = dmg * hit * 0.1 - target.hp * 100.0
		"kill":
			score = dmg * hit - target.hp
			if dmg >= target.hp:
				score += 10.0 * hit * KILL_FOCUS
		_:
			score = dmg * hit - target.hp
			if dmg >= target.hp:
				score += 10.0 * hit
	if dmg > 0 and attacker.ai.priority.has(target.unit_name):
		score += PRIORITY_BONUS
	return score


## Expected counter damage if `target` can strike back at the enemy's current cell,
## weighted by the enemy's caution.
static func _counter_risk(enemy: Unit, target: Unit, map: BattleMap) -> float:
	if not Combat.can_counter(enemy, target, map):
		return 0.0
	return enemy.ai.caution * Combat.damage(target, enemy, map, enemy) * Combat.hit_chance(target, enemy, map, enemy)


# --- Turn ---------------------------------------------------------------------------

static func take_turn(enemy: Unit, battle: Battle) -> void:
	var map: BattleMap = battle.map
	var players: Array[Unit] = battle.units_of(Unit.Team.PLAYER)
	if players.is_empty():
		return

	battle.cursor.cell = enemy.cell
	battle.camera.follow(enemy.cell)
	await battle.camera.settle()
	await battle.get_tree().create_timer(0.2).timeout

	update_wake(enemy, battle)
	if update_retreat(enemy):
		enemy.popup("Retreat!", Color.LIGHT_GRAY)

	var reach: Dictionary = map.get_reachable(enemy, battle.units())
	var mode := current_move(enemy)
	var allowed: Dictionary = reach.cells if enemy.retreating else allowed_cells(enemy, mode, reach.cells)

	if await _try_heal(enemy, battle, {"cells": allowed, "parents": reach.parents}):
		_finish(enemy)
		return

	if enemy.ai.get("loot", false) and not enemy.retreating and await _try_loot(enemy, battle, reach):
		_finish(enemy)
		return

	if enemy.retreating:
		var dest := _retreat_cell(enemy, battle, reach)
		await enemy.move_along(map.build_path(reach.parents, enemy.cell, dest))
		if enemy.ai.retreat_attacks:
			var parting_shot := _best_attack(enemy, battle, {enemy.cell: 0})
			if not parting_shot.is_empty():
				await _execute_attack(enemy, battle, parting_shot, reach.parents)
		_finish(enemy)
		return

	var plan := _best_attack(enemy, battle, allowed) if enemy.ai.attack else {}
	if not plan.is_empty():
		await _execute_attack(enemy, battle, plan, reach.parents)
	else:
		match mode:
			"charge":
				await _advance(enemy, battle, reach, players)
			"guard":
				if enemy.cell != enemy.anchor:
					await _move_toward(enemy, battle, reach, enemy.anchor)
			"goto":
				if enemy.ai.destination != Vector2i(-1, -1):
					await _move_toward(enemy, battle, reach, enemy.ai.destination)
			# "hold" and "in_range" stay put.
	_finish(enemy)


## Untyped on purpose: the enemy may have died (and been freed) during its own
## attack, and a typed parameter rejects freed objects before the check below runs.
static func _finish(enemy) -> void:
	if is_instance_valid(enemy) and enemy.hp > 0:
		enemy.has_acted = true


## Best attack from any of `cells`: every (weapon, cell, target) and every (spell,
## cell, target or blast center). Range affects the triangle and whether the target
## can counter, so each candidate is scored with the enemy standing on that cell.
## Returns {} if nothing can be attacked.
static func _best_attack(enemy: Unit, battle: Battle, cells: Dictionary) -> Dictionary:
	var map: BattleMap = battle.map
	var players: Array[Unit] = battle.units_of(Unit.Team.PLAYER)
	var all_units: Array[Unit] = battle.units()
	var best := {}
	var best_score := -INF
	var home := enemy.cell
	var original: Dictionary = enemy.weapon
	for w in enemy.weapons():
		enemy.equip(enemy.items.find(w))
		for p in players:
			for cell in cells:
				if not enemy.can_attack_at(BattleMap.distance(cell, p.cell)):
					continue
				enemy.cell = cell
				var score: float = _target_score(enemy, Combat.damage(enemy, p, map), Combat.hit_chance(enemy, p, map), p) \
					- cells[cell] * 0.01 - _counter_risk(enemy, p, map)
				enemy.cell = home
				if score > best_score:
					best_score = score
					best = {"target": p, "cell": cell, "weapon": w, "spell": ""}
	if not original.is_empty():
		enemy.equip(enemy.items.find(original))

	for s in enemy.spells:
		if Spells.is_support(s) or not Spells.can_afford(enemy, s):
			continue
		var spell := Spells.get_spell(s)
		if spell.has("terraform"):
			continue
		# Spending MP has a cost, so a big spell must earn its price.
		var mp_cost: float = spell.mp * MP_COST_WEIGHT
		for cell in cells:
			enemy.cell = cell
			if spell.target == "enemy":
				for p in players:
					if not Spells.reaches(s, BattleMap.distance(cell, p.cell), enemy):
						continue
					var score: float = _target_score(enemy, Combat.spell_damage(enemy, p, spell, map),
						Combat.spell_hit_chance(enemy, p, spell, map), p) \
						- cells[cell] * 0.01 - _counter_risk(enemy, p, map) - mp_cost
					if score > best_score:
						best_score = score
						best = {"target": p, "cell": cell, "spell": s}
			elif spell.target == "area":
				for c in Spells.area_centers(enemy, s, map, all_units):
					var victims := Spells.area_targets(enemy, s, c, all_units, map)
					if victims.is_empty():
						continue
					var score: float = -cells[cell] * 0.01 - mp_cost
					for v in victims:
						score += _target_score(enemy, Combat.spell_damage(enemy, v, spell, map),
							Combat.spell_hit_chance(enemy, v, spell, map), v)
					if score > best_score:
						best_score = score
						best = {"target": victims[0], "cell": cell, "spell": s, "center": c}
			enemy.cell = home
	return best


static func _execute_attack(enemy: Unit, battle: Battle, plan: Dictionary, parents: Dictionary) -> void:
	var map: BattleMap = battle.map
	if plan.spell == "":
		enemy.equip(enemy.items.find(plan.weapon))
	await enemy.move_along(map.build_path(parents, enemy.cell, plan.cell))
	if plan.spell == "":
		battle.cursor.cell = plan.target.cell
		await battle.actions.do_combat(enemy, plan.target)
	elif Spells.get_spell(plan.spell).target == "area":
		battle.cursor.cell = plan.center
		await battle.actions.cast_area(enemy, plan.center, plan.spell)
	else:
		battle.cursor.cell = plan.target.cell
		await battle.actions.do_spell_attack(enemy, plan.target, plan.spell)


# --- Fallback movement -----------------------------------------------------------

## Advance toward the nearest player (measured by terrain cost). Units that can't
## attack follow their nearest ally instead of walking into the enemy.
static func _advance(enemy: Unit, battle: Battle, reach: Dictionary, players: Array[Unit]) -> void:
	var goals: Array[Unit] = players
	var offensive_spells := enemy.spells.filter(func(s: String) -> bool: return not Spells.is_support(s))
	if enemy.weapon.is_empty() and offensive_spells.is_empty():
		goals = []
		goals.assign(battle.units_of(enemy.team).filter(func(u: Unit) -> bool: return u != enemy))
	if goals.is_empty():
		return
	var nearest: Unit = goals[0]
	for p in goals:
		if BattleMap.distance(enemy.cell, p.cell) < BattleMap.distance(enemy.cell, nearest.cell):
			nearest = p
	await _move_toward(enemy, battle, reach, nearest.cell)


## Moves to the reachable cell closest (by terrain cost) to `target`, then opens or
## breaks whatever blocks the way, if that's the way it planned.
static func _move_toward(enemy: Unit, battle: Battle, reach: Dictionary, target: Vector2i) -> void:
	var map: BattleMap = battle.map
	var field := map.cost_field(target, enemy, _obstacle_costs(enemy, battle))
	var dest := _closest_cell(field, reach.cells, enemy.cell)
	await enemy.move_along(map.build_path(reach.parents, enemy.cell, dest))
	await _clear_obstacle(enemy, battle, field)


# --- Breakable tiles and doors -----------------------------------------------------

## Planning costs for the breakable tiles and doors `u` could get through: a door it
## can open costs one turn, anything else the turns it takes to break, each turn
## counted as a full turn of movement. Empty if `u` doesn't break things.
static func _obstacle_costs(u: Unit, battle: Battle) -> Dictionary:
	var costs := {}
	if not u.ai.get("breaks", true):
		return costs
	var map: BattleMap = battle.map
	var damage: int = _best_tile_weapon(u).damage
	for cell in map.tile_hp:
		var turns := INF
		if map.is_door(cell) and battle.actions.can_open_chest(u):
			turns = 1
		elif damage > 0:
			turns = ceilf(float(map.tile_hp[cell]) / damage)
		if turns < INF:
			costs[cell] = turns * maxf(u.mov, 1) + 1
	return costs


## The weapon that hits tiles hardest: {"index", "damage"} (index -1 if unarmed).
static func _best_tile_weapon(u: Unit) -> Dictionary:
	var best := {"index": -1, "damage": 0}
	var original: Dictionary = u.weapon
	for w in u.weapons():
		u.equip(u.items.find(w))
		var damage := Combat.base_attack(u)
		if damage > best.damage:
			best = {"index": u.items.find(w), "damage": damage}
	if not original.is_empty():
		u.equip(u.items.find(original))
	return best


## Opens or breaks the obstacle in reach that lies furthest along the way `field`
## leads (closer to the goal than `u` is). Returns true if it did something.
static func _clear_obstacle(u: Unit, battle: Battle, field: Dictionary) -> bool:
	if not is_instance_valid(u) or u.hp <= 0 or not u.ai.get("breaks", true):
		return false
	var map: BattleMap = battle.map
	var best := Vector2i(-1, -1)
	var opens := false
	for d in BattleMap.DIRS:
		var cell := u.cell + d
		if map.is_door(cell) and battle.actions.can_open_chest(u) and field.get(cell, INF) < field.get(u.cell, INF):
			if best == Vector2i(-1, -1) or field[cell] < field[best]:
				best = cell
				opens = true
	if opens:
		battle.cursor.cell = best
		await battle.actions.do_open_door(u, best)
		return true
	var weapon: Dictionary = _best_tile_weapon(u)
	if weapon.index < 0:
		return false
	u.equip(weapon.index)
	for cell in battle.actions.breakable_cells(u, u.weapon):
		if field.get(cell, INF) < field.get(u.cell, INF) and (best == Vector2i(-1, -1) or field[cell] < field[best]):
			best = cell
	if best == Vector2i(-1, -1):
		return false
	battle.cursor.cell = best
	await battle.actions.do_break(u, best)
	return true


static func _closest_cell(field: Dictionary, cells: Dictionary, start: Vector2i) -> Vector2i:
	var dest := start
	for c in cells:
		if field.get(c, INF) < field.get(dest, INF):
			dest = c
	return dest


## Where a retreating unit heads this turn, per `retreat_to`: next to the nearest
## ally that can heal, onto the nearest free healing tile, or away from players.
static func _retreat_cell(u: Unit, battle: Battle, reach: Dictionary) -> Vector2i:
	var map: BattleMap = battle.map
	var mode: String = u.ai.retreat_to
	if mode == "healer_or_tile" or mode == "healer":
		var healer: Unit = null
		for ally in battle.units_of(u.team):
			if ally == u:
				continue
			var can_heal: bool = ally.spells.any(func(s: String) -> bool:
				return Spells.is_support(s) and Spells.can_afford(ally, s))
			if can_heal and (healer == null
					or BattleMap.distance(u.cell, ally.cell) < BattleMap.distance(u.cell, healer.cell)):
				healer = ally
		if healer:
			return _closest_cell(map.cost_field(healer.cell, u), reach.cells, u.cell)
	if mode == "healer_or_tile" or mode == "tile":
		if map.terrain_heal(u.cell) > 0.0:
			return u.cell
		var tile := Vector2i(-1, -1)
		for c in map.healing_cells():
			var occupant: Unit = battle.unit_at(c)
			if occupant and occupant != u:
				continue
			if tile == Vector2i(-1, -1) or BattleMap.distance(u.cell, c) < BattleMap.distance(u.cell, tile):
				tile = c
		if tile != Vector2i(-1, -1):
			return _closest_cell(map.cost_field(tile, u), reach.cells, u.cell)
	# Away: the reachable cell farthest from the nearest player.
	var players: Array[Unit] = battle.units_of(Unit.Team.PLAYER)
	var best := u.cell
	var best_dist := -1
	for c in reach.cells:
		var nearest := 999
		for p in players:
			nearest = mini(nearest, BattleMap.distance(c, p.cell))
		if nearest > best_dist:
			best_dist = nearest
			best = c
	return best


## Looters head for the nearest intact village or chest and loot it on arrival.
## Returns false when there's nothing left to loot (the unit then moves as usual).
static func _try_loot(enemy: Unit, battle: Battle, reach: Dictionary) -> bool:
	var map: BattleMap = battle.map
	var targets: Array = map.lootable_objects()
	if targets.is_empty():
		return false
	var field: Dictionary = {}
	var target: Dictionary = {}
	var obstacles := _obstacle_costs(enemy, battle)
	for o in targets:
		var f := map.cost_field(o.cell, enemy, obstacles)
		if not f.has(enemy.cell):
			continue
		if target.is_empty() or f[enemy.cell] < field[enemy.cell]:
			target = o
			field = f
	if target.is_empty():
		return false
	if enemy.cell != target.cell:
		var dest := _closest_cell(field, reach.cells, enemy.cell)
		await enemy.move_along(map.build_path(reach.parents, enemy.cell, dest))
	if enemy.cell == target.cell:
		await battle.actions.loot(enemy, target)
	else:
		await _clear_obstacle(enemy, battle, field)
	return true


## Moves to and heals the ally that would gain the most HP. Returns true if it cast.
static func _try_heal(caster: Unit, battle: Battle, reach: Dictionary) -> bool:
	var cells: Dictionary = reach.cells
	var best_spell := ""
	var best_target: Unit = null
	var best_cell := caster.cell
	var best_amount := MIN_USEFUL_HEAL - 1
	for s in caster.spells:
		if not Spells.is_support(s) or not Spells.can_afford(caster, s):
			continue
		var spell := Spells.get_spell(s)
		for ally in battle.units_of(caster.team):
			if ally == caster:
				continue
			var amount := Spells.heal_amount(caster, spell, ally)
			if amount <= best_amount:
				continue
			# Cheapest reachable cell the spell reaches the ally from.
			var cell_found := false
			var cast_cell := caster.cell
			for cell in cells:
				if Spells.reaches(s, BattleMap.distance(cell, ally.cell), caster) \
						and (not cell_found or cells[cell] < cells[cast_cell]):
					cast_cell = cell
					cell_found = true
			if cell_found:
				best_spell = s
				best_target = ally
				best_cell = cast_cell
				best_amount = amount
	if not best_target:
		return false
	var map: BattleMap = battle.map
	await caster.move_along(map.build_path(reach.parents, caster.cell, best_cell))
	battle.cursor.cell = best_target.cell
	await battle.actions.cast_heal(caster, best_target, best_spell)
	return true
