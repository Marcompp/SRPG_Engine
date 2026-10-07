class_name BattleMap
extends Node2D
## Terrain grid, pathfinding and range highlights.

const TILE := 16
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

# cost < 0 means impassable.
const TERRAIN := {
	".": {"name": "Plain", "cost": 1, "def": 0, "avo": 0, "color": Color("78b04f")},
	"F": {"name": "Forest", "cost": 2, "def": 1, "avo": 20, "color": Color("4e8a3a")},
	"M": {"name": "Mountain", "cost": -1, "def": 0, "avo": 0, "color": Color("8a7a5c")},
	"~": {"name": "River", "cost": -1, "def": 0, "avo": 0, "color": Color("3f7fd0")},
}

const LAYOUT: Array[String] = [
	"....F..~....F..",
	".FF....~.....F.",
	"...............",
	"..MM...~..MM...",
	"..M....~...M...",
	"....F..~..F....",
	"...............",
	".FF....~...FF..",
	"..F....~....F..",
	".......~.......",
]

const MOVE_COLOR := Color(0.3, 0.5, 1.0, 0.5)
const ATTACK_COLOR := Color(1.0, 0.25, 0.25, 0.45)
const SUPPORT_COLOR := Color(0.3, 1.0, 0.4, 0.4)
const AREA_COLOR := Color(1.0, 0.6, 0.1, 0.55)
const DANGER_COLOR := Color(0.6, 0.1, 0.75, 0.3)
const DANGER_EDGE_COLOR := Color(0.85, 0.3, 1.0, 0.9)
const MARKED_COLOR := Color(0.9, 0.1, 0.1, 0.3)
const MARKED_EDGE_COLOR := Color(1.0, 0.35, 0.35, 0.95)
const ARROW_COLOR := Color(1.0, 0.85, 0.25, 0.95)

var cols := LAYOUT[0].length()
var rows := LAYOUT.size()
## Live terrain, starts as LAYOUT and can be changed by spells (see set_terrain).
var grid: Array[String] = LAYOUT.duplicate()
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


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


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
	queue_redraw()


func move_cost(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return -1
	return terrain_at(cell).cost


func terrain_def(cell: Vector2i) -> int:
	return terrain_at(cell).def


func terrain_avoid(cell: Vector2i) -> int:
	return terrain_at(cell).avo


## Dijkstra limited by the unit's MOV. Allies can be passed through but not
## stopped on; enemies block. Returns {"cells": {cell: cost}, "parents": {cell: prev}}.
func get_reachable(unit: Unit, units: Array[Unit]) -> Dictionary:
	var occupied := {}
	for u in units:
		occupied[u.cell] = u
	var costs := {unit.cell: 0}
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
			var step := move_cost(nxt)
			if step < 0:
				continue
			if occupied.has(nxt) and occupied[nxt].team != unit.team:
				continue
			var total: int = costs[cur] + step
			if total > unit.mov or (costs.has(nxt) and costs[nxt] <= total):
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


## Unbounded terrain-cost distance from `target` to every cell (ignores units).
## Used by the AI to approach targets around obstacles.
func cost_field(target: Vector2i) -> Dictionary:
	var costs := {target: 0}
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
			var step := move_cost(nxt)
			if step < 0:
				continue
			var total: int = costs[cur] + step
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
	draw_rect(Rect2(o, Vector2(TILE, TILE)), Color(0, 0, 0, 0.12), false, 1.0)
