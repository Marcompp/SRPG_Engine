extends "res://tests/test_base.gd"
## The data files (data/*.cfg, read by GameData): how they load, and that every name
## one file uses for another's entries (skills, items, statuses, classes...) exists.


func test_data_loads_like_constants() -> void:
	check(Weapons.DATA.is_read_only(), "tables are read-only")
	check(Weapons.DATA["Iron Bow"].is_read_only() and Weapons.DATA["Iron Bow"].effective.is_read_only(),
		"down to their nested values")
	check(Levels.DATA["river_crossing"].players[0].is_read_only(), "maps too")
	check(Statuses.DATA["Poison"].color is Color and BattleMap.TERRAIN["."].color is Color, "hex colors load as Colors")
	check(Classes.DATA["Swordsman"].learn.has(10), "int keys stay ints")
	check(typeof(Weapons.DATA["Iron Sword"].mt) == TYPE_INT and typeof(BattleMap.TERRAIN["="].cost["*"]) == TYPE_FLOAT,
		"ints stay ints and floats stay floats")
	check(Levels.DATA["river_crossing"].players[0].cell is Vector2i, "cells load as Vector2i")
	check_eq(Levels.DATA.keys(), Array(Levels.ORDER), "maps load in index order")
	check_eq(Chapters.DATA.keys().slice(0, Chapters.ORDER.size()), Array(Chapters.ORDER),
		"the first campaign's chapters load in its order")
	for campaign: String in Chapters.CAMPAIGNS:
		var info: Dictionary = Chapters.CAMPAIGNS[campaign]
		check(info.has("name") and not info.chapters.is_empty(), "campaign %s: a name and chapters" % campaign)
		for chapter: String in info.chapters:
			check(Chapters.DATA.has(chapter) and not Levels.DATA.has(chapter),
				"campaign %s: chapter %s loads, and isn't also a test map's id" % [campaign, chapter])


