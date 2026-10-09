class_name BattlePhases
extends Node
## Turn flow: player and enemy phases, reinforcements, game over, and
## leaving the battle (campaign, suspend/resume).

var battle: Battle

const PREP_SCENE := "res://scenes/prep.tscn"


# --- Phases -------------------------------------------------------------------

func start_player_phase() -> void:
	battle.state = Battle.State.BUSY
	battle.enemy_phase = false
	battle.ui.hide_info()
	# Every unit, including carried ones, so passengers can act once set down.
	for u in battle.units_root.get_children():
		if u is Unit:
			u.has_acted = false
			u.refreshed = false
			u.refresh_pending = false
	clear_inspire(Unit.Team.PLAYER)
	for u in battle.units_of(Unit.Team.PLAYER):
		u.regen_mp(u.mp_regen())
	battle.turn += 1
	await battle.ui.show_banner("Player Phase\n" + battle.turn_text(), Color("2850b0"))
	await heal_on_tiles(Unit.Team.PLAYER)
	await battle.events.on_turn(battle.turn, "player")
	if check_game_over():
		return
	var players := battle.units_of(Unit.Team.PLAYER)
	if not players.is_empty():
		battle.cursor.cell = players[0].cell
	battle.refresh_threat()
	# Turn rewind can come back here.
	battle.turn_history.append(SaveGame.capture(battle, false))
	# Auto save: the turn can be resumed from here (level select > Resume).
	if Settings.value("auto_save"):
		SaveGame.write_suspend(battle)
	battle.state = Battle.State.IDLE
	battle.input.refresh_info()


## Inspire lasts until the start of the inspired side's next phase.
func clear_inspire(team: Unit.Team) -> void:
	for u in battle.units_root.get_children():
		if u is Unit and u.team == team:
			u.inspire_bonus = 0


## Healing tiles (e.g. Forts), regeneration (Trolls) and allies' Prayer restore a
## share of max HP to `team`'s units at the start of that team's phase.
func heal_on_tiles(team: Unit.Team) -> void:
	var healed := false
	for u in battle.units_of(team):
		var rate: float = battle.map.terrain_heal(u.cell) + Skills.turn_heal(u)
		for ally in battle.units_of(team):
			if ally != u and BattleMap.distance(ally.cell, u.cell) == 1:
				rate += Skills.ally_turn_heal(ally)
		if rate > 0.0 and u.hp < u.max_hp:
			var amount := mini(ceili(u.max_hp * rate), u.max_hp - u.hp)
			u.heal(amount)
			u.popup("+%d" % amount, Color.PALE_GREEN)
			healed = true
	if healed:
		await get_tree().create_timer(0.5).timeout


func end_player_phase() -> void:
	battle.state = Battle.State.BUSY
	battle.enemy_phase = true
	battle.ui.hide_info()
	await battle.ui.show_banner("Enemy Phase", Color("b02828"))
	clear_inspire(Unit.Team.ENEMY)
	for e in battle.units_of(Unit.Team.ENEMY):
		e.regen_mp(e.mp_regen())
	await heal_on_tiles(Unit.Team.ENEMY)
	await spawn_reinforcements()
	await battle.events.on_turn(battle.turn, "enemy")
	EnemyAI.update_all_wake(battle)
	for e in battle.units_of(Unit.Team.ENEMY):
		# has_acted: reinforcements that just arrived wait for the next phase.
		if not is_instance_valid(e) or e.hp <= 0 or e.has_acted:
			continue
		await EnemyAI.take_turn(e, battle)
		if is_instance_valid(e) and e.hp > 0:
			await battle.events.on_area(e)
		if check_game_over():
			return
		# Galeforce: one more turn.
		if is_instance_valid(e) and e.hp > 0 and e.refresh_pending:
			e.refresh_pending = false
			e.has_acted = false
			await EnemyAI.take_turn(e, battle)
			if check_game_over():
				return
	if check_game_over(true):
		return
	start_player_phase()


## The level's reinforcements for this turn appear on their cell, or the nearest
## free cell they can stand on within 2 tiles (blocked otherwise), and wait a phase.
func spawn_reinforcements() -> void:
	var arrived := false
	for wave in Levels.get_level(Levels.selected).get("reinforcements", []):
		if wave.turn != battle.turn:
			continue
		for data in wave.units:
			var u := Unit.create(data.name, Unit.Team.ENEMY, data.cell, data)
			var cell := _free_cell_near(u, data.cell)
			if cell == Vector2i(-1, -1):
				u.free()
				continue
			u.set_cell(cell)
			u.has_acted = true
			battle.units_root.add_child(u)
			arrived = true
	if arrived:
		battle.refresh_threat()
		await battle.ui.show_banner("Reinforcements!", Color("b02828"))


