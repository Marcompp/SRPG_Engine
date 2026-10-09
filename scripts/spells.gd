class_name Spells
extends RefCounted
## Spell definitions. Spells cost MP, are cast as an action on the caster's own
## phase, and never trigger as counters.

## MP regained by every unit at the start of its own phase. Kept low because
## current MP is also magic defense: spent MP should stay spent for a while.
const MP_REGEN := 1

## target: "ally"  = heal another unit on the caster's team.
##         "enemy" = single-target damage; the target may counter.
##         "area"  = damage every enemy within `radius` of a chosen cell; no counters.
## element: "fire", "ice", "water", "earth", "lightning", "light" or "dark"; some
##          tags are weak to or resist elements (Combat.TAG_TRAITS).
## terraform: terrain key the target cell becomes after the cast (area spells only).
##            Such spells may target empty cells, but only ones whose terrain can change.
const DATA := {
	"Heal": {"mp": 4, "target": "ally", "min_rng": 1, "max_rng": 1, "power": 10, "exp": 11},
	"Fire": {"mp": 3, "target": "enemy", "element": "fire", "min_rng": 1, "max_rng": 2, "power": 5, "hit": 90},
	"Firestorm": {"mp": 8, "target": "area", "element": "fire", "min_rng": 1, "max_rng": 3, "radius": 1, "power": 3, "hit": 80},
	"Earth Spike": {"mp": 5, "target": "area", "element": "earth", "min_rng": 1, "max_rng": 2, "radius": 0, "power": 6, "hit": 85,
		"terraform": "M"},
}

## Terrain that terraforming spells can transform.
const TERRAFORMABLE: Array[String] = [".", "=", "F", "S", "D", "*"]


static func get_spell(spell_name: String) -> Dictionary:
	return DATA[spell_name]


static func is_support(spell_name: String) -> bool:
	return get_spell(spell_name).target == "ally"


## HP restored by a healing spell: INT + power, capped by the target's missing HP.
static func heal_amount(caster: Unit, spell: Dictionary, target: Unit) -> int:
	return mini(caster.combat_int() + spell.power, target.max_hp - target.hp)


static func can_afford(caster: Unit, spell_name: String) -> bool:
	return caster.mp >= get_spell(spell_name).mp


static func reaches(spell_name: String, dist: int) -> bool:
	var s := get_spell(spell_name)
	return dist >= s.min_rng and dist <= s.max_rng


## Furthest distance from the caster a spell can affect (cast range + area radius).
static func reach_ranges(spell_name: String) -> Vector2i:
	var s := get_spell(spell_name)
	var radius: int = s.get("radius", 0)
	return Vector2i(maxi(1, s.min_rng - radius), s.max_rng + radius)


## Valid unit targets for a heal or single-target spell from the caster's current cell.
static func targets_for(caster: Unit, spell_name: String, units: Array[Unit]) -> Array[Unit]:
	var result: Array[Unit] = []
	var spell := get_spell(spell_name)
	for u in units:
		if u == caster:
			continue
		match spell.target:
			"ally":
				if u.team != caster.team or u.hp >= u.max_hp:
					continue
			"enemy":
				if u.team == caster.team:
					continue
			_:
				continue
		if reaches(spell_name, BattleMap.distance(caster.cell, u.cell)):
			result.append(u)
	return result


## Cells hit by an area spell centered on `center`.
static func area_cells(spell_name: String, center: Vector2i, map: BattleMap) -> Array[Vector2i]:
	var radius: int = get_spell(spell_name).get("radius", 0)
	var result: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if absi(dx) + absi(dy) <= radius and map.in_bounds(c):
				result.append(c)
	return result


## Enemies of the caster inside an area spell's blast.
static func area_targets(caster: Unit, spell_name: String, center: Vector2i, units: Array[Unit], map: BattleMap) -> Array[Unit]:
	var cells := area_cells(spell_name, center, map)
	var result: Array[Unit] = []
	for u in units:
		if u.team != caster.team and cells.has(u.cell):
			result.append(u)
	return result


## Cells an area spell can be centered on from the caster's current cell.
## Terraforming spells skip cells whose terrain can't change or that hold an ally.
static func area_centers(caster: Unit, spell_name: String, map: BattleMap, units: Array[Unit]) -> Array[Vector2i]:
	var s := get_spell(spell_name)
	var result: Array[Vector2i] = []
	for dx in range(-s.max_rng, s.max_rng + 1):
		for dy in range(-s.max_rng, s.max_rng + 1):
			var c := caster.cell + Vector2i(dx, dy)
			if not map.in_bounds(c) or not reaches(spell_name, absi(dx) + absi(dy)):
				continue
			if s.has("terraform"):
				if not TERRAFORMABLE.has(map.terrain_key(c)):
					continue
				if units.any(func(u: Unit) -> bool: return u.cell == c and u.team == caster.team):
					continue
			result.append(c)
	return result


## Whether an area spell may be cast at `center`: it must hit an enemy,
## unless it terraforms (then any valid center will do).
static func can_cast_at(caster: Unit, spell_name: String, center: Vector2i, units: Array[Unit], map: BattleMap) -> bool:
	if get_spell(spell_name).has("terraform"):
		return area_centers(caster, spell_name, map, units).has(center)
	return not area_targets(caster, spell_name, center, units, map).is_empty()


## Whether the spell has anything worth casting at from the caster's current cell.
static func has_targets(caster: Unit, spell_name: String, units: Array[Unit], map: BattleMap) -> bool:
	if get_spell(spell_name).target == "area":
		for c in area_centers(caster, spell_name, map, units):
			if can_cast_at(caster, spell_name, c, units, map):
				return true
		return false
	return not targets_for(caster, spell_name, units).is_empty()
