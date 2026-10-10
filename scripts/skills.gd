class_name Skills
extends RefCounted
## Skills: everything a unit has beyond its stats, from any source. Design and the
## planned effect kinds: docs/skills.md.
##
## Sources (see `sources`): personal (roster "skills"), class (Classes "skills"; a
## mounted unit also keeps its foot class's, minus terrain movement), its mount's,
## race (Races "skills"), learned (Unit.learned: level-up tables and scrolls, at most
## LEARNED_CAP), the equipped weapon's "skills" and held non-weapon items' "skills".
##
## Every skill has a "description" and any of these effects:
## stats:      flat bonuses: {"str": 2, "mov": 1} (keys of Experience.STATS, plus "mov";
##             "hp"/"mp" raise max HP/MP).
## weight_relief: its weapons count as this much lighter (see Combat.attack_speed).
## command:    adds a unit menu command: "dance", "inspire", "steal".
## turn_start: at the start of its side's phase: {"heal": fraction of max HP, "mp": MP,
##             "heal_allies": fraction of max HP for adjacent allies}.
## terrain_costs: {terrain key: MOV}: it pays this instead when it's cheaper than its
##             move type's cost (Swimming, Climbing, Forester).
## range:      max range bonus by weapon type, or "spell" for every spell: {"bow": 1}.
## abilities:  racial attacks it can use (Spells entries with "ability"): each gets
##             its own unit menu entry.
## exp:        multiplier on EXP earned.
## immune:     statuses it ignores ("poison": statuses aren't implemented yet).
## battle:     combat modifiers while fighting: {"atk", "def", "res" (magic defense),
##             "hit", "avo", "crit", "crit_avo", "as"} (see BATTLE_KEYS). Shown in the
##             forecast.
## rules:      change how a fight goes (see RULES): "vantage" (strike first when
##             attacked), "desperation" (follow-up right after the first strike),
##             "quick_riposte" (always double when attacked, if able to counter),
##             "wary_fighter" (nobody doubles in its fights), "no_counter" (foes can't
##             counter its attacks), "counter_any" (counters at any range when armed).
## proc:       rolls on each strike: {"on": "attack"/"defend", "rate", "effect",
##             "value"}. Rate: a number, or a stat of the owner ("dex", "lck", "lv",
##             also "dex/2" or "lck*2"). Effects (see PROC_EFFECTS): "pierce" (ignore
##             `value` of the foe's DEF), "drain" (heal `value` of damage dealt),
##             "damage_bonus" (+value damage), "lethal" (kill), "reduce" (cut damage
##             taken by `value`), "survive" (a lethal hit leaves 1 HP). At most one
##             attack and one defense proc per strike: the first that rolls, in
##             skill order. Weapon strikes only. Not in the forecast; the AI ignores them.
## after_combat: once a fight it took part in is over, if it's still standing:
##             {"effect", "value"}: "heal" (`value` of max HP), "refresh" (act again,
##             once per turn), "damage_foe" (the foe loses `value` of its max HP, never
##             below 1), "damage_near_foe" (so do the foe's allies within 2 of it).
## map:        movement rules: "pass" (move through enemies), "pathfinder" (every
##             passable tile costs 1 MOV), "canto" (move again with the MOV left after
##             acting; player units), "footwork" (Canto, but only after Dancing).
## aura:       {"radius", "affects": "allies"/"enemies", "battle": {...}}: battle
##             modifiers for other units within `radius` tiles (not the owner).
## growths:    growth rate bonuses on level-up: {"all": 10, "str": 5}.
## if:         conditions for battle, rules, proc and after_combat effects (all must
##             hold; see CONDITIONS): "initiating"/"defending": true, "phase":
##             "player"/"enemy", "hp_below"/"hp_above": fraction of max HP
##             (inclusive), "range": [min, max], "weapon_type"/"foe_weapon_type"/
##             "foe_tag"/"terrain": a value or a list of them, "adjacent_ally"/
##             "no_adjacent_ally": true, "killed": true (after_combat: the foe died).
## hidden:     never shown to the player (status screen, info panel, proc popups),
##             on either side.

const LEARNED_CAP := 5
const BATTLE_KEYS: Array[String] = ["atk", "def", "res", "hit", "avo", "crit", "crit_avo", "as"]
const RULES: Array[String] = ["vantage", "desperation", "quick_riposte", "wary_fighter", "no_counter",
	"counter_any"]
