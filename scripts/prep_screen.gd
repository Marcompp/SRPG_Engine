extends Control
## Battle preparations for the next campaign chapter (see Campaign):
##   Pick Units: who deploys (the Lord always does; up to the chapter's slots).
##   Items:      move items between a unit and the convoy (also how units swap items).
##   Repair:     restore any worn weapon in the army or convoy to full uses (free
##               for now; it will cost gold once there is gold).
##   Promote:    units at Classes.PROMOTION_LEVEL+ change into a promoted class.
##   Status:     the status screen for any army unit.
##   Check Map:  the chapter's map, to look around and swap the deployed units'
##               starting cells (see BattleInput.start_formation); Fight! from there too.
##   Fight!:     start the chapter.
## Up/Down: choose. Z: confirm. X: back. Changes are saved to the campaign at once.

const BATTLE_SCENE := "res://scenes/main.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const DIM := Color(0.7, 0.75, 0.95)
const MENU: Array[String] = ["Pick Units", "Items", "Repair", "Promote", "Status", "Check Map", "Fight!", "Level Select"]

## "menu", "pick", "items_unit", "items", "repair", "promote_unit", "promote_class", "status_unit", "status"
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


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 8
	self.theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.25)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _label(Vector2(8, 4))
	_title.add_theme_font_size_override("font_size", 10)
	_objective = _label(Vector2(8, 18), DIM)
	_left = _label(Vector2(8, 34))
	_right = _label(Vector2(96, 34))
	_hint = _label(Vector2(8, 148), DIM)
	_status = StatusScreen.new()
	add_child(_status)

	if not Campaign.load_save():
		Campaign.start_new()
	Campaign.active = true
	picked = _kept_picks()
	_render()


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
	if not (up or down or left or right or accept or cancel):
		return
	get_viewport().set_input_as_handled()
	message = ""
	if mode == "status":
		if up or down:
			var names := _army_names()
			var i := wrapi(names.find(current_unit) + (1 if down else -1), 0, names.size())
			_show_status(names[i])
		elif left or right:
			_status.change_page(1 if right else -1)
		elif cancel:
			_status.close()
			_status_unit.free()
			mode = "status_unit"
		_render()
		return
	if up or down:
		index = wrapi(index + (1 if down else -1), 0, maxi(1, _row_count()))
	elif (left or right) and mode == "items":
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
				"Repair":
					_enter("repair")
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
		"repair":
			_repair()
		"promote_unit":
			var eligible := _promotable()
			if not eligible.is_empty():
				current_unit = eligible[index]
				_enter("promote_class")
		"promote_class":
			var options := Classes.promotions(Campaign.army_unit(current_unit).unit_class)
			var gains := Campaign.promote(current_unit, options[index])
			Campaign.save()
			message = "%s is now a %s! %s" % [current_unit, options[index], _gains_text(gains)]
			_enter("promote_unit")
		"status_unit":
			_show_status(_army_names()[index])


func _back() -> void:
	match mode:
		"items":
			_enter("items_unit")
		"promote_class":
			_enter("promote_unit")
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
			message = "Your Lord must fight."
		else:
			picked.erase(unit_name)
	elif picked.size() >= slots:
		message = "Only %d units can deploy." % slots
	else:
		picked.append(unit_name)


func _move_item() -> void:
	var d := Campaign.army_unit(current_unit)
	if column == 0 and index < d.items.size():
		Campaign.store_item(current_unit, index)
	elif column == 1 and index < Campaign.convoy.size():
		if not Campaign.take_item(current_unit, index):
			message = "%s can't carry more." % current_unit
	Campaign.save()
	index = clampi(index, 0, maxi(0, _row_count() - 1))


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


func _repair() -> void:
	var list := _repairables()
	if index >= list.size():
		return
	var it: Dictionary = list[index][1]
	it.uses = Weapons.max_uses(it)
	Campaign.save()
	message = "%s's %s repaired." % [list[index][0], it.name]
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
		"repair":
			return _repairables().size()
		"promote_unit":
			return _promotable().size()
		"promote_class":
			return Classes.promotions(Campaign.army_unit(current_unit).unit_class).size()
	return 0


