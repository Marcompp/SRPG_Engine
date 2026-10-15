extends Control
## Portrait editor (dev tool): pick parts, ramps and offsets, see the result, and
## save it as a named character's preset (data/portrait_presets.cfg) or bake it
## to a PNG (portraits/baked/). Run from the project folder:
##   godot --path . res://tools/portrait_editor.tscn
## "Export art" re-reads art/portraits/*.ase, so a part saved in the art program
## shows up without restarting. Keys: R randomizes, S toggles shadows.

const PRESETS_FILE := "res://data/portrait_presets.cfg"
const ZOOM := 4
const OFFSET_LIMIT := 16

var recipe := {}
var shadows := true
var rng := RandomNumberGenerator.new()

var _preview: TextureRect
var _preview_small: TextureRect
var _controls: VBoxContainer
var _presets: OptionButton
var _name: LineEdit
var _status: Label
var _info: Label
## Set while controls are being filled in, so their signals don't change the recipe.
var _filling := false


func _ready() -> void:
	# A desktop tool, not a 240x160 game screen.
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = Vector2i(1280, 840)
	window.move_to_center()
	window.title = "Portrait editor"
	rng.randomize()
	_build()
	recipe = Portraits.default_recipe()
	_rebuild_controls()
	_fill_presets()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	match event.keycode:
		KEY_R: _randomize()
		KEY_S:
			shadows = not shadows
			_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("24242c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = Portraits.SIZE.x * ZOOM
	columns.add_child(left)
	_preview = _texture_rect(Portraits.SIZE * ZOOM)
	_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview.gui_input.connect(_on_preview_input)
	left.add_child(_preview)
	var small_row := HBoxContainer.new()
	_preview_small = _texture_rect(Portraits.SIZE)
	small_row.add_child(_preview_small)
	_info = Label.new()
	_info.text = "Hover the preview to see what a pixel is."
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	small_row.add_child(_info)
	left.add_child(small_row)

	var buttons := HFlowContainer.new()
	left.add_child(buttons)
	_button(buttons, "Randomize (R)", _randomize)
	_button(buttons, "Reset", func():
		recipe = Portraits.default_recipe()
		_fill_controls()
		_refresh())
	_button(buttons, "Shadows (S)", func():
		shadows = not shadows
		_refresh())
	_button(buttons, "Export art", _export_art)

	left.add_child(HSeparator.new())
	var preset_row := HBoxContainer.new()
	left.add_child(preset_row)
	_presets = OptionButton.new()
	_presets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_presets.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_presets)
	var name_row := HBoxContainer.new()
	left.add_child(name_row)
	_name = LineEdit.new()
	_name.placeholder_text = "Character name"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_button(name_row, "Save preset", _save_preset)
	_button(name_row, "Delete", _delete_preset)
	_button(name_row, "Bake PNG", _bake)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size.x = Portraits.SIZE.x * ZOOM
	left.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_controls = VBoxContainer.new()
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_controls)


func _texture_rect(size: Vector2i) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## The part, color and offset controls (again after an export: parts may change).
func _rebuild_controls() -> void:
	for c in _controls.get_children():
		_controls.remove_child(c)
		c.queue_free()
	_preview.custom_minimum_size = Portraits.SIZE * ZOOM
	_preview_small.custom_minimum_size = Portraits.SIZE

	var grid := _section("Parts", 2)
	for slot in Portraits.slots():
		var variants: Array = Portraits.PARTS.get(slot, {}).keys()
		if variants.is_empty():
			continue
		var option := _row_option(grid, slot)
		if Portraits.OPTIONAL.has(slot):
			option.add_item("(none)")
			option.set_item_metadata(-1, "")
		for v: String in variants:
			option.add_item(v)
			option.set_item_metadata(-1, v)
		option.set_meta("slot", slot)
		option.item_selected.connect(func(i):
			_set_in("parts", slot, option.get_item_metadata(i)))

	grid = _section("Colors", 2)
	for role: String in Portraits.ROLES:
		if Portraits.ROLES[role].get("fixed", false):
			continue
		var names := [role]
		if Portraits.ROLES[role].get("sides", false):
			names.append_array(Portraits.SIDES.values().map(func(s): return role + s))
		for r: String in names:
			var option := _row_option(grid, r if r == role else "  " + r)
			if r != role:
				option.add_item("(same as %s)" % role)
				option.set_item_metadata(-1, "")
			var ramps: Dictionary = Portraits.RAMPS.get(Portraits.family(role), {})
			for ramp: String in ramps:
				option.add_icon_item(_swatch(ramps[ramp]), ramp)
				option.set_item_metadata(-1, ramp)
			option.set_meta("role", r)
			option.item_selected.connect(func(i):
				_set_in("ramps", r, option.get_item_metadata(i)))

	grid = _section("Offsets (x, y, spacing)", 4)
	for slot in Portraits.slots():
		if not Portraits.PARTS.has(slot):
			continue
		var label := Label.new()
		label.text = slot
		var follows: String = Portraits.SLOTS.get(slot, {}).get("follows", "")
		if follows != "":
			label.text += " (+%s)" % follows
		grid.add_child(label)
		var sided: bool = Portraits.PARTS[slot].values().any(func(pieces): return pieces.has("left") or pieces.has("right"))
		for axis in ["x", "y", "spacing"]:
			if axis == "spacing" and not sided:
				grid.add_child(Control.new())
				continue
			var spin := SpinBox.new()
			spin.min_value = -OFFSET_LIMIT
			spin.max_value = OFFSET_LIMIT
			spin.set_meta("offset", [slot, axis])
			spin.value_changed.connect(func(value): _set_offset(slot, axis, int(value)))
			grid.add_child(spin)
	_fill_controls()


