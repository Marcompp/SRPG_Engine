class_name Races
extends RefCounted
## Races: a per-unit trait (roster "race", default "Human"), independent of class.
## Design and lore notes: docs/races.md.
##
## tags:       effectiveness tags added to the class's (see Unit.tags, Combat.TAG_TRAITS).
## move:       movement type used whatever the class.
## winged:     moves as flying, unless the class is mounted.
## amphibious: in a foot or scout class, also swims and climbs.
## bonus_mov:  extra MOV in foot and scout classes.
## banned:     classes it can't take: "mounted" or a move type.
## only:       move types of the only classes it can take.
## carrier:    can Rescue and Shove in any class; can't be Rescued or Shoved.
## immovable:  can't be Rescued or Shoved.
## immune:     statuses it ignores ("poison": not implemented yet).
## hp_regen:   fraction of max HP restored at the start of its phase.
## mp_regen:   MP recovered at the start of its phase, on top of Spells.MP_REGEN.
## exp_mult:   multiplier on EXP earned.
## Ship classes keep their own movement: race movement rules don't apply to them.

const DATA := {
	"Human": {"exp_mult": 1.1,
		"description": "Adaptable: earns 10% more EXP."},
	"Orc": {"tags": ["greenskin"], "immune": ["poison"],
		"description": "Greenskin. Immune to poison."},
	"Troll": {"hp_regen": 0.1, "immune": ["poison"],
		"description": "Regenerates 10% HP every turn. Immune to poison."},
	"Elf": {"tags": ["fae"],
		"description": "Fae."},
	"Fairy": {"tags": ["flying", "fae"], "winged": true, "mp_regen": 1,
		"description": "Winged: flies unless mounted, and counts as a flier. Fae. Recovers 1 extra MP every turn."},
	"Naga": {"tags": ["aquatic", "reptile"], "move": "mermaid", "banned": ["mounted"],
		"description": "Aquatic: always moves through water, and is weak to spears and Lightning but resists Fire and Water. Reptile: weak to Ice. Can't ride."},
	"Lizal": {"tags": ["reptile"], "amphibious": true, "immune": ["poison"],
		"description": "Amphibious: swims and climbs in foot and scout classes. Reptile: weak to Ice, resists Fire. Immune to poison."},
	"Centaur": {"tags": ["horse"], "move": "horse", "bonus_mov": 1, "carrier": true, "banned": ["flying"],
		"description": "Equine: always moves and counts as a horse, +1 MOV in foot and scout classes. Can Rescue and Shove; can't be Rescued or Shoved. Can't fly."},
	"Minotaur": {"tags": ["horse"], "banned": ["mounted"],
		"description": "Half-Equine: counts as a horse. Can't ride."},
	"Harpy": {"tags": ["flying"], "winged": true, "banned": ["heavy"],
		"description": "Winged: flies unless mounted, and counts as a flier. Can't wear heavy armor."},
	"Ent": {"tags": ["wooden"], "move": "heavy", "immovable": true, "banned": ["mounted"],
		"description": "Wooden Body: always moves as heavy armor, can't be Rescued or Shoved. Weak to axes, Fire and Ice; resists Water and Earth. Can't ride."},
	"Stoneborn": {"tags": ["heavy"], "move": "heavy", "immovable": true, "only": ["foot", "heavy"],
		"immune": ["poison"],
		"description": "Stone Body: always moves and counts as heavy armor, can't be Rescued or Shoved. Immune to poison. Foot and armor classes only."},
	"Skeleton": {"tags": ["undead"], "immune": ["poison"],
		"description": "Undead: weak to silver, Fire and Light; resists Dark. Immune to poison."},
	"Ghost": {"tags": ["undead", "spirit"], "move": "spirit", "immune": ["poison"],
		"description": "Undead: weak to silver, Fire and Light; resists Dark. Spiritual: always moves and counts as a spirit. Immune to poison."},
}

## Foot and scout move types (what "foot and scout classes" means above).
const FOOT_MOVES: Array[String] = ["foot", "rogue", "climb", "swim", "swim_climb"]


static func get_data(race: String) -> Dictionary:
	assert(DATA.has(race), "unknown race: " + race)
	return DATA[race]


## Whether a unit of `race` can take `class_id`.
static func allows(race: String, class_id: String) -> bool:
	var r := get_data(race)
	var c := Classes.get_data(class_id)
	if r.has("only") and not r.only.has(c.move):
		return false
	for ban: String in r.get("banned", []):
		if (ban == "mounted" and c.get("mounted", false)) or ban == c.move:
			return false
	return true


## Movement type for a unit of `race` in `class_id`.
static func move_type(race: String, class_id: String) -> String:
	var r := get_data(race)
	var c := Classes.get_data(class_id)
	var move: String = c.move
	if move == "ship":
		return move
	if r.has("move"):
		return r.move
	if r.get("winged", false) and not c.get("mounted", false):
		return "flying"
	if r.get("amphibious", false) and FOOT_MOVES.has(move):
		return "rogue_swim_climb" if move == "rogue" else "swim_climb"
	return move


## Extra MOV for a unit of `race` in `class_id`.
static func bonus_mov(race: String, class_id: String) -> int:
	return get_data(race).get("bonus_mov", 0) if FOOT_MOVES.has(Classes.get_data(class_id).move) else 0
