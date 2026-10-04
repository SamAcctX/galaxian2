extends "res://tests/freighter_geometry.gd"
## Detached declaration/resource checks, not an earned Vossk-world encounter.
const Population=preload("res://src/content/free_population_definitions.gd")
const Traffic=preload("res://src/content/free_traffic_definitions.gd")
const Vossk=preload("res://src/content/vossk_traffic_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const World=preload("res://src/content/ordinary_world_definitions.gd")
const Death=preload("res://src/content/freighter_destruction_definitions.gd")
const Resources=preload("res://src/content/freighter_destruction_resources.gd")

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest):check(false,library.error+bindings.error);return
	verify_target_factions(library,bindings)
	if failures:return
	if not bindings.mido_travel.has("vossk_traffic"):
		check(Population.freighter_hull(bindings,1)==-1 and Death.for_faction(bindings,1).is_empty(),"Earlier packs unexpectedly gained Vossk traffic")
		return
	check(Vossk.parameters(bindings.mido_travel.vossk_traffic),"Vossk declarations differ from the checked source")
	check(Population.freighter_hull(bindings,1)==13,"Vossk freighter inherited hull15")
	var assembly:=Population.freighter_assembly(bindings,1)
	check(Population.assembly_hull(bindings,assembly)==13,"Vossk assembly lost hull identity")
	var empty: Array=Population.empty_child_resources(bindings,assembly)
	check(Population.Equal.equal_value(empty,[17040,17041] if bindings.mido_travel.has("vossk_lod") else []),"Empty children require their independent source proof")
	check(Population.empty_child_resources(bindings,Population.freighter_assembly(bindings,0)).is_empty(),"Empty-child permission leaked to another faction")
	for id in empty:check(not bindings.records.has(int(id)),"Empty child unexpectedly has a resource registration")
	var row:={"actor_kind":1,"hull_catalogue_id":13,"subtype":1,"world_flag":true,"model_assembly_required":true,"assembly":assembly}
	check(Traffic.actor_matches(bindings,row,"freighter",-1,false,1),"Valid detached Vossk ship declaration rejected")
	check(not Traffic.actor_matches(bindings,row,"freighter",-1,false,0),"Vossk freighter entered a Terran traffic group")
	row.hull_catalogue_id=15
	check(not Traffic.actor_matches(bindings,row,"freighter",-1,false,1),"Wrong Vossk hull accepted")
	check(bindings.mido_travel.vossk_traffic.boxes.size()==5,"Vossk collision lost source boxes")
	for box in bindings.mido_travel.vossk_traffic.boxes:
		check(box.offset[0]==0 and box.half_extents.all(func(value):return value>0),"Invalid source collision dimensions")
	verify_import_guards(bindings)
	var rules:=Death.for_faction(bindings,1)
	check(rules.get("hull_catalogue_id")==13 and rules.get("wreck_layout_id")==4 and rules.get("cargo_model_id")==16991,"Vossk death inherited another faction's hull, wreck or cargo")
	var resources:=Resources.new()
	if not resources._configure_resources(library,bindings,rules):check(false,resources.error);return
	var assets:=resources.snapshot()
	check(assets.model.model_id==18303 and assets.initial_material.id==34712 and assets.wreck_material.id==33355,"Vossk destruction art changed faction")
	check(assets.model.end_ms>assets.model.start_ms and not assets.wreck_shapes.is_empty(),"Vossk animation or wreck volumes are empty")
	check(assets.wreck_shapes.all(func(shape):return shape.kind==1),"Vossk box-only wreck gained invented sphere shapes")
	for faction in [0,2]:
		var previous:=Resources.new()
		if not previous._configure_resources(library,bindings,Death.for_faction(bindings,faction)):check(false,previous.error);continue
		check(not previous.snapshot().wreck_shapes.is_empty(),"Existing faction lost mixed wreck shapes")

