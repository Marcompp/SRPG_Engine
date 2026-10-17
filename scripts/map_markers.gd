class_name MapMarkers
extends Node2D
## Small marks drawn over units on the map, above the tokens (they may stick out past
## the tile). Some are about a "subject": the player unit selected, or else the one
## under the cursor while browsing:
##   ! (red):   this foe has a weapon or spell effective against the subject (x3 or x2)
##   ! (gold):  this foe could crit the subject at CRIT_WARNING% or more with something
##              it carries (killer weapons, crit skills...)
##   bubble:    the subject can Talk to this unit (anywhere on the map)
## Others are always shown:
##   crown:     a boss
##   coin:      a foe carrying gold or something stealable

## Crit chance (against the subject) that earns the gold warning.
const CRIT_WARNING := 20
const EFFECTIVE_COLOR := Color8(255, 70, 50)
const CRIT_COLOR := Color8(255, 210, 60)
const OUTLINE := Color(0, 0, 0, 0.9)
const GOLD := Color8(255, 205, 70)
const GOLD_LIGHT := Color8(255, 245, 190)
const BUBBLE := Color8(250, 250, 245)
const BUBBLE_DOTS := Color8(60, 80, 140)

var battle: Battle
## Warnings (foe -> "effective" or "crit") for _warned_for, worked out at most every
## REFRESH_MS (they try each foe's weapons, so not every frame).
var _warnings := {}
var _warned_for: Unit
var _warned_at := -REFRESH_MS
const REFRESH_MS := 250


func _process(_delta: float) -> void:
	queue_redraw()


## The unit the warnings and talk bubbles are about, or null.
func subject() -> Unit:
	if battle.enemy_phase or battle.state in [Battle.State.BUSY, Battle.State.GAME_OVER]:
		return null
	var input := battle.input
	if input.selected and input.selected.team == Unit.Team.PLAYER:
		return input.selected
	if battle.state in [Battle.State.IDLE, Battle.State.FORMATION]:
		var h := input.hovered
		if h and is_instance_valid(h) and h.team == Unit.Team.PLAYER:
			return h
	return null


## "effective", "crit" or "": what `foe` threatens `target` with.
static func warning(foe: Unit, target: Unit) -> String:
	if not Factions.hostile(foe.team, target.team):
		return ""
	for w in foe.weapons():
		if Combat.multiplier(w, target) > 1:
			return "effective"
	var spells := _damage_spells(foe)
	for s in spells:
		if Combat.multiplier(Spells.get_spell(s), target) > 1:
			return "effective"
	if _max_crit(foe, target, spells) >= CRIT_WARNING:
		return "crit"
	return ""


## The foe's best crit chance against `target` with any weapon it can wield (each tried
## as if equipped, so weapon-granted skills count) or damage spell.
static func _max_crit(foe: Unit, target: Unit, spells: Array[String]) -> int:
	var best := 0
	var saved := foe.items.duplicate()
	for i in foe.items.size():
		if foe.can_wield(saved[i]):
			foe.items.assign(saved)
			foe.equip(i)
			best = maxi(best, Combat.crit_chance(foe, target))
	foe.items.assign(saved)
	for s in spells:
		best = maxi(best, Combat.spell_crit_chance(foe, target, Spells.get_spell(s)))
	return best


static func _damage_spells(u: Unit) -> Array[String]:
	return u.attack_spells().filter(func(s: String) -> bool:
		return not Spells.is_support(s) and not Spells.get_spell(s).get("status_only", false))


## Whether a foe carries gold or an item that could be stolen.
static func has_loot(u: Unit) -> bool:
	return u.team != Unit.Team.PLAYER and (u.gold > 0 or u.items.any(func(it): return not Items.is_weapon(it)))


func _draw() -> void:
	var who := subject()
	var talkers: Array[Unit] = []
	if who:
		talkers = battle.events.talk_partners(who)
	_update_warnings(who)
	# A 1 px bob, so the contextual marks catch the eye.
	var bob := -1.0 if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else 0.0
	for u in battle.units():
		if not u.visible:
			continue
		var at := u.position
		if u.is_boss:
			_crown(at)
		if has_loot(u):
			_coin(at)
		if who and u != who:
			var w: String = _warnings.get(u, "")
			if w != "":
				_exclamation(at + Vector2(0, bob), EFFECTIVE_COLOR if w == "effective" else CRIT_COLOR)
			if talkers.has(u):
				_bubble(at + Vector2(0, bob))


func _update_warnings(who: Unit) -> void:
	var now := Time.get_ticks_msec()
	if who == _warned_for and now - _warned_at < REFRESH_MS:
		return
	_warned_for = who
	_warned_at = now
	_warnings.clear()
	if not who:
		return
	for foe in battle.threats_to(who.team):
		var w := warning(foe, who)
		if w != "":
			_warnings[foe] = w


## Top right, sticking out above the tile.
func _exclamation(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(12, -5), Vector2(4, 6)), OUTLINE)
	draw_rect(Rect2(at + Vector2(12, 1), Vector2(4, 4)), OUTLINE)
	draw_rect(Rect2(at + Vector2(13, -4), Vector2(2, 4)), color)
	draw_rect(Rect2(at + Vector2(13, 2), Vector2(2, 2)), color)


## Top left: a speech bubble with three dots and a tail.
func _bubble(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-1, -5), Vector2(9, 6)), OUTLINE)
	draw_rect(Rect2(at + Vector2(0, 1), Vector2(3, 2)), OUTLINE)
	draw_rect(Rect2(at + Vector2(0, -4), Vector2(7, 4)), BUBBLE)
	draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 2)), BUBBLE)
	for x in [1, 3, 5]:
		draw_rect(Rect2(at + Vector2(x, -2), Vector2(1, 1)), BUBBLE_DOTS)


## Top center, over the token's edge.
func _crown(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(4, -3), Vector2(8, 5)), OUTLINE)
	draw_rect(Rect2(at + Vector2(5, -1), Vector2(6, 2)), GOLD)
	for spike in [Rect2(5, -2, 1, 1), Rect2(7, -2, 2, 1), Rect2(10, -2, 1, 1)]:
		draw_rect(Rect2(at + spike.position, spike.size), GOLD)


## Bottom right, above the HP bar.
func _coin(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(12, 8), Vector2(5, 5)), OUTLINE)
	draw_rect(Rect2(at + Vector2(13, 9), Vector2(3, 3)), GOLD)
	draw_rect(Rect2(at + Vector2(13, 9), Vector2(1, 1)), GOLD_LIGHT)
