class_name Levels
extends RefCounted
## Playable maps: terrain layout plus both rosters. The level select screen sets
## `selected` and the battle scene loads it. The default is the first level,
## which the test suite relies on.
##
## Terrain keys are defined in BattleMap.TERRAIN; unit entries are read by Unit.create().
## Every unit needs a "class" (see Classes), which sets its movement and weapons.

static var selected := "river_crossing"
## Set by the level select to resume the suspended battle instead of starting fresh.
static var resume := false

static var ORDER := GameData.strings("levels/index", "", "order")

static var DATA := GameData.folder("levels")


## A test map (DATA) or a campaign chapter (Chapters.DATA).
static func get_level(id: String) -> Dictionary:
	return DATA[id] if DATA.has(id) else Chapters.DATA[id]
