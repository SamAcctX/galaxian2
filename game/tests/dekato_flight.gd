extends SceneTree
## Enclosing selected-flight integration. Inputs are explicit native component
## fixtures, never a relabelled save, an earned journey or campaign completion.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Rules=preload("res://src/content/dekato_convoy_definitions.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Frame=preload("res://src/simulation/first_flight_frame.gd")
const Session=preload("res://src/presentation/first_flight_session.gd")
const Vitals=preload("res://src/presentation/flight_vitals_overlay.gd")
const Secondaries=preload("res://src/presentation/secondary_weapon_panel.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const PlayerEntry=preload("res://src/content/player_entry_definitions.gd")
const Career=preload("res://src/simulation/opening_handoff.gd")
const Reputation=preload("res://src/simulation/faction_reputation.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const Inventory=preload("res://tests/fixtures/bakka_equipment.gd")
const History=preload("res://tests/fixtures/sahi_location_history.gd")
const Bodies=preload("res://src/content/scenery_body_resources.gd")
const Effects=preload("res://src/content/scenery_effect_resources.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var checks:=0
var failures:=0
var captures:=""
var session: Node3D
var vitals: Control
var secondaries: Control
var retained_emp_quantity: int=-1
var now_us:=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size() not in [3,4]:check(false,"Supply content, bindings and visuals");finish();return
	captures=OS.get_environment("GOF2_CAPTURE_DIR") if args.size()==3 else args[3]
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);finish();return
	verify_saved_identity(library,bindings,cat)
	if failures:finish();return
	var mission:={"kind":4,"station_id":22,"reward":0,"bonus":0,"source_parameter":0}
	check(not Navigation.destination_supported(bindings,38,mission,22),"Selected components opened the public Dekato route")
	check(not PlayerEntry.new().configure(bindings,38,22,true,0),"Dekato acquired ordinary free entry")
	if not Rules.available(bindings):
		check(not Rules.selected(bindings,38,mission,22) and not Contracts.new().advance_dekato_story(bindings,{}),"Earlier bindings acquired Dekato career advancement")
		check(not Construction.new().prepare_dekato_selected(bindings,cat,null,{}, {},{},4096,123,null,null),"Earlier bindings admitted selected construction")
		check(Frame.OrdinaryFlight.briefing(bindings,38,false,22).get("events",[]).is_empty(),"Earlier bindings acquired Dekato briefing")
		check(not load("res://src/content/audio_resources.gd").new().configure(library,bindings,38),"Earlier bindings acquired Dekato radio recordings")
		check(Frame.OrdinaryFlight.objective(bindings,38).is_empty(),"Earlier bindings acquired Dekato results")
		finish();return
	await verify(library,bindings,cat,args[2])
	if vitals!=null:vitals.free()
	if secondaries!=null:secondaries.free()
	if session!=null:session.free();await process_frame
	finish()

## Actual earned source bytes are only loaded with their own binding identity.
## Reading this checkpoint never turns the selected component into an earned
## successor. A valid old career and the new convoy capability are not enough
## to authorize a cross-binding restore, departure or migration.
func verify_saved_identity(library: RefCounted,bindings: RefCounted,cat: RefCounted) -> void:
	var source_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	if source_path.is_empty():return
	var legacy_args: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_SOURCE_ARGS")))
	var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	if not legacy_args is Array or legacy_args.size()!=3 or expected.length()!=64:check(false,"Supply the retained checkpoint's original content arguments and SHA256");return
	check(FileAccess.get_sha256(source_path)==expected,"The actual source checkpoint changed before admission")
	var legacy:=Bindings.new()
	if not legacy.open(str(legacy_args[1]),library.manifest):check(false,legacy.error);return
	var file:=SaveFile.new();var archive:=Archive.new()
	var record:=file.load_document(source_path,legacy,cat,library)
	if record.is_empty():check(false,file.error);return
	var station:=archive.restore(legacy,cat,library,record)
	if station==null:check(false,archive.error);return
	var before: Dictionary=station.snapshot()
	check(before.campaign_cursor==38 and before.loadout.station_id==27 and before.mission.station_id==22,"Use the actual acknowledged B'akka source checkpoint")
	check(before.contracts.credits==22100 and before.contracts.passengers==3 and before.cargo.entries.is_empty(),"The source checkpoint lost its actual wallet, passengers or empty cargo")
	check(archive.capture(station,legacy)==record and not station.prepare_departure(legacy,cat).is_empty(),"The actual checkpoint cannot continue under its original bindings")
	if bindings.binding_id!=legacy.binding_id:
		check(archive.restore(bindings,cat,library,record)==null and not archive.error.is_empty(),"The optional capability silently relabelled the actual saved career")
		check(file.load_document(source_path,bindings,cat,library).is_empty(),"The save-file reader bypassed the exact binding boundary")
		var construction:=Construction.new()
		check(not construction.prepare_free(bindings,cat,station,4096,123) and construction.snapshot().is_empty(),"A foreign retained station bypassed native departure identity")
	check(station.snapshot()==before and archive.capture(station,legacy)==record,"Rejected successor admission changed the retained source owners")
	check(FileAccess.get_sha256(source_path)==expected,"Read-only successor admission changed the source file")
	print("Actual saved source remains ",legacy.binding_id," / ",expected,"; no migration or earned successor claim")

func verify(library: RefCounted,bindings: RefCounted,cat: RefCounted,art: String) -> void:
	var progress:=Career.calculate_progress(bindings.opening_handoff,38,0,0,0)
	var dialogue: Dictionary=load("res://src/content/dialogue_definitions.gd").select(bindings,38)
	var voice_rules: Script=load("res://src/content/radio_audio_definitions.gd")
	check(voice_rules.parameters(dialogue.voice,1),"The source convoy radio lost its single recording")
	check(not voice_rules.parameters(dialogue.voice,2) and not voice_rules.parameters(dialogue.voice,0),"Radio voice accepted a mismatched or empty event extent")
	progress.reputation=Reputation.initial(bindings);progress.debris_destroyed=0;progress.capital_ship_kills=0
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,
		"station_id":22,"system_id":4,"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false,"rank":progress.rank,"difficulty":0.5}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":22,"system_id":4,"ship_id":0,"equipment_ids":[2,41,86,81,55]}
	var original_context:=context.duplicate(true)
	var fixture:=Inventory.new();var equipment: RefCounted=fixture.create(bindings,cat,seed)
	if equipment==null:check(false,fixture.error);return
	var history:=History.new()
	var locations: RefCounted=history.create(bindings,cat,library,[27,22],{"campaign_cursor":38,"rank":progress.rank,"reputation":progress.reputation})
	if locations==null:check(false,history.error);return
	var owned: Dictionary=equipment.snapshot();var kept_locations: Dictionary=locations.snapshot()
	for slot in owned.loadout.slots:
		if slot is Dictionary and slot.get("item_id")==41:retained_emp_quantity=int(slot.quantity)
	check(retained_emp_quantity>0,"The component fixture lacks its retained EMP ammunition")
	var entry:=PlayerEntry.new()
	if not entry.configure_dekato(bindings,context,0):check(false,entry.error);return
	var parameters: Dictionary=bindings.opening_actors.player_initialization
	var capacities:=Player.resolve_capacities(cat.tables.items,owned.loadout.equipment_ids,parameters)
	var repair: Dictionary=parameters.repair
	var hull:=Player.resolve_ship_hull(cat.tables.ships[0].fields[int(repair.base_hull_field)],repair.initial_upgrades,repair)
	var cache:=entry.player_cache(parameters.flight_cache,owned.loadout,hull,capacities,false)
	cache.values.hull=67;cache.values.armor=mini(7,int(capacities.armor));cache.values.shield=mini(5,int(capacities.shield))
	var bodies:=Bodies.new();var effects:=Effects.new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var prepared:=Construction.new()
	check(not prepared.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,null,cache,true,bodies,effects) and prepared.snapshot().is_empty(),"Missing retained locations manufactured an arrival")
	check(not prepared.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,null,true,bodies,effects) and prepared.snapshot().is_empty(),"Missing cache refilled the ship")
	if not prepared.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects):check(false,prepared.error);return
	var constructed: Dictionary=prepared.snapshot();var arrival: Dictionary=constructed.departure.arrival_environment
	check(constructed.departure.get("dekato_source_receipt",{})==bindings.dekato_source_receipt(),"Selected construction lost its supplemental declaration provenance")
	var invalid_source:=Construction.new();invalid_source._state=prepared._state.duplicate(true)
	# Retain real observation owners so this negative test reaches the source
	# guard, rather than failing because an invented construction has no world.
	invalid_source._scenery=prepared.scenery_owner();invalid_source._camera=prepared.camera_owner();invalid_source._player=prepared.player_owner()
	invalid_source._state.departure.dekato_source_receipt={"source_binding_id":"0".repeat(64)}
	var refused_frame:=Frame.new()
	check(not refused_frame.configure(bindings,cat,library,invalid_source,"F",1.0) and refused_frame.error=="The prepared convoy changed its explicit source provenance","A substituted source receipt reached the live convoy owners")
	if not bindings.dekato_source_receipt().is_empty():
		invalid_source._state.departure.erase("dekato_source_receipt")
		check(not refused_frame.configure(bindings,cat,library,invalid_source,"F",1.0) and refused_frame.error=="The prepared convoy changed its explicit source provenance","The selected supplemental convoy admitted missing provenance")
	check(arrival.source=="cached_planet" and arrival.cache_station_id==22 and arrival.location_order==[27,22],"Arrival ignored the retained source location order")
	check(constructed.player_pose.origin==arrival.position and constructed.player_pose.basis.z.dot(-arrival.position.normalized())>0.999,"Source arrival lost its position or facing")
	check(constructed.scenery.world_initialization.dekato_context==constructed.dekato_context and constructed.campaign_cursor==38,"The full world fell back to ordinary traffic")
	check(prepared.player_owner().cache_snapshot()==cache and prepared.equipment_owner().snapshot()==owned,"Selected construction repaired pools or changed equipment")
	check(equipment.snapshot()==owned and locations.snapshot()==kept_locations and context==original_context,"Construction mutated its retained inputs")
	var wrong:=cache.duplicate(true);wrong.binding_id="0".repeat(64)
	check(not prepared.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,wrong,true,bodies,effects) and prepared.snapshot()==constructed,"A rejected cache replaced the accepted construction")
	check(prepared.contract_owner()==null,"A detached selected fixture manufactured a career")
	var retained: RefCounted=prepare_retained_career(bindings,cat,equipment,context,progress,locations,cache,bodies,effects)
	if retained==null:return
	prepared=retained;constructed=prepared.snapshot()
	if OS.get_environment("GOF2_DEKATO_COMPONENT_LOADOUTS")=="1":
		verify_representative_loadouts(bindings,cat,library,prepared,bodies,effects)
		return
	var frame:=Frame.new()
	var probe:=Frame.Encounter.new()
	if not probe.configure_dekato(bindings,cat,library,prepared.player_owner(),prepared.scenery_owner(),equipment,progress.reputation):check(false,probe.error);return
	var packet: Dictionary=probe.combat_snapshot()
	if not Rules.combat_population(bindings,packet):
		print("Selected particle input: ",probe.career_snapshot()," actors=",packet.actors.map(func(actor):
			var row:={}
			for key in ["base_content_id","binding_id","campaign_cursor","station_id","actor_id","authored_story","actor_kind","subtype","population_group","hull_catalogue_id"]:row[key]=actor.get(key)
			return row))
	if not frame.configure(bindings,cat,library,prepared,"F",0.5):check(false,frame.error);return
	var initial: Dictionary=frame.snapshot()
	check(initial.actors.size()==7 and initial.actors.slice(0,2).all(func(actor):return actor.actor_kind==2),"Frame omitted the original freighters or escorts")
	check(Rules.combat_population(bindings,initial.encounter.combat),"Shared effects rejected the retained source cast")
	var unselected: Dictionary=initial.encounter.combat.duplicate(true);unselected.erase("dekato_context")
	check(not Rules.combat_population(bindings,unselected),"Shared effects accepted an unselected seven-ship cast")
	var foreign: Dictionary=initial.encounter.combat.duplicate(true);foreign.actors[0].binding_id="foreign"
	check(not Rules.combat_population(bindings,foreign),"Shared effects accepted a foreign actor")
	var wrong_hull: Dictionary=initial.encounter.combat.duplicate(true);wrong_hull.actors[2].hull_catalogue_id=15
	check(not Rules.combat_population(bindings,wrong_hull),"Shared effects accepted a freighter hull as an escort")
	var wrong_cast: Dictionary=initial.encounter.combat.duplicate(true);wrong_cast.actors[0].subtype=0
	check(not Rules.combat_population(bindings,wrong_cast),"Shared effects accepted the wrong freighter subtype")
	check(initial.equipment.loadout.equipment_ids==owned.loadout.equipment_ids and initial.player_cache.values==cache.values,"Frame replaced actual equipment or cache values")
	check(frame.contract_owner()!=null and frame.contract_owner().snapshot()==initial.contracts and initial.contracts==constructed.departure.contracts,"Frame lost the retained native career or changed its admission")
	check(initial.encounter.primaries.guns[0].projectiles.weapon.item_id==2,"Frame replaced the mounted primary")
	check(initial.mining_objective.phase=="collecting" and not initial.combat_objective_satisfied and frame.prepare_station().is_empty(),"Empty cargo completed the convoy")
	var frozen: Dictionary=frame.snapshot();var paused: RefCounted=frame.evaluate(100,Vector2.ONE,1.0,true)
	check(paused!=null and paused.snapshot()==frozen and frame.snapshot()==frozen,"Paused preparation mutated the world")
	if DisplayServer.get_name()!="headless":
		var visuals:=Visuals.new()
		if not visuals.open(art,library.manifest):check(false,visuals.error);return
		session=Session.new();root.add_child(session)
		if not session.configure_dekato_selected(library,bindings,visuals,prepared,0,123) or not session.activate():check(false,session.error);return
		# These are the application's existing host-owned HUD controls, not
		# scene-local substitutes or supplied vitals/ammunition snapshots.
		vitals=Vitals.new();root.add_child(vitals);vitals.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		secondaries=Secondaries.new();root.add_child(secondaries);secondaries.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if not vitals.configure(library,bindings,visuals) or not secondaries.configure(library,bindings,visuals):check(false,vitals.error+secondaries.error);return
		frame=session.flight_owner()
		await capture("dekato-incoming")
	var input_branch:=OS.get_environment("GOF2_DEKATO_INPUT_BRANCH")
	if not input_branch.is_empty():
		if input_branch not in ["success","failure"]:check(false,"Unknown selected input branch");return
		var combat_prepared: RefCounted=prepare_shielded_component(bindings,cat,prepared,bodies,effects)
		if combat_prepared==null:return
		await verify_input_flight(bindings,cat,library,art,combat_prepared,input_branch=="success")
		check(equipment.snapshot()==owned and locations.snapshot()==kept_locations and prepared.snapshot()==constructed,"Input branch mutated its retained preparation")
		return
	for i in 70:
		frame=advance(frame,100)
		if frame==null:return
	check(not frame.snapshot().entry_released and not frame.snapshot().scenery_collision_enabled,"Entry released before 7001ms")
	frame=advance(frame,1)
	if frame==null:return
	check(frame.snapshot().entry_released and frame.snapshot().scenery_collision_enabled,"Source entry failed to release at 7001ms")
	check(frame.snapshot().player_pose!=initial.player_pose and frame.snapshot().player.vitals.hull==67,"Entry did not move the ship or refilled its hull")
	for i in 49:
		frame=advance(frame,100)
		if frame==null:return
	check(not frame.dialogue_visible() and frame._briefing.snapshot().hud_elapsed_ms==5000,"Briefing did not retain the original strict HUD threshold")
	frame=advance(frame,1)
	if frame==null:return
	var modal: Dictionary=frame.snapshot()
	check(modal.dialogue.visible and modal.dialogue.text_id==int(Rules.declarations(bindings).mission.briefing_events[0].text_id) and modal.dialogue.voice_event_id==184,"Original convoy briefing was replaced or skipped")
	await capture("dekato-briefing")
	var modal_before: Dictionary=frame.snapshot()
	frame=advance(frame,100,Vector2.ONE,true)
	if frame==null:return
	check(frame.snapshot().player_pose==modal_before.player_pose and frame.snapshot().world_elapsed_ms==modal_before.world_elapsed_ms and frame.snapshot().progress==modal_before.progress,"Briefing accepted combat input or advanced its clock")
	if session!=null:
		check(session.briefing_audio.snapshot().history.map(func(event):return event.source_id)==[184],"Briefing omitted the original voice")
		if not session.navigate("next"):check(false,session.error);return
		frame=session.flight_owner()
	else:
		var next: RefCounted=frame.navigate("next")
		if next==null:check(false,frame.error);return
		frame=next
	check(not frame.dialogue_visible() and frame.snapshot().campaign_cursor==38,"Briefing acknowledgement completed the mission")
	var steering_start: Dictionary=frame.snapshot()
	for i in 20:
		frame=advance(frame,100,Vector2(0.3,-0.2),true)
		if frame==null:return
	check(frame.snapshot().player_pose.basis!=steering_start.player_pose.basis,"Live frame ignored player steering")
	check(frame.snapshot().encounter.primaries!=steering_start.encounter.primaries,"Live frame did not advance the retained primary weapon")
	for i in 70:
		if frame.snapshot().radio.get("visible",false):break
		frame=advance(frame,100)
		if frame==null:return
	var radio: Dictionary=frame.snapshot().radio
	check(radio.get("visible",false) and frame.snapshot().world_elapsed_ms>17000,"Timed convoy transmission did not reach the live frame")
	check(frame._radio._definition.events[0].voice_event_id==523,"Timed radio replaced its source voice")
	if session!=null:
		var audio: Dictionary=session.flight_audio.snapshot()
		check(audio.voice_displayed==[true] and audio.active.has(523) and audio.active[523].get("voice",false) and not audio.active[523].source_bank.is_empty(),"The actual original radio recording was not committed")
	await capture("dekato-radio-flight")
	check(frame.snapshot().campaign_cursor==38 and frame.snapshot().mining_objective.phase=="collecting" and frame.prepare_station().is_empty(),"Selected frame manufactured result settlement or onward travel")
	check(equipment.snapshot()==owned and locations.snapshot()==kept_locations and prepared.snapshot()==constructed,"Flight mutated retained preparation owners")
	check(Navigation.destination_supported(bindings,38,constructed.departure.mission,22)==Rules.source_arrival_available(bindings) and not PlayerEntry.new().configure(bindings,38,22,true,0),"Integration bypassed explicit route consent or opened generic player entry")
	print("Dekato selected flight: world_ms=",frame.snapshot().world_elapsed_ms,"; radio=",radio,"; player=",frame.snapshot().player.vitals,"; retained cache and original arrival; no earned journey/save claim")
	await verify_results(frame,bindings)
	if session!=null:await render_failure(bindings,library,art,prepared)
	if not await verify_input_flight(bindings,cat,library,art,prepared,true,true):return
	check(equipment.snapshot()==owned and locations.snapshot()==kept_locations and prepared.snapshot()==constructed,"Result branches mutated retained preparation owners")

