class_name UnitListScreen
extends Control
## Every unit on the map in one sortable table (player units in blue, enemies in
## red, player units that already acted dimmed), in the Gilded Night look
## (docs/ui_theme.md). Laid out in HD units (960x640): put it on a UiLayer.
## Up/Down: row (scrolls). Left/Right: sort column. Z: put the cursor on the unit.
## D: its status screen. X: close. (Input is routed here by Battle.)

const DIM := UiTheme.DIM
const PLAYER_TEXT := Color8(165, 195, 255)
const ENEMY_TEXT := Color8(240, 150, 135)
const ACTED_TEXT := Color8(120, 118, 140)
const SORTED_HEADER := UiTheme.GOLD_BRIGHT
## key: what the column sorts by (see _value()). Name and Class sort A-Z, numbers high to low.
## x is inside the panel.
const COLUMNS := [
	{"title": "Name", "x": 48.0, "key": "name"},  # i18n
	{"title": "Class", "x": 226.0, "key": "class"},  # i18n
	{"title": "Lv", "x": 430.0, "key": "lv"},  # i18n
	{"title": "HP", "x": 490.0, "key": "hp"},  # i18n
	{"title": "Str", "x": 600.0, "key": "str"},  # i18n
	{"title": "Dex", "x": 662.0, "key": "dex"},  # i18n
	{"title": "Agi", "x": 724.0, "key": "agi"},  # i18n
	{"title": "Def", "x": 786.0, "key": "def"},  # i18n
	{"title": "Mov", "x": 848.0, "key": "mov"},  # i18n
]
const PANEL_RECT := Rect2(20, 20, 920, 568)
## The first row's top, inside the panel.
const TOP := 74.0
const ROW_H := 36.0
const VISIBLE_ROWS := 13

var units: Array[Unit] = []
var index := 0
var sort_col := 0
var _scroll := 0
var _panel: Panel
var _rows: Control
var _cursor: Panel
var _diamond: DiamondCursor
var _footer: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = UiLayer.SIZE
	var bg := ColorRect.new()
	bg.color = Color(6 / 255.0, 7 / 255.0, 20 / 255.0, 0.9)
	bg.size = UiLayer.SIZE
	add_child(bg)
	_panel = Panel.new()
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	add_child(_panel)
	_cursor = Panel.new()
	_cursor.theme_type_variation = &"SelectedRow"
	_cursor.size = Vector2(PANEL_RECT.size.x - 24, ROW_H)
	_cursor.position.x = 12
	_panel.add_child(_cursor)
	_diamond = DiamondCursor.new()
	_diamond.position = Vector2(22, ROW_H / 2.0)
	_cursor.add_child(_diamond)
	_rows = Control.new()
	_panel.add_child(_rows)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.3)
	rule.position = Vector2(28, TOP - 8)
	rule.size = Vector2(PANEL_RECT.size.x - 56, 1)
	_panel.add_child(rule)
	_footer = Label.new()
	_footer.theme_type_variation = &"SubLabel"
	_footer.position = Vector2(PANEL_RECT.position.x + 8, PANEL_RECT.end.y + 10)
	add_child(_footer)


func open(list: Array[Unit]) -> void:
	units = list.duplicate()
	index = 0
	_scroll = 0
	_sort()
	visible = true
	_render()


func close() -> void:
	visible = false


func selected_unit() -> Unit:
	return units[index] if not units.is_empty() else null


func move(step: int) -> void:
	if units.is_empty():
		return
	index = wrapi(index + step, 0, units.size())
	_render()


## Moves the selection to `u` (e.g. the unit the stats screen was flipped to).
func select_unit(u: Unit) -> void:
	if units.has(u):
		index = units.find(u)
		_render()


## Left/Right picks the sort column; the selection follows its unit.
func change_sort(step: int) -> void:
	var keep := selected_unit()
	sort_col = wrapi(sort_col + step, 0, COLUMNS.size())
	_sort()
	index = maxi(0, units.find(keep))
	_render()


func _sort() -> void:
	var key: String = COLUMNS[sort_col].key
	var order := {}
	for i in units.size():
		order[units[i]] = i
	var text_sort := key == "name" or key == "class"
	units.sort_custom(func(a: Unit, b: Unit) -> bool:
		var va = _value(a, key)
		var vb = _value(b, key)
		if va != vb:
			return va < vb if text_sort else va > vb
		return order[a] < order[b])  # stable: ties keep their previous order


func _value(u: Unit, key: String) -> Variant:
	match key:
		"name": return u.unit_name
		"class": return u.class_display_name()
		"lv": return u.level
		"hp": return u.hp
		"str": return u.strength
		"dex": return u.dexterity
		"agi": return u.agility
		"def": return u.defense
		"mov": return u.mov
	return 0


func _render() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for c in COLUMNS.size():
		var header := _label(tr(COLUMNS[c].title), Vector2(COLUMNS[c].x, 22), SORTED_HEADER if c == sort_col else UiTheme.CAPTION)
		header.theme_type_variation = &"CaptionLabel"
		header.add_theme_font_size_override("font_size", 17)
		if c == sort_col:
			header.add_theme_stylebox_override("normal", UiTheme.tab_underline())
	# Keep the selected row on screen.
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + VISIBLE_ROWS:
		_scroll = index - VISIBLE_ROWS + 1
	for row in range(_scroll, mini(_scroll + VISIBLE_ROWS, units.size())):
		var u := units[row]
		var y := TOP + (row - _scroll) * ROW_H
		var color: Color = ENEMY_TEXT if u.team == Unit.Team.ENEMY \
			else (Factions.COLORS[u.team].lightened(0.4) if u.team != Unit.Team.PLAYER \
			else (ACTED_TEXT if u.has_acted else PLAYER_TEXT))
		var values := [u.unit_name, u.class_display_name(), u.level, "%d/%d" % [u.hp, u.max_hp],
			u.strength, u.dexterity, u.agility, u.defense, u.mov]
		var text_color := ACTED_TEXT if u.team == Unit.Team.PLAYER and u.has_acted else UiTheme.TEXT
		for c in COLUMNS.size():
			var label := _label(str(values[c]), Vector2(COLUMNS[c].x, y + 2), color if c == 0 else text_color)
			if c < 2:  # Name and Class: shorten to fit before the next column
				_fit(label, COLUMNS[c + 1].x - COLUMNS[c].x - 12)
	_cursor.visible = not units.is_empty()
	_cursor.position.y = TOP + (index - _scroll) * ROW_H
	_footer.text = tr("%d/%d   Z: go to  D: info  L/R: sort  X: close") % [index + 1, units.size()] \
		if not units.is_empty() else tr("No units")


## Shortens a label's text (ending in ".") until it fits in `width` units.
func _fit(label: Label, width: float) -> void:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return
	var text := label.text
	while text.length() > 1 and font.get_string_size(text + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		text = text.left(text.length() - 1)
	label.text = text + "."


func _label(text: String, pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_color_override("font_color", color)
	_rows.add_child(label)
	return label
