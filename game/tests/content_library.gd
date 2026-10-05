extends SceneTree
const Library = preload("res://src/content/library.gd")
var failures := 0


func _initialize() -> void:
	var directories := OS.get_cmdline_user_args()
	if directories.is_empty():
		push_error("Supply one or more imported cache directories after --")
		quit(2)
		return
	var identities := {}
	for directory in directories:
		var library := Library.new()
		check(library.open(directory), library.error)
		if library.manifest.is_empty():
			continue
		for code in library.manifest.languages:
			check(library.select_language(code), library.error)
			check(library.strings.size() == Library.catalogue_layout(library.manifest).strings, "Unexpected localization count")
		var malformed: Dictionary = library.manifest.duplicate(true)
		malformed.ship_table.records = 63
		check(Library.catalogue_layout(malformed).is_empty(), "Unknown ship extent accepted")
		malformed = library.manifest.duplicate(true)
		malformed.languages[malformed.languages.keys()[0]].records = 3402 if malformed.profile.edition == "mac-full-hd" else 3385
		check(Library.catalogue_layout(malformed).is_empty(), "Another edition's language extent accepted")
		malformed = library.manifest.duplicate(true)
		malformed.files["resources/data/bin/ships.bin"].bytes += 36
		check(Library.catalogue_layout(malformed).is_empty(), "Ship byte extent disagrees with its catalogue")
		check(library.save_directory().contains(library.manifest.content_id), "Save identity is missing")
		check(not identities.has(library.save_directory()), "Different bases share a save namespace")
		identities[library.save_directory()] = true
		check_verified_reads(library, directory)
		check(not library.select_language("absent"), "Missing language accepted")
		check(library.strings.is_empty(), "Failed language change retained stale strings")
		check(not library.open("relative/path"), "Relative cache path accepted")
		check(library.manifest.is_empty(), "Failed content change retained stale manifest")
	print("Native content checks: %d profiles; %d failures" % [directories.size(), failures])
	quit(1 if failures else 0)


## A second read returns the verified bytes again: the caller's own copy, within
## the reader's budget, and only while the file on disk is unchanged.
func check_verified_reads(library: RefCounted, directory: String) -> void:
	var name := "resources/data/bin/ships.bin"
	var first: PackedByteArray = library.read_resource(name, 1 << 20)
	check(not first.is_empty(), library.error)
	var kept: PackedByteArray = first.duplicate()
	first[0] ^= 255
	var second: PackedByteArray = library.read_resource(name, 1 << 20)
	check(second == kept, "A caller's edit reached the next reader of the resource")
	second[0] ^= 255
	check(library.read_resource(name, 1 << 20) == kept, "An edit of the verified copy reached the next reader of the resource")
	check(library.read_resource(name, 8).is_empty(), "A verified resource ignored its reader budget")
	var read := 0
	for other in library.manifest.files:
		if read > 2 * Library.MAX_CACHED_RESOURCES:
			break
		var size := int(library.manifest.files[other].bytes)
		if size > 0 and size <= Library.MAX_CACHED_RESOURCES / 2 and other.begins_with("resources/"):
			read += library.read_resource(other, size).size()
	var held := 0
	for entry in library._verified.values():
		held += entry[1].size()
	check(read > Library.MAX_CACHED_RESOURCES and held == library._verified_bytes and held <= Library.MAX_CACHED_RESOURCES, "Verified resources outgrew their budget")
	check(library.read_resource(name, 1 << 20) == kept, "A resource changed after it left the verified copies")
	# A private copy of the manifest and this one file; then the file changes.
	var copy := OS.get_user_data_dir().path_join("library-check")
	DirAccess.make_dir_recursive_absolute(copy.path_join(name.get_base_dir()))
	DirAccess.copy_absolute(directory.path_join("manifest.json"), copy.path_join("manifest.json"))
	DirAccess.copy_absolute(directory.path_join(name), copy.path_join(name))
	var private := Library.new()
	check(private.open(copy) and private.read_resource(name, 1 << 20) == kept, private.error)
	var stamp := FileAccess.get_modified_time(copy.path_join(name))
	var changed: PackedByteArray = kept.duplicate()
	changed[0] ^= 255
	# Modification times count whole seconds.
	while FileAccess.get_modified_time(copy.path_join(name)) == stamp:
		OS.delay_msec(100)
		var file := FileAccess.open(copy.path_join(name), FileAccess.WRITE)
		file.store_buffer(changed)
		file.close()
	check(private.read_resource(name, 1 << 20).is_empty() and private.error == "Resource checksum mismatch", "A changed resource was served from its verified copy")
	var restored := FileAccess.open(copy.path_join(name), FileAccess.WRITE)
	restored.store_buffer(kept)
	restored.close()
	check(private.read_resource(name, 1 << 20) == kept, "A restored resource was refused: " + private.error)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
