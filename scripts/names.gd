class_name Names
extends RefCounted
## Random names for generic units (roster "generic": true), by race and gender.
## data/names.cfg has a section per race with its own naming style ({gender: [names]});
## races without one, and genders a race doesn't list, use its [default] section.

static var BY_RACE := GameData.entries("names")
static var DEFAULT: Dictionary = BY_RACE["default"]


static func random(race: String, gender: String) -> String:
	var lists: Dictionary = BY_RACE.get(race, DEFAULT)
	var pool: Array = lists.get(gender, DEFAULT.get(gender, []))
	if pool.is_empty():
		# No list for it (no gender: "none"): any of the race's names.
		for g in lists:
			pool = pool + lists[g]
	return pool.pick_random()
