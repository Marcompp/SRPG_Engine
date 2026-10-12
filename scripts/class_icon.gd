class_name ClassIcon
extends Control
## Placeholder class icons (data/icons.cfg), until there are map sprites: a pixel
## bitmap per role that a class names with "icon" (Classes). Drawn on map tokens
## (Unit._draw) and, as this Control, scaled up on the status screen's portrait.

static var ICONS := GameData.entries("icons")

const COLOR := Color.WHITE
const SHADOW := Color(0, 0, 0, 0.45)

## The icon's rows ("#" drawn, "." empty).
var pixels: Array = []


## The icon rows for `class_id`, or [] when it has none.
static func for_class(class_id: String) -> Array:
	var icon: String = Classes.get_data(class_id).get("icon", "")
	return ICONS[icon].pixels if ICONS.has(icon) else []


## Draws `rows` on `canvas` with its top-left at `origin`, each pixel `px` wide,
## over a shadow down and to the right (a third of a pixel, at least 1).
static func paint(canvas: CanvasItem, rows: Array, origin: Vector2, px: float) -> void:
	for pass_color: Color in [SHADOW, COLOR]:
		var offset := Vector2.ONE * maxf(1.0, floorf(px / 3.0)) if pass_color == SHADOW else Vector2.ZERO
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					canvas.draw_rect(Rect2(origin + offset + Vector2(x, y) * px, Vector2(px, px)), pass_color)


func _draw() -> void:
	if pixels.is_empty():
		return
	var scale_px := floorf(minf(size.x / pixels[0].length(), size.y / pixels.size()))
	var drawn := Vector2(pixels[0].length(), pixels.size()) * scale_px
	paint(self, pixels, ((size - drawn) / 2.0).floor(), scale_px)
