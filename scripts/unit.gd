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
	"swim": Color("8fd0ff"),
	"climb": Color("b0b0b0"),
	"swim_climb": Color("8a6fd0"),
	"rogue_swim_climb": Color("3f8f6a"),
	"heavy": Color("505860"),
	"spirit": Color("c070ff"),
}
## Corner pip on units under an Inspire buff.
const INSPIRED_COLOR := Color("ffb030")
## MP bar color when there isn't enough MP for any of the unit's spells.
const MP_EMPTY_COLOR := Color("8a8a8a")

var unit_name := ""
var team: Team = Team.PLAYER
var is_lord := false
## Class name, a key of Classes.DATA. set_class() copies what the class and race
## decide (move type, tags, mounted, weapon types, abilities) into the fields below.
var unit_class := ""
## Movement type: one of BattleMap.MOVE_TYPES. Decides terrain costs and
## whether terrain bonuses apply. The race can override the class's (see Races).
var move_type := "foot"
## Effectiveness tags: the class's move type plus the race's tags. Weapons are
## effective against these, and Combat.TAG_TRAITS gives weaknesses/resistances.
var tags: Array[String] = []
## Race: a key of Races.DATA (roster "race", default "Human").
var race := "Human"
## Possible values of `gender`.
const GENDERS: Array[String] = ["male", "female"]
## Hidden: never shown to the player, but rules can check it (e.g. mounts that only
## accept some riders). Roster "gender"; generics without one get a random gender.
var gender: String = GENDERS.pick_random()
## Notable events in this unit's story, oldest first (roster "bio"); shown on the
## status screen's Biography page. Player units only.
var biography: Array[String] = []
## Mounted units can Rescue allies, and can't Shove, be Shoved or be Rescued.
var mounted := false
## Weapon types the unit can equip (see Weapons). Others can still be carried.
var weapon_types: Array[String] = []
## Class abilities: "ship" (see Classes). Other special commands are skills.
var abilities: Array[String] = []
## Personal skills (roster "skills"); see Skills for every other source.
var personal_skills: Array[String] = []
## Personal level-up skills (roster "learn": {level: skill}), on top of the class's.
var learn_table := {}
## Skills learned from level-ups and scrolls, kept for good (at most Skills.LEARNED_CAP).
var learned: Array[String] = []
## Rescue (Thracia 776 style): the ally this unit is carrying, or null. A carried
## unit is off the map (hidden, excluded from Battle.units()) until dropped.
var carrying: Unit
## Units aboard this ship (see Classes "ship"); off the map like a carried unit.
var passengers: Array[Unit] = []
## The unit (rescuer or ship) carrying this one, or null.
var carried_by: Unit
## Left the map through an exit (escape objective): off the map but alive.
var escaped := false
## STR/DEF bonus from an Inspire; cleared at the start of the unit's next phase.
var inspire_bonus := 0:
	set(value):
		inspire_bonus = value
		queue_redraw()
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
## Computed properties (getters over other fields) that suspend saves must skip:
## they're rebuilt from the fields they read. Add any new computed property here.
const SAVE_SKIP: Array[String] = ["mov", "weapon", "min_range", "max_range"]
## MOV from the roster and level-ups; `mov` adds the race's bonus (see Races).
var base_mov := 5
var mov_bonus := 0
var mov: int:
	get:
		return base_mov + mov_bonus + Skills.stat_bonus(self, "mov")
	set(value):
		base_mov = value
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
	u.race = stats.get("race", "Human")
	assert(Races.DATA.has(u.race), "unknown race: " + u.race)
	u.gender = stats.get("gender", u.gender)
	assert(GENDERS.has(u.gender), "unknown gender: " + u.gender)
	u.biography.assign(stats.get("bio", []))
	u.personal_skills.assign(stats.get("skills", []))
	u.learn_table = stats.get("learn", {})
	u.set_class(stats["class"])
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
	# Starting above level 1: it already knows what its learn tables teach by now.
	for lv in range(1, u.level + 1):
		for skill in u.skills_learned_at(lv):
			if not u.learned.has(skill) and not Skills.has(u, skill):
				u.learned.append(skill)
	u.learned.assign(u.learned.slice(-Skills.LEARNED_CAP))
	u.set_cell(p_cell)
	return u


static func weapon_reaches(w: Dictionary, dist: int) -> bool:
	return not w.is_empty() and dist >= w.min_rng and dist <= w.max_rng


## Applies a class (also how promotion will change it; the level is kept).
func set_class(class_id: String) -> void:
	var data := Classes.get_data(class_id)
	assert(Races.allows(race, class_id), "%s can't be a %s" % [race, class_id])
	unit_class = class_id
	move_type = Races.move_type(race, class_id)
	assert(BattleMap.MOVE_TYPES.has(move_type), "unknown move type: " + move_type)
	mov_bonus = Races.bonus_mov(race, class_id)
	tags.assign([data.move])
	for tag: String in Races.get_data(race).get("tags", []):
		if not tags.has(tag):
			tags.append(tag)
	mounted = data.get("mounted", false)
	weapon_types.assign(data.weapons)
	abilities.assign(data.get("abilities", []))
	queue_redraw()


