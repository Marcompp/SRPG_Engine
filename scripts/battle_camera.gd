class_name BattleCamera
extends Camera2D
## The battle view: a screen-sized window onto maps that can be bigger than the
## screen. Like GBA Fire Emblem, it scrolls to keep its focus (the cursor, or a
## moving unit) at least MARGIN tiles from the screen edge, and never shows past
## the map's edges. Maps that fit on one screen don't scroll.

## Tiles kept between the focus and the screen edge.
const MARGIN := 2
## Scroll speed in pixels per second (scaled by game speed, like everything else).
const SPEED := 600.0

## Top-left cell of the view the camera is heading for. UI placement uses this.
var origin := Vector2i.ZERO
## Screen size in tiles (15 x 10 at 240 x 160).
var view := Vector2i(15, 10)
var _map_size := Vector2i(15, 10)


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	view = Vector2i((get_viewport_rect().size / BattleMap.TILE).floor())


## Call once the map is loaded, then snap() to where the view should start.
func setup(cols: int, rows: int) -> void:
	_map_size = Vector2i(cols, rows)
	origin = _clamped(origin)


## Scrolls (if needed) so `cell` is at least MARGIN tiles inside the view.
func follow(cell: Vector2i) -> void:
	var o := origin
	if cell.x < o.x + MARGIN:
		o.x = cell.x - MARGIN
	elif cell.x > o.x + view.x - 1 - MARGIN:
		o.x = cell.x - view.x + 1 + MARGIN
	if cell.y < o.y + MARGIN:
		o.y = cell.y - MARGIN
	elif cell.y > o.y + view.y - 1 - MARGIN:
		o.y = cell.y - view.y + 1 + MARGIN
	origin = _clamped(o)


## Jumps to show `cell` without scrolling (map start, resume).
func snap(cell: Vector2i) -> void:
	follow(cell)
	position = _target()


## Where `cell` is on screen, in tiles (for placing UI away from the cursor).
func screen_cell(cell: Vector2i) -> Vector2i:
	return cell - origin


func is_settled() -> bool:
	return position.is_equal_approx(_target())


## Waits until the scroll in progress is done.
func settle() -> void:
	while not is_settled():
		await get_tree().process_frame


func _process(delta: float) -> void:
	position = position.move_toward(_target(), SPEED * delta)


func _target() -> Vector2:
	return Vector2(origin * BattleMap.TILE)


func _clamped(o: Vector2i) -> Vector2i:
	return Vector2i(clampi(o.x, 0, maxi(0, _map_size.x - view.x)), clampi(o.y, 0, maxi(0, _map_size.y - view.y)))
