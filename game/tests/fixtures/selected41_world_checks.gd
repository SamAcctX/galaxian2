extends RefCounted
## Uses the explicitly detached late-portal stimulus from the native Host
## navigation check. Initialization evidence is not an earned successor save.
const World=preload("res://src/simulation/selected41_world_initialization.gd")
const Builder=preload("res://src/simulation/selected41_construction.gd")
const Field=preload("res://src/simulation/scenery_field.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const ENVIRONMENT_SECONDS=1700000001
const FIELD_SECONDS=1700000002

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,departure: RefCounted,visuals: RefCounted) -> void:
	var before: Dictionary=departure.snapshot()
	var entry: RefCounted=departure.prepare_successor41_entry(bindings)
	if entry==null:host.check(false,departure.error);return
	var retained: Dictionary=entry.snapshot()
	var career: Dictionary=entry.career_owner().snapshot()
	var equipment: Dictionary=entry.equipment_owner().snapshot()
	var world:=World.new()
	for times in [[-1,FIELD_SECONDS],[ENVIRONMENT_SECONDS,2147483648],[1.0,FIELD_SECONDS],[ENVIRONMENT_SECONDS,null]]:
		host.check(not world.prepare(bindings,cat,library,entry,times[0],times[1]) and world.snapshot().is_empty(),"Invalid source41 time partially published a world")
	host.check(not world.prepare(bindings,cat,null,entry,ENVIRONMENT_SECONDS,FIELD_SECONDS) and world.snapshot().is_empty(),"Missing native field resources partially published a world")
	if not world.prepare(bindings,cat,library,entry,ENVIRONMENT_SECONDS,FIELD_SECONDS):host.check(false,world.error);return
	var state: Dictionary=world.snapshot()
	var scenery: Dictionary=state.scenery
	var initialized: Dictionary=scenery.world_initialization
	var components: Dictionary=state.components
	host.check(world.matches_departure(departure) and state.campaign_cursor==41 and state.station_id==-1 and state.system_id==-1 and state.world_type==3 and not state.application_committed,"Source41 world lost its typed uncommitted entry")
	host.check(state.entry_conditions=={"companions_empty":true,"location_match":true,"special_placement":true},"Native portal lost the actual arrival camera/placement flag")
	host.check(state.environment.campaign_cursor==41 and state.environment.station_id==-1 and state.environment.return_station_id==retained.return_station_id and state.environment.return_system_id==retained.return_system_id,"Source41 environment changed return provenance")
	host.check(state.environment.objects.size()==2 and world.environment_owner().object_state(1).is_empty() and not state.environment.docking_available,"Source41 invented a second gate or dockable Void station")
	host.check(state.environment.objects[0].model_ids==[16443,16446,16449] and state.environment.objects[1].model_ids==[15000,15002,15001,15003],"Source41 did not retain the source Void station/gate")
	var random:=Random.new();random.seed_from(ENVIRONMENT_SECONDS)
	host.check(state.environment_input_random_state==random.snapshot(),"Source41 environment was not independently time seeded")
	var gate:=Vector3(0,-10000+random.next_int(20000),170000+random.next_int(50000))
	host.check(state.environment.player_position==gate and state.environment.random_state==random.snapshot(),"Source41 skipped or reordered its two incoming-gate draws")
	var portal:=Vector3(-40000+random.next_int(80000),-20000+random.next_int(40000),40000+random.next_int(40000))
	host.check(state.environment_object=={"resource_id":16994,"position":portal} and state.environment_random_state==random.snapshot(),"Source41 skipped the ordinary portal draws or consumed a forbidden launch yaw")
	host.check(state.player_pose==Transform3D(Basis.IDENTITY,Vector3(3000,2000,-320000)) and state.player_pose.origin!=gate,"Source41 script did not replace the fallback gate player pose")
	random.seed_from(-1)
	var count:=80+random.next_int(80)
	host.check(scenery.departure_population.count_random_state==random.snapshot(),"Source41 count used world time instead of station -1")
	for _axis in 3:random.next_int(100000)
	host.check(scenery.departure_population.random_state==random.snapshot() and scenery.center==Vector3(-30000,0,30000) and scenery.objects.size()==count,"Source41 omitted discarded center draws or the Void center override")
	var field:=Field.new()
	if not field.configure(bindings,cat,-1,true,false,41):host.check(false,field.error);return
	random.seed_from(FIELD_SECONDS)
	var expected_field: Dictionary=field.generate(Vector3(-30000,0,30000),random.snapshot())
	host.check(scenery.objects==expected_field.objects and initialized.input_random_state==expected_field.random_state,"Source41 actors did not start exactly after the separately time-seeded field")
	host.check(scenery.bodies.objects.size()==count and scenery.destruction.size()==count,"Source41 field omitted native contacts or destruction owners")
	for row in scenery.objects:
		host.check(row.model_variant==1 and row.item_id==int(bindings.scenery_resources.fallback_item_id) and row.ore_draws==0,"Source41 sampled ordinary ore or the wrong asteroid geometry")
	var factory:=Factory.new()
	if not factory.configure_selected41(bindings,cat,entry):host.check(false,factory.error);return
	var expected_cast: Dictionary=factory.generate(expected_field.random_state)
	host.check(initialized.npc_construction==expected_cast and components.construction==expected_cast,"Source41 generated a second cast or crossed the field/cast random-state boundary")
	host.check(world.construction_owner().npc_construction_owner()==world.scenery_owner().world_initialization_owner().npc_construction_owner(),"Native source41 bodies did not consume the field's actual factory owner")
	random.restore(expected_cast.random_state)
	var void_weapon: Dictionary=bindings.mido_travel.sahi_encounter.weapons["void"]
	var impact: int=load("res://src/content/contract_world_definitions.gd").impact_model(bindings,0)
	for id in 8:
		var actual: Dictionary=initialized.weapon_effects[id]
		if id==0:
			host.check(actual=={"actor_id":0,"unarmed":true},"Source41 allocated weapons to its unarmed Vossk freighter")
			continue
		var assignments:=[]
		for pass_index in 2:
			var flips:=[]
			for _slot in 4:flips.append(random.next_int(2)==0)
			assignments.append({"item_id":0 if pass_index==0 else int(void_weapon.item_id),"resource_id":impact if pass_index==0 else int(void_weapon.impact_model_id),"flipped":flips})
		host.check(actual.discarded_default==assignments[0] and actual.primary==assignments[1],"Source41 reordered default/faction weapon effects at actor%d"%id)
	host.check(initialized.random_state==random.snapshot() and scenery.random_state==random.snapshot() and state.camera.input_random_state==random.snapshot(),"Source41 camera did not follow exactly 56 fighter-effect draws")
	var offset:=Vector3(500+random.next_int(500),500+random.next_int(500),7000)
	for axis in 2:
		if random.next_int(2)==0:offset[axis]=-offset[axis]
	host.check(state.camera.special_placement and state.camera.offset==offset and state.camera.fixed_shot.eye==state.player_pose*offset and state.random_state==random.snapshot(),"Source41 actual arrival camera branch/order changed")
	var other:=World.new()
	if not other.prepare(bindings,cat,library,entry,ENVIRONMENT_SECONDS+1,FIELD_SECONDS):host.check(false,other.error);return
	var changed: Dictionary=other.snapshot()
	host.check(changed.environment!=state.environment and changed.scenery==scenery and changed.components==components and changed.camera==state.camera,"Environment time leaked across the source field reseed")
	other=World.new()
	if not other.prepare(bindings,cat,library,entry,ENVIRONMENT_SECONDS,FIELD_SECONDS+1):host.check(false,other.error);return
	changed=other.snapshot()
	host.check(changed.environment==state.environment and changed.environment_object==state.environment_object and changed.scenery.objects!=scenery.objects and changed.components.player_pose==components.player_pose,"Field time leaked backward into environment or moved the script player")
	var rejected:=Builder.new()
	host.check(not rejected.prepare_initialized(bindings,cat,entry,load("res://src/simulation/opening_world_initialization.gd").new()) and rejected.snapshot().is_empty(),"An ungenerated world granted source41 native bodies")
	host.check(not world.prepare(bindings,cat,library,entry,0,0) and world.snapshot()==state,"Repeated preparation replaced a complete source41 candidate")
	var observation: Dictionary=world.snapshot();observation.scenery.objects[0].position=Vector3.ZERO;observation.entry.player_cache.values.hull=999
	host.check(world.snapshot()==state and entry.snapshot()==retained and entry.career_owner().snapshot()==career and entry.equipment_owner().snapshot()==equipment and departure.snapshot()==before,"Source41 preparation/render observations mutated a parent or retained career")
	if OS.get_environment("GOF2_SELECTED41_NPC_PROBE")=="1":await load("res://tests/fixtures/selected41_npc_checks.gd").run(host,library,bindings,cat,visuals,world,other)
	if OS.get_environment("GOF2_SELECTED41_RADIO_PROBE")=="1":await load("res://tests/fixtures/selected41_radio_checks.gd").run(host,library,bindings,cat,visuals,world,other)
	if OS.get_environment("GOF2_SELECTED41_SEQUENCE_PROBE")=="1":await load("res://tests/fixtures/selected41_sequence_checks.gd").run(host,library,bindings,cat,visuals,world,other)
	if DisplayServer.get_name()!="headless":await load("res://tests/fixtures/selected41_construction_checks.gd").render(host,library,bindings,visuals,world.construction_owner(),world)
	host.check(departure.snapshot()==before and world.snapshot()==state,"Source41 GPU presentation changed native construction or its actual40 parent")
	print("Source41 native WORLD: field%d,8actors,56effectdraws,arrival-camera%s; input%s -> field%s -> cast%s -> effects%s -> camera%s; detached candidate, no Host commit"%[count,offset,state.environment_input_random_state,expected_field.random_state,expected_cast.random_state,initialized.random_state,state.random_state])
