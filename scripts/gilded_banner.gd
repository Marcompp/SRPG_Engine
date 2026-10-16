class_name GildedBanner
extends Control
## The phase banner and end screen (docs/ui_theme.md): a band across the screen, tinted
## by the side, fading out at both ends, between two gold rules with a gem at their
## middle; the title in engraved capitals and an optional hint under it. HD units.

const HEIGHT := 170.0
## Where the band reaches full strength, as a fraction of the width from each end.
const FADE := 0.28

var tint := Color.BLACK
var _title: Label
var _hint: Label


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(UiLayer.SIZE.x, HEIGHT)
	position = Vector2(0, (UiLayer.SIZE.y - HEIGHT) / 2.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.size = size
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiTheme.display(700, 6))
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", UiTheme.GOLD_BRIGHT)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_title)
	_hint = Label.new()
	_hint.theme_type_variation = "SubLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)


## `title` and `hint` come translated; `side_color` tints the band.
func show_text(title: String, hint: String, side_color: Color) -> void:
	_title.text = title
	_hint.text = hint
	_hint.visible = hint != ""
	tint = side_color
	queue_redraw()


func _draw() -> void:
	var band := UiTheme.NAVY_TOP.lerp(tint.darkened(0.35), 0.4)
	band.a = 0.9
	_strip(0.0, HEIGHT, band)
	for y in [0.0, HEIGHT - 1.0]:
		_strip(y, 1.0, UiTheme.GOLD)
		var c := Vector2(size.x / 2.0, y + 0.5)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]),
			UiTheme.GOLD_PALE)


## A horizontal strip at `y`, `h` tall, in `color`, fading to clear at both ends.
func _strip(y: float, h: float, color: Color) -> void:
	var clear := Color(color, 0.0)
	var xs := [0.0, size.x * FADE, size.x * (1.0 - FADE), size.x]
	var colors := [clear, color, color, clear]
	for i in 3:
		draw_polygon(PackedVector2Array([Vector2(xs[i], y), Vector2(xs[i + 1], y), Vector2(xs[i + 1], y + h), Vector2(xs[i], y + h)]),
			PackedColorArray([colors[i], colors[i + 1], colors[i + 1], colors[i]]))
