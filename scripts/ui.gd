class_name BattleUI
extends CanvasLayer
## HUD: unit/terrain info, action menu, combat forecast, phase banner, end screen.

var menu_options: Array[String] = []
var menu_index := 0

var _root: Control
var _info: PanelContainer
var _info_label: Label
var _menu: PanelContainer
var _menu_label: Label
var _forecast: PanelContainer
## Forecast grid cells, indexed [row][column]; column 0 is the row header.
var _forecast_cells: Array = []
var _spell_forecast: PanelContainer
var _spell_label: Label
var _trade: PanelContainer
## One label per side of the trade window: [selected unit, partner].
var _trade_labels: Array[Label] = []
var _level_up: PanelContainer
var _level_title: Label
## Rows of [name, value, gain] labels, one per stat in Experience.STATS.
var _level_rows: Array = []
var _banner: ColorRect
var _banner_label: Label
## Full-screen unit stats page.
var _status: PanelContainer
var _status_title: Label
var _status_stats: GridContainer
var _status_combat: GridContainer
var _status_items: Label


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.15, 0.4, 0.9)
	sb.border_color = Color(0.85, 0.85, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(3)
	theme.set_stylebox("panel", "PanelContainer", sb)

	_root = Control.new()
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_info_label = Label.new()
	_info = _make_panel(_info_label)
	_menu_label = Label.new()
	_menu = _make_panel(_menu_label)
	_forecast = _make_forecast()
	_spell_label = Label.new()
	_spell_forecast = _make_panel(_spell_label)
	_level_up = _make_level_up()
	_trade = _make_trade()
	_status = _make_status()

	_banner = ColorRect.new()
	_banner.position = Vector2(0, 56)
	_banner.size = Vector2(240, 48)
	_banner.visible = false
	_root.add_child(_banner)
	_banner_label = Label.new()
	_banner_label.add_theme_font_size_override("font_size", 14)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)
	_banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)


func _make_panel(label: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.add_child(label)
	_root.add_child(panel)
	return panel


const FORECAST_ROWS: Array[String] = ["", "", "HP", "Dmg", "Hit", "Crit"]
const DIM := Color(0.7, 0.75, 0.95)
const ADVANTAGE := Color(0.5, 1.0, 0.5)
const DISADVANTAGE := Color(1.0, 0.5, 0.5)


func _make_forecast() -> PanelContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	for row_name in FORECAST_ROWS:
		var row: Array[Label] = []
		for col in 3:
			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if col == 0 else HORIZONTAL_ALIGNMENT_CENTER
			if col == 0:
				label.text = row_name
				label.add_theme_color_override("font_color", DIM)
			grid.add_child(label)
			row.append(label)
		_forecast_cells.append(row)
	var panel := PanelContainer.new()
	panel.visible = false
	panel.add_child(grid)
	_root.add_child(panel)
	return panel


func _make_trade() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in 2:
		var label := Label.new()
		label.custom_minimum_size.x = 84
		row.add_child(label)
		_trade_labels.append(label)
	var panel := PanelContainer.new()
	panel.visible = false
	panel.add_child(row)
	_root.add_child(panel)
	return panel


func _make_level_up() -> PanelContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_level_title = Label.new()
	_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_level_title)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0)
	for key in Experience.STATS:
		var row: Array[Label] = []
		for col in 3:
			var label := Label.new()
			if col == 0:
				label.text = Experience.STAT_LABELS[key]
				label.add_theme_color_override("font_color", DIM)
			elif col == 2:
				label.add_theme_color_override("font_color", ADVANTAGE)
				label.custom_minimum_size.x = 12
			grid.add_child(label)
			row.append(label)
		_level_rows.append(row)
	box.add_child(grid)
	var panel := PanelContainer.new()
	panel.visible = false
	panel.add_child(box)
	_root.add_child(panel)
	return panel


## Places a panel in a screen corner; right-side panels grow leftward.
func _place(panel: Control, right: bool, bottom: bool) -> void:
	var preset := Control.PRESET_TOP_LEFT
	if right and bottom:
		preset = Control.PRESET_BOTTOM_RIGHT
	elif right:
		preset = Control.PRESET_TOP_RIGHT
	elif bottom:
		preset = Control.PRESET_BOTTOM_LEFT
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 3)
	panel.visible = true


