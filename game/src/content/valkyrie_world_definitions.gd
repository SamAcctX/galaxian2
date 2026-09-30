extends RefCounted
## Valkyrie's special locations: stations with their own assemblies and orbits
## that have no station at all.
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")
## Station exterior layers (hull, emissive, additive) for stations that do not
## use their station-ID meshes: Kothar's research station and the Valkyrie base.
const STATION_MODELS:={100:[16931,16932,16933],101:[16928,16929,16930]}
## Orbits without a station while their story is active.
const EMPTY_ORBITS:=[102,103,104]
## The Valkyrie base is destroyed once its story is over.
const DESTROYED_AFTER:={101:83}

static func station_models(bindings: RefCounted,station_id: int) -> Array:
	if not Valkyrie.available(bindings) or not STATION_MODELS.has(station_id):return []
	return STATION_MODELS[station_id].duplicate()

static func empty_orbit(station_id: int,cursor: int) -> bool:
	return station_id in EMPTY_ORBITS or (DESTROYED_AFTER.has(station_id) and cursor>int(DESTROYED_AFTER[station_id]))

## Station markets that differ from the ordinary generator. Items: "weapons"
## (weapons only), "weapons_or_subtype" (weapons plus one subtype), "category"
## (one category), "goods_list" (commodities from a list plus every system's
## goods), "none". A "ships" list replaces the random shipyard.
const STOCK:={
	101:{"items":"weapons","ships":[]},
	105:{"items":"weapons_or_subtype","subtype":28,"low_tech":false},
	106:{"items":"goods_list","list":[101,102,103,107,108,109,114,124,0],"category":4},
	107:{"items":"category","category":3,"low_tech":false,"ships":[2,11,23,24,25,32,48,60]},
	108:{"items":"none","ships":[]},
}
const WEAPON_CATEGORIES:=[0,1,2]

static func stock_station(bindings: RefCounted,station_id: int) -> bool:
	return load("res://src/content/ordinary_world_definitions.gd").location(bindings,station_id).get("expansion",false)

static func stock_rules(station_id: int) -> Dictionary:
	return STOCK.get(station_id,{}).duplicate(true)