## The damaged unshielded ship above is retained as a real input-only death
## regression. Battle outcome coverage separately uses the existing original
## shielded component preset with original primary2, not edited weapon/actor stats,
## a purchase, an upgraded earned202 ship, or an in-flight pool refill.
func prepare_shielded_component(bindings: RefCounted,cat: RefCounted,original: RefCounted,bodies: RefCounted,effects: RefCounted,primary_id:=2) -> RefCounted:
	var before: Dictionary=original.snapshot()
	var career: RefCounted=original.contract_owner();var locations: RefCounted=career.location_owner()
	var context: Dictionary=career.campaign_flight_context(bindings,Navigation.Campaign.mission(bindings.mido_travel,38))
	if context.is_empty():check(false,career.error);return null
	var seed: Dictionary=before.departure.loadout.duplicate(true)
	seed.equipment_ids=[primary_id,41,50,81,55]
	var fixture:=Inventory.new();var equipment: RefCounted=fixture.create(bindings,cat,seed)
	if equipment==null:check(false,fixture.error);return null
	var entry:=PlayerEntry.new()
	if not entry.configure_dekato(bindings,context,0):check(false,entry.error);return null
	var loadout: Dictionary=equipment.snapshot().loadout
	var parameters: Dictionary=bindings.opening_actors.player_initialization
	var capacities:=Player.resolve_capacities(cat.tables.items,loadout.equipment_ids,parameters)
	var repair: Dictionary=parameters.repair
	var hull:=Player.resolve_ship_hull(cat.tables.ships[0].fields[int(repair.base_hull_field)],repair.initial_upgrades,repair)
	var cache: Dictionary=entry.player_cache(parameters.flight_cache,loadout,hull,capacities,false)
	var result:=Construction.new()
	if not result.prepare_dekato_selected(bindings,cat,equipment,context,career.snapshot().progress,{},4096,123,locations,cache,true,bodies,effects,career):check(false,result.error);return null
	check(result.player_owner().cache_snapshot()==cache and result.contract_owner().snapshot()==career.snapshot() and original.snapshot()==before,"Preparing a separate combat component changed the damaged source or retained career")
	print("Dekato independent shielded component: equipment=",loadout.equipment_ids," initial pools=",cache.values,"; no purchase, no saved202 migration, no in-flight refill")
	return result