## Put panels on the side of the screen away from the cursor.
func _away_right(cursor_cell: Vector2i) -> bool:
	return cursor_cell.x < 8


func update_info(unit: Unit, terrain: Dictionary, cursor_cell: Vector2i) -> void:
	var text := ""
	if unit:
		var weapon := "No weapon"
		if not unit.weapon.is_empty():
			var rng := str(unit.min_range) if unit.min_range == unit.max_range \
				else "%d-%d" % [unit.min_range, unit.max_range]
			weapon = "%s (%d)  Rng %s  [%d/%d]" % [unit.weapon.name, unit.weapon.uses, rng,
				unit.items.size(), Unit.MAX_ITEMS]
		var lv := "Lv %d" % unit.level
		if unit.team == Unit.Team.PLAYER:
			lv += "  EXP %d" % unit.exp_points
		var hp_line := "HP %d/%d" % [unit.hp, unit.max_hp]
		if unit.is_caster():
			hp_line += "  MP %d/%d" % [unit.mp, unit.max_mp]
		text = "%s  %s\n%s\n" % [unit.unit_name, lv, hp_line]
		if not unit.weapon.is_empty() or not unit.is_caster():
			text += weapon + "\n"
		var others: Array[String] = []
		for i in unit.items.size():
			if not Items.is_weapon(unit.items[i]):
				others.append(item_label(unit, i))
		if not others.is_empty():
			text += "Items: %s\n" % ", ".join(others)
		if not unit.spells.is_empty():
			text += "Spells: %s\n" % ", ".join(unit.spells)
		if unit.is_dancer:
			text += "Skill: Dance\n"
		text += "STR %d  SKL %d  SPD %d  LCK %d\nDEF %d  RES %d  MOV %d\n" % [
			unit.strength, unit.skill, unit.speed, unit.luck, unit.defense, unit.resistance, unit.mov]
		if unit.is_caster():
			text += "MAG %d\n" % unit.magic
	text += "%s  DEF+%d AVO+%d" % [terrain.name, terrain.def, terrain.avo]
	_info_label.text = text
	_place(_info, _away_right(cursor_cell), cursor_cell.y < 4)


func hide_info() -> void:
	_info.visible = false


func show_menu(options: Array[String], cursor_cell: Vector2i) -> void:
	menu_options = options
	menu_index = 0
	_refresh_menu()
	_place(_menu, _away_right(cursor_cell), false)


func menu_move(step: int) -> void:
	if step == 0:
		return
	menu_index = wrapi(menu_index + step, 0, menu_options.size())
	_refresh_menu()


func menu_choice() -> String:
	return menu_options[menu_index]


func hide_menu() -> void:
	_menu.visible = false


func _refresh_menu() -> void:
	var lines: Array[String] = []
	for i in menu_options.size():
		lines.append(("> " if i == menu_index else "   ") + menu_options[i])
	_menu_label.text = "\n".join(lines)


## `atk_label` replaces the attacker's weapon name (e.g. with the spell being cast).
func show_forecast(attacker: Unit, defender: Unit, f: Dictionary, cursor_cell: Vector2i, atk_label := "") -> void:
	_fill_forecast_column(1, attacker, f.atk, true, atk_label)
	_fill_forecast_column(2, defender, f.def, f.can_counter)
	_place(_forecast, _away_right(cursor_cell), false)


func _fill_forecast_column(col: int, unit: Unit, stats: Dictionary, can_attack: bool, label_override := "") -> void:
	var cells: Array = []
	for row in _forecast_cells:
		cells.append(row[col])
	cells[0].text = unit.unit_name
	var weapon_label: Label = cells[1]
	if label_override:
		weapon_label.text = label_override
	else:
		weapon_label.text = unit.weapon.name if not unit.weapon.is_empty() else "--"
	if stats.triangle > 0:
		weapon_label.add_theme_color_override("font_color", ADVANTAGE)
	elif stats.triangle < 0:
		weapon_label.add_theme_color_override("font_color", DISADVANTAGE)
	else:
		weapon_label.remove_theme_color_override("font_color")
	cells[2].text = str(unit.hp)
	cells[3].text = ("%d%s" % [stats.dmg, " x2" if stats.double else ""]) if can_attack else "--"
	cells[4].text = str(stats.hit) if can_attack else "--"
	cells[5].text = str(stats.crit) if can_attack else "--"


