extends SceneTree
const Definitions = preload("res://src/content/font_definitions.gd")
const Fixture = preload("res://tests/font_fixture.gd")
var failures := 0
func _initialize() -> void:
	var data := Fixture.definition("baseline", "middle", "large")
	check(Definitions.parameters(data), "Synthetic font declarations rejected")
	var a := Definitions.choice(data, "aa", 0)
	check(a.font_id == 500 and a.resource == "baseline" and a.font_group == 0 and a.spacing == -2, "Default font choice changed")
	a = Definitions.choice(data, "ak", 1)
	check(a.font_id == 504 and a.resource == "middle" and a.language_id == 10 and a.spacing == -5, "Language-specific medium font changed")
	a = Definitions.choice(data, "ap", 3)
	check(a.font_id == 507 and a.resource == "large" and a.spacing == -7, "Japanese large mode changed")
	a = Definitions.choice(data, "ap", 2)
	check(a.resource == "baseline" and a.spacing == -5, "Wide mode must use its source baseline atlas")
	a = Definitions.choice(data, "ap", 3, "secondary")
	check(a.font_id == 501 and a.font_group == 1 and a.spacing == 0, "Secondary font must use its own group and spacing")
	a = Definitions.choice(data, "ak", 0, "language_list")
	check(a.font_id == 502 and a.spacing == 0, "Language list font changed")
	for mode in [-1, 4]: check(Definitions.choice(data, "aa", mode).is_empty(), "Invalid mode accepted")
	check(Definitions.choice(data, "zz", 0).is_empty() and Definitions.choice(data, "aa", 0, "bad").is_empty(), "Unknown language/role guessed")
	var alias := data.duplicate(true)
	alias.languages.rows[0].file = "zz.lang"
	check(Definitions.choice(alias, "aa", 0).is_empty() and Definitions.choice(alias, "zz", 0).font_id == 500, "Language was guessed from numeric ID")
	for mutation in ["font", "language", "spacing", "variants"]:
		var bad := data.duplicate(true)
		match mutation:
			"font": bad.records[1].id = bad.records[0].id
			"language": bad.languages.rows[2].file = bad.languages.rows[1].file
			"spacing": bad.selection.spacing.default[0] = 0.5
			"variants": bad.textures.rows[0].variants.large = bad.textures.rows[0].variants.baseline
		check(not Definitions.parameters(bad) and Definitions.choice(bad, "aa", 0).is_empty(), "Malformed font choice accepted: " + mutation)
	# Android loads language 0's file for languages 10 and 11; language 0 keeps its font.
	var fallback := data.duplicate(true)
	for i in [10, 11]: fallback.languages.rows[i].file = fallback.languages.rows[0].file
	check(Definitions.parameters(fallback) and Definitions.choice(fallback, "aa", 0).language_id == 0, "Android fallback language rows rejected or chosen over language 0")
	var registrations := {17: []}
	for mode in ["baseline", "medium", "large"]:
		registrations[17].append({"kind": "texture", "registration_type": 2, "resource": data.textures.rows[0].variants[mode], "source_offset": data.textures.rows[0].source_offsets[mode]})
	var android := android_extents(data)
	check(Definitions.validate(data, 4096, "x86_64", registrations).is_empty() and Definitions.validate(android, 4096, "android-armv7", registrations).is_empty(), "Source font extents rejected")
	check(not Definitions.validate(android, 4096, "x86_64", registrations).is_empty() and not Definitions.validate(data, 4096, "android-armv7", registrations).is_empty(), "Font extents accepted for another compiler")
	check(Definitions.validate(android_extents(fallback), 4096, "android-armv7", registrations).is_empty() and not Definitions.validate(fallback, 4096, "x86_64", registrations).is_empty(), "Language fallback accepted outside Android")
	print("Font selection checks: %d failures" % failures)
	quit(1 if failures else 0)
func android_extents(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	for row in data.records: row.source_bytes = 4
	for row in data.languages.rows: row.source_bytes = 12
	data.languages.provenance = {"dispatch": {"offset": 0, "bytes": 10}, "table": {"offset": 50, "bytes": 32}}
	data.selection.source_bytes = 626
	data.textures.provenance = {"medium": {"offset": 20, "bytes": 16}, "large": {"offset": 160, "bytes": 26}}
	return data
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
