extends Control
## Level select (for testing): Up/Down to pick a level, Z to play it.

const BATTLE_SCENE := "res://scenes/main.tscn"
const DIM := Color(0.7, 0.75, 0.95)

var index := 0
var _list: Label
var _description: Label


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 8
	self.theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.25)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

	var title := Label.new()
	title.text = "Level Select"
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)
	_list = Label.new()
	box.add_child(_list)
	_description = Label.new()
	_description.add_theme_color_override("font_color", DIM)
	box.add_child(_description)
	var hint := Label.new()
	hint.text = "Up/Down: choose   Z: play"
	hint.add_theme_color_override("font_color", DIM)
	box.add_child(hint)

	index = maxi(0, Levels.ORDER.find(Levels.selected))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up", true):
		index = wrapi(index - 1, 0, Levels.ORDER.size())
		_refresh()
	elif event.is_action_pressed("ui_down", true):
		index = wrapi(index + 1, 0, Levels.ORDER.size())
		_refresh()
	elif event.is_action_pressed("confirm"):
		Levels.selected = Levels.ORDER[index]
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _refresh() -> void:
	var lines: Array[String] = []
	for i in Levels.ORDER.size():
		var level := Levels.get_level(Levels.ORDER[i])
		lines.append(("> " if i == index else "   ") + level.name)
	_list.text = "\n".join(lines)
	_description.text = Levels.get_level(Levels.ORDER[index]).description
