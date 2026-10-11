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

static var DATA := GameData.entries("classes")


## Stat caps (keys as in Experience.STATS). Every class uses these unless it sets
## its own "caps" (a partial dictionary is fine: unlisted stats keep the default).
static var DEFAULT_CAPS := GameData.section("class_stats", "default_caps")


## Promotion (in the campaign's prep screen): a unit at PROMOTION_LEVEL or above can
## promote into one of its class's "promotes_to" classes. It keeps its level and gains
## the new class's bonus (keys as in Experience.STATS; capped by the new class's caps).
const PROMOTION_LEVEL := 15
static var DEFAULT_PROMOTION_BONUS := GameData.section("class_stats", "default_promotion_bonus")
static var PROMOTION_BONUS := GameData.entries("promotion_bonuses")


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
