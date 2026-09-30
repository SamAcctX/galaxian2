extends RefCounted
## Native support for the verified story states after the travel unlock.
const Visit=preload("res://src/content/suttnar_visit_definitions.gd")
const Preparation=preload("res://src/content/kappa_preparation_definitions.gd")
const Return=preload("res://src/content/kappa_return_definitions.gd")
const Outcome=preload("res://src/content/kappa_outcome_definitions.gd")
const Departure=preload("res://src/content/kappa_departure_definitions.gd")
const Post=preload("res://src/content/post_sahi_definitions.gd")
const Thynome=preload("res://src/content/thynome_expedition_definitions.gd")
const DimaReturn=preload("res://src/content/dima_return_definitions.gd")
const PostProbe=preload("res://src/content/post_probe_visit_definitions.gd")
const Crystals=preload("res://src/content/void_crystal_definitions.gd")
const Nehma=preload("res://src/content/nehma_visit_definitions.gd")
const Gakkrr=preload("res://src/content/gakkrr_visit_definitions.gd")
const BakkaReturn=preload("res://src/content/bakka_return_definitions.gd")
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")

static func result_rules(bindings: RefCounted,cursor: Variant,mission: Variant) -> Dictionary:
	return Outcome.conversation(bindings,cursor,mission)

static func result_presentation(bindings: RefCounted,cursor: Variant,mission: Variant,failed:=false) -> Dictionary:
	var rules:=result_rules(bindings,cursor,mission)
	if rules.is_empty():return {}
	var presentation: Dictionary=load("res://src/content/full_hold_story_definitions.gd").briefing(bindings,2)
	if presentation.is_empty():return {}
	presentation.campaign_cursor=int(cursor);presentation.mission_kind=int(rules.mission.kind)
	presentation.events=rules.events.duplicate(true)
	if failed:
		var failure: Dictionary=bindings.mido_travel.kappa_outcome.failure
		presentation.events=[{"speaker_id":int(failure.speaker_id),"text_id":int(failure.text_ids[0]),"voice_event_id":int(failure.voice_event_id)}]
	return presentation

## Preparing original dialogue does not authorize a campaign departure.
static func dialogue_rules(bindings: RefCounted,cursor: Variant,mission: Variant,station_only:=false) -> Dictionary:
	if station_only:
		var expansion:=Valkyrie.conversation(bindings,cursor,mission)
		if not expansion.is_empty():return expansion
		var recipe: Dictionary=load("res://src/content/mission_recipe.gd").select(bindings,cursor)
		if recipe.get("entry")=="station" and recipe.mission==mission:
			return {"campaign_cursor":recipe.cursor,"mission":recipe.mission,"next_cursor":recipe.next_cursor,
				"next_mission":recipe.next_mission,"reward_credits":recipe.career.reward_credits,
				"events":recipe.result.lines,"target_station_required":true}
		if cursor==39:return load("res://src/content/nehma_return_definitions.gd").conversation(bindings,cursor,mission)
		if Preparation.selected(bindings,cursor,mission,"fitting"):return bindings.mido_travel.kappa_preparation.fitting.duplicate(true)
		if bindings!=null and expedition_available(bindings.mido_travel) and cursor==27:return Thynome.conversation(bindings,cursor,mission)
		if bindings!=null and post_probe_available(bindings.mido_travel):
			if cursor in [31,32]:return PostProbe.conversation(bindings,cursor,mission)
			if cursor==33:return Crystals.conversation(bindings,cursor,mission)
			if cursor==34 and nehma_available(bindings.mido_travel):return Nehma.conversation(bindings,cursor,mission)
			if cursor==35 and nehma_available(bindings.mido_travel):return Gakkrr.conversation(bindings,cursor,mission)
			if cursor==37:return BakkaReturn.conversation(bindings,cursor,mission)
		return Return.conversation(bindings,cursor,mission)
	if Visit.selected(bindings,cursor,mission):return bindings.mido_travel.suttnar_visit.duplicate(true)
	if Preparation.selected(bindings,cursor,mission,"visit"):return bindings.mido_travel.kappa_preparation.visit.duplicate(true)
	if bindings!=null and expedition_available(bindings.mido_travel) and cursor==30:return DimaReturn.conversation(bindings,cursor,mission)
	return {}

static func dialogue_presentation(bindings: RefCounted,cursor: Variant,mission: Variant,station_only:=false) -> Dictionary:
	var rules:=dialogue_rules(bindings,cursor,mission,station_only)
	if rules.is_empty():return {}
	var presentation: Dictionary=load("res://src/content/full_hold_story_definitions.gd").briefing(bindings,2)
	if presentation.is_empty():return {}
	presentation.campaign_cursor=int(cursor);presentation.mission_kind=int(rules.mission.kind)
	presentation.events=rules.events.duplicate(true)
	return presentation

