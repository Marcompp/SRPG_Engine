class_name OptionsScreen
extends Control
## Options menu (see Settings): Up/Down picks a row, Left/Right changes it,
## Z or X closes and saves. Used by both the battle and the level select.

const DIM := Color(0.7, 0.75, 0.95)
const SELECTED := Color(1.0, 0.85, 0.25)

var index := 0
var _rows: Label
var _hint: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.38)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 14)
	title.position = Vector2(12, 8)
	add_child(title)
	_rows = Label.new()
	_rows.position = Vector2(12, 34)
	add_child(_rows)
	_hint = Label.new()
	_hint.text = "Up/Down: choose  Left/Right: change  Z/X: close"
	_hint.position = Vector2(12, 146)
	_hint.add_theme_color_override("font_color", DIM)
	add_child(_hint)


func open() -> void:
	index = 0
	visible = true
	_render()


func close() -> void:
	Settings.save()
	visible = false


func move(step: int) -> void:
	index = wrapi(index + step, 0, Settings.OPTIONS.size())
	_render()


func change(step: int) -> void:
	var option: Dictionary = Settings.OPTIONS[index]
	var i := wrapi(Settings.choice_index(option) + step, 0, option.choices.size())
	Settings.set_value(option.key, option.choices[i][0])
	_render()


func _render() -> void:
	var lines: Array[String] = []
	for i in Settings.OPTIONS.size():
		var option: Dictionary = Settings.OPTIONS[i]
		var text: String = option.choices[Settings.choice_index(option)][1]
		lines.append("%s%s:  < %s >" % ["> " if i == index else "   ", option.label, text])
	_rows.text = "\n".join(lines)