func _gains_text(gains: Dictionary) -> String:
	var parts := []
	for key in gains:
		if gains[key] > 0:
			parts.append("%s+%d" % [Experience.STAT_LABELS[key], gains[key]])
	return " ".join(parts)


func _render() -> void:
	var chapter := Campaign.chapter_data()
	_title.text = chapter.name
	_objective.text = "Victory: " + Objectives.victory_text(Objectives.of(chapter))
	var lines: Array[String] = []
	var side: Array[String] = []
	match mode:
		"menu":
			for i in MENU.size():
				lines.append(_row(i, MENU[i]))
			side.append("Deployed %d/%d" % [picked.size(), chapter.deploy.size()])
			for unit_name in picked:
				side.append("  " + unit_name)
			if not Campaign.fallen.is_empty():
				side.append("Fallen: %s" % ", ".join(Campaign.fallen.map(func(f): return f.unit.unit_name)))
		"pick":
			var names := _army_names()
			for i in names.size():
				lines.append(_row(i, "[%s] %s" % ["x" if picked.has(names[i]) else " ", names[i]]))
			var d := Campaign.army_unit(names[index])
			side.append("%s  Lv %d" % [d.unit_class, d.level])
			side.append("Deployed %d/%d" % [picked.size(), chapter.deploy.size()])
		"items_unit", "status_unit":
			var names := _army_names()
			for i in names.size():
				var d := Campaign.army_unit(names[i])
				lines.append(_row(i, "%s  Lv %d" % [names[i], d.level]))
			side.append("Convoy: %d items" % Campaign.convoy.size())
		"items":
			var d := Campaign.army_unit(current_unit)
			lines.append(current_unit)
			for i in d.items.size():
				lines.append(_row(i, Items.label(d.items[i], " "), column == 0))
			side.append("Convoy")
			for i in Campaign.convoy.size():
				side.append(_row(i, Items.label(Campaign.convoy[i], " "), column == 1))
			if Campaign.convoy.is_empty():
				side.append("   (empty)")
		"repair":
			var list := _repairables()
			if list.is_empty():
				lines.append("Every weapon is in good repair.")
			for i in list.size():
				var it: Dictionary = list[i][1]
				lines.append(_row(i, "%s: %s  %s/%d" % [list[i][0], it.name,
					"broken" if Weapons.is_broken(it) else str(it.uses), Weapons.max_uses(it)]))
			side.append("Repairs are free")
			side.append("for now.")
		"promote_unit":
			var eligible := _promotable()
			if eligible.is_empty():
				lines.append("No unit has reached Lv %d." % Classes.PROMOTION_LEVEL)
			for i in eligible.size():
				var d := Campaign.army_unit(eligible[i])
				lines.append(_row(i, "%s  %s Lv %d" % [eligible[i], d.unit_class, d.level]))
		"promote_class":
			var options := Classes.promotions(Campaign.army_unit(current_unit).unit_class)
			lines.append("Promote %s to:" % current_unit)
			for i in options.size():
				lines.append(_row(i, options[i]))
			var bonus := Classes.promotion_bonus(options[index])
			side.append(_gains_text(bonus))
	_left.text = "\n".join(lines)
	_right.text = "\n".join(side)
	var hints := {
		"menu": "Up/Down: choose  Z: select",
		"pick": "Z: deploy / bench  X: back",
		"items": "Z: move item  Left/Right: unit/convoy  X: back",
		"repair": "Z: repair  X: back",
		"status": "Left/Right: page  Up/Down: unit  X: back",
	}
	_hint.text = message if message != "" else hints.get(mode, "Z: select  X: back")


func _row(i: int, text: String, active := true) -> String:
	return ("> " if active and i == index else "   ") + text
