extends Control
## Level select (for testing): Up/Down to pick a level, Z to play it. When a
## battle was suspended, a "Resume" entry at the top picks it back up; "Options"
## at the bottom opens the options menu.

const BATTLE_SCENE := "res://scenes/main.tscn"
const PREP_SCENE := "res://scenes/prep.tscn"
const DIM := Color(0.7, 0.75, 0.95)

var index := 0
## [{"label", "description", "level", "resume"}], in display order.
var choices: Array = []
var _list: Label
var _description: Label
var _options: OptionsScreen
## New Campaign was pressed once while a campaign exists (needs a second press).
var _confirm_new := false


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

	_options = OptionsScreen.new()
	add_child(_options)

	_build_choices()
	_refresh()


func _build_choices() -> void:
	choices.clear()
	var suspended := SaveGame.read_suspend()
	if not suspended.is_empty() and (Levels.DATA.has(suspended.level) or Chapters.DATA.has(suspended.level)):
		var level := Levels.get_level(suspended.level)
		choices.append({"label": "Resume: %s, Turn %d" % [level.name, suspended.turn],
			"description": "Continue the suspended battle.", "level": suspended.level, "resume": true})
	if Campaign.load_save():
		if Campaign.is_complete():
			choices.append({"label": "Campaign complete!", "description": "Every chapter cleared. Start a new campaign below.",
				"campaign": "none"})
		else:
			choices.append({"label": "Continue Campaign: %s" % Campaign.chapter_data().name.get_slice(":", 0),
				"description": "Back to the preparations for %s." % Campaign.chapter_data().name, "campaign": "continue"})
	choices.append({"label": "New Campaign", "campaign": "new",
		"description": "Five chapters with one army. Overwrites the current campaign." if Campaign.has_save()
			else "Five chapters with one army, permadeath included."})
	for id in Levels.ORDER:
		var level := Levels.get_level(id)
		choices.append({"label": level.name, "description": level.description, "level": id, "resume": false})
	choices.append({"label": "Options", "description": "Game speed, fast-forward, danger zone, turn and level-up settings.",
		"options": true})
	# Start on Resume when there is one, otherwise on the last test map played.
	index = 0
	if not choices[0].get("resume", false):
		for i in choices.size():
			if choices[i].get("level", "") == Levels.selected:
				index = i


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		if event.is_action_pressed("ui_up", true):
			_options.move(-1)
		elif event.is_action_pressed("ui_down", true):
			_options.move(1)
		elif event.is_action_pressed("ui_left", true):
			_options.change(-1)
		elif event.is_action_pressed("ui_right", true):
			_options.change(1)
		elif event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
			_options.close()
		return
	if event.is_action_pressed("ui_up", true):
		index = wrapi(index - 1, 0, choices.size())
		_refresh()
	elif event.is_action_pressed("ui_down", true):
		index = wrapi(index + 1, 0, choices.size())
		_refresh()
	elif event.is_action_pressed("confirm"):
		var choice: Dictionary = choices[index]
		if choice.get("options", false):
			_options.open()
			return
		match choice.get("campaign", ""):
			"none":
				return
			"continue":
				get_tree().change_scene_to_file(PREP_SCENE)
				return
			"new":
				# Overwriting a campaign takes a second press.
				if Campaign.has_save() and not _confirm_new:
					_confirm_new = true
					_description.text = "Press Z again to start over (the current campaign is lost)."
					return
				Campaign.start_new()
				get_tree().change_scene_to_file(PREP_SCENE)
				return
		Campaign.active = false
		Levels.selected = choice.level
		Levels.resume = choice.resume
		if choice.resume and Chapters.DATA.has(choice.level):
			Campaign.active = true  # resume_suspended() reloads the campaign too
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _refresh() -> void:
	_confirm_new = false  # moving away cancels a pending "press Z again"
	var lines: Array[String] = []
	for i in choices.size():
		lines.append(("> " if i == index else "   ") + choices[i].label)
	_list.text = "\n".join(lines)
	_description.text = choices[index].description
