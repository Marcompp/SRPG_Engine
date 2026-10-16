extends Control
## Level select (for testing): Up/Down to pick a level, Z to play it. When a
## battle was suspended, a "Resume" entry at the top picks it back up; then each
## campaign (Chapters.CAMPAIGNS) gets a Continue entry (if it has a save) and a New
## one; "Options" at the bottom opens the options menu. Drawn on an HD layer in the
## Gilded Night look (docs/ui_theme.md), in 960x640 units.

const BATTLE_SCENE := "res://scenes/main.tscn"
const PREP_SCENE := "res://scenes/prep.tscn"
const DIM := UiTheme.DIM

var index := 0
## [{"label", "description", and "level"+"resume", "campaign"+"campaign_id" or
## "options"}], in display order.
var choices: Array = []
## Rows of the choice list shown at once.
const LIST_ROWS := 7
const PANEL_RECT := Rect2(150, 112, 660, 360)
const ROW_H := 44.0

## One label per visible row; the band and diamond sit on the selected one.
var _rows: Array[Label] = []
var _cursor: Panel
var _description: Label
var _hint: Label
var _options: OptionsScreen
## New Campaign was pressed once while a campaign exists (needs a second press).
var _confirm_new := false


func _ready() -> void:
	Text.manual(self)  # the code translates what it shows
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hd := UiLayer.new(1)
	add_child(hd)
	var screen := hd.root

	var bg := ColorRect.new()
	bg.color = Color(8 / 255.0, 9 / 255.0, 26 / 255.0)
	bg.size = UiLayer.SIZE
	screen.add_child(bg)
	var title := Label.new()
	title.text = tr("Level Select")
	title.add_theme_font_override("font", UiTheme.display(700, 6))
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	title.size = Vector2(UiLayer.SIZE.x, 0)
	title.position = Vector2(0, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(title)

	var panel := Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	screen.add_child(panel)
	_cursor = Panel.new()
	_cursor.theme_type_variation = &"SelectedRow"
	_cursor.size = Vector2(PANEL_RECT.size.x - 24, ROW_H)
	_cursor.position.x = 12
	panel.add_child(_cursor)
	var diamond := DiamondCursor.new()
	diamond.position = Vector2(26, ROW_H / 2.0)
	_cursor.add_child(diamond)
	for i in LIST_ROWS:
		var row := Label.new()
		row.position = Vector2(52, 26 + i * ROW_H)
		row.size = Vector2(PANEL_RECT.size.x - 80, ROW_H)
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(row)
		_rows.append(row)
	_description = Label.new()
	_description.theme_type_variation = &"SubLabel"
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.position = Vector2(PANEL_RECT.position.x + 20, PANEL_RECT.end.y + 20)
	_description.size = Vector2(PANEL_RECT.size.x - 40, 0)
	screen.add_child(_description)
	_hint = Label.new()
	_hint.theme_type_variation = &"SubLabel"
	_hint.size = Vector2(UiLayer.SIZE.x, 0)
	_hint.position = Vector2(0, UiLayer.SIZE.y - 46)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_hint)

	_options = OptionsScreen.new()
	_options.veil_alpha = 1.0
	screen.add_child(_options)

	_build_choices()
	_refresh()
	Sound.music("title")


func _build_choices() -> void:
	choices.clear()
	Campaign.migrate_old_save()
	var suspended := SaveGame.read_suspend()
	if not suspended.is_empty() and (Levels.DATA.has(suspended.level) or Chapters.DATA.has(suspended.level)):
		var level := Levels.get_level(suspended.level)
		choices.append({"label": tr("Resume: %s, Turn %d") % [tr(level.name), suspended.turn],
			"description": tr("Continue the suspended battle."), "level": suspended.level, "resume": true})
	# Listing reads every campaign's save; the selected campaign is put back after.
	var was_selected := Campaign.id
	for campaign_id: String in Chapters.CAMPAIGNS:
		Campaign.select(campaign_id)
		var campaign_name := tr(Campaign.info().name)
		if Campaign.load_save():
			if Campaign.is_complete():
				choices.append({"label": tr("%s: complete!") % campaign_name, "campaign": "none",
					"campaign_id": campaign_id, "description": tr("Every chapter cleared. Start it again below.")})
			else:
				var chapter_name := tr(Campaign.chapter_data().name)
				choices.append({"label": tr("Continue %s: %s") % [campaign_name, chapter_name.get_slice(":", 0)],
					"description": tr("Back to the preparations for %s.") % chapter_name, "campaign": "continue",
					"campaign_id": campaign_id})
		var about := tr(Campaign.info().get("description", ""))
		choices.append({"label": tr("New: %s") % campaign_name, "campaign": "new", "campaign_id": campaign_id,
			"description": (about + " " + tr("Overwrites your progress in it.")).strip_edges() if Campaign.has_save()
				else about})
	Campaign.select(was_selected)
	for id in Levels.ORDER:
		var level := Levels.get_level(id)
		choices.append({"label": tr(level.name), "description": tr(level.description), "level": id, "resume": false})
	choices.append({"label": tr("Options"), "description": tr("Game speed, fast-forward, danger zone, turn and level-up settings."),
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
		Sound.play("cursor")
		_refresh()
	elif event.is_action_pressed("ui_down", true):
		index = wrapi(index + 1, 0, choices.size())
		Sound.play("cursor")
		_refresh()
	elif event.is_action_pressed("confirm"):
		Sound.play("confirm")
		var choice: Dictionary = choices[index]
		if choice.get("options", false):
			_options.open()
			return
		if choice.has("campaign_id"):
			Campaign.select(choice.campaign_id)
		match choice.get("campaign", ""):
			"none":
				return
			"continue":
				Campaign.load_save()
				get_tree().change_scene_to_file(PREP_SCENE)
				return
			"new":
				# Overwriting a campaign takes a second press.
				if Campaign.has_save() and not _confirm_new:
					_confirm_new = true
					_description.text = tr("Press Z again to start over (your progress in it is lost).")
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
	# A window of LIST_ROWS entries that scrolls to keep the selection in view.
	var first := clampi(index - LIST_ROWS / 2, 0, maxi(0, choices.size() - LIST_ROWS))
	for r in LIST_ROWS:
		var i := first + r
		_rows[r].visible = i < choices.size()
		if i >= choices.size():
			continue
		_rows[r].text = choices[i].label
		_rows[r].add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT if i == index else UiTheme.TEXT)
		if i == index:
			_cursor.position.y = _rows[r].position.y
	_description.text = choices[index].description
	_hint.text = tr("Up/Down: choose   Z: play   (%d/%d)") % [index + 1, choices.size()]
