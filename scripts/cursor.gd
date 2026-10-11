class_name Cursor
extends Node2D
## Tile selection cursor. It glides to its cell instead of jumping, and its corners
## breathe in and out a pixel, like GBA Fire Emblem's.

## How quickly it closes the distance to its cell (fraction per second, roughly).
const GLIDE := 30.0
## Seconds per breathing step.
const BREATH_PERIOD := 0.25

var cell := Vector2i.ZERO:
	set(value):
		cell = value
		if not is_inside_tree():
			position = Vector2(value * BattleMap.TILE)

var _inset := 0


## Jumps straight to its cell (map start, rewind).
func snap() -> void:
	position = Vector2(cell * BattleMap.TILE)


func _process(delta: float) -> void:
	var target := Vector2(cell * BattleMap.TILE)
	if position != target:
		position = position.lerp(target, minf(1.0, GLIDE * delta))
		if position.distance_to(target) < 0.5:
			position = target
		queue_redraw()
	var inset := int(Time.get_ticks_msec() / (BREATH_PERIOD * 1000.0)) % 2
	if inset != _inset:
		_inset = inset
		queue_redraw()


func _draw() -> void:
	# Pixel-snapped so the gliding cursor stays crisp.
	draw_set_transform(position.round() - position)
	var s := float(BattleMap.TILE)
	var l := 4.0
	var i := float(_inset)
	# A dark outline under the white, so it reads on any terrain.
	for pass_style in [[Color(0, 0, 0, 0.6), 3.0], [Color.WHITE, 2.0]]:
		for corner in [Vector2(i, i), Vector2(s - i, i), Vector2(i, s - i), Vector2(s - i, s - i)]:
			var hx := l if corner.x < s / 2 else -l
			var hy := l if corner.y < s / 2 else -l
			draw_line(corner, corner + Vector2(hx, 0), pass_style[0], pass_style[1])
			draw_line(corner, corner + Vector2(0, hy), pass_style[0], pass_style[1])