func _section(title: String, columns: int) -> GridContainer:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color("e8c070"))
	_controls.add_child(label)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	_controls.add_child(grid)
	_controls.add_child(HSeparator.new())
	return grid


func _row_option(grid: GridContainer, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	grid.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 220
	grid.add_child(option)
	return option


## A ramp's shades side by side, for the color menus.
func _swatch(ramp: Array) -> ImageTexture:
	var image := Image.create_empty(ramp.size() * 6, 12, false, Image.FORMAT_RGBA8)
	for i in ramp.size():
		image.fill_rect(Rect2i(i * 6, 0, 6, 12), Color(ramp[i]))
	return ImageTexture.create_from_image(image)


## Shows the recipe in the controls.
func _fill_controls() -> void:
	_filling = true
	for node in _all_controls(_controls):
		if node is OptionButton and node.has_meta("slot"):
			_select(node, Portraits.variant(recipe, node.get_meta("slot")))
		elif node is OptionButton and node.has_meta("role"):
			var role: String = node.get_meta("role")
			var picked: String = recipe.get("ramps", {}).get(role, "")
			_select(node, picked if picked != "" or role != Portraits.base_role(role) else Portraits.ramp_name(recipe, role))
		elif node is SpinBox:
			var where: Array = node.get_meta("offset")
			node.value = recipe.get("offsets", {}).get(where[0], {}).get(where[1], 0)
	_filling = false


func _all_controls(node: Node) -> Array:
	var result := []
	for c in node.get_children():
		result.append(c)
		result.append_array(_all_controls(c))
	return result


func _select(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if option.get_item_metadata(i) == value:
			option.select(i)
			return
	option.select(0)


func _set_in(group: String, key: String, value: String) -> void:
	if _filling:
		return
	var d: Dictionary = recipe.get_or_add(group, {})
	if value == "" and group == "ramps":
		d.erase(key)
	else:
		d[key] = value
	_refresh()


func _set_offset(slot: String, axis: String, value: int) -> void:
	if _filling:
		return
	var o: Dictionary = recipe.get_or_add("offsets", {}).get_or_add(slot, {})
	o[axis] = value
	_refresh()


func _refresh() -> void:
	var texture := ImageTexture.create_from_image(Portraits.compose(recipe, shadows))
	_preview.texture = texture
	_preview_small.texture = texture
	_set_status("" if shadows else "Shadows off.")


func _randomize() -> void:
	recipe = Portraits.random_recipe(rng)
	_fill_controls()
	_refresh()


func _on_preview_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var p := Vector2i(event.position / _preview.size * Vector2(Portraits.SIZE))
	if not Rect2i(Vector2i.ZERO, Portraits.SIZE).has_point(p):
		return
	# Which part is on top there: the topmost slot with a pixel at that point.
	var text := "(%d, %d)" % [p.x, p.y]
	for d in range(Portraits.STACK.size() - 1, -1, -1):
		var slot := Portraits.STACK[d].get_slice(":", 0)
		var v := Portraits.variant(recipe, slot)
		if v == "":
			continue
		for piece: String in Portraits.PARTS[slot][v]:
			if Portraits.EFFECTS.has(piece) or Portraits.depth_of(slot, piece) != d:
				continue
			var part: Dictionary = Portraits.PARTS[slot][v][piece]
			var local: Vector2i = p - part.pos - Portraits.offset(recipe, slot, piece)
			var img := _part_image(part.file)
			if Rect2i(Vector2i.ZERO, img.get_size()).has_point(local) and img.get_pixel(local.x, local.y).a8 > 0:
				var k := Portraits.key(img.get_pixel(local.x, local.y))
				var what: String = "effect" if k.is_empty() else "%s shade %d" % k
				if not k.is_empty() and Portraits.SIDES.has(piece) and Portraits.ROLES[k[0]].get("sides", false):
					what = "%s%s shade %d" % [k[0], Portraits.SIDES[piece], k[1]]
				_info.text = "%s\n%s/%s%s\n%s" % [text, slot, v, "" if piece == "main" else ":" + piece, what]
				return
	_info.text = text


var _part_images := {}

func _part_image(file: String) -> Image:
	if not _part_images.has(file):
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(Portraits.PARTS_DIR + file))
		_part_images[file] = image
	return _part_images[file]


func _export_art() -> void:
	var errors := PortraitExporter.run()
	if not errors.is_empty():
		_set_status("Export failed:\n" + "\n".join(errors.slice(0, 12)), true)
		return
	_part_images.clear()
	_rebuild_controls()
	_refresh()
	_set_status("Exported %d slots from art/portraits/." % Portraits.PARTS.size())


func _fill_presets() -> void:
	_presets.clear()
	_presets.add_item("(presets)")
	for name: String in _load_presets().get_sections():
		_presets.add_item(name)


func _on_preset_selected(i: int) -> void:
	if i == 0:
		return
	var name := _presets.get_item_text(i)
	var config := _load_presets()
	recipe = {}
	for key in config.get_section_keys(name):
		recipe[key] = config.get_value(name, key)
	_name.text = name
	_fill_controls()
	_refresh()


func _load_presets() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PRESETS_FILE)
	return config