## Changes race and reapplies the class, since the race shapes what it gives.
func set_race(new_race: String) -> void:
	race = new_race
	set_class(unit_class)


func race_data() -> Dictionary:
	return Races.get_data(race)


func has_ability(ability: String) -> bool:
	return abilities.has(ability)


## Skills its class's and its own learn tables teach at `lv`.
func skills_learned_at(lv: int) -> Array[String]:
	var result: Array[String] = []
	for table: Dictionary in [Classes.get_data(unit_class).get("learn", {}), learn_table]:
		if table.has(lv) and not result.has(table[lv]):
			result.append(table[lv])
	return result


## Cap for a stat (keys as in Experience.STATS), from the unit's class.
func stat_cap(key: String) -> int:
	return Classes.caps(unit_class)[key]


func is_capped(key: String) -> bool:
	return get(Experience.STATS[key]) >= stat_cap(key)


func is_mounted() -> bool:
	return mounted


func is_ship() -> bool:
	return has_ability("ship")


## Rescue: mounted units and carrier races (Centaurs) can carry allies.
func can_carry() -> bool:
	return mounted or race_data().get("carrier", false)


func can_be_carried() -> bool:
	return not (mounted or is_ship() or race_data().get("carrier", false) or race_data().get("immovable", false))


## Shove: mounted units can't (they Rescue instead), unless their race is a carrier.
func can_shove() -> bool:
	return not is_ship() and (not mounted or race_data().get("carrier", false))


func can_be_shoved() -> bool:
	return can_be_carried()


## Free passenger slots (0 for anything that isn't a ship).
func cargo_space() -> int:
	if not is_ship():
		return 0
	return Classes.get_data(unit_class).get("capacity", 1) - passengers.size()


## Whether the unit's class can equip this item.
func can_wield(item: Dictionary) -> bool:
	return Items.is_weapon(item) and weapon_types.has(item.type)


## Stats as used in combat: skill bonuses (Skills "stats"), plus an Inspire bonus
## for STR and DEF.
func combat_str() -> int:
	return strength + Skills.stat_bonus(self, "str") + inspire_bonus


func combat_def() -> int:
	return defense + Skills.stat_bonus(self, "def") + inspire_bonus


func combat_int() -> int:
	return intelligence + Skills.stat_bonus(self, "int")


func combat_lck() -> int:
	return luck + Skills.stat_bonus(self, "lck")


## DEX and AGI are halved while carrying someone (FE5's rescue penalty).
func combat_dex() -> int:
	var dex := dexterity + Skills.stat_bonus(self, "dex")
	return floori(dex / 2.0) if carrying else dex


func combat_agi() -> int:
	var agi := agility + Skills.stat_bonus(self, "agi")
	return floori(agi / 2.0) if carrying else agi


func is_caster() -> bool:
	return not spells.is_empty()


## MP recovered at the start of the unit's phase (Mana Flow and the like add more).
func mp_regen() -> int:
	return Spells.MP_REGEN + Skills.turn_mp(self)


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


## Index of the equipped weapon (the first one the unit can wield) in `items`,
## or -1 when unarmed.
func equipped_index() -> int:
	for i in items.size():
		if can_wield(items[i]):
			return i
	return -1


## Weapons the unit can wield (it may carry others it can't).
func weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if can_wield(item):
			result.append(item)
	return result


## Moves items[index] to the front, making it the equipped weapon.
func equip(index: int) -> void:
	if index < 0 or not can_wield(items[index]):
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
		"mp":
			var amount := mini(item.mp, max_mp - mp)
			regen_mp(amount)
			popup("+%d MP" % amount, MP_COLOR)
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
## Floating text over the unit. `raise` lifts it, so two popups at once don't overlap.
func popup(text: String, color: Color, raise := 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 10
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-12, -8 - raise)
	label.size = Vector2(40, 10)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", -16.0 - raise, 0.5)
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
	if inspire_bonus > 0:
		draw_rect(Rect2(11, 5, 2, 2), INSPIRED_COLOR)
	var aboard: Unit = carrying if carrying else (passengers[0] if not passengers.is_empty() else null)
	if aboard:
		# Small flag in the carried unit's team color.
		var flag := PLAYER_COLOR if aboard.team == Team.PLAYER else ENEMY_COLOR
		draw_rect(Rect2(3, 2, 3, 3), Color.WHITE)
		draw_rect(Rect2(3.5, 2.5, 2, 2), flag.lightened(0.3))
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
