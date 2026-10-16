class_name BattleUI
extends CanvasLayer
## HUD: unit/terrain info, action menu, combat forecast, phase banner, end screen.
## The HUD windows and the dialogue are on an HD layer (UiLayer, Gilded Night:
## docs/ui_theme.md), laid out in 960x640 units, and the status screen on another one on
## top; the unit list and options still use the old 240x160 look on this layer, between
## the two.

var menu_options: Array[String] = []
var menu_index := 0
## Optional prompt shown above the menu options (e.g. the end-turn warning).
var _menu_title := ""
## Level-up windows wait for confirm; the test suite turns this off (2 s timeout instead).
var level_up_waits := true
## Dialogue box for map events (see BattleEvents).
var dialogue: DialogueBox
## Top-left map cell on screen (from BattleCamera), for placing panels away from the cursor.
var view_origin := Vector2i.ZERO
signal level_up_confirmed
var _fast_forward: Label

## Old-look screens, in 240x160 units.
var _root: Control
## The HUD windows, in 960x640 units.
var _hd: UiLayer
## Unit card: face, side, name, class and level, HP (and MP) bars, then the details.
var _card: PanelContainer
var _face: Panel
var _face_icon: ClassIcon
var _face_letter: Label
var _card_side: Label
var _card_name: Label
var _card_sub: Label
var _hp_bar: GildedBar
var _hp_text: Label
var _mp_row: HBoxContainer
var _mp_bar: GildedBar
var _mp_text: Label
## Weapon, items, spells, notes and stats.
var _card_details: Label
## Terrain window: the terrain's name and its bonus (or a breakable tile's HP).
var _terrain: PanelContainer
var _terrain_name: Label
var _terrain_bonus: Label
var _menu: PanelContainer
var _menu_prompt: Label
## One label per visible menu row (MENU_ROWS); the selected one holds the cursor.
var _menu_rows: Array[Label] = []
var _menu_cursor: DiamondCursor
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
var _banner: GildedBanner
## GBA-style unit info screen.
var status_screen: StatusScreen
## Sortable table of every unit (map menu > Units).
var unit_list: UnitListScreen
## Map menu > Options.
var options_screen: OptionsScreen
var _objective: PanelContainer
var _objective_label: Label

## Gap between HUD windows and the screen edge, in HD units.
const MARGIN := 28
## Map rows and columns on screen (16 px cells on the 240x160 screen).
const SCREEN_CELLS := Vector2i(15, 10)
const MENU_ROW_HEIGHT := 44
const MP_FROM := Color8(84, 132, 220)
const MP_TO := Color8(170, 200, 255)


func _ready() -> void:
	# The HD layer goes under this one, so the old-look full-screen views cover the HUD.
	layer = 2
	_hd = UiLayer.new(1)
	add_child(_hd)
	_root = Control.new()
	_root.theme = UiTheme.legacy()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_card = _make_card()
	_terrain = _make_terrain()
	_menu = _make_menu()
	_forecast = _make_forecast()
	_spell_label = Label.new()
	_spell_forecast = _make_panel(_spell_label)
	_level_up = _make_level_up()
	_trade = _make_trade()
	_objective_label = Label.new()
	_objective = _make_panel(_objective_label)
	# The unit list goes under the status screen, which can be opened from it.
	unit_list = UnitListScreen.new()
	_root.add_child(unit_list)
	dialogue = DialogueBox.new()
	_hd.root.add_child(dialogue)
	# The status screen opens from the unit list, so its HD layer goes above this one.
	var top := UiLayer.new(3)
	add_child(top)
	status_screen = StatusScreen.new()
	top.root.add_child(status_screen)
	options_screen = OptionsScreen.new()
	_root.add_child(options_screen)

	_fast_forward = Label.new()
	_fast_forward.visible = false
	_fast_forward.theme_type_variation = "CaptionLabel"
	_fast_forward.add_theme_font_size_override("font_size", 18)
	_fast_forward.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	_fast_forward.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_fast_forward.add_theme_constant_override("outline_size", 6)
	_hd.root.add_child(_fast_forward)
	_fast_forward.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_fast_forward.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_banner = GildedBanner.new()
	_banner.visible = false
	_hd.root.add_child(_banner)


## A HUD window holding `content`, hidden until placed.
func _make_panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.add_child(content)
	_hd.root.add_child(panel)
	return panel


func _label(parent: Control, variation := &"", text := "") -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	parent.add_child(label)
	return label