## These are detached equipped entries. They prove admission, movement and real
## projectile emission for both starter guns, not shopping or an earned save.
func verify_representative_loadouts(bindings: RefCounted,cat: RefCounted,library: RefCounted,original: RefCounted,bodies: RefCounted,effects: RefCounted) -> void:
	var preserved: Dictionary=original.snapshot()
	for primary_id in [0,22]:
		var prepared: RefCounted=prepare_shielded_component(bindings,cat,original,bodies,effects,primary_id)
		if prepared==null:return
		var frame:=Frame.new()
		if not frame.configure(bindings,cat,library,prepared,"F",1.0):check(false,frame.error);return
		for tick in 122:
			if frame.dialogue_visible():break
			var next: RefCounted=frame.evaluate(100)
			if next==null:check(false,frame.error);return
			frame=next
		check(frame.snapshot().phase=="briefing" and frame.snapshot().dialogue.voice_event_id==184,"A starter loadout did not reach the actual entry briefing")
		if failures:return
		frame=frame.navigate("next")
		if frame==null:check(false,"A starter loadout could not acknowledge its briefing");return
		var before: Dictionary=frame.snapshot();var emitted:=false
		for tick in 20:
			var next: RefCounted=frame.evaluate(100,Vector2(0.3,-0.2),1.0,false,Vector2i(1280,720),Vector2.ZERO,true)
			if next==null:check(false,frame.error);return
			frame=next
			emitted=emitted or frame.snapshot().encounter.primaries.guns[0].projectiles.slots.any(func(slot):return slot!=null)
		var after: Dictionary=frame.snapshot()
		check(after.entry_released and after.player_pose!=before.player_pose and after.player.vitals.hull>0,"Admitted starter equipment could not control a surviving player")
		check(emitted and after.encounter.primaries.guns[0].projectiles.weapon.item_id==primary_id,"The admitted starter gun failed to emit its own native projectiles")
		check(after.campaign_cursor==38 and after.equipment==before.equipment and after.contracts.credits==before.contracts.credits,"Detached starter controls changed inventory, wallet or campaign progress")
		check(original.snapshot()==preserved,"Starter loadout coverage changed the retained component parent")
		print("Detached starter",primary_id," entry, briefing, steering and projectile emission checked; no station purchase or earned-save claim")

