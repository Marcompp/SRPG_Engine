class_name BattleFormation
extends RefCounted
## The prep screen's Check Map (part of BattleInput, as `input.formation`): look
## around the chapter's map before it starts (FORMATION state) and swap units between
## the deploy cells. Fight! starts the battle from here.

var input: BattleInput
## True while Check Map is showing (BattleInput.browse() goes to FORMATION, not IDLE).
var active := false
## The deploy cells units can be swapped between.
var cells: Array = []
## The unit picked up to move, or null.
var held: Unit


func _init(owner: BattleInput) -> void:
	input = owner


## The prep screen's Check Map: look around the chapter's map before it starts and
## swap units between the deploy cells. Fight! starts the battle from here.
func start(deploy_cells: Array) -> void:
	active = true
	cells = deploy_cells
	var shown := {}
	for c in cells:
		shown[c] = true
	input.battle.map.deploy_cells = shown
	input.battle.state = Battle.State.BUSY
	await input.battle.ui.show_banner("Check Map", Color("2850b0"))
	input.browse()


## Z: pick up a unit, put it down on a deploy cell (swapping with whoever is
## there), mark an enemy, or open the menu on an empty tile.
func accept() -> void:
	var cell := input.battle.cursor.cell
	var u := input.battle.unit_at(cell)
	if held:
		if u == held:
			drop_held()
		elif can_place(held, cell) and (u == null or can_place(u, held.cell)):
			swap_start_cells(held, cell)
			drop_held()
		return
	if u and u.team == Unit.Team.PLAYER:
		held = u
		input.battle.map.held_cell = u.cell
	elif u:
		input.toggle_mark(u)
	else:
		input.battle.ui.hide_info()
		var options: Array[String] = ["Fight!", "Units", "Objective", "Options", "Back to Prep"]
		input._open_menu("formation", options)


func drop_held() -> void:
	held = null
	input.battle.map.held_cell = Vector2i(-1, -1)
	input.refresh_info()


## Whether `u` may start on `cell`: a deploy cell it can stand on.
func can_place(u: Unit, cell: Vector2i) -> bool:
	return cells.has(cell) and input.battle.map.unit_cost(u, cell) >= 0


## Moves `u` to `cell`; a unit already there takes u's old cell. Saved to
## Campaign.placement so the battle (and a later Check Map) keeps the layout.
func swap_start_cells(u: Unit, cell: Vector2i) -> void:
	var other := input.battle.unit_at(cell)
	if other:
		other.set_cell(u.cell)
	u.set_cell(cell)
	for p in input.battle.units_of(Unit.Team.PLAYER):
		Campaign.placement[p.unit_name] = p.cell
	input.battle.refresh_threat()


func end() -> void:
	held = null
	active = false
	Campaign.checking_map = false
	input.battle.map.deploy_cells = {}
	input.battle.map.held_cell = Vector2i(-1, -1)
	input.battle.map.clear_ranges()
	input.battle.ui.hide_info()


## X (nothing picked up) or Back to Prep: return to the prep screen; the
## placement is kept.
func leave() -> void:
	end()
	input.get_tree().change_scene_to_file(BattlePhases.PREP_SCENE)
