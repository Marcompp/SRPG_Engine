class_name UiLayer
extends CanvasLayer
## A layer for HD UI (docs/ui_theme.md): scaled by 0.25 over the 240x160 game, so its
## children are laid out in 960x640 units. canvas_items stretch draws 2D at window
## resolution, so at the 4x window one unit is one screen pixel. Add screens to `root`.

const SIZE := Vector2(960, 640)
## HD units per game pixel.
const UNITS := 4.0

var root: Control


func _init(layer_index := 1) -> void:
	layer = layer_index
	scale = Vector2.ONE / UNITS
	root = Control.new()
	root.name = "Root"
	# Sized explicitly: a full-rect preset would size it to the 240x160 viewport.
	root.size = SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.hd()
	add_child(root)


## A point in game pixels (240x160) in this layer's units.
static func from_game(point: Vector2) -> Vector2:
	return point * UNITS
