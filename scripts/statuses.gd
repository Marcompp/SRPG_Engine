class_name Statuses
extends RefCounted
## Status effects (design: docs/status_effects.md): temporary conditions on a unit,
## kept in Unit.statuses as {name: turns left} (-1: until cured). An active status
## is also a skill source (see Skills.sources), so it can use any skill key under
## "effects". Keys:
##
## description: shown on the status screen (also used as its skill description).
## color:       its marker on the map tile.
## duration:    default turns (-1: until cured). Turns go down at the start of the
##              afflicted unit's side's phase, after its tick.
## tick:        at the start of its side's phase: {"damage": [min, max]}. Tick damage
##              never kills, leaving 1 HP, unless the unit is already at 1 HP.
## lingers:     kept when the chapter ends (others are cleared).
## effects:     skill keys (see Skills) that apply while it lasts.

const DATA := {
	"Poison": {"description": "Loses 4-6 HP at the start of each of its phases (never below 1, unless already at 1 HP).",
		"color": Color("b050e0"), "duration": 3, "tick": {"damage": [4, 6]}},
}

const KEYS: Array[String] = ["description", "color", "duration", "tick", "lingers", "effects"]
const TICK_KEYS: Array[String] = ["damage"]


static func get_data(status: String) -> Dictionary:
	assert(DATA.has(status), "unknown status: " + status)
	return DATA[status]


## The status as a skill (see Skills.get_data): its effects plus its description.
static func skill_data(status: String) -> Dictionary:
	var d: Dictionary = get_data(status).get("effects", {}).duplicate()
	d.description = get_data(status).description
	return d


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
		for key: String in d.get("tick", {}):
			if not TICK_KEYS.has(key):
				problems.append("%s: unknown tick key %s" % [s, key])
		if Skills.DATA.has(s):
			problems.append("%s: also a skill name" % s)
		for p in Skills.problems_in(s, skill_data(s)):
			problems.append("%s (effects)" % p)
	return problems
