extends RefCounted
## Retained hiring terms, independent of the player's freelance contract slot.
const Numbers=preload("res://src/content/opening_definitions.gd")
const DURATION_MS:=600000
const ACTIVE_KEYS:=["station_id","contact_id","names","faction","portrait","price","remaining_ms"]

static func offer(contact: Dictionary,station_id: int,bindings: RefCounted) -> Dictionary:
	if contact.get("role")!=6 or not contact.get("roster") is Dictionary:return {}
	if not contact.roster.get("extra_names") is Array or not contact.get("portrait") is Dictionary:return {}
	var names: Array=[contact.get("name")]
	names.append_array(contact.roster.extra_names)
	var active:={"station_id":station_id,"contact_id":contact.get("contact_id"),
		"names":names,"faction":contact.get("faction"),"portrait":contact.portrait.duplicate(true),
		"price":contact.roster.get("price"),"remaining_ms":DURATION_MS}
	return active if valid_active(active,bindings) else {}

static func valid_state(value: Variant,bindings: RefCounted) -> bool:
	if not value is Dictionary or value.size()!=2 or not value.get("hired_total") is int or not value.get("active") is Dictionary:return false
	if not Numbers.integer(value.hired_total,0,2147483647):return false
	return value.active.is_empty() or (valid_active(value.active,bindings) and value.hired_total>=value.active.names.size())

static func valid_active(value: Variant,bindings: RefCounted) -> bool:
	if bindings==null or not value is Dictionary or value.size()!=ACTIVE_KEYS.size():return false
	for key in ACTIVE_KEYS:
		if not value.has(key):return false
	for key in ["station_id","contact_id","faction","price","remaining_ms"]:
		if not value[key] is int:return false
	var faction_count:=int(bindings.early_contracts.generation.identity.faction_bound)
	if not Numbers.integer(value.station_id,0,2147483647) or not Numbers.integer(value.contact_id,0,4095) or not Numbers.integer(value.faction,0,faction_count-1):return false
	if not Numbers.integer(value.price,1,2147483647) or not Numbers.integer(value.remaining_ms,0,DURATION_MS):return false
	if not value.names is Array or value.names.is_empty() or value.names.size()>3:return false
	for pilot in value.names:
		if not pilot is String or pilot.is_empty() or pilot.length()>1024:return false
	var portrait: Variant=value.portrait
	if not portrait is Dictionary or portrait.size()!=3 or portrait.get("status")!="fixed" or not portrait.get("family") is int or not portrait.get("parts") is Array:return false
	var counts: Array=bindings.early_contracts.get("generation",{}).get("portraits",{}).get("counts",[])
	if not Numbers.integer(portrait.family,0,counts.size()-1):return false
	var limits: Array=counts[portrait.family]
	if portrait.parts.size()!=limits.size():return false
	for index in limits.size():
		if not portrait.parts[index] is int or not Numbers.integer(portrait.parts[index],0,int(limits[index])-1):return false
	return true
