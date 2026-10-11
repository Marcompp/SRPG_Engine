class_name Factions
extends RefCounted
## The sides of a battle (Unit.Team) and who fights whom (design: docs/factions.md).
## Hostility is one-way: hostile(a, b) means side a attacks side b. Relations start
## from DEFAULT_HOSTILE, a level's "relations" can override a side's list
## ({"other": ["enemy"]}), and events can change them mid-battle. They're per battle
## (reset when one loads) and saved with it.

const PLAYER := Unit.Team.PLAYER
const ENEMY := Unit.Team.ENEMY
const ALLY := Unit.Team.ALLY
const OTHER := Unit.Team.OTHER
const NEUTRAL := Unit.Team.NEUTRAL

## Phase order; sides with no units skip theirs (the enemy phase always runs, for
## reinforcements).
const PHASE_ORDER: Array[Unit.Team] = [PLAYER, ALLY, ENEMY, OTHER, NEUTRAL]
## Keys used in level data and events ("== turn 3, ally ==", "team": "other").
const KEYS := {PLAYER: "player", ALLY: "ally", ENEMY: "enemy", OTHER: "other", NEUTRAL: "neutral"}
const NAMES := {PLAYER: "Player", ALLY: "Ally", ENEMY: "Enemy", OTHER: "Other", NEUTRAL: "Neutral"}
## Colors work as keys too ("== turn 3, green ==", "@side Varga, purple").
const ALIASES := {"blue": PLAYER, "green": ALLY, "red": ENEMY, "purple": OTHER, "yellow": NEUTRAL}
## Level roster lists for each side.
const ROSTERS := {"players": PLAYER, "allies": ALLY, "enemies": ENEMY, "others": OTHER, "neutrals": NEUTRAL}
const COLORS := {PLAYER: Color("3a6fd8"), ALLY: Color("3aa848"), ENEMY: Color("d84a3a"), OTHER: Color("9a4ad8"),
	NEUTRAL: Color("d0a830")}
const BANNER_COLORS := {PLAYER: Color("2850b0"), ALLY: Color("28803a"), ENEMY: Color("b02828"), OTHER: Color("6a2ab0"),
	NEUTRAL: Color("a08018")}
## Who each side attacks by default. The player can attack neutrals (provoking them),
## but neutrals attack nobody.
const DEFAULT_HOSTILE := {
	PLAYER: [ENEMY, OTHER, NEUTRAL],
	ALLY: [ENEMY, OTHER],
	ENEMY: [PLAYER, ALLY, OTHER, NEUTRAL],
	OTHER: [PLAYER, ALLY, ENEMY, NEUTRAL],
	NEUTRAL: [],
}

## {side: [sides it's hostile to]} for the current battle.
static var relations := {}


## Default relations, then the level's overrides.
static func reset(level: Dictionary = {}) -> void:
	relations = {}
	for side in DEFAULT_HOSTILE:
		relations[side] = DEFAULT_HOSTILE[side].duplicate()
	var overrides: Dictionary = level.get("relations", {})
	for key: String in overrides:
		var foes: Array = []
		for foe_key: String in overrides[key]:
			foes.append(from_key(foe_key))
		relations[from_key(key)] = foes


## Whether side `a` attacks side `b`.
static func hostile(a: Unit.Team, b: Unit.Team) -> bool:
	if relations.is_empty():
		reset()
	return a != b and relations[a].has(b)


## Neither side is hostile to the other (the same side, or allies like player and
## ally): they can move through each other.
static func friendly(a: Unit.Team, b: Unit.Team) -> bool:
	return not hostile(a, b) and not hostile(b, a)


static func set_hostile(a: Unit.Team, b: Unit.Team, on: bool) -> void:
	if relations.is_empty():
		reset()
	if on and not relations[a].has(b) and a != b:
		relations[a].append(b)
	elif not on:
		relations[a].erase(b)


static func key(side: Unit.Team) -> String:
	return KEYS[side]


## The side for a key ("ally") or color ("green"), or -1 for an unknown one.
static func from_key(text: String) -> int:
	for side in KEYS:
		if KEYS[side] == text:
			return side
	return ALIASES.get(text, -1)


## Relations as plain data for a save (keys as strings, so they survive any format).
static func to_save() -> Dictionary:
	var data := {}
	for side in relations:
		data[KEYS[side]] = relations[side].map(func(s): return KEYS[s])
	return data


static func from_save(data: Dictionary) -> void:
	reset()
	for key_text: String in data:
		relations[from_key(key_text)] = data[key_text].map(func(k): return from_key(k))
