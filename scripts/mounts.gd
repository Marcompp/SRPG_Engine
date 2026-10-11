class_name Mounts
extends RefCounted
## Mounts: creatures units ride into battle (design: docs/mounts.md).
##
## A mount is a record (a Dictionary): {"name", "species", "gender" (visible, for
## flavor), "level", "exp", "stats": {STATS}, "growths": {STATS}, "skills"}.
## Mounting reclasses the rider into the mounted class for its foot class
## (MOUNTED_CLASS, shared by every species); the species supplies move type, tags,
## MOV and the class's display name. While mounted:
##   effective STR/INT/DEX/AGI/LCK/DEF = rider's stat / 2 (rounded down) + mount's;
##   HP and MP stay the rider's own; MOV is the species'.
## In the campaign, mounts live in the stable (Campaign.stable) or on their rider.

const LEVEL_CAP := 10
const EXP_PER_LEVEL := 100
## Mount stats (no HP/MP: those stay the rider's own).
const STATS: Array[String] = ["str", "int", "dex", "agi", "lck", "def"]
## Every stat caps at this unless the species says otherwise (a rider's stat caps
## at 20, so rider / 2 + mount tops out at 20 too).
const DEFAULT_CAP := 10

## move:     move type while riding it (BattleMap.MOVE_TYPES).
## tags:     effectiveness tags it adds (replacing the mounted class's own).
## mov:      MOV while riding it.
## base:     stats at level 1; growths: % per level; caps: per stat (default DEFAULT_CAP).
## exp_rate: multiplier on the EXP the mount earns (see Experience.mount_combat_exp;
##           for non-combat EXP like Dance, the fixed amount times this).
## riders:   who may ride it: {"gender": [...]} (hidden unit gender).
static var SPECIES := GameData.entries("mount_species")

## Foot class -> its mounted class (one per role, shared by every species).
## Classes not listed (heavy armor, ships, spirits) can't mount.
static var MOUNTED_CLASS := GameData.section("mounts", "mounted_class")

## What a mounted class is called on each species.
static var DISPLAY := GameData.section("mounts", "display")

static var NAMES := GameData.strings("mounts", "names", "list")


static func species_data(species: String) -> Dictionary:
	assert(SPECIES.has(species), "unknown mount species: " + species)
	return SPECIES[species]


static func cap(species: String, stat: String) -> int:
	return species_data(species).get("caps", {}).get(stat, DEFAULT_CAP)


## A mount of `species` at `level`, with average stats for that level (base plus
## growth x levels gained, rounded down), so roster and enemy mounts are predictable.
## `extra` (a roster "mount" entry) can set "name", "gender", "skills" and "stats".
static func generate(species: String, level := 1, extra := {}) -> Dictionary:
	var data := species_data(species)
	level = clampi(level, 1, LEVEL_CAP)
	var stats := {}
	for s in STATS:
		stats[s] = mini(data.base[s] + floori(data.growths[s] * (level - 1) / 100.0), cap(species, s))
	stats.merge(extra.get("stats", {}), true)
	return {
		"name": extra.get("name", NAMES.pick_random()),
		"species": species,
		"gender": extra.get("gender", ["male", "female"].pick_random()),
		"level": level,
		"exp": 0,
		"stats": stats,
		"growths": data.growths.duplicate(),
		"skills": extra.get("skills", []).duplicate(),
	}


## The mounted class for `foot_class`, or "" if it can't mount.
static func mounted_class(foot_class: String) -> String:
	return MOUNTED_CLASS.get(foot_class, "")


static func display_name(mounted_class_id: String, species: String) -> String:
	return DISPLAY.get(mounted_class_id, {}).get(species, mounted_class_id)


## Why a unit (foot class, race, hidden gender) can't ride `species` (translated), or "" if it can.
static func ride_problem(foot_class: String, race: String, gender: String, species: String) -> String:
	var mounted := mounted_class(foot_class)
	if mounted == "":
		return TranslationServer.translate("A {class} can't ride.").format({"class": foot_class})
	if race == "Centaur":
		return TranslationServer.translate("Centaurs don't ride: they're mounted already.")
	if not Races.allows(race, mounted):
		return TranslationServer.translate("{race}s can't ride.").format({"race": race})
	var genders: Array = species_data(species).get("riders", {}).get("gender", [])
	if not genders.is_empty() and not genders.has(gender):
		return TranslationServer.translate("{species} only accept {genders} riders.").format({
			"species": species if species.ends_with("s") else species + "s",
			"genders": TranslationServer.translate(" or ").join(genders)})
	return ""


## Gives a mount EXP; returns the stat gains of each level gained ([{stat: 1}...]).
static func gain_exp(mount: Dictionary, amount: int) -> Array:
	var level_ups := []
	if mount.level >= LEVEL_CAP:
		return level_ups
	mount.exp += amount
	while mount.exp >= EXP_PER_LEVEL and mount.level < LEVEL_CAP:
		mount.exp -= EXP_PER_LEVEL
		mount.level += 1
		var gains := {}
		for s in STATS:
			if mount.stats[s] < cap(mount.species, s) and randi_range(0, 99) < mount.growths.get(s, 0):
				mount.stats[s] += 1
				gains[s] = 1
		level_ups.append(gains)
	if mount.level >= LEVEL_CAP:
		mount.exp = 0
	return level_ups
