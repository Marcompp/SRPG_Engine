class_name SaveGame
extends RefCounted
## Suspend data: one battle in progress, saved mid player phase and resumed from
## the level select. Units are saved generically (every script variable), so new
## Unit fields are saved without touching this file. Exceptions:
##   - computed properties (getters over other fields) are listed in Unit.SAVE_SKIP;
##   - references to other units (carrying, passengers...) are saved as unit ids.

const VERSION := 1
## Tests point this elsewhere so they never touch a real suspend.
static var path := "user://suspend.save"


static func has_suspend() -> bool:
	return FileAccess.file_exists(path)


static func write_suspend(battle: Battle) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(capture(battle))


static func read_suspend() -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var()
	if not data is Dictionary or data.get("version", 0) != VERSION:
		return {}
	return data


static func delete_suspend() -> void:
	if has_suspend():
		DirAccess.remove_absolute(path)


# --- Capture / restore ----------------------------------------------------------

## Everything needed to rebuild the battle at the current point of the player phase.
## `with_history`: include the turn rewind snapshots (themselves captured without).
static func capture(battle: Battle, with_history := true) -> Dictionary:
	var all: Array[Unit] = battle.all_units()
	var ids := {}
	for i in all.size():
		ids[all[i]] = i
	var units := []
	for u in all:
		units.append(unit_to_dict(u, ids))
	var data := {
		"version": VERSION,
		"level": Levels.selected,
		"campaign": Campaign.active,
		"turn": battle.turn,
		"grid": _encode(battle.map.grid, ids),
		"tile_hp": battle.map.tile_hp.duplicate(),
		"objects": _encode(battle.map.objects, ids),
		"danger_on": battle.danger_on,
		"marked": _encode(battle.marked, ids),
		"campaign_deaths": _encode(battle.campaign_deaths, ids),
		"units": units,
		"rewinds_left": battle.rewinds_left,
	}
	if with_history:
		data["history"] = battle.turn_history.duplicate()
	return data


## Rebuilds the battle from capture() data: terrain, then every unit (two passes, so
## references between units resolve), then battle-level state.
static func restore(battle: Battle, data: Dictionary) -> void:
	battle.map.load_layout(data.grid)
	battle.map.tile_hp = data.get("tile_hp", battle.map.tile_hp)
	battle.map.load_objects(data.objects, Objectives.of(Levels.get_level(data.level)))
	battle.turn = data.turn
	battle.campaign_deaths.assign(data.campaign_deaths)
	var all: Array[Unit] = []
	for entry in data.units:
		var u := Unit.new()
		u.name = entry.unit_name
		battle.units_root.add_child(u)
		all.append(u)
	for i in all.size():
		_apply(all[i], data.units[i], all)
	battle.danger_on = data.danger_on
	battle.marked.assign(_decode(data.marked, all))
	battle.rewinds_left = data.get("rewinds_left", battle.rewinds_left)
	if data.has("history"):
		battle.turn_history = data.history.duplicate()


## One unit as plain data. References to other units become ids from `ids`
## (unknown ones, e.g. when saving a single unit, become -1, i.e. null).
static func unit_to_dict(u: Unit, ids := {}) -> Dictionary:
	var data := {}
	for name in saved_properties(u):
		data[name] = _encode(u.get(name), ids)
	return data


## A new Unit (not yet in the tree) from unit_to_dict() data.
static func unit_from_dict(data: Dictionary) -> Unit:
	var u := Unit.new()
	u.name = data.unit_name
	_apply(u, data, [])
	return u


static func _apply(u: Unit, data: Dictionary, all: Array[Unit]) -> void:
	for name in data:
		_set_property(u, name, _decode(data[name], all))
	u.set_cell(u.cell)
	u.visible = u.carried_by == null and not u.escaped
	u.queue_redraw()


## Script variables worth saving: everything except computed properties.
static func saved_properties(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for p in u.get_script().get_script_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not Unit.SAVE_SKIP.has(p.name):
			result.append(p.name)
	return result


static func _set_property(u: Unit, name: String, value: Variant) -> void:
	var current: Variant = u.get(name)
	if current is Array and value is Array:
		current.assign(value)  # keeps typed arrays (Array[String]...) typed
	else:
		u.set(name, value)


## Units become {"__unit": id}; containers are copied (untyped) recursively.
static func _encode(value: Variant, ids: Dictionary) -> Variant:
	if value is Unit:
		return {"__unit": ids.get(value, -1)}
	if value is Array:
		var out := []
		for v in value:
			out.append(_encode(v, ids))
		return out
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _encode(value[k], ids)
		return out
	return value


static func _decode(value: Variant, all: Array[Unit]) -> Variant:
	if value is Dictionary and value.size() == 1 and value.has("__unit"):
		return all[value.__unit] if value.__unit >= 0 and value.__unit < all.size() else null
	if value is Array:
		var out := []
		for v in value:
			out.append(_decode(v, all))
		return out
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _decode(value[k], all)
		return out
	return value