## Explicit component ledger, not an earned203 checkpoint. Its native location,
## Void and blueprint owners retain their own state and identity. No saved202
## document is copied, relabelled or used to manufacture these input values.
func create_component_career(bindings: RefCounted,cat: RefCounted,context: Dictionary,progress: Dictionary,locations: RefCounted) -> RefCounted:
	var source:=Contracts.new()
	source._rules=bindings.early_contracts;source._progress_rules=bindings.opening_handoff;source._catalogues=cat
	var side:={"kind":11,"station_id":99,"story":false,"difficulty":2,"quantity":2,"reward":321,"bonus":0,"source_parameter":2}
	var local: Dictionary=locations.location(int(context.station_id))
	source._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":38,"station_id":int(context.station_id),"rank":progress.rank,"reputation":progress.reputation.duplicate(true),
		"difficulty":context.difficulty,"progress":progress.duplicate(true),"credits":12345,"passengers":2,
		"mission":side,"active_offer_id":4,"accepted_contact":{"station_id":27,"offer_id":4,"offer":{"mission":side.duplicate(true)}},
		"offers":local.offers.duplicate(true),"population":local.population.duplicate(true),
		"completed_side_missions":4,"delivery_statistics":{"cargo":1,"passengers":0},
		"travel_statistics":{"jumpgates_used":3},"pending_result":{},"result_serial":2}
	source._lounges=locations.fork();source._void_source=Contracts.VoidSource.new();source._blueprints=Contracts.Blueprints.new()
	if not source._void_source.configure_fresh(bindings,cat,locations.snapshot().system_availability) or not source._blueprints.configure(cat,bindings.binding_id):check(false,source._void_source.error+source._blueprints.error);return null
	return source

func prepare_retained_career(bindings: RefCounted,cat: RefCounted,equipment: RefCounted,context: Dictionary,progress: Dictionary,locations: RefCounted,cache: Dictionary,bodies: RefCounted,effects: RefCounted) -> RefCounted:
	var source:=create_component_career(bindings,cat,context,progress,locations)
	if source==null:return null
	var initial: Dictionary=source.snapshot()
	var mission: Dictionary=Navigation.Campaign.mission(bindings.mido_travel,38)
	check(source.campaign_flight_context(bindings,mission)==context and source.snapshot()==initial,"Native career did not select the exact retained story")
	for mutation in [["base_content_id","foreign"],["binding_id","foreign"],["campaign_cursor",37],["station_id",27],["rank",20],["difficulty",1.0],["pending_result",{"retained":true}],["accepted_contact",{}]]:
		var invalid: RefCounted=source.fork();invalid._state[mutation[0]]=mutation[1]
		var before: Dictionary=invalid.snapshot();var rejected:=Construction.new()
		check(not rejected.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects,invalid) and rejected.snapshot().is_empty() and invalid.snapshot()==before,"Rejected admission mutated or accepted another career: "+mutation[0])
	for field in ["_flight","_pending_flight"]:
		var invalid: RefCounted=source.fork();invalid.set(field,{"retained":true})
		var before: Dictionary=invalid.snapshot();var pending: Dictionary=invalid._pending_flight.duplicate(true)
		check(invalid.campaign_flight_context(bindings,mission).is_empty() and invalid.snapshot()==before and invalid._pending_flight==pending,"Career admission discarded unresolved flight ownership: "+field)
	for field in ["_void_source","_blueprints","_lounges"]:
		var invalid: RefCounted=source.fork();invalid.set(field,null)
		var before: Dictionary=invalid.snapshot()
		check(invalid.campaign_flight_context(bindings,mission).is_empty() and invalid.snapshot()==before,"Career admission manufactured a missing owner: "+field)
	var target:=Construction.new()
	check(not target.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects,RefCounted.new()),"Selected construction accepted a nonnative career")
	var changed: RefCounted=locations.fork();changed._state.current_station_id=27
	check(not target.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,changed,cache,true,bodies,effects,source) and target.snapshot().is_empty(),"Selected construction replaced its retained location history")
	check(not target.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},-1,123,locations,cache,true,bodies,effects,source) and target.snapshot().is_empty() and source.snapshot()==initial,"Failed scenery preparation committed career admission")
	if not target.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects,source):check(false,target.error);return null
	check(target.contract_owner().snapshot()==initial and target.snapshot().departure.contracts==initial and source.snapshot()==initial,"Construction changed the wallet, job or retained career owners")
	var corrupt:=progress.duplicate(true);corrupt.rank_score+=1
	check(not source.advance_dekato_story(bindings,corrupt) and source.snapshot()==initial,"Career advance accepted inconsistent counters")
	check(not source.retain_dekato_progress(bindings,corrupt) and source.snapshot()==initial,"Career sampling accepted inconsistent counters")
	check(Archive.new().capture(target,bindings).is_empty(),"Selected construction acquired station persistence")
	return verify_incoming_admission(bindings,cat,equipment,source,context,progress,locations,cache,bodies,effects,target)

