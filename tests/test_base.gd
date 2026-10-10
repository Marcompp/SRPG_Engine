extends RefCounted
## Shared state and helpers for the test suites (tests/test_*.gd, each extending this
## file). The runner (tests/run_tests.gd) hands every suite the SceneTree, then runs
## each of its test_ methods on a fresh battle scene. Tests should place the units
## they use explicitly, since the starting map is crowded.

const MAIN_SCENE := "res://scenes/main.tscn"

## The runner (a SceneTree): holds the current battle and the failures.
var tree
var root: Window
var process_frame: Signal
## The battle scene under test (kept on the runner, which frees it after each test).
var b: Node:
	get:
		return tree.b
	set(value):
		tree.b = value


func setup(runner) -> void:
	tree = runner
	root = runner.root
	process_frame = runner.process_frame


func create_timer(seconds: float) -> SceneTreeTimer:
	return tree.create_timer(seconds)


func check(condition: bool, message: String) -> void:
	if not condition:
		tree.failures.append("%s: %s" % [tree.current_test, message])


## Builds the battle scene and waits until it takes input (`ready_state`: IDLE in the
## player phase, FORMATION for Check Map).
func _fresh_battle(ready_state := Battle.State.IDLE) -> void:
	b = load(MAIN_SCENE).instantiate()
	# Nobody presses Z in tests: level-ups time out instead (see test_level_up_waits_for_confirm).
	b.get_node("UI").level_up_waits = false
	DialogueBox.auto_advance = true  # event dialogue continues on its own
	root.add_child(b)
	while b.state != ready_state:
		await process_frame


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])


func unit_named(unit_name: String, team: int = Unit.Team.PLAYER) -> Unit:
	for u in b.units():
		if u.unit_name == unit_name and u.team == team:
			return u
	return null


## Moves every unit except `keep` far out of the way (bottom-right open cells).
func clear_board(keep: Array) -> void:
	var parking := [Vector2i(14, 9), Vector2i(13, 9), Vector2i(12, 9), Vector2i(11, 9), Vector2i(10, 9),
		Vector2i(9, 9), Vector2i(8, 9), Vector2i(14, 8), Vector2i(13, 8), Vector2i(14, 6), Vector2i(13, 6),
		Vector2i(12, 6), Vector2i(14, 4), Vector2i(13, 4), Vector2i(12, 4), Vector2i(14, 3), Vector2i(14, 2),
		Vector2i(13, 2)]
	var i := 0
	for u in b.units():
		if not keep.has(u):
			u.set_cell(parking[i])
			i += 1


func press(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	b.input._unhandled_input(e)
	await process_frame
	while b.state == b.State.BUSY:
		await process_frame


func pick(option: String) -> void:
	if not b.ui.menu_options.has(option):
		check(false, "menu has no '%s' (options: %s)" % [option, b.ui.menu_options])
		return
	while b.ui.menu_choice() != option:
		await press(KEY_DOWN)
	await press(KEY_Z)


func _texts(screen: StatusScreen) -> Array:
	var result := []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label and node.is_visible_in_tree():
			result.append(node.text)
		stack.append_array(node.get_children())
	return result


## Removes every unit except `keep`, so AI tests only see the units they set up.
func isolate(keep: Array) -> void:
	for u in b.units():
		if not keep.has(u):
			u.get_parent().remove_child(u)
			u.queue_free()


## Puts a fresh copy of `weapon_name` first in `u`'s inventory (equipped).
func give_weapon(u: Unit, weapon_name: String) -> void:
	u.items.push_front(Items.make(weapon_name))


## Back to default options (removes the test settings file).
func reset_settings() -> void:
	DirAccess.remove_absolute(Settings.path)
	Settings.reload()


## Starts campaign chapter `index` with a fresh campaign whose army has every
## recruit up to it, deployed by default.
func start_chapter(index: int) -> void:
	Campaign.start_new()
	for i in range(1, index + 1):
		Campaign.chapter = i
		Campaign.add_recruits()
	Campaign.active = true
	Campaign.deployed = Campaign.default_deployment()
	Levels.selected = Chapters.ORDER[index]
	b.queue_free()
	await process_frame
	await _fresh_battle()


func remove_unit(u: Unit) -> void:
	u.get_parent().remove_child(u)
	u.free()


func start_level(id: String) -> void:
	Levels.selected = id
	b.queue_free()
	await process_frame
	await _fresh_battle()
	Levels.selected = "river_crossing"


## Selects `u` and opens its menu without moving it.
func open_menu_in_place(u: Unit) -> void:
	b.cursor.cell = u.cell
	await press(KEY_Z)
	await press(KEY_Z)


## Lord (Iron Sword) next to a Brigand (Iron Axe), everyone else gone.
func _duel() -> Array[Unit]:
	var lord := unit_named("Lord")
	var brig := unit_named("Brigand", Unit.Team.ENEMY)
	isolate([lord, brig])
	await process_frame
	lord.set_cell(Vector2i(5, 6))
	brig.set_cell(Vector2i(6, 6))
	brig.equip(0)
	return [lord, brig]


## A plain enemy Brigand on `cell` (for tests that need more foes than _duel leaves).
func _spawn_enemy(cell: Vector2i, hp := 20) -> Unit:
	var u := Unit.create("Brigand", Unit.Team.ENEMY, cell, {"class": "Brigand", "items": ["Iron Axe"],
		"hp": hp, "str": 5, "dex": 1, "agi": 0, "lck": 0, "def": 3, "mov": 5})
	b.units_root.add_child(u)
	return u


## Plays a few full turns (player phase ends, enemies act) and checks the battle
## loop settles; shared by the per-map smoke tests.
func run_enemy_phases() -> void:
	for turn in 3:
		if b.state == b.State.GAME_OVER:
			break
		b.phases.end_player_phase()
		while b.state != b.State.IDLE and b.state != b.State.GAME_OVER:
			await process_frame
	check(b.state == b.State.IDLE or b.state == b.State.GAME_OVER, "battle loop settles")


## Puts `u` on a fresh mount of `species` (as its foot class `foot`). Pegasi only
## take female riders, so pegasus riders become female.
func ride(u: Unit, species: String, foot := "Footman", level := 1) -> void:
	if species == "Pegasus":
		u.gender = "female"
	u.dismount()
	u.set_class(foot)
	u.mount_up(Mounts.generate(species, level))
