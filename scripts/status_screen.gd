class_name StatusScreen
extends Control
## Full-screen unit info, modeled on GBA Fire Emblem's status screen, in the Gilded Night
## look (docs/ui_theme.md). Laid out in HD units (960x640): put it on a UiLayer.
##
## Left column (always shown): portrait, name, class, race, level/EXP, HP and MP.
## Right panel: pages flipped with Left/Right. Stats (capped stats glow green), Items
## (inventory, combat numbers, spells), Skills, and Biography (player units only).
## Detail mode (D): a highlight moves over the entries of the left column and the
## current page, and a box explains the highlighted one (text from Glossary).

const DIM := UiTheme.DIM
const CAPPED := Color8(130, 235, 120)
const CAPPED_TO := Color8(200, 255, 170)
const BAR_FROM := Color8(184, 145, 62)
const BAR_TO := UiTheme.GOLD_BRIGHT
const MP_FROM := Color8(84, 132, 220)
const MP_TO := Color8(170, 200, 255)
## Stats raised by skills.
const BOOSTED := UiTheme.GOLD_BRIGHT
## Page ids, translated where shown.
const PAGES: Array[String] = ["Stats", "Items", "Skills", "Bio"]  # i18n
const STAT_ROWS := [["str", "STR"], ["int", "INT"], ["dex", "DEX"], ["agi", "AGI"],  # i18n
	["lck", "LCK"], ["def", "DEF"]]
const MARGIN := 40.0
const LEFT_WIDTH := 300.0
## The page panel, and where pages start inside it.
const PANEL_RECT := Rect2(384, 40, 536, 548)
const PAGE_ORIGIN := Vector2(36, 86)
const PAGE_WIDTH := 464.0
const PORTRAIT := Vector2(260, 216)

## The dark veil behind the screen: see-through over the battle map, opaque over a busy
## screen (the prep screen sets 1). Set before the screen enters the tree.
var veil_alpha := 0.92
var unit: Unit
var page := 0
var detail := false

## Detail-mode targets: [{"node": Control, "text": String}]. The first
## `_left_count` belong to the left column, the rest to the current page.
var _entries: Array = []
var _left_count := 0
var _detail_index := 0
## Nodes drawn in the capped color; _process makes them pulse.
var _glow: Array[CanvasItem] = []
var _time := 0.0

var _left: Control
var _panel: Panel
var _page: Control
var _tabs: Array[Label] = []
var _hint: Label
var _highlight: Panel
var _desc_panel: PanelContainer
var _desc_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = UiLayer.SIZE
	var bg := ColorRect.new()
	bg.color = Color(6 / 255.0, 7 / 255.0, 20 / 255.0, veil_alpha)
	bg.size = UiLayer.SIZE
	add_child(bg)

	_left = Control.new()
	add_child(_left)
	_panel = Panel.new()
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	add_child(_panel)
	_page = Control.new()
	_page.position = PAGE_ORIGIN
	_panel.add_child(_page)
	for i in PAGES.size():
		var tab := _label(_panel, tr(PAGES[i]), Vector2(PAGE_ORIGIN.x + i * 118, 26), &"CaptionLabel")
		tab.add_theme_font_size_override("font_size", 18)
		_tabs.append(tab)
	_hint = _label(self, "", Vector2(PANEL_RECT.position.x, PANEL_RECT.end.y + 10), &"SubLabel")

	_highlight = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.GOLD, 0.12)
	sb.border_color = UiTheme.GOLD_BRIGHT
	sb.set_border_width_all(1)
	_highlight.add_theme_stylebox_override("panel", sb)
	_highlight.visible = false
	add_child(_highlight)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	_desc_label.custom_minimum_size.x = PAGE_WIDTH - 40
	_desc_panel = PanelContainer.new()
	var box: GildedStyleBox = UiTheme.hd().get_stylebox("panel", "PanelContainer").duplicate()
	box.fill_top = Color(UiTheme.NAVY_TOP, 1.0)  # opaque: the page behind shouldn't show through
	box.fill_bottom = Color(UiTheme.NAVY_BOTTOM, 1.0)
	_desc_panel.add_theme_stylebox_override("panel", box)
	_desc_panel.visible = false
	_desc_panel.add_child(_desc_label)
	add_child(_desc_panel)


