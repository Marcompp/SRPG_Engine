class_name Weapons
extends RefCounted
## Weapon definitions. Values follow the GBA Fire Emblem iron/steel/silver tiers.
## min_rng/max_rng are Manhattan distances the weapon can strike at.
## effective: move types this weapon's might is tripled against (Combat.EFFECTIVE_MULTIPLIER).
## silver:    spirits don't resist it (they halve damage from other weapons).
## inflict:   {"status", "chance"}: each hit that lands gives the target that status
##            (see Statuses) with `chance`% odds.

static var DATA := GameData.entries("weapons")


## Returns a fresh copy (so each unit tracks its own uses).
## Broken weapons (0 uses left) stay in the inventory and keep working, weakened
## (as in Three Houses): half Mt, -BROKEN_HIT_PENALTY Hit, no Crit. Repair restores them.
const BROKEN_HIT_PENALTY := 30


static func is_broken(w: Dictionary) -> bool:
	return w.has("uses") and w.uses <= 0


static func max_uses(w: Dictionary) -> int:
	return DATA[w.name].uses if DATA.has(w.name) else w.get("uses", 0)


## Mt, Hit and Crit as they work in combat (broken weapons are weakened).
static func mt(w: Dictionary) -> int:
	return floori(w.mt / 2.0) if is_broken(w) else w.mt


static func hit(w: Dictionary) -> int:
	return w.hit - BROKEN_HIT_PENALTY if is_broken(w) else w.hit


static func crit(w: Dictionary) -> int:
	return 0 if is_broken(w) else w.crit


static func make(weapon_name: String) -> Dictionary:
	var w: Dictionary = DATA[weapon_name].duplicate()
	w.name = weapon_name
	return w
