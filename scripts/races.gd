class_name Races
extends RefCounted
## Races: a per-unit trait (roster "race", default "Human"), independent of class.
## Design and lore notes: docs/races.md.
##
## tags:       effectiveness tags added to the class's (see Unit.tags, Combat.TAG_TRAITS).
## skills:     racial traits (see Skills): EXP bonus, regeneration, immunities, and the
##             body skills for movement and build (Winged, Equine, Stone Body...).
## amphibious: in a foot class (scouts included), also swims and climbs: it gets the
##             Swimming and Climbing skills (see Skills.sources).
## banned:     classes it can't take: "mounted" or a move type.
## only:       move types of the only classes it can take.
## caps:       changes to the class's stat caps: {"hp": 5, "agi": -3}.
## growths:    changes to the unit's growth rates (%): {"str": 5}.
## gender_ratio: odds of each hidden gender for units without one in their roster:
##             {"female": 70, "male": 30} (default 50:50). "none": no gender.

static var DATA := GameData.entries("races")

## Classes with terrain skills (scouts, climbers, swimmers) count as foot classes.
const FOOT_MOVES: Array[String] = ["foot"]

## Movement types by priority: the class (or the mount, for a mounted unit) and the
## unit's body skills each propose one, and the highest wins (see winning_move).
const MOVE_PRIORITY := {"spirit": 5, "ship": 4, "horse": 3, "drake": 3, "flying": 2, "heavy": 1, "foot": 0,
	"mermaid": 0}

const DEFAULT_GENDER_RATIO := {"male": 50, "female": 50}


static func get_data(race: String) -> Dictionary:
	assert(DATA.has(race), "unknown race: " + race)
	return DATA[race]


## Whether a unit of `race` can take `class_id`.
static func allows(race: String, class_id: String) -> bool:
	var r := get_data(race)
	var c := Classes.get_data(class_id)
	if r.has("only") and not r.only.has(c.move):
		return false
	# "Foot classes only" means plain foot: no scouts, climbers or swimmers.
	if r.has("only") and not Skills.innate_terrain_skills(c).is_empty():
		return false
	for ban: String in r.get("banned", []):
		if (ban == "mounted" and c.get("mounted", false)) or ban == c.move:
			return false
	return true


## The movement that wins among `proposals` (the class's or mount's first, then the
## skills'): the highest in MOVE_PRIORITY. On a tie the later one wins, so a skill
## beats a class of the same rank (a Naga Footman swims).
static func winning_move(proposals: Array) -> String:
	var best: String = proposals[0]
	for move: String in proposals:
		if MOVE_PRIORITY[move] >= MOVE_PRIORITY[best]:
			best = move
	return best


## Movement type for an unmounted unit of `race` in `class_id`, from its race's skills
## alone (a unit's own skills can add more: see Unit.set_class).
static func move_type(race: String, class_id: String) -> String:
	var proposals: Array = [Classes.get_data(class_id).move]
	for skill: String in get_data(race).get("skills", []):
		if Skills.get_data(skill).has("move"):
			proposals.append(Skills.get_data(skill).move)
	return winning_move(proposals)


## The race's change to a stat cap (keys as in Experience.STATS).
static func cap_change(race: String, stat: String) -> int:
	return get_data(race).get("caps", {}).get(stat, 0)


## The race's change to a growth rate.
static func growth_change(race: String, stat: String) -> int:
	return get_data(race).get("growths", {}).get(stat, 0)


## A random hidden gender for a unit of `race`, by its gender_ratio.
static func roll_gender(race: String) -> String:
	var ratio: Dictionary = get_data(race).get("gender_ratio", DEFAULT_GENDER_RATIO)
	var total := 0
	for g in ratio:
		total += ratio[g]
	var pick := randi_range(1, total)
	for g: String in ratio:
		pick -= ratio[g]
		if pick <= 0:
			return g
	return ratio.keys()[-1]
