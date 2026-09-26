extends RefCounted
## Resolve supported encounter entry differences from validated content.
## Shared player initialization consumes these rules without campaign switches.
const Departure=preload("res://src/content/station_departure_definitions.gd")
const FullHold=preload("res://src/content/full_hold_departure_definitions.gd")
const Pirate=preload("res://src/content/full_hold_pirate_definitions.gd")
const Training=preload("res://src/content/combat_training_weapon_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Alioth=preload("res://src/content/alioth_lifecycle_definitions.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const Sahi=preload("res://src/content/sahi_encounter_definitions.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
const FlightStages=preload("res://src/content/flight_stages.gd")
const KINDS={0:"opening",1:"arrival",2:"mining",4:"full_hold",7:"training",10:"local",11:"local",12:"local",13:"local",14:"convoy",16:"alioth",21:"kappa"}
var error:=""
var cursor:=-1
var is_arrival:=false
var is_departure:=false
var uses_equipment:=false
var restores_local:=false
var equipped_entry:={}
var _kind:=""
var _departure:={}
var _training:={}
var _pirate:={}
var _travel:={}

func configure(bindings: RefCounted, value: int, station_id: int=-1, restoring_local:=false,ship_id: int=-1) -> bool:
	error="";cursor=-1;is_arrival=false;is_departure=false;uses_equipment=false
	equipped_entry={};_kind="";_departure={};_training={};_pirate={};_travel={};restores_local=false
	if bindings==null or (not KINDS.has(value) and not FreeFlight.Campaign.supported(bindings,value) and value not in FlightStages.POST_SAHI and not (value==33 and station_id==-1)):return reject("Unsupported player entry")
	var kind: String="ordinary_void" if value==33 and station_id==-1 else "post_sahi" if value in FlightStages.POST_SAHI else KINDS.get(value,"free")
	if value==21 and FreeFlight.Campaign.supported(bindings.mido_travel,value) and not FreeFlight.Campaign.rescue_at(bindings.mido_travel,value,station_id):kind="free"
	if value==14 and Travel.navigation_available(bindings.mido_travel,value):kind="local"
	if value in [24,28] and Cache.sahi_entry(bindings.mido_travel,ship_id,value).get("station_id")==station_id:kind="sahi"
	var departure:=kind in ["mining","full_hold","training"]
	if departure and not Departure.parameters(bindings.station_departure):return reject("This profile has no supported first departure")
	if kind=="full_hold" and (not FullHold.parameters(bindings.full_hold_departure) or not FullHold.StationReturn.parameters(bindings.station_return)):return reject("This profile has no supported second mining departure")
	if kind=="training" and not Training.parameters(bindings.combat_training_weapons):return reject("This profile has no supported equipped training entry")
	if kind=="alioth":
		if not Alioth.available(bindings) or station_id!=int(bindings.mido_travel.alioth_attack.station_id) or restoring_local:return reject("Alioth requires its docked equipment and source encounter")
		_travel=bindings.mido_travel.duplicate(true)
		equipped_entry=Cache.alioth_entry(_travel)
		departure=true
	if kind=="kappa":
		if not load("res://src/content/kappa_lifecycle_definitions.gd").available(bindings):return reject("Kappa requires its retained equipment and source encounter")
		equipped_entry=Cache.kappa_entry(bindings.mido_travel)
		if equipped_entry.is_empty() or station_id!=int(equipped_entry.station_id) or ship_id!=int(equipped_entry.ship_id):return reject("Kappa player entry differs from its supported ship or location")
		_travel=bindings.mido_travel.duplicate(true);departure=not restoring_local;restores_local=restoring_local
	if kind=="sahi":
		_travel=bindings.mido_travel.duplicate(true)
		equipped_entry=Cache.sahi_entry(_travel,ship_id,value)
		if equipped_entry.is_empty() or station_id!=int(equipped_entry.station_id):return reject("Sahi player entry requires its selected equipped location")
		departure=not restoring_local;restores_local=restoring_local
	if kind=="post_sahi":
		equipped_entry=Cache.post_sahi_entry(bindings.mido_travel,value,ship_id)
		if equipped_entry.is_empty() or station_id!=int(equipped_entry.station_id):return reject("The post-Sahi player entry differs from its source world")
		_travel=bindings.mido_travel.duplicate(true);departure=not restoring_local;restores_local=restoring_local
	if kind=="ordinary_void":
		equipped_entry=Cache.ordinary_void_entry(bindings.mido_travel,ship_id)
		if equipped_entry.is_empty() or not restoring_local:return reject("The ordinary Void player requires its retained portal arrival")
		_travel=bindings.mido_travel.duplicate(true);departure=false;restores_local=true
	if kind=="free":
		if not FreeFlight.available(bindings):return reject("Ordinary player entry is unavailable")
		equipped_entry=FreeFlight.player_entry(bindings,station_id,ship_id,value)
		if equipped_entry.is_empty():return reject("Ordinary player entry requires its equipped location")
		_travel=bindings.mido_travel.duplicate(true);departure=not restoring_local;restores_local=restoring_local
	if kind in ["local","convoy"]:
		equipped_entry=Travel.player_entry(bindings.mido_travel,station_id,value)
		if equipped_entry.is_empty():return reject("This profile has no supported equipped local entry")
		_travel=bindings.mido_travel.duplicate(true)
		departure=true if kind=="convoy" else (not restoring_local if Travel.navigation_available(_travel,value) else station_id==int(Travel.journey(_travel,value).from_station_id))
		if kind=="convoy" and restoring_local:return reject("The capture encounter starts from its docked equipment")
		restores_local=not departure
	cursor=value;_kind=kind;is_arrival=kind=="arrival";is_departure=departure;uses_equipment=kind=="training"
	if departure:_departure=(bindings.full_hold_departure if kind=="full_hold" else bindings.station_departure).duplicate(true)
	if uses_equipment:
		_training=bindings.combat_training_weapons.duplicate(true)
		equipped_entry=_training.player_entry.duplicate(true)
	if kind in ["local","convoy","alioth","free","kappa","sahi","post_sahi","ordinary_void"]:uses_equipment=true
	if kind=="full_hold":_pirate=bindings.full_hold_pirate.duplicate(true)
	return true

## Explicit native story selection, not an extension of generic free entry.
## The player adapter requires an actual surviving cache for this arrival.
func configure_dekato(bindings: RefCounted,context: Dictionary,ship_id: int) -> bool:
	error="";cursor=-1;is_arrival=false;is_departure=false;uses_equipment=false
	equipped_entry={};_kind="";_departure={};_training={};_pirate={};_travel={};restores_local=false
	if not load("res://src/content/dekato_convoy_definitions.gd").context_valid(bindings,context) or ship_id<0:return reject("Dekato player entry requires the selected source context and ship")
	equipped_entry=bindings.mido_travel.player_entry.duplicate(true)
	for key in ["campaign_cursor","station_id","system_id"]:equipped_entry[key]=context[key]
	equipped_entry.ship_id=ship_id
	cursor=context.campaign_cursor;_kind="dekato";uses_equipment=true;restores_local=true
	return true

## Pool restoration at the retained origin only. This capability grants neither
## a location transition nor generic cursor40 player/departure admission.
func configure_selected40(bindings: RefCounted,context: Dictionary,ship_id: int) -> bool:
	error="";cursor=-1;is_arrival=false;is_departure=false;uses_equipment=false
	equipped_entry={};_kind="";_departure={};_training={};_pirate={};_travel={};restores_local=false
	if not load("res://src/content/selected40_population_definitions.gd").context_valid(bindings,context) or ship_id<0:return reject("Selected40 player pools require their retained source context and ship")
	equipped_entry=bindings.mido_travel.player_entry.duplicate(true)
	equipped_entry.merge({"campaign_cursor":context.campaign_cursor,"station_id":context.origin_station_id,"system_id":context.origin_system_id,"ship_id":ship_id},true)
	cursor=context.campaign_cursor;_kind="selected40";uses_equipment=true;restores_local=true
	return true

## Explicit source41 pool restoration. General player entry remains closed.
func configure_selected41(bindings: RefCounted,context: Dictionary,ship_id: int) -> bool:
	error="";cursor=-1;is_arrival=false;is_departure=false;uses_equipment=false
	equipped_entry={};_kind="";_departure={};_training={};_pirate={};_travel={};restores_local=false
	if not load("res://src/content/selected41_population_definitions.gd").context_valid(bindings,context) or ship_id<0:return reject("Source41 player requires its retained native portal context")
	equipped_entry=bindings.mido_travel.player_entry.duplicate(true)
	equipped_entry.merge({"campaign_cursor":41,"station_id":-1,"system_id":-1,"ship_id":ship_id},true)
	cursor=41;_kind="selected41";uses_equipment=true;restores_local=true
	return true

## A typed normal-world continuation restores the transferred cache. It never
## authorizes a generic player entry, station departure or repair/reset.
func configure_normal_return(bindings: RefCounted,mission_context: RefCounted,loadout: Dictionary) -> bool:
	error="";cursor=-1;is_arrival=false;is_departure=false;uses_equipment=false
	equipped_entry={};_kind="";_departure={};_training={};_pirate={};_travel={};restores_local=false
	if not is_instance_of(mission_context,load("res://src/simulation/mission_context.gd")) or not mission_context.matches_loadout(loadout):return reject("Normal player entry requires its admitted equipment")
	var identity: Dictionary=mission_context.identity()
	if not mission_context.normal_location(bindings,int(loadout.station_id),int(identity.campaign_cursor)):return reject("Normal player entry requires its completed portal return")
	equipped_entry=bindings.mido_travel.player_entry.duplicate(true)
	equipped_entry.merge({"campaign_cursor":identity.campaign_cursor,"station_id":loadout.station_id,"system_id":loadout.system_id,"ship_id":loadout.ship_id},true)
	cursor=identity.campaign_cursor;_kind="normal_return";uses_equipment=true;restores_local=true
	return true

func player_cache(parameters: Dictionary, seed: Dictionary, hull: int, capacities: Dictionary, reset:=false) -> Dictionary:
	if cursor<0:return {}
	if _kind=="normal_return":return {} if reset else Cache._departure_cache(parameters,equipped_entry,seed,hull,capacities,false)
	if _kind=="selected41":return {} if reset else Cache._departure_cache(parameters,equipped_entry,seed,hull,capacities,false,true)
	if _kind in ["dekato","selected40"]:return Cache._departure_cache(parameters,equipped_entry,seed,hull,capacities,reset)
	if _kind=="alioth":return Cache.alioth_attack_cache(parameters,_travel,seed,hull,capacities,reset)
	if _kind=="kappa":return Cache.kappa_rescue_cache(parameters,_travel,seed,hull,capacities,reset)
	if _kind=="sahi":return Cache.sahi_cache(parameters,_travel,seed,hull,capacities,reset,cursor)
	if _kind=="post_sahi":return Cache.post_sahi_cache(parameters,_travel,seed,hull,capacities,reset,cursor)
	if _kind=="ordinary_void":return Cache.ordinary_void_cache(parameters,_travel,seed,hull,capacities,reset)
	if _kind=="free":return Cache._departure_cache(parameters,equipped_entry,seed,hull,capacities,reset)
	if _kind in ["local","convoy"]:return Cache.local_travel_cache(parameters,_travel,seed,hull,capacities,reset,cursor)
	if _kind=="training":return Cache.combat_training_cache(parameters,_training,seed,hull,capacities,reset)
	if is_departure:return Cache.departure_cache(parameters,_departure,seed,hull,capacities,reset)
	if reset:return {}
	return Cache.base_cache(parameters,seed,hull,capacities,cursor)

func contact_weapons(opening_weapon: Dictionary) -> Dictionary:
	if cursor<0:return {}
	if _kind=="normal_return":return {"candidates":[],"enabled":false,"context":{}}
	if _kind=="selected41":return {"candidates":[],"enabled":false,"context":{}}
	if _kind in ["convoy","alioth","free","kappa","sahi","post_sahi","ordinary_void","dekato","selected40"]:return {"candidates":[],"enabled":false,"context":{}}
	if _kind=="local":
		var armed:=is_departure or Travel.navigation_available(_travel,cursor)
		return {"candidates":[Travel.ordinary_weapon(_travel,cursor)] if armed else [],
			"enabled":armed,"context":{"campaign_cursor":cursor,"nonplayer_source":true}}
	var weapon:=opening_weapon
	if _kind=="full_hold" and not _pirate.is_empty():
		if not Pirate.parameters(_pirate):reject("Unsupported second-trip pirate weapon");return {}
		weapon=_pirate.primary_weapon
	return {"candidates":_training.npc_weapons.duplicate(true) if uses_equipment else [weapon.duplicate(true)],
		"enabled":_kind!="full_hold" or not _pirate.is_empty(),
		"context":{"campaign_cursor":cursor,"nonplayer_source":true} if uses_equipment else {}}

func reject(message: String) -> bool:
	error=message
	return false
