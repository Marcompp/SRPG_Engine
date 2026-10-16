class_name DiamondCursor
extends Control
## The Gilded Night menu cursor: a small gold diamond with a soft glow that pulses.
## Its position is its center.

const RADIUS := 6.0
const PULSE_SECONDS := 1.2

## Off for a still cursor (and in tests that compare frames).
@export var pulse := true
var _time := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if pulse and is_visible_in_tree():
		_time = fmod(_time + delta, PULSE_SECONDS)
		queue_redraw()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_time / PULSE_SECONDS * TAU) if pulse else 0.75
	for i in 3:
		_diamond(RADIUS + 3 + i * 3, Color(UiTheme.GOLD_PALE, (0.16 - i * 0.04) * (0.5 + glow)))
	_diamond(RADIUS, UiTheme.GOLD_PALE)
	_diamond(RADIUS - 3, Color.WHITE.lerp(UiTheme.GOLD_PALE, 0.4))


func _diamond(r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]), color)