## The incoming transaction is exercised with the same disclosed target-world
## component, not a fabricated completed gate/local trip. Its real public route
## remains unavailable until the complete source/target worlds and saved career
## are supported. All subsequent flight checks use the shared arrival dispatcher.
func verify_incoming_admission(bindings: RefCounted,cat: RefCounted,equipment: RefCounted,source: RefCounted,context: Dictionary,progress: Dictionary,locations: RefCounted,cache: Dictionary,bodies: RefCounted,effects: RefCounted,selected: RefCounted) -> RefCounted:
	var incoming:=Construction.Incoming.new()
	if not incoming.configure(bindings,cat,22,locations,38):check(false,incoming.error);return null
	var original: Dictionary=selected.snapshot();var prior: Dictionary=source.snapshot()
	var owned: Dictionary=equipment.snapshot();var history: Dictionary=locations.snapshot();var arrival: Dictionary=incoming.snapshot()
	var mission: Dictionary=Navigation.Campaign.mission(bindings.mido_travel,38)
	check(not selected._prepare_free_owned(bindings,cat,equipment,source,mission,{},4096,123,true,bodies,effects,cache) and selected.snapshot()==original,"A selected convoy acquired ordinary station departure or replaced the prepared world")
	for from_station in [-1,22,cat.tables.stations.size()]:
		check(not selected._prepare_free_owned(bindings,cat,equipment,source,mission,{},4096,123,true,bodies,effects,cache,incoming,from_station) and selected.snapshot()==original,"Invalid source station replaced the retained incoming world")
	check(not selected.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects,source,RefCounted.new(),27) and selected.snapshot()==original,"A nonnative incoming placement acquired the convoy")
	check(not selected.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects,null,incoming,27) and selected.snapshot()==original,"An incoming world manufactured a missing native career")
	check(not selected.prepare_dekato_selected(bindings,cat,equipment,context,progress,{},4096,123,locations,cache,true,bodies,effects,source,null,27) and selected.snapshot()==original,"A detached component manufactured travel provenance")
	for mutation in [["base_content_id","foreign"],["binding_id","foreign"],["campaign_cursor",37],["station_id",27],["system_id",5],["location_order",[22,27]]]:
		var changed:=Construction.Incoming.new();changed._state=arrival.duplicate(true);changed._state[mutation[0]]=mutation[1]
		check(not selected._prepare_free_owned(bindings,cat,equipment,source,mission,{},4096,123,true,bodies,effects,cache,changed,27) and selected.snapshot()==original,"Mismatched incoming placement replaced the prepared world: "+mutation[0])
	check(not selected._prepare_free_owned(bindings,cat,equipment,source,mission,{},-1,123,true,bodies,effects,cache,incoming,27) and selected.snapshot()==original,"Failed incoming scenery committed the new world")
	var common:=Construction.new()
	if not common._prepare_free_owned(bindings,cat,equipment,source,mission,{},4096,123,true,bodies,effects,cache,incoming,27):check(false,common.error);return null
	var expected:=original.duplicate(true);expected.departure.from_station_id=27
	check(common.snapshot()==expected,"Shared arrival dispatch changed the selected world beyond retaining its departure provenance")
	check(common.snapshot().departure.arrival_environment==arrival and common.player_owner().cache_snapshot()==cache,"Shared arrival regenerated placement or refilled the surviving cache")
	check(common.contract_owner().snapshot()==prior and common.equipment_owner().snapshot()==owned,"Shared arrival changed the wallet, accepted job or equipped inventory")
	check(source.snapshot()==prior and equipment.snapshot()==owned and locations.snapshot()==history and incoming.snapshot()==arrival and selected.snapshot()==original,"Incoming admission mutated its source owners")
	check(Navigation.destination_supported(bindings,38,mission,22)==Rules.source_arrival_available(bindings) and not PlayerEntry.new().configure(bindings,38,22,true,0),"Incoming integration bypassed explicit route consent or opened generic player entry")
	return common

func unchanged_career_fields(before: Dictionary,after: Dictionary) -> bool:
	var left:=before.duplicate(true);var right:=after.duplicate(true)
	for key in ["campaign_cursor","progress","rank","reputation"]:left.erase(key);right.erase(key)
	return left==right

## The initial ship/career is the disclosed selected component above. From
## activation onward this branch only steers, throttles, fires and presses Next;
## no contact injection, pose/pool edits, actor retirement or result setters.
func verify_input_flight(bindings: RefCounted,cat: RefCounted,library: RefCounted,art: String,prepared: RefCounted,success: bool,expect_death:=false) -> bool:
	var prior: Node3D=session;var prior_clock:=now_us
	var frame:=Frame.new()
	if not frame.configure(bindings,cat,library,prepared,"F",0.5):check(false,frame.error);return false
	if prior!=null:
		prior.scene.set_display_active(false)
		var visuals:=Visuals.new()
		if not visuals.open(art,library.manifest):check(false,visuals.error);return false
		session=Session.new();root.add_child(session);now_us=0
		if not session.configure_dekato_selected(library,bindings,visuals,prepared,0,123) or not session.activate():check(false,session.error);return false
		frame=session.flight_owner()
	var before: Dictionary=frame.snapshot()
	var result: bool=await fly_input_branch(frame,before,success,expect_death)
	if prior!=null:
		session.free();session=prior;now_us=prior_clock;prior.scene.set_display_active(true)
	return result

