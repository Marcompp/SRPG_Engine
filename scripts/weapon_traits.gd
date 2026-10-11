class_name WeaponTraits
extends RefCounted
## Weapon traits earned through use. Every weapon keeps a kill history (who it
## killed, how, and the state its wielder was in); on its KILLS_FOR_TRAIT-th kill it
## gains one trait, a skill (see Skills) rolled with weights from that history. The
## trait is the weapon's own: it goes in the weapon's "skills" (granted while
## equipped, like any weapon skill) and "trait", and stays with it (trades, convoy,
## the campaign). Forging and enchanting will come later.

const KILLS_FOR_TRAIT := 50

## History key -> traits it leans toward. Keys:
##   who:   "tag:<unit tag>" (heavy, horse, flying...), "vs:<foe weapon type>"
##   how:   "crit", "counter" (on the counter), "initiated" (on its own attack),
##          "ranged" (2+ tiles away), "boss"
##   state: "low_hp" (wielder at or below half HP), "alone" (no ally next to it),
##          "afflicted" (wielder under a status)
const LEANINGS := {
	"tag:heavy": ["Armorbane"], "tag:horse": ["Horsebane", "Impale"], "tag:flying": ["Skybane", "Impale"],
	"tag:reptile": ["Wyrmbane"], "tag:undead": ["Grimbane"], "tag:spirit": ["Grimbane"], "tag:fae": ["Faebane"],
	"tag:greenskin": ["Orcbane"], "tag:aquatic": ["Tidebane"], "tag:wooden": ["Woodsplitter"],
	"vs:sword": ["Swordbreaker"], "vs:axe": ["Axebreaker"], "vs:spear": ["Spearbreaker"], "vs:bow": ["Bowbreaker"],
	"crit": ["Crit +20", "Lethality"], "counter": ["Quick Riposte", "Steady Stance", "Vantage"],
	"initiated": ["Death Blow", "Darting Blow"], "ranged": ["Far Shot", "Aegis"], "boss": ["Lethality", "Death Blow"],
	"low_hp": ["Wrath", "Vantage", "Desperation", "Miracle"], "alone": ["Solo Fighter", "Evasion"],
	"afflicted": ["Steady Stance", "Miracle"],
}
## Traits any weapon can roll, whatever its history, each with this weight (a
## history key's kills are split between its traits).
const GENERIC: Array[String] = ["Death Blow", "Evasion", "Crit +20", "Darting Blow"]
const GENERIC_WEIGHT := 3.0


## Notes a kill by `u` with `weapon` (its equipped weapon) on `foe`. `result`: the
## strike (crit, "counter" when it was a counterattack); `alone`: no ally was next to
## `u`. Returns the trait the weapon just earned, or "".
static func record_kill(weapon: Dictionary, u: Unit, foe: Unit, result: Dictionary, alone: bool) -> String:
	var history: Dictionary = weapon.get("history", {})
	var keys: Array[String] = []
	for tag: String in foe.tags:
		keys.append("tag:" + tag)
	if not foe.weapon.is_empty():
		keys.append("vs:" + str(foe.weapon.type))
	if result.get("crit", false):
		keys.append("crit")
	keys.append("counter" if result.get("counter", false) else "initiated")
	if BattleMap.distance(u.cell, foe.cell) >= 2:
		keys.append("ranged")
	if foe.is_boss:
		keys.append("boss")
	if u.hp * 2 <= u.max_hp:
		keys.append("low_hp")
	if alone:
		keys.append("alone")
	if not u.statuses.is_empty():
		keys.append("afflicted")
	for key in keys:
		history[key] = history.get(key, 0) + 1
	weapon["history"] = history
	weapon["kills"] = weapon.get("kills", 0) + 1
	if weapon.kills != KILLS_FOR_TRAIT or weapon.has("trait"):
		return ""
	var earned := roll(history)
	weapon["trait"] = earned
	var skills: Array = weapon.get("skills", []).duplicate()
	skills.append(earned)
	weapon["skills"] = skills
	return earned


## Weights for each trait a history leans toward (plus the generic ones).
static func weights(history: Dictionary) -> Dictionary:
	var result := {}
	for t in GENERIC:
		result[t] = GENERIC_WEIGHT
	for key: String in history:
		var leaning: Array = LEANINGS.get(key, [])
		for t: String in leaning:
			result[t] = result.get(t, 0.0) + float(history[key]) / leaning.size()
	return result


static func roll(history: Dictionary) -> String:
	var w := weights(history)
	var total := 0.0
	for t in w:
		total += w[t]
	var pick := randf() * total
	for t in w:
		pick -= w[t]
		if pick <= 0.0:
			return t
	return w.keys()[-1]


## Every trait named here exists in Skills; empty when it's fine.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	var all: Array[String] = GENERIC.duplicate()
	for key in LEANINGS:
		all.append_array(LEANINGS[key])
	for t in all:
		if not Skills.DATA.has(t):
			problems.append("unknown trait skill " + t)
	return problems
