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
const SPECIES := {
	"Horse": {"move": "horse", "tags": ["horse"], "mov": 7, "exp_rate": 1.0,
		"base": {"str": 2, "int": 0, "dex": 2, "agi": 3, "lck": 1, "def": 2},
		"growths": {"str": 40, "int": 5, "dex": 35, "agi": 45, "lck": 30, "def": 35},
		"description": "The baseline mount: fast on open ground, slowed by forests and indoors. Weak to Pikes."},
	"Pegasus": {"move": "flying", "tags": ["flying"], "mov": 7, "exp_rate": 0.9,
		"base": {"str": 1, "int": 2, "dex": 3, "agi": 4, "lck": 3, "def": 1},
		"growths": {"str": 30, "int": 25, "dex": 40, "agi": 50, "lck": 40, "def": 20},
		"riders": {"gender": ["female"]},
		"description": "Flies over any terrain, but no terrain bonuses and weak to bows. Only accepts female riders."},
	"Drake": {"move": "drake", "tags": ["reptile"], "mov": 5, "exp_rate": 0.7,
		"base": {"str": 3, "int": 0, "dex": 1, "agi": 1, "lck": 0, "def": 4},
		"growths": {"str": 45, "int": 5, "dex": 25, "agi": 20, "lck": 15, "def": 45},
		"description": "Flightless. Less MOV than a horse, but crosses hills and mountains easily. Reptile: weak to Ice, resists Fire."},
}

## Foot class -> its mounted class (one per role, shared by every species).
## Classes not listed (heavy armor, ships, spirits) can't mount.
const MOUNTED_CLASS := {
	"Swordsman": "Equestrian", "Rogue": "Equestrian", "Corsair": "Equestrian", "Performer": "Equestrian",
	"Footman": "Cavalry", "Bannerman": "Cavalry",
	"Axeman": "Raider", "Brigand": "Raider",
	"Archer": "Nomad", "Poacher": "Nomad",
	"Mage": "Battlemage", "Cleric": "Battlemage",
	"Swordsmaster": "Gendarme", "Assassin": "Gendarme", "Swashbuckler": "Gendarme", "Hoplite": "Gendarme",
	"Berserker": "Warlord",
	"Marksman": "Hussar", "Reaver": "Hussar",
	"Sorcerer": "Spellknight", "Bishop": "Spellknight",
}

## What a mounted class is called on each species.
const DISPLAY := {
	"Equestrian": {"Horse": "Equestrian", "Pegasus": "Sky Knight", "Drake": "Drake Knight"},
	"Cavalry": {"Horse": "Cavalry", "Pegasus": "Flier", "Drake": "Drake Lancer"},
	"Raider": {"Horse": "Raider", "Pegasus": "Sky Raider", "Drake": "Drake Raider"},
	"Nomad": {"Horse": "Nomad", "Pegasus": "Sky Archer", "Drake": "Drake Archer"},
	"Battlemage": {"Horse": "Battlemage", "Pegasus": "Sky Mage", "Drake": "Drake Mage"},
	"Gendarme": {"Horse": "Gendarme", "Pegasus": "Whitewing", "Drake": "Drake Lord"},
	"Warlord": {"Horse": "Warlord", "Pegasus": "Storm Rider", "Drake": "Wyrm Warlord"},
	"Hussar": {"Horse": "Hussar", "Pegasus": "Sky Hussar", "Drake": "Drake Hussar"},
	"Spellknight": {"Horse": "Spellknight", "Pegasus": "Sky Sage", "Drake": "Drake Sage"},
}

const NAMES := ["Bayard", "Arion", "Marengo", "Copper", "Thistle", "Gale", "Ember", "Juniper", "Shadowfax",
	"Bramble", "Duchess", "Pepper", "Comet", "Willow", "Sable", "Fenwick"]


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


## Why a unit (foot class, race, hidden gender) can't ride `species`, or "" if it can.
static func ride_problem(foot_class: String, race: String, gender: String, species: String) -> String:
	var mounted := mounted_class(foot_class)
	if mounted == "":
		return "A %s can't ride." % foot_class
	if race == "Centaur":
		return "Centaurs don't ride: they're mounted already."
	if not Races.allows(race, mounted):
		return "%ss can't ride." % race
	var genders: Array = species_data(species).get("riders", {}).get("gender", [])
	if not genders.is_empty() and not genders.has(gender):
		return "%s only accept %s riders." % [species if species.ends_with("s") else species + "s",
			" or ".join(genders)]
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
