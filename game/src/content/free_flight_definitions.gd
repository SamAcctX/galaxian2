extends RefCounted
const StoryFlights=preload("res://src/content/valkyrie_flight_definitions.gd")
## Shared ordinary-entry rules. The station owner authorizes actual departure.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Campaign=preload("res://src/content/free_campaign_definitions.gd")
const Life=preload("res://src/content/free_lifecycle_definitions.gd")
const Worlds=preload("res://src/content/ordinary_world_definitions.gd")
const VALUES = {"scope":"augmenta_ordinary_entry","campaign_cursor":18,"initial_station_id":98,"system_id":19,"departure_flags":{"special_arrival":false,"void_encounter":false},"special_confirmation_cursor":48,"launch_clear_after_ms":7000,"launch_clear_strict":true}
const SPANS = {"free_flight_convoy_clear":[155626,87],"free_flight_scene_clear":[134971,325],"free_flight_confirmation":[431803,192],"free_flight_launch_clear":[151066,205],"free_flight_ordinary_dispatch":[152236,50]}

# Native composition.
const MAC_SPANS = {"free_flight_convoy_clear":[155626,87],"free_flight_scene_clear":[134971,325],"free_flight_confirmation":[432231,192],"free_flight_launch_clear":[151066,205],"free_flight_ordinary_dispatch":[152236,50]}

static func parameters(data: Variant) -> bool:return Equal.equal_value(data,VALUES)

static func available(bindings: RefCounted) -> bool:
	return Life.available(bindings) and parameters(bindings.mido_travel.get("free_flight"))

static func player_entry(source: Variant,station_id: int,ship_id: int,cursor: int=18) -> Dictionary:
	var travel:=Campaign.source_travel(source)
	if not parameters(travel.get("free_flight")) or not load("res://src/content/mido_travel_definitions.gd").parameters(travel) or ship_id<0 or not Campaign.supported(source,cursor):return {}
	# Cursor36 may still depart Ga'kkrr as an ordinary free flight, but its
	# mission target is the authored B'akka contest. Do not let generic entry or
	# cache helpers manufacture that target before the contest capability exists.
	var story: Dictionary=Campaign.mission(source,cursor)
	if cursor==36 and station_id==int(story.get("station_id",-1)) and not load("res://src/content/bakka_contest_definitions.gd").parameters(travel.get("bakka_contest")):return {}
	# Eanya's ordinary world support must not turn its pending convoy target
	# into a generic player/cache entry, even when that story is only declared
	# by the preceding pack. The authored arrival has its own retained adapter.
	# A Valkyrie combat flight is a story job the contract runner builds here.
	if story.get("kind") in [1,4] and station_id==int(story.get("station_id",-1)) and not (source is RefCounted and not StoryFlights.story_job(source,cursor,station_id).is_empty()):return {}
	var world:=Worlds.location(source,station_id)
	if world.is_empty():return {}
	var result: Dictionary=travel.player_entry.duplicate(true)
	result.campaign_cursor=cursor;result.system_id=int(world.system_id)
	result.station_id=station_id;result.ship_id=ship_id
	return result

static func flight(bindings: RefCounted,station_id: int,cursor: int=18) -> Dictionary:
	if not available(bindings) or player_entry(bindings,station_id,0,cursor).is_empty():return {}
	var result: Dictionary=bindings.first_flight.duplicate(true)
	result.scope="augmenta_ordinary_flight";result.campaign_cursor=cursor
	result.station_id=station_id;result.system_id=int(Worlds.location(bindings,station_id).system_id);result.mission_kind=-1
	if result.system_id!=19:result.scope="ordinary_flight"
	result.erase("actor_count")
	return result

static func response_flags(bindings: RefCounted,flags: Variant) -> bool:
	if not available(bindings) or not flags is Dictionary:return false
	var bound:=int(bindings.early_contracts.base_navigation.global_station_bound)
	for station in flags:
		if not station is int or station<0 or station>=bound or not flags[station] is bool:return false
	return true

static func ordinary_entry(bindings: RefCounted,entry: Dictionary) -> bool:
	if not available(bindings) or not Campaign.supported(bindings,entry.get("campaign_cursor")):return false
	if entry.get("mission_track")=="side_job":
		return entry.get("departure",{}).get("contract_context")==entry.get("scenery",{}).get("world_initialization",{}).get("contract_context")
	var context: Variant=entry.get("departure",{}).get("free_context")
	if not context is Dictionary or not Life.Traffic.context_valid(bindings,context):return false
	if context.campaign_cursor!=entry.campaign_cursor:return false
	return entry.get("scenery",{}).get("world_initialization",{}).get("npc_construction",{}).get("free_context")==context

static func docking(bindings: RefCounted,station_id: int,cursor: int=18) -> Dictionary:
	if flight(bindings,station_id,cursor).is_empty() or not load("res://src/content/station_return_definitions.gd").parameters(bindings.station_return):return {}
	return _docking_values(station_id,int(Worlds.location(bindings,station_id).system_id),cursor)

static func _docking_values(station_id: int,system_id: int=19,cursor: int=18) -> Dictionary:
	var result: Dictionary=load("res://src/content/contract_world_definitions.gd")._docking_values(station_id,cursor)
	result.scope="augmenta_ordinary_station" if system_id==19 else "ordinary_station";result.system_id=system_id
	return result

static func docking_parameters(data: Dictionary) -> bool:
	var system: Variant=data.get("system_id")
	# The shared world entry already admits the catalogue location. Docking
	# validates its rule shape without maintaining a second destination list.
	return data.get("campaign_cursor") is int and data.campaign_cursor>=0 and system is int and system>=0 and data.get("station_id") is int and data.station_id>=0 and Equal.equal_value(data,_docking_values(data.station_id,system,int(data.get("campaign_cursor",-1))))
