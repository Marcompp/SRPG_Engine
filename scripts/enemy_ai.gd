class_name EnemyAI
extends RefCounted
## Simple AI: heal a wounded ally if possible, otherwise make the attack (weapon or
## spell) with the best expected damage, otherwise advance. Units with no way to
## attack stay with their allies.

## Casters only bother healing when it restores at least this much HP.
const MIN_USEFUL_HEAL := 5
## Score penalty per MP spent, so expensive spells are saved for worthwhile casts.
const MP_COST_WEIGHT := 20.0


## Expected damage, plus a bonus scaled by the chance of a kill.
static func _hit_score(dmg: int, hit: int, target: Unit) -> float:
	var score: float = dmg * hit - target.hp
	if dmg >= target.hp:
		score += 10.0 * hit
	return score


## Expected counter damage (halved) if `target` can strike back at the enemy's current cell.
static func _counter_risk(enemy: Unit, target: Unit, map: BattleMap) -> float:
	if not Combat.can_counter(enemy, target):
		return 0.0
	return 0.5 * Combat.damage(target, enemy, map) * Combat.hit_chance(target, enemy, map)


static func take_turn(enemy: Unit, battle: Node) -> void:
	var map: BattleMap = battle.map
	var reach := map.get_reachable(enemy, battle.units())
	var cells: Dictionary = reach.cells
	var players: Array[Unit] = battle.units_of(Unit.Team.PLAYER)
	if players.is_empty():
		return

	battle.cursor.cell = enemy.cell
	await battle.get_tree().create_timer(0.2).timeout

	if await _try_heal(enemy, battle, reach):
		if is_instance_valid(enemy) and enemy.hp > 0:
			enemy.has_acted = true
		return

	# Find the best attack: every (weapon, cell, target) and every (spell, cell, target
	# or blast center). Range affects the triangle and whether the target can counter,
	# so evaluate each candidate with the enemy temporarily standing on that cell.
	var all_units: Array[Unit] = battle.units()
	var best_target: Unit = null
	var best_cell := enemy.cell
	var best_weapon: Dictionary = {}
	var best_spell := ""
	var best_center := Vector2i.ZERO
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
				var score: float = _hit_score(Combat.damage(enemy, p, map), Combat.hit_chance(enemy, p, map), p) \
					- cells[cell] * 0.01 - _counter_risk(enemy, p, map)
				enemy.cell = home
				if score > best_score:
					best_score = score
					best_target = p
					best_cell = cell
					best_weapon = w
					best_spell = ""
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
					if not Spells.reaches(s, BattleMap.distance(cell, p.cell)):
						continue
					var score: float = _hit_score(Combat.spell_damage(enemy, p, spell, map),
						Combat.spell_hit_chance(enemy, p, spell, map), p) \
						- cells[cell] * 0.01 - _counter_risk(enemy, p, map) - mp_cost
					if score > best_score:
						best_score = score
						best_target = p
						best_cell = cell
						best_spell = s
			elif spell.target == "area":
				for c in Spells.area_centers(enemy, s, map, all_units):
					var victims := Spells.area_targets(enemy, s, c, all_units, map)
					if victims.is_empty():
						continue
					var score: float = -cells[cell] * 0.01 - mp_cost
					for v in victims:
						score += _hit_score(Combat.spell_damage(enemy, v, spell, map),
							Combat.spell_hit_chance(enemy, v, spell, map), v)
					if score > best_score:
						best_score = score
						best_target = victims[0]
						best_cell = cell
						best_spell = s
						best_center = c
			enemy.cell = home

	if best_spell:
		var spell := Spells.get_spell(best_spell)
		await enemy.move_along(map.build_path(reach.parents, enemy.cell, best_cell))
		if spell.target == "area":
			battle.cursor.cell = best_center
			await battle.cast_area(enemy, best_center, best_spell)
		else:
			battle.cursor.cell = best_target.cell
			await battle.do_spell_attack(enemy, best_target, best_spell)
	elif best_target:
		enemy.equip(enemy.items.find(best_weapon))
		await enemy.move_along(map.build_path(reach.parents, enemy.cell, best_cell))
		battle.cursor.cell = best_target.cell
		await battle.do_combat(enemy, best_target)
	else:
		# Advance toward the nearest player (measured by terrain cost). Units that
		# can't attack follow their nearest ally instead of walking into the enemy.
		var goals: Array[Unit] = players
		var offensive_spells := enemy.spells.filter(func(s: String) -> bool: return not Spells.is_support(s))
		if enemy.weapon.is_empty() and offensive_spells.is_empty():
			goals = []
			goals.assign(battle.units_of(enemy.team).filter(func(u: Unit) -> bool: return u != enemy))
		if goals.is_empty():
			enemy.has_acted = true
			return
		var nearest: Unit = goals[0]
		for p in goals:
			if BattleMap.distance(enemy.cell, p.cell) < BattleMap.distance(enemy.cell, nearest.cell):
				nearest = p
		var field := map.cost_field(nearest.cell)
		var dest := enemy.cell
		for cell in cells:
			if field.get(cell, INF) < field.get(dest, INF):
				dest = cell
		await enemy.move_along(map.build_path(reach.parents, enemy.cell, dest))

	if is_instance_valid(enemy) and enemy.hp > 0:
		enemy.has_acted = true


## Moves to and heals the ally that would gain the most HP. Returns true if it cast.
static func _try_heal(caster: Unit, battle: Node, reach: Dictionary) -> bool:
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
				if Spells.reaches(s, BattleMap.distance(cell, ally.cell)) \
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
	await battle.cast_heal(caster, best_target, best_spell)
	return true