func _process(delta: float) -> void:
	if not visible or _glow.is_empty():
		return
	_time += delta
	var pulse := 0.75 + 0.25 * sin(_time * 5.0)
	for node in _glow:
		node.modulate = Color(1, 1, 1, pulse)


# --- Public API -----------------------------------------------------------------

## Shows `u`, keeping the current page when possible (Up/Down cycling keeps it).
func show_unit(u: Unit) -> void:
	unit = u
	page = mini(page, page_count() - 1)
	detail = false
	_render()
	visible = true


func close() -> void:
	visible = false
	detail = false
	page = 0


## Biography is a player-only page.
func page_count() -> int:
	return PAGES.size() if unit.team == Unit.Team.PLAYER else PAGES.size() - 1


func change_page(step: int) -> void:
	page = wrapi(page + step, 0, page_count())
	_render()


func enter_detail() -> void:
	if _entries.is_empty():
		return
	detail = true
	# Start on the page's first entry when it has any, otherwise on the left column.
	_detail_index = _left_count if _entries.size() > _left_count else 0
	_update_detail()


func exit_detail() -> void:
	detail = false
	_update_detail()


## Up/Down steps through the entries; Left/Right jumps between the left column and the page.
func move_detail(dir: Vector2i) -> void:
	if dir.y != 0:
		_detail_index = wrapi(_detail_index + dir.y, 0, _entries.size())
	elif dir.x != 0 and _entries.size() > _left_count:
		_detail_index = _left_count if _detail_index < _left_count else 0
	_update_detail()


func highlighted_text() -> String:
	return _entries[_detail_index].text if detail else ""


# --- Rendering ------------------------------------------------------------------

func _render() -> void:
	_glow.clear()
	_entries.clear()
	for parent in [_left, _page]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_render_left()
	_left_count = _entries.size()
	match PAGES[page]:
		"Stats":
			_render_stats()
		"Items":
			_render_items()
		"Skills":
			_render_skills()
		"Bio":
			_render_bio()
	for i in _tabs.size():
		_tabs[i].visible = i < page_count()
		_tabs[i].add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT if i == page else DIM)
		if i == page:
			_tabs[i].add_theme_stylebox_override("normal", UiTheme.tab_underline())
		else:
			_tabs[i].remove_theme_stylebox_override("normal")
	_update_detail()


