class_name Names
extends RefCounted
## Random names for generic units (roster "generic": true), by race and gender.
## Races without their own lists use DEFAULT. Add a race to BY_RACE to give it
## its own naming style.

const DEFAULT := {
	"male": ["Aldric", "Bram", "Cedric", "Dorran", "Edmund", "Falk", "Garret", "Hal", "Ivo", "Jory",
		"Kell", "Leof", "Marten", "Niall", "Osric", "Piers", "Quill", "Rowan", "Sten", "Tobin",
		"Ulric", "Vane", "Wat", "Yorick"],
	"female": ["Adela", "Brin", "Cara", "Della", "Elspeth", "Fenna", "Greta", "Hild", "Isolde", "Jessa",
		"Kaya", "Lisbet", "Maren", "Nell", "Odette", "Petra", "Rhea", "Sabine", "Tilda", "Una",
		"Vera", "Wynn", "Yara", "Zelda"],
}

## Per-race lists, same shape as DEFAULT. Empty for now: every race uses DEFAULT.
const BY_RACE := {}


static func random(race: String, gender: String) -> String:
	var lists: Dictionary = BY_RACE.get(race, DEFAULT)
	var pool: Array = lists.get(gender, DEFAULT[gender])
	return pool.pick_random()
