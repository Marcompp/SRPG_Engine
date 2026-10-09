class_name DialogueBox
extends Control
## GBA-style dialogue: two portrait slots above a text box at the bottom of the
## screen, a name plate, and text typed out letter by letter. Driven by
## BattleEvents: say() shows a line and returns once the player advances.
## Z (advance): finishes the line, then moves on. Holding X types faster.

signal advanced

const CHARS_PER_SECOND := 45.0
## Multiplier while cancel (X) is held.
const FAST := 4.0
const BOX_HEIGHT := 46
const PORTRAIT := 44
const NARRATOR := ""

## Tests set this: lines show in full and continue at once.
static var auto_advance := false
## Portraits: [{"name", "color", "letter"} or {}] for the left (0) and right (1) slots.
var slots: Array = [{}, {}]

var _box: PanelContainer
var _name_plate: PanelContainer
var _name_label: Label
var _text: Label
var _portraits: Array[ColorRect] = []
var _letters: Array[Label] = []
var _typing := false
var _shown := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in 2:
		var frame := ColorRect.new()
		frame.size = Vector2(PORTRAIT, PORTRAIT)
		frame.position = Vector2(6 if side == 0 else 240 - 6 - PORTRAIT, 160 - BOX_HEIGHT - PORTRAIT - 2)
		add_child(frame)
		var letter := Label.new()
		letter.add_theme_font_size_override("font_size", 26)
		letter.size = frame.size
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(letter)
		_portraits.append(frame)
		_letters.append(letter)
	_box = PanelContainer.new()
	_box.position = Vector2(2, 160 - BOX_HEIGHT - 2)
	_box.size = Vector2(236, BOX_HEIGHT)
	add_child(_box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(228, BOX_HEIGHT - 8)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_box.add_child(_text)
	_name_plate = PanelContainer.new()
	_name_label = Label.new()
	_name_plate.add_child(_name_label)
	add_child(_name_plate)


## Shows `text` said by `speaker` (a slot entry, or {} for narration) on `side`, and
## returns once the player advances past it.
func say(speaker: Dictionary, side: int, text: String) -> void:
	visible = true
	if not speaker.is_empty():
		slots[side] = speaker
	_refresh_portraits(side if not speaker.is_empty() else -1)
	_name_plate.visible = not speaker.is_empty()
	if not speaker.is_empty():
		_name_label.text = speaker.name
		_name_plate.reset_size()
		var x := 6.0 if side == 0 else 240.0 - 6.0 - _name_plate.size.x
		_name_plate.position = Vector2(x, 160 - BOX_HEIGHT - 2 - _name_plate.size.y + 3)
	_text.text = text
	if auto_advance:
		_text.visible_characters = -1
		return
	_shown = 0.0
	_text.visible_characters = 0
	_typing = true
	await advanced


## Z: finish the line if it's still typing, otherwise move on.
func advance() -> void:
	if not visible:
		return
	if _typing:
		_typing = false
		_text.visible_characters = -1
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


func _process(delta: float) -> void:
	if not _typing:
		return
	var speed := CHARS_PER_SECOND * (FAST if Input.is_action_pressed("cancel") else 1.0)
	_shown += delta * speed
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _text.get_total_character_count():
		_typing = false
		_text.visible_characters = -1


func _refresh_portraits(speaking: int) -> void:
	for side in 2:
		var s: Dictionary = slots[side]
		_portraits[side].visible = not s.is_empty()
		if s.is_empty():
			continue
		_portraits[side].color = s.color
		_letters[side].text = s.letter
		# The listener is dimmed, as in GBA FE.
		_portraits[side].modulate = Color.WHITE if side == speaking or speaking < 0 else Color(0.55, 0.55, 0.6)
