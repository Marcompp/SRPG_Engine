class_name BattleEvents
extends Node
## Map events: dialogue and cutscenes (design: docs/events.md, format: EventScript).
## Loads the map's events/<map id>.txt plus any events in the level data, fires
## them on their triggers and runs their scripts. The battle waits meanwhile, in
## the DIALOGUE state (Z advances, S skips the rest of the scene).

const EVENTS_DIR := "res://events/"

var battle: Battle
## Every event of this map (see EventScript for the shape).
var events: Array = []
## Indices of events that already ran (once-only events don't run again).
var fired: Array = []
## Flags set by @flag, read by "if"/"unless" options.
var flags := {}
## Set by the skip key: the rest of the scene runs without waiting.
var skipping := false
## Which speaker spoke last (for picking portrait sides).
var _last_side := 1


func load_for(level_id: String) -> void:
	events = EventScript.load_file(EVENTS_DIR + level_id + ".txt")
	events.append_array(Levels.get_level(level_id).get("events", []))
	fired = []
	flags = {}


## Adds events written in the text format (tests, tools).
func load_text(text: String) -> Array:
	var result := EventScript.parse(text)
	events.append_array(result.events)
	return result.errors


# --- Triggers ------------------------------------------------------------------------

func on_start() -> void:
	await _fire(func(e): return e.trigger == "start")


func on_turn(turn: int, phase: String) -> void:
	var test := func(e: Dictionary) -> bool:
		var event_phase: String = e.args[1] if e.args.size() > 1 else "player"
		return e.trigger == "turn" and e.args[0] == turn and event_phase == phase
	await _fire(test)


## Units `u` can Talk to: adjacent, with a talk event naming `u` first.
func talk_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for i in events.size():
		var e: Dictionary = events[i]
		if e.trigger != "talk" or e.args[0] != u.unit_name or not _ready_to_run(i):
			continue
		for other in battle.units():
			if other.unit_name == e.args[1] and BattleMap.distance(u.cell, other.cell) == 1 and not result.has(other):
				result.append(other)
	return result


func run_talk(a: Unit, b: Unit) -> void:
	var test := func(e: Dictionary) -> bool:
		return e.trigger == "talk" and e.args[0] == a.unit_name and e.args[1] == b.unit_name
	await _fire(test, true)


## Before a fight: "battle X" events for either side, "battle X, Y" for this pair.
func before_battle(a: Unit, b: Unit) -> void:
	var names := [a.unit_name, b.unit_name]
	var test := func(e: Dictionary) -> bool:
		if e.trigger != "battle" or not names.has(e.args[0]):
			return false
		return e.args.size() == 1 or (names.has(e.args[1]) and e.args[0] != e.args[1])
	await _fire(test)


func on_death(u: Unit) -> void:
	await _fire(func(e): return e.trigger == "death" and e.args[0] == u.unit_name)


## A unit ended its move on `u.cell`. Returns whether a scene played.
func on_area(u: Unit) -> bool:
	var team := "player" if u.team == Unit.Team.PLAYER else "enemy"
	var test := func(e: Dictionary) -> bool:
		if e.trigger != "area" or not e.args[0].has(u.cell):
			return false
		var who: String = e.args[1]
		return who == "" or who == u.unit_name or who == team
	return await _fire(test)


func on_visit(cell: Vector2i) -> void:
	await _fire(func(e): return e.trigger == "visit" and e.args[0][0] == cell)


## The map was won ("victory") or lost ("defeat"), before the end screen.
func on_end(result: String) -> void:
	await _fire(func(e): return e.trigger == result)


func _ready_to_run(i: int) -> bool:
	var e: Dictionary = events[i]
	if fired.has(i) and not e.repeat:
		return false
	for flag in e["if"]:
		if not flags.has(flag):
			return false
	for flag in e.unless:
		if flags.has(flag):
			return false
	return true


## Runs every eligible event matching `test`, in file order (`first_only`: just one).
## Returns whether any ran.
func _fire(test: Callable, first_only := false) -> bool:
	var ran := false
	for i in events.size():
		if test.call(events[i]) and _ready_to_run(i):
			if not fired.has(i):
				fired.append(i)
			ran = true
			await run(events[i].script)
			if first_only:
				break
	return ran


# --- Running scripts --------------------------------------------------------------------

