extends RefCounted
## Valkyrie story flights. The original builds a story cast and radio once when
## a location is entered at a story cursor. The story then moves on silently
## after 10 s in space at the target station (kind 156) or at any other station
## (kind 160); the cast and radio keep running. Combat flights (kind 4) are
## built only at their target station and move on once their objective ships
## are destroyed. Read from the Mac mission factory, radio factory and level
## script.
const Campaign=preload("res://src/content/valkyrie_campaign_definitions.gd")
const FLIGHT_KINDS:=[4,156,160,163]
const ADVANCE_AFTER_MS:=10000
## [speaker, text, voice, condition, value]: 5 = after the level time,
## 6 = after the given earlier line.
const RADIO:={
	49:[[0,2109,1469,5,8000]],
	50:[[63,2110,1470,5,8000],[0,2111,1471,6,0],[63,2112,1472,6,1],[0,2113,1473,6,2]],
	51:[[63,2114,1474,5,8000],[0,2115,1475,6,0]],
	52:[[63,2116,1476,5,8000],[0,2117,1477,6,0]],
	56:[[27,2143,1481,5,8000],[0,2144,1482,6,0],[28,2145,1483,16,0],[0,2146,1484,20,3],[0,2147,1485,6,3],[27,2148,1486,28,0]],
}
## Condition 16 = a non-friendly ship is awake, 20 = ships destroyed,
## 28 = the player's armour is gone. Combat flights play their result lines
## over the radio once the objective ships are gone (assumption: the original
## shows them as its in-flight result conversation).
const RESULT_RADIO:={56:[[27,2149,1206],[0,2150,1207]]}
## [count, faction, hull, hostile]. All Vossk (faction 1); hull 13 is their
## large ship, built as the Vossk freighter-class assembly (subtype 1).
const CASTS:={
	49:[[5,1,9,false]],
	50:[[4,1,9,false]],
	51:[[1,1,13,true],[5,1,9,true]],
	52:[[2,1,13,true],[6,1,9,true]],
}
const LARGE_HULL:=13
## Combat flights: waypoints in world units, then groups of
## [count, faction, hull (-1 = the faction's random fighter), role, waypoint].
## Escorts start asleep beside the player with near-infinite hull and fly the
## waypoints; targets sleep at a waypoint until the player comes near.
const COMBAT:={
	56:{"points":[Vector3(0,0,-60000),Vector3(-12000,-7000,-110000),Vector3(15000,3000,-160000)],
		"groups":[[3,8,24,"escort",0],[2,8,-1,"target",0],[4,8,-1,"target",1]]},
}
const ESCORT_HULL:=9999999
## Convoy hunts (kind 163): at each listed station a transport of the system's
## race waits with five fighters around a point far from the station. Within
## CONVOY_RANGE the convoy turns hostile; destroying the transport clears the
## station. Every other ship destroyed with the mission item adds to the career's
## story counter. Radio texts step by two per cleared station.
## Assumptions: the transport keeps the +x side (the original picks either side),
## its two attached containers and the extra traffic ships are not built.
const CONVOY:={59:{"stations":[56,45,22],"item_id":179,"approach_text":2180,"destroyed_text":2179,"final":[0,2179,1228],
	"voices":{2174:1130,2175:1131,2176:1132,2177:1133,2178:1134}}}
const CONVOY_RANGE:=50000
const CONVOY_ESCORTS:=5
## Once this radio line has finished, every story ship turns hostile and the
## Vossk standing drops to its worst value (standing 0 = 100).
const TURN_HOSTILE_AFTER:={50:{"radio_index":2,"reputation_axis":0,"reputation_value":100}}

## The story job selected at this location, if the career is in a story flight.
static func story_job(bindings: RefCounted,cursor: Variant,station_id: Variant,progress: Dictionary={}) -> Dictionary:
	if not cursor is int or not station_id is int or not Campaign.saved_story(bindings,cursor) or not (CASTS.has(cursor) or COMBAT.has(cursor) or CONVOY.has(cursor)):return {}
	var mission:=Campaign.mission(cursor)
	if mission.is_empty() or int(mission.kind) not in FLIGHT_KINDS:return {}
	if COMBAT.has(cursor) and station_id!=int(mission.station_id):return {}
	var job:={"kind":int(mission.kind),"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
		"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":int(mission.station_id)}
	if CONVOY.has(cursor):
		var index: int=CONVOY[cursor].stations.find(station_id)
		var cleared:=int(progress.get("story_stations_mask",0))
		if index<0 or cleared & (1<<index):return {}
		var faction:=int(load("res://src/content/ordinary_world_definitions.gd").location(bindings,station_id).get("faction",-1))
		if faction<0:return {}
		job.merge({"convoy_index":index,"cleared_mask":cleared,"faction":faction})
	return job

## Kills that count toward a convoy mission's story counter.
static func counts_kill(cursor: Variant,kill: Dictionary,excluded: Array) -> bool:
	return cursor is int and CONVOY.has(cursor) and int(kill.get("item_id",-1))==int(CONVOY[cursor].item_id) and not excluded.has(kill.get("actor_id"))

static func is_story_job(mission: Variant) -> bool:
	return mission is Dictionary and mission.get("story_job",false)==true

