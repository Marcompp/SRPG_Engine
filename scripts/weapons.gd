class_name Weapons
extends RefCounted
## Weapon definitions. Values follow the GBA Fire Emblem iron/steel/silver tiers.
## min_rng/max_rng are Manhattan distances the weapon can strike at.
## effective: move types this weapon's might is tripled against (Combat.EFFECTIVE_MULTIPLIER).
## silver:    spirits don't resist it (they halve damage from other weapons).

const DATA := {
	"Iron Sword": {"type": "sword", "mt": 5, "hit": 90, "crit": 0, "wt": 5, "min_rng": 1, "max_rng": 1, "uses": 46},
	"Killing Edge": {"type": "sword", "mt": 9, "hit": 75, "crit": 30, "wt": 7, "min_rng": 1, "max_rng": 1, "uses": 20},
	"Knife": {"type": "sword", "mt": 3, "hit": 80, "crit": 0, "wt": 3, "min_rng": 1, "max_rng": 2, "uses": 30},
	"Iron Spear": {"type": "spear", "mt": 7, "hit": 80, "crit": 0, "wt": 8, "min_rng": 1, "max_rng": 1, "uses": 45},
	"Javelin": {"type": "spear", "mt": 6, "hit": 65, "crit": 0, "wt": 11, "min_rng": 1, "max_rng": 2, "uses": 20},
	"Iron Axe": {"type": "axe", "mt": 8, "hit": 75, "crit": 0, "wt": 10, "min_rng": 1, "max_rng": 1, "uses": 45},
	"Steel Axe": {"type": "axe", "mt": 11, "hit": 65, "crit": 0, "wt": 15, "min_rng": 1, "max_rng": 1, "uses": 30},
	"Hatchet": {"type": "axe", "mt": 7, "hit": 60, "crit": 0, "wt": 12, "min_rng": 1, "max_rng": 2, "uses": 20},
	"Iron Bow": {"type": "bow", "mt": 6, "hit": 85, "crit": 0, "wt": 5, "min_rng": 2, "max_rng": 2, "uses": 45,
		"effective": ["flying"]},
	# Effective weapons
	"Pike": {"type": "spear", "mt": 7, "hit": 70, "crit": 0, "wt": 13, "min_rng": 1, "max_rng": 1, "uses": 16,
		"effective": ["horse"]},
	"Hammer": {"type": "axe", "mt": 10, "hit": 55, "crit": 0, "wt": 15, "min_rng": 1, "max_rng": 1, "uses": 20,
		"effective": ["heavy"]},
	"Woodcutter": {"type": "axe", "mt": 9, "hit": 65, "crit": 0, "wt": 13, "min_rng": 1, "max_rng": 1, "uses": 20,
		"effective": ["ship"]},
	# Silver tier: strong, and the only physical weapons spirits don't resist.
	"Silver Sword": {"type": "sword", "mt": 13, "hit": 80, "crit": 0, "wt": 8, "min_rng": 1, "max_rng": 1, "uses": 20,
		"silver": true, "effective": ["spirit"]},
	"Silver Spear": {"type": "spear", "mt": 14, "hit": 75, "crit": 0, "wt": 10, "min_rng": 1, "max_rng": 1, "uses": 20,
		"silver": true, "effective": ["spirit"]},
	"Silver Axe": {"type": "axe", "mt": 15, "hit": 70, "crit": 0, "wt": 12, "min_rng": 1, "max_rng": 1, "uses": 20,
		"silver": true, "effective": ["spirit"]},
	"Silver Bow": {"type": "bow", "mt": 13, "hit": 75, "crit": 0, "wt": 6, "min_rng": 2, "max_rng": 2, "uses": 20,
		"silver": true, "effective": ["flying", "spirit"]},
	"Quarterstaff": {"type": "staff", "mt": 4, "hit": 85, "crit": 0, "wt": 4, "min_rng": 1, "max_rng": 1, "uses": 40},
}


## Returns a fresh copy (so each unit tracks its own uses).
static func make(weapon_name: String) -> Dictionary:
	var w: Dictionary = DATA[weapon_name].duplicate()
	w.name = weapon_name
	return w
