extends Node2D
class_name Battle
## Battle scene root: the map, units, cursor and UI, plus state shared by
## its parts: input (BattleInput), unit actions (BattleActions) and turn flow
## (BattlePhases). Also answers questions about units on the map and enemy threat.

## What input is accepted right now: BUSY while anything animates, GAME_OVER at the end.
enum State { IDLE, SELECTED, MENU, TARGETING, AREA_TARGET, TRADE, STATUS, UNIT_LIST, OBJECTIVE, OPTIONS, CHOICE, DIALOGUE, BUSY, GAME_OVER }

@onready var map: BattleMap = $Map
@onready var units_root: Node2D = $Units
@onready var cursor: Cursor = $Cursor
@onready var ui: BattleUI = $UI

var state := State.BUSY
## Whether the enemy danger zone overlay is shown (toggled with danger_zone).
var danger_on := false
## Enemies the player marked (Z); their threat is drawn as a red overlay.
var marked: Array[Unit] = []
## Current turn number (a turn is one player phase plus one enemy phase).
var turn := 0
## True during the enemy phase, when holding cancel fast-forwards.
var enemy_phase := false
## Set by Seize, or by the Lord's Escape: wins seize/escape objectives.
var objective_done := false
## Player units that fell this battle ({"name", "turn"}), for campaign permadeath.
var campaign_deaths: Array = []
## "victory" or "defeat" once the battle has ended.
var battle_result := ""
## Turn rewind: a snapshot (SaveGame.capture without history) from the start of each
## player phase, oldest first, and the uses left this map (-1: unlimited). The
## Options setting sets the uses when a map starts.
var turn_history: Array = []
var rewinds_left := 0

## Scrolls the view over maps bigger than the screen (see BattleCamera).
var camera: BattleCamera
## The battle's parts, created in _ready (child nodes, so input gets events).
var input: BattleInput
var actions: BattleActions
var phases: BattlePhases
var events: BattleEvents

const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"


# --- Setup --------------------------------------------------------------------

func _ready() -> void:
	Skills.field = units  # auras and adjacency conditions look at the units on the map
	input = _add_part(BattleInput.new(), "Input")
	actions = _add_part(BattleActions.new(), "Actions")
	phases = _add_part(BattlePhases.new(), "Phases")
	events = _add_part(BattleEvents.new(), "Events")
	events.load_for(Levels.selected)
	camera = BattleCamera.new()
	camera.name = "Camera"
	add_child(camera)
	if Levels.resume:
		Levels.resume = false
		phases.resume_suspended()
		_start_camera()
		return
	danger_on = Settings.value("danger_zone_default")
	rewinds_left = Settings.value("rewinds")
	var level := Levels.get_level(Levels.selected)
	map.load_layout(level.layout)
	map.load_objects(level.get("objects", []), Objectives.of(level))
	if level.has("deploy"):
		deploy_army(level)
	else:
		for data in level.players:
			units_root.add_child(Unit.create(data.name, Unit.Team.PLAYER, data.cell, data))
	for data in level.enemies:
		units_root.add_child(Unit.create(data.name, Unit.Team.ENEMY, data.cell, data))
	var players := units_of(Unit.Team.PLAYER)
	cursor.cell = players[0].cell if not players.is_empty() else Vector2i.ZERO
	_start_camera()
	await events.on_start()
	phases.start_player_phase()


func _start_camera() -> void:
	camera.setup(map.cols, map.rows)
	camera.snap(cursor.cell)
	ui.view_origin = camera.origin


## The cell the camera keeps in view: a unit while it moves, otherwise the cursor.
func camera_focus() -> Vector2i:
	for u in units():
		if u.moving:
			return Vector2i((u.position / BattleMap.TILE).round())
	return cursor.cell


func _add_part(part: Node, part_name: String) -> Node:
	part.name = part_name
	part.battle = self
	add_child(part)
	return part


## Campaign chapter: the units picked in the prep screen, on the chapter's deploy
## cells in order (the Lord first).
func deploy_army(level: Dictionary) -> void:
	var cells: Array = level.deploy
	var names: Array = Campaign.deployed if not Campaign.deployed.is_empty() else Campaign.default_deployment()
	var i := 0
	for unit_name in names:
		var data := Campaign.army_unit(unit_name)
		if data.is_empty() or i >= cells.size():
			continue
		var u := SaveGame.unit_from_dict(data)
		u.team = Unit.Team.PLAYER
		u.set_cell(cells[i])
		units_root.add_child(u)
		i += 1


