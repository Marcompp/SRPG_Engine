class_name Unit
extends Node2D
## A single unit on the map. Drawn as a colored square with an HP bar.

enum Team { PLAYER, ENEMY }

const PLAYER_COLOR := Color("3a6fd8")
const ENEMY_COLOR := Color("d84a3a")
const ACTED_COLOR := Color("6a6a6a")
const HP_COLOR := Color("5ee05e")
const MP_COLOR := Color("5aa0ff")
## Small corner mark showing a non-foot movement type at a glance.
const MOVE_TYPE_BADGES := {
	"horse": Color("8b5a2b"),
	"rogue": Color("1f5f2a"),
	"flying": Color("f0f0ff"),
	"ship": Color("10204a"),
	"mermaid": Color("3ad0c0"),
}
## MP bar color when there isn't enough MP for any of the unit's spells.
const MP_EMPTY_COLOR := Color("8a8a8a")

var unit_name := ""
var team: Team = Team.PLAYER
var is_lord := false
## Can use Dance to let an adjacent ally that already acted act again.
var is_dancer := false
## Movement type: a key of BattleMap.MOVE_COSTS ("foot", "horse", "rogue", "flying",
## "ship", "mermaid"). Decides terrain costs and whether terrain bonuses apply.
var move_type := "foot"
## Enemy behavior (see AIProfiles), resolved from the roster's "ai" entry.
var ai: Dictionary = AIProfiles.resolve({})
## Whether a sleeping unit's wake condition has fired.
var ai_awake := false
## Set when a player targets this unit; read by the "attacked" wake condition.
var was_attacked := false
## Whether it's currently retreating to heal.
var retreating := false
## Starting cell; the center of a "guard" unit's area.
var anchor := Vector2i.ZERO
var level := 1
var exp_points := 0
## Growth rates in percent, keyed like Experience.STATS ("hp", "str", ...).
var growths := {}
var max_hp := 10
var hp := 10
var strength := 5
var dexterity := 5
var agility := 5
var luck := 0
var defense := 2
var intelligence := 0
var mov := 5
## Everyone has MP: casters spend it on spells, and current MP is also magic
## defense (see Combat.magic_defense). Only casters show an MP bar on the map.
var max_mp := 0
var mp := 0:
	set(value):
		mp = value
		queue_redraw()
var spells: Array[String] = []
const MAX_ITEMS := 5

## Inventory of weapons and consumables (see Items). The first weapon in the
## list is the equipped one.
var items: Array[Dictionary] = []
var weapon: Dictionary:
	get:
		var i := equipped_index()
		return items[i] if i >= 0 else {}
## Equipped weapon's range; 0 when unarmed.
var min_range: int:
	get:
		return weapon.get("min_rng", 0)
var max_range: int:
	get:
		return weapon.get("max_rng", 0)
var cell := Vector2i.ZERO
var has_acted := false:
	set(value):
		has_acted = value
		queue_redraw()


static func create(p_name: String, p_team: Team, p_cell: Vector2i, stats: Dictionary) -> Unit:
	var u := Unit.new()
	u.unit_name = p_name
	u.name = p_name
	u.team = p_team
	u.is_lord = stats.get("lord", false)
	u.is_dancer = stats.get("dancer", false)
	u.move_type = stats.get("move", "foot")
	assert(BattleMap.MOVE_COSTS.has(u.move_type), "unknown move type: " + u.move_type)
	u.ai = AIProfiles.resolve(stats.get("ai", {}))
	u.anchor = p_cell
	u.level = stats.get("lv", 1)
	u.growths = stats.get("growths", {})
	u.max_hp = stats.hp
	u.hp = stats.hp
	u.strength = stats.str
	u.dexterity = stats.dex
	u.agility = stats.agi
	u.luck = stats.lck
	u.defense = stats.def
	u.mov = stats.mov
	u.intelligence = stats.get("int", 0)
	u.max_mp = stats.get("mp", 0)
	u.mp = u.max_mp
	u.spells.assign(stats.get("spells", []))
	for item_name in stats.get("items", []).slice(0, MAX_ITEMS):
		u.items.append(Items.make(item_name))
	u.set_cell(p_cell)
	return u


static func weapon_reaches(w: Dictionary, dist: int) -> bool:
	return not w.is_empty() and dist >= w.min_rng and dist <= w.max_rng


func is_caster() -> bool:
	return not spells.is_empty()


func regen_mp(amount: int) -> void:
	mp = mini(max_mp, mp + amount)
	queue_redraw()