## Recipe parts for the shared contract cast factory and result runner.
static func recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor)
	if COMBAT.has(cursor):return _combat_recipe(job)
	if CONVOY.has(cursor):return _convoy_recipe(job)
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
	return {"actor_count":first,"ship_groups":groups,"radio":_radio(cursor,0),
		"success":{"kind":"elapsed","after_ms":ADVANCE_AFTER_MS} if arrives else {"kind":"never"},
		"story":_advance(cursor),"turn_hostile":TURN_HOSTILE_AFTER.get(cursor,{}).duplicate(true)}

static func _combat_recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor)
	var plan: Dictionary=COMBAT[cursor]
	var groups:=[];var first:=0;var targets:=[];var escorts:=0
	for row in plan.groups:
		var escort: bool=row[3]=="escort"
		var group:={"first_actor":first,"end_actor":first+int(row[0]),"faction":int(row[1]),"population_group":"story","origin":"zero",
			"ship_state":{"mode":5,"active":false,"targeting_blocked":true},
			"policy":{"initial_hostile":not escort,"updated_hostile":not escort,"friendly":escort}}
		if int(row[2])>=0:group.hull_catalogue_id=int(row[2])
		if escort:
			escorts+=int(row[0])
			group.position={"kind":"player_offset","offset":Vector3.ZERO,"bound":Vector3(7000,7000,7000)}
			group.route_start=int(row[4])
			group.ship_state.hull_override=ESCORT_HULL
		else:
			group.position={"kind":"path_scatter","index":int(row[4]),"offsets":[-1500,-1500,-1500],"bounds":[3000,3000,3000]}
			targets.append_array(range(first,first+int(row[0])))
		groups.append(group)
		first+=int(row[0])
	return {"actor_count":first,"ship_groups":groups,"placement":{"kind":"points","points":plan.points.duplicate()},
		"radio":_radio(cursor,targets.size()),
		"success":{"kind":18,"first_actor":targets.min(),"end_actor":targets.max()+1},
		"story":_advance(cursor),"turn_hostile":{}}

static func _convoy_recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor);var plan: Dictionary=CONVOY[cursor]
	var mask:=int(job.cleared_mask) | (1<<int(job.convoy_index))
	var left:=0
	for index in plan.stations.size():
		if not mask & (1<<index):left+=1
	var neutral:={"initial_hostile":false,"updated_hostile":false,"friendly":false}
	var state:={"mode":0,"active":true,"targeting_blocked":false}
	var groups:=[
		{"first_actor":0,"end_actor":1,"faction":int(job.faction),"subtype":1,"population_group":"freighter","origin":"zero",
			"ship_state":state.merged({"cruise_enabled":false}),"policy":neutral.duplicate(),
			"position":{"kind":"path_scatter","index":0,"offsets":[-15000,-1500,-25000],"bounds":[30000,3000,50000]}},
		{"first_actor":1,"end_actor":1+CONVOY_ESCORTS,"faction":int(job.faction),"population_group":"story","origin":"zero",
			"ship_state":state.duplicate(),"policy":neutral.duplicate(),"route_start":0,
			"position":{"kind":"path_scatter","index":0,"offsets":[-4000,-1500,-4000],"bounds":[8000,3000,8000]}}]
	# Text for this station: 2174/2176/2178 on approach, 2175/2177 when the
	# transport dies; the last station ends with the result line instead.
	var approach:=int(plan.approach_text)-2*(left+1);var destroyed:=int(plan.destroyed_text)-2*left
	var radio:=[{"speaker_id":0,"text_id":approach,"voice_event_id":int(plan.voices[approach]),"condition":29,"values":[0,CONVOY_RANGE]}]
	var last: Array=plan.final if left==0 else [0,destroyed,int(plan.voices[destroyed])]
	radio.append({"speaker_id":int(last[0]),"text_id":int(last[1]),"voice_event_id":int(last[2]),"condition":1,"values":[0]})
	var story:=_advance(cursor) if left==0 else {"from_cursor":cursor,"campaign_cursor":cursor,"mission":Campaign.mission(cursor),"previous_mission":Campaign.mission(cursor)}
	story.progress={"story_stations_mask":mask}
	return {"actor_count":1+CONVOY_ESCORTS,"ship_groups":groups,"placement":{"kind":"points","points":[Vector3(95000,-4500,145000)]},
		"radio":radio,"success":{"kind":18,"first_actor":0,"end_actor":1},"story":story,"turn_hostile":{"radio_index":0},
		"story_excluded_actors":[0]}

static func _radio(cursor: int,targets: int) -> Array:
	var radio:=[]
	for row in RADIO.get(cursor,[]):radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":row[3],"values":[row[4]]})
	var result: Array=RESULT_RADIO.get(cursor,[])
	for index in result.size():
		var row: Array=result[index]
		var after: Array=[20,targets] if index==0 else [6,radio.size()-1]
		radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":after[0],"values":[after[1]]})
	return radio

static func _advance(cursor: int) -> Dictionary:
	var next:=Campaign.next_cursor(cursor)
	return {"from_cursor":cursor,"campaign_cursor":next,"mission":Campaign.mission(next),"previous_mission":Campaign.mission(cursor)}
