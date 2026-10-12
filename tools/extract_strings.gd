extends SceneTree
## Collects every translatable text into locale/messages.pot, the template that
## translations (.po files) are made from. Run from the project folder:
##   godot --headless --path . --script res://tools/extract_strings.gd
## What counts as translatable: docs/translation.md. In short, from scripts/*.gd:
## the first argument of tr(), TranslationServer.translate() and Text.entry(), the
## two of tr_n() and TranslationServer.translate_plural(), and every string value on
## a statement marked with a "# i18n" comment (dictionary keys and lowercase ids like
## "game_speed" are left out); from events/*.txt: dialogue, speakers, @narrate and
## @banner text.

const SCRIPTS_DIR := "res://scripts/"
const EVENTS_DIR := "res://events/"
const DATA_DIR := "res://data/"
## Data files whose entry (section) names are shown to the player.
const NAMED_DATA: Array[String] = ["weapons", "items", "classes", "races", "spells", "skills", "statuses",
	"mount_species"]
## Display text keys of a data entry (its top-level keys only: a roster's unit "name"
## isn't one).
const DATA_TEXT_KEYS: Array[String] = ["name", "description", "cured_text"]
const OUTPUT := "res://locale/messages.pot"

const _SINGLE := ["tr", "TranslationServer.translate", "Text.entry"]
const _PLURAL := ["tr_n", "TranslationServer.translate_plural"]


func _init() -> void:
	var messages := collect()
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(to_pot(messages))
	file.close()
	print("%d texts -> %s" % [messages.size(), OUTPUT])
	quit()


## {text: {"plural": String, "refs": ["scripts/ui.gd:12"...], "notes": [...]}}, in
## the order they're first found.
static func collect() -> Dictionary:
	var messages := {}
	for path in _files(SCRIPTS_DIR, "gd"):
		for found in scan_script(FileAccess.get_file_as_string(path)):
			_add(messages, found, path)
	for path in _files(EVENTS_DIR, "txt"):
		for found in scan_events(FileAccess.get_file_as_string(path)):
			_add(messages, found, path)
	for path in _files_deep(DATA_DIR, "cfg"):
		var file := path.trim_prefix(DATA_DIR).get_basename()
		for found in scan_data(FileAccess.get_file_as_string(path), NAMED_DATA.has(file), file == "mounts"):
			_add(messages, found, path)
	return messages


## Texts in GDScript source: [{"text", "plural", "line"}].
static func scan_script(source: String) -> Array:
	var result := []
	for statement in _statements(source):
		var code: String = statement.code
		var strings: Array = statement.strings
		var taken := {}
		for fn in _PLURAL:
			for m in _calls(fn, 2).search_all(code):
				var i := m.get_string(1).to_int()
				var j := m.get_string(2).to_int()
				result.append({"text": strings[i].text, "plural": strings[j].text, "line": strings[i].line})
				taken[i] = true
				taken[j] = true
		for fn in _SINGLE:
			for m in _calls(fn, 1).search_all(code):
				var i := m.get_string(1).to_int()
				if not taken.has(i):
					result.append({"text": strings[i].text, "line": strings[i].line})
					taken[i] = true
		if not _marked(statement.comment):
			continue
		for i in strings.size():
			if taken.has(i) or _is_key(code, i) or _is_id(strings[i].text):
				continue
			result.append({"text": strings[i].text, "line": strings[i].line})
	return result


## Texts in an event file: [{"text", "line", "note"}].
static func scan_events(source: String) -> Array:
	var result := []
	var lines := source.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("=="):
			continue
		var c := EventScript._command(line, i + 1, [])
		if c.is_empty():
			continue
		match c[0]:
			"say":
				result.append({"text": c[1], "line": i + 1, "note": "speaker (a unit's name is not translated)"})
				result.append({"text": c[2], "line": i + 1})
			"narrate", "banner":
				result.append({"text": c[1], "line": i + 1})
	return result


## Texts in a data file: [{"text", "line"}]. `named`: its entry names are display
## names (NAMED_DATA). `mounts`: its [display] section holds mounted class names.
static func scan_data(source: String, named: bool, mounts := false) -> Array:
	var result := []
	var section := ""
	var header := RegEx.create_from_string("^\\[(.+)\\]$")
	var field := RegEx.create_from_string("^(\\w+|\"(?:[^\"\\\\]|\\\\.)*\")=(.*)$")
	var lines := source.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges(false, true)
		var m := header.search(line)
		if m:
			section = m.get_string(1)
			if named:
				result.append({"text": section, "line": i + 1})
			continue
		m = field.search(line)
		if not m:
			continue
		if DATA_TEXT_KEYS.has(m.get_string(1)):
			var value = str_to_var(m.get_string(2))
			if value is String:
				result.append({"text": value, "line": i + 1})
		elif mounts and section == "display":
			var names = str_to_var(m.get_string(2))
			if names is Dictionary:
				for display_name in names.values():
					result.append({"text": display_name, "line": i + 1})
	return result


