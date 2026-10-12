extends RefCounted

static func definition(mac := true, android := false) -> Dictionary:
	var size := 4 if android else 68 if mac else 94
	return {"records": [
		{"id": 200, "texture_id": 600, "region": 3, "source_offset": 100, "source_bytes": size},
		{"id": 200, "texture_id": 601, "region": 4, "source_offset": 200, "source_bytes": size},
		{"id": 202, "texture_id": 601, "region": 7, "source_offset": 300, "source_bytes": size}],
		"ranges": [{"first_id": 500, "first_texture_id": 900, "count": 3, "region": 0, "source_offset": 1000, "source_bytes": 82 if android else 106 if mac else 128}]}
