class_name StatusScreen
extends Control
## Full-screen unit info, modeled on GBA Fire Emblem's status screen.
##
## Left third (always shown): portrait, name, class, race, level/EXP, HP and MP.
## Right side: pages flipped with Left/Right. Stats (capped stats glow green), Items
## (inventory, combat numbers, spells), Skills, and Biography (player units only).
## Detail mode (D): a highlight moves over the entries of the left column and the
## current page, and a box explains the highlighted one (text from Glossary).

const DIM := Color(0.7, 0.75, 0.95)
const CAPPED := Color(0.45, 1.0, 0.45)
const BAR_BG := Color(0.05, 0.07, 0.22)
const BAR_FILL := Color(0.55, 0.75, 1.0)
const HP_FILL := Color("5ee05e")
const MP_FILL := Color("5aa0ff")
const PAGES: Array[String] = ["Stats", "Items", "Skills", "Bio"]
const STAT_ROWS := [["str", "STR"], ["int", "INT"], ["dex", "DEX"], ["agi", "AGI"],
	["lck", "LCK"], ["def", "DEF"]]
const LEFT_WIDTH := 80
const PAGE_ORIGIN := Vector2(86, 17)
const PAGE_WIDTH := 150.0

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
var _page: Control
var _tabs: Array[Label] = []
var _hint: Label
var _highlight: Panel
var _desc_panel: PanelContainer
var _desc_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.38)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var divider := ColorRect.new()
	divider.color = Color(0.85, 0.85, 1.0, 0.6)
	divider.position = Vector2(LEFT_WIDTH, 4)
	divider.size = Vector2(1, 140)
	add_child(divider)

	_left = Control.new()
	add_child(_left)
	_page = Control.new()
	_page.position = PAGE_ORIGIN
	add_child(_page)
	for i in PAGES.size():
		var tab := _label(self, PAGES[i], Vector2(PAGE_ORIGIN.x + i * 37, 3))
		_tabs.append(tab)
	_hint = _label(self, "", Vector2(4, 148), DIM)

	_highlight = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(1.0, 0.85, 0.25)
	sb.set_border_width_all(1)
	_highlight.add_theme_stylebox_override("panel", sb)
	_highlight.visible = false
	add_child(_highlight)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size.x = 140
	_desc_panel = PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.08, 0.1, 0.3)  # opaque: the page behind shouldn't show through
	box_style.border_color = Color(0.85, 0.85, 1.0)
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(2)
	box_style.set_content_margin_all(3)
	_desc_panel.add_theme_stylebox_override("panel", box_style)
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
			_label(_page, "No skills yet.", Vector2(0, 2), DIM)
		"Bio":
			_render_bio()
	for i in _tabs.size():
		_tabs[i].visible = i < page_count()
		_tabs[i].add_theme_color_override("font_color", Color.WHITE if i == page else DIM)
		_tabs[i].text = ("[%s]" if i == page else " %s ") % PAGES[i]
	_update_detail()


func _render_left() -> void:
	# Portrait placeholder: team color, initial, movement badge (until there's art).
	var frame := ColorRect.new()
	frame.color = Color.BLACK
	frame.position = Vector2(15, 5)
	frame.size = Vector2(50, 50)
	_left.add_child(frame)
	var portrait := ColorRect.new()
	portrait.color = Unit.PLAYER_COLOR if unit.team == Unit.Team.PLAYER else Unit.ENEMY_COLOR
	portrait.position = Vector2(16, 6)
	portrait.size = Vector2(48, 48)
	_left.add_child(portrait)
	var initial := _label(portrait, unit.unit_name.left(1), Vector2.ZERO)
	initial.add_theme_font_size_override("font_size", 28)
	initial.size = portrait.size
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if Unit.MOVE_TYPE_BADGES.has(unit.move_type):
		var badge := ColorRect.new()
		badge.color = Unit.MOVE_TYPE_BADGES[unit.move_type]
		badge.position = Vector2(40, 2)
		badge.size = Vector2(6, 6)
		portrait.add_child(badge)

	var name_label := _label(_left, unit.unit_name, Vector2(0, 56))
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.size.x = LEFT_WIDTH
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_entry(_label(_left, unit.unit_class, Vector2(6, 70)), Glossary.unit_class(unit))
	_entry(_label(_left, unit.race, Vector2(6, 80)), Glossary.race(unit))
	_entry(_label(_left, "Lv %d" % unit.level, Vector2(6, 91)), Glossary.stat("lv", unit))
	if unit.team == Unit.Team.PLAYER:
		_entry(_label(_left, "Exp %d" % unit.exp_points, Vector2(40, 91)), Glossary.stat("exp", unit))
	_entry(_label(_left, "HP %d/%d" % [unit.hp, unit.max_hp], Vector2(6, 103)), Glossary.stat("hp", unit))
	_bar(_left, Vector2(6, 114), 68, float(unit.hp) / unit.max_hp, HP_FILL)
	var max_mp := maxi(unit.max_mp, 1)
	_entry(_label(_left, "MP %d/%d" % [unit.mp, unit.max_mp], Vector2(6, 119)), Glossary.stat("mp", unit))
	_bar(_left, Vector2(6, 130), 68, float(unit.mp) / max_mp, MP_FILL)