func _render_left() -> void:
	# Portrait placeholder in a gilded frame: team color, class icon or initial, movement
	# badge (until units have portraits).
	var frame := PanelContainer.new()
	frame.position = Vector2(MARGIN, MARGIN)
	_left.add_child(frame)
	var portrait := Panel.new()
	portrait.custom_minimum_size = PORTRAIT
	var style := StyleBoxFlat.new()
	style.bg_color = Factions.COLORS[unit.team].darkened(0.3)
	portrait.add_theme_stylebox_override("panel", style)
	frame.add_child(portrait)
	var icon := ClassIcon.for_class(unit.unit_class)
	if not icon.is_empty():
		var view := ClassIcon.new()
		view.pixels = icon
		view.position = Vector2(36, 24)
		view.size = PORTRAIT - Vector2(72, 48)
		portrait.add_child(view)
	else:
		var initial := _label(portrait, unit.token_letter(), Vector2.ZERO)
		initial.add_theme_font_override("font", UiTheme.display(700))
		initial.add_theme_font_size_override("font_size", 110)
		initial.size = PORTRAIT
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if Unit.MOVE_TYPE_BADGES.has(unit.move_type):
		var badge := ColorRect.new()
		badge.color = Unit.MOVE_TYPE_BADGES[unit.move_type]
		badge.position = Vector2(PORTRAIT.x - 34, 10)
		badge.size = Vector2(24, 24)
		portrait.add_child(badge)

	var x := MARGIN + 6
	var name_label := _label(_left, unit.unit_name, Vector2(MARGIN, 312), &"NameLabel")
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.size.x = LEFT_WIDTH
	_entry(_label(_left, unit.class_display_name(), Vector2(x, 362)), Glossary.unit_class(unit))
	_entry(_label(_left, unit.race, Vector2(x, 394), &"SubLabel"), Glossary.race(unit))
	_entry(_label(_left, tr("Lv %d") % unit.level, Vector2(x, 432)), Glossary.stat("lv", unit))
	if unit.team == Unit.Team.PLAYER:
		_entry(_label(_left, tr("Exp %d") % unit.exp_points, Vector2(x + 110, 432)), Glossary.stat("exp", unit))
	_meter(Vector2(x, 476), "HP", unit.hp, unit.max_hp, UiTheme.HP_FROM, UiTheme.HP_TO, Glossary.stat("hp", unit))
	_meter(Vector2(x, 514), "MP", unit.mp, unit.max_mp, MP_FROM, MP_TO, Glossary.stat("mp", unit))


## A caption, a bar and "cur / max" in a row of the left column; the numbers are the entry.
func _meter(pos: Vector2, caption: String, value: int, most: int, from: Color, to: Color, help: String) -> void:
	_label(_left, tr(caption), pos + Vector2(0, 6), &"CaptionLabel")
	_bar(_left, pos + Vector2(46, 14), 150, float(value) / maxi(most, 1), from, to)
	var numbers := _label(_left, "%d / %d" % [value, most], pos + Vector2(206, 0))
	numbers.custom_minimum_size.x = 90
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_entry(numbers, help)


func _render_stats() -> void:
	const ROW := 42.0
	for i in STAT_ROWS.size():
		var key: String = STAT_ROWS[i][0]
		var row_y := i * ROW
		var bonus := Skills.stat_bonus(unit, key)
		var own: int = unit.get(Experience.STATS[key])
		var value: int = unit.ridden(own, key) + bonus
		var capped := unit.is_capped(key)
		_label(_page, tr(STAT_ROWS[i][1]), Vector2(0, row_y + 7), &"CaptionLabel")
		var value_label := _label(_page, str(value), Vector2(60, row_y))
		value_label.custom_minimum_size.x = 40
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if capped or bonus > 0:
			value_label.add_theme_color_override("font_color", CAPPED if capped else BOOSTED)
		var text := Glossary.stat(key, unit)
		if bonus != 0:
			text += " " + tr("Skills: %+d.") % bonus
		if not unit.mount.is_empty():
			text += " " + tr("Mounted: rider %d / 2 + %s %d.") % [own, unit.mount.name, unit.mount.stats.get(key, 0)]
		_entry(value_label, text)
		var fill := _bar(_page, Vector2(124, row_y + 13), 300, float(value) / unit.stat_cap(key),
			CAPPED if capped else BAR_FROM, CAPPED_TO if capped else BAR_TO)
		fill.glow = capped
		if capped:
			_glow.append(value_label)
			_glow.append(fill)
	var y := STAT_ROWS.size() * ROW + 8
	_label(_page, tr("MOV"), Vector2(0, y + 7), &"CaptionLabel")
	var mov := _label(_page, "%d  %s" % [unit.mov, unit.move_type.capitalize()], Vector2(84, y))
	if Skills.stat_bonus(unit, "mov") > 0:
		mov.add_theme_color_override("font_color", BOOSTED)
	_entry(mov, tr(Glossary.STATS.mov) + " " + (tr(Glossary.MOVE_TYPES[unit.move_type]) if Glossary.MOVE_TYPES.has(unit.move_type) else ""))
	y += ROW
	if not unit.mount.is_empty():
		var m := unit.mount
		_entry(_label(_page, tr("%s: %s Lv %d (%s)") % [m.species, m.name, m.level, m.gender.capitalize()],
			Vector2(0, y), &"SubLabel"), Mounts.species_data(m.species).description)
		y += 34
	if unit.carrying:
		_label(_page, tr("Carrying %s (DEX/AGI halved)") % unit.carrying.unit_name, Vector2(0, y), &"SubLabel")
		y += 34
	_render_statuses(Vector2(0, y))