## Resolve optional declarations without replacing the selected pack or exposing
## a merged payload. Legacy dictionary callers retain their original boundary.
static func source_travel(source: Variant) -> Dictionary:
	if source is Dictionary:return source
	return source.mido_travel if source is RefCounted and source.get("mido_travel") is Dictionary else {}

static func onward_available(source: Variant) -> bool:
	if not source is RefCounted:return false
	var rules=load("res://src/content/nehma_return_definitions.gd")
	return rules.source_available(source)

static func supported(source: Variant,cursor: Variant) -> bool:
	var travel:=source_travel(source)
	if not cursor is int or not travel.has("free_flight"):return false
	if not completed_mission(source,cursor).is_empty():return true
	if source is RefCounted and Valkyrie.saved_story(source,cursor):return true
	if cursor in [39,40]:return onward_available(source)
	if cursor==27:return Post.parameters(travel.get("post_sahi",{}))
	if cursor in [28,30,31]:return expedition_available(travel)
	if cursor==32:return post_probe_available(travel)
	# Retaining a declared mission does not admit its target story world.
	if cursor==35:return nehma_available(travel)
	if cursor==36:return gakkrr_available(travel)
	if BakkaReturn.parameters(travel.get("bakka_return")) and (cursor==int(travel.bakka_return.mission.campaign_cursor) or cursor==int(travel.bakka_return.next_mission.campaign_cursor)):return gakkrr_available(travel)
	if cursor in [33,34]:return post_probe_available(travel) and Crystals.parameters(travel.get("void_crystals")) and load("res://src/content/void_access_definitions.gd").parameters(travel.get("void_access"))
	return cursor==int(travel.free_flight.campaign_cursor) or (Visit.parameters(travel.get("suttnar_visit")) and cursor==int(travel.suttnar_visit.next_cursor)) or (chapter_available(travel) and cursor in [20,21,22,23,24])

static func chapter_available(travel: Dictionary) -> bool:
	return Departure.parameters(travel.get("kappa_departure")) and Preparation.parameters(travel.get("kappa_preparation")) and Return.parameters(travel.get("kappa_return")) and Outcome.parameters(travel.get("kappa_outcome"))

static func expedition_available(travel: Dictionary) -> bool:
	return Post.portal_available(travel,30)

static func post_probe_available(travel: Dictionary) -> bool:
	return expedition_available(travel) and PostProbe.parameters(travel.get("post_probe_visits"))

static func nehma_available(travel: Dictionary) -> bool:
	return supported(travel,34) and Nehma.parameters(travel.get("nehma_visit"))

static func gakkrr_available(travel: Dictionary) -> bool:
	return nehma_available(travel) and Gakkrr.parameters(travel.get("gakkrr_visit"))

static func gakkrr_world_available(travel: Dictionary) -> bool:
	# Imported dialogue alone cannot authorize travel into an unfinished world.
	if not gakkrr_available(travel):return false
	var target: Dictionary=travel.gakkrr_visit.mission35
	return load("res://src/content/ordinary_world_definitions.gd").location(travel,int(target.station_id)).get("system_id",-1)==int(target.system_id)

static func mission(source: Variant,cursor: int) -> Dictionary:
	if not supported(source,cursor):return {}
	var completed:=completed_mission(source,cursor)
	if not completed.is_empty():return completed
	if source is RefCounted and Valkyrie.saved_story(source,cursor):return Valkyrie.mission(cursor)
	var travel:=source_travel(source)
	if cursor==39:return PostProbe.mission_values(load("res://src/content/nehma_return_definitions.gd").declarations(source).mission)
	if cursor==40:return PostProbe.mission_values(load("res://src/content/nehma_return_definitions.gd").declarations(source).next_mission)
	if cursor==28:return Thynome.mission_values(travel.thynome_expedition.mission28)
	if cursor==30:
		var result:={}
		for key in ["kind","station_id","reward"]:result[key]=int(travel.void_probe.mission30_declaration[key])
		result.bonus=0;result.source_parameter=0
		return result
	if cursor==31:return DimaReturn.next_mission(travel.dima_return)
	if cursor==32:return PostProbe.mission_values(travel.post_probe_visits.missions["32"])
	if cursor==33:return PostProbe.mission_values(travel.void_crystals.mission33)
	if cursor==34:return PostProbe.mission_values(travel.void_crystals.next_mission)
	if cursor==35:return PostProbe.mission_values(travel.nehma_visit.next_mission)
	if cursor==36:return PostProbe.mission_values(travel.gakkrr_visit.next_mission)
	if cursor==37:return PostProbe.mission_values(travel.bakka_return.mission)
	if BakkaReturn.parameters(travel.get("bakka_return")) and cursor==int(travel.bakka_return.next_mission.campaign_cursor):return PostProbe.mission_values(travel.bakka_return.next_mission)
	if cursor==27:
		var result:={}
		for key in ["kind","station_id","reward","bonus","source_parameter"]:result[key]=int(travel.post_sahi.missions["27"][key])
		return result
	if cursor==int(travel.free_flight.campaign_cursor):
		var rules: Dictionary=travel.alioth_return
		return {"kind":int(rules.next_kind),"station_id":int(rules.next_station_id),"reward":0,"bonus":0,"source_parameter":0}
	if chapter_available(travel):
		for rules in [travel.kappa_preparation.visit,travel.kappa_preparation.fitting]+travel.kappa_return.conversations:
			if cursor==int(rules.campaign_cursor):return _mission(rules.mission)
			if cursor==int(rules.next_cursor):return _mission(rules.next_mission)
	var result:={}
	for key in travel.suttnar_visit.next_mission:result[key]=int(travel.suttnar_visit.next_mission[key])
	return result

