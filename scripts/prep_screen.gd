extends Control
## Battle preparations for the next campaign chapter (see Campaign):
##   Pick Units: who deploys (the Lord always does; up to the chapter's slots).
##   Items:      move items between a unit and the convoy (also how units swap items).
##   Shop:       buy into the convoy (left: the chapter's stock, see Shop) and sell
##               from it (right) for gold (docs/economy.md).
##   Repair:     restore any worn weapon in the army or convoy to full uses, for the
##               price of the uses it restores (Items.repair_cost).
##   Stable:     every mount: Z on a ridden one takes its rider off; Z on a free one
##               picks a rider (riding reclasses the unit; see Mounts). D: rename.
##   Promote:    units at Classes.PROMOTION_LEVEL+ change into a promoted class.
##   Status:     the status screen for any army unit.
##   Check Map:  the chapter's map, to look around and swap the deployed units'
##               starting cells (see BattleFormation.start); Fight! from there too.
##   Fight!:     start the chapter.
## Up/Down: choose. Z: confirm. X: back. D: info (the status screen for a unit, help
## for an item; on the status screen, its detail mode). Long lists scroll. Changes
## are saved to the campaign at once.

const BATTLE_SCENE := "res://scenes/main.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const DIM := Color(0.7, 0.75, 0.95)
## The two list columns: x and width (the left one gets the full width when the
## right one is empty).
const LEFT_X := 8.0
const RIGHT_X := 122.0
const COLUMN_W := 110.0
const FULL_W := 224.0
## The lists sit between here and the hint, which takes up to two lines at the bottom.
const LIST_TOP := 34.0
const HINT_TOP := 138.0
## Entries are ids, translated where shown.
const MENU: Array[String] = ["Pick Units", "Items", "Shop", "Repair", "Stable", "Promote", "Status", "Check Map", "Fight!",  # i18n
	"Level Select"]

## "menu", "pick", "items_unit", "items", "shop", "repair", "promote_unit", "promote_class", "status_unit", "status"
var mode := "menu"
var index := 0
## Items mode: 0 = the unit's inventory, 1 = the convoy.
var column := 0
var current_unit := ""
var picked: Array = []
var message := ""

var _title: Label
var _objective: Label
var _left: Label
var _right: Label
var _hint: Label
var _status: StatusScreen
var _status_unit: Unit
## Where X on the status screen goes back to.
var _status_return := "status_unit"
## Item help (D on an item); any key closes it.
var _help: PanelContainer
var _help_label: Label
## Stable: the mount being given a rider, and the name editor.
var _mount: Dictionary = {}
var _rename: LineEdit


func _ready() -> void:
	Text.manual(self)  # the code translates what it shows
	var theme := Theme.new()
	theme.default_font_size = 8
	theme.set_constant("line_spacing", "Label", 1)
	self.theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.25)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _label(Vector2(8, 4))
	_title.add_theme_font_size_override("font_size", 10)
	_objective = _label(Vector2(8, 18), DIM)
	_left = _label(Vector2(LEFT_X, LIST_TOP))
	_right = _label(Vector2(RIGHT_X, LIST_TOP))
	for column_label in [_left, _right]:
		column_label.size = Vector2(COLUMN_W, HINT_TOP - LIST_TOP)
		column_label.clip_text = true
		column_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint = _label(Vector2(LEFT_X, HINT_TOP), DIM)
	_hint.size = Vector2(FULL_W, 160 - HINT_TOP)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_help_label = Label.new()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size.x = FULL_W - 6
	_help = PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.08, 0.1, 0.3)
	box_style.border_color = Color(0.85, 0.85, 1.0)
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(2)
	box_style.set_content_margin_all(3)
	_help.add_theme_stylebox_override("panel", box_style)
	_help.visible = false
	_help.add_child(_help_label)
	add_child(_help)
	_status = StatusScreen.new()
	add_child(_status)
	_rename = LineEdit.new()
	_rename.visible = false
	_rename.position = Vector2(96, 120)
	_rename.size = Vector2(120, 14)
	_rename.max_length = 16
	_rename.text_submitted.connect(_finish_rename)
	add_child(_rename)

	if not Campaign.load_save():
		Campaign.start_new()
	Campaign.active = true
	picked = _kept_picks()
	_render()
	Sound.music("prep")


