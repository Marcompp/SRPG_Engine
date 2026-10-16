class_name GildedStyleBox
extends StyleBox
## The Gilded Night panel (docs/ui_theme.md): a navy gradient, an outer gold line, a fainter
## inner line and a filigree flourish on each corner, overhanging the panel. Drawn in code,
## so it stays sharp at any scale. Sizes are in HD units (one screen pixel at 4x).

@export var fill_top := UiTheme.NAVY_TOP
@export var fill_bottom := UiTheme.NAVY_BOTTOM
@export var line := UiTheme.GOLD
## The inner line, `inner_inset` in from the outer one at 30% gold.
@export var inner_line := true
@export var inner_inset := 6.0
@export var corners := true
@export var shadow := true

## How far the corner flourishes reach outside the panel.
const OVERHANG := 8.0
const SHADOW_STEPS := 4


func _init() -> void:
	content_margin_left = 20
	content_margin_right = 20
	content_margin_top = 14
	content_margin_bottom = 14


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(OVERHANG + SHADOW_STEPS * 3)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if shadow:
		for i in SHADOW_STEPS:
			rs.canvas_item_add_rect(to_canvas_item, rect.grow(2 + i * 3).grow_individual(0, 0, 0, 4),
				Color(0, 0, 0, 0.09))
	var p := rect.position
	var e := rect.end
	rs.canvas_item_add_polygon(to_canvas_item,
		PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]),
		PackedColorArray([fill_top, fill_top, fill_bottom, fill_bottom]))
	# Half-unit offsets put one-unit lines exactly on the screen's pixel rows at 4x.
	_outline(to_canvas_item, rect.grow(-0.5), line)
	if inner_line:
		_outline(to_canvas_item, rect.grow(-inner_inset - 0.5), Color(line, 0.3))
	if corners:
		var origins := [p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]
		for i in 4:
			_flourish(to_canvas_item, origins[i], i * PI / 2)


func _outline(item: RID, r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y), r.position])
	RenderingServer.canvas_item_add_polyline(item, pts, PackedColorArray([color]), 1.0)


## One corner's flourish, drawn for the top-left corner and turned by `angle` about `origin`:
## a rounded outer frame line hugging the corner and a small gem on the diagonal.
func _flourish(item: RID, origin: Vector2, angle: float) -> void:
	var pts := PackedVector2Array([Vector2(-OVERHANG + 1, 22)])
	for t in 9:
		var a := PI + t * (PI / 2) / 8
		pts.append(Vector2(2, 2) + Vector2(cos(a), sin(a)) * 9)
	pts.append(Vector2(22, -OVERHANG + 1))
	var curl := PackedVector2Array()
	for t in 7:
		var a := PI / 2 + t * (PI / 2) / 6
		curl.append(Vector2(9, 9) + Vector2(cos(a), sin(a)) * 6)
	for i in pts.size():
		pts[i] = origin + pts[i].rotated(angle)
	for i in curl.size():
		curl[i] = origin + curl[i].rotated(angle)
	var rs := RenderingServer
	rs.canvas_item_add_polyline(item, pts, PackedColorArray([line]), 1.6, true)
	rs.canvas_item_add_polyline(item, curl, PackedColorArray([Color(line, 0.6)]), 1.2, true)
	var gem := PackedVector2Array()
	for d in [Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)]:
		gem.append(origin + (Vector2(-2, -2) + d).rotated(angle))
	rs.canvas_item_add_polygon(item, gem, PackedColorArray([UiTheme.GOLD_PALE]))
