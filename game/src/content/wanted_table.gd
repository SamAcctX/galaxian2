extends RefCounted
## The expansion's Most Wanted list (resources/data/bin/wanted.bin): 25
## big-endian records, no header. Each: name, 13 integers, portrait parts.
const Cursor = preload("res://src/content/binary_cursor.gd")
const RESOURCE := "resources/data/bin/wanted.bin"
const COUNT := 25
const FIELDS := ["index", "board", "race", "male", "ship", "weapon", "hull", "loot_item",
	"loot_amount", "reward", "required_bounties", "required_mission", "wingmen"]

## Rows, or [] (and `error`) when the file is malformed. Packs without the
## file (no expansion) simply have no list.
static func decode(bytes: PackedByteArray) -> Array:
	var cursor := Cursor.new(bytes)
	var rows := []
	for i in COUNT:
		var row := {"name": cursor.be_string(256)}
		var values := cursor.be_ints(FIELDS.size())
		if values.size() != FIELDS.size():
			return []
		for field in FIELDS.size():
			row[FIELDS[field]] = values[field]
		var parts := cursor.be_i32()
		if parts < 0 or parts > 16:
			return []
		row.portrait = []
		for part in parts:
			var value := cursor.u8()
			row.portrait.append(value - 256 if value > 127 else value)
		if not cursor.error.is_empty() or row.index != i or row.board < 0 or row.board > 3 or row.hull < 0 or row.reward < 0:
			return []
		rows.append(row)
	return rows if cursor.remaining() == 0 else []
