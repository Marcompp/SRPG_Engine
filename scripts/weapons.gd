class_name Weapons
extends RefCounted
## Weapon definitions. Values follow the GBA Fire Emblem iron/steel tier.
## min_rng/max_rng are Manhattan distances the weapon can strike at.

const DATA := {
	"Iron Sword": {"type": "sword", "mt": 5, "hit": 90, "crit": 0, "wt": 5, "min_rng": 1, "max_rng": 1, "uses": 46},
	"Killing Edge": {"type": "sword", "mt": 9, "hit": 75, "crit": 30, "wt": 7, "min_rng": 1, "max_rng": 1, "uses": 20},
	"Knife": {"type": "sword", "mt": 3, "hit": 80, "crit": 0, "wt": 3, "min_rng": 1, "max_rng": 2, "uses": 30},
	"Iron Lance": {"type": "lance", "mt": 7, "hit": 80, "crit": 0, "wt": 8, "min_rng": 1, "max_rng": 1, "uses": 45},
	"Javelin": {"type": "lance", "mt": 6, "hit": 65, "crit": 0, "wt": 11, "min_rng": 1, "max_rng": 2, "uses": 20},
	"Iron Axe": {"type": "axe", "mt": 8, "hit": 75, "crit": 0, "wt": 10, "min_rng": 1, "max_rng": 1, "uses": 45},
	"Steel Axe": {"type": "axe", "mt": 11, "hit": 65, "crit": 0, "wt": 15, "min_rng": 1, "max_rng": 1, "uses": 30},
	"Hatchet": {"type": "axe", "mt": 7, "hit": 60, "crit": 0, "wt": 12, "min_rng": 1, "max_rng": 2, "uses": 20},
	"Iron Bow": {"type": "bow", "mt": 6, "hit": 85, "crit": 0, "wt": 5, "min_rng": 2, "max_rng": 2, "uses": 45},
}


## Returns a fresh copy (so each unit tracks its own uses).
static func make(weapon_name: String) -> Dictionary:
	var w: Dictionary = DATA[weapon_name].duplicate()
	w.name = weapon_name
	return w
