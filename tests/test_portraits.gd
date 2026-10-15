extends "res://tests/test_base.gd"
## Portraits (Portraits, tools/portrait_exporter.gd, data/portraits.cfg): the data, the
## exported parts against the art, and composing (recolors, sides, offsets, shadows).


func test_portrait_data() -> void:
	var seen := {}
	for role: String in Portraits.ROLES:
		var r: Dictionary = Portraits.ROLES[role]
		var keys: Array = r["keys"]
		check_eq(keys.size(), 1 if r.get("fixed", false) else Portraits.SHADES, "%s: a key per shade" % role)
		for k: String in keys:
			check(not seen.has(k), "%s: key %s is also %s's" % [role, k, seen.get(k)])
			seen[k] = role
		if not r.get("fixed", false):
			var fam := Portraits.family(role)
			check(Portraits.RAMPS.has(fam), "%s: family %s exists" % [role, fam])
			if r.has("default"):
				check(Portraits.RAMPS.get(fam, {}).has(r.default), "%s: default ramp %s exists" % [role, r.default])
	for fam: String in Portraits.RAMPS:
		for ramp: String in Portraits.RAMPS[fam]:
			var colors: Array = Portraits.RAMPS[fam][ramp]
			check_eq(colors.size(), Portraits.SHADES, "%s/%s: four shades" % [fam, ramp])
			for c: String in colors:
				check(Color.html_is_valid(c), "%s/%s: %s is a color" % [fam, ramp, c])
	for slot: String in Portraits.SLOTS:
		check(Portraits.slots().has(slot), "[slots] %s is in the stack" % slot)
		var follows: String = Portraits.SLOTS[slot].get("follows", "")
		check(follows == "" or Portraits.slots().has(follows), "%s follows a slot" % slot)
	for name: String in Portraits.PRESETS:
		_check_recipe(Portraits.PRESETS[name], name)


func _check_recipe(recipe: Dictionary, what: String) -> void:
	for slot: String in recipe.get("parts", {}):
		var v: String = recipe.parts[slot]
		check(Portraits.PARTS.get(slot, {}).has(v) or (v == "" and Portraits.OPTIONAL.has(slot)),
			"%s: part %s/%s exists" % [what, slot, v])
	for role: String in recipe.get("ramps", {}):
		check(Portraits.ROLES.has(Portraits.base_role(role)), "%s: role %s exists" % [what, role])
		if Portraits.ROLES.has(Portraits.base_role(role)):
			check(Portraits.RAMPS[Portraits.family(role)].has(recipe.ramps[role]), "%s: ramp %s exists" % [what, recipe.ramps[role]])
	for slot: String in recipe.get("offsets", {}):
		check(Portraits.slots().has(slot), "%s: offset slot %s exists" % [what, slot])


func test_portrait_parts_match_the_art() -> void:
	# The exported parts are up to date with art/portraits/ (export again if not).
	var files := Array(DirAccess.get_files_at(PortraitExporter.ART_DIR)).filter(func(f): return f.ends_with(".ase"))
	check(not files.is_empty(), "there's portrait art")
	for file: String in files:
		var ase := AseFile.open(PortraitExporter.ART_DIR + file)
		check_eq(ase.error, "", file + " reads")
		check_eq(ase.size, Portraits.SIZE, file + ": the canvas is the portrait size")
		for layer in ase.layers:
			if layer.group or layer.name.begins_with("_") or not layer.cels.has(0):
				continue
			var name := PortraitExporter.parse_name(layer.name)
			check(not name.has("error"), "%s: %s: %s" % [file, layer.name, name.get("error", "")])
			if name.has("error"):
				continue
			check_eq(PortraitExporter.check_pixels(layer.cels[0].image, Portraits.EFFECTS.has(name.piece)), [] as Array[String],
				"%s: %s: only key colors" % [file, layer.name])
			var part: Dictionary = Portraits.PARTS.get(name.slot, {}).get(name.variant, {}).get(name.piece, {})
			check(not part.is_empty(), "%s is exported" % layer.name)
			if part.is_empty():
				continue
			var exported := Image.new()
			exported.load_png_from_buffer(FileAccess.get_file_as_bytes(Portraits.PARTS_DIR + part.file))
			var image: Image = layer.cels[0].image
			var used := image.get_used_rect()
			check_eq(part.pos, layer.cels[0].pos + used.position, "%s: exported in place" % layer.name)
			exported.convert(Image.FORMAT_RGBA8)
			check(image.get_region(used).get_data() == exported.get_data(), "%s: the exported pixels are the art's" % layer.name)