func _make_card() -> PanelContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	column.add_child(head)
	# Face: a placeholder until units have portraits (team color, class icon or initial).
	_face = Panel.new()
	_face.custom_minimum_size = Vector2(76, 76)
	_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_face)
	_face_icon = ClassIcon.new()
	_face.add_child(_face_icon)
	_face_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	_face_letter = _label(_face)
	_face_letter.add_theme_font_override("font", UiTheme.display(700))
	_face_letter.add_theme_font_size_override("font_size", 40)
	_face_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	_card_side = _label(info, &"CaptionLabel")
	_card_name = _label(info, &"NameLabel")
	_card_sub = _label(info, &"SubLabel")
	var hp_row := _bar_row(info, "HP")
	_hp_bar = hp_row.get_child(1)
	_hp_text = hp_row.get_child(2)
	_mp_row = _bar_row(info, "MP")
	_mp_bar = _mp_row.get_child(1)
	_mp_bar.fill_from = MP_FROM
	_mp_bar.fill_to = MP_TO
	_mp_text = _mp_row.get_child(2)
	_card_details = _label(column)
	_card_details.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	_card_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_details.custom_minimum_size.x = 430
	return _make_panel(column)


## A caption, a bar and a "cur / max" label in a row.
func _bar_row(parent: Control, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := _label(row, &"CaptionLabel", tr(caption))
	label.custom_minimum_size.x = 30
	var bar := GildedBar.new()
	bar.custom_minimum_size.x = 150
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value := _label(row)
	value.custom_minimum_size.x = 86
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return row


func _make_terrain() -> PanelContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_terrain_name = _label(column, &"TitleLabel")
	_terrain_bonus = _label(column, &"SubLabel")
	return _make_panel(column)


func _make_menu() -> PanelContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.custom_minimum_size.x = 250
	_menu_prompt = _label(column, &"SubLabel")
	_menu_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_prompt.custom_minimum_size.x = 340
	var selected: StyleBox = UiTheme.selected_row().duplicate()
	selected.content_margin_left = 44
	selected.content_margin_right = 24
	for i in MENU_ROWS:
		var row := _label(column)
		row.custom_minimum_size.y = MENU_ROW_HEIGHT
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_stylebox_override("normal", _plain_row())
		row.set_meta("selected_style", selected)
		_menu_rows.append(row)
	# Always in the tree (on the selected row), so it's freed with the HUD.
	_menu_cursor = DiamondCursor.new()
	_menu_rows[0].add_child(_menu_cursor)
	var panel := _make_panel(column)
	# The panel's own margins are kept small so the selection band reaches its edges.
	var sb: GildedStyleBox = panel.get_theme_stylebox("panel").duplicate()
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	return panel


## The MP row is only shown for spells, where current MP is the magic defense; the
## Status row only when a side's hits can inflict a status.
const FORECAST_ROWS: Array[String] = ["", "", "HP", "MP", "Dmg", "Hit", "Crit", "Status"]  # i18n
const DIM := UiTheme.DIM
const ADVANTAGE := Color8(160, 230, 120)
const DISADVANTAGE := Color8(240, 130, 110)
const EFFECTIVE := UiTheme.GOLD_BRIGHT


func _make_forecast() -> PanelContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 2)
	for row_index in FORECAST_ROWS.size():
		var row: Array[Label] = []
		for col in 3:
			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if col == 0 else HORIZONTAL_ALIGNMENT_CENTER
			if col == 0:
				label.text = tr(FORECAST_ROWS[row_index])
				label.theme_type_variation = &"CaptionLabel"
			elif row_index == 0:
				label.theme_type_variation = &"TitleLabel"
			else:
				label.custom_minimum_size.x = 124
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(label)
			row.append(label)
		_forecast_cells.append(row)
	return _make_panel(grid)


func _make_trade() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	for i in 2:
		var label := Label.new()
		label.custom_minimum_size.x = 360
		row.add_child(label)
		_trade_labels.append(label)
	return _make_panel(row)


