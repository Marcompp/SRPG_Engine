class_name DialogueBox
extends Control
## Dialogue (Gilded Night, docs/ui_theme.md): two portrait slots above a full-width text
## box at the bottom of the screen, the speaker's name on a plate over the box's top
## edge, and text typed out letter by letter, with a gold arrow once the line is done.
## Laid out in HD units (960x640, on BattleUI's UiLayer). Driven by BattleEvents: say()
## shows a line and returns once the player advances.
## Z (advance): finishes the line, then moves on. Holding X types faster.

signal advanced

const CHARS_PER_SECOND := 45.0
## Multiplier while cancel (X) is held.
const FAST := 4.0
## The "text" sound plays every this many letters while a line types out.
const BLIP_EVERY := 3
const MARGIN := 28.0
const BOX_HEIGHT := 150.0
## Portrait slots: 2x the portraits' 96x80, a placeholder until units have portraits.
const PORTRAIT := Vector2(192, 160)
## How far the portraits and the name plate reach down behind / over the box's edge.
const TUCK := 14.0
const NARRATOR := ""

## Tests set this: lines show in full and continue at once.
static var auto_advance := false
## Portraits: [{"name", "color", "letter"} or {}] for the left (0) and right (1) slots.
var slots: Array = [{}, {}]

var _box: PanelContainer
var _name_plate: PanelContainer
var _name_label: Label
var _text: Label
var _portraits: Array[Panel] = []
var _letters: Array[Label] = []
var _arrow: Polygon2D
var _typing := false
var _shown := 0.0
## Letters shown when the "text" sound last played.
var _blipped := 0
var _time := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = UiLayer.SIZE
	var box_top := UiLayer.SIZE.y - MARGIN - BOX_HEIGHT
	for side in 2:
		var frame := Panel.new()
		frame.size = PORTRAIT
		frame.position = Vector2(56 if side == 0 else UiLayer.SIZE.x - 56 - PORTRAIT.x, box_top - PORTRAIT.y + TUCK)
		add_child(frame)
		var letter := Label.new()
		letter.add_theme_font_override("font", UiTheme.display(700))
		letter.add_theme_font_size_override("font_size", 96)
		letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		letter.size = PORTRAIT
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(letter)
		_portraits.append(frame)
		_letters.append(letter)
	_box = PanelContainer.new()
	_box.position = Vector2(MARGIN, box_top)
	_box.size = Vector2(UiLayer.SIZE.x - 2 * MARGIN, BOX_HEIGHT)
	add_child(_box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", UiTheme.SIZE_DIALOGUE)
	_text.custom_minimum_size = Vector2(_box.size.x - 88, BOX_HEIGHT - 52)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_child(_text)
	_box.add_child(pad)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(-8, -5), Vector2(8, -5), Vector2(0, 5)])
	_arrow.color = UiTheme.GOLD_PALE
	_arrow.visible = false
	_box.add_child(_arrow)
	_name_plate = PanelContainer.new()
	_name_plate.theme_type_variation = &"PlatePanel"
	_name_label = Label.new()
	_name_label.theme_type_variation = &"TitleLabel"
	_name_label.add_theme_font_size_override("font_size", 27)
	_name_plate.add_child(_name_label)
	add_child(_name_plate)


## Shows `text` said by `speaker` (a slot entry, or {} for narration) on `side`, and
## returns once the player advances past it.
func say(speaker: Dictionary, side: int, text: String) -> void:
	if not visible:
		visible = true
		UiTheme.appear(self, false)
	if not speaker.is_empty():
		slots[side] = speaker
	_refresh_portraits(side if not speaker.is_empty() else -1)
	_name_plate.visible = not speaker.is_empty()
	if not speaker.is_empty():
		_name_label.text = speaker.name
		_name_plate.reset_size()
		var x := MARGIN + 30 if side == 0 else UiLayer.SIZE.x - MARGIN - 30 - _name_plate.size.x
		_name_plate.position = Vector2(x, _box.position.y - _name_plate.size.y + TUCK)
	# Narration is set in italics.
	_text.add_theme_font_override("font", UiTheme.body(speaker.is_empty()))
	_text.text = text
	_arrow.visible = false
	if auto_advance:
		_text.visible_characters = -1
		return
	_shown = 0.0
	_blipped = -BLIP_EVERY
	_text.visible_characters = 0
	_typing = true
	await advanced


## Z: finish the line if it's still typing, otherwise move on.
func advance() -> void:
	if not visible:
		return
	if _typing:
		_finish_line()
	else:
		advanced.emit()


## Ends a scene: hides the box and clears the portraits.
func close() -> void:
	visible = false
	slots = [{}, {}]
	_typing = false


## Hides the box (e.g. while units move) but keeps who's on screen.
func hide_box() -> void:
	visible = false


func _finish_line() -> void:
	_typing = false
	_text.visible_characters = -1
	_arrow.visible = true


func _process(delta: float) -> void:
	if _arrow.visible:
		# The arrow bobs while it waits.
		_time = fmod(_time + delta, 1.0)
		_arrow.position = Vector2(_box.size.x - 34, _box.size.y - 26 + roundf(sin(_time * TAU) * 3))
	if not _typing:
		return
	var speed := CHARS_PER_SECOND * (FAST if Input.is_action_pressed("cancel") else 1.0)
	_shown += delta * speed
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _blipped + BLIP_EVERY:
		_blipped = _text.visible_characters
		Sound.play("text")
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_line()


func _refresh_portraits(speaking: int) -> void:
	for side in 2:
		var s: Dictionary = slots[side]
		_portraits[side].visible = not s.is_empty()
		if s.is_empty():
			continue
		var style := StyleBoxFlat.new()
		style.bg_color = (s.color as Color).darkened(0.3)
		style.border_color = UiTheme.GOLD
		style.set_border_width_all(1)
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 10
		_portraits[side].add_theme_stylebox_override("panel", style)
		_letters[side].text = s.letter
		# The listener is dimmed, as in GBA FE.
		_portraits[side].modulate = Color.WHITE if side == speaking or speaking < 0 else Color(0.55, 0.55, 0.6)