## The gettext template.
static func to_pot(messages: Dictionary) -> String:
	var out := PackedStringArray([
		"# Translatable text. Generated by tools/extract_strings.gd: don't edit by hand.",
		"msgid \"\"",
		"msgstr \"\"",
		"\"Content-Type: text/plain; charset=UTF-8\\n\"",
		"",
	])
	for text: String in messages:
		var m: Dictionary = messages[text]
		for note in m.notes:
			out.append("#. " + note)
		out.append("#: " + " ".join(m.refs))
		out.append("msgid " + _quote(text))
		if m.plural != "":
			out.append("msgid_plural " + _quote(m.plural))
			out.append("msgstr[0] \"\"")
			out.append("msgstr[1] \"\"")
		else:
			out.append("msgstr \"\"")
		out.append("")
	return "\n".join(out)


# --- Helpers ----------------------------------------------------------------------

static func _add(messages: Dictionary, found: Dictionary, path: String) -> void:
	var text: String = found.text
	if text.strip_edges() == "":
		return
	if not messages.has(text):
		messages[text] = {"plural": "", "refs": [], "notes": []}
	var m: Dictionary = messages[text]
	m.refs.append("%s:%d" % [path.trim_prefix("res://"), found.line])
	if found.get("plural", "") != "":
		m.plural = found.plural
	if found.has("note") and not m.notes.has(found.note):
		m.notes.append(found.note)


static func _files(dir: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == extension:
			result.append(dir + f)
	result.sort()
	return result


## Files with `extension` in `dir` and every folder under it.
static func _files_deep(dir: String, extension: String) -> Array[String]:
	var result := _files(dir, extension)
	for sub in DirAccess.get_directories_at(dir):
		result.append_array(_files_deep(dir + sub + "/", extension))
	return result


## `fn("§0§"` (and `, "§1§"` for plurals) in a statement's code, where §N§ stands
## for its Nth string literal.
static func _calls(fn: String, count: int) -> RegEx:
	var pattern := "(?<![\\w.])" + fn.replace(".", "\\.") + "\\(\\s*§(\\d+)§"
	if count == 2:
		pattern += "\\s*,\\s*§(\\d+)§"
	return RegEx.create_from_string(pattern)


static func _marked(comment: String) -> bool:
	return RegEx.create_from_string("\\bi18n\\b").search(comment) != null


## Whether string N is a dictionary key ("label": ...).
static func _is_key(code: String, i: int) -> bool:
	var at := code.find("§%d§" % i)
	return code.substr(at + str(i).length() + 2).strip_edges().begins_with(":")


## Lowercase ids ("game_speed", "x4"), and strings with no words ("", "--", "%d").
static func _is_id(text: String) -> bool:
	var words := RegEx.create_from_string("%[-+0-9.]*[a-z]|\\{\\w+\\}").sub(text, "", true)
	return RegEx.create_from_string("^[a-z0-9_]*$").search(text) != null \
		or RegEx.create_from_string("[A-Za-z]").search(words) == null


## Splits GDScript source into statements: lines joined while brackets are open or a
## line ends in "\". Each is {"code": the code with its strings replaced by §N§,
## "strings": [{"text", "line"}], "comment": its comments joined}.
static func _statements(source: String) -> Array:
	var result := []
	var code := ""
	var strings := []
	var comment := ""
	var depth := 0
	var line := 1
	var i := 0
	var n := source.length()
	while i < n:
		var ch := source[i]
		if ch == "\"" or ch == "'":
			var start := i
			var quote := ch
			i += 1
			while i < n and source[i] != quote and source[i] != "\n":
				if source[i] == "\\":
					i += 1
				i += 1
			var literal := source.substr(start, i - start + 1)
			if quote == "'":
				literal = "\"" + literal.substr(1, literal.length() - 2).replace("\\'", "'").replace("\"", "\\\"") + "\""
			code += "§%d§" % strings.size()
			strings.append({"text": str(str_to_var(literal)), "line": line})
			i += 1
			continue
		if ch == "#":
			var end := source.find("\n", i)
			if end < 0:
				end = n
			comment += " " + source.substr(i, end - i)
			i = end
			continue
		if ch in "([{":
			depth += 1
		elif ch in ")]}":
			depth = maxi(0, depth - 1)
		if ch == "\n":
			line += 1
			if depth == 0 and not code.strip_edges().ends_with("\\"):
				result.append({"code": code, "strings": strings, "comment": comment})
				code = ""
				strings = []
				comment = ""
				i += 1
				continue
		code += ch
		i += 1
	result.append({"code": code, "strings": strings, "comment": comment})
	return result


static func _quote(text: String) -> String:
	return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t") + "\""
