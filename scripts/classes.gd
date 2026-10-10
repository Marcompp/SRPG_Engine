class_name Classes
extends RefCounted
## Unit classes. A roster entry's "class" decides which weapon types the unit can
## wield, how it moves and its special abilities; stats stay per unit.
##
## weapons:     weapon types the class can equip (see Weapons).
## Mounted classes (Equestrian, Cavalry, Raider, Nomad, Battlemage and their
## promotions) are what a unit becomes on a mount (see Mounts): shared by every
## species, which supplies their move type, tags and display name ("Cavalry" on a
## pegasus is a "Flier"). Their own "move" only applies to a unit placed in one
## without a mount.
## move:        one of BattleMap.MOVE_TYPES. Also the class's effectiveness tag
##              (see Unit.tags); the unit's race may change how it moves. Scouts,
##              climbers and swimmers are "foot" with a terrain skill (Forester,
##              Climbing, Swimming).
## mounted:     can Rescue allies; can't Shove, be Shoved or be Rescued.
## abilities:   "ship" = allies can Board it; it Unloads them without ending its
##              turn. Can't Shove or be Shoved.
## skills:      innate skills: every unit of the class has them (see Skills). A
##              promoted class lists its own full set; the old class's are dropped.
## learn:       {level: skill}: small rewards for sticking with the class, learned for
##              good on reaching that level in it (they count toward Skills.LEARNED_CAP).
## capacity:    passengers a ship can hold.
## promoted:    second-tier class.
## promotes_to: classes this one can promote into. Promotion will happen in the
##              battle prep screen and keeps the unit's level.

const DATA := {
	# Foot
	"Swordsman": {"weapons": ["sword"], "move": "foot", "learn": {10: "Speed +2"}, "promotes_to": ["Swordsmaster"]},
	"Swordsmaster": {"weapons": ["sword"], "move": "foot", "skills": ["Crit +20"], "promoted": true},
	"Footman": {"weapons": ["spear"], "move": "foot", "learn": {10: "Open Ground"}, "promotes_to": ["Hoplite"]},
	"Hoplite": {"weapons": ["spear"], "move": "foot", "skills": ["Impale"], "promoted": true},
	"Axeman": {"weapons": ["axe"], "move": "foot", "learn": {10: "Strength +2"}, "promotes_to": ["Berserker"]},
	"Archer": {"weapons": ["bow"], "move": "foot", "learn": {10: "Skill +4"}, "promotes_to": ["Marksman"]},
	"Marksman": {"weapons": ["bow"], "move": "foot", "skills": ["Bow Range +1"], "promoted": true},
	# Rogue / scouting
	"Rogue": {"weapons": ["sword"], "move": "foot", "skills": ["Forester", "Steal", "Lockpick"],
		"learn": {10: "Evasion"}, "promotes_to": ["Assassin"]},
	"Assassin": {"weapons": ["sword", "bow"], "move": "foot", "skills": ["Forester", "Steal", "Lockpick", "Lethality"],
		"promoted": true},
	"Corsair": {"weapons": ["sword"], "move": "foot", "skills": ["Swimming"], "learn": {10: "Sea Legs"},
		"promotes_to": ["Swashbuckler"]},
	"Swashbuckler": {"weapons": ["sword", "axe"], "move": "foot", "skills": ["Swimming", "Pass"], "promoted": true},
	"Brigand": {"weapons": ["axe"], "move": "foot", "skills": ["Climbing"], "learn": {10: "Highlander"},
		"promotes_to": ["Berserker"]},
	"Berserker": {"weapons": ["axe"], "move": "foot", "skills": ["Swimming", "Climbing", "Wrath"], "promoted": true},
	"Poacher": {"weapons": ["bow"], "move": "foot", "skills": ["Forester"], "learn": {10: "Ambush"},
		"promotes_to": ["Reaver"]},
	"Reaver": {"weapons": ["bow", "axe"], "move": "foot", "skills": ["Forester", "Brawn"], "promoted": true},
	# Armor
	"Guard": {"weapons": ["spear"], "move": "heavy", "learn": {10: "Defense +2"}, "promotes_to": ["Juggernaut"]},
	"Turret": {"weapons": ["bow"], "move": "heavy", "learn": {10: "Max HP +5"}, "promotes_to": ["Juggernaut"]},
	"Juggernaut": {"weapons": ["spear", "axe", "bow"], "move": "heavy", "skills": ["Warding"], "promoted": true},
	# Mages
	"Mage": {"weapons": ["staff"], "move": "foot", "learn": {10: "Magic +2"}, "promotes_to": ["Sorcerer"]},
	"Sorcerer": {"weapons": ["staff", "sword"], "move": "foot", "skills": ["Spell Range +1"], "promoted": true},
	"Cleric": {"weapons": ["staff"], "move": "foot", "learn": {10: "Max MP +5"}, "promotes_to": ["Bishop"]},
	"Bishop": {"weapons": ["staff", "spear"], "move": "foot", "skills": ["Prayer"], "promoted": true},
	# Horse
	"Equestrian": {"weapons": ["sword"], "move": "horse", "mounted": true, "skills": ["Canto"], "promotes_to": ["Gendarme"]},
	"Cavalry": {"weapons": ["spear"], "move": "horse", "mounted": true, "skills": ["Canto"], "promotes_to": ["Gendarme"]},
	"Gendarme": {"weapons": ["sword", "spear"], "move": "horse", "mounted": true, "skills": ["Canto"], "promoted": true},
	"Nomad": {"weapons": ["bow"], "move": "horse", "mounted": true, "skills": ["Canto"], "promotes_to": ["Hussar"]},
	"Hussar": {"weapons": ["bow", "spear"], "move": "horse", "mounted": true, "skills": ["Canto"], "promoted": true},
	"Raider": {"weapons": ["axe"], "move": "horse", "mounted": true, "skills": ["Canto"], "promotes_to": ["Warlord"]},
	"Warlord": {"weapons": ["axe", "spear"], "move": "horse", "mounted": true, "skills": ["Canto"], "promoted": true},
	"Battlemage": {"weapons": ["staff"], "move": "horse", "mounted": true, "skills": ["Canto"], "promotes_to": ["Spellknight"]},
	"Spellknight": {"weapons": ["staff", "sword"], "move": "horse", "mounted": true, "skills": ["Canto"], "promoted": true},
	# Ships
	"Galley": {"weapons": ["bow"], "move": "ship", "abilities": ["ship"], "capacity": 2},
	# Spirits (pass through any terrain, even walls, for 1 MOV; no terrain bonuses)
	"Wraith": {"weapons": ["sword"], "move": "spirit"},
	# Special
	"Performer": {"weapons": ["sword"], "move": "foot", "skills": ["Dance"], "learn": {10: "Footwork"}},
	"Bannerman": {"weapons": ["spear"], "move": "foot", "skills": ["Inspire"]},
}