func spend_mp(amount: int) -> void:
	mp -= amount
	queue_redraw()


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	queue_redraw()
	modulate = Color(0.5, 1, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


## Distinct (min, max) reach across the unit's support (true) or offensive (false) spells.
func spell_ranges(support: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for s in spells:
		if Spells.is_support(s) != support:
			continue
		var r := Spells.reach_ranges(s)
		if not result.has(r):
			result.append(r)
	return result


## Whether the equipped weapon can strike at this distance.
func can_attack_at(dist: int) -> bool:
	return weapon_reaches(weapon, dist)


## Index of the equipped weapon in `items`, or -1 when unarmed.
func equipped_index() -> int:
	for i in items.size():
		if Items.is_weapon(items[i]):
			return i
	return -1


func weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if Items.is_weapon(item):
			result.append(item)
	return result


## Moves items[index] to the front, making it the equipped weapon.
func equip(index: int) -> void:
	if index < 0 or not Items.is_weapon(items[index]):
		return
	var w := items[index]
	items.remove_at(index)
	items.push_front(w)


## Spends one use of a consumable and applies it. Removes it when used up.
func use_item(index: int) -> void:
	var item := items[index]
	match item.kind:
		"heal":
			var amount := mini(item.heal, max_hp - hp)
			heal(amount)
			popup("+%d" % amount, Color.PALE_GREEN)
	item.uses -= 1
	if item.uses <= 0:
		items.remove_at(index)


## Distinct (min, max) ranges across all carried weapons.
func weapon_ranges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for w in weapons():
		var r := Vector2i(w.min_rng, w.max_rng)
		if not result.has(r):
			result.append(r)
	return result


func set_cell(c: Vector2i) -> void:
	cell = c
	position = Vector2(c * BattleMap.TILE)


func move_along(path: Array[Vector2i]) -> void:
	cell = path[-1]
	if path.size() <= 1:
		position = Vector2(cell * BattleMap.TILE)
		return
	var tw := create_tween()
	for c in path.slice(1):
		tw.tween_property(self, "position", Vector2(c * BattleMap.TILE), 0.07)
	await tw.finished


func lunge(toward: Vector2i) -> void:
	var base := Vector2(cell * BattleMap.TILE)
	var offset := Vector2(toward - cell).normalized() * 5.0
	var tw := create_tween()
	tw.tween_property(self, "position", base + offset, 0.08)
	tw.tween_property(self, "position", base, 0.1)
	await tw.finished


func notify_attacked() -> void:
	was_attacked = true


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	queue_redraw()
	modulate = Color(1, 0.3, 0.3)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)


## Spends one use of the equipped weapon. Returns true if it broke
## (it is removed, and the next item becomes equipped).
func use_weapon() -> bool:
	var i := equipped_index()
	items[i].uses -= 1
	if items[i].uses <= 0:
		items.remove_at(i)
		return true
	return false


## Floating combat text above the unit.
func popup(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 10
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-12, -8)
	label.size = Vector2(40, 10)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", -16.0, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.tween_callback(label.queue_free)


func die() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_parent().remove_child(self)
	queue_free()


func _draw() -> void:
	var body := ACTED_COLOR if has_acted else (PLAYER_COLOR if team == Team.PLAYER else ENEMY_COLOR)
	draw_rect(Rect2(2, 1, 12, 11), body)
	draw_rect(Rect2(2, 1, 12, 11), Color.BLACK, false, 1.0)
	if is_lord:
		draw_rect(Rect2(5, 0, 6, 2), Color.GOLD)
	if MOVE_TYPE_BADGES.has(move_type):
		draw_rect(Rect2(11, 2, 2, 2), MOVE_TYPE_BADGES[move_type])
	draw_string(ThemeDB.fallback_font, Vector2(2, 10), unit_name.left(1),
		HORIZONTAL_ALIGNMENT_CENTER, 12, 9, Color.WHITE)
	_draw_bar(13, 2, float(hp) / max_hp, HP_COLOR)
	if is_caster():
		# No dark backing for MP, so spent MP doesn't read like missing HP.
		_draw_bar(15, 1, float(mp) / max_mp, MP_COLOR if can_cast_any() else MP_EMPTY_COLOR, false)


## Whether the unit has enough MP for at least one of its spells.
func can_cast_any() -> bool:
	for s in spells:
		if Spells.can_afford(self, s):
			return true
	return false


func _draw_bar(y: float, height: float, fraction: float, color: Color, backing := true) -> void:
	if backing:
		draw_rect(Rect2(2, y, 12, height), Color.BLACK)
	draw_rect(Rect2(2, y, 12.0 * fraction, height), color)
