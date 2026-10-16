class_name GildedBar
extends Control
## A Gilded Night meter (HP, MP, stats): a dark track with a thin gold outline and a
## gradient fill that can glow. Sized by its layout; 8 units tall by default.

## How full the bar is, 0 to 1.
@export_range(0.0, 1.0) var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var fill_from := UiTheme.HP_FROM:
	set(v):
		fill_from = v
		queue_redraw()
@export var fill_to := UiTheme.HP_TO:
	set(v):
		fill_to = v
		queue_redraw()
@export var glow := true


func _init() -> void:
	custom_minimum_size = Vector2(40, 8)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.55))
	if ratio > 0.0:
		var fill := Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y))
		if glow:
			for i in 3:
				draw_rect(fill.grow(1 + i * 2), Color(fill_to, 0.07))
		var e := fill.end
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(e.x, 0), e, Vector2(0, e.y)]),
			PackedColorArray([fill_from, fill_from.lerp(fill_to, ratio), fill_from.lerp(fill_to, ratio), fill_from]))
	draw_rect(r.grow(0.5), Color(UiTheme.GOLD, 0.65), false, 1.0)
