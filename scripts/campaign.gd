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
## Starting cells the player arranged with Check Map: {unit name: cell}. Units
## without one take the chapter's free deploy cells in order (see Battle.deploy_army).
static var placement: Dictionary = {}
## True while the prep screen's Check Map shows the chapter's map (Battle formation).
static var checking_map := false
## Mounts nobody is riding (see Mounts); ridden ones live on their rider's record.
static var stable: Array = []


static func has_save() -> bool:
	return FileAccess.file_exists(path)


static func start_new() -> void:
	chapter = 0
	army = []
	convoy = []
	fallen = []
	recruited = []
	stable = []
	clear_deployment()
	add_recruits()
	save()


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var({"version": SaveGame.VERSION, "chapter": chapter, "army": army, "convoy": convoy,
		"fallen": fallen, "recruited": recruited, "stable": stable})


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
	stable = data.get("stable", [])
	# Saves from before mounts: units on the old mounted classes get a mount.
	for i in army.size():
		if not Classes.DATA.has(army[i].unit_class) or (Classes.get_data(army[i].unit_class).get("mounted", false)
				and army[i].get("mount", {}).is_empty()):
			var u := SaveGame.unit_from_dict(army[i])
			army[i] = SaveGame.unit_to_dict(u)
			u.free()
	return true


# --- Stable (see Mounts) ----------------------------------------------------------------

## Every mount in the campaign: [{"mount": record, "rider": unit name or ""}],
## ridden ones first (army order), then the stable.
static func all_mounts() -> Array:
	var result := []
	for d in army:
		if not d.get("mount", {}).is_empty():
			result.append({"mount": d.mount, "rider": d.unit_name})
	for m in stable:
		result.append({"mount": m, "rider": ""})
	return result


## Why `unit_name` can't ride `mount`, or "".
static func ride_problem(unit_name: String, mount: Dictionary) -> String:
	var d := army_unit(unit_name)
	var foot: String = d.get("foot_class", "")
	return Mounts.ride_problem(foot if foot != "" else d.unit_class, d.race, d.gender, mount.species)


## Puts `unit_name` on a stable mount; a mount it was riding goes back to the stable.
static func assign_mount(unit_name: String, mount: Dictionary) -> void:
	var i := army.find(army_unit(unit_name))
	var u := SaveGame.unit_from_dict(army[i])
	if not u.mount.is_empty():
		stable.append(u.dismount())
	stable.erase(mount)
	u.mount_up(mount)
	army[i] = SaveGame.unit_to_dict(u)
	u.free()


## Takes `unit_name` off its mount, back to its foot class; the mount goes to the stable.
static func unassign_mount(unit_name: String) -> void:
	var i := army.find(army_unit(unit_name))
	var u := SaveGame.unit_from_dict(army[i])
	stable.append(u.dismount())
	army[i] = SaveGame.unit_to_dict(u)
	u.free()


## The class name to show for an army unit record (mounted classes by species).
static func class_label(d: Dictionary) -> String:
	var m: Dictionary = d.get("mount", {})
	return Mounts.display_name(d.unit_class, m.species) if not m.is_empty() else d.unit_class


## Forgets the picks and placement of the chapter being prepared. Not done by
## load_save, so they survive the trip to Check Map and a retried chapter.
static func clear_deployment() -> void:
	deployed = []
	placement = {}
	checking_map = false


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
	clear_deployment()
	if not is_complete():
		add_recruits()
	save()


static func can_promote(data: Dictionary) -> bool:
	return data.level >= Classes.PROMOTION_LEVEL and not promotion_options(data).is_empty()


## Classes an army unit can promote into: its foot class's promotions (a mounted
## unit promotes on foot, then rides again: see Mounts).
static func promotion_options(data: Dictionary) -> Array:
	var foot: String = data.get("foot_class", "")
	return Classes.promotions(foot if foot != "" else data.unit_class)


## Promotes an army unit (prep screen): new class, same level, plus the new class's
## bonus. Returns the gains actually applied (after caps).
static func promote(unit_name: String, new_class: String) -> Dictionary:
	var i := army.find(army_unit(unit_name))
	var u := SaveGame.unit_from_dict(army[i])
	if u.mount.is_empty():
		u.set_class(new_class)
	else:
		u.foot_class = new_class
		u.set_class(Mounts.mounted_class(new_class))
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
