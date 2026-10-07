extends SceneTree
const Library = preload("res://src/content/library.gd")
const VisualLibrary = preload("res://src/content/visual_library.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Supply base and visual directories")
		quit(2)
		return
	var library := Library.new()
	var visuals := VisualLibrary.new()
	if not library.open(args[0]) or not visuals.open(args[1], library.manifest):
		push_error(library.error + visuals.error)
		quit(1)
		return
	var errors: Array = []
	var levels := 0
	for name in visuals.textures:
		var image := visuals.load_image(name)
		if image == null:
			errors.append({"path": name, "error": visuals.error})
		else:
			levels += image.get_mipmap_count() + 1
	# Decoded pixels are kept for the next request: every image is its own, the
	# pixels are the same, and the kept pixels stay within their budget.
	var held := 0
	for entry in visuals._decoded.values():
		held += entry[4].size()
	if held != visuals._decoded_bytes or held > visuals._decoded_limit or visuals._decoded.is_empty():
		errors.append({"error": "Decoded textures outgrew their budget"})
	for name in visuals._decoded.keys().slice(-3):
		var first := visuals.load_image(name)
		var pixels := first.get_data()
		first.fill(Color.RED)
		var second := visuals.load_image(name)
		if is_same(first, second) or second.get_data() != pixels or second.get_size() != first.get_size() or second.has_mipmaps() != first.has_mipmaps():
			errors.append({"path": name, "error": "An edited image reached the next request for its texture"})
	# A batch decodes on the worker threads what single requests decode here:
	# the same images, each name once, and nothing for an unknown texture.
	var batch: Array = visuals.textures.keys().slice(0, 24)
	visuals._decoded.clear()
	visuals._decoded_bytes = 0
	var together: Dictionary = visuals.load_images(batch + batch.slice(0, 3) + ["resources/absent.aei"])
	if together.size() != batch.size():
		errors.append({"error": "A batch of textures lost or invented entries"})
	for name in together:
		var alone := visuals.load_image(name)
		var image: Image = together[name]
		if alone == null or image.get_data() != alone.get_data() or image.get_size() != alone.get_size() or image.has_mipmaps() != alone.has_mipmaps():
			errors.append({"path": name, "error": "A texture decoded in a batch differs from the same texture decoded alone"})
	print(JSON.stringify({"edition": library.manifest.profile.edition, "textures": visuals.textures.size(),
		"decoded_levels": levels, "errors": errors}, "  "))
	quit(0 if errors.is_empty() else 1)