func fly_input_branch(frame: RefCounted,before: Dictionary,success: bool,expect_death: bool) -> bool:
	var pilot:=Pilot.new();var firing_frames:=0;var briefing_seen:=false;var live_captured:=false;var damage_observed:=false
	var selected: Array=range(2,7) if success else [0,1]
	var label:="damaged" if expect_death else "success" if success else "failure"
	print("Dekato input ",label," native primary=",before.encounter.primaries.guns[0].projectiles.weapon)
	for tick in 6000:
		var state: Dictionary=frame.snapshot()
		if frame.dialogue_visible():
			if state.phase in ["return_instructions","failure_instructions"]:
				if expect_death:check(false,"The damaged-ship loss regression unexpectedly completed the convoy");return false
				await capture("dekato-pilot-"+label+"-result")
				var expected: String="return_instructions" if success else "failure_instructions"
				check(briefing_seen and state.phase==expected and state.campaign_cursor==38 and firing_frames>0,"Input-only "+label+" branch did not reach its original result")
				if state.phase!=expected:return false
				check(selected.all(func(id):return state.encounter.combat.actors[id].actor_mode==4),"Input-only result bypassed actual target retirement")
				check(state.player.vitals.hull>0 and state.progress.player_kills>before.progress.player_kills,"Input-only outcome lacks living-player combat evidence")
				check(unchanged_career_fields(before.contracts,state.contracts),"Input-only battle changed independent career state")
				var pages: int=2 if success else 1
				for page in pages:
					frame=result_next(frame,"next")
					if frame==null:return false
					if page==0 and success:await capture("dekato-pilot-success-second")
				var completed: Dictionary=frame.snapshot()
				check(completed.campaign_cursor==(39 if success else 38) and frame.contract_owner()!=null and frame.contract_owner().snapshot()==completed.contracts,"Input-only acknowledgement lost its retained native career")
				check(unchanged_career_fields(before.contracts,completed.contracts) and completed.reward_credits==0,"Input-only acknowledgement paid or replaced the independent job")
				check(frame.prepare_station().is_empty() and Archive.new().capture(frame,frame._story_bindings).is_empty(),"A selected input-only battle manufactured an earned station save")
				if success:await capture("dekato-pilot-flight-continued")
				else:check(frame.prepare_game_over().get("source_state")==1,"Input-only convoy failure lost its source exit")
				print("Dekato input-only ",label,": frames=",tick," firing=",firing_frames," kills=",int(completed.progress.player_kills)-int(before.progress.player_kills)," hull=",completed.player.vitals.hull," career=",completed.contracts.campaign_cursor,"; explicit component entry, not an earned203 save")
				return true
			check(not briefing_seen and state.dialogue.voice_event_id==184,"Input-only branch encountered an unexpected briefing")
			briefing_seen=true;frame=result_next(frame,"next")
			if frame==null:return false
			continue
		if frame.death_active():
			await capture("dekato-pilot-"+label+"-death")
			if expect_death:
				check(briefing_seen and damage_observed and state.player.vitals.hull<=0 and state.campaign_cursor==38 and not state.combat_objective_acknowledged,"Damaged-ship death bypassed actual combat or acknowledged the convoy")
				check(frame.contract_owner()!=null and frame.contract_owner().snapshot()==state.contracts and unchanged_career_fields(before.contracts,state.contracts),"Player death lost or paid the retained career")
				check(frame.prepare_station().is_empty() and Archive.new().capture(frame,frame._story_bindings).is_empty(),"A dead selected player acquired station persistence")
				print("Dekato input-only damaged-ship death at frame ",tick,"; firing=",firing_frames,"; career38 and independent job retained")
				return true
			check(false,"Input-only "+label+" pilot died at frame "+str(tick)+"; "+str(state.player.vitals));return false
		# The deliberate convoy-loss diagnostic first removes four attacking
		# escorts by normal fire, leaving one alive so victory cannot trigger.
		# It then targets the two freighters through the same physical controls.
		var targets: Array=selected
		if not success:
			var escorts: Array=[2,3,4,6].filter(func(id):return state.encounter.combat.actors[id].vitals.hull>0)
			if not escorts.is_empty():targets=escorts
		var input: Dictionary=pilot.controls(state,tick,targets,true)
		# Continuous lateral input keeps the small ship moving around its aim
		# point rather than reversing through the escorts' retained shot paths.
		input.strafe=1.0
		if not expect_death and input.target>=0:
			# A wider freighter orbit reduces angular tracking speed and keeps
			# the launch point outside the large ship's native contact geometry.
			var firing_distance:=14000.0 if input.target in [0,1] else 2500.0
			input.throttle=1.0 if input.distance>firing_distance else 0.0
		if tick%200==0:print("Dekato input-only ",label," tick=",tick," target=",input.target," distance=",int(input.distance)," firing=",firing_frames," hull=",state.player.vitals.hull," actor hulls=",state.encounter.combat.actors.map(func(actor):return actor.vitals.hull))
		if session!=null:
			if session.can_control():
				for adjustment in 10:
					var throttle: float=session.snapshot().input_throttle
					if absf(throttle-float(input.throttle))<0.01:break
					if not session.action("throttle_up" if throttle<float(input.throttle) else "throttle_down"):check(false,session.error);return false
			now_us+=100000
			if not session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,session.error);return false
			frame=session.flight_owner()
		else:
			var next: RefCounted=frame.evaluate(100,input.commands,input.throttle,false,Vector2i(1280,720),Vector2.ZERO,input.fire,false,false,-1,input.strafe)
			if next==null:check(false,frame.error);return false
			frame=next
		if not damage_observed and frame.snapshot().player.vitals.hull<state.player.vitals.hull:
			damage_observed=true
			var volleys: Array=frame.snapshot().encounter.weapon_events
			print("Dekato input first hull loss at ",tick,"; player contacts=",volleys.filter(func(volley):return not volley.contacts.is_empty()).map(func(volley):return {"actor_id":volley.actor_id,"contacts":volley.contacts}),"; position=",frame.snapshot().player_pose.origin)
		if input.fire:firing_frames+=1
		if not live_captured and briefing_seen and firing_frames>10:
			await capture("dekato-pilot-flight-"+label);live_captured=true
		if tick%20==0:await process_frame
	check(false,"Input-only "+label+" flight exhausted its bounded control allowance")
	return false

## The stimuli are explicit lethal native contacts, not pilot-input evidence.
## Only the real actor/destruction/accounting owners can produce mode4 here;
## the tests never set actor modes, result modes, objective flags or progress.
func retired_branch(parent: RefCounted,ids: Array) -> RefCounted:
	var branch: RefCounted=parent.fork_for_frame()
	var encounter: RefCounted=branch._encounter
	var control: RefCounted=encounter._control.fork_for_frame(false,encounter._combat)
	var bodies: RefCounted=control.combat_owner()
	if not bodies.begin_contact_pass(branch._random,true):check(false,bodies.error);return null
	for id in ids:
		if bodies.normal_hit(int(id),1000000,false).is_empty():check(false,bodies.error);return null
	check(ids.all(func(id):return bodies.actor_snapshot(id).vitals.hull==0 and bodies.actor_snapshot(id).actor_mode!=4),"Lethal contact bypassed native retirement")
	var target:={"base_content_id":bindings_id(parent,"base_content_id"),"binding_id":bindings_id(parent,"binding_id"),
		"pose":branch._pose,"ship_id":0,"active":false,"hull":67,"special_flight":false,"targeting_blocked":false,"alternate_position":null}
	var random: Dictionary=bodies.contact_random_state()
	var operation: Dictionary=control.advance(100,target,bodies,random)
	if operation.is_empty():check(false,control.error);return null
	random=operation.random_state
	for tick in 600:
		if ids.all(func(id):return control._combat.actor_snapshot(id).actor_mode==4):break
		operation=control.advance(100,target,null,random)
		if operation.is_empty():check(false,control.error);return null
		random=operation.random_state
	check(ids.all(func(id):return control._combat.actor_snapshot(id).actor_mode==4),"Native retirement did not finish within the component bound")
	encounter._control=control;encounter._combat=control.combat_owner();branch._random=random
	return branch

func bindings_id(frame: RefCounted,key: String) -> String:return frame._entry[key]