## Runs a script (command arrays, see EventScript). Input switches to the dialogue
## controls meanwhile, and goes back to what it was after.
func run(script: Array) -> void:
	if script.is_empty():
		return
	var previous := battle.state
	battle.state = Battle.State.DIALOGUE
	skipping = false
	battle.ui.hide_info()
	for command in script:
		await _run_command(command)
	battle.ui.dialogue.close()
	skipping = false
	battle.state = previous


## The skip key: finish the scene without waiting (commands still take effect).
func skip() -> void:
	skipping = true
	battle.ui.dialogue.advance()
	battle.ui.dialogue.advance()


func _run_command(c: Array) -> void:
	match c[0]:
		"say":
			if skipping:
				return
			var speaker := _speaker(c[1])
			await battle.ui.dialogue.say(speaker, _side_for(speaker.name), c[2])
		"narrate":
			if not skipping:
				await battle.ui.dialogue.say({}, 0, c[1])
		"move":
			var u := find_unit(c[1])
			if u == null:
				return
			battle.ui.dialogue.hide_box()
			var cell: Vector2i = c[2]
			var path: Array[Vector2i] = []
			var reach: Dictionary = battle.map.get_reachable(u, battle.units(), 999.0)
			if reach.parents.has(cell):
				path = battle.map.build_path(reach.parents, u.cell, cell)
			if skipping or path.is_empty():
				u.set_cell(cell)
			else:
				await u.move_along(path)
		"spawn":
			var data: Dictionary = Levels.get_level(Levels.selected).get("event_units", {}).get(c[1], {})
			if data.is_empty():
				push_error("event: no event_units entry for %s" % c[1])
				return
			var team := Unit.Team.PLAYER if data.get("team", "enemy") == "player" else Unit.Team.ENEMY
			battle.units_root.add_child(Unit.create(data.get("name", c[1]), team, c[2], data))
			battle.refresh_threat()
		"remove":
			var u := find_unit(c[1])
			if u:
				battle.units_root.remove_child(u)
				u.queue_free()
				battle.refresh_threat()
		"recruit":
			var u := find_unit(c[1])
			if u:
				recruit(u)
		"give":
			var u := find_unit(c[1])
			if u:
				u.popup(battle.actions.give_item(u, c[2]), Color.GOLD)
		"camera":
			battle.cursor.cell = c[1]
			if skipping:
				battle.camera.snap(c[1])
			else:
				await battle.camera.settle()
		"wait":
			if not skipping:
				await get_tree().create_timer(c[1]).timeout
		"flag":
			flags[c[1]] = true
		"banner":
			if not skipping:
				battle.ui.dialogue.hide_box()
				await battle.ui.show_banner(c[1], Color("4a3a8a"))


## The unit `u` switches to the player's side for good (it joins the campaign army
## when the chapter is won). It can't act until the next player phase.
func recruit(u: Unit) -> void:
	u.team = Unit.Team.PLAYER
	u.has_acted = true
	battle.marked.erase(u)
	u.biography.append("Joined the army at %s." % battle.actions.map_title())
	u.popup("Joined!", Color.GOLD)
	u.queue_redraw()
	battle.refresh_threat()


## A unit on the map by name (any side), or null.
func find_unit(unit_name: String) -> Unit:
	for u in battle.units():
		if u.unit_name == unit_name:
			return u
	return null


## Portrait data for a speaker: a unit's colors and token letter, or a neutral
## portrait for labels with no unit ("Messenger").
func _speaker(speaker_name: String) -> Dictionary:
	for u in battle.all_units():
		if u.unit_name == speaker_name:
			var color := Unit.PLAYER_COLOR if u.team == Unit.Team.PLAYER else Unit.ENEMY_COLOR
			return {"name": speaker_name, "color": color, "letter": u.token_letter()}
	return {"name": speaker_name, "color": Color(0.45, 0.45, 0.5), "letter": speaker_name.left(1)}


## A speaker keeps the side it already has; a new one takes the side opposite
## whoever spoke last.
func _side_for(speaker_name: String) -> int:
	var slots: Array = battle.ui.dialogue.slots
	for side in 2:
		if slots[side].get("name", "") == speaker_name:
			_last_side = side
			return side
	var side := 1 - _last_side if not slots[0].is_empty() or not slots[1].is_empty() else 0
	_last_side = side
	return side