func test_data_references_exist() -> void:
	var skill := func(name: String, where: String) -> void:
		check(Skills.DATA.has(name), "%s: unknown skill %s" % [where, name])
	var item := func(name: String, where: String) -> void:
		check(Weapons.DATA.has(name) or Items.CONSUMABLES.has(name), "%s: unknown item %s" % [where, name])
	var status := func(name: String, where: String) -> void:
		check(Statuses.DATA.has(name), "%s: unknown status %s" % [where, name])
	for id: String in Classes.DATA:
		var c: Dictionary = Classes.DATA[id]
		for s: String in c.get("skills", []) + c.get("learn", {}).values():
			skill.call(s, "class " + id)
	for id: String in Classes.DATA:
		var icon: String = Classes.DATA[id].get("icon", "")
		check(icon == "" or ClassIcon.ICONS.has(icon), "class %s: unknown icon %s" % [id, icon])
	for id: String in ClassIcon.ICONS:
		var rows: Array = ClassIcon.ICONS[id].pixels
		check(rows.all(func(r: String) -> bool: return r.length() == rows[0].length() \
			and r.replace("#", "").replace(".", "") == ""), "icon %s: equal rows of # and ." % id)
	for id: String in Races.DATA:
		var r: Dictionary = Races.DATA[id]
		for s: String in r.get("skills", []):
			skill.call(s, "race " + id)
		for ban: String in r.get("banned", []):
			check(ban == "mounted" or BattleMap.MOVE_TYPES.has(ban), "race %s: unknown ban %s" % [id, ban])
		for m: String in r.get("only", []):
			check(BattleMap.MOVE_TYPES.has(m), "race %s: unknown move type %s" % [id, m])
		for key: String in r.get("caps", {}).keys() + r.get("growths", {}).keys():
			check(Experience.STATS.has(key), "race %s: unknown stat %s" % [id, key])
		for g: String in r.get("gender_ratio", {}):
			check(Unit.GENDERS.has(g), "race %s: unknown gender %s" % [id, g])
		for key: String in r:
			check(key in ["tags", "skills", "amphibious", "banned", "only", "caps", "growths", "gender_ratio",
				"description"], "race %s: unknown key %s" % [id, key])
	for id: String in Weapons.DATA:
		var w: Dictionary = Weapons.DATA[id]
		for s: String in w.get("skills", []):
			skill.call(s, "weapon " + id)
		if w.has("inflict"):
			status.call(w.inflict.status, "weapon " + id)
	for id: String in Items.CONSUMABLES:
		var it: Dictionary = Items.CONSUMABLES[id]
		for s: String in it.get("skills", []) + ([it.skill] if it.has("skill") else []):
			skill.call(s, "item " + id)
		if it.has("cures"):
			status.call(it.cures, "item " + id)
	for id: String in Spells.DATA:
		var sp: Dictionary = Spells.DATA[id]
		if sp.has("inflict"):
			status.call(sp.inflict.status, "spell " + id)
		if sp.has("terraform"):
			check(BattleMap.TERRAIN.has(sp.terraform), "spell %s: unknown terrain %s" % [id, sp.terraform])
	for id: String in Items.PRICES:
		item.call(id, "prices")
	for id: String in Shop.DEFAULT_STOCK:
		check(Items.cost(id) > 0, "default shop stock: %s has a price" % id)
	for foot: String in Mounts.MOUNTED_CLASS:
		check(Classes.DATA.has(foot) and Classes.DATA.has(Mounts.MOUNTED_CLASS[foot]),
			"mounted_class: %s -> %s are classes" % [foot, Mounts.MOUNTED_CLASS[foot]])
	for mounted: String in Mounts.DISPLAY:
		check(Classes.DATA.has(mounted), "mount display: unknown class %s" % mounted)
		for species: String in Mounts.DISPLAY[mounted]:
			check(Mounts.SPECIES.has(species), "mount display: unknown species %s" % species)
	for key: String in BattleMap.TERRAIN:
		var t: Dictionary = BattleMap.TERRAIN[key]
		for m: String in t.cost:
			check(m == "*" or BattleMap.MOVE_TYPES.has(m), "terrain %s: unknown move type %s" % [key, m])
		if t.has("breakable"):
			check(BattleMap.TERRAIN.has(t.breakable.becomes), "terrain %s: becomes unknown terrain" % key)
	for preset: String in AIProfiles.PRESETS:
		for k: String in AIProfiles.PRESETS[preset]:
			check(AIProfiles.DEFAULTS.has(k), "AI preset %s: unknown setting %s" % [preset, k])
	for id: String in Levels.DATA.keys() + Chapters.DATA.keys():
		_check_map(id, skill, item)


## A map's rosters (every side, recruits, reinforcements) and objects.
func _check_map(id: String, skill: Callable, item: Callable) -> void:
	var level := Levels.get_level(id)
	var roster: Array = level.get("recruits", [])
	for key: String in Factions.ROSTERS:
		roster += level.get(key, [])
	for wave: Dictionary in level.get("reinforcements", []):
		roster += wave.units
	roster += level.get("event_units", {}).values()
	for u: Dictionary in roster:
		var where := "%s: %s" % [id, u.get("name", "?")]
		for it: String in u.get("items", []):
			item.call(it, where)
		for sp: String in u.get("spells", []):
			check(Spells.DATA.has(sp), "%s: unknown spell %s" % [where, sp])
		for s: String in u.get("skills", []):
			skill.call(s, where)
		if u.has("ai") and u.ai.has("preset"):
			check(AIProfiles.PRESETS.has(u.ai.preset), "%s: unknown AI preset %s" % [where, u.ai.preset])
		if u.has("mount"):
			check(Mounts.SPECIES.has(u.mount.species), "%s: unknown mount species" % where)
	for o: Dictionary in level.get("objects", []):
		for it: String in ([o.item] if o.has("item") else []) + o.get("stock", []):
			item.call(it, "%s: %s" % [id, o.type])