func _free_cell_near(u: Unit, origin: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := origin + Vector2i(dx, dy)
			if absi(dx) + absi(dy) > 2 or battle.unit_at(c) != null or not battle.can_stand_on(u, c):
				continue
			if best == Vector2i(-1, -1) or BattleMap.distance(origin, c) < BattleMap.distance(origin, best):
				best = c
	return best


## Checks the map objective (see Objectives); `turn_over` is true right after an
## enemy phase ends, when survive/defend maps count a turn as done.
func check_game_over(turn_over := false) -> bool:
	if battle.state == Battle.State.GAME_OVER:
		return true
	var result := Objectives.result(battle, turn_over)
	if result == "":
		return false
	battle.enemy_phase = false
	battle.state = Battle.State.GAME_OVER
	battle.battle_result = result
	discard_suspend()
	var won := result == "victory"
	var hint := "Z: restart   X: level select"
	if Campaign.active:
		var last := Campaign.chapter >= Chapters.ORDER.size() - 1
		hint = ("Z: continue" if not last else "Z: finish the campaign") if won \
			else "Z: retry the chapter   X: level select"
	_show_end(won, hint)
	return true


## The map's victory/defeat scene (if any), then the end screen.
func _show_end(won: bool, hint: String) -> void:
	await battle.events.on_end(battle.battle_result)
	battle.ui.show_end("Victory!" if won else "Defeat...", Color("2850b0") if won else Color("602020"), hint)


# --- Campaign flow (see Campaign) ---------------------------------------------

## End screen, Z: after a win, bank the chapter and move on; after a loss, retry it
## with the army as it was before (the last campaign save).
func continue_campaign() -> void:
	if battle.battle_result == "victory":
		Campaign.finish_chapter(battle)
	else:
		Campaign.load_save()
	if Campaign.is_complete():
		Campaign.active = false
		get_tree().change_scene_to_file(Battle.LEVEL_SELECT_SCENE)
	else:
		get_tree().change_scene_to_file(PREP_SCENE)


# --- Suspend / resume (see SaveGame) ------------------------------------------

## Map menu > Suspend: save the battle and go back to the level select, which then
## offers to resume it.
func suspend() -> void:
	SaveGame.write_suspend(battle)
	get_tree().change_scene_to_file(Battle.LEVEL_SELECT_SCENE)


## Rebuilds a suspended battle and picks the player phase up where it stopped.
func resume_suspended() -> void:
	var data := SaveGame.read_suspend()
	# A campaign chapter needs the campaign it belongs to (army, convoy, chapter).
	Campaign.active = data.get("campaign", false) and Campaign.load_save()
	battle.events.load_for(data.level)
	SaveGame.restore(battle, data)
	_resume_player_phase()


## Whether the map menu offers Rewind: uses left and an earlier turn start to go to.
func can_rewind() -> bool:
	return battle.rewinds_left != 0 and not battle.turn_history.is_empty()


## Turn rewind: back to the start of the player phase of turn_history[index]. Later
## snapshots are dropped and a use is spent. Rebuilds the battle in place.
func rewind_to(index: int) -> void:
	var snapshot: Dictionary = battle.turn_history[index]
	var history := battle.turn_history.slice(0, index + 1)
	var left := battle.rewinds_left - 1 if battle.rewinds_left > 0 else battle.rewinds_left
	battle.state = Battle.State.BUSY
	battle.input.selected = null
	battle.map.clear_ranges()
	for child in battle.units_root.get_children():
		battle.units_root.remove_child(child)
		child.queue_free()
	SaveGame.restore(battle, snapshot)
	battle.turn_history = history
	battle.rewinds_left = left
	if Settings.value("auto_save"):
		SaveGame.write_suspend(battle)
	var players := battle.units_of(Unit.Team.PLAYER)
	battle.cursor.cell = players[0].cell if not players.is_empty() else Vector2i.ZERO
	battle.camera.snap(battle.cursor.cell)
	await battle.ui.show_banner("Rewound to\n" + battle.turn_text(), Color("4a3a8a"))
	_resume_player_phase()


func _resume_player_phase() -> void:
	var players := battle.units_of(Unit.Team.PLAYER)
	battle.cursor.cell = players[0].cell if not players.is_empty() else Vector2i.ZERO
	battle.enemy_phase = false
	battle.refresh_threat()
	battle.state = Battle.State.IDLE
	battle.input.refresh_info()


## A map that ended can't be resumed.
func discard_suspend() -> void:
	var data := SaveGame.read_suspend()
	if not data.is_empty() and data.level == Levels.selected:
		SaveGame.delete_suspend()
