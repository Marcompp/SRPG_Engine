class_name Portraits
extends RefCounted
## Portraits put together from layered parts and painted from color ramps (design:
## docs/portraits.md). Parts are drawn in key colors (data/portraits.cfg [roles]) in
## art/portraits/*.ase; tools/portrait_exporter.gd exports them to portraits/parts/.
## Every pixel is composed as a (role, shade) pair and colored at the end, so
## shadows and recolors work with any ramps.
##
## A recipe says which parts, ramps and offsets make a portrait (all keys optional):
##   {"parts": {"hair": "messy", "marks": ""},   ; "" leaves an optional slot empty
##    "ramps": {"skin": "tan", "iris": "brown", "iris_r": "green"},
##    "offsets": {"eyes": {"x": 0, "y": -1, "spacing": 1}}}
## A slot it doesn't name gets its first variant, or stays empty if it's optional.
## Named characters' recipes are in data/portrait_presets.cfg (made with
## tools/portrait_editor.tscn).

const PARTS_DIR := "res://portraits/parts/"
const BAKED_DIR := "res://portraits/baked/"
const SHADES := 4
## Pieces on one side: their sided roles (iris -> iris_l) and spacing apply.
const SIDES := {"left": "_l", "right": "_r"}
## Pieces that change what's under them (by slots stacked below theirs) instead of
## adding pixels: one shade darker, one lighter, or erased.
const EFFECTS: Array[String] = ["shadow", "light", "mask"]

static var STACK: Array[String]
static var OPTIONAL: Array[String]
static var ROLES: Dictionary
static var SLOTS: Dictionary
static var RAMPS: Dictionary
static var PRESETS: Dictionary
## The canvas every part is placed on (the art's size).
static var SIZE := Vector2i(96, 80)
## Exported parts: {slot: {variant: {piece: {"file", "pos"}}}}; the plain piece is "main".
static var PARTS: Dictionary

## Role names, sided ones included (iris, iris_l, iris_r...); a pixel stores an index.
static var _role_names: Array[String] = []
static var _role_index := {}
## Key color (as an int) -> [role index, shade].
static var _key_of := {}
## Part file -> PackedInt32Array of (x, y, role index * SHADES + shade) triples.
static var _pixels := {}
static var _textures := {}


static func _static_init() -> void:
	reload()


## Reads the data and the exported parts again (the editor calls it after an export).
static func reload() -> void:
	STACK = GameData.strings("portraits", "stack", "order")
	OPTIONAL = GameData.strings("portraits", "stack", "optional")
	ROLES = GameData.section("portraits", "roles")
	SLOTS = GameData.section("portraits", "slots")
	RAMPS = GameData.entries("portrait_ramps")
	PRESETS = GameData.entries("portrait_presets")
	_role_names.clear()
	_role_index.clear()
	_key_of.clear()
	for role: String in ROLES:
		var names := [role]
		if ROLES[role].get("sides", false):
			names.append_array(SIDES.values().map(func(suffix): return role + suffix))
		for n: String in names:
			_role_index[n] = _role_names.size()
			_role_names.append(n)
		var keys: Array = ROLES[role]["keys"]
		for shade in keys.size():
			_key_of[Color(keys[shade]).to_rgba32()] = [_role_index[role], shade]
	PARTS = {}
	var index := ConfigFile.new()
	if index.load(PARTS_DIR + "index.cfg") == OK:
		SIZE = index.get_value("canvas", "size", SIZE)
		for slot in index.get_sections():
			if slot != "canvas":
				PARTS[slot] = {}
				for variant in index.get_section_keys(slot):
					PARTS[slot][variant] = index.get_value(slot, variant)
	_pixels.clear()
	_textures.clear()


## The slots portraits are made of, back to front, without pieces ("hair:back" -> "hair").
static func slots() -> Array[String]:
	var result: Array[String] = []
	for entry in STACK:
		var slot := entry.get_slice(":", 0)
		if not result.has(slot):
			result.append(slot)
	return result


## Where `piece` of `slot` goes in STACK.
static func depth_of(slot: String, piece: String) -> int:
	var own := STACK.find(slot + ":" + piece)
	return own if own >= 0 else STACK.find(slot)