# --- Queries ------------------------------------------------------------------

## Every living unit, including carried and boarded ones (which are off the map).
func all_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for child in units_root.get_children():
		if child is Unit and child.hp > 0:
			result.append(child)
	return result


## Units on the map (carried units are off the map and excluded).
func units() -> Array[Unit]:
	var result: Array[Unit] = []
	for child in units_root.get_children():
		if child is Unit and child.hp > 0 and child.carried_by == null and not child.escaped:
			result.append(child)
	return result


func units_of(team: Unit.Team) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units():
		if u.team == team:
			result.append(u)
	return result


func unit_at(cell: Vector2i) -> Unit:
	for u in units():
		if u.cell == cell:
			return u
	return null


## Whether `u` may be placed on `cell` (shoved, dropped, unloaded): the cell must be
## enterable within one move, i.e. cost no more than its MOV. Rivers cost foot units
## 6, so a MOV 5 foot soldier can't be dropped into one.
func can_stand_on(u: Unit, cell: Vector2i) -> bool:
	var cost := map.unit_cost(u, cell)
	return cost >= 0 and cost <= u.mov


## Nearest empty cell to `from` that `u` can stand on, or (-1, -1) if there's none.
func nearest_free_cell(u: Unit, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for y in map.rows:
		for x in map.cols:
			var c := Vector2i(x, y)
			if not can_stand_on(u, c) or unit_at(c) != null:
				continue
			if best == Vector2i(-1, -1) or BattleMap.distance(from, c) < BattleMap.distance(from, best):
				best = c
	return best


## Weapon ranges plus offensive spell reach. Spells the unit can't afford are
## skipped when `affordable_only` (used for enemy threat, which must be accurate).
func offense_ranges(u: Unit, affordable_only := false) -> Array[Vector2i]:
	var offense := u.weapon_ranges()
	for s in u.attack_spells():
		if Spells.is_support(s) or (affordable_only and not Spells.can_afford(u, s)):
			continue
		var r := Spells.reach_ranges(s, u)
		if not offense.has(r):
			offense.append(r)
	return offense


## "Turn N", or "Turn N / M" on maps with a turn limit.
func turn_text() -> String:
	var objective := Objectives.of(Levels.get_level(Levels.selected))
	if objective.type in ["survive", "defend"]:
		return "Turn %d / %d" % [turn, objective.turns]
	return "Turn %d" % turn


# --- Enemy threat (danger zone and marked enemies) ----------------------------

## Every cell an enemy could attack next phase: where it can move, plus what its
## weapons and affordable damage spells reach from there.
func enemy_threat(e: Unit) -> Dictionary:
	return EnemyAI.threat_from(e, self, EnemyAI.movement_cells(e, self))


func threat_of(enemies: Array[Unit]) -> Dictionary:
	var cells := {}
	for e in enemies:
		cells.merge(enemy_threat(e))
	return cells


## Recomputes the purple (all enemies) and red (marked enemies) overlays. Called
## whenever positions may have changed, and drops marks on enemies that died.
func refresh_threat() -> void:
	# A plain loop, not filter(): a marked enemy that died has been freed, and a
	# lambda with a `Unit` parameter can't even be called with a freed object.
	var alive: Array[Unit] = []
	for e in marked:
		if is_instance_valid(e) and e.hp > 0:
			alive.append(e)
	marked = alive
	map.danger_cells = threat_of(units_of(Unit.Team.ENEMY)) if danger_on else {}
	map.marked_cells = threat_of(marked)


# --- Game speed ---------------------------------------------------------------

## Game speed comes from Options; holding cancel during the enemy phase multiplies
## it by the fast-forward speed (also from Options).
func _process(_delta: float) -> void:
	camera.follow(camera_focus())
	ui.view_origin = camera.origin
	var ff: float = Settings.value("fast_forward_speed") if enemy_phase and Input.is_action_pressed("cancel") else 1.0
	var speed: float = Settings.value("game_speed") * ff
	if Engine.time_scale != speed:
		Engine.time_scale = speed
		ui.show_fast_forward(ff)


func _exit_tree() -> void:
	# Leaving mid-fast-forward (restart, level select) must not keep the game sped up.
	Engine.time_scale = 1.0
