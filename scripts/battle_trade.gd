class_name BattleTrade
extends RefCounted
## The trade screen (part of BattleInput, as `input.trade`). Pick an item on either
## side, then a slot on the other side: an occupied slot swaps the two items, an
## empty slot hands the item over. Trading never uses up the unit's action, so it can
## trade repeatedly and with several partners (it commits the unit's move, though).

var input: BattleInput
## The unit trading with the selected one.
var partner: Unit
## x = side (0 the selected unit, 1 the partner), y = slot.
var cursor := Vector2i.ZERO
## The picked-up item's (side, slot), or (-1, -1) when none.
var held := Vector2i(-1, -1)


func _init(owner: BattleInput) -> void:
	input = owner



func open(with: Unit) -> void:
	partner = with
	held = Vector2i(-1, -1)
	cursor = Vector2i(0 if not input.selected.items.is_empty() else 1, 0)
	input.battle.cursor.cell = input.selected.cell
	input.battle.state = Battle.State.TRADE
	_refresh()


func _side(side: int) -> Unit:
	return input.selected if side == 0 else partner


## Highest slot the cursor may sit on for a side: only filled slots, plus the
## first empty one when it is the drop target for a held item.
func _max_slot(side: int) -> int:
	var count := _side(side).items.size()
	if held.x >= 0 and side != held.x:
		return mini(count, Unit.MAX_ITEMS - 1)
	return count - 1


func move(dir: Vector2i) -> void:
	if dir.y != 0:
		var top := _max_slot(cursor.x)
		cursor.y = wrapi(cursor.y + dir.y, 0, top + 1)
	elif held.x < 0:
		var other := 1 - cursor.x
		if _max_slot(other) >= 0:
			cursor = Vector2i(other, mini(cursor.y, _max_slot(other)))
	_refresh()


func accept() -> void:
	if held.x < 0:
		# Pick up the item under the cursor and jump to the other side.
		held = cursor
		var other := 1 - cursor.x
		cursor = Vector2i(other, mini(cursor.y, _max_slot(other)))
	else:
		var from := _side(held.x).items
		var to := _side(cursor.x).items
		var item := from[held.y]
		if cursor.y < to.size():
			from[held.y] = to[cursor.y]
			to[cursor.y] = item
		else:
			from.remove_at(held.y)
			to.append(item)
		input.move_committed = true
		held = Vector2i(-1, -1)
		# Stay on this side if it still has items, otherwise hop back.
		if _max_slot(cursor.x) < 0:
			cursor.x = 1 - cursor.x
		cursor.y = mini(cursor.y, _max_slot(cursor.x))
	_refresh()


func cancel() -> void:
	if held.x >= 0:
		cursor = held
		held = Vector2i(-1, -1)
		_refresh()
		return
	input.battle.ui.hide_trade()
	input.selected.queue_redraw()
	partner.queue_redraw()
	input.open_unit_menu()


func _refresh() -> void:
	input.battle.ui.show_trade(input.selected, partner, cursor, held)
