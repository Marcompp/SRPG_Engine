class_name Classes
extends RefCounted
## Unit classes. A roster entry's "class" decides which weapon types the unit can
## wield, how it moves and its special abilities; stats stay per unit.
##
## weapons:     weapon types the class can equip (see Weapons).
## move:        one of BattleMap.MOVE_TYPES. Also the class's effectiveness tag
##              (see Unit.tags); the unit's race may change how it moves.
## mounted:     can Rescue allies; can't Shove, be Shoved or be Rescued.
## abilities:   "dance"   = refresh an adjacent ally that already acted.
##              "inspire" = buff every adjacent ally's STR and DEF until the next
##                          player phase; the bonus grows with the user's level.
##              "ship"    = allies can Board it; it Unloads them without ending its
##                          turn. Can't Shove or be Shoved.
## capacity:    passengers a ship can hold.
## promoted:    second-tier class.
## promotes_to: classes this one can promote into. Promotion will happen in the
##              battle prep screen and keeps the unit's level.

const DATA := {
	# Foot
	"Swordsman": {"weapons": ["sword"], "move": "foot", "promotes_to": ["Swordsmaster"]},
	"Swordsmaster": {"weapons": ["sword"], "move": "foot", "promoted": true},
	"Footman": {"weapons": ["spear"], "move": "foot", "promotes_to": ["Hoplite"]},
	"Hoplite": {"weapons": ["spear"], "move": "foot", "promoted": true},
	"Axeman": {"weapons": ["axe"], "move": "foot", "promotes_to": ["Berserker"]},
	"Archer": {"weapons": ["bow"], "move": "foot", "promotes_to": ["Marksman"]},
	"Marksman": {"weapons": ["bow"], "move": "foot", "promoted": true},
	# Rogue / scouting
	"Rogue": {"weapons": ["sword"], "move": "rogue", "promotes_to": ["Assassin"]},
	"Assassin": {"weapons": ["sword", "bow"], "move": "rogue", "promoted": true},
	"Corsair": {"weapons": ["sword"], "move": "swim", "promotes_to": ["Swashbuckler"]},
	"Swashbuckler": {"weapons": ["sword", "axe"], "move": "swim", "promoted": true},
	"Brigand": {"weapons": ["axe"], "move": "climb", "promotes_to": ["Berserker"]},
	"Berserker": {"weapons": ["axe"], "move": "swim_climb", "promoted": true},
	"Poacher": {"weapons": ["bow"], "move": "rogue", "promotes_to": ["Reaver"]},
	"Reaver": {"weapons": ["bow", "axe"], "move": "rogue", "promoted": true},
	# Armor
	"Guard": {"weapons": ["spear"], "move": "heavy", "promotes_to": ["Juggernaut"]},
	"Turret": {"weapons": ["bow"], "move": "heavy", "promotes_to": ["Juggernaut"]},
	"Juggernaut": {"weapons": ["spear", "axe", "bow"], "move": "heavy", "promoted": true},
	# Mages
	"Mage": {"weapons": ["staff"], "move": "foot", "promotes_to": ["Sorcerer"]},
	"Sorcerer": {"weapons": ["staff", "sword"], "move": "foot", "promoted": true},
	"Cleric": {"weapons": ["staff"], "move": "foot", "promotes_to": ["Bishop"]},
	"Bishop": {"weapons": ["staff", "spear"], "move": "foot", "promoted": true},
	# Horse
	"Equestrian": {"weapons": ["sword"], "move": "horse", "mounted": true, "promotes_to": ["Gendarme"]},
	"Cavalry": {"weapons": ["spear"], "move": "horse", "mounted": true, "promotes_to": ["Gendarme"]},
	"Gendarme": {"weapons": ["sword", "spear"], "move": "horse", "mounted": true, "promoted": true},
	"Nomad": {"weapons": ["bow"], "move": "horse", "mounted": true, "promotes_to": ["Hussar"]},
	"Hussar": {"weapons": ["bow", "spear"], "move": "horse", "mounted": true, "promoted": true},
	# Flying
	"Flier": {"weapons": ["spear"], "move": "flying", "mounted": true, "promotes_to": ["Whitewing"]},
	"Whitewing": {"weapons": ["spear", "sword"], "move": "flying", "mounted": true, "promoted": true},
	# Ships
	"Galley": {"weapons": ["bow"], "move": "ship", "abilities": ["ship"], "capacity": 2},
	# Spirits (pass through any terrain, even walls, for 1 MOV; no terrain bonuses)
	"Wraith": {"weapons": ["sword"], "move": "spirit"},
	# Special
	"Performer": {"weapons": ["sword"], "move": "foot", "abilities": ["dance"]},
	"Bannerman": {"weapons": ["spear"], "move": "foot", "abilities": ["inspire"]},
}


## Stat caps (keys as in Experience.STATS). Every class uses these unless it sets
## its own "caps" (a partial dictionary is fine: unlisted stats keep the default).
const DEFAULT_CAPS := {"hp": 80, "mp": 40, "str": 20, "int": 20, "dex": 20, "agi": 20, "lck": 20, "def": 20}


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