func test_portrait_exporter_checks() -> void:
	var image := Image.create_empty(3, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color("f8e3bb"))  # skin key
	check_eq(PortraitExporter.check_pixels(image), [] as Array[String], "key colors pass")
	image.set_pixel(1, 0, Color("715858"))  # one off from a skin key
	image.set_pixel(2, 0, Color(Color("f8e3bb"), 0.5))
	check_eq(PortraitExporter.check_pixels(image).size(), 2, "a near-miss color and a semi-transparent pixel fail")
	image.set_pixel(2, 0, Color.BLACK)
	check_eq(PortraitExporter.check_pixels(image, true), [] as Array[String], "effect pieces take any opaque color")
	check_eq(PortraitExporter.parse_name("hair/messy:back"), {"slot": "hair", "variant": "messy", "piece": "back"}, "a stacked piece")
	check_eq(PortraitExporter.parse_name("eyes/a:left").piece, "left", "a side")
	check_eq(PortraitExporter.parse_name("nose/a").piece, "main", "no piece")
	for bad in ["Eyes", "wings/a", "eyes/a:sideways", "eyes/Big"]:
		check(PortraitExporter.parse_name(bad).has("error"), "\"%s\" is refused" % bad)


func test_portrait_recolor() -> void:
	var base := Portraits.default_recipe()
	var image := Portraits.compose(base)
	check_eq(image.get_size(), Portraits.SIZE, "the portrait size")
	var tan := base.duplicate(true)
	tan.ramps = {"skin": "tan"}
	var colors := _colors(Portraits.compose(tan))
	check(colors.has(Color(Portraits.RAMPS.skin.tan[3])), "tan skin is painted")
	check(not colors.has(Color(Portraits.RAMPS.skin.peach[3])), "...instead of peach")
	# Each eye can have its own colors; unpicked, they follow the shared role.
	var odd := base.duplicate(true)
	odd.ramps = {"iris": "red", "iris_r": "green"}
	colors = _colors(Portraits.compose(odd))
	check(colors.has(Color(Portraits.RAMPS.iris.red[1])) and colors.has(Color(Portraits.RAMPS.iris.green[1])), "one red eye, one green")
	odd.ramps = {"iris": "red"}
	check(not _colors(Portraits.compose(odd)).has(Color(Portraits.RAMPS.iris.green[1])), "both red when only iris is picked")


func test_portrait_offsets() -> void:
	var r := Portraits.default_recipe()
	r.parts.hair = ""  # nothing over the eyes
	r.ramps = {"iris": "red"}
	var red := Color(Portraits.RAMPS.iris.red[1])
	var before := _bounds(Portraits.compose(r), red)
	r.offsets = {"eyes": {"y": -2}}
	check_eq(_bounds(Portraits.compose(r), red), Rect2i(before.position + Vector2i(0, -2), before.size), "eyes up 2")
	r.offsets = {"eyes": {"spacing": 1}}
	check_eq(_bounds(Portraits.compose(r), red), before.grow_individual(1, 0, 1, 0), "eyes 1 farther apart each")
	r.offsets = {"eyes": {"y": -1, "spacing": 2}, "brows": {"x": 1}}
	check_eq(Portraits.offset(r, "brows", "left"), Vector2i(-1, -1), "brows follow their eye")
	check_eq(Portraits.offset(r, "brows", "right"), Vector2i(3, -1), "...on both sides")


func test_portrait_shadows() -> void:
	# Default ramps are the key colors, so composed pixels read back as (role, shade).
	var r := Portraits.default_recipe()
	var lit := Portraits.compose(r, false)
	var shaded := Portraits.compose(r)
	var changed := 0
	for y in Portraits.SIZE.y:
		for x in Portraits.SIZE.x:
			var a := Portraits.key(lit.get_pixel(x, y))
			var b2 := Portraits.key(shaded.get_pixel(x, y))
			if a != b2:
				changed += 1
				check(b2[0] == a[0] and b2[1] == a[1] - 1, "(%d, %d): one shade darker in its own ramp: %s -> %s" % [x, y, a, b2])
	check(changed > 0, "the hair casts a shadow")


func test_portrait_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var first := Portraits.random_recipe(rng)
	rng.seed = 42
	check_eq(Portraits.random_recipe(rng), first, "the same seed makes the same portrait")
	for i in 20:
		var r := Portraits.random_recipe(rng, {"skin": ["dark"]})
		_check_recipe(r, "random %d" % i)
		check_eq(r.ramps.skin, "dark", "pools narrow the picks")
	check_eq(Portraits.compose(first).get_size(), Portraits.SIZE, "and it composes")
	for name: String in Portraits.PRESETS:
		check_eq(Portraits.preset_image(name).get_size(), Portraits.SIZE, name + "'s portrait")


func _colors(image: Image) -> Dictionary:
	var result := {}
	for y in image.get_height():
		for x in image.get_width():
			result[image.get_pixel(x, y)] = true
	return result


func _bounds(image: Image, color: Color) -> Rect2i:
	var rect := Rect2i()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y) == color:
				rect = Rect2i(x, y, 1, 1) if rect.size == Vector2i.ZERO else rect.expand(Vector2i(x, y)).merge(Rect2i(x, y, 1, 1))
	return rect
