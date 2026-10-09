class_name Skills
extends RefCounted
## Skills: everything a unit has beyond its stats, from any source. Design and the
## planned effect kinds: docs/skills.md.
##
## Sources (see `sources`): personal (roster "skills"), class (Classes "skills"),
## race (Races "skills"), learned (Unit.learned: level-up tables and scrolls, at most
## LEARNED_CAP), the equipped weapon's "skills" and held non-weapon items' "skills".
##
## Every skill has a "description" and any of these effects:
## stats:      flat bonuses: {"str": 2, "mov": 1} (keys of Experience.STATS, plus "mov";
##             not "hp"/"mp").
## command:    adds a unit menu command: "dance", "inspire".
## turn_start: at the start of its side's phase: {"heal": fraction of max HP, "mp": MP}.
## exp:        multiplier on EXP earned.
## immune:     statuses it ignores ("poison": statuses aren't implemented yet).
## hidden:     never shown to the player (status screen, info panel), on either side.

const LEARNED_CAP := 5

const DATA := {
	# Commands.
	"Dance": {"description": "Dance: refresh an adjacent ally that has already acted.", "command": "dance"},
	"Inspire": {"description": "Inspire: every adjacent ally gets +STR/DEF until your next phase (+1, plus 1 every 5 levels).",
		"command": "inspire"},
	# Racial traits.
	"Adaptable": {"description": "Earns 10% more EXP.", "exp": 1.1},
	"Regeneration": {"description": "Recovers 10% of max HP at the start of each turn.", "turn_start": {"heal": 0.1}},
	"Mana Flow": {"description": "Recovers 1 extra MP at the start of each turn.", "turn_start": {"mp": 1}},
	"Poison Immunity": {"description": "Immune to poison.", "immune": ["poison"]},
	# Stat skills.
	"Celerity": {"description": "+1 MOV.", "stats": {"mov": 1}},
	"Strength +2": {"description": "+2 STR.", "stats": {"str": 2}},
	"Magic +2": {"description": "+2 INT.", "stats": {"int": 2}},
	"Skill +2": {"description": "+2 DEX.", "stats": {"dex": 2}},
	"Speed +2": {"description": "+2 AGI.", "stats": {"agi": 2}},
	"Luck +4": {"description": "+4 LCK.", "stats": {"lck": 4}},
	"Defense +2": {"description": "+2 DEF.", "stats": {"def": 2}},
}


static func get_data(skill: String) -> Dictionary:
	assert(DATA.has(skill), "unknown skill: " + skill)
	return DATA[skill]


static func is_hidden(skill: String) -> bool:
	return get_data(skill).get("hidden", false)


## Every skill `u` has, in a stable order, each once (its first source wins):
## [[skill, source]], where source is "Personal", "Class", "Race", "Learned" or the
## name of the weapon or item that grants it.
static func sources(u: Unit) -> Array:
	var result := []
	var seen := {}
	var add := func(list: Array, source: String) -> void:
		for skill: String in list:
			if not seen.has(skill):
				seen[skill] = true
				result.append([skill, source])
	add.call(u.personal_skills, "Personal")
	add.call(Classes.get_data(u.unit_class).get("skills", []), "Class")
	add.call(Races.get_data(u.race).get("skills", []), "Race")
	add.call(u.learned, "Learned")
	if not u.weapon.is_empty():
		add.call(u.weapon.get("skills", []), u.weapon.name)
	for item in u.items:
		if not Items.is_weapon(item):
			add.call(item.get("skills", []), item.name)
	return result


static func of(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for pair in sources(u):
		result.append(pair[0])
	return result


static func has(u: Unit, skill: String) -> bool:
	return of(u).has(skill)


## The skills shown to the player, with their sources (hidden ones left out).
static func visible_sources(u: Unit) -> Array:
	return sources(u).filter(func(pair: Array) -> bool: return not is_hidden(pair[0]))


## Sum of `stats` bonuses for `key` ("str", "mov"...).
static func stat_bonus(u: Unit, key: String) -> int:
	var total := 0
	for skill in of(u):
		total += get_data(skill).get("stats", {}).get(key, 0)
	return total


## Unit menu commands its skills grant ("dance", "inspire").
static func commands(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for skill in of(u):
		var command: String = get_data(skill).get("command", "")
		if command != "" and not result.has(command):
			result.append(command)
	return result


static func exp_multiplier(u: Unit) -> float:
	var mult := 1.0
	for skill in of(u):
		mult *= get_data(skill).get("exp", 1.0)
	return mult


## Fraction of max HP recovered at the start of its phase.
static func turn_heal(u: Unit) -> float:
	var total := 0.0
	for skill in of(u):
		total += get_data(skill).get("turn_start", {}).get("heal", 0.0)
	return total


## Extra MP recovered at the start of its phase.
static func turn_mp(u: Unit) -> int:
	var total := 0
	for skill in of(u):
		total += get_data(skill).get("turn_start", {}).get("mp", 0)
	return total


static func is_immune(u: Unit, status: String) -> bool:
	return of(u).any(func(skill: String) -> bool: return get_data(skill).get("immune", []).has(status))
