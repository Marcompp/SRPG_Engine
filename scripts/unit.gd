class_name Unit
extends Node2D
## A single unit on the map. Drawn as a colored square with an HP bar.

## The side a unit fights for (see Factions). New sides go at the end: saves store
## the number.
enum Team { PLAYER, ENEMY, ALLY, OTHER, NEUTRAL }

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
	"drake": Color("b06030"),
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
## whether terrain bonuses apply. The class (or mount) and the unit's body skills
## each propose one, and the highest wins (see Races.winning_move).
var move_type := "foot"
## Effectiveness tags: the class's move type plus the mount's, race's and body
## skills' tags. Weapons are
## effective against these, and Combat.TAG_TRAITS gives weaknesses/resistances.
var tags: Array[String] = []
## Race: a key of Races.DATA (roster "race", default "Human").
var race := "Human"
## Possible values of `gender` ("none": races without gender, like Ents).
const GENDERS: Array[String] = ["male", "female", "none"]
## Hidden: never shown to the player, but rules can check it (e.g. mounts that only
## accept some riders). Roster "gender"; units without one roll it from their race's
## gender ratio (see Races.roll_gender).
var gender := "male"
## Generic units (roster "generic": true) get a random name (see Names) and show
## their class's initial on the map instead of their name's.
var generic := false
## Bosses: roster "boss": true, or the "boss" AI preset. Defeating one is a
## biography moment.
var is_boss := false
## Foes this unit has defeated.
var kills := 0
## Notable events in this unit's story, oldest first (roster "bio"); shown on the
## status screen's Biography page. Player units only. Entries are Text entries (or
## plain strings), translated when shown: see Text.render.
var biography: Array = []
## Mounted units can Rescue allies, and can't Shove, be Shoved or be Rescued.
var mounted := false
## The mount it's riding (see Mounts for the record), or {}. Riding reclasses it into
## its foot class's mounted class; `foot_class` is what it goes back to.
var mount := {}
var foot_class := ""
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
## True while walking a path (the camera follows it).
var moving := false
## Left the map through an exit (escape objective): off the map but alive.
var escaped := false
## STR/DEF bonus from an Inspire; cleared at the start of the unit's next phase.
var inspire_bonus := 0:
	set(value):
		inspire_bonus = value
		queue_redraw()
## Gold it carries (roster "gold"): the player's side takes it by defeating the
## unit, or Steal (docs/economy.md).
var gold := 0
## Active status effects: {name: turns left} (-1: until cured). See Statuses.
var statuses := {}
## Enemy behavior (see AIProfiles), resolved from the roster's "ai" entry.
var ai: Dictionary = AIProfiles.resolve({})
## Galeforce-style skills: it may act again once this action is done, and it already
## did this turn (cleared at the start of its side's phase).
var refresh_pending := false
var refreshed := false
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
## Max HP from the roster, level-ups and promotion; `max_hp` adds skill bonuses.
var base_max_hp := 10
var max_hp: int:
	get:
		return base_max_hp + Skills.stat_bonus(self, "hp")
	set(value):
		base_max_hp = value
## Never above max HP (losing a Max HP skill, e.g. trading a ring away, lowers it).
var hp := 10:
	get:
		return mini(hp, max_hp)
var strength := 5
var dexterity := 5
var agility := 5
var luck := 0
var defense := 2
var intelligence := 0
## Computed properties (getters over other fields) that suspend saves must skip:
## they're rebuilt from the fields they read. Add any new computed property here.
## Also skipped: transient animation state (see Game feel below).
const SAVE_SKIP: Array[String] = ["mov", "max_hp", "max_mp", "weapon", "min_range", "max_range", "moving",
	"lifted", "_shown_hp", "_flash", "_bob"]
## MOV from the roster and level-ups; `mov` adds the race's bonus (see Races).
var base_mov := 5
var mov_bonus := 0
var mov: int:
	get:
		if not mount.is_empty():
			return Mounts.species_data(mount.species).mov + Skills.stat_bonus(self, "mov")
		return base_mov + mov_bonus + Skills.stat_bonus(self, "mov")
	set(value):
		base_mov = value
