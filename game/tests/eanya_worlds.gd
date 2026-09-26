extends "res://tests/nesla_worlds.gd"
## Original Eanya ordinary-world components. No career position is fabricated.
var module_counts:={}

func world_spec() -> Dictionary:
	return {"name":"Eanya","system":4,"ids":[20,21,22,23,24],"types":[11,14,3,5,7],"models":[5,1,9,8,8],"fields":[0,1,3,15,15,90,20,8],"arrays":[[14,0,0],[20,21,22,23,24],[17,27],[0,1,2]],"freighters":[3],"hostiles":[2,8],"gates":[[85,20],[20,85]],"closed":[130,135]}

func verify_actor_extra(bindings: RefCounted,row: Dictionary,actor: Dictionary) -> void:
	if row.population_group!="freighter":return
	module_counts[row.assembly.container_count]=true
	check(actor.hull_resource==bindings.resolve(17049,"mesh") and actor.free_traffic and actor.subtype==1,"Ordinary Mido actor resolved a fixed faction assembly")
	check(actor.point_boxes==[{"offset":Vector3(0,-199,4708),"half_extents":Vector3(490,765,620)},{"offset":Vector3(0,-14,-98),"half_extents":Vector3(2250,702.5,4430)}],"Mido actor lost its original collision boxes")
	check(Traffic.Population.freighter_assembly_matches(bindings,3,row.assembly),"Original modular assembly was not admitted")
	for count in [-1,4,1.5,true]:
		var invalid:=row.duplicate(true);invalid.assembly.container_count=count
		check(not Traffic.actor_matches(bindings,invalid,"freighter",-1,false,3),"Ordinary Mido accepted an invalid section count")
	var invalid:=row.duplicate(true);invalid.assembly.container_lod_model_id=17055
	check(not Traffic.actor_matches(bindings,invalid,"freighter",-1,false,3),"Ordinary Mido accepted lights as cargo geometry")
	invalid=row.duplicate(true);invalid.assembly=Traffic.Population.freighter_assembly(bindings,2)
	check(not Traffic.actor_matches(bindings,invalid,"freighter",-1,false,3),"Ordinary Mido accepted a Nivelian model alias")
	invalid=row.duplicate(true);invalid.assembly.erase("container_count")
	check(not Traffic.actor_matches(bindings,invalid,"freighter",-1,false,3),"An undrawn Mido template became a live actor")

func verify_extra(bindings: RefCounted,cat: RefCounted) -> void:
	for count in 4:check(module_counts.has(count),"Ordinary population did not exercise section count%d"%count)
	check(Traffic.Population.freighter_hull(bindings,3)==15 and Traffic.Population.freighter_assembly(bindings,3).get("root_model_id")==17049,"Ordinary Mido lost its separate source factory")
	var navigation=load("res://src/content/free_navigation_definitions.gd")
	var mission: Dictionary=navigation.Campaign.mission(bindings.mido_travel,38)
	check(not navigation.destination_supported(bindings,38,mission,22),"Ordinary Eanya support admitted unfinished Dekato story gameplay")
	check(navigation.destination_supported(bindings,38,mission,20),"Ordinary Eanya gate destination was suppressed by the pending story")
	var retained: Dictionary=bindings.ambient_population
	bindings.ambient_population={}
	check(Worlds.catalogue_location(bindings,cat,20).is_empty() and Traffic.Population.freighter_hull(bindings,3)==-1,"Missing Mido construction admitted Eanya")
	bindings.ambient_population=retained
	var contacts: Dictionary=bindings.persistent_contacts
	bindings.persistent_contacts={}
	check(Worlds.catalogue_location(bindings,cat,20).is_empty(),"Missing authored contact support admitted Eanya")
	bindings.persistent_contacts=contacts
	check(not Worlds.catalogue_location(bindings,cat,20).is_empty(),"Restored original dependencies did not restore Eanya")
