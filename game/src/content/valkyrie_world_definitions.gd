extends RefCounted
## Valkyrie's special locations: stations with their own assemblies and orbits
## that have no station at all.
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")
## Station exterior layers (hull, emissive, additive) for stations that do not
## use their station-ID meshes: Kothar's research station and the Valkyrie base.
const STATION_MODELS:={100:[16931,16932,16933],101:[16928,16929,16930]}
## Orbits without a station while their story is active.
const EMPTY_ORBITS:=[102,103,104,109,110]
## The Valkyrie base is destroyed once its story is over.
const DESTROYED_AFTER:={101:83,111:93}

static func station_models(bindings: RefCounted,station_id: int) -> Array:
	if not Valkyrie.available(bindings) or not STATION_MODELS.has(station_id):return []
	return STATION_MODELS[station_id].duplicate()

## Star-map planet sizes past the imported 22: the App Store table goes on
## 256, 0, 256, 256 for types 22-25 (Talidor and Ginoya planets).
const MAP_PLANET_SIZES:=[256,0,256,256]
static func map_planet_sizes(bindings: RefCounted,imported: Array) -> Array:
	if not Valkyrie.available(bindings) or imported.size()!=22:return imported
	return imported+MAP_PLANET_SIZES

## Star-map sun textures past the imported 16 (sky textures 16-18), and
## Ginoya's map sun, which is always texture 10036 (verified initStarSystem).
const MAP_SUN_TEXTURES:=[10038,10033,10037]
const GINOYA_MAP_SUN:=10036
static func map_sun_texture(bindings: RefCounted,imported: Array,system_id: int,sky_index: int) -> int:
	var known: Array=imported+MAP_SUN_TEXTURES if Valkyrie.available(bindings) and imported.size()==16 else imported
	if Valkyrie.available(bindings) and system_id==int(SUPERNOVA.system_id):return GINOYA_MAP_SUN
	return int(known[sky_index]) if sky_index>=0 and sky_index<known.size() else -1

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
	100:{"ships":[37,38,40],"from_cursor":84},
	111:{"items":"none","ships":[],"until_cursor":157},
	112:{"items":"none","ships":[],"until_cursor":157},
	113:{"items":"none","ships":[],"until_cursor":157},
}
const WEAPON_CATEGORIES:=[0,1,2]

## Ginoya's supernova (verified Level::createSpace, Level::update,
## Status::getGammaRayDamagePerSecond). While the cursor is below 158 Ginoya
## uses sky 15 plus two overlay meshes (texture 10084, 10085 from 106); at 89
## the pre-supernova sky (mesh 17805, texture 10070). The sun grows 1.37x after
## the 89 blast.
const SUPERNOVA:={"system_id":27,"until_cursor":157,"intro_cursor":89,"intro_sky":[17805,10070],
	"sky":[17815,10080],"overlay_meshes":[17824,17825],"overlay_textures":[[105,10084],[158,10085]],"sun_scale":1.37}
## Gamma loss per second in each Ginoya orbit: [[from cursor, rate], ...]
## (the last band whose cursor is reached applies). A fitted gamma shield
## (sort 38) cuts it by its attribute-52 percentage. Below 15 a HUD warning;
## at 0 the ship is destroyed. Gamma starts at 100 in every flight whose
## orbit has no radiation; story moves keep it.
const GAMMA_RATES:={109:[[0,0.7],[106,3.0],[158,1.0]],110:[[0,0.4],[106,2.0],[158,0.0]],
	111:[[0,0.4],[106,1.0],[158,0.0]],112:[[0,0.3],[106,0.5],[158,0.0]],113:[[0,0.2],[106,0.3],[158,0.0]]}
const GAMMA_SHIELD_SORT:=38
const GAMMA_SHIELD_ATTRIBUTE:=52
const GAMMA_WARNING:=15
const GAMMA_NOTICE:=44

static func gamma_rate(station_id: int,cursor: int) -> float:
	var rate:=0.0
	for band in GAMMA_RATES.get(station_id,[]):
		if cursor>=int(band[0]):rate=float(band[1])
	return rate

## Once Valkyrie is won (cursor above 83) and owned, Vossk stations may also
## sell the S'Kanarr (39) and ship 41, each on a 1-in-2 draw.
const WON_SHIPS:={"after_cursor":83,"faction":1,"draw_bound":2,"ships":[[39,1],[41,1]]}

static func stock_station(bindings: RefCounted,station_id: int) -> bool:
	return load("res://src/content/ordinary_world_definitions.gd").location(bindings,station_id).get("expansion",false)

## A rule with "from_cursor" applies only from that campaign cursor on.
static func stock_rules(station_id: int,cursor: int=-1) -> Dictionary:
	var rules: Dictionary=STOCK.get(station_id,{}).duplicate(true)
	if cursor<int(rules.get("from_cursor",-1)) or (cursor>=0 and cursor>int(rules.get("until_cursor",cursor))):return {}
	rules.erase("from_cursor");rules.erase("until_cursor")
	return rules
