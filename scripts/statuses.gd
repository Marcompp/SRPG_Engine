class_name Statuses
extends RefCounted
## Status effects (design: docs/status_effects.md): temporary conditions on a unit,
## kept in Unit.statuses as {name: turns left} (-1: until cured). An active status
## is also a skill source (see Skills.sources), so it can use any skill key under
## "effects". Keys:
##
## description: shown on the status screen (also used as its skill description).
## color:       its marker on the map tile.
## duration:    default turns (-1: until cured): how many of the afflicted unit's own
##              phases it lasts. Turns go down at the end of each of them.
## tick:        at the start of its side's phase: {"damage": [min, max]}. Tick damage
##              never kills, leaving 1 HP, unless the unit is already at 1 HP.
## restrict:    what it can't do (see RESTRICTIONS): "move", "act" (no commands and no
##              counterattacks: it starts its phase as having acted), "magic" (spells
##              and racial attacks), "items".
## cure_on_hit: ends when the unit takes damage (popup: `cured_text`, or "<name> ended").
## no_avoid:    its Avoid is 0 (terrain and skills included).
## control:     "berserk": the AI plays its turn at the start of its side's phase (player
##              units too), attacking the nearest unit of any side it can reach.
## lingers:     kept when the chapter ends (others are cleared).
## effects:     skill keys (see Skills) that apply while it lasts.

const DATA := {
	"Poison": {"description": "Loses 4-6 HP at the start of each of its phases (never below 1, unless already at 1 HP).",
		"color": Color("b050e0"), "duration": 3, "tick": {"damage": [4, 6]}},
	"Silence": {"description": "Can't use spells or racial attacks.",
		"color": Color("5aa0ff"), "duration": 3, "restrict": ["magic"]},
	"Sleep": {"description": "Can't move, act or counterattack. Wakes up when it takes damage.",
		"color": Color("7080b0"), "duration": 2, "restrict": ["move", "act"], "cure_on_hit": true,
		"cured_text": "Woke up"},
	"Paralyse": {"description": "Can't move, but can still act where it stands.",
		"color": Color("e0c040"), "duration": 1, "restrict": ["move"]},
	"Berserk": {"description": "Out of control: at the start of its phase it attacks the nearest unit it can reach, friend or foe.",
		"color": Color("e05030"), "duration": 3, "control": "berserk"},
	"Petrify": {"description": "Turned to stone: can't move, act or counterattack, and has no Avoid, but DEF +10. Lasts until cured, even between chapters.",
		"color": Color("909090"), "duration": -1, "restrict": ["move", "act"], "no_avoid": true, "lingers": true,
		"effects": {"stats": {"def": 10}}},
}

const KEYS: Array[String] = ["description", "color", "duration", "tick", "restrict", "cure_on_hit", "cured_text",
	"no_avoid", "control", "lingers", "effects"]
const RESTRICTIONS: Array[String] = ["move", "act", "magic", "items"]
const TICK_KEYS: Array[String] = ["damage"]


static func get_data(status: String) -> Dictionary:
	assert(DATA.has(status), "unknown status: " + status)
	return DATA[status]


## The status as a skill (see Skills.get_data): its effects plus its description.
static func skill_data(status: String) -> Dictionary:
	var d: Dictionary = get_data(status).get("effects", {}).duplicate()
	d.description = get_data(status).description
	return d


## Whether one of `u`'s statuses stops it doing `what` (see RESTRICTIONS).
static func restricts(u: Unit, what: String) -> bool:
	for s: String in u.statuses:
		if get_data(s).get("restrict", []).has(what):
			return true
	return false


## Whether one of `u`'s statuses has the flag `key` (e.g. "no_avoid").
static func has_flag(u: Unit, key: String) -> bool:
	for s: String in u.statuses:
		if get_data(s).get(key, false):
			return true
	return false


## Whether a status (Berserk) has the AI play `u`'s turns, against every side.
static func is_berserk(u: Unit) -> bool:
	for s: String in u.statuses:
		if get_data(s).get("control", "") == "berserk":
			return true
	return false


## `u` took damage: ends its cure_on_hit statuses (Sleep), with a popup each.
static func on_damaged(u: Unit) -> void:
	for s: String in u.statuses.keys():
		if get_data(s).get("cure_on_hit", false):
			u.statuses.erase(s)
			u.popup(get_data(s).get("cured_text", s + " ended"), Color.LIGHT_GRAY, 10.0)
	u.queue_redraw()


## "3 turns", "1 turn" or "Until cured".
static func duration_text(turns: int) -> String:
	if turns < 0:
		return "Until cured"
	return "%d turn%s" % [turns, "" if turns == 1 else "s"]


## Inflicts `status` on `u` for `turns` (its default duration when 0). Again on a unit
## that has it: refreshes it to the longer of the two. Returns false if `u` is immune.
static func inflict(u: Unit, status: String, turns := 0) -> bool:
	if Skills.is_immune(u, status):
		return false
	if turns == 0:
		turns = get_data(status).duration
	var current: int = u.statuses.get(status, 0)
	if current < 0 or turns < 0:
		u.statuses[status] = -1
	else:
		u.statuses[status] = maxi(current, turns)
	u.queue_redraw()
	return true


## Removes `status` from `u`; with no status, every status. Returns what was cured.
static func cure(u: Unit, status := "") -> Array[String]:
	var cured: Array[String] = []
	for s: String in u.statuses.keys():
		if status == "" or s == status:
			cured.append(s)
			u.statuses.erase(s)
	u.queue_redraw()
	return cured


## HP `u` loses to its statuses' ticks this phase start (already capped so it only
## kills a unit at 1 HP).
static func tick_damage(u: Unit) -> int:
	var total := 0
	for s: String in u.statuses:
		var dmg: Array = get_data(s).get("tick", {}).get("damage", [0, 0])
		total += randi_range(dmg[0], dmg[1])
	if total <= 0:
		return 0
	return 1 if u.hp <= 1 else mini(total, u.hp - 1)


## Counts down every status by one turn; returns the ones that ran out (removed).
static func count_down(u: Unit) -> Array[String]:
	var ended: Array[String] = []
	for s: String in u.statuses.keys():
		if u.statuses[s] < 0:
			continue
		u.statuses[s] -= 1
		if u.statuses[s] <= 0:
			u.statuses.erase(s)
			ended.append(s)
	u.queue_redraw()
	return ended


## End of a chapter: only lingering statuses carry over.
static func clear_for_next_map(u: Unit) -> void:
	for s: String in u.statuses.keys():
		if not get_data(s).get("lingers", false):
			u.statuses.erase(s)


## Problems in DATA (unknown keys, bad effects); empty when it's fine.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	for s: String in DATA:
		var d: Dictionary = DATA[s]
		for key: String in d:
			if not KEYS.has(key):
				problems.append("%s: unknown key %s" % [s, key])
		for key: String in ["description", "color", "duration"]:
			if not d.has(key):
				problems.append("%s: no %s" % [s, key])
		for r: String in d.get("restrict", []):
			if not RESTRICTIONS.has(r):
				problems.append("%s: unknown restriction %s" % [s, r])
		for key: String in d.get("tick", {}):
			if not TICK_KEYS.has(key):
				problems.append("%s: unknown tick key %s" % [s, key])
		if Skills.DATA.has(s):
			problems.append("%s: also a skill name" % s)
		for p in Skills.problems_in(s, skill_data(s)):
			problems.append("%s (effects)" % p)
	return problems