func show_heal_forecast(caster: Unit, target: Unit, spell_name: String, amount: int, cursor_cell: Vector2i) -> void:
	var cost: int = Spells.get_spell(spell_name).mp
	_spell_label.text = "%s  (%d MP)\n%s  MP %d -> %d\n%s  HP %d -> %d" % [
		spell_name, cost, caster.unit_name, caster.mp, caster.mp - cost,
		target.unit_name, target.hp, target.hp + amount]
	_place(_spell_forecast, _away_right(cursor_cell), false)


## `rows`: [name, hp, dmg, hit] per enemy inside the blast.
## `note` is an extra line, e.g. the terrain change a terraforming spell will make.
func show_area_forecast(caster: Unit, spell_name: String, rows: Array, cursor_cell: Vector2i, note := "") -> void:
	var cost: int = Spells.get_spell(spell_name).mp
	var lines: Array[String] = ["%s  MP %d -> %d" % [spell_name, caster.mp, caster.mp - cost]]
	if rows.is_empty():
		lines.append("No targets")
	for r in rows:
		lines.append("%s  HP %d  Dmg %d  Hit %d" % r)
	if note:
		lines.append(note)
	_spell_label.text = "\n".join(lines)
	_place(_spell_forecast, _away_right(cursor_cell), cursor_cell.y < 5)


func show_shove_forecast(target: Unit, dest_terrain: String, cursor_cell: Vector2i) -> void:
	_spell_label.text = "Shove\n%s -> %s" % [target.unit_name, dest_terrain]
	_place(_spell_forecast, _away_right(cursor_cell), false)


func show_dance_forecast(target: Unit, cursor_cell: Vector2i) -> void:
	_spell_label.text = "Dance\n%s can act again" % target.unit_name
	_place(_spell_forecast, _away_right(cursor_cell), false)


static func item_label(unit: Unit, index: int) -> String:
	var item := unit.items[index]
	return "%s %d%s" % [item.name, item.uses, " E" if index == unit.equipped_index() else ""]


## Partner's inventory while choosing who to trade with.
func show_trade_preview(partner: Unit, cursor_cell: Vector2i) -> void:
	var lines: Array[String] = ["Trade with %s" % partner.unit_name]
	for i in partner.items.size():
		lines.append("  " + item_label(partner, i))
	if partner.items.is_empty():
		lines.append("  (no items)")
	_spell_label.text = "\n".join(lines)
	_place(_spell_forecast, _away_right(cursor_cell), false)


## Two inventories side by side. `cursor`/`held`: x = side (0 left, 1 right), y = slot;
## held is (-1, -1) when nothing is picked up. ">" marks the cursor, "*" the held item.
func show_trade(left: Unit, right: Unit, cursor: Vector2i, held: Vector2i) -> void:
	hide_info()
	var sides: Array[Unit] = [left, right]
	for side in 2:
		var u := sides[side]
		var lines: Array[String] = [u.unit_name]
		for slot in Unit.MAX_ITEMS:
			var mark := "  "
			if held == Vector2i(side, slot):
				mark = "* "
			if cursor == Vector2i(side, slot):
				mark = "> "
			lines.append(mark + (item_label(u, slot) if slot < u.items.size() else "---"))
		_trade_labels[side].text = "\n".join(lines)
	_trade.reset_size()
	_trade.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 3)
	_trade.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_trade.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_trade.visible = true


func hide_trade() -> void:
	_trade.visible = false


func hide_forecast() -> void:
	_forecast.visible = false
	_spell_forecast.visible = false


## Shows the stats before the level-up with "+1" next to each stat that rose.
func show_level_up(unit: Unit, before: Dictionary, gains: Dictionary) -> void:
	hide_info()
	_level_title.text = "%s  Level Up!  Lv %d" % [unit.unit_name, unit.level]
	var i := 0
	for key in Experience.STATS:
		var row: Array = _level_rows[i]
		var shown: bool = unit.is_caster() or not key in Experience.CASTER_STATS
		for label in row:
			label.visible = shown
		row[1].text = str(before[key] + gains.get(key, 0))
		row[2].text = "+%d" % gains[key] if gains.has(key) else ""
		i += 1
	_level_up.reset_size()
	_level_up.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_level_up.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_level_up.grow_vertical = Control.GROW_DIRECTION_BOTH
	_level_up.visible = true
	await get_tree().create_timer(2.0).timeout
	_level_up.visible = false