func _label(pos: Vector2, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.position = pos
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


# --- Input --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var up := event.is_action_pressed("ui_up", true)
	var down := event.is_action_pressed("ui_down", true)
	var left := event.is_action_pressed("ui_left", true)
	var right := event.is_action_pressed("ui_right", true)
	var accept := event.is_action_pressed("confirm")
	var cancel := event.is_action_pressed("cancel")
	var info := event.is_action_pressed("unit_info")
	if _rename.visible:
		if cancel:
			_rename.visible = false
			_render()
			get_viewport().set_input_as_handled()
		return
	if not (up or down or left or right or accept or cancel or info):
		return
	get_viewport().set_input_as_handled()
	if _help.visible:
		_help.visible = false
		Sound.play("cancel")
		_render()
		return
	if info and mode == "stable" and index < Campaign.all_mounts().size():
		_start_rename(Campaign.all_mounts()[index].mount)
		return
	Sound.play("confirm" if accept or info else "cancel" if cancel else "cursor")
	message = ""
	if mode == "status":
		# Detail mode: arrows move the highlight, D or X go back to browsing.
		if _status.detail:
			if up or down or left or right:
				_status.move_detail(Vector2i(int(right) - int(left), int(down) - int(up)))
			elif info or cancel:
				_status.exit_detail()
		elif info:
			_status.enter_detail()
		elif up or down:
			var names := _army_names()
			var i := wrapi(names.find(current_unit) + (1 if down else -1), 0, names.size())
			_show_status(names[i])
		elif left or right:
			_status.change_page(1 if right else -1)
		elif cancel:
			_status.close()
			_status_unit.free()
			_status_unit = null
			mode = _status_return
			index = maxi(0, _list_units().find(current_unit))
		_render()
		return
	if info:
		_info()
		_render()
		return
	if up or down:
		index = wrapi(index + (1 if down else -1), 0, maxi(1, _row_count()))
	elif (left or right) and mode in ["items", "shop"]:
		column = 1 - column
		index = 0
	elif accept:
		_accept()
	elif cancel:
		_back()
	_render()


func _accept() -> void:
	match mode:
		"menu":
			match MENU[index]:
				"Pick Units":
					_enter("pick")
				"Items":
					_enter("items_unit")
				"Shop":
					column = 0
					_enter("shop")
				"Repair":
					_enter("repair")
				"Stable":
					_enter("stable")
				"Promote":
					_enter("promote_unit")
				"Status":
					_enter("status_unit")
				"Check Map":
					_go_to_map(true)
				"Fight!":
					_go_to_map(false)
				"Level Select":
					Campaign.active = false
					get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
		"pick":
			_toggle_pick(_army_names()[index])
		"items_unit":
			current_unit = _army_names()[index]
			column = 0
			_enter("items")
		"items":
			_move_item()
		"shop":
			_shop()
		"repair":
			_repair()
		"stable":
			var mounts := Campaign.all_mounts()
			if index < mounts.size():
				if mounts[index].rider != "":
					Campaign.unassign_mount(mounts[index].rider)
					Campaign.save()
					message = tr("{mount} is back in the stable.").format({"mount": mounts[index].mount.name})
				else:
					_mount = mounts[index].mount
					_enter("stable_rider")
		"stable_rider":
			var names := _army_names()
			var problem := Campaign.ride_problem(names[index], _mount)
			if problem != "":
				message = problem
			else:
				Campaign.assign_mount(names[index], _mount)
				Campaign.save()
				message = tr("{unit} now rides {mount}.").format({"unit": names[index], "mount": _mount.name})
				_enter("stable")
		"promote_unit":
			var eligible := _promotable()
			if not eligible.is_empty():
				current_unit = eligible[index]
				_enter("promote_class")
		"promote_class":
			var options := Campaign.promotion_options(Campaign.army_unit(current_unit))
			var gains := Campaign.promote(current_unit, options[index])
			Campaign.save()
			message = tr("{unit} is now a {class}!").format({"unit": current_unit, "class": options[index]}) + " " + _gains_text(gains)
			_enter("promote_unit")
		"status_unit":
			_show_status(_army_names()[index])


## D: the status screen for a highlighted unit, help for a highlighted item.
func _info() -> void:
	var units := _list_units()
	if index < units.size():
		_show_status(units[index])
		return
	var it := _highlighted_item()
	if not it.is_empty():
		_help_label.text = Glossary.item(it)
		_help.reset_size()
		_help.position = Vector2(4, 160 - 4 - _help.get_combined_minimum_size().y)
		_help.visible = true


## The units listed in this mode, in row order (empty where the rows aren't units).
func _list_units() -> Array:
	match mode:
		"pick", "items_unit", "status_unit", "stable_rider":
			return _army_names()
		"promote_unit":
			return _promotable()
	return []


## The item on the highlighted row, or {} where the rows aren't items.
func _highlighted_item() -> Dictionary:
	var list := []
	match mode:
		"items":
			list = Campaign.army_unit(current_unit).items if column == 0 else Campaign.convoy
		"shop":
			if column == 0:
				var stock := Shop.stock_for(Campaign.chapter_data())
				return Items.make(stock[index]) if index < stock.size() else {}
			list = Campaign.convoy
		"repair":
			list = _repairables().map(func(r): return r[1])
	return list[index] if index < list.size() else {}


func _back() -> void:
	match mode:
		"items":
			_enter("items_unit")
		"promote_class":
			_enter("promote_unit")
		"stable_rider":
			_enter("stable")
		_:
			_enter("menu")


func _enter(new_mode: String) -> void:
	mode = new_mode
	index = 0


# --- Actions -------------------------------------------------------------------------

func _toggle_pick(unit_name: String) -> void:
	var d := Campaign.army_unit(unit_name)
	var slots: int = Campaign.chapter_data().deploy.size()
	if picked.has(unit_name):
		if d.is_lord:
			message = tr("Your Lord must fight.")
		else:
			picked.erase(unit_name)
	elif picked.size() >= slots:
		message = tr("Only %d units can deploy.") % slots
	else:
		picked.append(unit_name)


func _move_item() -> void:
	var d := Campaign.army_unit(current_unit)
	if column == 0 and index < d.items.size():
		Campaign.store_item(current_unit, index)
	elif column == 1 and index < Campaign.convoy.size():
		if not Campaign.take_item(current_unit, index):
			message = tr("{unit} can't carry more.").format({"unit": current_unit})
	Campaign.save()
	index = clampi(index, 0, maxi(0, _row_count() - 1))


func _start_rename(mount: Dictionary) -> void:
	_mount = mount
	_rename.text = mount.name
	_rename.visible = true
	_rename.grab_focus()
	_rename.select_all()


func _finish_rename(new_name: String) -> void:
	if new_name.strip_edges() != "":
		_mount.name = new_name.strip_edges()
		Campaign.save()
	_rename.visible = false
	_render()


## Worn weapons in the army and convoy: [[owner name or "Convoy", item]].
func _repairables() -> Array:
	var result := []
	for d in Campaign.army:
		for it in d.items:
			if Items.is_weapon(it) and it.uses < Weapons.max_uses(it):
				result.append([d.unit_name, it])
	for it in Campaign.convoy:
		if Items.is_weapon(it) and it.uses < Weapons.max_uses(it):
			result.append(["Convoy", it])
	return result


## Buys the highlighted stock item into the convoy (left), or sells the highlighted
## convoy item (right).
func _shop() -> void:
	if column == 0:
		var stock := Shop.stock_for(Campaign.chapter_data())
		if index >= stock.size():
			return
		var item_name: String = stock[index]
		if not Shop.can_afford(item_name, Campaign.gold):
			message = tr("Not enough gold for {item}.").format({"item": item_name})
			return
		Campaign.gold -= Items.cost(item_name)
		Campaign.convoy.append(Items.make(item_name))
		message = tr("Bought {item}: it's in the convoy.").format({"item": item_name})
	else:
		if index >= Campaign.convoy.size():
			return
		var item: Dictionary = Campaign.convoy[index]
		var price := Items.sell_price(item)
		if price <= 0:
			message = tr("{item} can't be sold.").format({"item": item.name})
			return
		Campaign.gold += price
		Campaign.convoy.remove_at(index)
		message = tr("Sold {item} for {price} gold.").format({"item": item.name, "price": price})
		index = clampi(index, 0, maxi(0, Campaign.convoy.size() - 1))
	Campaign.save()


func _repair() -> void:
	var list := _repairables()
	if index >= list.size():
		return
	var it: Dictionary = list[index][1]
	var price := Items.repair_cost(it)
	if price > Campaign.gold:
		message = tr("Not enough gold: {item} costs {price} to repair.").format({"item": it.name, "price": price})
		return
	Campaign.gold -= price
	it.uses = Weapons.max_uses(it)
	Campaign.save()
	message = tr("{owner}'s {item} repaired for {price} gold.").format({"owner": tr(list[index][0]), "item": it.name,
		"price": price})
	index = clampi(index, 0, maxi(0, _row_count() - 1))


## The picks made before Check Map (or a lost try at this chapter), if they still
## fit the army; otherwise the default deployment.
func _kept_picks() -> Array:
	var slots: int = Campaign.chapter_data().deploy.size()
	var kept := Campaign.deployed.filter(func(n): return not Campaign.army_unit(n).is_empty())
	var has_lord := Campaign.army.all(func(d): return not d.is_lord or kept.has(d.unit_name))
	if kept.is_empty() or kept.size() > slots or not has_lord:
		Campaign.placement = {}
		return Campaign.default_deployment()
	return kept


## Starts the chapter, or with `check_map`, shows its map first (Check Map).
func _go_to_map(check_map: bool) -> void:
	# Keep the army's order (Lord first, as default_deployment does).
	var order := Campaign.default_deployment()
	var names := []
	for unit_name in _army_names():
		if picked.has(unit_name) and Campaign.army_unit(unit_name).is_lord:
			names.append(unit_name)
	for unit_name in _army_names():
		if picked.has(unit_name) and not names.has(unit_name):
			names.append(unit_name)
	Campaign.deployed = names if not names.is_empty() else order
	Campaign.checking_map = check_map
	Campaign.active = true
	Levels.selected = Campaign.chapter_id()
	Levels.resume = false
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _show_status(unit_name: String) -> void:
	if _status_unit:
		_status_unit.free()
	current_unit = unit_name
	_status_unit = SaveGame.unit_from_dict(Campaign.army_unit(unit_name))
	_status.show_unit(_status_unit)
	if mode != "status":
		_status_return = mode
	mode = "status"


# --- Lists and rendering -----------------------------------------------------------------

func _army_names() -> Array:
	return Campaign.army.map(func(d): return d.unit_name)


func _promotable() -> Array:
	return Campaign.army.filter(func(d): return Campaign.can_promote(d)).map(func(d): return d.unit_name)


func _row_count() -> int:
	match mode:
		"menu":
			return MENU.size()
		"pick", "items_unit", "status_unit":
			return Campaign.army.size()
		"items":
			return Campaign.army_unit(current_unit).items.size() if column == 0 else Campaign.convoy.size()
		"shop":
			return Shop.stock_for(Campaign.chapter_data()).size() if column == 0 else Campaign.convoy.size()
		"repair":
			return _repairables().size()
		"stable":
			return Campaign.all_mounts().size()
		"stable_rider":
			return Campaign.army.size()
		"promote_unit":
			return _promotable().size()
		"promote_class":
			return Campaign.promotion_options(Campaign.army_unit(current_unit)).size()
	return 0


func _gains_text(gains: Dictionary) -> String:
	var parts := []
	for key in gains:
		if gains[key] > 0:
			parts.append("%s+%d" % [tr(Experience.STAT_LABELS[key]), gains[key]])
	return " ".join(parts)


func _render() -> void:
	var chapter := Campaign.chapter_data()
	_title.text = tr(chapter.name)
	_objective.text = tr("Victory: {text}").format({"text": Objectives.victory_text(Objectives.of(chapter))})
	var lines: Array[String] = []
	var side: Array[String] = []
	# Lines at the top of a column that stay put while its rows scroll.
	var left_head := 1 if mode in ["items", "shop", "repair", "stable_rider", "promote_class"] else 0
	var side_head := 1 if mode in ["items", "shop"] else 0
	match mode:
		"menu":
			for i in MENU.size():
				lines.append(_row(i, tr(MENU[i])))
			side.append(tr("Gold %d") % Campaign.gold)
			side.append(tr("Deployed %d/%d") % [picked.size(), chapter.deploy.size()])
			for unit_name in picked:
				side.append("  " + unit_name)
			if not Campaign.fallen.is_empty():
				side.append(tr("Fallen: %s") % ", ".join(Campaign.fallen.map(func(f): return f.unit.unit_name)))
		"pick":
			var names := _army_names()
			for i in names.size():
				lines.append(_row(i, "[%s] %s" % ["x" if picked.has(names[i]) else " ", names[i]]))
			var d := Campaign.army_unit(names[index])
			side.append(tr("%s  Lv %d") % [Campaign.class_label(d), d.level])
			side.append(tr("Deployed %d/%d") % [picked.size(), chapter.deploy.size()])
		"items_unit", "status_unit":
			var names := _army_names()
			for i in names.size():
				var d := Campaign.army_unit(names[i])
				lines.append(_row(i, tr("%s  Lv %d") % [names[i], d.level]))
			side.append(tr("Convoy: %d items") % Campaign.convoy.size())
		"items":
			var d := Campaign.army_unit(current_unit)
			lines.append(current_unit)
			for i in d.items.size():
				lines.append(_row(i, Items.label(d.items[i], " "), column == 0))
			side.append(tr("Convoy"))
			for i in Campaign.convoy.size():
				side.append(_row(i, Items.label(Campaign.convoy[i], " "), column == 1))
			if Campaign.convoy.is_empty():
				side.append("   " + tr("(empty)"))
		"shop":
			var stock := Shop.stock_for(Campaign.chapter_data())
			lines.append(tr("Buy  Gold %d") % Campaign.gold)
			for i in stock.size():
				lines.append(_row(i, Shop.buy_label(stock[i], Campaign.gold), column == 0))
			side.append(tr("Sell (convoy)"))
			for i in Campaign.convoy.size():
				side.append(_row(i, Shop.sell_label(Campaign.convoy[i]), column == 1))
			if Campaign.convoy.is_empty():
				side.append("   " + tr("(empty)"))
		"repair":
			var list := _repairables()
			lines.append(tr("Gold %d") % Campaign.gold)
			if list.is_empty():
				lines.append(tr("Every weapon is in good repair."))
			for i in list.size():
				var it: Dictionary = list[i][1]
				lines.append(_row(i, "%s: %s  %s/%d  %dG" % [tr(list[i][0]), it.name,
					tr("broken") if Weapons.is_broken(it) else str(it.uses), Weapons.max_uses(it), Items.repair_cost(it)]))
		"stable":
			var mounts := Campaign.all_mounts()
			if mounts.is_empty():
				lines.append(tr("No mounts yet."))
			for i in mounts.size():
				var m: Dictionary = mounts[i].mount
				lines.append(_row(i, tr("%s  %s Lv %d") % [m.name, m.species, m.level]))
			if index < mounts.size():
				var m: Dictionary = mounts[index].mount
				side.append(tr("Rider: %s") % (mounts[index].rider if mounts[index].rider != "" else tr("none")))
				side.append("%s, %s" % [m.species, m.gender])
				for s in Mounts.STATS:
					side.append("%s %d" % [tr(Experience.STAT_LABELS[s]), m.stats[s]])
				side.append(", ".join(m.get("skills", [])))
		"stable_rider":
			var names := _army_names()
			lines.append(tr("Who rides {mount}?").format({"mount": _mount.name}))
			for i in names.size():
				var d := Campaign.army_unit(names[i])
				var mark := " " if Campaign.ride_problem(names[i], _mount) == "" else "x"
				lines.append(_row(i, "[%s] %s  %s" % [mark, names[i], Campaign.class_label(d)]))
		"promote_unit":
			var eligible := _promotable()
			if eligible.is_empty():
				lines.append(tr("No unit has reached Lv %d.") % Classes.PROMOTION_LEVEL)
			for i in eligible.size():
				var d := Campaign.army_unit(eligible[i])
				lines.append(_row(i, tr("%s  %s Lv %d") % [eligible[i], Campaign.class_label(d), d.level]))
		"promote_class":
			var options := Campaign.promotion_options(Campaign.army_unit(current_unit))
			lines.append(tr("Promote {unit} to:").format({"unit": current_unit}))
			for i in options.size():
				lines.append(_row(i, options[i]))
			var bonus := Classes.promotion_bonus(options[index])
			side.append(_gains_text(bonus))
	var side_active := mode in ["items", "shop"] and column == 1
	_left.text = "\n".join(_fit(lines, left_head, -1 if side_active else index))
	_right.text = "\n".join(_fit(side, side_head, index if side_active else -1))
	_left.size.x = COLUMN_W if not side.is_empty() else FULL_W
	var hints := {  # i18n
		"menu": "Up/Down: choose  Z: select",
		"pick": "Z: deploy / bench  D: info  X: back",
		"items_unit": "Z: select  D: info  X: back",
		"status_unit": "Z: select  D: info  X: back",
		"promote_unit": "Z: select  D: info  X: back",
		"items": "Z: move item  Left/Right: unit/convoy  D: info  X: back",
		"shop": "Z: buy / sell  Left/Right: buy/sell  D: info  X: back",
		"repair": "Z: repair  D: info  X: back",
		"stable": "Z: assign / unassign  D: rename  X: back",
		"stable_rider": "Z: ride  D: info  X: back",
	}
	_hint.text = message if message != "" else tr(hints.get(mode, "Z: select  X: back"))
	# The status screen has its own hint; item help covers it.
	_hint.visible = mode != "status" and not _help.visible


## The rows of a column that fit above the hint, scrolled to keep row `selected`
## (-1: none) in view; the first `head` lines (titles) always show. "..." stands
## in for rows hidden above or below.
func _fit(lines: Array[String], head: int, selected: int) -> Array[String]:
	var rows := int((HINT_TOP - LIST_TOP) / _left.get_line_height()) - head
	if lines.size() - head <= rows:
		return lines
	var body := lines.slice(head)
	var first := clampi(selected - rows / 2, 0, body.size() - rows)
	var shown := body.slice(first, first + rows)
	if first > 0:
		shown[0] = "   ..."
	if first + rows < body.size():
		shown[-1] = "   ..."
	var result: Array[String] = []
	result.assign(lines.slice(0, head) + shown)
	return result


func _row(i: int, text: String, active := true) -> String:
	return ("> " if active and i == index else "   ") + text
