extends RefCounted
## Compares a save written today with an older saved file: fields the file
## predates (newer medal stats, blueprint stations) are ignored, every field
## the file does record must match.
static func matches_older(current: Variant,older: Variant) -> bool:
	if current is Dictionary and older is Dictionary:
		for key in older:
			if not current.has(key) or not matches_older(current[key],older[key]):return false
		return true
	if current is Array and older is Array:
		if current.size()!=older.size():return false
		for index in older.size():
			if not matches_older(current[index],older[index]):return false
		return true
	return current==older