func _save_preset() -> void:
	var name := _name.text.strip_edges()
	if name == "" or name.contains("]"):
		_set_status("Give the character a name first.", true)
		return
	var config := _load_presets()
	if config.has_section(name):
		config.erase_section(name)
	var clean := _clean(recipe)
	for key: String in clean:
		config.set_value(name, key, clean[key])
	_write_presets(config)
	_fill_presets()
	_set_status("Saved %s." % name)


func _delete_preset() -> void:
	var name := _name.text.strip_edges()
	var config := _load_presets()
	if not config.has_section(name):
		_set_status("No preset named \"%s\"." % name, true)
		return
	config.erase_section(name)
	_write_presets(config)
	_fill_presets()
	_set_status("Deleted %s." % name)


## The recipe without zero offsets, so presets stay short.
func _clean(r: Dictionary) -> Dictionary:
	var offsets := {}
	for slot: String in r.get("offsets", {}):
		var o := {}
		for axis: String in r.offsets[slot]:
			if r.offsets[slot][axis] != 0:
				o[axis] = r.offsets[slot][axis]
		if not o.is_empty():
			offsets[slot] = o
	var result := {"parts": r.get("parts", {}).duplicate(), "ramps": r.get("ramps", {}).duplicate()}
	if not offsets.is_empty():
		result["offsets"] = offsets
	return result


## Writes the presets by hand: ConfigFile.save would drop the file's header comment.
func _write_presets(config: ConfigFile) -> void:
	var path := ProjectSettings.globalize_path(PRESETS_FILE)
	var header := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not line.begins_with(";"):
			break
		header += line + "\n"
	var text := header
	for section in config.get_sections():
		text += "\n[%s]\n" % section
		for key in config.get_section_keys(section):
			text += "%s=%s\n" % [key, var_to_str(config.get_value(section, key)).replace("\n", " ")]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	Portraits.reload()


func _bake() -> void:
	var name := _name.text.strip_edges()
	if name == "":
		_set_status("Give the character a name first.", true)
		return
	var path := Portraits.baked_path(name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Portraits.BAKED_DIR))
	Portraits.compose(recipe).save_png(ProjectSettings.globalize_path(path))
	_set_status("Baked %s. It's used instead of the recipe from now on; delete the file to go back." % path)


func _set_status(text: String, error := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color("f08080") if error else Color("a0d0a0"))
