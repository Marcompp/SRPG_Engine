class_name EventScript
extends RefCounted
## Parses a map's event file (events/<map id>.txt) into events. Design: docs/events.md.
##
## An event starts with a header line, then its script, one beat per line:
##
##   # Comments start with "#"; blank lines are ignored.
##   == start ==                       before the first player phase
##   == turn 3 ==                      start of turn 3's player phase
##   == turn 3, enemy ==               start of turn 3's enemy phase
##   == talk Lord, Thief ==            Lord gets a Talk command next to Thief
##   == battle Bandit King ==          before any fight involving the Bandit King
##   == battle Lord, Bandit King ==    before a fight between these two
##   == death Rider ==                 when Rider falls
##   Options after "|": "repeat" (run every time), "if <flag>", "unless <flag>":
##   == turn 2 | if bridge_held ==
##
##   Lord: We hold the bridge.         a line of dialogue (unit name or any label)
##   @narrate The river runs high.     text with no speaker
##   @move Bandit King (10, 4)         walk a unit to a cell
##   @spawn Raider (12, 3)             add a unit from the level's "event_units"
##   @remove Thief                     take a unit off the map
##   @recruit Thief                    a unit joins the player's side
##   @give Lord, Silver Sword          an item for a unit
##   @camera (10, 4)                   pan the view
##   @wait 0.5                         pause, in seconds
##   @flag bridge_held                 set a flag (see "if"/"unless")
##   @banner Reinforcements!           a banner
##
## Each event is {"trigger", "args", "repeat", "if": [flags], "unless": [flags],
## "script": [command arrays], "line"}. Commands are arrays: ["say", speaker, text],
## ["narrate", text], ["move", unit, cell], ["spawn", name, cell], ["remove", unit],
## ["recruit", unit], ["give", unit, item], ["camera", cell], ["wait", seconds],
## ["flag", name], ["banner", text]. A level's "events" entry can hold events in
## that same shape (with "script" written as command arrays) for anything the text
## can't express.

const TRIGGERS: Array[String] = ["start", "turn", "talk", "battle", "death"]
const COMMANDS: Array[String] = ["say", "narrate", "move", "spawn", "remove", "recruit", "give", "camera",
	"wait", "flag", "banner"]


## Events in the file at `path`, or [] if there's none. Errors are pushed (and
## returned by parse()).
static func load_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var result := parse(FileAccess.get_file_as_string(path))
	for e in result.errors:
		push_error("%s: %s" % [path, e])
	return result.events


## {"events": [...], "errors": ["line N: ..."]}.
static func parse(text: String) -> Dictionary:
	var events := []
	var errors := []
	var current: Dictionary = {}
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		var n := i + 1
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("==") and line.ends_with("=="):
			current = _header(line.substr(2, line.length() - 4).strip_edges(), n, errors)
			if not current.is_empty():
				events.append(current)
			continue
		if current.is_empty():
			errors.append("line %d: script before any \"== trigger ==\" header" % n)
			continue
		var command := _command(line, n, errors)
		if not command.is_empty():
			current.script.append(command)
	return {"events": events, "errors": errors}


static func _header(text: String, n: int, errors: Array) -> Dictionary:
	var parts := text.split("|")
	var head := parts[0].strip_edges()
	var word := head.get_slice(" ", 0)
	if not TRIGGERS.has(word):
		errors.append("line %d: unknown trigger \"%s\"" % [n, word])
		return {}
	var rest := head.substr(word.length()).strip_edges()
	var args: Array = []
	for a in rest.split(","):
		if a.strip_edges() != "":
			args.append(a.strip_edges())
	var e := {"trigger": word, "args": args, "repeat": false, "if": [], "unless": [], "script": [], "line": n}
	match word:
		"turn":
			if args.is_empty() or not args[0].is_valid_int():
				errors.append("line %d: \"turn\" needs a turn number" % n)
				return {}
			args[0] = args[0].to_int()
			if args.size() > 1 and not args[1] in ["player", "enemy"]:
				errors.append("line %d: turn phase must be player or enemy" % n)
				return {}
		"talk":
			if args.size() != 2:
				errors.append("line %d: \"talk\" needs two unit names" % n)
				return {}
		"battle":
			if args.size() < 1 or args.size() > 2:
				errors.append("line %d: \"battle\" needs one or two unit names" % n)
				return {}
		"death":
			if args.size() != 1:
				errors.append("line %d: \"death\" needs a unit name" % n)
				return {}
	for option in parts.slice(1):
		var o := option.strip_edges()
		if o == "repeat":
			e.repeat = true
		elif o.begins_with("if "):
			e["if"].append(o.substr(3).strip_edges())
		elif o.begins_with("unless "):
			e.unless.append(o.substr(7).strip_edges())
		else:
			errors.append("line %d: unknown option \"%s\"" % [n, o])
	return e


static func _command(line: String, n: int, errors: Array) -> Array:
	if not line.begins_with("@"):
		var colon := line.find(":")
		if colon <= 0:
			errors.append("line %d: expected \"Speaker: text\" or an @command" % n)
			return []
		return ["say", line.substr(0, colon).strip_edges(), line.substr(colon + 1).strip_edges()]
	var word := line.substr(1).get_slice(" ", 0)
	var rest := line.substr(1 + word.length()).strip_edges()
	match word:
		"narrate", "banner", "flag", "remove", "recruit":
			if rest == "":
				errors.append("line %d: @%s needs an argument" % [n, word])
				return []
			return [word, rest]
		"move", "spawn":
			var cell: Variant = _cell(rest)
			var name := rest.substr(0, rest.find("(")).strip_edges() if rest.contains("(") else ""
			if cell == null or name == "":
				errors.append("line %d: @%s needs a name and a cell, like \"@%s Thief (3, 4)\"" % [n, word, word])
				return []
			return [word, name, cell]
		"camera":
			var cell: Variant = _cell(rest)
			if cell == null:
				errors.append("line %d: @camera needs a cell, like \"@camera (3, 4)\"" % n)
				return []
			return ["camera", cell]
		"wait":
			if not rest.is_valid_float():
				errors.append("line %d: @wait needs seconds" % n)
				return []
			return ["wait", rest.to_float()]
		"give":
			var parts := rest.split(",", false, 1)
			if parts.size() != 2:
				errors.append("line %d: @give needs \"Unit, Item\"" % n)
				return []
			return ["give", parts[0].strip_edges(), parts[1].strip_edges()]
	errors.append("line %d: unknown command @%s" % [n, word])
	return []


## The "(x, y)" at the end of `text`, or null.
static func _cell(text: String) -> Variant:
	var m := RegEx.create_from_string("\\((\\s*-?\\d+)\\s*,\\s*(-?\\d+)\\s*\\)\\s*$").search(text)
	if m == null:
		return null
	return Vector2i(m.get_string(1).strip_edges().to_int(), m.get_string(2).to_int())