## [role, shade] for a key color, or [] if it isn't one.
static func key(color: Color) -> Array:
	var k: Array = _key_of.get(color.to_rgba32(), [])
	return [] if k.is_empty() else [_role_names[k[0]], k[1]]


## The family a role (sided or not) paints from.
static func family(role: String) -> String:
	var base := base_role(role)
	return ROLES[base].get("family", base)


static func base_role(role: String) -> String:
	for suffix: String in SIDES.values():
		if role.ends_with(suffix) and ROLES.has(role.trim_suffix(suffix)):
			return role.trim_suffix(suffix)
	return role


## The ramp a recipe paints `role` with: its own pick, else the shared role's (for
## sided roles), else the role's default.
static func ramp_name(recipe: Dictionary, role: String) -> String:
	var ramps: Dictionary = recipe.get("ramps", {})
	var fam := family(role)
	for r in [role, base_role(role)]:
		if RAMPS.get(fam, {}).has(ramps.get(r, "")):
			return ramps[r]
	var default: String = ROLES[base_role(role)].get("default", "")
	return default if RAMPS.get(fam, {}).has(default) else RAMPS.get(fam, {}).keys().front()


## The variant a recipe uses in `slot` ("" for none).
static func variant(recipe: Dictionary, slot: String) -> String:
	var variants: Dictionary = PARTS.get(slot, {})
	var picked: String = recipe.get("parts", {}).get(slot, "" if OPTIONAL.has(slot) else "?")
	if variants.has(picked) or (picked == "" and OPTIONAL.has(slot)):
		return picked
	return "" if variants.is_empty() else variants.keys().front()


## How far a piece moves: its slot's offset plus the offsets of the slots it follows;
## spacing moves left pieces left and right pieces right.
static func offset(recipe: Dictionary, slot: String, piece: String) -> Vector2i:
	var total := Vector2i.ZERO
	var spacing := 0
	var seen := {}
	while slot != "" and not seen.has(slot):
		seen[slot] = true
		var o: Dictionary = recipe.get("offsets", {}).get(slot, {})
		total += Vector2i(o.get("x", 0), o.get("y", 0))
		spacing += o.get("spacing", 0)
		slot = SLOTS.get(slot, {}).get("follows", "")
	if piece == "left":
		total.x -= spacing
	elif piece == "right":
		total.x += spacing
	return total


## A recipe with every slot's first variant and the default ramps.
static func default_recipe() -> Dictionary:
	var parts := {}
	for slot in slots():
		if PARTS.has(slot):
			parts[slot] = PARTS[slot].keys().front()
	return {"parts": parts, "ramps": {}, "offsets": {}}


## A random recipe. `pools` narrows the ramp picks, by role or family:
## {"skin": ["tan", "brown"], "cloth": ["red"]}.
static func random_recipe(rng: RandomNumberGenerator, pools := {}) -> Dictionary:
	var parts := {}
	for slot in slots():
		var options: Array = PARTS.get(slot, {}).keys()
		if options.is_empty():
			continue
		if OPTIONAL.has(slot):
			options.append("")
		parts[slot] = options[rng.randi() % options.size()]
	var ramps := {}
	for role: String in ROLES:
		if ROLES[role].get("fixed", false):
			continue
		var fam := family(role)
		var options: Array = pools.get(role, pools.get(fam, RAMPS.get(fam, {}).keys()))
		if not options.is_empty():
			ramps[role] = options[rng.randi() % options.size()]
	var offsets := {}
	for slot: String in SLOTS:
		var o := {}
		for axis in ["x", "y", "spacing"]:
			var range_: Array = SLOTS[slot].get(axis, [])
			if range_.size() == 2:
				o[axis] = rng.randi_range(range_[0], range_[1])
		if not o.is_empty():
			offsets[slot] = o
	return {"parts": parts, "ramps": ramps, "offsets": offsets}