## One square per status in its map color, with its initial (placeholders for icons);
## highlight one in detail mode for what it does and how long it lasts.
func _render_statuses(pos: Vector2) -> void:
	if unit.statuses.is_empty():
		return
	_label(_page, tr("Status"), pos + Vector2(0, 7), &"CaptionLabel")
	var x := 84.0
	for status: String in unit.statuses:
		var square := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Statuses.get_data(status).color
		style.border_color = UiTheme.GOLD
		style.set_border_width_all(1)
		square.add_theme_stylebox_override("panel", style)
		square.position = Vector2(x, pos.y + 2)
		square.size = Vector2(30, 30)
		_page.add_child(square)
		var initial := _label(square, status.left(1), Vector2.ZERO)
		initial.add_theme_font_override("font", UiTheme.display(700))
		initial.add_theme_font_size_override("font_size", 18)
		initial.size = square.size
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_entry(square, "%s (%s): %s" % [status, Statuses.duration_text(unit.statuses[status]).to_lower(),
			Statuses.get_data(status).description])
		x += 38.0


func _render_items() -> void:
	const ROW := 36.0
	if unit.items.is_empty():
		_label(_page, tr("No items"), Vector2(0, 0), &"SubLabel")
	var equipped := unit.equipped_index()
	for i in unit.items.size():
		var it := unit.items[i]
		var y := i * ROW
		if i == equipped:
			var mark := _label(_page, tr("E"), Vector2(0, y + 6), &"CaptionLabel")
			mark.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
		_entry(_label(_page, it.name, Vector2(30, y)), Glossary.item(it))
		var uses := _label(_page, str(it.get("uses", "")), Vector2(PAGE_WIDTH - 80, y))
		uses.custom_minimum_size.x = 60
		uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Combat numbers for the equipped weapon (before terrain and the weapon triangle).
	var armed := not unit.weapon.is_empty()
	var rng := "--"
	if armed:
		rng = str(unit.min_range) if unit.min_range == unit.max_range \
			else "%d-%d" % [unit.min_range, unit.max_range]
	var numbers := [  # i18n
		["Atk", Combat.base_attack(unit) if armed else "--", "atk"],
		["Hit", Combat.base_hit(unit) if armed else "--", "hit"],
		["Avo", Combat.base_avoid(unit), "avo"],
		["Crit", Combat.base_crit(unit) if armed else "--", "crit"],
		["AS", Combat.attack_speed(unit), "as"],
		["Rng", rng, "rng"],
	]
	var top := Unit.MAX_ITEMS * ROW + 18
	_divider(top - 10)
	for i in numbers.size():
		var pos := Vector2((i % 3) * 156.0, top + floorf(i / 3.0) * 38.0)
		_label(_page, tr(numbers[i][0]), pos + Vector2(0, 7), &"CaptionLabel")
		_entry(_label(_page, str(numbers[i][1]), pos + Vector2(62, 0)), tr(Glossary.COMBAT[numbers[i][2]]))

	if not unit.spells.is_empty():
		var spells_top := top + 92
		_divider(spells_top - 10)
		_label(_page, tr("Spells"), Vector2(0, spells_top + 7), &"CaptionLabel")
		for i in unit.spells.size():
			var s: String = unit.spells[i]
			var spell := Spells.get_spell(s)
			var y := spells_top + 32 + i * ROW
			_entry(_label(_page, s, Vector2(30, y)), Glossary.spell(s))
			var cost := _label(_page, tr("%dMP") % spell.mp, Vector2(PAGE_WIDTH - 120, y))
			cost.custom_minimum_size.x = 100
			cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Every visible skill with where it comes from; learned skills count toward the cap.
