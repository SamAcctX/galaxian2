extends RefCounted
## Lazy loading of validated, base-bound texture derivatives.
const MAX_BYTES := 192 * 1024 * 1024
const MAX_PIXELS := 32 * 1024 * 1024
var error := ""
var root := ""
var base_content_id := ""
var textures := {}
## Decoded pixels of recently loaded textures, most recently used last: name to
## [modification time, width, height, mipmaps, pixels]. Images made from them
## share the pixels until one is edited, so a sprite sheet asked for once per
## sprite is read, checked and inflated once.
var _decoded := {}
var _decoded_bytes := 0
var _decoded_limit := 32 * 1024 * 1024 if OS.has_feature("mobile") else 128 * 1024 * 1024
## Textures made by load_texture(), held weakly: name to [modification time,
## WeakRef]. Sprites cut from one sheet share its texture while any is in use.
var _shared := {}

func open(directory: String, base_manifest: Dictionary) -> bool:
	error = ""
	root = ""
	base_content_id = ""
	textures = {}
	_decoded.clear()
	_decoded_bytes = 0
	_shared.clear()
	var file := FileAccess.open(directory.path_join("visuals.json"), FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		return fail("Missing or oversized visual manifest")
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or value.get("schema") != 1:
		return fail("Unsupported visual schema")
	if not value.get("recipe") is Dictionary or not value.get("textures") is Dictionary:
		return fail("Incomplete visual manifest")
	if value.recipe.get("base_content_id") != base_manifest.get("content_id"):
		return fail("These textures belong to a different base content identity")
	for name in value.textures:
		var row: Variant = value.textures[name]
		if not row is Dictionary or not base_manifest.files.has(name):
			return fail("Unknown source texture")
		if row.get("source_sha256") != base_manifest.files[name].get("sha256"):
			return fail("Source texture provenance mismatch")
		var expected: String = "textures/" + str(name).sha256_text() + ".g2tx"
		if row.get("path") != expected:
			return fail("Invalid normalized texture path")
		if not row.get("bytes") is float and not row.get("bytes") is int:
			return fail("Invalid normalized texture size")
		if row.bytes < 24 or row.bytes > MAX_BYTES:
			return fail("Oversized normalized texture")
	root = directory
	base_content_id = value.recipe.base_content_id
	textures = value.textures
	return true

func load_image(name: String) -> Image:
	error = ""
	if not textures.has(name):
		fail("This texture has not been prepared")
		return null
	var row: Dictionary = textures[name]
	# A changed derivative is read, checked and decoded again.
	var path := root.path_join(row.path)
	var modified := FileAccess.get_modified_time(path)
	var cached: Variant = _decoded.get(name)
	if cached != null:
		_decoded.erase(name)
		if modified != 0 and cached[0] == modified:
			_decoded[name] = cached
			return Image.create_from_data(cached[1], cached[2], cached[3], Image.FORMAT_RGBA8, cached[4])
		_decoded_bytes -= cached[4].size()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(row.bytes):
		fail("Texture derivative is missing or changed")
		return null
	var data := file.get_buffer(int(row.bytes))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(data)
	if hash.finish().hex_encode() != row.get("sha256"):
		fail("Texture derivative checksum mismatch")
		return null
	var image := decode_image(data)
	if image != null and modified != 0:
		var pixels := image.get_data()
		if pixels.size() <= _decoded_limit / 2:
			_decoded[name] = [modified, image.get_width(), image.get_height(), image.has_mipmaps(), pixels]
			_decoded_bytes += pixels.size()
			for oldest in _decoded.keys():
				if _decoded_bytes <= _decoded_limit:
					break
				_decoded_bytes -= _decoded[oldest][4].size()
				_decoded.erase(oldest)
	return image

## One texture of the whole image for callers that draw or crop it unchanged.
## Each panel used to upload its own copy of every interface sheet it cut
## sprites from. Callers that edit pixels take load_image().
func load_texture(name: String) -> ImageTexture:
	error = ""
	var modified := 0
	if textures.has(name):
		modified = FileAccess.get_modified_time(root.path_join(textures[name].path))
	var held: Variant = _shared.get(name)
	if held != null and modified != 0 and held[0] == modified:
		var live: ImageTexture = held[1].get_ref()
		if live != null:
			return live
	var image := load_image(name)
	if image == null:
		return null
	var texture := ImageTexture.create_from_image(image)
	_shared[name] = [modified, weakref(texture)]
	return texture

func decode_image(data: PackedByteArray) -> Image:
	error = ""
	if data.size() < 24 or data.size() > MAX_BYTES or data.slice(0, 4).get_string_from_ascii() != "G2TX":
		fail("Invalid native texture envelope")
		return null
	var version := data.decode_u32(4)
	var width := data.decode_u32(8)
	var height := data.decode_u32(12)
	var levels := data.decode_u32(16)
	var expected := data.decode_u32(20)
	if version != 1 or width < 1 or height < 1 or width > 8192 or height > 8192 or width * height > MAX_PIXELS:
		fail("Unsupported native texture dimensions")
		return null
	if levels < 1 or levels > 14:
		fail("Invalid native mip level count")
		return null
	var size := 0
	var w := width
	var h := height
	for i in levels:
		size += w * h * 4
		if i + 1 < levels and w == 1 and h == 1:
			fail("Too many native mip levels")
			return null
		if i + 1 < levels:
			w = maxi(1, w / 2)
			h = maxi(1, h / 2)
	if size != expected or size > MAX_BYTES or (levels > 1 and (w != 1 or h != 1)):
		fail("Invalid native mip payload extent")
		return null
	var pixels := data.slice(24).decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if pixels.size() != size:
		fail("Native texture decompression failed")
		return null
	return Image.create_from_data(width, height, levels > 1, Image.FORMAT_RGBA8, pixels)

func fail(message: String) -> bool:
	error = message
	return false
