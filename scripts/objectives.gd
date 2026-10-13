class_name Objectives
extends RefCounted
## Map objectives. A level's "objective" dictionary (default {"type": "rout"}):
##   {"type": "rout"}                               defeat every enemy
##   {"type": "boss", "boss": "Name"}               defeat the named enemy
##   {"type": "seize", "cell": Vector2i}            the Lord uses Seize on that tile
##   {"type": "survive", "turns": N}                still standing when turn N ends
##   {"type": "defend", "turns": N, "cell": Vector2i} as survive, but an enemy on the cell loses
##   {"type": "escape", "cells": [Vector2i, ...]}   the Lord uses Escape on an exit tile
## Any type can add "protect": ["Name", ...]: losing if one of those units falls
## (green allies or neutrals to keep alive; units that haven't arrived yet count as fine), and "caught_by": a side key ("neutral",
## "yellow"...): losing if a unit of that side is ever next to the player's Lord (the
## Royal Guard catching a runaway princess; see the "pursuer" AI preset). The danger
## zone shows where they could catch it.
## Losing the Lord always loses. Routing the enemy also wins every type except
## seize and escape (as in Fire Emblem, those need the Lord's command).

const DEFAULT := {"type": "rout"}


static func of(level: Dictionary) -> Dictionary:
	var obj = level.get("objective", DEFAULT)
	return obj if obj is Dictionary else DEFAULT


## Translated.
static func victory_text(obj: Dictionary) -> String:
	match obj.type:
		"boss":
			return TranslationServer.translate("Defeat %s.") % obj.boss
		"seize":
			return TranslationServer.translate("Seize the marked tile with your Lord.")
		"survive":
			return TranslationServer.translate_plural("Survive %d turn.", "Survive %d turns.", obj.turns) % obj.turns
		"defend":
			return TranslationServer.translate_plural("Defend the marked tile for %d turn.",
				"Defend the marked tile for %d turns.", obj.turns) % obj.turns
		"escape":
			return TranslationServer.translate("Escape with your Lord through a marked exit.")
	return TranslationServer.translate("Defeat every enemy.")


## Translated: the ways to lose, joined with ", or ".
static func defeat_text(obj: Dictionary) -> String:
	var ways: Array[String] = [TranslationServer.translate("Your Lord falls")]
	if obj.type == "defend":
		ways.append(TranslationServer.translate("an enemy reaches the marked tile"))
	if obj.has("protect"):
		ways.append(TranslationServer.translate("{units} falls").format({
			"units": TranslationServer.translate(" or ").join(obj.protect)}))
	if obj.has("caught_by"):
		ways.append(TranslationServer.translate("a {side} unit gets next to your Lord").format({
			"side": TranslationServer.translate(Factions.NAMES[Factions.from_key(obj.caught_by)])}))
	return TranslationServer.translate(", or ").join(ways) + "."


## Cells the map marks for the objective (seize tile, defended tile, exits).
static func marked_cells(obj: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match obj.type:
		"seize", "defend":
			result.append(obj.cell)
		"escape":
			result.assign(obj.cells)
	return result


## Whether `u` could Seize from where it stands.
static func can_seize(obj: Dictionary, u: Unit) -> bool:
	return obj.type == "seize" and u.is_lord and u.cell == obj.cell


static func can_escape(obj: Dictionary, u: Unit) -> bool:
	return obj.type == "escape" and obj.cells.has(u.cell)


## "victory", "defeat" or "" for the battle's current state. `turn_over` is true
## right after an enemy phase ends (when survive/defend count a turn as done).
static func result(battle: Battle, turn_over := false) -> String:
	var obj := of(Levels.get_level(Levels.selected))
	if not _lord_alive(battle):
		return "defeat"
	for unit_name: String in obj.get("protect", []):
		if battle.fallen_names.has(unit_name):
			return "defeat"
	if obj.type == "defend":
		for e in battle.threats_to(Unit.Team.PLAYER):
			if e.cell == obj.cell:
				return "defeat"
	if obj.has("caught_by") and is_caught(battle, obj):
		return "defeat"
	if battle.objective_done:
		return "victory"
	# Every unit hostile to the player: red, purple, provoked yellow (see Factions).
	var routed: bool = battle.threats_to(Unit.Team.PLAYER).is_empty()
	match obj.type:
		"seize", "escape":
			return ""
		"boss":
			if routed or not battle.all_units().any(
					func(u: Unit) -> bool: return u.team != Unit.Team.PLAYER and u.unit_name == obj.boss):
				return "victory"
		"survive", "defend":
			if routed or (turn_over and battle.turn >= obj.turns):
				return "victory"
		_:
			if routed:
				return "victory"
	return ""


## Whether a unit of the "caught_by" side stands next to a player Lord on the map. A
## sleeping one (AI "wake", or a status that stops it acting) catches nobody.
static func is_caught(battle: Battle, obj: Dictionary) -> bool:
	for u in catchers(battle, obj):
		if EnemyAI.is_asleep(u) or Statuses.restricts(u, "act"):
			continue
		for lord in battle.units_of(Unit.Team.PLAYER):
			if lord.is_lord and BattleMap.distance(u.cell, lord.cell) == 1:
				return true
	return false


## The units of the objective's "caught_by" side (none without one).
static func catchers(battle: Battle, obj: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	if obj.has("caught_by"):
		result = battle.units_of(Factions.from_key(obj.caught_by))
	return result


## A carried or escaped Lord is still alive, so this looks past units().
static func _lord_alive(battle: Battle) -> bool:
	for u in battle.units_root.get_children():
		if u is Unit and u.hp > 0 and u.team == Unit.Team.PLAYER and u.is_lord:
			return true
	return false
