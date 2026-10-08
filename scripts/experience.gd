class_name Experience
extends RefCounted
## EXP and level-ups, simplified from the GBA Fire Emblem formulas.

const EXP_PER_LEVEL := 100
const LEVEL_CAP := 20
const KILL_BONUS := 20
## Flat EXP for each Dance (as in GBA FE) and each Inspire.
const DANCE_EXP := 10
const INSPIRE_EXP := 10
## Rerolls when a level-up would give no stats at all.
const EMPTY_LEVEL_REROLLS := 2

## Growth key -> Unit property. Order is the display order on the level-up screen.
const STATS := {
	"hp": "max_hp",
	"str": "strength",
	"int": "intelligence",
	"dex": "dexterity",
	"agi": "agility",
	"lck": "luck",
	"def": "defense",
	"mp": "max_mp",
}
const STAT_LABELS := {"hp": "HP", "str": "Str", "int": "Int", "dex": "Dex", "agi": "Agi", "lck": "Lck",
	"def": "Def", "mp": "MP"}
## Stats only shown/rolled for casters. MP isn't one: it's everyone's magic defense.
const CASTER_STATS: Array[String] = ["int"]


## EXP a unit earns from one combat against `foe`.
static func combat_exp(unit: Unit, foe: Unit, dealt_damage: bool, killed: bool) -> int:
	if not dealt_damage:
		return 1
	var gained := maxi(1, int((31 + foe.level - unit.level) / 3.0))
	if killed:
		gained += maxi(0, KILL_BONUS + (foe.level - unit.level) * 3)
	return clampi(gained, 1, EXP_PER_LEVEL)


## Rolls each stat against the unit's growth rates. Returns {growth_key: 1} for stats that rose.
## Capped stats never roll, so they can't trigger (or absorb) the empty-level reroll.
static func roll_level_up(unit: Unit) -> Dictionary:
	var gains := {}
	for attempt in EMPTY_LEVEL_REROLLS + 1:
		for key in STATS:
			if key in CASTER_STATS and not unit.is_caster():
				continue
			if unit.is_capped(key):
				continue
			if randi_range(0, 99) < unit.growths.get(key, 0):
				gains[key] = 1
		if not gains.is_empty():
			break
	return gains


static func apply_level_up(unit: Unit, gains: Dictionary) -> void:
	unit.level += 1
	for key in gains:
		var prop: String = STATS[key]
		unit.set(prop, mini(unit.get(prop) + gains[key], unit.stat_cap(key)))
	if gains.has("hp"):
		unit.hp += gains.hp
	if gains.has("mp"):
		unit.mp += gains.mp
	unit.queue_redraw()