## Everyone has MP: casters spend it on spells, and current MP is also magic
## defense (see Combat.magic_defense). Only casters show an MP bar on the map.
var base_max_mp := 0
var max_mp: int:
	get:
		return base_max_mp + Skills.stat_bonus(self, "mp")
	set(value):
		base_max_mp = value
var mp := 0:
	get:
		return mini(mp, max_mp)
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
		return weapon.get("max_rng", 0) + (Skills.range_bonus(self, weapon.type) if not weapon.is_empty() else 0)
var cell := Vector2i.ZERO
var has_acted := false:
	set(value):
		has_acted = value
		queue_redraw()

# --- Game feel (visual only, never saved) ---------------------------------------
## Units that can still act bob a pixel, in step with each other like GBA map
## sprites; the selected unit (`lifted`) bobs faster.
const BOB_PERIOD := 0.5
const LIFTED_BOB_PERIOD := 0.18
## HP per second the bar drains (or fills) toward the real HP.
const BAR_SPEED := 30.0
const HIT_FLASH_COLOR := Color(1, 1, 1, 0.85)
const BAR_LOSS_COLOR := Color("f8e070")
var lifted := false:
	set(value):
		lifted = value
		queue_redraw()
## HP the bar shows; it chases `hp`. -1 until first drawn, so new units start full.
var _shown_hp := -1.0
## Strength of the white flash (hit, crit wind-up), fading to 0.
var _flash := 0.0
## Current bob frame (0 or 1).
var _bob := 0


static func create(p_name: String, p_team: Team, p_cell: Vector2i, stats: Dictionary) -> Unit:
	var u := Unit.new()
	u.unit_name = p_name
	u.name = p_name
	u.team = p_team
	u.is_lord = stats.get("lord", false)
	u.race = stats.get("race", "Human")
	assert(Races.DATA.has(u.race), "unknown race: " + u.race)
	u.gold = stats.get("gold", 0)
	u.gender = stats.get("gender", Races.roll_gender(u.race))
	assert(GENDERS.has(u.gender), "unknown gender: " + u.gender)
	u.generic = stats.get("generic", false)
	if u.generic:
		u.unit_name = Names.random(u.race, u.gender)
	u.is_boss = stats.get("boss", false) or stats.get("ai", {}).get("preset", "") == "boss"
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
	# Roster "mount": {"species", optional "level" (default: half the rider's), "name",
	# "gender", "skills", "stats"}: it starts the battle riding it.
	if stats.has("mount"):
		var m: Dictionary = stats.mount
		u.mount_up(Mounts.generate(m.species, m.get("level", maxi(1, u.level / 2)), m))
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


## Whether `w` reaches `dist` in this unit's hands (range skills included).
func reaches(w: Dictionary, dist: int) -> bool:
	return not w.is_empty() and dist >= w.min_rng and dist <= w.max_rng + Skills.range_bonus(self, w.type)


## Applies a class (also how promotion will change it; the level is kept).
func set_class(class_id: String) -> void:
	var data := Classes.get_data(class_id)
	assert(Races.allows(race, class_id), "%s can't be a %s" % [race, class_id])
	unit_class = class_id
	var own_move: String = data.move
	var class_tag: String = data.move
	if not mount.is_empty():
		# The species decides how a mounted unit moves and what it counts as.
		var species := Mounts.species_data(mount.species)
		own_move = species.move
		class_tag = species.tags[0]
	move_type = Races.winning_move([own_move] + Skills.moves(self))
	assert(BattleMap.MOVE_TYPES.has(move_type), "unknown move type: " + move_type)
	mov_bonus = Skills.foot_mov(self) if Races.FOOT_MOVES.has(data.move) else 0
	tags.assign([class_tag])
	var more: Array = Races.get_data(race).get("tags", []) + Skills.body_tags(self)
	if not mount.is_empty():
		more = Mounts.species_data(mount.species).tags + more
	for tag: String in more:
		if not tags.has(tag):
			tags.append(tag)
	mounted = data.get("mounted", false)
	weapon_types.assign(data.weapons)
	abilities.assign(data.get("abilities", []))
	queue_redraw()