const PROC_EFFECTS: Array[String] = ["pierce", "drain", "damage_bonus", "lethal", "reduce", "survive"]
const CONDITIONS: Array[String] = ["initiating", "defending", "phase", "hp_below", "hp_above", "range",
	"weapon_type", "foe_weapon_type", "foe_tag", "terrain", "adjacent_ally", "no_adjacent_ally", "killed"]
const EFFECT_KEYS: Array[String] = ["description", "stats", "command", "turn_start", "exp", "immune", "battle",
	"rules", "proc", "after_combat", "map", "aura", "growths", "terrain_costs", "range", "weight_relief", "abilities", "if",
	"hidden"]
const AFTER_EFFECTS: Array[String] = ["heal", "refresh", "damage_foe", "damage_near_foe"]
const MAP_RULES: Array[String] = ["pass", "pathfinder", "canto", "footwork"]
## Skills that make terrain cheaper (see terrain_costs): innate to scouts, climbers and
## swimmers, and what amphibious races get in foot classes.
const TERRAIN_SKILLS: Array[String] = ["Forester", "Climbing", "Swimming"]

## The units on the map, for auras and adjacency conditions (set by Battle; unset,
## e.g. in unit-only checks, they're ignored).
static var field: Callable

const DATA := {
	# Commands.
	"Dance": {"description": "Dance: refresh an adjacent ally that has already acted.", "command": "dance"},
	"Inspire": {"description": "Inspire: every adjacent ally gets +STR/DEF until your next phase (+1, plus 1 every 5 levels).",
		"command": "inspire"},
	"Steal": {"description": "Steal: take an item (not a weapon) from an adjacent foe with lower AGI.", "command": "steal"},
	"Lockpick": {"description": "Opens chests and doors without a key."},
	# Terrain movement.
	"Forester": {"description": "Moves through forests (1.5 MOV) and thickets (6) more easily.",
		"terrain_costs": {"F": 1.5, "#": 6}},
	"Climbing": {"description": "Crosses hills (2 MOV) and mountains (4) more easily.", "terrain_costs": {"h": 2, "M": 4}},
	"Swimming": {"description": "Wades rivers, lakes and the sea (2 MOV) and can get past waterfalls (6).",
		"terrain_costs": {"~": 2, "L": 2, "W": 2, "v": 6}},
	"Sea Legs": {"description": "+15 Hit on water.", "battle": {"hit": 15}, "if": {"terrain": ["~", "L", "W", "v"]}},
	"Ambush": {"description": "+15 Hit in forests and thickets.", "battle": {"hit": 15}, "if": {"terrain": ["F", "#"]}},
	"Highlander": {"description": "+15 Hit on hills and mountains.", "battle": {"hit": 15}, "if": {"terrain": ["h", "M"]}},
	"Open Ground": {"description": "+10 Avo on open terrain (plains, paths, sand, snow, floors, bridges).",
		"battle": {"avo": 10}, "if": {"terrain": [".", "=", "S", "*", "_", "c", "B"]}},
	"Footwork": {"description": "Can move again after Dancing, with the MOV it has left.", "map": ["footwork"]},
	# Mount skills.
	"Loyal": {"description": "Mount skill: takes a fatal blow once. The mount falls; the rider stays on the map on foot, at 1 HP."},
	"Prayer": {"description": "Adjacent allies recover 10% of max HP at the start of each turn.",
		"turn_start": {"heal_allies": 0.1}},
	# Racial attacks (see Spells "ability").
	"Fire Breath": {"description": "Fire Breath: a fire attack at range 1-2 (STR + 6 against DEF, 80 Hit). No MP.",
		"abilities": ["Fire Breath"]},
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
	"Skill +4": {"description": "+4 DEX.", "stats": {"dex": 4}},
	"Max HP +5": {"description": "+5 max HP.", "stats": {"hp": 5}},
	"Max MP +5": {"description": "+5 max MP.", "stats": {"mp": 5}},
	"Brawn": {"description": "Weapons weigh 5 less for it.", "weight_relief": 5},
	"Speed +2": {"description": "+2 AGI.", "stats": {"agi": 2}},
	"Luck +4": {"description": "+4 LCK.", "stats": {"lck": 4}},
	"Defense +2": {"description": "+2 DEF.", "stats": {"def": 2}},
	# Combat modifiers.
	"Wrath": {"description": "+30 Crit at or below half HP.", "battle": {"crit": 30}, "if": {"hp_below": 0.5}},
	"Crit +20": {"description": "+20 Crit.", "battle": {"crit": 20}},
	"Impale": {"description": "+25 Crit against mounted foes (horses and fliers).", "battle": {"crit": 25},
		"if": {"foe_tag": ["horse", "flying"]}},
	"Evasion": {"description": "+10 Avo.", "battle": {"avo": 10}},
	"Warding": {"description": "+5 magic defense.", "battle": {"res": 5}},
	"Bow Range +1": {"description": "+1 max range with bows.", "range": {"bow": 1}},
	"Spell Range +1": {"description": "+1 max range for spells.", "range": {"spell": 1}},
	"Death Blow": {"description": "+6 Atk when initiating combat.", "battle": {"atk": 6}, "if": {"initiating": true}},
	"Darting Blow": {"description": "+5 AS when initiating combat.", "battle": {"as": 5}, "if": {"initiating": true}},
	"Armored Blow": {"description": "+6 DEF when initiating combat.", "battle": {"def": 6}, "if": {"initiating": true}},
	"Steady Stance": {"description": "+4 DEF when attacked.", "battle": {"def": 4}, "if": {"defending": true}},
	"Swordbreaker": {"description": "+50 Hit and Avo against swords.", "battle": {"hit": 50, "avo": 50},
		"if": {"foe_weapon_type": "sword"}},
	"Axebreaker": {"description": "+50 Hit and Avo against axes.", "battle": {"hit": 50, "avo": 50},
		"if": {"foe_weapon_type": "axe"}},
	"Spearbreaker": {"description": "+50 Hit and Avo against spears.", "battle": {"hit": 50, "avo": 50},
		"if": {"foe_weapon_type": "spear"}},
	"Bowbreaker": {"description": "+50 Hit and Avo against bows.", "battle": {"hit": 50, "avo": 50},
		"if": {"foe_weapon_type": "bow"}},
	# Strike order and counters.
	"Vantage": {"description": "Strikes first when attacked at or below half HP.", "rules": ["vantage"],
		"if": {"defending": true, "hp_below": 0.5}},
	"Desperation": {"description": "At or below half HP, its follow-up comes right after its first strike, before the counter.",
		"rules": ["desperation"], "if": {"initiating": true, "hp_below": 0.5}},
	"Quick Riposte": {"description": "Always strikes twice when attacked at or above half HP.",
		"rules": ["quick_riposte"], "if": {"defending": true, "hp_above": 0.5}},
	"Wary Fighter": {"description": "Neither side can strike twice in its fights.", "rules": ["wary_fighter"]},
	"Dazzle": {"description": "Foes can't counter its attacks.", "rules": ["no_counter"]},
	"Close Counter": {"description": "Counters at any range when armed.", "rules": ["counter_any"]},
	# Procs.
	"Luna": {"description": "DEX% chance to ignore half the foe's DEF.",
		"proc": {"on": "attack", "rate": "dex", "effect": "pierce", "value": 0.5}},
	"Sol": {"description": "DEX% chance to heal HP equal to the damage dealt.",
		"proc": {"on": "attack", "rate": "dex", "effect": "drain", "value": 1.0}},
	"Lethality": {"description": "DEX/4% chance to defeat the foe in one blow.",
		"proc": {"on": "attack", "rate": "dex/4", "effect": "lethal"}},
	"Pavise": {"description": "DEX% chance to halve damage from adjacent foes.",
		"proc": {"on": "defend", "rate": "dex", "effect": "reduce", "value": 0.5}, "if": {"range": [1, 1]}},
	"Aegis": {"description": "DEX% chance to halve damage from foes at range.",
		"proc": {"on": "defend", "rate": "dex", "effect": "reduce", "value": 0.5}, "if": {"range": [2, 99]}},
	"Miracle": {"description": "LCK% chance to survive a lethal blow with 1 HP (needs more than 1 HP).",
		"proc": {"on": "defend", "rate": "lck", "effect": "survive"}},
	# After combat.
	"Lifetaker": {"description": "Recovers 50% of max HP after defeating a foe it attacked.",
		"after_combat": {"effect": "heal", "value": 0.5}, "if": {"initiating": true, "killed": true}},
	"Galeforce": {"description": "Can act again after defeating a foe it attacked (once per turn).",
		"after_combat": {"effect": "refresh"}, "if": {"initiating": true, "killed": true}},
	"Poison Strike": {"description": "A foe it attacks loses 20% of max HP after combat (never below 1).",
		"after_combat": {"effect": "damage_foe", "value": 0.2}, "if": {"initiating": true}},
	"Savage Blow": {"description": "Foes within 2 tiles of the one it attacks lose 20% of max HP (never below 1).",
		"after_combat": {"effect": "damage_near_foe", "value": 0.2}, "if": {"initiating": true}},
	# Turn start.
	"Renewal": {"description": "Recovers 30% of max HP at the start of each turn.", "turn_start": {"heal": 0.3}},
	# Movement.
	"Pass": {"description": "Can move through enemies.", "map": ["pass"]},
	"Pathfinder": {"description": "Every tile it can enter costs 1 MOV.", "map": ["pathfinder"]},
	"Canto": {"description": "Can move again after acting, with the MOV it has left.", "map": ["canto"]},
	# Auras.
	"Charisma": {"description": "Allies within 3 tiles get +10 Hit and Avo.",
		"aura": {"radius": 3, "affects": "allies", "battle": {"hit": 10, "avo": 10}}},
	"Anathema": {"description": "Foes within 3 tiles get -10 Avo and Crit avoid.",
		"aura": {"radius": 3, "affects": "enemies", "battle": {"avo": -10, "crit_avo": -10}}},
	"Fortify": {"description": "Allies within 1 tile get +2 DEF in combat.",
		"aura": {"radius": 1, "affects": "allies", "battle": {"def": 2}}},
	# EXP and growth.
	"Paragon": {"description": "Earns double EXP.", "exp": 2.0},
	"Aptitude": {"description": "+20% to every growth rate.", "growths": {"all": 20}},
	# Adjacency.
	"Solo Fighter": {"description": "+10 Hit and Avo with no ally next to it.", "battle": {"hit": 10, "avo": 10},
		"if": {"no_adjacent_ally": true}},
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
	if Classes.DATA.has(u.unit_class):  # unset while a unit is being built
		add.call(Classes.get_data(u.unit_class).get("skills", []), "Class")
	# Mounted: the foot class's innate skills stay, except terrain movement (the mount
	# moves for it). The mount's own skills count too.
	if Classes.DATA.has(u.foot_class):
		var kept: Array = Classes.get_data(u.foot_class).get("skills", []).filter(
			func(s): return not TERRAIN_SKILLS.has(s))
		add.call(kept, "Class")
	if not u.mount.is_empty():
		add.call(u.mount.get("skills", []), u.mount.name)
	add.call(Races.get_data(u.race).get("skills", []), "Race")
	if Races.get_data(u.race).get("amphibious", false) and Classes.DATA.has(u.unit_class) \
			and Classes.get_data(u.unit_class).move == "foot" and u.mount.is_empty():
		add.call(["Swimming", "Climbing"], "Race")
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


## Fraction of max HP `u` gives adjacent allies at the start of their phase (Prayer).
static func ally_turn_heal(u: Unit) -> float:
	var total := 0.0
	for skill in of(u):
		total += get_data(skill).get("turn_start", {}).get("heal_allies", 0.0)
	return total


## Cheapest MOV cost `u`'s terrain skills give for terrain `key`, or -1 when none apply.
static func terrain_cost(u: Unit, key: String) -> float:
	var best := -1.0
	for skill in of(u):
		var costs: Dictionary = get_data(skill).get("terrain_costs", {})
		if costs.has(key) and (best < 0 or costs[key] < best):
			best = costs[key]
	return best


## Terrain skills a class gives (its scout/climber/swimmer identity).
static func innate_terrain_skills(class_data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for skill: String in class_data.get("skills", []):
		if TERRAIN_SKILLS.has(skill):
			result.append(skill)
	return result


## Max range bonus for weapon type `kind` ("bow"...) or "spell".
static func range_bonus(u: Unit, kind: String) -> int:
	var total := 0
	for skill in of(u):
		total += get_data(skill).get("range", {}).get(kind, 0)
	return total


static func weight_relief(u: Unit) -> int:
	var total := 0
	for skill in of(u):
		total += get_data(skill).get("weight_relief", 0)
	return total


## Racial attacks (Spells names) `u`'s skills grant.
static func abilities(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for skill in of(u):
		for a: String in get_data(skill).get("abilities", []):
			if not result.has(a):
				result.append(a)
	return result


## Extra MP recovered at the start of its phase.
static func turn_mp(u: Unit) -> int:
	var total := 0
	for skill in of(u):
		total += get_data(skill).get("turn_start", {}).get("mp", 0)
	return total


static func is_immune(u: Unit, status: String) -> bool:
	return of(u).any(func(skill: String) -> bool: return get_data(skill).get("immune", []).has(status))


# --- Combat (see Combat) -------------------------------------------------------------

## Whether `skill`'s "if" conditions hold for `u` fighting `foe`. `initiating`: `u`
## started the fight. Terrain conditions fail without a map.
static func conditions_met(skill: String, u: Unit, foe: Unit, map: BattleMap, initiating: bool,
		killed := false) -> bool:
	var cond: Dictionary = get_data(skill).get("if", {})
	for key: String in cond:
		var v: Variant = cond[key]
		var list: Array = v if v is Array else [v]
		match key:
			"initiating":
				if v != initiating:
					return false
			"defending":
				if v == initiating:
					return false
			"phase":
				var phase_team := u.team if initiating else foe.team
				if (phase_team == Unit.Team.PLAYER) != (v == "player"):
					return false
			"hp_below":
				if u.hp > u.max_hp * float(v):
					return false
			"hp_above":
				if u.hp < u.max_hp * float(v):
					return false
			"range":
				var d := BattleMap.distance(u.cell, foe.cell)
				if d < v[0] or d > v[1]:
					return false
			"weapon_type":
				if not list.has(u.weapon.get("type", "")):
					return false
			"foe_weapon_type":
				if not list.has(foe.weapon.get("type", "")):
					return false
			"foe_tag":
				if not list.any(func(t): return foe.tags.has(t)):
					return false
			"terrain":
				if map == null or not list.has(map.terrain_key(u.cell)):
					return false
			"adjacent_ally":
				if has_adjacent_ally(u) != bool(v):
					return false
			"no_adjacent_ally":
				if has_adjacent_ally(u) == bool(v):
					return false
			"killed":
				if killed != bool(v):
					return false
	return true


static func field_units() -> Array[Unit]:
	var result: Array[Unit] = []
	if field.is_valid():
		result.assign(field.call())
	return result


static func has_adjacent_ally(u: Unit) -> bool:
	return field_units().any(func(o: Unit) -> bool:
		return o != u and o.team == u.team and BattleMap.distance(o.cell, u.cell) == 1)


## Largest aura radius in DATA, so aura lookups only check units that close.
static func _max_aura_radius() -> int:
	var r := 0
	for skill: String in DATA:
		r = maxi(r, DATA[skill].get("aura", {}).get("radius", 0))
	return r


## Sum of the `battle` modifiers of `u`'s skills that apply against `foe` (every key
## of BATTLE_KEYS, 0 when none).
static func battle_mods(u: Unit, foe: Unit, map: BattleMap, initiating: bool) -> Dictionary:
	var mods := {}
	for key in BATTLE_KEYS:
		mods[key] = 0
	for skill in of(u):
		var battle: Dictionary = get_data(skill).get("battle", {})
		if battle.is_empty() or not conditions_met(skill, u, foe, map, initiating):
			continue
		for key in battle:
			mods[key] += battle[key]
	var reach := _max_aura_radius()
	for o in field_units():
		var d := BattleMap.distance(o.cell, u.cell)
		if o == u or d > reach:
			continue
		for skill in of(o):
			var aura: Dictionary = get_data(skill).get("aura", {})
			if aura.is_empty() or d > aura.radius or (aura.affects == "allies") != (o.team == u.team):
				continue
			for key in aura.battle:
				mods[key] += aura.battle[key]
	return mods


## Combat rules (RULES) `u`'s skills give it against `foe`.
static func rules(u: Unit, foe: Unit, map: BattleMap, initiating: bool) -> Array[String]:
	var result: Array[String] = []
	for skill in of(u):
		var list: Array = get_data(skill).get("rules", [])
		if not list.is_empty() and conditions_met(skill, u, foe, map, initiating):
			for r: String in list:
				if not result.has(r):
					result.append(r)
	return result


## `u`'s proc skills for `on` ("attack" or "defend") whose conditions hold, in order.
static func procs(u: Unit, foe: Unit, map: BattleMap, initiating: bool, on: String) -> Array[String]:
	var result: Array[String] = []
	for skill in of(u):
		var proc: Dictionary = get_data(skill).get("proc", {})
		if proc.get("on", "") == on and conditions_met(skill, u, foe, map, initiating):
			result.append(skill)
	return result


## A proc's activation chance for `u`, in percent.
static func proc_rate(u: Unit, skill: String) -> int:
	var rate: Variant = get_data(skill).proc.rate
	if not rate is String:
		return int(rate)
	var m := RegEx.create_from_string("^(\\w+)(?:([*/])(\\d+))?$").search(rate)
	assert(m != null, "bad proc rate: " + rate)
	var stats := {"str": u.combat_str(), "int": u.combat_int(), "dex": u.combat_dex(), "agi": u.combat_agi(),
		"lck": u.combat_lck(), "def": u.combat_def(), "lv": u.level}
	assert(stats.has(m.get_string(1)), "bad proc rate stat: " + rate)
	var value: float = stats[m.get_string(1)]
	match m.get_string(2):
		"*":
			value *= m.get_string(3).to_int()
		"/":
			value /= m.get_string(3).to_int()
	return int(value)


## `u`'s after_combat effects that apply now: [{"skill", "effect", "value"}].
static func after_combat(u: Unit, foe: Unit, map: BattleMap, initiating: bool, killed: bool) -> Array:
	var result := []
	for skill in of(u):
		var after: Dictionary = get_data(skill).get("after_combat", {})
		if not after.is_empty() and conditions_met(skill, u, foe, map, initiating, killed):
			result.append({"skill": skill, "effect": after.effect, "value": after.get("value", 0.0)})
	return result


## Movement rules (MAP_RULES) from `u`'s skills.
static func map_rules(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for skill in of(u):
		for r: String in get_data(skill).get("map", []):
			if not result.has(r):
				result.append(r)
	return result


## Growth rate bonus for `key` ("str"...), including "all".
static func growth_bonus(u: Unit, key: String) -> int:
	var total := 0
	for skill in of(u):
		var g: Dictionary = get_data(skill).get("growths", {})
		total += g.get("all", 0) + g.get(key, 0)
	return total


static func roll_proc(u: Unit, skill: String) -> bool:
	return randi_range(0, 99) < proc_rate(u, skill)


## Problems in DATA (unknown keys, effects, rules, conditions); empty when it's fine.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	for skill: String in DATA:
		var d: Dictionary = DATA[skill]
		if not d.has("description"):
			problems.append(skill + ": no description")
		for key: String in d:
			if not EFFECT_KEYS.has(key):
				problems.append("%s: unknown key %s" % [skill, key])
		for key: String in d.get("stats", {}):
			if not Experience.STATS.has(key) and key != "mov":
				problems.append("%s: unknown stat %s" % [skill, key])
		for key: String in d.get("battle", {}):
			if not BATTLE_KEYS.has(key):
				problems.append("%s: unknown battle key %s" % [skill, key])
		for r: String in d.get("rules", []):
			if not RULES.has(r):
				problems.append("%s: unknown rule %s" % [skill, r])
		for key: String in d.get("if", {}):
			if not CONDITIONS.has(key):
				problems.append("%s: unknown condition %s" % [skill, key])
		for r: String in d.get("map", []):
			if not MAP_RULES.has(r):
				problems.append("%s: unknown map rule %s" % [skill, r])
		if d.has("after_combat") and not AFTER_EFFECTS.has(d.after_combat.get("effect", "")):
			problems.append("%s: unknown after_combat effect" % skill)
		if d.has("aura"):
			for key: String in d.aura.get("battle", {}):
				if not BATTLE_KEYS.has(key):
					problems.append("%s: unknown aura battle key %s" % [skill, key])
			if not d.aura.get("affects", "") in ["allies", "enemies"] or not d.aura.has("radius"):
				problems.append("%s: aura needs radius and affects: allies/enemies" % skill)
		for key: String in d.get("terrain_costs", {}):
			if not BattleMap.TERRAIN.has(key):
				problems.append("%s: unknown terrain %s" % [skill, key])
		for key: String in d.get("range", {}):
			if not ["sword", "spear", "axe", "bow", "staff", "spell"].has(key):
				problems.append("%s: unknown range kind %s" % [skill, key])
		for a: String in d.get("abilities", []):
			if not Spells.DATA.has(a) or not Spells.DATA[a].get("ability", false):
				problems.append("%s: %s isn't an ability in Spells" % [skill, a])
		for key: String in d.get("growths", {}):
			if not Experience.STATS.has(key) and key != "all":
				problems.append("%s: unknown growth %s" % [skill, key])
		if d.has("proc"):
			if not PROC_EFFECTS.has(d.proc.get("effect", "")):
				problems.append("%s: unknown proc effect" % skill)
			if not d.proc.get("on", "") in ["attack", "defend"]:
				problems.append("%s: proc needs on: attack/defend" % skill)
	return problems