func verify_results(parent: RefCounted,bindings: RefCounted) -> void:
	var preserved: Dictionary=parent.snapshot()
	var retained_career: Dictionary=parent.contract_owner().snapshot()
	check(parent._encounter.poll_mission_result(false,true).get("mode")==0,"Live actors completed the mission")
	check(not parent._encounter.acknowledge_mission_result(),"Unopened result accepted acknowledgement")
	var win: RefCounted=retired_branch(parent,range(2,7))
	if win==null:return
	var status: Dictionary=win._encounter._control.defeat_status()
	check(status.satisfied and not status.failed,"Five retired Mido escorts did not produce success-only readiness")
	check(win._encounter._control.career_snapshot().accounting.counter_deltas.player_kills==5,"Native result lost its five credited Mido defeats")
	# The source succeeds only after 5000ms, on an allowed idle-radio poll.
	for sample in [[5000,false,true,0],[5001,true,true,0],[5001,false,false,0],[5001,false,true,1]]:
		var probe: RefCounted=win._encounter.fork_for_frame()
		check(probe.sample_mission_clock(int(preserved.world_elapsed_ms),sample[0]),probe.error)
		var selected: Dictionary=probe.poll_mission_result(sample[1],sample[2])
		check(selected.get("mode")==sample[3],"Dekato success ignored the original HUD/idle-radio/periodic gate")
		if sample[0]==5001 and sample[1]:check(selected.get("clock_ms")==0,"Blocked due success poll failed to reset its clock")
	var single: RefCounted=retired_branch(parent,[0])
	if single==null:return
	check(not single._encounter._control.defeat_status().failed and single._encounter.poll_mission_result(true,false).get("mode")==0,"Losing only one freighter failed the convoy")
	var single_win: RefCounted=retired_branch(win,[0])
	if single_win==null:return
	check(single_win._encounter.sample_mission_clock(int(preserved.world_elapsed_ms),5001),single_win._encounter.error)
	check(single_win._encounter.poll_mission_result(false,true).get("mode")==1,"One surviving freighter prevented a completed escort victory")
	var both: RefCounted=retired_branch(parent,[0,1])
	if both==null:return
	check(both._encounter.sample_mission_clock(int(preserved.world_elapsed_ms),0),both._encounter.error)
	check(both._encounter.poll_mission_result(true,false).get("mode")==2 and not both._encounter._control.defeat_status().satisfied,"Both freighters lost with escorts still active failed to bypass time and radio gates")
	var all_retired: RefCounted=retired_branch(win,[0,1])
	if all_retired==null:return
	status=all_retired._encounter._control.defeat_status()
	check(status.satisfied and status.failed,"Independent all-retired source predicates were collapsed")
	for sample in [[0,true,false,2],[5000,false,true,2],[5001,true,true,2],[5001,false,false,2],[5001,false,true,1]]:
		var probe: RefCounted=all_retired._encounter.fork_for_frame()
		check(probe.sample_mission_clock(int(preserved.world_elapsed_ms),sample[0]),probe.error)
		var selected: Dictionary=probe.poll_mission_result(sample[1],sample[2])
		check(selected.get("mode")==sample[3],"Completion-first/failure-fallback order changed")
		check(probe.poll_mission_result(false,true)==selected,"An opened result changed on repeated polling")
	# The existing frame currently has active radio and a sub-threshold HUD
	# clock. Failure must still open on a zero-time pass, not a periodic tick.
	var losing: RefCounted=all_retired.evaluate(0)
	if losing==null:check(false,all_retired.error);return
	var failed: Dictionary=losing.snapshot()
	check(failed.phase=="failure_instructions" and failed.campaign_cursor==38 and not failed.combat_objective_satisfied,"Gated success suppressed an immediate convoy failure")
	check(failed.dialogue.count==1 and failed.dialogue.voice_event_id==-1 and failed.dialogue.text.contains("\n\n\n"),"Failure did not use the original silent combined page")
	check(losing.navigate("previous")==null and losing.navigate("next",true)==null and losing.snapshot()==failed,"Invalid or paused failure navigation mutated the frame")
	var exited: RefCounted=losing.navigate("next")
	if exited==null:check(false,losing.error);return
	check(exited.prepare_game_over().get("source_state")==1 and exited.snapshot().campaign_cursor==38 and exited.snapshot().reward_credits==0,"Failure acknowledgement advanced or rewarded the campaign")
	check(exited.contract_owner()!=null and exited.contract_owner().snapshot()==exited.snapshot().contracts and unchanged_career_fields(retained_career,exited.snapshot().contracts),"Failure lost or settled the independent career")
	check(exited.evaluate(100).snapshot()==exited.snapshot() and exited.navigate("next")==null,"Acknowledged failure resumed or acknowledged twice")
	check(losing.snapshot()==failed,"Failure acknowledgement mutated its parent")
	# Let the actual briefing and radio clocks select success in the live frame.
	if session!=null and not session._commit(win,false):check(false,session.error);return
	for tick in 180:
		if win.dialogue_visible():break
		win=advance(win,100)
		if win==null:return
	var opened: Dictionary=win.snapshot()
	check(opened.phase=="return_instructions" and opened.campaign_cursor==38 and opened.combat_objective_satisfied and not opened.combat_objective_acknowledged,"Live result skipped its two-page acknowledgement")
	if opened.phase!="return_instructions":return
	var events: Array=Rules.declarations(bindings).mission.result_events
	check(opened.dialogue.text_id==int(events[0].text_id) and opened.dialogue.voice_event_id==399 and opened.dialogue.count==2,"First original result page changed")
	check(win.navigate("previous")==null and win.navigate("next",true)==null and win.snapshot()==opened,"Rejected result input mutated the accepted frame")
	await capture("dekato-result-first")
	var frozen: RefCounted=win.evaluate(100,Vector2.ONE,1.0,false,Vector2i(1280,720),Vector2.ZERO,true,true)
	check(frozen!=null and frozen.snapshot().player_pose==opened.player_pose and frozen.snapshot().world_elapsed_ms==opened.world_elapsed_ms and frozen.snapshot().progress==opened.progress,"Result modal consumed time/input or auto-acknowledged")
	win=result_next(win,"next")
	if win==null:return
	check(win.snapshot().dialogue.text_id==int(events[1].text_id) and win.snapshot().dialogue.voice_event_id==400 and win.snapshot().campaign_cursor==38,"First Next advanced instead of showing the second original page")
	await capture("dekato-result-second")
	win=result_next(win,"previous")
	if win==null:return
	check(win.snapshot().dialogue.index==0 and win.snapshot().progress==opened.progress,"Previous changed the earned combat counters")
	win=result_next(win,"next")
	if win==null:return
	var second: Dictionary=win.snapshot()
	var invalid: RefCounted=win.fork_for_frame()
	check(invalid._encounter.acknowledge_mission_result(),invalid._encounter.error)
	var invalid_before: Dictionary=invalid.snapshot()
	check(invalid.navigate("next")==null and invalid.snapshot()==invalid_before,"Rejected controller retirement partially advanced the objective")
	for field in ["pending_result","campaign_cursor","binding_id"]:
		var rejected: RefCounted=win.fork_for_frame();rejected._convoy_career=win._convoy_career.fork()
		rejected._convoy_career._state[field]={"retained":true} if field=="pending_result" else 39 if field=="campaign_cursor" else "foreign"
		var before: Dictionary=rejected.snapshot();var ledger: Dictionary=rejected._convoy_career.snapshot()
		check(rejected.navigate("next")==null and rejected.snapshot()==before and rejected._convoy_career.snapshot()==ledger,"Rejected career partially retired the result or advanced the objective: "+field)
	var missing: RefCounted=win.fork_for_frame();missing._convoy_career=null
	var missing_before: Dictionary=missing.snapshot()
	check(missing.navigate("next")==null and missing.snapshot()==missing_before,"Acknowledgement silently discarded its admitted career")
	win=result_next(win,"next")
	if win==null:return
	var continued: Dictionary=win.snapshot()
	check(continued.campaign_cursor==39 and continued.mission=={"kind":11,"station_id":30,"reward":0,"bonus":0,"source_parameter":0},"Final Next did not select the exact original mission39")
	check(continued.combat_objective_acknowledged and not continued.cargo_objective_acknowledged and not continued.station_return_required and continued.reward_credits==0,"Acknowledgement invented a mining return or reward")
	check(continued.encounter.controller.mission_result.retired and continued.encounter.controller.mission_result.mode==0,"Final Next failed to retire the native result")
	check(continued.player_cache==second.player_cache and continued.equipment==second.equipment and continued.cargo==second.cargo,"Acknowledgement repaired or replaced retained player resources")
	check(continued.progress.rank_score==second.progress.rank_score+int(bindings.opening_handoff.cursor_weight),"Acknowledgement duplicated or lost campaign score")
	var career: RefCounted=win.contract_owner()
	check(career!=null and career.snapshot()==continued.contracts and career.snapshot().campaign_cursor==39 and unchanged_career_fields(retained_career,career.snapshot()),"Final acknowledgement lost or paid the retained delivery, wallet, locations, Void or blueprint owners")
	var acknowledged: Dictionary=career.snapshot()
	check(not career.advance_dekato_story(bindings,second.progress) and career.snapshot()==acknowledged,"Retained career acknowledged Dekato twice")
	check(win.prepare_station().is_empty() and Archive.new().capture(win,bindings).is_empty(),"A selected result manufactured physical docking or a station save")
	check(Navigation.destination_supported(bindings,39,continued.mission,30)==Navigation.Campaign.onward_available(bindings),"Pending Néhma travel ignored its attached source capability")
	check(win.navigate("next")==null,"Settled result accepted duplicate Next")
	win=advance(win,100)
	if win==null:return
	check(win.snapshot().world_elapsed_ms>continued.world_elapsed_ms and win.snapshot().progress==continued.progress and win.snapshot().encounter.campaign_cursor==38,"Pending39 replaced the native38 world or duplicated accounting")
	check(win.contract_owner().snapshot()==win.snapshot().contracts and unchanged_career_fields(retained_career,win.snapshot().contracts),"Continued flight lost its current native career")
	await capture("dekato-result-continued")
	if session!=null:check(session.objective_audio.snapshot().history.map(func(event):return event.source_id)==[399,400,399,400],"Result navigation did not play the original recordings in order")
	check(parent.snapshot()==preserved,"Result branches changed the retained live parent")
	print("Dekato result: native retirement, strict clock/radio gates, failure exit, original voices399/400, atomic retained career39 and immutable independent job/locations/Void/blueprints; component input, no earned travel/save claim")

