extends Node2D
## Battle controller: spawns units, runs the turn loop and routes input.

enum State { IDLE, SELECTED, MENU, TARGETING, AREA_TARGET, BUSY, GAME_OVER }

const PLAYER_UNITS := [
	{"name": "Lord", "cell": Vector2i(1, 4), "lord": true, "weapons": ["Iron Sword", "Knife"], "lv": 1,
		"spells": ["Earth Spike"],
		"hp": 18, "str": 5, "mag": 2, "skl": 8, "spd": 9, "lck": 7, "def": 4, "res": 1, "mov": 5, "mp": 8,
		"growths": {"hp": 80, "str": 45, "mag": 20, "skl": 50, "spd": 40, "lck": 45, "def": 30, "res": 30, "mp": 30}},
	{"name": "Fighter", "cell": Vector2i(2, 2), "weapons": ["Iron Axe", "Hatchet"], "lv": 2,
		"hp": 24, "str": 7, "skl": 4, "spd": 5, "lck": 3, "def": 3, "res": 0, "mov": 5,
		"growths": {"hp": 80, "str": 60, "skl": 40, "spd": 20, "lck": 45, "def": 25, "res": 15}},
	{"name": "Knight", "cell": Vector2i(2, 6), "weapons": ["Iron Lance", "Javelin"], "lv": 1,
		"hp": 22, "str": 7, "skl": 4, "spd": 2, "lck": 2, "def": 9, "res": 1, "mov": 4,
		"growths": {"hp": 90, "str": 40, "skl": 30, "spd": 30, "lck": 35, "def": 55, "res": 15}},
	{"name": "Archer", "cell": Vector2i(1, 6), "weapons": ["Iron Bow"], "lv": 1,
		"hp": 18, "str": 5, "skl": 7, "spd": 6, "lck": 4, "def": 3, "res": 1, "mov": 5,
		"growths": {"hp": 60, "str": 40, "skl": 50, "spd": 60, "lck": 50, "def": 15, "res": 25}},
	{"name": "Cleric", "cell": Vector2i(0, 5), "spells": ["Heal"], "lv": 1,
		"hp": 16, "str": 1, "mag": 5, "skl": 5, "spd": 7, "lck": 6, "def": 1, "res": 6, "mov": 5, "mp": 12,
		"growths": {"hp": 50, "str": 10, "mag": 55, "skl": 40, "spd": 45, "lck": 55, "def": 10, "res": 60, "mp": 40}},
	{"name": "Mage", "cell": Vector2i(0, 3), "spells": ["Fire", "Firestorm"], "lv": 1,
		"hp": 16, "str": 1, "mag": 6, "skl": 5, "spd": 6, "lck": 3, "def": 2, "res": 4, "mov": 5, "mp": 14,
		"growths": {"hp": 55, "str": 5, "mag": 60, "skl": 45, "spd": 45, "lck": 30, "def": 15, "res": 40, "mp": 50}},
	{"name": "Dancer", "cell": Vector2i(0, 7), "dancer": true, "lv": 1,
		"hp": 15, "str": 1, "skl": 3, "spd": 10, "lck": 8, "def": 1, "res": 3, "mov": 5,
		"growths": {"hp": 60, "str": 10, "skl": 30, "spd": 65, "lck": 60, "def": 15, "res": 35}},
]
const ENEMY_UNITS := [
	{"name": "Thief", "cell": Vector2i(14, 1), "weapons": ["Knife"], "lv": 1,
		"hp": 16, "str": 3, "skl": 5, "spd": 9, "lck": 2, "def": 1, "res": 1, "mov": 6},
	{"name": "Brigand", "cell": Vector2i(12, 2), "weapons": ["Iron Axe", "Hatchet"], "lv": 2,
		"hp": 20, "str": 5, "skl": 1, "spd": 4, "lck": 0, "def": 3, "res": 0, "mov": 5},
	{"name": "Soldier", "cell": Vector2i(13, 4), "weapons": ["Iron Lance", "Javelin"], "lv": 1,
		"hp": 18, "str": 5, "skl": 3, "spd": 4, "lck": 1, "def": 4, "res": 1, "mov": 5},
	{"name": "Archer", "cell": Vector2i(14, 5), "weapons": ["Iron Bow"], "lv": 2,
		"hp": 17, "str": 5, "skl": 4, "spd": 5, "lck": 1, "def": 2, "res": 1, "mov": 5},
	{"name": "Brigand", "cell": Vector2i(12, 6), "weapons": ["Steel Axe"], "lv": 3,
		"hp": 21, "str": 6, "skl": 2, "spd": 3, "lck": 0, "def": 2, "res": 0, "mov": 5},
	{"name": "Cleric", "cell": Vector2i(14, 7), "spells": ["Heal"], "lv": 2,
		"hp": 15, "str": 1, "mag": 4, "skl": 4, "spd": 6, "lck": 4, "def": 1, "res": 5, "mov": 5, "mp": 10},
	{"name": "Mage", "cell": Vector2i(13, 6), "spells": ["Fire", "Firestorm"], "lv": 2,
		"hp": 15, "str": 1, "mag": 5, "skl": 4, "spd": 5, "lck": 1, "def": 1, "res": 4, "mov": 5, "mp": 12},
	{"name": "Mercenary", "cell": Vector2i(13, 8), "weapons": ["Killing Edge", "Iron Sword"], "lv": 3,
		"hp": 19, "str": 4, "skl": 6, "spd": 8, "lck": 2, "def": 3, "res": 1, "mov": 5},
]

