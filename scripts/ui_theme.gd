class_name UiTheme
## The UI's look, "Gilded Night" (design: docs/ui_theme.md): palette, fonts and the shared
## Theme, hd(), for screens on a UiLayer (laid out in 960x640 units).

## Palette.
const GOLD := Color8(214, 178, 94)  # lines and outlines
const GOLD_BRIGHT := Color8(243, 220, 154)  # names, selected text
const GOLD_PALE := Color8(244, 220, 150)  # the diamond, corner gems
const CAPTION := Color8(201, 178, 122)  # small capitals (labels, tabs)
const TEXT := Color8(239, 230, 207)
const DIM := Color8(169, 160, 196)  # secondary text
const NAVY_TOP := Color(18 / 255.0, 20 / 255.0, 50 / 255.0, 0.95)
const NAVY_BOTTOM := Color(8 / 255.0, 9 / 255.0, 28 / 255.0, 0.92)
const HP_FROM := Color8(111, 191, 94)
const HP_TO := Color8(214, 234, 138)

## Font sizes in HD units.
const SIZE_NAME := 30
const SIZE_TITLE := 24
const SIZE_BODY := 25
const SIZE_DIALOGUE := 28
const SIZE_SMALL := 21
const SIZE_CAPTION := 16

const DISPLAY_FONT := "res://fonts/Cinzel-Variable.ttf"
const BODY_FONT := "res://fonts/EBGaramond-Variable.ttf"
const BODY_ITALIC_FONT := "res://fonts/EBGaramond-Italic-Variable.ttf"

static var _hd: Theme
static var _fonts := {}


## A font at a weight (100-900, along the variable font's axis), optionally letter-spaced.
## One FontVariation carries both: nesting variations loses the inner one's weight.
static func font(path: String, weight := 400, spacing := 0) -> Font:
	var key := "%s/%d/%d" % [path, weight, spacing]
	if not _fonts.has(key):
		var base: FontFile = load(path)
		# Mipmaps keep text smooth when the window's scale draws it smaller than its
		# size (see UiLayer).
		base.generate_mipmaps = true
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		v.spacing_glyph = spacing
		_fonts[key] = v
	return _fonts[key]


## Engraved capitals for names, headings and labels.
static func display(weight := 500, spacing := 1) -> Font:
	return font(DISPLAY_FONT, weight, spacing)


static func body(italic := false, weight := 400) -> Font:
	return font(BODY_ITALIC_FONT if italic else BODY_FONT, weight)


## The theme for UiLayer screens. Label variations: NameLabel (a unit's name), TitleLabel
## (a window's heading), SubLabel (secondary text), CaptionLabel (small capitals).
## PanelContainer variations: PlatePanel (the dialogue name plate). SelectedRow is a
## Panel variation for the highlighted menu row.
static func hd() -> Theme:
	if _hd:
		return _hd
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 0)
	t.set_stylebox("panel", "PanelContainer", GildedStyleBox.new())
	t.set_stylebox("panel", "Panel", GildedStyleBox.new())

	_label_variation(t, "NameLabel", display(700, 2), SIZE_NAME, GOLD_BRIGHT)
	_label_variation(t, "TitleLabel", display(500, 1), SIZE_TITLE, GOLD_BRIGHT)
	_label_variation(t, "SubLabel", body(), SIZE_SMALL, DIM)
	_label_variation(t, "CaptionLabel", display(500, 2), SIZE_CAPTION, CAPTION)

	t.set_type_variation("PlatePanel", "PanelContainer")
	var plate := GildedStyleBox.new()
	plate.corners = false
	plate.inner_line = false
	plate.fill_top = Color(NAVY_BOTTOM, 0.95)
	plate.fill_bottom = Color(NAVY_TOP, 0.95)
	plate.set_content_margin_all(6)
	plate.content_margin_left = 26
	plate.content_margin_right = 26
	t.set_stylebox("panel", "PlatePanel", plate)

	t.set_type_variation("SelectedRow", "Panel")
	t.set_stylebox("panel", "SelectedRow", selected_row())
	_hd = t
	return t


static func _label_variation(t: Theme, name: StringName, f: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, f)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


## The highlighted menu row: a gold band fading out at both ends.
static func selected_row() -> StyleBoxTexture:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.85, 1.0])
	g.colors = PackedColorArray([Color(GOLD, 0.0), Color(GOLD, 0.32), Color(GOLD, 0.1), Color(GOLD, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 1
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	return sb


## The active tab: a gold underline.
static func tab_underline() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = GOLD
	sb.border_width_bottom = 2
	sb.content_margin_bottom = 6
	return sb


## Seconds a window takes to appear, at normal game speed.
const APPEAR_SECONDS := 0.14


## Fades `c` in as it opens (and, with `grow`, scales it up from 97% around its
## center: scale doesn't move the layout). Faster at higher game speeds; instant when
## the "atmosphere" option is off. Closing stays instant.
static func appear(c: Control, grow := true) -> void:
	var running: Tween = c.get_meta("appear_tween") if c.has_meta("appear_tween") else null
	if running and running.is_valid():
		running.kill()
	c.modulate.a = 1.0
	c.scale = Vector2.ONE
	if not Settings.value("atmosphere"):
		return
	var seconds := APPEAR_SECONDS / float(Settings.value("game_speed"))
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(c, "modulate:a", 1.0, seconds)
	if grow:
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * 0.97
		tw.tween_property(c, "scale", Vector2.ONE, seconds)
	c.set_meta("appear_tween", tw)
