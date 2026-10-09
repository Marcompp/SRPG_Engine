class_name Combat
extends RefCounted
## Combat math, modeled on the GBA Fire Emblem formulas.
##
## Skills (see Skills) change the numbers ("battle" modifiers), the strike order
## ("rules") and single strikes ("proc"). Their conditions can depend on who started
## the fight, so the matchup functions take an optional `initiator`; null means the
## first unit (the striker) started it, which is right for an attack being planned.

const DOUBLE_THRESHOLD := 4
const CRIT_MULTIPLIER := 3
## Effectiveness levels (see docs/races.md). Effective: weapon might x3 against a
## tag the weapon is effective against (bows vs fliers, Pike vs horses...), as in
## GBA Fire Emblem. Weak: might (or spell power) x2 against a source the target's
## tags are weak to (TAG_TRAITS). Resistant: half damage. Levels don't stack: the
## strongest one that applies counts.
const EFFECTIVE_MULTIPLIER := 3
const WEAK_MULTIPLIER := 2
## Weaknesses and resistances by tag (see Unit.tags), against damage sources:
## weapon types, "silver" and spell elements. Spirits also resist every weapon
## that isn't silver.
const TAG_TRAITS := {
	"aquatic": {"weak": ["spear", "lightning"], "resist": ["fire", "water"]},
	"reptile": {"weak": ["ice"], "resist": ["fire"]},
	"wooden": {"weak": ["axe", "fire", "ice"], "resist": ["water", "earth"]},
	"undead": {"weak": ["silver", "fire", "light"], "resist": ["dark"]},
}
const TRIANGLE_DMG := 1
const TRIANGLE_HIT := 15
## Key beats value. Bows and staves sit outside the triangle.
const TRIANGLE := {"sword": "axe", "axe": "spear", "spear": "sword"}


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
	return u.combat_agi() - maxi(0, u.weapon.get("wt", 0) - u.combat_str())


# Unit-only parts of the formulas (equipped weapon, no target or terrain). These are
# what the stats screen shows; the matchup functions below build on them.

static func base_attack(u: Unit) -> int:
	return u.combat_str() + u.weapon.mt


static func base_hit(u: Unit) -> int:
	return u.weapon.hit + u.combat_dex() * 2 + int(u.combat_lck() * 0.5)


static func base_avoid(u: Unit) -> int:
	return attack_speed(u) * 2 + u.combat_lck()


static func base_crit(u: Unit) -> int:
	return u.weapon.crit + int(u.combat_dex() * 0.5)


## Skill "battle" modifiers for `u` fighting `foe` in a fight `initiator` started.
static func mods(u: Unit, foe: Unit, map: BattleMap, initiator: Unit) -> Dictionary:
	return Skills.battle_mods(u, foe, map, initiator == u)


## Attack speed in a fight, with skill modifiers.
static func speed(u: Unit, foe: Unit, map: BattleMap, initiator: Unit) -> int:
	return attack_speed(u) + mods(u, foe, map, initiator).as


## Avoid in a fight: speed, luck, terrain and skill modifiers.
static func avoid(u: Unit, foe: Unit, map: BattleMap, initiator: Unit) -> int:
	return speed(u, foe, map, initiator) * 2 + u.combat_lck() + map.unit_terrain_avoid(u) \
		+ mods(u, foe, map, initiator).avo


## `pierce`: fraction of the defender's DEF ignored (Luna-style procs).
static func damage(attacker: Unit, defender: Unit, map: BattleMap, initiator: Unit = null, pierce := 0.0) -> int:
	if attacker.weapon.is_empty():
		return 0
	var init := initiator if initiator else attacker
	var atk: int = base_attack(attacker) + triangle(attacker, defender) * TRIANGLE_DMG
	atk += attacker.weapon.mt * (multiplier(attacker.weapon, defender) - 1)
	atk += mods(attacker, defender, map, init).atk
	var def: int = defender.combat_def() + map.unit_terrain_def(defender) + mods(defender, attacker, map, init).def
	def -= floori(maxi(def, 0) * pierce)
	var dmg := maxi(0, atk - def)
	if resists(defender, attacker.weapon):
		dmg = floori(dmg / 2.0)
	return dmg