func _make_level_up() -> PanelContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_level_title = _label(box, &"TitleLabel")
	_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	for key in Experience.STATS:
		var row: Array[Label] = []
		for col in 3:
			var label := Label.new()
			if col == 0:
				label.text = tr(Experience.STAT_LABELS[key])
				label.theme_type_variation = &"CaptionLabel"
				label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			elif col == 1:
				label.custom_minimum_size.x = 32
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			else:
				label.add_theme_color_override("font_color", ADVANTAGE)
				label.custom_minimum_size.x = 48
			grid.add_child(label)
			row.append(label)
		_level_rows.append(row)
	box.add_child(grid)
	var hint := _label(box, &"SubLabel", tr("Z: continue"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return _make_panel(box)


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
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
	panel.visible = true


## A panel centered on the screen.
func _center(panel: Control) -> void:
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = true


## Put panels on the side of the screen away from the cursor (map cells are turned
## into screen cells with view_origin, so this works on scrolled maps).
func _away_right(cursor_cell: Vector2i) -> bool:
	return (cursor_cell - view_origin).x < 8


## Whether the cursor is in the top `rows` rows of the screen.
func _near_top(cursor_cell: Vector2i, rows: int) -> bool:
	return (cursor_cell - view_origin).y < rows


## Whether the cursor is in the bottom `rows` rows of the screen.
func _near_bottom(cursor_cell: Vector2i, rows: int) -> bool:
	return (cursor_cell - view_origin).y >= SCREEN_CELLS.y - rows


## The unit card (when there's a unit) and the terrain window, on the side of the screen
## away from the cursor: the card at the top unless the cursor is near it, the terrain at
## the other end. `tile_hp` is the remaining HP of a breakable tile (-1 otherwise); it's
## shown instead of the terrain bonuses.
func update_info(unit: Unit, terrain: Dictionary, cursor_cell: Vector2i, tile_hp := -1) -> void:
	_terrain_name.text = terrain.name
	# Show the bonus the unit on the tile actually gets (fliers and spirits get none).
	if tile_hp >= 0:
		_terrain_bonus.text = tr("HP %d/%d") % [tile_hp, terrain.breakable.hp]
	elif unit and BattleMap.NO_TERRAIN_BONUS.has(unit.move_type):
		_terrain_bonus.text = tr("No bonus (%s)") % unit.move_type.capitalize()
	else:
		_terrain_bonus.text = tr("DEF %+d · AVO %+d") % [terrain.def, terrain.avo]
	var right := _away_right(cursor_cell)
	if not unit:
		_card.visible = false
		_place(_terrain, right, not _near_bottom(cursor_cell, 3))
		return
	_fill_card(unit)
	var card_bottom := _near_top(cursor_cell, 4)
	_place(_card, right, card_bottom)
	_place(_terrain, right, not card_bottom)


func _fill_card(unit: Unit) -> void:
	var face_style := StyleBoxFlat.new()
	face_style.bg_color = Factions.COLORS[unit.team].darkened(0.25)
	face_style.border_color = UiTheme.GOLD
	face_style.set_border_width_all(1)
	_face.add_theme_stylebox_override("panel", face_style)
	_face_icon.pixels = ClassIcon.for_class(unit.unit_class)
	_face_icon.queue_redraw()
	_face_letter.text = unit.token_letter() if _face_icon.pixels.is_empty() else ""
	_card_side.text = tr(Factions.NAMES[unit.team])
	_card_side.add_theme_color_override("font_color", Factions.COLORS[unit.team].lerp(Color.WHITE, 0.5))
	_card_name.text = unit.unit_name
	var sub: Array[String] = [unit.class_display_name(), tr("Lv %d") % unit.level]
	if unit.team == Unit.Team.PLAYER:
		sub.append(tr("EXP %d") % unit.exp_points)
	_card_sub.text = " · ".join(sub)
	_hp_bar.ratio = float(unit.hp) / maxi(1, unit.max_hp)
	_hp_text.text = "%d / %d" % [unit.hp, unit.max_hp]
	_mp_row.visible = unit.max_mp > 0
	_mp_bar.ratio = float(unit.mp) / maxi(1, unit.max_mp)
	_mp_text.text = "%d / %d" % [unit.mp, unit.max_mp]

	var lines: Array[String] = []
	if not unit.weapon.is_empty():
		var rng := str(unit.min_range) if unit.min_range == unit.max_range \
			else "%d-%d" % [unit.min_range, unit.max_range]
		lines.append(tr("%s (%d)  Rng %s  [%d/%d]") % [unit.weapon.name, unit.weapon.uses, rng,
			unit.items.size(), Unit.MAX_ITEMS])
	elif not unit.is_caster():
		lines.append(tr("No weapon"))
	var others: Array[String] = []
	for i in unit.items.size():
		if not Items.is_weapon(unit.items[i]):
			others.append(item_label(unit, i))
	if not others.is_empty():
		lines.append(tr("Items: %s") % ", ".join(others))
	if not unit.spells.is_empty():
		lines.append(tr("Spells: %s") % ", ".join(unit.spells))
	lines.append_array(unit_notes(unit))
	var stats := tr("STR %d  DEX %d  AGI %d  LCK %d\nDEF %d  MOV %d") % [
		unit.combat_str(), unit.combat_dex(), unit.combat_agi(), unit.combat_lck(), unit.combat_def(), unit.mov]
	if unit.move_type != "foot":
		stats += " (%s)" % unit.move_type.capitalize()
	if unit.is_caster():
		stats += "  " + tr("INT %d") % unit.combat_int()
	lines.append(stats)
	_card_details.text = "\n".join(lines)


func hide_info() -> void:
	_card.visible = false
	_terrain.visible = false


func show_menu(options: Array[String], cursor_cell: Vector2i, title := "") -> void:
	menu_options = options
	menu_index = 0
	_menu_title = title
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


## Options the menu shows at once (it scrolls past that).
const MENU_ROWS := 9


## The menu's visible rows, as shown (for tests and debugging).
func menu_text() -> String:
	var shown: Array[String] = []
	for row in _menu_rows:
		if row.visible:
			shown.append(row.text)
	return "\n".join(shown)


func _refresh_menu() -> void:
	_menu_prompt.text = _menu_title
	_menu_prompt.visible = _menu_title != ""
	# A window of MENU_ROWS options that scrolls with the selection; "..." stands in
	# for options hidden above or below.
	var first := clampi(menu_index - MENU_ROWS / 2, 0, maxi(0, menu_options.size() - MENU_ROWS))
	var last := mini(first + MENU_ROWS, menu_options.size())
	for r in MENU_ROWS:
		var row := _menu_rows[r]
		var i := first + r
		row.visible = i < last
		if not row.visible:
			continue
		var hidden := (i == first and first > 0) or (i == last - 1 and last < menu_options.size())
		row.text = "..." if hidden else tr(menu_options[i])
		var selected := i == menu_index and not hidden
		row.add_theme_stylebox_override("normal", row.get_meta("selected_style") if selected else _plain_row())
		row.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT if selected else (UiTheme.DIM if hidden else UiTheme.TEXT))
		if selected:
			if _menu_cursor.get_parent() != row:
				_menu_cursor.reparent(row, false)
			_menu_cursor.position = Vector2(22, MENU_ROW_HEIGHT / 2.0)


var _plain: StyleBoxEmpty


## Unselected menu rows: no background, the same margins as the selected one.
func _plain_row() -> StyleBoxEmpty:
	if not _plain:
		_plain = StyleBoxEmpty.new()
		_plain.content_margin_left = 44
		_plain.content_margin_right = 24
	return _plain


## `atk_label` replaces the attacker's weapon name (e.g. with the spell being cast).
## `magic` shows each side's MP, which spells subtract instead of DEF.
func show_forecast(attacker: Unit, defender: Unit, f: Dictionary, cursor_cell: Vector2i, atk_label := "",
		magic := false) -> void:
	_fill_forecast_column(1, attacker, f.atk, true, atk_label)
	_fill_forecast_column(2, defender, f.def, f.can_counter)
	for label in _forecast_cells[3]:
		label.visible = magic
	var statuses: bool = not f.atk.get("inflict", {}).is_empty() or (f.can_counter and not f.def.get("inflict", {}).is_empty())
	for label in _forecast_cells[7]:
		label.visible = statuses
	_forecast_cells[7][1].text = inflict_text(f.atk.get("inflict", {}), defender)
	_forecast_cells[7][2].text = inflict_text(f.def.get("inflict", {}), attacker) if f.can_counter else "--"
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
	# Effectiveness and weaknesses (x3 / x2 might) beat the triangle color;
	# resistances halve damage.
	if stats.get("multiplier", 1) > 1:
		weapon_label.text += " x%d" % stats.multiplier
		weapon_label.add_theme_color_override("font_color", EFFECTIVE)
	if stats.get("resisted", false):
		weapon_label.text += " 1/2"
	cells[2].text = str(unit.hp)
	cells[3].text = str(unit.mp)
	cells[4].text = ("%d%s" % [stats.dmg, " x2" if stats.double else ""]) if can_attack else "--"
	cells[5].text = str(stats.hit) if can_attack else "--"
	cells[6].text = str(stats.crit) if can_attack else "--"


func show_heal_forecast(caster: Unit, target: Unit, spell_name: String, amount: int, cursor_cell: Vector2i) -> void:
	var cost: int = Spells.get_spell(spell_name).mp
	var effect := tr("HP %d -> %d") % [target.hp, target.hp + amount]
	if Spells.get_spell(spell_name).get("cures", false):
		effect = tr("Cures {statuses}").format({"statuses": ", ".join(target.statuses.keys())})
	_spell_label.text = tr("%s  (%d MP)\n%s  MP %d -> %d\n%s  %s") % [
		spell_name, cost, caster.unit_name, caster.mp, caster.mp - cost, target.unit_name, effect]
	_place(_spell_forecast, _away_right(cursor_cell), false)


## `rows`: [name, hp, dmg, hit] per enemy inside the blast.
## `note` is an extra line, e.g. the terrain change a terraforming spell will make.
func show_area_forecast(caster: Unit, spell_name: String, rows: Array, cursor_cell: Vector2i, note := "") -> void:
	var cost: int = Spells.get_spell(spell_name).mp
	var lines: Array[String] = [tr("%s  MP %d -> %d") % [spell_name, caster.mp, caster.mp - cost]]
	if rows.is_empty():
		lines.append(tr("No targets"))
	for r in rows:
		lines.append(tr("%s  HP %d  Dmg %d  Hit %d") % r)
	if note:
		lines.append(note)
	_spell_label.text = "\n".join(lines)
	_place(_spell_forecast, _away_right(cursor_cell), _near_top(cursor_cell, 5))


func show_rescue_forecast(target: Unit, cursor_cell: Vector2i) -> void:
	_spell_label.text = tr("Rescue {unit}\nDEX/AGI halved while carrying").format({"unit": target.unit_name})
	_place(_spell_forecast, _away_right(cursor_cell), false)


## `verb`: "Drop {unit}" (a rescued ally) or "Unload {unit}" (a ship's passenger), untranslated.
func show_drop_forecast(carried: Unit, dest_terrain: String, cursor_cell: Vector2i, verb := "Drop {unit}") -> void:
	_spell_label.text = tr(verb).format({"unit": carried.unit_name}) + "\n-> " + dest_terrain
	_place(_spell_forecast, _away_right(cursor_cell), false)


func show_board_forecast(ship: Unit, cursor_cell: Vector2i) -> void:
	_spell_label.text = tr("Board %s\nAboard: %d/%d") % [ship.unit_name, ship.passengers.size(),
		ship.passengers.size() + ship.cargo_space()]
	_place(_spell_forecast, _away_right(cursor_cell), false)


func show_inspire_forecast(allies: Array[Unit], bonus: int, cursor_cell: Vector2i) -> void:
	var names: Array[String] = []
	for a in allies:
		names.append(a.unit_name)
	_spell_label.text = tr("Inspire  STR/DEF +%d") % bonus + "\n" + ", ".join(names)
	_place(_spell_forecast, _away_right(cursor_cell), false)


func show_shove_forecast(target: Unit, dest_terrain: String, cursor_cell: Vector2i) -> void:
	_spell_label.text = tr("Shove") + "\n%s -> %s" % [target.unit_name, dest_terrain]
	_place(_spell_forecast, _away_right(cursor_cell), false)


## `duet` is BattleActions.duet's result: {} for a plain Dance.
func show_dance_forecast(target: Unit, duet: Dictionary, cursor_cell: Vector2i) -> void:
	if duet:
		var names: Array[String] = []
		for a: Unit in duet.refreshed:
			names.append(a.unit_name)
		_spell_label.text = tr("Duet") + "\n" + (", ".join(names) if names else tr("Nobody to refresh"))
	else:
		_spell_label.text = tr("Dance") + "\n" + tr("{unit} can act again").format({"unit": target.unit_name})
	_place(_spell_forecast, _away_right(cursor_cell), false)


## Forecast for actions aimed at a tile (Break, Open Door).
func show_cell_forecast(text: String, cursor_cell: Vector2i) -> void:
	_spell_label.text = text
	_place(_spell_forecast, _away_right(cursor_cell), false)


## Extra lines for the info panel and stats screen: command skills, buffs, cargo.
static func unit_notes(unit: Unit) -> Array[String]:
	var lines: Array[String] = []
	for pair in Skills.visible_sources(unit):
		if Skills.get_data(pair[0]).has("command") or Skills.get_data(pair[0]).has("abilities"):
			lines.append(TranslationServer.translate("Skill: %s") % pair[0])
	if not unit.statuses.is_empty():
		var shown: Array[String] = []
		for s: String in unit.statuses:
			var turns: int = unit.statuses[s]
			shown.append(s if turns < 0 else "%s (%d)" % [s, turns])
		lines.append(TranslationServer.translate("Status: %s") % ", ".join(shown))
	if unit.inspire_bonus > 0:
		lines.append(TranslationServer.translate("Inspired: STR/DEF +%d") % unit.inspire_bonus)
	if unit.carrying:
		lines.append(TranslationServer.translate("Carrying: %s (DEX/AGI halved)") % unit.carrying.unit_name)
	if unit.is_ship():
		var names: Array[String] = []
		for p in unit.passengers:
			names.append(p.unit_name)
		lines.append(TranslationServer.translate("Aboard (%d/%d): %s") % [unit.passengers.size(), unit.passengers.size() + unit.cargo_space(),
			", ".join(names) if not names.is_empty() else "--"])
	return lines


## Forecast Status cell: "Poison 100", "Immune" or "--".
static func inflict_text(inflict: Dictionary, target: Unit) -> String:
	if inflict.is_empty():
		return "--"
	if Skills.is_immune(target, inflict.status):
		return TranslationServer.translate("Immune")
	return "%s %d" % [inflict.status, inflict.get("chance", 100)]


static func item_label(unit: Unit, index: int) -> String:
	var item := unit.items[index]
	return Items.label(item, " ") + (" " + TranslationServer.translate("E") if index == unit.equipped_index() else "")


## Partner's inventory while choosing who to trade with.
func show_trade_preview(partner: Unit, cursor_cell: Vector2i) -> void:
	var lines: Array[String] = [tr("Trade with {unit}").format({"unit": partner.unit_name})]
	for i in partner.items.size():
		lines.append("  " + item_label(partner, i))
	if partner.items.is_empty():
		lines.append("  " + tr("(no items)"))
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
	_trade.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
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
	_level_title.text = tr("%s  Level Up!  Lv %d") % [unit.unit_name, unit.level]
	var i := 0
	for key in Experience.STATS:
		var row: Array = _level_rows[i]
		var shown: bool = unit.is_caster() or not key in Experience.CASTER_STATS
		for label in row:
			label.visible = shown
		row[1].text = str(before[key] + gains.get(key, 0))
		row[2].text = "+%d" % gains[key] if gains.has(key) else ""
		i += 1
	_center(_level_up)
	if level_up_waits and Settings.value("level_up_wait"):
		await level_up_confirmed
	else:
		await get_tree().create_timer(2.0).timeout
	_level_up.visible = false


## Confirm closes the level-up window. The battle ignores input while it's busy,
## so the window handles this itself.
func _unhandled_input(event: InputEvent) -> void:
	if _level_up.visible and event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		Sound.play("confirm")
		level_up_confirmed.emit()


## Shows the fast-forward speed in the top-right corner (hidden at normal speed).
func show_fast_forward(speed: float) -> void:
	_fast_forward.visible = speed > 1.0
	_fast_forward.text = ">> x%d" % int(speed)


## `text`'s first line is the title, the rest (e.g. the turn) goes under it.
func show_banner(text: String, color: Color) -> void:
	var lines := text.split("
", true, 1)
	_banner.show_text(lines[0], lines[1] if lines.size() > 1 else "", color)
	_banner.modulate.a = 0.0
	_banner.visible = true
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.7)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.2)
	await tw.finished
	_banner.visible = false


## `text` and `hint` come translated.
func show_end(text: String, color: Color, hint := "") -> void:
	if hint == "":
		hint = tr("Z: restart   X: level select")
	hide_info()
	hide_menu()
	hide_forecast()
	_banner.show_text(text, hint, color)
	_banner.modulate.a = 1.0
	_banner.visible = true


# --- Status screen (see StatusScreen) ---------------------------------------------

func show_status(unit: Unit) -> void:
	status_screen.show_unit(unit)


func hide_status() -> void:
	status_screen.close()


# --- Objective (map menu > Objective) ------------------------------------------------

func show_objective(lines: Array[String]) -> void:
	hide_info()
	_objective_label.text = "\n".join(lines)
	_center(_objective)


func hide_objective() -> void:
	_objective.visible = false
