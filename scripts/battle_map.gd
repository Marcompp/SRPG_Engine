class_name BattleMap
extends Node2D
## Terrain grid, pathfinding and range highlights.

const TILE := 16
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Movement types (a class's "move"):
##   foot (most units), heavy (armor), horse, rogue (scouts), climb (hills/mountains),
##   swim (water), mermaid (aquatic), ship (seafaring), flying, spirit,
##   swim_climb (Berserker, amphibious races) and rogue_swim_climb (amphibious
##   scouts): hybrids, see HYBRID_MOVES.
## A unit's race can override its class's move type (see Races).
const MOVE_TYPES: Array[String] = ["foot", "heavy", "horse", "rogue", "climb", "swim",
	"mermaid", "ship", "flying", "spirit", "swim_climb", "rogue_swim_climb"]
## Hybrid move types: on each terrain, the cheapest cost among their parts.
const HYBRID_MOVES := {"swim_climb": ["swim", "climb"], "rogue_swim_climb": ["rogue", "swim", "climb"]}
## Move types that get no DEF/AVO from terrain (they pass over it).
const NO_TERRAIN_BONUS: Array[String] = ["flying", "spirit"]
const IMPASSABLE := -1.0

## Terrain: DEF/AVO bonuses, `heal` (fraction of max HP restored at the start of the
## occupant's phase) and `cost`: MOV spent to enter, by move type. "*" is the cost for
## every type not listed; -1 = impassable. Fliers pay 1 wherever they aren't listed,
## and spirits always pay 1 (see cost_for()).
const TERRAIN := {
	# Outdoors
	".": {"name": "Plain", "def": 0, "avo": 0, "color": Color("78b04f"),
		"cost": {"*": 1, "mermaid": 3, "ship": 6}},
	"=": {"name": "Path", "def": 0, "avo": -20, "color": Color("c9ad7a"),
		"cost": {"*": 0.7, "mermaid": 1.5, "ship": 5}},
	"H": {"name": "House", "def": 0, "avo": 15, "color": Color("78b04f"),
		"cost": {"*": 1, "horse": 1.2, "ship": 10}},
	"T": {"name": "Fort", "def": 3, "avo": 25, "heal": 0.2, "color": Color("9c8a6a"),
		"cost": {"*": 1.5}},
	"S": {"name": "Sand", "def": 0, "avo": 5, "color": Color("d8c78a"),
		"cost": {"*": 1, "horse": 1.5, "mermaid": 2, "ship": 5}},
	"D": {"name": "Dune", "def": 0, "avo": 15, "color": Color("c9ac62"),
		"cost": {"*": 1.5, "horse": 3, "mermaid": 2, "ship": 4}},
	"F": {"name": "Forest", "def": 1, "avo": 20, "color": Color("4e8a3a"),
		"cost": {"*": 2, "rogue": 1.5, "mermaid": 3, "horse": 4, "ship": 10}},
	"#": {"name": "Thicket", "def": 2, "avo": 30, "color": Color("2f5f2c"),
		"cost": {"*": 10, "horse": 20, "ship": 20, "rogue": 6}},
	"h": {"name": "Hill", "def": 2, "avo": 20, "color": Color("9aa25a"),
		"cost": {"*": 4, "climb": 2, "horse": 10, "mermaid": 10, "heavy": 10, "ship": 20}},
	"M": {"name": "Mountain", "def": 3, "avo": 30, "color": Color("8a7a5c"),
		"cost": {"*": 7, "climb": 4, "horse": 15, "mermaid": 15, "heavy": 15, "ship": 20}},
	"~": {"name": "River", "def": 0, "avo": 10, "color": Color("3f7fd0"),
		"cost": {"*": 6, "swim": 2, "mermaid": 1, "ship": 1, "horse": 8, "heavy": 8}},
	"L": {"name": "Lake", "def": 0, "avo": 10, "color": Color("4a8ad8"),
		"cost": {"*": 6, "swim": 2, "mermaid": 1, "ship": 1, "horse": 8, "heavy": 8}},
	"W": {"name": "Sea", "def": 0, "avo": 10, "color": Color("2a5fa8"),
		"cost": {"*": 6, "swim": 2, "mermaid": 1, "ship": 1, "horse": 8, "heavy": 8}},
	"v": {"name": "Waterfall", "def": 0, "avo": 30, "color": Color("7ab8f0"),
		"cost": {"*": 20, "mermaid": 6, "swim": 6, "ship": 8}},
	"*": {"name": "Snow", "def": 0, "avo": 5, "color": Color("e6edf3"),
		"cost": {"*": 1, "horse": 1.5, "mermaid": 2, "ship": 5}},
	"i": {"name": "Ice", "def": 0, "avo": -20, "color": Color("b6def0"),
		"cost": {"*": 1.5, "horse": 2, "heavy": 1, "mermaid": 1, "ship": 4}},
	# Indoors
	"_": {"name": "Floor", "def": 0, "avo": 0, "color": Color("8c857a"),
		"cost": {"*": 1, "mermaid": 3, "horse": 1.5, "flying": 1.5, "ship": 10}},
	"c": {"name": "Carpet", "def": 0, "avo": 0, "color": Color("9a3a3a"),
		"cost": {"*": 1, "mermaid": 3, "horse": 1.5, "flying": 1.5, "ship": 10}},
	"X": {"name": "Wall", "def": 0, "avo": 0, "color": Color("4a4440"),
		"cost": {"*": IMPASSABLE, "flying": IMPASSABLE}},
	"I": {"name": "Pillar", "def": 0, "avo": 20, "color": Color("8c857a"),
		"cost": {"*": 2, "ship": 20}},
	"O": {"name": "Abyss", "def": 0, "avo": 0, "color": Color("101018"),
		"cost": {"*": IMPASSABLE}},
	"|": {"name": "Fence", "def": 0, "avo": 0, "color": Color("9a9282"),
		"cost": {"*": IMPASSABLE}},
	# Breakable: "breakable" gives the tile's HP and what it becomes when broken.
	"x": {"name": "Cracked Wall", "def": 0, "avo": 0, "color": Color("4a4440"),
		"cost": {"*": IMPASSABLE, "flying": IMPASSABLE}, "breakable": {"hp": 20, "becomes": "_"}},
	"/": {"name": "Cracked Fence", "def": 0, "avo": 0, "color": Color("9a9282"),
		"cost": {"*": IMPASSABLE}, "breakable": {"hp": 10, "becomes": "."}},
	"Y": {"name": "Trunk", "def": 0, "avo": 0, "color": Color("78b04f"),
		"cost": {"*": IMPASSABLE}, "breakable": {"hp": 15, "becomes": ".", "bridge": true}},
	# Doors: opened by units that can open chests, or broken like a cracked wall.
	"+": {"name": "Door", "def": 0, "avo": 0, "color": Color("4a4440"),
		"cost": {"*": IMPASSABLE, "flying": IMPASSABLE}, "breakable": {"hp": 20, "becomes": "_"}, "door": true},
	# Left by a fallen trunk: walkable, and water units still pass underneath.
	"B": {"name": "Bridge", "def": 0, "avo": 0, "color": Color("3f7fd0"),
		"cost": {"*": 1, "mermaid": 1, "ship": 1}},
}

## Water a fallen trunk can bridge, and how many tiles of it.
const BRIDGEABLE: Array[String] = ["~", "L"]
const BRIDGE_LENGTH := 3


## MOV a unit of `move_type` spends entering terrain `key` (-1 = impassable).
static func cost_for(key: String, move_type: String) -> float:
	if move_type == "spirit":
		return 1.0
	if HYBRID_MOVES.has(move_type):
		var best := IMPASSABLE
		for part: String in HYBRID_MOVES[move_type]:
			var c := cost_for(key, part)
			if c >= 0 and (best < 0 or c < best):
				best = c
		return best
	var cost: Dictionary = TERRAIN[key].cost
	if cost.has(move_type):
		return cost[move_type]
	if move_type == "flying":
		return 1.0
	return cost["*"]

const MOVE_COLOR := Color(0.3, 0.5, 1.0, 0.5)
const ATTACK_COLOR := Color(1.0, 0.25, 0.25, 0.45)
const SUPPORT_COLOR := Color(0.3, 1.0, 0.4, 0.4)
const AREA_COLOR := Color(1.0, 0.6, 0.1, 0.55)
const DANGER_COLOR := Color(0.6, 0.1, 0.75, 0.3)
const DANGER_EDGE_COLOR := Color(0.85, 0.3, 1.0, 0.9)
const MARKED_COLOR := Color(0.9, 0.1, 0.1, 0.3)
const MARKED_EDGE_COLOR := Color(1.0, 0.35, 0.35, 0.95)
const ARROW_COLOR := Color(1.0, 0.85, 0.25, 0.95)

var cols := 0
var rows := 0
## Remaining HP of breakable tiles (cracked walls, doors...), by cell.
var tile_hp := {}
## Live terrain: starts as the level's layout and can be changed by spells (see set_terrain).
var grid: Array[String] = []
var move_cells: Array = []
var attack_cells: Array = []
var support_cells: Array = []
var area_cells: Array = []
## Threat overlays, drawn under the other highlights: every enemy (purple,
## toggled by the player) and the enemies the player has marked (red).
var danger_cells: Dictionary = {}:
	set(value):
		danger_cells = value
		queue_redraw()
var marked_cells: Dictionary = {}:
	set(value):
		marked_cells = value
		queue_redraw()
## Planned movement path for the selected unit, start cell first.
var arrow_path: Array[Vector2i] = []:
	set(value):
		arrow_path = value
		queue_redraw()
## Map objects from the level's "objects": dictionaries with "type" ("village" or
## "chest"), "cell", "item" (the reward) and "state": "intact", "visited" (village
## a player visited), "looted" (village an enemy destroyed) or "opened" (chest).
var objects: Array = []
## Objective tiles to outline (see Objectives.marked_cells) and the objective type.
var objective_cells: Array[Vector2i] = []
var objective_type := ""


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func load_layout(layout: Array) -> void:
	grid.assign(layout)
	rows = grid.size()
	cols = grid[0].length()
	tile_hp.clear()
	for y in rows:
		for x in cols:
			var info := breakable_info(Vector2i(x, y))
			if not info.is_empty():
				tile_hp[Vector2i(x, y)] = info.hp
	queue_redraw()


## {"hp", "becomes", ...} for a breakable tile, or {}.
func breakable_info(cell: Vector2i) -> Dictionary:
	if not in_bounds(cell):
		return {}
	return terrain_at(cell).get("breakable", {})


func is_door(cell: Vector2i) -> bool:
	return in_bounds(cell) and terrain_at(cell).get("door", false)


## Damages a breakable tile; returns true if that broke it.
func damage_tile(cell: Vector2i, amount: int, from: Vector2i) -> bool:
	tile_hp[cell] = maxi(0, tile_hp.get(cell, 0) - amount)
	queue_redraw()
	if tile_hp[cell] > 0:
		return false
	break_tile(cell, from)
	return true


## Turns a breakable tile into what it becomes. A trunk falls into the water: away
## from `from` (the breaker's cell) if there's water that way, otherwise toward the
## first side that has some, bridging up to BRIDGE_LENGTH tiles.
func break_tile(cell: Vector2i, from: Vector2i) -> void:
	var info := breakable_info(cell)
	set_terrain(cell, info.becomes)
	if info.get("bridge", false):
		var delta := cell - from
		var away := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		var dirs: Array[Vector2i] = [away]
		dirs.append_array(DIRS)
		for d in dirs:
			if d != Vector2i.ZERO and BRIDGEABLE.has(_key_or_empty(cell + d)):
				var c := cell + d
				for i in BRIDGE_LENGTH:
					if not BRIDGEABLE.has(_key_or_empty(c)):
						break
					set_terrain(c, "B")
					c += d
				break


func _key_or_empty(cell: Vector2i) -> String:
	return terrain_key(cell) if in_bounds(cell) else ""


func load_objects(list: Array, objective: Dictionary) -> void:
	objects = []
	for o in list:
		var copy: Dictionary = o.duplicate()
		copy["state"] = copy.get("state", "intact")
		objects.append(copy)
	objective_type = objective.type
	objective_cells = Objectives.marked_cells(objective)
	queue_redraw()


## The map object on `cell`, or {} if there's none.
func object_at(cell: Vector2i) -> Dictionary:
	for o in objects:
		if o.cell == cell:
			return o
	return {}


## Villages not yet visited or looted, and chests not yet opened.
func lootable_objects() -> Array:
	return objects.filter(func(o): return o.state == "intact")


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func terrain_at(cell: Vector2i) -> Dictionary:
	return TERRAIN[grid[cell.y][cell.x]]


func terrain_key(cell: Vector2i) -> String:
	return grid[cell.y][cell.x]


## Changes a tile's terrain (e.g. Earth Spike raising a mountain).
func set_terrain(cell: Vector2i, key: String) -> void:
	var row := grid[cell.y]
	grid[cell.y] = row.substr(0, cell.x) + key + row.substr(cell.x + 1)
	tile_hp.erase(cell)
	if TERRAIN[key].has("breakable"):
		tile_hp[cell] = TERRAIN[key].breakable.hp
	queue_redraw()


## Cost to enter `cell` for a unit of `move_type` (-1 = impassable or off the map).
func move_cost(cell: Vector2i, move_type := "foot") -> float:
	if not in_bounds(cell):
		return IMPASSABLE
	return cost_for(terrain_key(cell), move_type)


func terrain_def(cell: Vector2i) -> int:
	return terrain_at(cell).def


func terrain_avoid(cell: Vector2i) -> int:
	return terrain_at(cell).avo


## Terrain DEF/AVO the unit actually gets where it stands (fliers get none).
func unit_terrain_def(u: Unit) -> int:
	return 0 if NO_TERRAIN_BONUS.has(u.move_type) else terrain_def(u.cell)


func unit_terrain_avoid(u: Unit) -> int:
	return 0 if NO_TERRAIN_BONUS.has(u.move_type) else terrain_avoid(u.cell)


## Fraction of max HP this cell restores at the start of its occupant's phase.
func terrain_heal(cell: Vector2i) -> float:
	return terrain_at(cell).get("heal", 0.0)


func healing_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			if terrain_heal(Vector2i(x, y)) > 0.0:
				result.append(Vector2i(x, y))
	return result


## Dijkstra limited by the unit's MOV. Allies can be passed through but not
## stopped on; enemies block. Returns {"cells": {cell: cost}, "parents": {cell: prev}}.
## What entering `cell` costs `u`: its move type's cost, or 1 with Pathfinder.
func unit_cost(u: Unit, cell: Vector2i) -> float:
	var cost := move_cost(cell, u.move_type)
	if cost > 0 and Skills.map_rules(u).has("pathfinder"):
		return 1.0
	return cost


## Cells `unit` can reach with `budget` MOV (default: its MOV): {"cells": {cell: cost},
## "parents": {cell: previous cell}}. Enemies block the way, unless it has Pass.
func get_reachable(unit: Unit, units: Array[Unit], budget := -1.0) -> Dictionary:
	if budget < 0:
		budget = unit.mov
	var passes := Skills.map_rules(unit).has("pass")
	var occupied := {}
	for u in units:
		occupied[u.cell] = u
	var costs := {unit.cell: 0.0}
	var parents := {}
	var frontier: Array[Vector2i] = [unit.cell]
	while not frontier.is_empty():
		var best := 0
		for i in frontier.size():
			if costs[frontier[i]] < costs[frontier[best]]:
				best = i
		var cur: Vector2i = frontier[best]
		frontier.remove_at(best)
		for d in DIRS:
			var nxt := cur + d
			var step := unit_cost(unit, nxt)
			if step < 0:
				continue
			if occupied.has(nxt) and occupied[nxt].team != unit.team and not passes:
				continue
			var total: float = costs[cur] + step
			# Costs can be fractional (Path 0.7), so allow for float rounding.
			if total > budget + 0.001 or (costs.has(nxt) and costs[nxt] <= total):
				continue
			costs[nxt] = total
			parents[nxt] = cur
			frontier.append(nxt)
	var cells := {}
	for cell in costs:
		if occupied.has(cell) and occupied[cell] != unit:
			continue
		cells[cell] = costs[cell]
	return {"cells": cells, "parents": parents}


func build_path(parents: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [to]
	var cur := to
	while cur != from:
		cur = parents[cur]
		path.push_front(cur)
	return path


## Cells attackable from any of the given move cells with any of the given
## (min, max) ranges, excluding the move cells themselves.
func get_attack_cells(move_set: Dictionary, ranges: Array[Vector2i]) -> Array:
	var max_range := 0
	for r in ranges:
		max_range = maxi(max_range, r.y)
	var result := {}
	for c in move_set:
		for dx in range(-max_range, max_range + 1):
			for dy in range(-max_range, max_range + 1):
				var dist := absi(dx) + absi(dy)
				if dist < 1 or not ranges.any(func(r: Vector2i) -> bool: return dist >= r.x and dist <= r.y):
					continue
				var t: Vector2i = c + Vector2i(dx, dy)
				if in_bounds(t) and not move_set.has(t):
					result[t] = true
	return result.keys()


## Unbounded terrain-cost distance from `target` to every cell (ignores units),
## for a unit of `move_type`. Used by the AI to approach targets around obstacles.
## `extra` gives costs for cells that are otherwise impassable (the AI uses it to
## plan through breakable tiles and doors).
func cost_field(target: Vector2i, move_type := "foot", extra := {}) -> Dictionary:
	var costs := {target: 0.0}
	var frontier: Array[Vector2i] = [target]
	while not frontier.is_empty():
		var best := 0
		for i in frontier.size():
			if costs[frontier[i]] < costs[frontier[best]]:
				best = i
		var cur: Vector2i = frontier[best]
		frontier.remove_at(best)
		for d in DIRS:
			var nxt := cur + d
			var step: float = extra.get(nxt, move_cost(nxt, move_type))
			if step < 0:
				continue
			var total: float = costs[cur] + step
			if costs.has(nxt) and costs[nxt] <= total:
				continue
			costs[nxt] = total
			frontier.append(nxt)
	return costs


func show_ranges(moves: Array, attacks: Array, supports: Array = []) -> void:
	move_cells = moves
	attack_cells = attacks
	support_cells = supports.filter(func(c: Vector2i) -> bool: return not attacks.has(c))
	queue_redraw()


## Highlights an area spell's blast: `cast_cells` = where it can be aimed, `blast` = what it hits.
func show_area(cast_cells: Array, blast: Array) -> void:
	move_cells = []
	support_cells = []
	attack_cells = cast_cells
	area_cells = blast
	queue_redraw()


func clear_ranges() -> void:
	move_cells = []
	attack_cells = []
	support_cells = []
	area_cells = []
	arrow_path = []
	queue_redraw()


func _draw() -> void:
	for y in rows:
		for x in cols:
			_draw_tile(Vector2i(x, y))
	_draw_objects()
	_draw_zone(danger_cells, DANGER_COLOR, DANGER_EDGE_COLOR)
	_draw_zone(marked_cells, MARKED_COLOR, MARKED_EDGE_COLOR)
	for c in move_cells:
		draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), MOVE_COLOR)
	for c in attack_cells:
		draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), ATTACK_COLOR)
	for c in support_cells:
		draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), SUPPORT_COLOR)
	for c in area_cells:
		draw_rect(Rect2(Vector2(c * TILE), Vector2(TILE, TILE)), AREA_COLOR)
	_draw_arrow()


