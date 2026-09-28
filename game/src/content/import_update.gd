extends RefCounted
## A newer extraction may add declarations from the same original executable.
## Earlier declarations must remain identical; installed packs are immutable.
const Equal=preload("res://src/content/opening_escape_definitions.gd")

static func compatible(parent: Dictionary,previous: Dictionary,header: Dictionary,current: Dictionary) -> bool:
	for key in ["base_content_id","source_executable_sha256","architecture"]:
		if parent.get(key)!=header.get(key):return false
	for key in previous:
		if key in ["reader","diagnostics"]:continue
		if not current.has(key):return false
		if key=="registrations":
			if not previous[key] is Array or not current[key] is Array:return false
			var rows:={}
			for row in current[key]:rows[JSON.stringify(row)]=true
			for row in previous[key]:
				if not rows.has(JSON.stringify(row)):return false
		elif not contains(previous[key],current[key]):return false
	return true

static func contains(previous: Variant,current: Variant) -> bool:
	if previous is Dictionary:
		if not current is Dictionary:return false
		for key in previous:
			if not current.has(key) or not contains(previous[key],current[key]):return false
		return true
	return Equal.equal_value(previous,current)