## Rides `record` (see Mounts): reclasses into the mounted class for its foot class.
## Riding another mount first gets off the current one.
func mount_up(record: Dictionary) -> void:
	if not mount.is_empty():
		dismount()
	var problem := Mounts.ride_problem(unit_class, race, gender, record.species)
	assert(problem == "", "%s: %s" % [unit_name, problem])
	foot_class = unit_class
	mount = record
	set_class(Mounts.mounted_class(foot_class))


## Gets off its mount (back to its foot class) and returns the mount record.
func dismount() -> Dictionary:
	var record := mount
	mount = {}
	var back := foot_class
	foot_class = ""
	if back != "":
		set_class(back)
	return record


## The class name shown to the player: mounted classes are named by species
## ("Cavalry" on a pegasus is a "Flier").
func class_display_name() -> String:
	return Mounts.display_name(unit_class, mount.species) if not mount.is_empty() else unit_class


## The class its promotions come from: its foot class while mounted.
func promotion_class() -> String:
	return foot_class if foot_class != "" else unit_class


## A stat as it works in combat before skills: while mounted, the rider's own value
## halved (rounded down) plus the mount's (see Mounts).
func ridden(value: int, stat: String) -> int:
	if mount.is_empty():
		return value
	return floori(value / 2.0) + mount.stats.get(stat, 0)


## Changes race and reapplies the class, since the race shapes what it gives.
func set_race(new_race: String) -> void:
	race = new_race
	set_class(unit_class)


func race_data() -> Dictionary:
	return Races.get_data(race)


## Key of MOVE_TYPE_BADGES for this unit: its move type, or for foot units its
## terrain skills ("rogue" scouts, "climb", "swim", "swim_climb"...).
func badge_key() -> String:
	if move_type != "foot":
		return move_type
	var parts: Array[String] = []
	for pair in [["Forester", "rogue"], ["Swimming", "swim"], ["Climbing", "climb"]]:
		if Skills.has(self, pair[0]):
			parts.append(pair[1])
	return "_".join(parts) if not parts.is_empty() else "foot"


## The unit's letter: its dialogue portrait, and its map token and status screen
## portrait when its class has no icon (see ClassIcon).
func token_letter() -> String:
	return unit_class.left(1) if generic else unit_name.left(1)


func has_ability(ability: String) -> bool:
	return abilities.has(ability)


## Skills its class's and its own learn tables teach at `lv`.
func skills_learned_at(lv: int) -> Array[String]:
	var result: Array[String] = []
	for table: Dictionary in [Classes.get_data(unit_class).get("learn", {}), learn_table]:
		if table.has(lv) and not result.has(table[lv]):
			result.append(table[lv])
	return result


## Cap for a stat (keys as in Experience.STATS): the class's, changed by the race's.
func stat_cap(key: String) -> int:
	return Classes.caps(unit_class)[key] + Races.cap_change(race, key)


## Growth rate for a stat (%): its own, plus its race's and skills' changes.
func growth_rate(key: String) -> int:
	return growths.get(key, 0) + Races.growth_change(race, key) + Skills.growth_bonus(self, key)


func is_capped(key: String) -> bool:
	return get(Experience.STATS[key]) >= stat_cap(key)


func is_mounted() -> bool:
	return mounted


func is_ship() -> bool:
	return has_ability("ship")


## Rescue: mounted units and carriers (Equine: Centaurs) can carry allies.
func can_carry() -> bool:
	return mounted or Skills.has_handling(self, "carrier")


func can_be_carried() -> bool:
	return not (mounted or is_ship() or Skills.has_handling(self, "carrier") or Skills.has_handling(self, "immovable"))


## Shove: mounted units can't (they Rescue instead), unless they're carriers.
func can_shove() -> bool:
	return not is_ship() and (not mounted or Skills.has_handling(self, "carrier"))


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
	return ridden(strength, "str") + Skills.stat_bonus(self, "str") + inspire_bonus


func combat_def() -> int:
	return ridden(defense, "def") + Skills.stat_bonus(self, "def") + inspire_bonus


