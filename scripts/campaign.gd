class_name Campaign
extends RefCounted
## The campaign: a fixed run of chapters (Chapters.ORDER) played by one army that
## carries levels, EXP and items from map to map.
##
## Permadeath: a unit that falls leaves the army for good. It's kept in `fallen`
## (its data plus where and when) so later mechanics can interact with death.
## Saved to `path` when a campaign starts and after each completed chapter, so a
## lost chapter is retried with the army as it was before it.

static var path := "user://campaign.save"
## True while the battle being played is a campaign chapter.
static var active := false
## Index into Chapters.ORDER of the chapter being prepared or played.
static var chapter := 0
## Unit dictionaries (SaveGame.unit_to_dict), in the order they joined. Unit names
## are unique within a campaign and identify units across chapters.
static var army: Array = []
## Shared item storage: overflow from full inventories, managed in the prep screen.
static var convoy: Array = []
## Fallen units: {"unit": dict, "chapter": chapter name, "turn": n}.
static var fallen: Array = []
## Chapters whose recruits already joined (so a retry doesn't add them twice).
static var recruited: Array = []
## Names of the units chosen in the prep screen for the next battle.
static var deployed: Array = []


static func has_save() -> bool:
	return FileAccess.file_exists(path)


static func start_new() -> void:
	chapter = 0
	army = []
	convoy = []
	fallen = []
	recruited = []
	deployed = []
	add_recruits()
	save()


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var({"version": SaveGame.VERSION, "chapter": chapter, "army": army, "convoy": convoy,
		"fallen": fallen, "recruited": recruited})


## Loads the saved campaign (the state before the current chapter). False if none.
static func load_save() -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var()
	if not data is Dictionary or data.get("version", 0) != SaveGame.VERSION:
		return false
	chapter = data.chapter
	army = data.army
	convoy = data.convoy
	fallen = data.fallen
	recruited = data.recruited
	deployed = []
	return true


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(path)


static func is_complete() -> bool:
	return chapter >= Chapters.ORDER.size()


static func chapter_id() -> String:
	return Chapters.ORDER[chapter]


static func chapter_data() -> Dictionary:
	return Levels.get_level(chapter_id())


## Adds the current chapter's recruits to the army (once per chapter).
static func add_recruits() -> void:
	var id := chapter_id()
	if recruited.has(id):
		return
	recruited.append(id)
	for data in chapter_data().get("recruits", []):
		var u := Unit.create(data.name, Unit.Team.PLAYER, Vector2i.ZERO, data)
		u.biography.append("Joined the army in %s." % chapter_data().name)
		army.append(SaveGame.unit_to_dict(u))
		u.free()


static func army_unit(unit_name: String) -> Dictionary:
	for d in army:
		if d.unit_name == unit_name:
			return d
	return {}


## Lord first, then the rest in army order, up to the chapter's deployment slots.
static func default_deployment() -> Array:
	var slots: int = chapter_data().deploy.size()
	var names := []
	for d in army:
		if d.is_lord:
			names.append(d.unit_name)
	for d in army:
		if not d.is_lord and names.size() < slots:
			names.append(d.unit_name)
	return names


## Called on victory: deployed survivors bring back their levels, EXP and items
## (healed and reset for the next map); units that fell move to `fallen`. Then the
## campaign moves to the next chapter and saves.
static func finish_chapter(battle: Battle) -> void:
	var name: String = chapter_data().name
	var survivors := {}
	for u in battle.all_units():
		if u.team == Unit.Team.PLAYER:
			survivors[u.unit_name] = u
	for death in battle.campaign_deaths:
		var d := army_unit(death.name)
		if d.is_empty():
			continue
		d.biography.append("Fell in %s, turn %d." % [name, death.turn])
		fallen.append({"unit": d, "chapter": name, "turn": death.turn})
		army.erase(d)
	for unit_name in survivors:
		var u: Unit = survivors[unit_name]
		_reset_for_next_map(u)
		var i := army.find(army_unit(unit_name))
		if i >= 0:
			army[i] = SaveGame.unit_to_dict(u)
		else:
			# Recruited during the chapter (see BattleEvents.recruit).
			army.append(SaveGame.unit_to_dict(u))
	chapter += 1
	if not is_complete():
		add_recruits()
	save()


static func can_promote(data: Dictionary) -> bool:
	return data.level >= Classes.PROMOTION_LEVEL and not Classes.promotions(data.unit_class).is_empty()


## Promotes an army unit (prep screen): new class, same level, plus the new class's
## bonus. Returns the gains actually applied (after caps).
static func promote(unit_name: String, new_class: String) -> Dictionary:
	var i := army.find(army_unit(unit_name))
	var u := SaveGame.unit_from_dict(army[i])
	u.set_class(new_class)
	var gains := {}
	var bonus := Classes.promotion_bonus(new_class)
	for key in bonus:
		var prop: String = Experience.STATS[key]
		var before: int = u.get(prop)
		u.set(prop, mini(before + bonus[key], u.stat_cap(key)))
		gains[key] = u.get(prop) - before
	u.hp = u.max_hp
	u.mp = u.max_mp
	u.biography.append("Promoted to %s before %s." % [new_class, chapter_data().name])
	army[i] = SaveGame.unit_to_dict(u)
	u.free()
	return gains


## Moves an item between a unit's inventory and the convoy (prep screen).
static func store_item(unit_name: String, item_index: int) -> void:
	var d := army_unit(unit_name)
	convoy.append(d.items[item_index])
	d.items.remove_at(item_index)


static func take_item(unit_name: String, convoy_index: int) -> bool:
	var d := army_unit(unit_name)
	if d.items.size() >= Unit.MAX_ITEMS:
		return false
	d.items.append(convoy[convoy_index])
	convoy.remove_at(convoy_index)
	return true


static func _reset_for_next_map(u: Unit) -> void:
	u.hp = u.max_hp
	u.mp = u.max_mp
	u.has_acted = false
	u.carrying = null
	u.carried_by = null
	u.passengers.clear()
	u.inspire_bonus = 0
	u.escaped = false
	u.was_attacked = false
	u.retreating = false
