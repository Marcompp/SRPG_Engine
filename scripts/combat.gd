class_name Combat
extends RefCounted
## Combat math, modeled on the GBA Fire Emblem formulas.

const DOUBLE_THRESHOLD := 4
const CRIT_MULTIPLIER := 3
const TRIANGLE_DMG := 1
const TRIANGLE_HIT := 15
## Key beats value.
const TRIANGLE := {"sword": "axe", "axe": "lance", "lance": "sword"}


## +1 if a has weapon-triangle advantage over b, -1 if disadvantage, else 0.
## Bows sit outside the triangle but always win it when striking from range.
static func triangle(a: Unit, b: Unit) -> int:
	if a.weapon.is_empty() or b.weapon.is_empty():
		return 0
	var a_bow: bool = a.weapon.type == "bow"
	var b_bow: bool = b.weapon.type == "bow"
	if a_bow != b_bow and BattleMap.distance(a.cell, b.cell) >= 2:
		return 1 if a_bow else -1
	if TRIANGLE.get(a.weapon.type) == b.weapon.type:
		return 1
	if TRIANGLE.get(b.weapon.type) == a.weapon.type:
		return -1
	return 0


## Agility after weapon weight burden (STR offsets weight).
static func attack_speed(u: Unit) -> int:
	return u.agility - maxi(0, u.weapon.get("wt", 0) - u.strength)


# Unit-only parts of the formulas (equipped weapon, no target or terrain). These are
# what the stats screen shows; the matchup functions below build on them.

static func base_attack(u: Unit) -> int:
	return u.strength + u.weapon.mt


static func base_hit(u: Unit) -> int:
	return u.weapon.hit + u.dexterity * 2 + int(u.luck * 0.5)


static func base_avoid(u: Unit) -> int:
	return attack_speed(u) * 2 + u.luck


static func base_crit(u: Unit) -> int:
	return u.weapon.crit + int(u.dexterity * 0.5)


static func damage(attacker: Unit, defender: Unit, map: BattleMap) -> int:
	if attacker.weapon.is_empty():
		return 0
	var atk: int = base_attack(attacker) + triangle(attacker, defender) * TRIANGLE_DMG
	return maxi(0, atk - (defender.defense + map.unit_terrain_def(defender)))


static func hit_chance(attacker: Unit, defender: Unit, map: BattleMap) -> int:
	if attacker.weapon.is_empty():
		return 0
	var hit: int = base_hit(attacker) + triangle(attacker, defender) * TRIANGLE_HIT
	var avoid: int = base_avoid(defender) + map.unit_terrain_avoid(defender)
	return clampi(hit - avoid, 0, 100)


static func crit_chance(attacker: Unit, defender: Unit) -> int:
	if attacker.weapon.is_empty():
		return 0
	return clampi(base_crit(attacker) - defender.luck, 0, 100)


static func doubles(a: Unit, b: Unit) -> bool:
	return attack_speed(a) >= attack_speed(b) + DOUBLE_THRESHOLD


static func can_counter(attacker: Unit, defender: Unit) -> bool:
	return defender.can_attack_at(BattleMap.distance(attacker.cell, defender.cell))


## List of [striker, target] pairs in the order they happen.
static func strike_order(attacker: Unit, defender: Unit) -> Array:
	var order := [[attacker, defender]]
	var counter := can_counter(attacker, defender)
	if counter:
		order.append([defender, attacker])
	if doubles(attacker, defender):
		order.append([attacker, defender])
	elif counter and doubles(defender, attacker):
		order.append([defender, attacker])
	return order


## GBA "true hit": average of two rolls, so high rates hit more often than shown
## and low rates less often.
static func roll_hit(chance: int) -> bool:
	return (randi_range(0, 99) + randi_range(0, 99)) / 2 < chance


## Resolves one strike: {"hit": bool, "crit": bool, "dmg": int}.
static func strike(attacker: Unit, defender: Unit, map: BattleMap) -> Dictionary:
	var result := {"hit": false, "crit": false, "dmg": 0}
	if not roll_hit(hit_chance(attacker, defender, map)):
		return result
	result.hit = true
	result.crit = randi_range(0, 99) < crit_chance(attacker, defender)
	result.dmg = damage(attacker, defender, map) * (CRIT_MULTIPLIER if result.crit else 1)
	return result


## Per-side numbers for the forecast window.
static func side_stats(attacker: Unit, defender: Unit, map: BattleMap) -> Dictionary:
	return {
		"dmg": damage(attacker, defender, map),
		"hit": hit_chance(attacker, defender, map),
		"crit": crit_chance(attacker, defender),
		"double": doubles(attacker, defender),
		"triangle": triangle(attacker, defender),
	}


# --- Magic --------------------------------------------------------------------
# Spells target magic defense instead of DEF, ignore the weapon triangle and never double.

## Current MP, so a caster that has spent MP is easier to hurt with magic.
static func magic_defense(u: Unit) -> int:
	return u.mp


static func spell_damage(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> int:
	return maxi(0, caster.intelligence + spell.power - (magic_defense(target) + map.unit_terrain_def(target)))


static func spell_hit_chance(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> int:
	var hit: int = spell.hit + caster.dexterity * 2 + int(caster.luck * 0.5)
	var avoid: int = attack_speed(target) * 2 + target.luck + map.unit_terrain_avoid(target)
	return clampi(hit - avoid, 0, 100)


static func spell_crit_chance(caster: Unit, target: Unit, spell: Dictionary) -> int:
	return clampi(spell.get("crit", 0) + int(caster.dexterity * 0.5) - target.luck, 0, 100)


## Resolves one spell hit, same shape as strike().
static func spell_strike(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> Dictionary:
	var result := {"hit": false, "crit": false, "dmg": 0}
	if not roll_hit(spell_hit_chance(caster, target, spell, map)):
		return result
	result.hit = true
	result.crit = randi_range(0, 99) < spell_crit_chance(caster, target, spell)
	result.dmg = spell_damage(caster, target, spell, map) * (CRIT_MULTIPLIER if result.crit else 1)
	return result


## Forecast for a single-target spell; the target counters with its weapon (once).
static func spell_forecast(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> Dictionary:
	var counter := can_counter(caster, target)
	var def_side := side_stats(target, caster, map)
	def_side.double = false
	def_side.triangle = 0
	return {
		"atk": {
			"dmg": spell_damage(caster, target, spell, map),
			"hit": spell_hit_chance(caster, target, spell, map),
			"crit": spell_crit_chance(caster, target, spell),
			"double": false,
			"triangle": 0,
		},
		"def": def_side,
		"can_counter": counter,
	}


static func forecast(attacker: Unit, defender: Unit, map: BattleMap) -> Dictionary:
	return {
		"atk": side_stats(attacker, defender, map),
		"def": side_stats(defender, attacker, map),
		"can_counter": can_counter(attacker, defender),
	}
