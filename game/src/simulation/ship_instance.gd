extends RefCounted
## Persistent hull properties. Installed equipment and cargo keep their own
## owners; a market quote never includes their value.
const Numbers=preload("res://src/content/opening_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=3 or not Numbers.integer(data.get("unit_price"),0,2147483647) or not Numbers.integer(data.get("faction_id"),0,9):return false
	var tags: Variant=data.get("upgrade_tags")
	return tags is Array and tags.size()<=4096 and tags.all(func(tag):return Numbers.integer(tag,0,2147483647))

static func from_inventory(bindings: RefCounted,cat: RefCounted,inventory: Dictionary) -> Dictionary:
	var seed: Dictionary=inventory.get("loadout",{})
	if seed.has("ship_instance"):
		return seed.ship_instance.duplicate(true) if valid(seed.ship_instance) else {}
	# Earlier native saves have the earned affiliation but no instance quote.
	# Initialize only missing state; opening the Hangar performs local repricing.
	if not Numbers.integer(seed.get("ship_id"),0,cat.tables.ships.size()-1):return {}
	var affiliations: Array=bindings.early_contracts.get("base_station_stock",{}).get("ships",{}).get("affiliations",[])
	if int(seed.ship_id)>=affiliations.size():return {}
	var faction: Variant=inventory.get("ship_affiliation",int(affiliations[int(seed.ship_id)]))
	var result:={"unit_price":int(Vitals.single(float(cat.tables.ships[int(seed.ship_id)].stats.base_price)/1.25)),"faction_id":faction,"upgrade_tags":[]}
	return result if valid(result) else {}

static func from_offer(offer: Dictionary) -> Dictionary:
	return {"unit_price":offer.unit_price,"faction_id":offer.faction_id,"upgrade_tags":offer.get("upgrade_tags",[]).duplicate()}

static func valid_offers(offers: Variant,cat: RefCounted) -> bool:
	if not offers is Array or offers.size()>128:return false
	for row in offers:
		if not row is Dictionary or row.size()!=3+int(row.has("upgrade_tags")) or not Numbers.integer(row.get("ship_id"),0,cat.tables.ships.size()-1):return false
		if not row.has("unit_price") or not row.has("faction_id") or (row.has("upgrade_tags") and not row.upgrade_tags is Array):return false
		if not valid(from_offer(row)):return false
	return true

static func upgrades(seed: Dictionary) -> Array:
	return seed.get("ship_instance",{}).get("upgrade_tags",[])