func verify_target_factions(library: RefCounted,bindings: RefCounted) -> void:
	# Detached target fixtures exercise the real inventory boundary, not just
	# its declaration predicate. They do not grant a career, route or reward.
	var cat=load("res://src/content/catalogues.gd").new()
	var loadout=load("res://src/simulation/opening_loadout.gd").new()
	if not cat.open(library) or not loadout.configure(bindings,cat,bindings.base_content_id):check(false,cat.error+loadout.error);return
	var population=load("res://src/simulation/scenery_population.gd").new()
	if not population.configure(bindings):check(false,population.error);return
	for station in [95,30,15]:
		var world:=World.location(bindings,station)
		if world.is_empty():continue
		var source: Dictionary=loadout.snapshot()
		source.merge({"station_id":station,"system_id":world.system_id,"campaign_cursor":18},true)
		var count: Dictionary=population.for_departure(station,{"companions_empty":true,"location_match":false,"special_placement":false},18)
		var field=load("res://src/simulation/scenery_field.gd").new()
		if count.is_empty() or not field.configure(bindings,cat,station,false,false,18):check(false,population.error+field.error);return
		var scenery: Dictionary=field.generate(count.center,{"state":98765})
		if scenery.is_empty():check(false,field.error);return
		for faction in [0,1,2]:
			var hull:=Population.freighter_hull(bindings,faction)
			if hull<0:continue
			var row:={"actor_id":0,"actor_kind":faction,"hull_catalogue_id":hull,"subtype":1,
				"population_group":"freighter","world_flag":true,"model_assembly_required":true,
				"assembly":Population.freighter_assembly(bindings,faction).duplicate(true)}
			var expected: bool=faction in [int(world.faction),int(bindings.mido_travel.free_population.freighter_alternate_factions[int(world.faction)])]
			var targets=load("res://src/simulation/opening_target_inventory.gd").new()
			var accepted: bool=targets._configure_source(bindings,cat,source,[row],scenery,count)
			# Population construction owns the world faction; the inventory trusts its rows.
			if expected:check(accepted,"Target inventory refused the world faction at station %d for freighter %d: %s"%[station,faction,targets.error])
			if accepted!=expected:return
			if not expected:
				check(targets.snapshot().is_empty(),"Rejected foreign freighter published target membership")
				continue
			check(targets.snapshot().npc_ids==[0],"Accepted freighter lost target membership")
			var detail=load("res://src/presentation/ship_detail_group.gd").new()
			if not detail.configure(bindings,{0:hull},[0],{0:row.assembly}):check(false,detail.error);return
			check(detail.refresh({0:Vector3.ZERO},Vector3.ZERO,1) and detail.snapshot().selections[0].level==0,"Source freighter detail lost its near geometry")
			if hull==13:
				var unsupported=load("res://src/presentation/ship_detail_group.gd").new()
				check(not unsupported.configure(bindings,{0:13},[0]),"Vossk detail fell back to another hull without its source assembly")
				check(not unsupported.configure(bindings,{0:13},[0],{0:Population.freighter_assembly(bindings,0)}),"Vossk detail accepted a different hull's assembly")
			row.assembly.body_resource_ids[0]+=1
			check(not detail.configure(bindings,{0:hull},[0],{0:row.assembly}) and detail.snapshot().is_empty(),"Changed source assembly passed freighter detail admission")
	print("Ordinary target inventory retained each supported world's freighter faction and strict assembly checks")

func verify_import_guards(bindings: RefCounted) -> void:
	var changed: Dictionary=bindings.mido_travel.duplicate(true)
	changed.vossk_traffic.boxes[0].half_extents[0]=-1
	check(not Travel.parameters(changed),"Mutated Vossk collision survived the import boundary")
	changed=bindings.mido_travel.duplicate(true);changed.vossk_traffic.death.model_id=18302
	check(not Travel.parameters(changed),"Wrong-faction destruction art survived the import boundary")
	if bindings.mido_travel.has("vossk_lod"):
		changed=bindings.mido_travel.duplicate(true);changed.vossk_lod.resource_ids.append(17038)
		check(not Travel.parameters(changed),"Real engine mesh became an optional empty child")
		changed=bindings.mido_travel.duplicate(true);changed.erase("vossk_traffic")
		check(not Travel.parameters(changed),"Empty children bypassed the matching Vossk assembly requirement")
	check(World.location(bindings.mido_travel,29).is_empty()!=World.vossk_available(bindings.mido_travel),"Vossk world admission disagrees with complete ship support")
	for capability in ["vossk_traffic","vossk_lod"]:
		changed=bindings.mido_travel.duplicate(true);changed.erase(capability)
		for station in [15,29]:check(World.location(changed,station).is_empty(),"Incomplete Vossk resources admitted an ordinary world")
		changed[capability]={}
		check(not World.vossk_available(changed),"Malformed Vossk resources admitted an ordinary world")
	check(Death.for_free(bindings,1,{}).is_empty(),"Asset selection bypassed the ordinary-world context gate")
