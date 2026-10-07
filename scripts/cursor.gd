class_name Cursor
extends Node2D
## Blinking tile selection cursor.

var cell := Vector2i.ZERO:
	set(value):
		cell = value
		position = Vector2(value * BattleMap.TILE)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var color := Color(1, 1, 1, 0.6 + 0.4 * sin(_time * 8.0))
	var s := float(BattleMap.TILE)
	var l := 4.0
	for corner in [Vector2(0, 0), Vector2(s, 0), Vector2(0, s), Vector2(s, s)]:
		var hx := l if corner.x == 0 else -l
		var hy := l if corner.y == 0 else -l
		draw_line(corner, corner + Vector2(hx, 0), color, 2.0)
		draw_line(corner, corner + Vector2(0, hy), color, 2.0)