func combat_int() -> int:
	return ridden(intelligence, "int") + Skills.stat_bonus(self, "int")


func combat_lck() -> int:
	return ridden(luck, "lck") + Skills.stat_bonus(self, "lck")


## DEX and AGI are halved while carrying someone (FE5's rescue penalty).
func combat_dex() -> int:
	var dex := ridden(dexterity, "dex") + Skills.stat_bonus(self, "dex")
	return floori(dex / 2.0) if carrying else dex


func combat_agi() -> int:
	var agi := ridden(agility, "agi") + Skills.stat_bonus(self, "agi")
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
	queue_redraw()  # the bar fills up from _shown_hp
	modulate = Color(0.5, 1, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


## Spells plus racial attacks (abilities from skills): everything it can cast or use
## besides weapons.
func attack_spells() -> Array[String]:
	var result: Array[String] = []
	if not can_use_magic():
		return result
	result.assign(spells)
	for a in Skills.abilities(self):
		if not result.has(a):
			result.append(a)
	return result


## False while a status (Silence) stops it casting spells and racial attacks.
func can_use_magic() -> bool:
	return not Statuses.restricts(self, "magic")


## Distinct (min, max) reach across the unit's support (true) or offensive (false) spells.
func spell_ranges(support: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for s in attack_spells():
		if Spells.is_support(s) != support:
			continue
		var r := Spells.reach_ranges(s, self)
		if not result.has(r):
			result.append(r)
	return result


## Whether the equipped weapon can strike at this distance.
func can_attack_at(dist: int) -> bool:
	return reaches(weapon, dist)


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
			popup(tr("+%d MP") % amount, MP_COLOR)
		"cure":
			Statuses.cure(self, item.get("cures", ""))
			popup(tr("Cured"), Color.PALE_GREEN)
	item.uses -= 1
	if item.uses <= 0:
		items.remove_at(index)


## Distinct (min, max) ranges across all carried weapons.
func weapon_ranges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for w in weapons():
		var r := Vector2i(w.min_rng, w.max_rng + Skills.range_bonus(self, w.type))
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
	moving = true
	var tw := create_tween()
	for c in path.slice(1):
		tw.tween_property(self, "position", Vector2(c * BattleMap.TILE), 0.07)
	await tw.finished
	moving = false


## Attack motion: a small pull back, then a quick thrust toward `toward`. A crit
## (`heavy`) flashes and holds the wind-up first, so it reads before it lands.
func lunge(toward: Vector2i, heavy := false) -> void:
	var base := Vector2(cell * BattleMap.TILE)
	var dir := Vector2(toward - cell).normalized()
	var tw := create_tween()
	if heavy:
		flash()
		tw.tween_property(self, "position", base - dir * 3.0, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.12)
	else:
		tw.tween_property(self, "position", base - dir * 1.5, 0.05)
	tw.tween_property(self, "position", base + dir * (8.0 if heavy else 6.0), 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


## Knocked back a little from `from` on a hit (further on a crit).
func recoil(from: Vector2i, heavy := false) -> void:
	await _hop(Vector2(cell - from).normalized() * (4.0 if heavy else 2.0), 0.05, 0.14)


## Sidesteps a missed attack from `from`.
func dodge(from: Vector2i) -> void:
	var dir := Vector2(cell - from).normalized()
	await _hop(Vector2(-dir.y, dir.x) * 4.0, 0.07, 0.12)


## Out to `offset` from the unit's cell and back.
func _hop(offset: Vector2, out_time: float, back_time: float) -> void:
	var base := Vector2(cell * BattleMap.TILE)
	var tw := create_tween()
	tw.tween_property(self, "position", base + offset, out_time).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", base, back_time).set_trans(Tween.TRANS_QUAD)
	await tw.finished


## White flash over the unit's body, fading out.
func flash(strength := 1.0) -> void:
	_flash = maxf(_flash, strength)
	queue_redraw()


func notify_attacked() -> void:
	was_attacked = true


## The HP bar drains to the new HP (see _process) instead of jumping.
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if amount > 0 and hp > 0:
		Statuses.on_damaged(self)
	flash()


## Spends one use of the equipped weapon. Returns true if it broke
## (it is removed, and the next item becomes equipped).
## Spends one use of the equipped weapon. Returns true when that broke it (it stays,
## weakened: see Weapons.is_broken); a broken weapon doesn't lose more uses.
func use_weapon() -> bool:
	var w := items[equipped_index()]
	if Weapons.is_broken(w):
		return false
	w.uses -= 1
	return w.uses <= 0


## Floating text over the unit. `raise` lifts it, so two popups at once don't overlap.
## It pops up past its resting height and settles back, then fades; `big` (crits) is larger.
func popup(text: String, color: Color, raise := 0.0, big := false) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 10
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-22, -6 - raise)
	label.size = Vector2(60, 10)
	label.add_theme_font_size_override("font_size", 10 if big else 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", -15.0 - raise, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35 if big else 0.25)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)


## Blinks white a few times, then fades out.
func die() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_callback(flash)
		tw.tween_interval(0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_parent().remove_child(self)
	queue_free()


func _process(delta: float) -> void:
	var redraw := false
	if _shown_hp < 0.0:
		_shown_hp = hp
	elif _shown_hp != hp:
		_shown_hp = move_toward(_shown_hp, hp, BAR_SPEED * delta)
		redraw = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		redraw = true
	# Bobbing runs on the wall clock, so every unit bobs in step.
	var bob := 0
	if not has_acted and hp > 0 and not Statuses.restricts(self, "act"):
		var period := LIFTED_BOB_PERIOD if lifted else BOB_PERIOD
		bob = int(Time.get_ticks_msec() / (period * 1000.0)) % 2
	if bob != _bob:
		_bob = bob
		redraw = true
	if redraw:
		queue_redraw()


func _draw() -> void:
	# The body bobs; the HP and MP bars underneath stay put.
	draw_set_transform(Vector2(0, -_bob))
	var body: Color = ACTED_COLOR if has_acted else Factions.COLORS[team]
	draw_rect(Rect2(2, 1, 12, 11), body)
	draw_rect(Rect2(2, 1, 12, 11), Color.BLACK, false, 1.0)
	# Its class's icon (the marks below stay on top), or its initial if it has none.
	var icon := ClassIcon.for_class(unit_class)
	if not icon.is_empty():
		ClassIcon.paint(self, icon, Vector2(4, 3), 1.0)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(2, 10), token_letter(),
			HORIZONTAL_ALIGNMENT_CENTER, 12, 9, Color.WHITE)
	if is_lord:
		draw_rect(Rect2(5, 0, 6, 2), Color.GOLD)
	if MOVE_TYPE_BADGES.has(badge_key()):
		draw_rect(Rect2(11, 2, 2, 2), MOVE_TYPE_BADGES[badge_key()])
	if inspire_bonus > 0:
		draw_rect(Rect2(11, 5, 2, 2), INSPIRED_COLOR)
	# One dot per status, up the left edge.
	var i := 0
	for status: String in statuses:
		draw_rect(Rect2(3, 9 - 3 * i, 2, 2), Statuses.get_data(status).color)
		i += 1
	var aboard: Unit = carrying if carrying else (passengers[0] if not passengers.is_empty() else null)
	if aboard:
		# Small flag in the carried unit's team color.
		var flag: Color = Factions.COLORS[aboard.team]
		draw_rect(Rect2(3, 2, 3, 3), Color.WHITE)
		draw_rect(Rect2(3.5, 2.5, 2, 2), flag.lightened(0.3))
	if _flash > 0.0:
		draw_rect(Rect2(2, 1, 12, 11), Color(HIT_FLASH_COLOR, HIT_FLASH_COLOR.a * _flash))
	draw_set_transform(Vector2.ZERO)
	# HP bar: what's being drained (or filled) shows in BAR_LOSS_COLOR until the bar catches up.
	var shown := _shown_hp if _shown_hp >= 0.0 else float(hp)
	_draw_bar(13, 2, maxf(shown, hp) / max_hp, BAR_LOSS_COLOR)
	_draw_bar(13, 2, minf(shown, hp) / max_hp, HP_COLOR, false)
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
