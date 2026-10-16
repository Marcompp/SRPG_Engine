class_name OptionsScreen
extends Control
## Options menu (see Settings), in the Gilded Night look (docs/ui_theme.md): Up/Down
## picks a row, Left/Right changes it, Z or X closes and saves. Used by both the battle
## and the level select. Laid out in HD units (960x640): put it on a UiLayer.

const DIM := UiTheme.DIM
const SELECTED := UiTheme.GOLD_BRIGHT
## Rows shown at once; the list scrolls to keep the selection in view.
const ROWS := 8
const PANEL_RECT := Rect2(150, 48, 660, 544)
## The first row's top, and the row height, inside the panel.
const TOP := 100.0
const ROW_H := 50.0

## The dark veil behind the screen: see-through over the battle map, opaque over a busy
## screen (the level select sets 1). Set before the screen enters the tree.
var veil_alpha := 0.9
var index := 0
var _names: Array[Label] = []
var _values: Array[Label] = []
var _cursor: Panel
var _hint: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = UiLayer.SIZE
	var bg := ColorRect.new()
	bg.color = Color(6 / 255.0, 7 / 255.0, 20 / 255.0, veil_alpha)
	bg.size = UiLayer.SIZE
	add_child(bg)
	var panel := Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	add_child(panel)
	var title := Label.new()
	title.text = tr("Options")
	title.theme_type_variation = &"NameLabel"
	title.size = Vector2(PANEL_RECT.size.x, 0)
	title.position = Vector2(0, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.3)
	rule.position = Vector2(40, TOP - 18)
	rule.size = Vector2(PANEL_RECT.size.x - 80, 1)
	panel.add_child(rule)
	_cursor = Panel.new()
	_cursor.theme_type_variation = &"SelectedRow"
	_cursor.size = Vector2(PANEL_RECT.size.x - 24, ROW_H)
	_cursor.position.x = 12
	panel.add_child(_cursor)
	var diamond := DiamondCursor.new()
	diamond.position = Vector2(26, ROW_H / 2.0)
	_cursor.add_child(diamond)
	for i in ROWS:
		var y := TOP + i * ROW_H
		var name_label := Label.new()
		name_label.position = Vector2(52, y)
		name_label.size = Vector2(320, ROW_H)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(name_label)
		_names.append(name_label)
		var value := Label.new()
		value.position = Vector2(PANEL_RECT.size.x - 40 - 240, y)
		value.size = Vector2(240, ROW_H)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(value)
		_values.append(value)
	_hint = Label.new()
	_hint.text = tr("Up/Down: choose  Left/Right: change  Z/X: close")
	_hint.theme_type_variation = &"SubLabel"
	_hint.size = Vector2(UiLayer.SIZE.x, 0)
	_hint.position = Vector2(0, PANEL_RECT.end.y + 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)


func open() -> void:
	index = 0
	visible = true
	_render()


func close() -> void:
	Settings.save()
	visible = false
	Sound.play("cancel")


func move(step: int) -> void:
	index = wrapi(index + step, 0, Settings.OPTIONS.size())
	Sound.play("cursor")
	_render()


func change(step: int) -> void:
	var option: Dictionary = Settings.OPTIONS[index]
	var i := wrapi(Settings.choice_index(option) + step, 0, option.choices.size())
	Settings.set_value(option.key, option.choices[i][0])
	Sound.apply_volumes()
	Sound.play("cursor")  # also a sample of the new effects volume
	_render()


## The current value of each visible row, as shown (for tests and debugging).
func rows_text() -> Array[String]:
	var shown: Array[String] = []
	for i in ROWS:
		if _names[i].visible:
			shown.append("%s: %s" % [_names[i].text, _values[i].text])
	return shown


func _render() -> void:
	var first := clampi(index - ROWS / 2, 0, maxi(0, Settings.OPTIONS.size() - ROWS))
	for r in ROWS:
		var i := first + r
		var shown := i < Settings.OPTIONS.size()
		_names[r].visible = shown
		_values[r].visible = shown
		if not shown:
			continue
		var option: Dictionary = Settings.OPTIONS[i]
		var text: String = option.choices[Settings.choice_index(option)][1]
		var selected := i == index
		_names[r].text = tr(option.label)
		_names[r].add_theme_color_override("font_color", SELECTED if selected else UiTheme.TEXT)
		# The selected row shows arrows: Left/Right changes it.
		_values[r].text = ("‹  %s  ›" if selected else "%s") % tr(text)
		_values[r].add_theme_color_override("font_color", SELECTED if selected else DIM)
		if selected:
			_cursor.position.y = TOP + r * ROW_H
