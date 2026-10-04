extends RefCounted
## Original authored contacts and population rules. Services remain separate.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Fonts=preload("res://src/content/font_definitions.gd")
const Layouts=preload("res://src/content/declaration_layouts.gd")
const Ordinary=preload("res://src/content/ordinary_generation_definitions.gd")
const VALUES = {"scope":"persistent_blueprint_lounge_contacts","supported_contact_ids":[5],"station_id":10,"system_id":6,"first_cursor":17,"fields":{"id":0,"station":1,"system":2,"faction":3,"male":4,"role4_parameter":5,"blueprint":6,"role8_parameter":7,"price":8},"male_value":1,"blueprint_role":3,"count":{"minimum":3,"draw_bound":2,"probe_maximum":4,"maximum":5},"portrait":{"family_index":0,"parts_start":1,"part_count":4},"authored_first":true,"authored_order":"table","hostile_replacement_requires_generated":true}
const SPANS = {"persistent_count":[-236767,267],"persistent_loader":[-675370,696],"persistent_constructor":[-720294,434],"persistent_station":[-719568,10],"persistent_system":[-719578,10],"persistent_roster":[-235772,178],"persistent_hostile_replacement":[-235591,387],"persistent_insertion":[-236439,667],"persistent_role_getter":[-719598,10],"persistent_generated_getter":[-719502,14],"persistent_portrait_setter":[-719488,14],"persistent_constructor_wrapper":[-720362,68],"persistent_blueprint_getter":[-718898,10],"persistent_price_getter":[-718660,10]}
const MAC_SPANS = {"persistent_count":[-237787,267],"persistent_loader":[-681258,696],"persistent_constructor":[-726190,434],"persistent_station":[-725464,10],"persistent_system":[-725474,10],"persistent_roster":[-236792,178],"persistent_hostile_replacement":[-236611,387],"persistent_insertion":[-237459,667],"persistent_role_getter":[-725494,10],"persistent_generated_getter":[-725398,14],"persistent_portrait_setter":[-725384,14],"persistent_constructor_wrapper":[-726258,68],"persistent_blueprint_getter":[-724794,10],"persistent_price_getter":[-724556,10]}

static func parameters(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=VALUES.size()+1 or not data.get("provenance") is Dictionary:return false
	for key in VALUES:
		if not Equal.equal_value(data.get(key),VALUES[key]):return false
	return true

static func validate(data: Variant,source_bytes: int,architecture: String,arrival: Dictionary,ordinary_generation: Dictionary) -> String:
	if not data is Dictionary:return "Missing persistent contact declarations"
	if data.is_empty():return ""
	if architecture!="x86_64" or not parameters(data) or not Ordinary.parameters(ordinary_generation):return "Unsupported persistent contact declarations"
	var source: Variant=arrival.get("provenance")
	if not source is Dictionary:return "Persistent contacts lack their source anchor"
	var anchor: Variant=source.get("actor")
	if not Fonts.extent(anchor,"offset","bytes",[315],source_bytes):return "Persistent contacts lack their source anchor"
	return "" if Layouts.matches(data.provenance,int(anchor.offset),source_bytes,[SPANS,MAC_SPANS]) else "Invalid persistent contact extents"

# Additional native locations using the same proved blueprint-contact branch.
# Identity, portrait, offer and price remain in the player's original table.
const BLUEPRINT_LOCATIONS={3:{"system_id":0,"contact_ids":[0]},5:{"system_id":1,"contact_ids":[6]},14:{"system_id":21,"contact_ids":[7]},20:{"system_id":4,"contact_ids":[2]},
	32:{"system_id":2,"contact_ids":[1]},43:{"system_id":8,"contact_ids":[4]},51:{"system_id":10,"contact_ids":[8]},54:{"system_id":10,"contact_ids":[3]},
	59:{"system_id":20,"contact_ids":[10]},78:{"system_id":15,"contact_ids":[11]},90:{"system_id":18,"contact_ids":[9]},
	105:{"system_id":25,"contact_ids":[16]},106:{"system_id":25,"contact_ids":[18]},107:{"system_id":25,"contact_ids":[17]}}

# Authored role-4 contacts retain their terms; purchases remain separate.
const ROLE4_LOCATIONS={18:{"system_id":3,"contact_ids":[12],"parameter":0},26:{"system_id":5,"contact_ids":[13],"parameter":1},65:{"system_id":13,"contact_ids":[14],"parameter":10},
	88:{"system_id":17,"contact_ids":[15],"parameter":21},122:{"system_id":29,"contact_ids":[19],"parameter":32},127:{"system_id":30,"contact_ids":[20],"parameter":33}}

## The Kaamo Club (108): mechanics 21-24 sell ship mods, 25 one special item
## from KAAMO_ITEMS, 26 a ship from KAAMO_SHIPS (only once the club is owned).
const KAAMO_STATION:=108
const KAAMO_ITEM_DEALER:=25
const KAAMO_SHIP_DEALER:=26
const KAAMO_ITEMS:=[200,220,208,213,216,228,229,230,231]
const KAAMO_SHIPS:=[55,56,57,58,59,60]
## Mod price as a percentage of the flown ship's price.
const KAAMO_MOD_PERCENT:=[20,30,40,20]
## Without the (in-app) VIP card the dealers charge double.
const KAAMO_PRICE_FACTOR:=2

static func contact_ids(data: Dictionary,station_id: int,system_id: int) -> Array:
	if not parameters(data):return []
	if station_id==int(data.station_id) and system_id==int(data.system_id):return data.supported_contact_ids
	var location: Dictionary=BLUEPRINT_LOCATIONS.get(station_id,ROLE4_LOCATIONS.get(station_id,{}))
	return location.contact_ids if location.get("system_id",-1)==system_id else []

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and bindings.get("source_architecture")=="x86_64" and parameters(bindings.get("persistent_contacts")) and Ordinary.available(bindings)