static func completed_mission(source: Variant,cursor: Variant) -> Dictionary:
	if not source is RefCounted:return {}
	return load("res://src/content/mission_recipe.gd").completed_career(source,cursor)

static func visit_at(travel: Dictionary,cursor: Variant,station_id: Variant) -> bool:
	if cursor==30 and expedition_available(travel):return station_id==int(travel.void_probe.mission30_declaration.station_id)
	if Visit.parameters(travel.get("suttnar_visit")) and cursor is int and cursor==int(travel.suttnar_visit.campaign_cursor) and station_id==int(travel.suttnar_visit.mission.station_id):return true
	return chapter_available(travel) and cursor is int and cursor==int(travel.kappa_preparation.visit.campaign_cursor) and station_id==int(travel.kappa_preparation.visit.mission.station_id)

static func active_visit(travel: Dictionary,context: Dictionary) -> bool:
	return visit_at(travel,context.get("campaign_cursor"),context.get("station_id")) and empty_story(travel,context)

## These selected story scenes share the original actor-free cast tail. Their
## clocks/dialogue still belong to the visit or station conversation owners.
static func ordinary_story_at(source: Variant,cursor: Variant,station_id: Variant) -> bool:
	var travel:=source_travel(source)
	# An expansion talk mission's target is an ordinary station until docking.
	if source is RefCounted and Valkyrie.saved_story(source,cursor):return station_id is int and Valkyrie.mission(cursor).get("kind")==Valkyrie.TALK and station_id==Valkyrie.mission(cursor).station_id
	if cursor==39:return supported(source,cursor) and station_id is int and station_id==mission(source,cursor).station_id
	if visit_at(travel,cursor,station_id):return true
	if cursor==27 and expedition_available(travel):return station_id==int(travel.post_sahi.missions["27"].station_id)
	if cursor==31 and post_probe_available(travel):return station_id==int(travel.post_probe_visits.missions["31"].station_id)
	# Admit the visit only when its complete crystal/source continuation is supported.
	if cursor==32 and supported(travel,33):return station_id==int(travel.post_probe_visits.missions["32"].station_id)
	if cursor==34 and nehma_available(travel):return station_id==int(travel.nehma_visit.mission34.station_id)
	if cursor==35 and gakkrr_world_available(travel):return station_id==int(travel.gakkrr_visit.mission35.station_id)
	if not chapter_available(travel) or cursor not in [20,22,23]:return false
	return station_id==mission(travel,cursor).get("station_id")

static func empty_story(source: Variant,context: Dictionary) -> bool:
	if not ordinary_story_at(source,context.get("campaign_cursor"),context.get("station_id")) or context.get("mission_story")!=true or context.get("mission_completed")!=false:return false
	var travel:=source_travel(source)
	var expected:=mission(source,context.campaign_cursor)
	var system:=18 if context.campaign_cursor==30 else 6 if context.campaign_cursor in [23,27] else 11
	if context.campaign_cursor==39:system=int(load("res://src/content/nehma_return_definitions.gd").declarations(source).mission.system_id)
	if context.campaign_cursor in [31,32]:system=int(travel.post_probe_visits.missions[str(context.campaign_cursor)].system_id)
	if context.campaign_cursor==34:system=int(travel.nehma_visit.mission34.system_id)
	if context.campaign_cursor==35:system=int(travel.gakkrr_visit.mission35.system_id)
	return context.get("system_id")==system and context.get("mission_kind")==expected.get("kind")

static func rescue_at(travel: Dictionary,cursor: Variant,station_id: Variant) -> bool:
	return chapter_available(travel) and cursor==int(travel.kappa_departure.rescue_cursor) and station_id==int(travel.kappa_preparation.fitting.next_mission.station_id)

static func sahi_at(travel: Dictionary,cursor: Variant,station_id: Variant) -> bool:
	if cursor==28 and expedition_available(travel):return station_id==int(travel.thynome_expedition.mission28.station_id)
	return Post.parameters(travel.get("post_sahi",{})) and load("res://src/content/sahi_encounter_definitions.gd").coherent(travel) and cursor==int(travel.sahi_visit.campaign_cursor) and station_id==int(travel.sahi_visit.mission.station_id)

static func _mission(source: Dictionary) -> Dictionary:
	var result:={}
	for key in source:result[key]=int(source[key])
	return result