## Stat caps (keys as in Experience.STATS). Every class uses these unless it sets
## its own "caps" (a partial dictionary is fine: unlisted stats keep the default).
const DEFAULT_CAPS := {"hp": 80, "mp": 40, "str": 20, "int": 20, "dex": 20, "agi": 20, "lck": 20, "def": 20}


## Promotion (in the campaign's prep screen): a unit at PROMOTION_LEVEL or above can
## promote into one of its class's "promotes_to" classes. It keeps its level and gains
## the new class's bonus (keys as in Experience.STATS; capped by the new class's caps).
const PROMOTION_LEVEL := 15
const DEFAULT_PROMOTION_BONUS := {"hp": 3, "str": 1, "dex": 1, "agi": 1, "def": 1, "mp": 1}
const PROMOTION_BONUS := {
	"Swordsmaster": {"hp": 3, "str": 2, "dex": 3, "agi": 3, "def": 1},
	"Hoplite": {"hp": 4, "str": 2, "dex": 1, "agi": 1, "def": 3},
	"Marksman": {"hp": 3, "str": 2, "dex": 3, "agi": 2, "def": 1},
	"Assassin": {"hp": 2, "str": 1, "dex": 3, "agi": 3, "lck": 2},
	"Swashbuckler": {"hp": 4, "str": 2, "dex": 2, "agi": 2, "def": 1},
	"Berserker": {"hp": 5, "str": 3, "dex": 1, "agi": 1, "def": 1},
	"Reaver": {"hp": 3, "str": 2, "dex": 2, "agi": 2, "def": 1},
	"Juggernaut": {"hp": 4, "str": 2, "def": 4},
	"Sorcerer": {"hp": 2, "int": 3, "dex": 1, "agi": 1, "mp": 4},
	"Bishop": {"hp": 3, "int": 2, "agi": 1, "lck": 2, "mp": 4},
	"Gendarme": {"hp": 3, "str": 2, "dex": 1, "agi": 1, "def": 2},
	"Hussar": {"hp": 3, "str": 1, "dex": 2, "agi": 2, "def": 1},
}


static func promotion_bonus(class_id: String) -> Dictionary:
	return PROMOTION_BONUS.get(class_id, DEFAULT_PROMOTION_BONUS)


static func caps(class_id: String) -> Dictionary:
	var result: Dictionary = DEFAULT_CAPS.duplicate()
	result.merge(get_data(class_id).get("caps", {}), true)
	return result


static func get_data(class_id: String) -> Dictionary:
	assert(DATA.has(class_id), "unknown class: " + class_id)
	return DATA[class_id]


static func promotions(class_id: String) -> Array:
	return get_data(class_id).get("promotes_to", [])


## STR/DEF bonus an Inspire from a unit of this level gives: +1, then +1 more every 5 levels.
static func inspire_bonus(level: int) -> int:
	return 1 + floori(level / 5.0)