## Damage sources a weapon or spell counts as, for weaknesses and resistances.
static func sources(attack: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if Items.is_weapon(attack):
		result.append(attack.type)
		if attack.get("silver", false):
			result.append("silver")
	if attack.has("element"):
		result.append(attack.element)
	return result


## Whether `weapon` is effective against `target` (its might is tripled).
static func is_effective(weapon: Dictionary, target: Unit) -> bool:
	return weapon.get("effective", []).any(func(t): return target.tags.has(t))


## Whether `target`'s tags are weak to the weapon or spell `attack`.
static func is_weak(target: Unit, attack: Dictionary) -> bool:
	return _trait_matches(target, attack, "weak")


## Might (or spell power) multiplier: x3 effective, x2 weak, else x1.
static func multiplier(attack: Dictionary, target: Unit) -> int:
	if is_effective(attack, target):
		return EFFECTIVE_MULTIPLIER
	if is_weak(target, attack):
		return WEAK_MULTIPLIER
	return 1


## Whether `target` takes half damage from `attack`. Spirits resist weapons that
## aren't silver. Being effective or weak beats resisting (levels don't stack).
static func resists(target: Unit, attack: Dictionary) -> bool:
	if multiplier(attack, target) > 1:
		return false
	if target.tags.has("spirit") and Items.is_weapon(attack) and not attack.get("silver", false):
		return true
	return _trait_matches(target, attack, "resist")


static func _trait_matches(target: Unit, attack: Dictionary, kind: String) -> bool:
	var from := sources(attack)
	for tag in target.tags:
		for source: String in TAG_TRAITS.get(tag, {}).get(kind, []):
			if from.has(source):
				return true
	return false


static func hit_chance(attacker: Unit, defender: Unit, map: BattleMap, initiator: Unit = null) -> int:
	if attacker.weapon.is_empty():
		return 0
	var init := initiator if initiator else attacker
	var hit: int = base_hit(attacker) + triangle(attacker, defender) * TRIANGLE_HIT \
		+ mods(attacker, defender, map, init).hit
	return clampi(hit - avoid(defender, attacker, map, init), 0, 100)


static func crit_chance(attacker: Unit, defender: Unit, map: BattleMap = null, initiator: Unit = null) -> int:
	if attacker.weapon.is_empty():
		return 0
	var init := initiator if initiator else attacker
	var crit: int = base_crit(attacker) + mods(attacker, defender, map, init).crit
	var dodge: int = defender.combat_lck() + mods(defender, attacker, map, init).crit_avo
	return clampi(crit - dodge, 0, 100)


static func doubles(a: Unit, b: Unit, map: BattleMap = null, initiator: Unit = null) -> bool:
	var init := initiator if initiator else a
	return speed(a, b, map, init) >= speed(b, a, map, init) + DOUBLE_THRESHOLD


## Whether `defender` strikes back: in its weapon's range (any range with
## "counter_any"), unless the attacker has "no_counter".
static func can_counter(attacker: Unit, defender: Unit, map: BattleMap = null) -> bool:
	if defender.weapon.is_empty() or Skills.rules(attacker, defender, map, true).has("no_counter"):
		return false
	if Skills.rules(defender, attacker, map, false).has("counter_any"):
		return true
	return defender.can_attack_at(BattleMap.distance(attacker.cell, defender.cell))


## How many times each side strikes: Vector2i(attacker, defender). Doubling (or
## "quick_riposte" for the defender), unless either side has "wary_fighter".
static func strike_counts(attacker: Unit, defender: Unit, map: BattleMap = null) -> Vector2i:
	var counter := can_counter(attacker, defender, map)
	var counts := Vector2i(1, 1 if counter else 0)
	var att_rules := Skills.rules(attacker, defender, map, true)
	var def_rules := Skills.rules(defender, attacker, map, false)
	if att_rules.has("wary_fighter") or def_rules.has("wary_fighter"):
		return counts
	if doubles(attacker, defender, map, attacker):
		counts.x = 2
	if counter and (doubles(defender, attacker, map, attacker) or def_rules.has("quick_riposte")):
		counts.y = 2
	return counts


## List of [striker, target] pairs in the order they happen: attacker, defender,
## then follow-ups. "vantage" lets the defender strike first; "desperation" moves
## the attacker's follow-up right after its first strike.
static func strike_order(attacker: Unit, defender: Unit, map: BattleMap = null) -> Array:
	var counts := strike_counts(attacker, defender, map)
	var a := [attacker, defender]
	var d := [defender, attacker]
	var order := []
	var left_a := counts.x
	var left_d := counts.y
	if left_d > 0 and Skills.rules(defender, attacker, map, false).has("vantage"):
		order.append(d)
		left_d -= 1
	order.append(a)
	left_a -= 1
	if left_a > 0 and Skills.rules(attacker, defender, map, true).has("desperation"):
		order.append(a)
		left_a -= 1
	if left_d > 0:
		order.append(d)
		left_d -= 1
	if left_a > 0:
		order.append(a)
	if left_d > 0:
		order.append(d)
	return order


## GBA "true hit": average of two rolls, so high rates hit more often than shown
## and low rates less often.
static func roll_hit(chance: int) -> bool:
	return (randi_range(0, 99) + randi_range(0, 99)) / 2 < chance


## Resolves one strike: {"hit", "crit", "dmg", "heal" (for the striker, from
## drain procs), "procs": [[unit, skill]] that fired}. One attack proc (striker)
## and one defense proc (target) at most.
static func strike(attacker: Unit, defender: Unit, map: BattleMap, initiator: Unit = null) -> Dictionary:
	var init := initiator if initiator else attacker
	var result := {"hit": false, "crit": false, "dmg": 0, "heal": 0, "procs": []}
	if not roll_hit(hit_chance(attacker, defender, map, init)):
		return result
	result.hit = true
	result.crit = randi_range(0, 99) < crit_chance(attacker, defender, map, init)
	var effect := {}
	for skill in Skills.procs(attacker, defender, map, init == attacker, "attack"):
		if Skills.roll_proc(attacker, skill):
			effect = Skills.get_data(skill).proc
			result.procs.append([attacker, skill])
			break
	var kind: String = effect.get("effect", "")
	var dmg := damage(attacker, defender, map, init, effect.value if kind == "pierce" else 0.0)
	if kind == "damage_bonus":
		dmg += effect.value
	dmg *= CRIT_MULTIPLIER if result.crit else 1
	if kind == "lethal":
		dmg = maxi(dmg, defender.hp)
	for skill in Skills.procs(defender, attacker, map, init == defender, "defend"):
		var guard: Dictionary = Skills.get_data(skill).proc
		var applies: bool = (guard.effect == "reduce" and dmg > 0) \
			or (guard.effect == "survive" and dmg >= defender.hp and defender.hp > 1)
		if applies and Skills.roll_proc(defender, skill):
			if guard.effect == "reduce":
				dmg -= floori(dmg * guard.value)
			else:
				dmg = defender.hp - 1
			result.procs.append([defender, skill])
			break
	result.dmg = dmg
	if kind == "drain":
		result.heal = floori(mini(dmg, defender.hp) * effect.value)
	return result


## Per-side numbers for the forecast window. `initiator`: who started the fight
## (null: `attacker`).
static func side_stats(attacker: Unit, defender: Unit, map: BattleMap, initiator: Unit = null) -> Dictionary:
	var init := initiator if initiator else attacker
	return {
		"dmg": damage(attacker, defender, map, init),
		"hit": hit_chance(attacker, defender, map, init),
		"crit": crit_chance(attacker, defender, map, init),
		"double": doubles(attacker, defender, map, init),
		"triangle": triangle(attacker, defender),
		"multiplier": 1 if attacker.weapon.is_empty() else multiplier(attacker.weapon, defender),
		"resisted": not attacker.weapon.is_empty() and resists(defender, attacker.weapon),
	}


# --- Magic --------------------------------------------------------------------
# Spells target magic defense instead of DEF, ignore the weapon triangle and never double.

## Current MP, so a caster that has spent MP is easier to hurt with magic.
static func magic_defense(u: Unit) -> int:
	return u.mp


static func spell_damage(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> int:
	var power: int = spell.power * multiplier(spell, target)
	var atk: int = caster.combat_int() + power + mods(caster, target, map, caster).atk
	var res: int = magic_defense(target) + map.unit_terrain_def(target) + mods(target, caster, map, caster).res
	var dmg := maxi(0, atk - res)
	if resists(target, spell):
		dmg = floori(dmg / 2.0)
	return dmg


static func spell_hit_chance(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> int:
	var hit: int = spell.hit + caster.combat_dex() * 2 + int(caster.combat_lck() * 0.5) 		+ mods(caster, target, map, caster).hit
	return clampi(hit - avoid(target, caster, map, caster), 0, 100)


static func spell_crit_chance(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap = null) -> int:
	var crit: int = spell.get("crit", 0) + int(caster.combat_dex() * 0.5) + mods(caster, target, map, caster).crit
	return clampi(crit - target.combat_lck() - mods(target, caster, map, caster).crit_avo, 0, 100)


## Resolves one spell hit, same shape as strike().
static func spell_strike(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> Dictionary:
	var result := {"hit": false, "crit": false, "dmg": 0, "heal": 0, "procs": []}
	if not roll_hit(spell_hit_chance(caster, target, spell, map)):
		return result
	result.hit = true
	result.crit = randi_range(0, 99) < spell_crit_chance(caster, target, spell, map)
	result.dmg = spell_damage(caster, target, spell, map) * (CRIT_MULTIPLIER if result.crit else 1)
	return result


## Forecast for a single-target spell; the target counters with its weapon (once).
static func spell_forecast(caster: Unit, target: Unit, spell: Dictionary, map: BattleMap) -> Dictionary:
	var counter := can_counter(caster, target, map)
	var def_side := side_stats(target, caster, map, caster)
	def_side.double = false
	def_side.triangle = 0
	return {
		"atk": {
			"dmg": spell_damage(caster, target, spell, map),
			"hit": spell_hit_chance(caster, target, spell, map),
			"crit": spell_crit_chance(caster, target, spell, map),
			"double": false,
			"triangle": 0,
			"multiplier": multiplier(spell, target),
			"resisted": resists(target, spell),
		},
		"def": def_side,
		"can_counter": counter,
	}


static func forecast(attacker: Unit, defender: Unit, map: BattleMap) -> Dictionary:
	var counts := strike_counts(attacker, defender, map)
	var atk := side_stats(attacker, defender, map, attacker)
	var def := side_stats(defender, attacker, map, attacker)
	atk.double = counts.x > 1
	def.double = counts.y > 1
	return {"atk": atk, "def": def, "can_counter": counts.y > 0}
