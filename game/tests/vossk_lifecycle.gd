extends "res://tests/free_lifecycle.gd"
## Same earned equipment prerequisite and shared lifecycle checks, with explicit
## Vossk world inputs. This does not create an earned campaign departure.
func lifecycle_equipment(equipment: RefCounted,bindings: RefCounted,cat: RefCounted,context: Dictionary) -> RefCounted:
	# Apply the source-supported relocation operations on a detached inventory.
	# This neither records a journey nor changes the captured campaign/save.
	var guard:=Construction.new()
	check(not guard.configure_free_traffic(bindings,cat,equipment,context,2),"Mismatched retained player location admitted departure")
	var result: RefCounted=equipment.fork()
	var stops: Array=[95,15]+([25] if context.system_id==5 else [])+([29] if context.station_id==29 else [])
	var gates=load("res://src/content/gate_arrival_definitions.gd")
	var worlds=load("res://src/content/ordinary_world_definitions.gd")
	var travel=load("res://src/content/mido_travel_definitions.gd")
	for station in stops:
		var owned: Dictionary=result.snapshot().loadout
		var world: Dictionary=worlds.catalogue_location(bindings,cat,station)
		if world.is_empty():check(false,"Missing component relocation world");return null
		var arrival:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":context.campaign_cursor,"from_station_id":owned.station_id,"station_id":station,"system_id":world.system_id,"source_state":int(bindings.mido_travel.travel.source_state),"world_type":int(bindings.mido_travel.travel.world_type),"audio_selector":int(bindings.mido_travel.travel.audio_selector)}
		if world.system_id==owned.system_id:
			if travel.route(bindings.mido_travel,context.campaign_cursor,owned.station_id,station).is_empty() or not result.relocate_local_arrival(bindings,cat,arrival):check(false,result.error);return null
		else:
			arrival=gates.packet(bindings,cat,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"from_station_id":owned.station_id,"destination_station_id":station},context.campaign_cursor)
			if arrival.is_empty() or not result.relocate_gate_arrival(bindings,cat,arrival):check(false,result.error);return null
	return result

func lifecycle_vectors() -> Array:
	var result:=[]
	for values in [[3,15,2,0,0.5],[5,25,22,0,0.5],[5,29,30,20,1.0]]:
		var context:=FreePopulation.CONTEXT.duplicate()
		context.system_id=values[0];context.station_id=values[1]
		context.rank=values[3];context.difficulty=values[4]
		result.append({"context":context,"seed":values[2]})
	return result

func verify_lifecycle_coverage() -> void:
	check(verified_hostile_budgets>0 and verified_hostile_reentries>0,"Vossk lifecycle omitted the reinforcement budgets or actual reentry transaction")
	for faction in [0,1,8]:check(observed_factions.has(faction),"Missing Vossk-world faction branch: "+str(faction)+"; observed "+str(observed_factions.keys()))
	check(verified_wrecks.size()==1 and verified_wrecks.has(1),"Vossk worlds did not exercise their original freighter wreck")