## Tinted cells with an outline on the zone's border, so it reads even under other overlays.
func _draw_zone(cells: Dictionary, fill: Color, edge: Color) -> void:
	for c in cells:
		var o := Vector2(c * TILE)
		draw_rect(Rect2(o, Vector2(TILE, TILE)), fill)
		for d in DIRS:
			if cells.has(c + d):
				continue
			var a := o + Vector2(TILE / 2.0, TILE / 2.0) + Vector2(d) * (TILE / 2.0 - 0.5)
			var side := Vector2(d.y, d.x) * (TILE / 2.0)
			draw_line(a - side, a + side, edge, 1.0)


## Villages, chests and objective tiles, drawn over the terrain.
func _draw_objects() -> void:
	for o in objects:
		var p := Vector2(o.cell * TILE)
		match o.type:
			"village":
				match o.state:
					"intact":  # yellow banner on the roof
						draw_rect(Rect2(p + Vector2(11, 1), Vector2(1, 6)), Color("5a4630"))
						draw_rect(Rect2(p + Vector2(12, 1), Vector2(3, 2)), Color("f0c030"))
					"visited":  # door closed
						draw_rect(Rect2(p + Vector2(7, 10), Vector2(2, 4)), Color("3a3a3a"))
					"looted":  # burned down
						draw_rect(Rect2(p + Vector2(2, 2), Vector2(12, 12)), Color(0.15, 0.1, 0.08, 0.75))
						draw_line(p + Vector2(4, 12), p + Vector2(12, 4), Color("ff7030"), 1.0)
			"chest":
				var body := Color("8b5a2b")
				draw_rect(Rect2(p + Vector2(4, 7), Vector2(8, 6)), body)
				draw_rect(Rect2(p + Vector2(4, 7), Vector2(8, 6)), Color.BLACK, false, 1.0)
				if o.state == "opened":
					draw_rect(Rect2(p + Vector2(5, 8), Vector2(6, 2)), Color("2a1a0a"))
					draw_rect(Rect2(p + Vector2(4, 4), Vector2(8, 2)), body)
				else:
					draw_rect(Rect2(p + Vector2(7, 9), Vector2(2, 2)), Color("f0c030"))
	var colors := {"seize": Color("f0c030"), "defend": Color("50a0ff"), "escape": Color("50e070")}
	for c in objective_cells:
		var p := Vector2(c * TILE)
		var color: Color = colors.get(objective_type, Color.WHITE)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), color, false, 2.0)