## The portrait a recipe makes. `shadows` false leaves out cast shadows and shadow
## pieces (to compare).
static func compose(recipe: Dictionary, shadows := true) -> Image:
	var w := SIZE.x
	var n := SIZE.x * SIZE.y
	var role := PackedInt32Array()
	role.resize(n)
	role.fill(-1)
	var shade := PackedByteArray()
	shade.resize(n)
	var depth := PackedInt32Array()
	depth.resize(n)
	depth.fill(-1)
	var fixed := {}
	for r in _role_names.size():
		fixed[r] = ROLES[base_role(_role_names[r])].get("fixed", false)

	for d in STACK.size():
		var slot := STACK[d].get_slice(":", 0)
		var v := variant(recipe, slot)
		if v == "":
			continue
		var placed := {}
		var pieces: Dictionary = PARTS[slot][v]
		# Pixels first, then the pieces that change them.
		for pass_effects in [false, true]:
			for piece: String in pieces:
				if EFFECTS.has(piece) != pass_effects or depth_of(slot, piece) != d:
					continue
				if piece == "shadow" and not shadows:
					continue
				var origin: Vector2i = pieces[piece].pos + offset(recipe, slot, piece)
				var px := _part_pixels(pieces[piece].file)
				for i in range(0, px.size(), 3):
					var x := origin.x + px[i]
					var y := origin.y + px[i + 1]
					if x < 0 or y < 0 or x >= w or y >= SIZE.y:
						continue
					var at := y * w + x
					if not pass_effects:
						var r := px[i + 2] / SHADES
						if SIDES.has(piece):
							r = _role_index.get(_role_names[r] + SIDES[piece], r)
						role[at] = r
						shade[at] = px[i + 2] % SHADES
						depth[at] = d
						placed[at] = true
					elif depth[at] >= 0 and depth[at] < d:
						if piece == "mask":
							var masks: Array = SLOTS.get(slot, {}).get("masks", [])
							if masks.is_empty() or masks.has(STACK[depth[at]].get_slice(":", 0)):
								role[at] = -1
								depth[at] = -1
						elif not fixed[role[at]]:
							shade[at] = clampi(shade[at] + (-1 if piece == "shadow" else 1), 0, SHADES - 1)
		var cast: Vector2i = SLOTS.get(slot, {}).get("cast_shadow", Vector2i.ZERO)
		if shadows and cast != Vector2i.ZERO:
			for at: int in placed:
				var x: int = at % w + cast.x
				var y: int = at / w + cast.y
				if x < 0 or y < 0 or x >= w or y >= SIZE.y:
					continue
				var t := y * w + x
				if depth[t] >= 0 and depth[t] < d and not fixed[role[t]]:
					shade[t] = maxi(shade[t] - 1, 0)

	var colors := []
	for r in _role_names.size():
		var base := base_role(_role_names[r])
		var hexes: Array = ROLES[base]["keys"] if fixed[r] else RAMPS[family(base)][ramp_name(recipe, _role_names[r])]
		colors.append(hexes.map(func(h): return Color(h)))
	var image := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for at in n:
		if role[at] >= 0:
			var c: Array = colors[role[at]]
			image.set_pixel(at % w, at / w, c[mini(shade[at], c.size() - 1)])
	return image


## compose() as a texture, cached by recipe.
static func texture(recipe: Dictionary) -> ImageTexture:
	var k := var_to_str(recipe)
	if not _textures.has(k):
		_textures[k] = ImageTexture.create_from_image(compose(recipe))
	return _textures[k]


## A named character's portrait: its baked PNG if it has one, else its recipe.
static func preset_image(name: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(baked_path(name))
	if not bytes.is_empty():
		var image := Image.new()
		if image.load_png_from_buffer(bytes) == OK:
			return image
	return compose(PRESETS.get(name, {}))


static func baked_path(name: String) -> String:
	return BAKED_DIR + name.validate_filename() + ".png"


## A part's pixels as (x, y, role index * SHADES + shade) triples, loaded once.
static func _part_pixels(file: String) -> PackedInt32Array:
	if _pixels.has(file):
		return _pixels[file]
	var px := PackedInt32Array()
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(PARTS_DIR + file)) != OK:
		push_error("can't read portrait part " + file)
	else:
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a8 == 0:
					continue
				# Effect pieces (shadow, light, mask) use any color.
				var k: Array = _key_of.get(Color(c, 1.0).to_rgba32(), [0, 0])
				px.append_array([x, y, k[0] * SHADES + k[1]])
	_pixels[file] = px
	return px