func show_banner(text: String, color: Color) -> void:
	_banner_label.text = text
	_banner.color = Color(color, 0.75)
	_banner.modulate.a = 0.0
	_banner.visible = true
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.7)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.2)
	await tw.finished
	_banner.visible = false


func show_end(text: String, color: Color) -> void:
	hide_info()
	hide_menu()
	hide_forecast()
	_banner_label.text = text + "\nPress Z to restart"
	_banner.color = Color(color, 0.85)
	_banner.modulate.a = 1.0
	_banner.visible = true


# --- Stats screen ----------------------------------------------------------------

func _make_status() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	_status_title = Label.new()
	left.add_child(_status_title)
	_status_stats = _make_pair_grid()
	left.add_child(_status_stats)
	var hint := Label.new()
	hint.text = "Up/Down: next unit\nX: close"
	hint.add_theme_color_override("font_color", DIM)
	left.add_child(hint)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	_status_combat = _make_pair_grid()
	right.add_child(_status_combat)
	_status_items = Label.new()
	right.add_child(_status_items)
	return panel


## Grid of label/value pairs, two pairs per row.
func _make_pair_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 0)
	return grid


func _fill_pair_grid(grid: GridContainer, pairs: Array) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for pair in pairs:
		var key := Label.new()
		key.text = pair[0]
		key.add_theme_color_override("font_color", DIM)
		grid.add_child(key)
		var value := Label.new()
		value.text = str(pair[1])
		value.custom_minimum_size.x = 16
		grid.add_child(value)


func show_status(unit: Unit) -> void:
	var title := "%s  Lv %d" % [unit.unit_name, unit.level]
	if unit.team == Unit.Team.PLAYER:
		title += "  EXP %d" % unit.exp_points
	title += "\nHP %d/%d" % [unit.hp, unit.max_hp]
	if unit.is_caster():
		title += "   MP %d/%d" % [unit.mp, unit.max_mp]
	_status_title.text = title

	var stats := [["STR", unit.strength]]
	if unit.is_caster():
		stats.append(["MAG", unit.magic])
	stats.append_array([["SKL", unit.skill], ["SPD", unit.speed], ["LCK", unit.luck],
		["DEF", unit.defense], ["RES", unit.resistance], ["MOV", unit.mov]])
	_fill_pair_grid(_status_stats, stats)

	# Combat numbers for the equipped weapon (before terrain and the weapon triangle).
	var armed := not unit.weapon.is_empty()
	var rng := "--"
	if armed:
		rng = str(unit.min_range) if unit.min_range == unit.max_range \
			else "%d-%d" % [unit.min_range, unit.max_range]
	_fill_pair_grid(_status_combat, [
		["Atk", Combat.base_attack(unit) if armed else "--"],
		["Hit", Combat.base_hit(unit) if armed else "--"],
		["Avo", Combat.base_avoid(unit)],
		["Crit", Combat.base_crit(unit) if armed else "--"],
		["AS", Combat.attack_speed(unit)],
		["Rng", rng],
	])

	var lines: Array[String] = ["Items"]
	if unit.items.is_empty():
		lines.append("  (none)")
	var equipped := unit.equipped_index()
	for i in unit.items.size():
		var item := unit.items[i]
		var mark := "E " if i == equipped else "   "
		if Items.is_weapon(item):
			var wr := str(item.min_rng) if item.min_rng == item.max_rng \
				else "%d-%d" % [item.min_rng, item.max_rng]
			lines.append("%s%s  %d  %s %s" % [mark, item.name, item.uses, item.type, wr])
		else:
			lines.append("%s%s  %d" % [mark, item.name, item.uses])
	if not unit.spells.is_empty():
		lines.append("Spells")
		for s in unit.spells:
			var spell := Spells.get_spell(s)
			lines.append("   %s  %dMP  %s" % [s, spell.mp, str(spell.max_rng)
				if spell.min_rng == spell.max_rng else "%d-%d" % [spell.min_rng, spell.max_rng]])
	if unit.is_dancer:
		lines.append("Skill: Dance")
	_status_items.text = "\n".join(lines)
	_status.visible = true


func hide_status() -> void:
	_status.visible = false
