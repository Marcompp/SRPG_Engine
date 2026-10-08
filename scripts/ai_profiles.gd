class_name AIProfiles
extends RefCounted
## Enemy behavior settings. A roster entry's "ai" dictionary is resolved as
## DEFAULTS <- PRESETS[ai.preset] <- the entry's own keys, so a unit can name a
## preset, tweak one, or spell out raw settings.
##
## move:            "charge"   - head for the nearest player, attack whatever scores best
##                  "in_range" - move only to attack something reachable this turn, else stay
##                  "hold"     - never move; attack only from its own tile
##                  "guard"    - stay within guard_radius of its starting tile; drift back when idle
##                  "goto"     - head for `destination`
## attack:          false = never starts a fight (it still counters)
## wake:            while asleep the unit uses `move`; the first condition met wakes it for
##                  good and it switches to `awake_move`. Conditions (any subset):
##                  radius (player within N tiles), in_threat (player inside its attack reach),
##                  turn (enemy phase >= N), attacked (a player targeted it),
##                  group (anyone sharing this group name woke up)
## targeting:       "damage" (expected damage), "kill" (strongly prefer likely kills),
##                  "weakest" (lowest current HP)
## priority:        unit names that get a targeting bonus
## caution:         weight on expected counter damage (0 = reckless)
## retreat_below:   HP fraction that starts a retreat (0 = never)
## retreat_until:   HP fraction at which it returns to normal
## retreat_to:      "healer_or_tile", "healer", "tile" (healing terrain) or "away" (from players)
## retreat_attacks: whether it still attacks while retreating
## loot:            heads for the nearest intact village or chest; burns the village or
##                  takes the chest's item when it gets there (then `move` as usual)

const DEFAULTS := {
	"move": "charge",
	"guard_radius": 3,
	"destination": Vector2i(-1, -1),
	"attack": true,
	"wake": {},
	"awake_move": "charge",
	"targeting": "damage",
	"priority": [],
	"caution": 0.5,
	"retreat_below": 0.0,
	"retreat_until": 1.0,
	"retreat_to": "healer_or_tile",
	"retreat_attacks": false,
	"loot": false,
}

## Classic Fire Emblem enemy archetypes.
const PRESETS := {
	"charger": {},
	"ambusher": {"move": "in_range"},
	"boss": {"move": "hold", "caution": 0.0},
	"turret": {"move": "hold"},
	"sentry": {"move": "guard", "guard_radius": 3},
	"sleeper": {"move": "hold", "wake": {"in_threat": true, "attacked": true}},
	"reinforcement": {"move": "hold", "wake": {"turn": 3}},
	"coward": {"retreat_below": 0.5},
	"thief": {"move": "goto", "attack": false, "loot": true},
}


static func resolve(ai: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate(true)
	if ai.has("preset"):
		result.merge(PRESETS[ai.preset].duplicate(true), true)
	for key in ai:
		if key != "preset":
			result[key] = ai[key]
	return result