func _draw_arrow() -> void:
	if arrow_path.size() < 2:
		return
	var points := PackedVector2Array()
	for c in arrow_path:
		points.append(Vector2(c * TILE) + Vector2(TILE / 2.0, TILE / 2.0))
	draw_polyline(points, ARROW_COLOR, 4.0)
	# Arrowhead at the destination.
	var tip := points[-1]
	var dir := (tip - points[-2]).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip + dir * 5.0, tip - dir * 2.0 + side * 5.0,
		tip - dir * 2.0 - side * 5.0]), ARROW_COLOR)


func _draw_tile(cell: Vector2i) -> void:
	var key: String = grid[cell.y][cell.x]
	var o := Vector2(cell * TILE)
	draw_rect(Rect2(o, Vector2(TILE, TILE)), TERRAIN[key].color)
	match key:
		"F":
			draw_colored_polygon(PackedVector2Array([o + Vector2(8, 2), o + Vector2(13, 11), o + Vector2(3, 11)]), Color("24572a"))
			draw_rect(Rect2(o + Vector2(7, 11), Vector2(2, 3)), Color("5a3b1e"))
		"M":
			draw_colored_polygon(PackedVector2Array([o + Vector2(8, 2), o + Vector2(15, 14), o + Vector2(1, 14)]), Color("6b5a40"))
			draw_colored_polygon(PackedVector2Array([o + Vector2(8, 2), o + Vector2(10, 6), o + Vector2(6, 6)]), Color("eeeeee"))
		"~":
			draw_line(o + Vector2(3, 5), o + Vector2(8, 5), Color("8fc0f0"))
			draw_line(o + Vector2(8, 11), o + Vector2(13, 11), Color("8fc0f0"))
		"W":
			draw_line(o + Vector2(2, 4), o + Vector2(6, 4), Color("5a8ad0"))
			draw_line(o + Vector2(9, 9), o + Vector2(14, 9), Color("5a8ad0"))
			draw_line(o + Vector2(3, 13), o + Vector2(7, 13), Color("5a8ad0"))
		"S":
			for dot in [Vector2(3, 4), Vector2(10, 3), Vector2(6, 9), Vector2(12, 12), Vector2(3, 13)]:
				draw_rect(Rect2(o + dot, Vector2(1, 1)), Color("b8a668"))
		"T":
			# Small stone keep with battlements and a door.
			draw_rect(Rect2(o + Vector2(3, 5), Vector2(10, 9)), Color("b8b0a0"))
			for bx in [3, 7, 11]:
				draw_rect(Rect2(o + Vector2(bx, 3), Vector2(2, 2)), Color("b8b0a0"))
			draw_rect(Rect2(o + Vector2(7, 10), Vector2(2, 4)), Color("5a4630"))
		"=":
			draw_line(o + Vector2(0, 5), o + Vector2(16, 5), Color("b0946a"))
			draw_line(o + Vector2(0, 11), o + Vector2(16, 11), Color("b0946a"))
		"H":
			draw_rect(Rect2(o + Vector2(4, 7), Vector2(8, 7)), Color("e0d0b0"))
			draw_colored_polygon(PackedVector2Array([o + Vector2(8, 2), o + Vector2(13, 7), o + Vector2(3, 7)]), Color("b04030"))
			draw_rect(Rect2(o + Vector2(7, 10), Vector2(2, 4)), Color("5a4630"))
		"D":
			draw_arc(o + Vector2(8, 13), 6.0, PI, TAU, 8, Color("a88a40"), 1.0)
			draw_arc(o + Vector2(5, 7), 4.0, PI, TAU, 6, Color("a88a40"), 1.0)
		"#":
			for tx in [4, 11]:
				draw_colored_polygon(PackedVector2Array([o + Vector2(tx, 1), o + Vector2(tx + 4, 9), o + Vector2(tx - 4, 9)]), Color("173a18"))
				draw_colored_polygon(PackedVector2Array([o + Vector2(tx, 6), o + Vector2(tx + 4, 14), o + Vector2(tx - 4, 14)]), Color("173a18"))
		"h":
			draw_arc(o + Vector2(8, 14), 7.0, PI, TAU, 10, Color("6f7a3a"), 2.0)
		"L":
			draw_line(o + Vector2(4, 6), o + Vector2(9, 6), Color("9ccaf5"))
			draw_line(o + Vector2(7, 11), o + Vector2(12, 11), Color("9ccaf5"))
		"v":
			for vx in [3, 7, 11]:
				draw_line(o + Vector2(vx, 0), o + Vector2(vx, 16), Color("eef6ff"), 1.0)
		"*":
			for dot in [Vector2(3, 3), Vector2(11, 5), Vector2(6, 10), Vector2(13, 12), Vector2(2, 13)]:
				draw_rect(Rect2(o + dot, Vector2(1, 1)), Color("aebdcc"))
		"i":
			draw_line(o + Vector2(3, 12), o + Vector2(12, 3), Color("eaf8ff"), 1.0)
			draw_line(o + Vector2(8, 14), o + Vector2(14, 8), Color("eaf8ff"), 1.0)
		"_":
			draw_line(o + Vector2(8, 0), o + Vector2(8, 16), Color("7a746a"))
			draw_line(o + Vector2(0, 8), o + Vector2(16, 8), Color("7a746a"))
		"c":
			draw_rect(Rect2(o + Vector2(1, 0), Vector2(1, 16)), Color("d0b050"))
			draw_rect(Rect2(o + Vector2(14, 0), Vector2(1, 16)), Color("d0b050"))
		"X":
			for by in [0, 5, 10]:
				draw_line(o + Vector2(0, by + 4.5), o + Vector2(16, by + 4.5), Color("2e2a27"))
				var bx := 4 if by % 10 == 0 else 10
				draw_line(o + Vector2(bx, by), o + Vector2(bx, by + 4), Color("2e2a27"))
		"I":
			draw_rect(Rect2(o + Vector2(5, 1), Vector2(6, 14)), Color("c8c2b6"))
			draw_rect(Rect2(o + Vector2(4, 1), Vector2(8, 2)), Color("dcd6ca"))
			draw_rect(Rect2(o + Vector2(4, 13), Vector2(8, 2)), Color("dcd6ca"))
		"O":
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(12, 12)), Color("000000"))
		"|", "/":
			for fx in [2, 8, 14]:
				draw_rect(Rect2(o + Vector2(fx - 1, 3), Vector2(2, 11)), Color("7a4e28"))
			draw_rect(Rect2(o + Vector2(0, 6), Vector2(16, 1)), Color("8b5a2b"))
			if key == "/":  # broken rail and a split post
				draw_rect(Rect2(o + Vector2(0, 10), Vector2(6, 1)), Color("8b5a2b"))
				draw_line(o + Vector2(8, 3), o + Vector2(10, 8), Color("2a1a0a"), 1.0)
			else:
				draw_rect(Rect2(o + Vector2(0, 10), Vector2(16, 1)), Color("8b5a2b"))
		"x":
			for by in [0, 5, 10]:
				draw_line(o + Vector2(0, by + 4.5), o + Vector2(16, by + 4.5), Color("2e2a27"))
			# Crack running down the wall.
			draw_polyline(PackedVector2Array([o + Vector2(9, 0), o + Vector2(7, 5), o + Vector2(10, 9),
				o + Vector2(6, 16)]), Color("c8bfb4"), 1.0)
		"Y":
			draw_circle(o + Vector2(8, 8), 6.0, Color("6b4423"))
			draw_arc(o + Vector2(8, 8), 4.0, 0, TAU, 12, Color("a07850"), 1.0)
			draw_arc(o + Vector2(8, 8), 2.0, 0, TAU, 8, Color("a07850"), 1.0)
		"+":
			draw_rect(Rect2(o + Vector2(2, 1), Vector2(12, 15)), Color("7a4e28"))
			draw_rect(Rect2(o + Vector2(2, 1), Vector2(12, 15)), Color("3a2410"), false, 1.0)
			draw_line(o + Vector2(8, 1), o + Vector2(8, 16), Color("3a2410"), 1.0)
			draw_rect(Rect2(o + Vector2(9, 8), Vector2(2, 2)), Color("f0c030"))
		"B":
			draw_rect(Rect2(o + Vector2(0, 3), Vector2(16, 10)), Color("9a6a3a"))
			for px in [4, 8, 12]:
				draw_line(o + Vector2(px, 3), o + Vector2(px, 13), Color("6b4423"), 1.0)
	draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0, 0, 0, 0.12), false, 1.0)
