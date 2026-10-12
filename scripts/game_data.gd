class_name GameData
extends RefCounted
## Reads the game's database: the .cfg files in data/ (format: docs/data.md). Each
## data module (Weapons, Classes, Levels...) loads its tables from here once, when its
## script loads. Tables are read-only, like the constants they replaced.

const DIR := "res://data/"


## Every section of data/<file>.cfg: {section: {key: value}}, in file order.
static func entries(file: String) -> Dictionary:
	var config := _load(file)
	var result := {}
	for section in config.get_sections():
		result[section] = _section(config, section)
	return _frozen(result)


## One section of data/<file>.cfg: {key: value} (empty when it has none).
static func section(file: String, name: String) -> Dictionary:
	var config := _load(file)
	return _frozen(_section(config, name) if config.has_section(name) else {})


## A list of names (a typed Array[String]) kept under `key` in a section.
static func strings(file: String, section_name: String, key: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(section(file, section_name).get(key, []))
	result.make_read_only()
	return result


## A folder of one-file-per-entry data (data/levels/, a campaign's chapters/): {id:
## data}, in the order `ids` lists, or by default the order its index.cfg lists. Each
## entry file holds its keys outside any section.
static func folder(dir: String, ids: Array = []) -> Dictionary:
	var result := {}
	for id: String in ids if not ids.is_empty() else Array(strings(dir + "/index", "", "order")):
		result[id] = _section(_load(dir + "/" + id), "")
	return _frozen(result)


static func _load(file: String) -> ConfigFile:
	var config := ConfigFile.new()
	var err := config.load(DIR + file + ".cfg")
	assert(err == OK, "can't read %s%s.cfg (error %d)" % [DIR, file, err])
	return config


## A section's keys. "color" values are written as hex and read as Colors.
static func _section(config: ConfigFile, name: String) -> Dictionary:
	var result := {}
	for key in config.get_section_keys(name):
		var value = config.get_value(name, key)
		if key == "color" and value is String:
			value = Color(value)
		result[key] = value
	return result


## Makes `value` and everything in it read-only.
static func _frozen(value: Variant) -> Variant:
	if value is Dictionary:
		for v in value.values():
			_frozen(v)
		value.make_read_only()
	elif value is Array:
		for v in value:
			_frozen(v)
		value.make_read_only()
	return value