func _render_stats() -> void:
	for i in STAT_ROWS.size():
		var key: String = STAT_ROWS[i][0]
		var row_y := i * 13.0
		var value: int = unit.get(Experience.STATS[key])
		var capped := unit.is_capped(key)
		_label(_page, STAT_ROWS[i][1], Vector2(0, row_y), DIM)
		var value_label := _label(_page, str(value), Vector2(30, row_y), CAPPED if capped else Color.WHITE)
		_entry(value_label, Glossary.stat(key, unit))
		var fill := _bar(_page, Vector2(50, row_y + 5), 90, float(value) / unit.stat_cap(key), CAPPED if capped else BAR_FILL)
		if capped:
			_glow.append(value_label)
			_glow.append(fill)
	var y := STAT_ROWS.size() * 13.0
	_label(_page, "MOV", Vector2(0, y), DIM)
	_entry(_label(_page, "%d  %s" % [unit.mov, unit.move_type.capitalize()], Vector2(30, y)),
		Glossary.STATS.mov + " " + Glossary.MOVE_TYPES.get(unit.move_type, ""))
	if unit.carrying:
		_label(_page, "Carrying %s (DEX/AGI halved)" % unit.carrying.unit_name, Vector2(0, y + 14), DIM)


func _render_items() -> void:
	if unit.items.is_empty():
		_label(_page, "No items", Vector2(0, 0), DIM)
	var equipped := unit.equipped_index()
	for i in unit.items.size():
		var it := unit.items[i]
		var y := i * 10.0
		if i == equipped:
			_label(_page, "E", Vector2(0, y), Color(1.0, 0.85, 0.25))
		_entry(_label(_page, it.name, Vector2(10, y)), Glossary.item(it))
		_label(_page, str(it.uses), Vector2(120, y))

	# Combat numbers for the equipped weapon (before terrain and the weapon triangle).
	var armed := not unit.weapon.is_empty()
	var rng := "--"
	if armed:
		rng = str(unit.min_range) if unit.min_range == unit.max_range \
			else "%d-%d" % [unit.min_range, unit.max_range]
	var numbers := [
		["Atk", Combat.base_attack(unit) if armed else "--", "atk"],
		["Hit", Combat.base_hit(unit) if armed else "--", "hit"],
		["Avo", Combat.base_avoid(unit), "avo"],
		["Crit", Combat.base_crit(unit) if armed else "--", "crit"],
		["AS", Combat.attack_speed(unit), "as"],
		["Rng", rng, "rng"],
	]
	for i in numbers.size():
		var pos := Vector2((i % 3) * 50.0, 56.0 + floorf(i / 3.0) * 11.0)
		_label(_page, numbers[i][0], pos, DIM)
		_entry(_label(_page, str(numbers[i][1]), pos + Vector2(22, 0)), Glossary.COMBAT[numbers[i][2]])

	if not unit.spells.is_empty():
		_label(_page, "Spells", Vector2(0, 82), DIM)
		for i in unit.spells.size():
			var s: String = unit.spells[i]
			var spell := Spells.get_spell(s)
			var y := 93.0 + i * 10.0
			_entry(_label(_page, s, Vector2(10, y)), Glossary.spell(s))
			_label(_page, "%dMP" % spell.mp, Vector2(120, y))


func _render_bio() -> void:
	if unit.biography.is_empty():
		_label(_page, "No notable events yet.", Vector2(0, 2), DIM)
		return
	var y := 0.0
	for event in unit.biography:
		# Wrapping must be set up before the text, or the label keeps its one-line width.
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = PAGE_WIDTH
		line.size = Vector2(PAGE_WIDTH, 0)
		line.text = "- " + event
		line.position = Vector2(0, y)
		_page.add_child(line)
		_entry(line, event)
		y += line.get_combined_minimum_size().y + 2


# --- Detail mode ------------------------------------------------------------------

func _update_detail() -> void:
	_hint.text = "Arrows: select   D/X: back" if detail \
		else "L/R: page  U/D: unit  D: info  X: close"
	var active := detail and not _entries.is_empty()
	_highlight.visible = active
	_desc_panel.visible = active
	if not active:
		return
	_detail_index = clampi(_detail_index, 0, _entries.size() - 1)
	var node: Control = _entries[_detail_index].node
	var rect := Rect2(node.global_position - global_position, node.get_combined_minimum_size().max(node.size))
	_highlight.position = rect.position - Vector2(2, 1)
	_highlight.size = rect.size + Vector2(4, 2)
	_desc_label.text = _entries[_detail_index].text
	_desc_panel.reset_size()
	# Like GBA help boxes: right under the highlighted entry (above it if there's no
	# room), in the page column so the left column stays readable.
	var box_h := _desc_panel.get_combined_minimum_size().y
	var y := rect.end.y + 2
	if y + box_h > 160.0:
		y = rect.position.y - box_h - 2
	_desc_panel.position = Vector2(LEFT_WIDTH + 4.0, y)


# --- Helpers ----------------------------------------------------------------------

func _label(parent: Node, text: String, pos: Vector2, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## Bar with a dark background; returns the fill so it can glow.
func _bar(parent: Node, pos: Vector2, width: float, fraction: float, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = BAR_BG
	back.position = pos
	back.size = Vector2(width, 3)
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos
	fill.size = Vector2(width * clampf(fraction, 0.0, 1.0), 3)
	parent.add_child(fill)
	return fill


func _entry(node: Control, text: String) -> void:
	_entries.append({"node": node, "text": text})