func _render_skills() -> void:
	const ROW := 38.0
	var shown := Skills.visible_sources(unit)
	if shown.is_empty():
		_label(_page, tr("No skills."), Vector2(0, 2), &"SubLabel")
	for i in shown.size():
		var skill: String = shown[i][0]
		var y := i * ROW
		_entry(_label(_page, skill, Vector2(0, y)), "%s: %s" % [skill, Skills.get_data(skill).description])
		_label(_page, tr(shown[i][1]), Vector2(250, y + 3), &"SubLabel")
	_label(_page, tr("Learned %d/%d") % [unit.learned.size(), Skills.LEARNED_CAP], Vector2(0, 400), &"SubLabel")


func _render_bio() -> void:
	if unit.biography.is_empty():
		_label(_page, tr("No notable events yet."), Vector2(0, 2), &"SubLabel")
		return
	var y := 0.0
	for entry in unit.biography:
		var event := Text.render(entry)
		# Wrapping must be set up before the text, or the label keeps its one-line width.
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_override("font", UiTheme.body(true))
		line.custom_minimum_size.x = PAGE_WIDTH
		line.size = Vector2(PAGE_WIDTH, 0)
		line.text = "– " + event
		line.position = Vector2(0, y)
		_page.add_child(line)
		_entry(line, event)
		y += line.get_combined_minimum_size().y + 8


## A faint gold rule across the page.
func _divider(y: float) -> void:
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.3)
	rule.position = Vector2(0, y)
	rule.size = Vector2(PAGE_WIDTH, 1)
	_page.add_child(rule)


# --- Detail mode ------------------------------------------------------------------

func _update_detail() -> void:
	_hint.text = tr("Arrows: select   D/X: back") if detail \
		else tr("L/R: page  U/D: unit  D: info  X: close")
	var active := detail and not _entries.is_empty()
	_highlight.visible = active
	_desc_panel.visible = active
	if not active:
		return
	_detail_index = clampi(_detail_index, 0, _entries.size() - 1)
	var node: Control = _entries[_detail_index].node
	var rect := Rect2(node.global_position - global_position, node.get_combined_minimum_size().max(node.size))
	_highlight.position = rect.position - Vector2(8, 3)
	_highlight.size = rect.size + Vector2(16, 6)
	_desc_label.text = _entries[_detail_index].text
	_desc_panel.reset_size()
	# Like GBA help boxes: right under the highlighted entry (above it if there's no
	# room), in the page column so the left column stays readable.
	var box_h := _desc_panel.get_combined_minimum_size().y
	var y := rect.end.y + 10
	if y + box_h > UiLayer.SIZE.y - 12:
		y = rect.position.y - box_h - 10
	_desc_panel.position = Vector2(PANEL_RECT.position.x + 16, y)


# --- Helpers ----------------------------------------------------------------------

func _label(parent: Node, text: String, pos: Vector2, variation := &"") -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.theme_type_variation = variation
	parent.add_child(label)
	return label


## A gilded bar; returned so it can glow.
func _bar(parent: Node, pos: Vector2, width: float, fraction: float, from: Color, to: Color) -> GildedBar:
	var bar := GildedBar.new()
	bar.position = pos
	bar.size = Vector2(width, 8)
	bar.ratio = fraction
	bar.fill_from = from
	bar.fill_to = to
	parent.add_child(bar)
	return bar


func _entry(node: Control, text: String) -> void:
	_entries.append({"node": node, "text": text})
