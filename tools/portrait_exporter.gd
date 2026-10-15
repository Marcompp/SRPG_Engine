class_name PortraitExporter
extends RefCounted
## Exports portrait parts from art/portraits/*.ase to portraits/parts/ (design:
## docs/portraits.md): one PNG per part, trimmed, plus index.cfg with each part's
## place on the canvas. Run by tools/export_portraits.gd or the portrait editor.
##
## Layers are named "slot/variant" or "slot/variant:piece" (a slot from
## data/portraits.cfg [stack]; variants and pieces in lowercase letters, digits and
## "_"). Pieces: "left"/"right" (one side: sided colors, spacing), "shadow", "light",
## "mask" (change what's under them), or one the stack places on its own ("back").
## Layers starting with "_" (references, backgrounds) and group layers are skipped,
## hidden or not. Every pixel must be a key color, fully opaque, except in effect
## pieces, where any opaque pixel counts.

const ART_DIR := "res://art/portraits/"


## Exports everything; returns the problems found (no parts are written if there are any).
static func run() -> Array[String]:
	write_palette()
	var errors: Array[String] = []
	var parts := {}  # slot -> variant -> piece -> {"image", "pos", "from"}
	var canvas := Vector2i.ZERO
	var files := Array(DirAccess.get_files_at(ART_DIR)).filter(func(f): return f.ends_with(".ase"))
	files.sort()
	if files.is_empty():
		errors.append("no .ase files in " + ART_DIR)
	for file: String in files:
		var ase := AseFile.open(ART_DIR + file)
		if not ase.error.is_empty():
			errors.append("%s: %s" % [file, ase.error])
			continue
		if canvas == Vector2i.ZERO:
			canvas = ase.size
		elif ase.size != canvas:
			errors.append("%s: %dx%d, but the other files are %dx%d" % [file, ase.size.x, ase.size.y, canvas.x, canvas.y])
			continue
		for layer in ase.layers:
			if layer.group or layer.name.begins_with("_"):
				continue
			var where := "%s, layer \"%s\"" % [file, layer.name]
			var name := parse_name(layer.name)
			if name.has("error"):
				errors.append("%s: %s" % [where, name.error])
				continue
			if not layer.cels.has(0):
				continue  # empty
			var image: Image = layer.cels[0].image
			errors.append_array(check_pixels(image, Portraits.EFFECTS.has(name.piece)).map(
				func(e): return "%s: %s" % [where, e]))
			var used := image.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var variants: Dictionary = parts.get_or_add(name.slot, {})
			var pieces: Dictionary = variants.get_or_add(name.variant, {})
			if pieces.has(name.piece):
				errors.append("%s: %s is also in %s" % [where, layer.name, pieces[name.piece].from])
				continue
			pieces[name.piece] = {"image": image.get_region(used), "pos": layer.cels[0].pos + used.position, "from": file}
	if not errors.is_empty():
		return errors
	_write(parts, canvas)
	return errors


## Writes art/portraits/keys.gpl, the key colors as a palette to draw with (Palette >
## Load in LibreSprite or Aseprite; in indexed mode nothing else can be painted). Same
## order as test.ase's palette: the transparent slot, the outline three times (to
## fill a row of four), then each role's shades, darkest first.
static func write_palette() -> void:
	var lines := ["GIMP Palette", "Name: Portrait keys (from data/portraits.cfg)", "Columns: 4", "#",
		"  0   0   0\t(transparent)"]
	for role: String in Portraits.ROLES:
		var keys: Array = Portraits.ROLES[role]["keys"]
		for i in maxi(keys.size(), 3) if keys.size() == 1 else keys.size():
			var c := Color(keys[mini(i, keys.size() - 1)])
			var label := role if keys.size() == 1 else "%s %d" % [role, i]
			lines.append("%3d %3d %3d\t%s" % [c.r8, c.g8, c.b8, label])
	var f := FileAccess.open(ProjectSettings.globalize_path(ART_DIR + "keys.gpl"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


## {"slot", "variant", "piece"} ("main" for none) from a layer name, or {"error"}.
static func parse_name(layer_name: String) -> Dictionary:
	var re := RegEx.create_from_string("^([a-z0-9_]+)/([a-z0-9_]+)(?::([a-z0-9_]+))?$")
	var m := re.search(layer_name)
	if m == null:
		return {"error": "name it slot/variant or slot/variant:piece (lowercase, digits, _), or start it with _ to skip it"}
	var slot := m.get_string(1)
	var piece := m.get_string(3) if m.get_string(3) != "" else "main"
	if not Portraits.slots().has(slot):
		return {"error": "no slot \"%s\" (data/portraits.cfg [stack])" % slot}
	if piece != "main" and not Portraits.SIDES.has(piece) and not Portraits.EFFECTS.has(piece) \
			and not Portraits.STACK.has(slot + ":" + piece):
		return {"error": "unknown piece \"%s\"" % piece}
	return {"slot": slot, "variant": m.get_string(2), "piece": piece}


## Pixels that aren't fully opaque key colors (`effect`: any opaque color will do).
static func check_pixels(image: Image, effect := false) -> Array[String]:
	var errors: Array[String] = []
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a8 == 0:
				continue
			if c.a8 != 255:
				errors.append("(%d, %d) is semi-transparent" % [x, y])
			elif not effect and Portraits.key(c).is_empty():
				errors.append("(%d, %d) is #%s, not a key color" % [x, y, c.to_html(false)])
			if errors.size() >= 10:
				errors.append("...")
				return errors
	return errors


static func _write(parts: Dictionary, canvas: Vector2i) -> void:
	var dir := ProjectSettings.globalize_path(Portraits.PARTS_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	# Clear the last export (parts can be renamed or removed).
	for sub in DirAccess.get_directories_at(dir):
		for f in DirAccess.get_files_at(dir.path_join(sub)):
			if f.ends_with(".png") or f.ends_with(".png.import"):
				DirAccess.remove_absolute(dir.path_join(sub).path_join(f))
	var text := "; Made by tools/portrait_exporter.gd from art/portraits/*.ase. Don't edit: export again.\n"
	text += "; Each slot's variants: {piece: {\"file\", \"pos\"}} (\"main\" when it has no piece name).\n\n"
	text += "[canvas]\nsize=%s\n" % var_to_str(canvas)
	for slot in Portraits.slots():
		if not parts.has(slot):
			continue
		DirAccess.make_dir_recursive_absolute(dir.path_join(slot))
		text += "\n[%s]\n" % slot
		for variant: String in parts[slot]:
			var entry := {}
			for piece: String in parts[slot][variant]:
				var file := "%s/%s%s.png" % [slot, variant, "" if piece == "main" else "_" + piece]
				parts[slot][variant][piece].image.save_png(dir.path_join(file))
				entry[piece] = {"file": file, "pos": parts[slot][variant][piece].pos}
			text += "%s=%s\n" % [variant, var_to_str(entry).replace("\n", " ")]
	var f := FileAccess.open(dir.path_join("index.cfg"), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	Portraits.reload()
