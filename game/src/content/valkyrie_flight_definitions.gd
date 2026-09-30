extends RefCounted
## Valkyrie story flights. The original builds a story cast and radio once when
## a location is entered at a story cursor. The story then moves on silently
## after 10 s in space at the target station (kind 156) or at any other station
## (kind 160); the cast and radio keep running. Read from the Mac mission
## factory, radio factory and level script.
const Campaign=preload("res://src/content/valkyrie_campaign_definitions.gd")
const FLIGHT_KINDS:=[156,160]
const ADVANCE_AFTER_MS:=10000
## [speaker, text, voice, condition, value]: 5 = after the level time,
## 6 = after the given earlier line.
const RADIO:={
	49:[[0,2109,1469,5,8000]],
	50:[[63,2110,1470,5,8000],[0,2111,1471,6,0],[63,2112,1472,6,1],[0,2113,1473,6,2]],
	51:[[63,2114,1474,5,8000],[0,2115,1475,6,0]],
	52:[[63,2116,1476,5,8000],[0,2117,1477,6,0]],
}
## [count, faction, hull, hostile]. All Vossk (faction 1); hull 13 is their
## large ship, built as the Vossk freighter-class assembly (subtype 1).
const CASTS:={
	49:[[5,1,9,false]],
	50:[[4,1,9,false]],
	51:[[1,1,13,true],[5,1,9,true]],
	52:[[2,1,13,true],[6,1,9,true]],
}
const LARGE_HULL:=13
## Once this radio line has finished, every story ship turns hostile and the
## Vossk standing drops to its worst value (standing 0 = 100).
const TURN_HOSTILE_AFTER:={50:{"radio_index":2,"reputation_axis":0,"reputation_value":100}}

## The story job selected at this location, if the career is in a story flight.
static func story_job(bindings: RefCounted,cursor: Variant,station_id: Variant) -> Dictionary:
	if not cursor is int or not station_id is int or not Campaign.saved_story(bindings,cursor) or not CASTS.has(cursor):return {}
	var mission:=Campaign.mission(cursor)
	if mission.is_empty() or int(mission.kind) not in FLIGHT_KINDS:return {}
	return {"kind":int(mission.kind),"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
		"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":int(mission.station_id)}

static func is_story_job(mission: Variant) -> bool:
	return mission is Dictionary and mission.get("story_job",false)==true

## Recipe parts for the shared contract cast factory and result runner.
static func recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor)
	var groups:=[];var first:=0
	for row in CASTS[cursor]:
		var hostile: bool=row[3]
		var group:={"first_actor":first,"end_actor":first+int(row[0]),"faction":int(row[1]),
			"population_group":"story","origin":"zero","position":{"kind":"player_offset","offset":Vector3(-6000,-2000,6000),"bound":Vector3(12000,4000,12000)},
			"ship_state":{"mode":0,"active":true,"targeting_blocked":false},
			"policy":{"initial_hostile":hostile,"updated_hostile":hostile,"friendly":not hostile}}
		if int(row[2])==LARGE_HULL:group.merge({"subtype":1,"population_group":"freighter","ship_state":{"mode":0,"active":true,"targeting_blocked":false,"cruise_enabled":false},"position":{"kind":"player_offset","offset":Vector3(-8000,-3000,12000),"bound":Vector3(16000,6000,16000)}},true)
		else:group.hull_catalogue_id=int(row[2])
		groups.append(group)
		first+=int(row[0])
	var at_target: bool=int(job.station_id)==int(job.target_station_id)
	var arrives: bool=at_target if int(job.kind)==156 else not at_target
	var radio:=[]
	for row in RADIO.get(cursor,[]):radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":row[3],"values":[row[4]]})
	var next:=Campaign.next_cursor(cursor)
	return {"actor_count":first,"ship_groups":groups,"radio":radio,
		"success":{"kind":"elapsed","after_ms":ADVANCE_AFTER_MS} if arrives else {"kind":"never"},
		"story":{"from_cursor":cursor,"campaign_cursor":next,"mission":Campaign.mission(next),"previous_mission":Campaign.mission(cursor)},
		"turn_hostile":TURN_HOSTILE_AFTER.get(cursor,{}).duplicate(true)}
