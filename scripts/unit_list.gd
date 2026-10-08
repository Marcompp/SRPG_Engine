class_name UnitListScreen
extends Control
## Every unit on the map in one sortable table (player units in blue, enemies in
## red, player units that already acted dimmed).
## Up/Down: row (scrolls). Left/Right: sort column. Z: put the cursor on the unit.
## D: its status screen. X: close. (Input is routed here by Battle.)

const DIM := Color(0.7, 0.75, 0.95)
const PLAYER_TEXT := Color(0.65, 0.8, 1.0)
const ENEMY_TEXT := Color(1.0, 0.6, 0.55)
const ACTED_TEXT := Color(0.55, 0.55, 0.6)
const SORTED_HEADER := Color(1.0, 0.85, 0.25)
## key: what the column sorts by (see _value()). Name and Class sort A-Z, numbers high to low.
const COLUMNS := [
	{"title": "Name", "x": 4.0, "key": "name"},
	{"title": "Class", "x": 50.0, "key": "class"},
	{"title": "Lv", "x": 106.0, "key": "lv"},
	{"title": "HP", "x": 122.0, "key": "hp"},
	{"title": "Str", "x": 150.0, "key": "str"},
	{"title": "Dex", "x": 168.0, "key": "dex"},
	{"title": "Agi", "x": 186.0, "key": "agi"},
	{"title": "Def", "x": 204.0, "key": "def"},
	{"title": "Mov", "x": 222.0, "key": "mov"},
]
const TOP := 15.0
const ROW_H := 10.0
const VISIBLE_ROWS := 13

var units: Array[Unit] = []
var index := 0
var sort_col := 0
var _scroll := 0
var _rows: Control
var _cursor: ColorRect
var _footer: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.38)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor = ColorRect.new()
	_cursor.color = Color(1, 1, 1, 0.15)
	_cursor.size = Vector2(236, ROW_H)
	_cursor.position.x = 2
	add_child(_cursor)
	_rows = Control.new()
	add_child(_rows)
	_footer = Label.new()
	_footer.position = Vector2(4, 148)
	_footer.add_theme_color_override("font_color", DIM)
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
		"class": return u.unit_class
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
		var header := _label(COLUMNS[c].title, Vector2(COLUMNS[c].x, 3),
			SORTED_HEADER if c == sort_col else DIM)
		if c == sort_col:
			header.text += "*"
	# Keep the selected row on screen.
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + VISIBLE_ROWS:
		_scroll = index - VISIBLE_ROWS + 1
	for row in range(_scroll, mini(_scroll + VISIBLE_ROWS, units.size())):
		var u := units[row]
		var y := TOP + (row - _scroll) * ROW_H
		var color := ENEMY_TEXT if u.team == Unit.Team.ENEMY \
			else (ACTED_TEXT if u.has_acted else PLAYER_TEXT)
		var values := [u.unit_name, u.unit_class, u.level, "%d/%d" % [u.hp, u.max_hp],
			u.strength, u.dexterity, u.agility, u.defense, u.mov]
		for c in COLUMNS.size():
			var label := _label(str(values[c]), Vector2(COLUMNS[c].x, y), color if c == 0 else Color.WHITE)
			if c < 2:  # Name and Class: shorten to fit before the next column
				_fit(label, COLUMNS[c + 1].x - COLUMNS[c].x - 3)
	_cursor.visible = not units.is_empty()
	_cursor.position.y = TOP + (index - _scroll) * ROW_H
	_footer.text = "%d/%d   Z: go to  D: info  L/R: sort  X: close" % [index + 1, units.size()] \
		if not units.is_empty() else "No units"


## Shortens a label's text (ending in ".") until it fits in `width` pixels.
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