func result_next(frame: RefCounted,action: String) -> RefCounted:
	if session!=null:
		if not session.navigate(action):check(false,session.error);return null
		return session.flight_owner()
	var next: RefCounted=frame.navigate(action)
	if next==null:check(false,frame.error)
	return next

## Alternate outcomes require independent presentation/audio sessions. Never
## rewind a live stream's serial or weaken its sequence checks for a fixture.
func render_failure(bindings: RefCounted,library: RefCounted,art: String,prepared: RefCounted) -> void:
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var prior: Node3D=session
	prior.scene.set_display_active(false)
	var losing_session:=Session.new();root.add_child(losing_session)
	if not losing_session.configure_dekato_selected(library,bindings,visuals,prepared,0,123) or not losing_session.activate():
		check(false,losing_session.error);losing_session.free();return
	var branch: RefCounted=retired_branch(losing_session.flight_owner(),range(7))
	if branch==null:losing_session.free();return
	var losing: RefCounted=branch.evaluate(0)
	if losing==null or not losing_session._commit(losing,false):
		check(false,branch.error+losing_session.error);losing_session.free();return
	check(losing.snapshot().phase=="failure_instructions" and losing.snapshot().hud_elapsed_ms==0,"Early rendered failure waited for a success poll")
	session=losing_session
	await capture("dekato-result-failure")
	check(session.objective_failure_audio.snapshot().history.is_empty(),"Silent failure played a success recording")
	check(session.navigate("next") and session.prepare_game_over().get("source_state")==1,session.error)
	session=prior;losing_session.free()

func advance(frame: RefCounted,milliseconds: int,commands:=Vector2.ZERO,fire:=false) -> RefCounted:
	if session!=null:
		now_us+=milliseconds*1000
		if not session.step(now_us,commands,fire):check(false,"Session frame: "+session.error);return null
		return session.flight_owner()
	var next: RefCounted=frame.evaluate(milliseconds,commands,1.0,false,Vector2i(1280,720),Vector2.ZERO,fire)
	if next==null:check(false,"Native frame: "+frame.error)
	return next

func capture(label: String) -> void:
	if session==null:return
	var state: Dictionary=session.presentation_snapshot()
	if not vitals.present(state) or not secondaries.present(session.secondary_feedback()):check(false,vitals.error+secondaries.error);return
	var hud_visible: bool=session.flight_hud_visible(state) and not session.map_open() and not session.secondary_menu_open()
	vitals.set_active(hud_visible);vitals.set_touch_inset(false)
	secondaries.set_hud_visible(hud_visible);secondaries.set_interaction(session.can_control(),false);secondaries.set_top_inset(vitals.top_inset())
	check(vitals.visible==(label in ["dekato-radio-flight","dekato-result-continued"] or label.begins_with("dekato-pilot-flight-")),"Host HUD visibility differs from the native entry/modal state")
	check(vitals._hull_text.text.begins_with(str(int(state.player.vitals.hull))+"/") and vitals._hull_badge.texture.get_meta("source_image_id")==1195,"Host HUD lost the surviving ship or original gauge art")
	check(secondaries._state==session.secondary_feedback() and secondaries._state.weapons.any(func(weapon):return weapon.item_id==41 and weapon.quantity==retained_emp_quantity),"Host HUD ammunition differs from its retained equipment slots")
	if captures.is_empty():check(false,"GPU integration requires its private capture directory");return
	if DirAccess.make_dir_recursive_absolute(captures)!=OK:check(false,"Cannot create private capture directory");return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image!=null and not image.is_empty() and image.save_png(captures.path_join(label+".png"))==OK,"Cannot capture "+label)

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)

func finish() -> void:
	print("Dekato selected flight: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
