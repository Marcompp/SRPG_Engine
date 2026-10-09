class_name Glossary
extends RefCounted
## Help text for the status screen's detail mode (D on the status screen).
## Weapon, item and spell entries are built from their data, so numbers stay in
## sync; the *_NOTES dictionaries add hand-written flavor where it helps.

const STATS := {
	"hp": "Hit points. The unit falls when they reach 0.",
	"mp": "Magic points. Spent to cast spells. Current MP also reduces spell damage taken (magic defense). Recovers {regen} each turn.",
	"str": "Strength. Adds to the damage of weapon attacks.",
	"int": "Intelligence. Adds to the power of spells, healing included.",
	"dex": "Dexterity. Raises hit rate (x2) and critical rate (/2).",
	"agi": "Agility. Sets attack speed, which gives avoid (x2) and lets the unit attack twice. Weapon weight above STR slows it down.",
	"lck": "Luck. Raises hit (/2) and avoid, and lowers the chance of taking a critical hit.",
	"def": "Defense. Reduces damage from weapon attacks.",
	"mov": "Movement points per turn. How far that goes depends on the movement type and terrain.",
	"lv": "Level. Rises every 100 EXP, up to {level_cap}.",
	"exp": "Experience. Earned by fighting, healing, dancing and inspiring; 100 EXP is a level.",
}

const COMBAT := {
	"atk": "Attack: STR + the equipped weapon's might. Weapon triangle: +1 with advantage, -1 with disadvantage.",
	"hit": "Base hit rate: weapon hit + DEX x2 + LCK / 2. The target's avoid is subtracted.",
	"avo": "Avoid: attack speed x2 + LCK, plus the terrain bonus (none for fliers and spirits).",
	"crit": "Base critical rate: weapon crit + DEX / 2. The target's LCK is subtracted. Crits deal triple damage.",
	"as": "Attack speed: AGI minus any weapon weight above STR. At 4 or more above the foe's, the unit attacks twice.",
	"rng": "Distances the equipped weapon can strike at.",
}

const MOVE_TYPES := {
	"foot": "On foot: the standard costs for every terrain.",
	"heavy": "Heavy armor: slow in hills, mountains and water, but sure-footed on ice. Weak to Hammers.",
	"horse": "Mounted on horseback: fast on open ground, slowed by forests, sand and indoors. Weak to Pikes. Can Rescue allies; can't Shove or be Shoved.",
	"mermaid": "Aquatic: moves freely through water, slowly on land.",
	"ship": "Seafaring: sails water; land is very slow going. Weak to Woodcutters.",
	"flying": "Flying: 1 MOV over any terrain except walls (1.5 indoors), but no terrain bonuses. Weak to bows. Can Rescue allies; can't Shove or be Shoved.",
	"spirit": "Spirit: 1 MOV through anything, walls included, but no terrain bonuses. Takes half damage from weapons that aren't silver.",
}

const WEAPON_NOTES := {
	"Killing Edge": "Its high critical rate makes it deadly.",
	"Knife": "Light enough to throw at range 2.",
	"Javelin": "A spear that can be thrown at range 2.",
	"Hatchet": "An axe that can be thrown at range 2.",
	"Iron Bow": "Can't hit adjacent foes. Wins the weapon triangle when shooting from range.",
	"Silver Bow": "Can't hit adjacent foes. Wins the weapon triangle when shooting from range.",
	"Pike": "A long spear made for unhorsing riders.",
	"Hammer": "Crushes armor.",
	"Woodcutter": "Splits planks and hulls alike.",
	"Quarterstaff": "A caster's staff for close defense.",
}

const SPELL_NOTES := {
	"Heal": "Restores INT + {power} HP to an adjacent ally.",
	"Fire": "Single-target fire magic: INT + {power} damage. The target may counter.",
	"Firestorm": "Hits every enemy in a small cross: INT + {power} damage each. No counters.",
	"Earth Spike": "INT + {power} damage to a unit on the target tile, then raises a mountain there.",
}


static func stat(key: String, unit: Unit) -> String:
	var text: String = STATS[key].format({"regen": Spells.MP_REGEN, "level_cap": Experience.LEVEL_CAP})
	if Experience.STATS.has(key):
		text += " Cap: %d." % unit.stat_cap(key)
	return text


static func unit_class(unit: Unit) -> String:
	var data := Classes.get_data(unit.unit_class)
	var text := "%s. Weapons: %s. Movement: %s." % [unit.unit_class,
		", ".join(data.weapons.map(func(w): return str(w).capitalize())), unit.move_type.capitalize()]
	var promotions := Classes.promotions(unit.unit_class)
	if not promotions.is_empty():
		text += " Promotes to %s." % ", ".join(promotions)
	elif data.get("promoted", false):
		text += " Promoted class."
	return text


static func race(unit: Unit) -> String:
	return "%s: %s" % [unit.race, unit.race_data().description]


static func item(it: Dictionary) -> String:
	if Items.is_weapon(it):
		var base: Dictionary = Weapons.DATA[it.name]
		var rng := str(it.min_rng) if it.min_rng == it.max_rng else "%d-%d" % [it.min_rng, it.max_rng]
		var text := "%s (%s). Mt %d  Hit %d  Crit %d  Wt %d  Rng %s  Uses %d/%d." % [
			it.name, str(it.type).capitalize(), it.mt, it.hit, it.crit, it.wt, rng, it.uses, base.uses]
		var effective: Array = it.get("effective", [])
		if not effective.is_empty():
			text += " Effective (x%d might) against %s." % [Combat.EFFECTIVE_MULTIPLIER,
				", ".join(effective.map(func(t): return str(t).capitalize()))]
		if it.get("silver", false):
			text += " Silver: spirits don't resist it, and the undead are weak to it."
		if WEAPON_NOTES.has(it.name):
			text += " " + WEAPON_NOTES[it.name]
		for skill: String in it.get("skills", []):
			text += " Equipped: %s (%s)" % [skill, Skills.get_data(skill).description]
		return text
	match it.get("kind", ""):
		"heal":
			return "%s: restores %d HP to the user and ends its turn. Uses %d." % [it.name, it.heal, it.uses]
		"mp":
			return "%s: restores %d MP to the user and ends its turn. Uses %d." % [it.name, it.mp, it.uses]
		"scroll":
			return "%s: teaches %s (%s) for good. Ends the user's turn." % [it.name, it.skill,
				Skills.get_data(it.skill).description]
	var text: String = it.name + "."
	for skill: String in it.get("skills", []):
		text += " Held: %s (%s)" % [skill, Skills.get_data(skill).description]
	if it.has("uses"):
		text += " Uses %d." % it.uses
	return text


static func spell(spell_name: String) -> String:
	var s := Spells.get_spell(spell_name)
	var rng := str(s.max_rng) if s.min_rng == s.max_rng else "%d-%d" % [s.min_rng, s.max_rng]
	var note: String = SPELL_NOTES.get(spell_name, "").format({"power": s.get("power", 0)})
	return "%s. %s Cost %d MP, range %s." % [spell_name, note, s.mp, rng]
