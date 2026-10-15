class_name AseFile
extends RefCounted
## Reads Aseprite / LibreSprite .ase files (spec: github.com/aseprite/aseprite,
## docs/ase-file-specs.md): canvas size, layers and their cels as Images. RGBA and
## indexed sprites; grayscale, tilemaps and blend modes aren't needed for portraits.

var size := Vector2i.ZERO
var frame_count := 0
## Bottom to top: {"name", "visible", "group" (a group layer: no cels), "level"
## (nesting depth), "cels": {frame: {"pos": Vector2i, "image": Image}}}.
var layers: Array[Dictionary] = []
var error := ""

var _depth := 32
var _transparent_index := 0
var _palette := PackedColorArray()


static func open(path: String) -> AseFile:
	var ase := AseFile.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		ase.error = "can't read " + path
	else:
		ase._parse(bytes)
	return ase


func _parse(b: PackedByteArray) -> void:
	if b.size() < 128 or b.decode_u16(4) != 0xA5E0:
		error = "not an .ase file"
		return
	frame_count = b.decode_u16(6)
	size = Vector2i(b.decode_u16(8), b.decode_u16(10))
	_depth = b.decode_u16(12)
	_transparent_index = b[28]
	if _depth != 32 and _depth != 8:
		error = "color mode not supported (use RGBA or indexed)"
		return
	var off := 128
	for frame in frame_count:
		var frame_size := b.decode_u32(off)
		var chunks := b.decode_u32(off + 12)
		if chunks == 0:
			chunks = b.decode_u16(off + 6)
		var p := off + 16
		for _i in chunks:
			var chunk_size := b.decode_u32(p)
			var data := b.slice(p + 6, p + chunk_size)
			match b.decode_u16(p + 4):
				0x2004: _read_layer(data)
				0x2005: _read_cel(data, frame)
				0x2019: _read_palette(data)
			if not error.is_empty():
				return
			p += chunk_size
		off += frame_size


func _read_layer(d: PackedByteArray) -> void:
	var name_length := d.decode_u16(16)
	layers.append({
		"name": d.slice(18, 18 + name_length).get_string_from_utf8(),
		"visible": d.decode_u16(0) & 1 != 0,
		"group": d.decode_u16(2) == 1,
		"level": d.decode_u16(4),
		"cels": {},
	})


func _read_cel(d: PackedByteArray, frame: int) -> void:
	var layer := d.decode_u16(0)
	var pos := Vector2i(d.decode_s16(2), d.decode_s16(4))
	var cel_type := d.decode_u16(7)
	if cel_type == 1:  # linked: the same cel as another frame's
		var linked: Dictionary = layers[layer].cels.get(d.decode_u16(16), {})
		if not linked.is_empty():
			layers[layer].cels[frame] = linked
		return
	if cel_type != 0 and cel_type != 2:
		return  # tilemaps
	var w := d.decode_u16(16)
	var h := d.decode_u16(18)
	var pixels := d.slice(20)
	if cel_type == 2:
		pixels = pixels.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	if pixels.size() != w * h * _depth / 8:
		error = "layer \"%s\": unreadable cel" % layers[layer].name
		return
	var image: Image
	if _depth == 32:
		image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, pixels)
	else:
		image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for i in pixels.size():
			var index := pixels[i]
			if index != _transparent_index and index < _palette.size():
				image.set_pixel(i % w, i / w, _palette[index])
	layers[layer].cels[frame] = {"pos": pos, "image": image}


func _read_palette(d: PackedByteArray) -> void:
	var first := d.decode_u32(4)
	var last := d.decode_u32(8)
	if _palette.size() <= last:
		_palette.resize(last + 1)
	var p := 20
	for i in range(first, last + 1):
		var flags := d.decode_u16(p)
		_palette[i] = Color8(d[p + 2], d[p + 3], d[p + 4], d[p + 5])
		p += 6
		if flags & 1:  # has a name
			p += 2 + d.decode_u16(p)