@onready var map: BattleMap = $Map
@onready var units_root: Node2D = $Units
@onready var cursor: Cursor = $Cursor
@onready var ui: BattleUI = $UI

var state := State.BUSY
var selected: Unit
var origin_cell := Vector2i.ZERO
var reach := {}
var menu_context := ""
var targets: Array[Unit] = []
var target_index := 0
## Inventory indices behind each entry of the attack weapon menu.
var weapon_choices: Array[int] = []
## Spell names behind each entry of the magic menu.
var spell_choices: Array[String] = []
## Spell being targeted, or "" when targeting an attack.
var active_spell := ""
## True while TARGETING picks an ally to Dance for.
var dancing := false
## Cells an area spell may be centered on while in AREA_TARGET.
var area_centers: Array[Vector2i] = []


func _ready() -> void:
	for data in PLAYER_UNITS:
		units_root.add_child(Unit.create(data.name, Unit.Team.PLAYER, data.cell, data))
	for data in ENEMY_UNITS:
		units_root.add_child(Unit.create(data.name, Unit.Team.ENEMY, data.cell, data))
	cursor.cell = PLAYER_UNITS[0].cell
	start_player_phase()


# --- Queries -----------------------------------------------------------------

func units() -> Array[Unit]:
	var result: Array[Unit] = []
	for child in units_root.get_children():
		if child is Unit and child.hp > 0:
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


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state == State.BUSY:
		return
	var dir := _dir_from(event)
	var accept := event.is_action_pressed("confirm")
	var cancel := event.is_action_pressed("cancel")
	if dir == Vector2i.ZERO and not accept and not cancel:
		return
	get_viewport().set_input_as_handled()

	match state:
		State.IDLE:
			if dir != Vector2i.ZERO:
				move_cursor(dir)
			elif accept:
				var u := unit_at(cursor.cell)
				if u and u.team == Unit.Team.PLAYER and not u.has_acted:
					select(u)
				elif u == null:
					ui.hide_info()
					var options: Array[String] = ["End Turn"]
					_open_menu("map", options)
		State.SELECTED:
			if dir != Vector2i.ZERO:
				move_cursor(dir)
			elif accept and reach.cells.has(cursor.cell):
				move_selected(cursor.cell)
			elif cancel:
				map.clear_ranges()
				cursor.cell = selected.cell
				selected = null
				state = State.IDLE
				refresh_info()
		State.MENU:
			if dir.y != 0:
				ui.menu_move(dir.y)
			elif accept:
				ui.hide_menu()
				menu_accept()
			elif cancel:
				ui.hide_menu()
				menu_cancel()
		State.TARGETING:
			if dir != Vector2i.ZERO:
				var step := 1 if dir.x + dir.y > 0 else -1
				target_index = wrapi(target_index + step, 0, targets.size())
				show_target()
			elif accept:
				ui.hide_forecast()
				state = State.BUSY
				if dancing:
					await do_dance(selected, targets[target_index])
				elif active_spell and Spells.is_support(active_spell):
					await cast_heal(selected, targets[target_index], active_spell)
				elif active_spell:
					await do_spell_attack(selected, targets[target_index], active_spell)
				else:
					await do_combat(selected, targets[target_index])
				finish_action()
			elif cancel:
				ui.hide_forecast()
				cursor.cell = selected.cell
				if dancing:
					open_unit_menu()
				elif active_spell:
					open_magic_menu()
				else:
					open_attack_menu()
		State.AREA_TARGET:
			if dir != Vector2i.ZERO:
				if area_centers.has(cursor.cell + dir):
					cursor.cell += dir
					show_area_preview()
			elif accept:
				if Spells.can_cast_at(selected, active_spell, cursor.cell, units(), map):
					ui.hide_forecast()
					state = State.BUSY
					await cast_area(selected, cursor.cell, active_spell)
					finish_action()
			elif cancel:
				ui.hide_forecast()
				map.clear_ranges()
				cursor.cell = selected.cell
				open_magic_menu()
		State.GAME_OVER:
			if accept:
				get_tree().reload_current_scene()


func _dir_from(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_left", true):
		return Vector2i.LEFT
	if event.is_action_pressed("ui_right", true):
		return Vector2i.RIGHT
	if event.is_action_pressed("ui_up", true):
		return Vector2i.UP
	if event.is_action_pressed("ui_down", true):
		return Vector2i.DOWN
	return Vector2i.ZERO


func move_cursor(dir: Vector2i) -> void:
	cursor.cell = (cursor.cell + dir).clamp(Vector2i.ZERO, Vector2i(map.cols - 1, map.rows - 1))
	refresh_info()


func refresh_info() -> void:
	ui.update_info(unit_at(cursor.cell), map.terrain_at(cursor.cell), cursor.cell)


# --- Player actions ----------------------------------------------------------

func select(u: Unit) -> void:
	selected = u
	origin_cell = u.cell
	reach = map.get_reachable(u, units())
	var offense := u.weapon_ranges()
	for r in u.spell_ranges(false):
		if not offense.has(r):
			offense.append(r)
	map.show_ranges(reach.cells.keys(), map.get_attack_cells(reach.cells, offense),
		map.get_attack_cells(reach.cells, u.spell_ranges(true)))
	state = State.SELECTED
	refresh_info()


func move_selected(dest: Vector2i) -> void:
	state = State.BUSY
	map.clear_ranges()
	ui.hide_info()
	await selected.move_along(map.build_path(reach.parents, selected.cell, dest))
	open_unit_menu()


func enemies_in_range(u: Unit, w: Dictionary) -> Array[Unit]:
	var result: Array[Unit] = []
	for e in units_of(Unit.Team.ENEMY):
		if Unit.weapon_reaches(w, BattleMap.distance(u.cell, e.cell)):
			result.append(e)
	return result


func can_attack_any(u: Unit) -> bool:
	for w in u.items:
		if not enemies_in_range(u, w).is_empty():
			return true
	return false


## Spells the unit can afford and that have a valid target from its current cell.
func castable_spells(u: Unit) -> Array[String]:
	var result: Array[String] = []
	for s in u.spells:
		if Spells.can_afford(u, s) and Spells.has_targets(u, s, units(), map):
			result.append(s)
	return result


func weapon_label(w: Dictionary) -> String:
	return "%s  %d" % [w.name, w.uses]


func open_unit_menu() -> void:
	var options: Array[String] = []
	if can_attack_any(selected):
		options.append("Attack")
	if not castable_spells(selected).is_empty():
		options.append("Magic")
	if not dance_targets(selected).is_empty():
		options.append("Dance")
	if not selected.items.is_empty():
		options.append("Items")
	options.append("Wait")
	_open_menu("unit", options)


## Weapon choice for Attack: only weapons that can reach an enemy are listed.
func open_attack_menu() -> void:
	var options: Array[String] = []
	weapon_choices = []
	for i in selected.items.size():
		if not enemies_in_range(selected, selected.items[i]).is_empty():
			options.append(weapon_label(selected.items[i]))
			weapon_choices.append(i)
	_open_menu("attack", options)


func open_magic_menu() -> void:
	spell_choices = castable_spells(selected)
	var options: Array[String] = []
	for s in spell_choices:
		options.append("%s  %dMP" % [s, Spells.get_spell(s).mp])
	_open_menu("magic", options)


## Inventory view; picking a weapon equips it (does not end the unit's turn).
func open_items_menu() -> void:
	var options: Array[String] = []
	for i in selected.items.size():
		options.append(weapon_label(selected.items[i]) + ("  (E)" if i == 0 else ""))
	_open_menu("items", options)


func _open_menu(context: String, options: Array[String]) -> void:
	menu_context = context
	ui.show_menu(options, selected.cell if selected else cursor.cell)
	state = State.MENU


func menu_accept() -> void:
	match menu_context:
		"map":
			end_player_phase()
		"unit":
			match ui.menu_choice():
				"Attack":
					open_attack_menu()
				"Magic":
					open_magic_menu()
				"Dance":
					start_dance_targeting()
				"Items":
					open_items_menu()
				"Wait":
					finish_action()
		"attack":
			selected.equip(weapon_choices[ui.menu_index])
			start_targeting()
		"magic":
			start_spell_targeting(spell_choices[ui.menu_index])
		"items":
			selected.equip(ui.menu_index)
			open_items_menu()


func menu_cancel() -> void:
	match menu_context:
		"map":
			state = State.IDLE
			refresh_info()
		"unit":
			selected.set_cell(origin_cell)
			cursor.cell = origin_cell
			select(selected)
		"attack", "magic", "items":
			open_unit_menu()


func start_targeting() -> void:
	active_spell = ""
	dancing = false
	targets = enemies_in_range(selected, selected.weapon)
	target_index = 0
	state = State.TARGETING
	show_target()


func start_spell_targeting(spell_name: String) -> void:
	active_spell = spell_name
	dancing = false
	if Spells.get_spell(spell_name).target == "area":
		start_area_targeting()
		return
	targets = Spells.targets_for(selected, spell_name, units())
	target_index = 0
	state = State.TARGETING
	show_target()


func show_target() -> void:
	var target := targets[target_index]
	cursor.cell = target.cell
	if dancing:
		ui.show_dance_forecast(target, cursor.cell)
	elif active_spell and Spells.is_support(active_spell):
		var spell := Spells.get_spell(active_spell)
		ui.show_heal_forecast(selected, target, active_spell, Spells.heal_amount(selected, spell, target), cursor.cell)
	elif active_spell:
		var spell := Spells.get_spell(active_spell)
		ui.show_forecast(selected, target, Combat.spell_forecast(selected, target, spell, map), cursor.cell, active_spell)
	else:
		ui.show_forecast(selected, target, Combat.forecast(selected, target, map), cursor.cell)


## Free cursor limited to the spell's cast range; starts on the center hitting the most enemies.
func start_area_targeting() -> void:
	area_centers = Spells.area_centers(selected, active_spell, map, units())
	var best := selected.cell
	var best_count := -1
	for c in area_centers:
		var count := Spells.area_targets(selected, active_spell, c, units(), map).size()
		if count > best_count:
			best = c
			best_count = count
	cursor.cell = best
	state = State.AREA_TARGET
	show_area_preview()


func current_area_victims() -> Array[Unit]:
	return Spells.area_targets(selected, active_spell, cursor.cell, units(), map)


func show_area_preview() -> void:
	map.show_area(area_centers, Spells.area_cells(active_spell, cursor.cell, map))
	var spell := Spells.get_spell(active_spell)
	var rows: Array = []
	for v in current_area_victims():
		rows.append([v.unit_name, v.hp, Combat.spell_damage(selected, v, spell, map),
			Combat.spell_hit_chance(selected, v, spell, map)])
	var note := ""
	if spell.has("terraform"):
		note = "%s -> %s" % [map.terrain_at(cursor.cell).name, BattleMap.TERRAIN[spell.terraform].name]
	ui.show_area_forecast(selected, active_spell, rows, cursor.cell, note)


## Adjacent allies who have already acted this phase.
func dance_targets(u: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if not u.is_dancer:
		return result
	for ally in units_of(u.team):
		if ally != u and ally.has_acted and BattleMap.distance(u.cell, ally.cell) == 1:
			result.append(ally)
	return result


func start_dance_targeting() -> void:
	active_spell = ""
	dancing = true
	targets = dance_targets(selected)
	target_index = 0
	state = State.TARGETING
	show_target()


## Refreshes the target so it can move and act again this phase.
func do_dance(dancer: Unit, target: Unit) -> void:
	dancer.popup("Dance", Color.PINK)
	await dancer.lunge(target.cell)
	target.has_acted = false
	target.popup("Refreshed", Color.PINK)
	await get_tree().create_timer(0.5).timeout
	if dancer.level < Experience.LEVEL_CAP:
		await gain_exp(dancer, Experience.DANCE_EXP)


func cast_heal(caster: Unit, target: Unit, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var amount := Spells.heal_amount(caster, spell, target)
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	await caster.lunge(target.cell)
	target.heal(amount)
	target.popup("+%d" % amount, Color.PALE_GREEN)
	await get_tree().create_timer(0.5).timeout
	if caster.team == Unit.Team.PLAYER and caster.level < Experience.LEVEL_CAP:
		await gain_exp(caster, spell.exp)


func do_combat(attacker: Unit, defender: Unit) -> void:
	# A unit whose weapon breaks makes no further strikes this combat (as in GBA FE),
	# even though its next item is equipped right away.
	var broke: Array[Unit] = []
	var dealt: Array[Unit] = []
	for pair in Combat.strike_order(attacker, defender):
		var a: Unit = pair[0]
		var d: Unit = pair[1]
		if a.hp <= 0 or d.hp <= 0:
			break
		if a.weapon.is_empty() or broke.has(a):
			continue
		var result := Combat.strike(a, d, map)
		await a.lunge(d.cell)
		_apply_strike(a, d, result, dealt)
		if result.hit and a.use_weapon():
			broke.append(a)
			a.popup("Broke!", Color.LIGHT_GRAY)
		await get_tree().create_timer(0.45).timeout
	await _finish_exchange(attacker, defender, dealt)


## Single-target damage spell: one cast (never doubles), then the target may counter once.
func do_spell_attack(caster: Unit, target: Unit, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var dealt: Array[Unit] = []
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	var result := Combat.spell_strike(caster, target, spell, map)
	await caster.lunge(target.cell)
	_apply_strike(caster, target, result, dealt)
	await get_tree().create_timer(0.45).timeout
	if target.hp > 0 and Combat.can_counter(caster, target):
		var counter := Combat.strike(target, caster, map)
		await target.lunge(caster.cell)
		_apply_strike(target, caster, counter, dealt)
		if counter.hit and target.use_weapon():
			target.popup("Broke!", Color.LIGHT_GRAY)
		await get_tree().create_timer(0.45).timeout
	await _finish_exchange(caster, target, dealt)


## Area spell: separate hit roll per enemy in the blast, no counters.
## Terraforming spells then change the target cell, hit or miss.
func cast_area(caster: Unit, center: Vector2i, spell_name: String) -> void:
	var spell := Spells.get_spell(spell_name)
	var victims := Spells.area_targets(caster, spell_name, center, units(), map)
	caster.spend_mp(spell.mp)
	caster.popup(spell_name, Color.LIGHT_SKY_BLUE)
	await caster.lunge(center)
	map.show_area([], Spells.area_cells(spell_name, center, map))
	var damaged: Array[Unit] = []
	for v in victims:
		var result := Combat.spell_strike(caster, v, spell, map)
		var dealt: Array[Unit] = []
		_apply_strike(caster, v, result, dealt)
		if not dealt.is_empty():
			damaged.append(v)
	if spell.has("terraform"):
		map.set_terrain(center, spell.terraform)
	await get_tree().create_timer(0.6).timeout
	map.clear_ranges()
	# EXP: sum of what each target would give, capped at one level.
	var awards: Array = []
	if caster.team == Unit.Team.PLAYER and caster.level < Experience.LEVEL_CAP and not victims.is_empty():
		var total := 0
		for v in victims:
			total += Experience.combat_exp(caster, v, damaged.has(v), v.hp <= 0)
		awards.append([caster, mini(total, Experience.EXP_PER_LEVEL)])
	await _remove_dead_and_award(victims, awards)


## Applies one strike's result with popups; records the striker in `dealt` if it did damage.
func _apply_strike(a: Unit, d: Unit, result: Dictionary, dealt: Array[Unit]) -> void:
	if result.hit:
		d.take_damage(result.dmg)
		if result.dmg > 0 and not dealt.has(a):
			dealt.append(a)
		d.popup(("Crit! %d" if result.crit else "%d") % result.dmg,
			Color.ORANGE if result.crit else Color.WHITE)
	else:
		d.popup("Miss", Color.LIGHT_GRAY)


## EXP for both sides of a one-on-one exchange, then deaths.
func _finish_exchange(attacker: Unit, defender: Unit, dealt: Array[Unit]) -> void:
	# Work out EXP before dead units are freed.
	var awards: Array = []
	for pair in [[attacker, defender], [defender, attacker]]:
		var u: Unit = pair[0]
		var foe: Unit = pair[1]
		if u.team == Unit.Team.PLAYER and u.hp > 0 and u.level < Experience.LEVEL_CAP:
			awards.append([u, Experience.combat_exp(u, foe, dealt.has(u), foe.hp <= 0)])
	var involved: Array[Unit] = [attacker, defender]
	await _remove_dead_and_award(involved, awards)


func _remove_dead_and_award(involved: Array[Unit], awards: Array) -> void:
	for u in involved:
		if u.hp <= 0:
			await u.die()
	for award in awards:
		await gain_exp(award[0], award[1])


func gain_exp(u: Unit, amount: int) -> void:
	u.popup("+%d EXP" % amount, Color.AQUAMARINE)
	await get_tree().create_timer(0.5).timeout
	u.exp_points += amount
	while u.exp_points >= Experience.EXP_PER_LEVEL and u.level < Experience.LEVEL_CAP:
		u.exp_points -= Experience.EXP_PER_LEVEL
		var gains := Experience.roll_level_up(u)
		var before := {}
		for key in Experience.STATS:
			before[key] = u.get(Experience.STATS[key])
		Experience.apply_level_up(u, gains)
		await ui.show_level_up(u, before, gains)
	if u.level >= Experience.LEVEL_CAP:
		u.exp_points = 0


func finish_action() -> void:
	if is_instance_valid(selected) and selected.hp > 0:
		selected.has_acted = true
		cursor.cell = selected.cell
	selected = null
	map.clear_ranges()
	if check_game_over():
		return
	for u in units_of(Unit.Team.PLAYER):
		if not u.has_acted:
			state = State.IDLE
			refresh_info()
			return
	end_player_phase()


# --- Phases ------------------------------------------------------------------

func start_player_phase() -> void:
	state = State.BUSY
	ui.hide_info()
	for u in units():
		u.has_acted = false
	for u in units_of(Unit.Team.PLAYER):
		u.regen_mp(Spells.MP_REGEN)
	await ui.show_banner("Player Phase", Color("2850b0"))
	var players := units_of(Unit.Team.PLAYER)
	if not players.is_empty():
		cursor.cell = players[0].cell
	state = State.IDLE
	refresh_info()


func end_player_phase() -> void:
	state = State.BUSY
	ui.hide_info()
	await ui.show_banner("Enemy Phase", Color("b02828"))
	for e in units_of(Unit.Team.ENEMY):
		e.regen_mp(Spells.MP_REGEN)
	for e in units_of(Unit.Team.ENEMY):
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		await EnemyAI.take_turn(e, self)
		if check_game_over():
			return
	start_player_phase()


func check_game_over() -> bool:
	if units_of(Unit.Team.ENEMY).is_empty():
		state = State.GAME_OVER
		ui.show_end("Victory!", Color("2850b0"))
		return true
	var lord_alive := false
	for u in units_of(Unit.Team.PLAYER):
		if u.is_lord:
			lord_alive = true
	if not lord_alive:
		state = State.GAME_OVER
		ui.show_end("Defeat...", Color("602020"))
		return true
	return false
