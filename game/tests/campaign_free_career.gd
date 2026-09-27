extends "res://tests/campaign_ending_application.gd"
## Fresh-process continuation from a paid native ending save, with real docking.
func run_application() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	if not prepare_content(OS.get_cmdline_user_args()):finish();return
	captures=OS.get_environment("GOF2_CAPTURE_DIR");directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var earned:=OS.get_environment("GOF2_ENDING_PAID_SAVE")
	if earned.is_empty() or not PrivatePath.private_path(directory.path_join("station.gof2save")):
		check(false,"Free career requires a paid native save and isolated output");finish();return
	DirAccess.make_dir_recursive_absolute(captures)
	var visuals=load("res://src/content/visual_library.gd").new()
	cat=load("res://src/content/catalogues.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest) or not cat.open(library):check(false,visuals.error+cat.error);finish();return
	app=Host.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(library,bindings,visuals);app.set_player_mode(true);app.set_process(false);app.enable_saves(directory)
	slot=app.station_save_path();DirAccess.make_dir_recursive_absolute(slot.get_base_dir())
	if DirAccess.copy_absolute(earned,slot)!=OK:check(false,"Could not copy the paid checkpoint");done();return
	app.show();await process_frame;focus();await key(KEY_F9)
	if app.session==null:check(false,app._save_notice.text);done();return
	app.session.rebase_time(now_us);original=app.session.station_owner().snapshot()
	check(original.campaign_cursor==45 and original.mission.kind==-1 and original.contracts.passengers==3,"Paid Resume lost the empty campaign slot or carried passengers")
	for tick in 20:if not step():done();return
	check(not app.session.snapshot().dialogue.visible and not app.session.presentation_active(),"Paid Resume replayed the ending or Carla's note")
	if original.has("docking"):
		var saved: Dictionary=app._save_file.load_document(slot,bindings,cat,library)
		var intact:=FileAccess.get_file_as_bytes(slot)
		for fault in ["docking","history","reward"]:
			var invalid:=saved.duplicate(true)
			match fault:
				"docking":invalid.station.docking.pre_motion_contact=false;invalid.station.docking.post_motion_volume_index=-1
				"history":invalid.station.mission_station_return.erase("station_history")
				"reward":invalid.station.reward_credits=40000
			var archive=load("res://src/simulation/station_archive.gd").new()
			check(archive.restore(bindings,cat,library,invalid)==null,"Completed career accepted invalid "+fault)
		check(app.session.station_owner().snapshot()==original and FileAccess.get_file_as_bytes(slot)==intact,"Rejected continuation changed the live or saved career")
	if OS.get_environment("GOF2_FREE_CAREER_QUOTE_CHECK")=="1":
		verify_new_quotation()
		if failures:done();return
	await capture("free-career-resumed-station")
	await key(KEY_ENTER)
	if app._launch_packet.is_empty() or not app.enter_first_flight(now_us,4096,1789100000):
		check(false,"Paid departure: "+app.status.text);done();return
	app.session.rebase_time(now_us)
	var deadline:=now_us+30000000
	while not app.session.can_control() and now_us<deadline:
		if not step():done();return
		if frame_number%20==0:await process_frame
	check(app.session.can_control(),"Completed career did not release ordinary flight")
	var airborne: Dictionary=app.session.snapshot()
	check(airborne.campaign_cursor==45 and airborne.mission==original.mission and airborne.contracts.credits==original.contracts.credits and airborne.contracts.mission==original.contracts.mission and airborne.contracts.passengers==3,"Departure repeated payment or changed the carried job")
	for tick in 20:await process_frame
	await capture("free-career-flight")
	if OS.get_environment("GOF2_FREE_CAREER_RESUME_ONLY")=="1":done();return
	if OS.get_environment("GOF2_FREE_CAREER_TRAVEL")=="1" and not await visit_neighbour():done();return
	await key(KEY_Q);await key(KEY_DOWN);await key(KEY_ENTER)
	check(app.session.snapshot().station_autopilot.active,"Autopilot menu did not select the station")
	deadline=now_us+240000000
	while app.session.status!="station_transition_required" and now_us<deadline:
		if not step():done();return
		if frame_number%20==0:await process_frame
	check(app.session.status=="station_transition_required","Free-career autopilot did not reach physical docking")
	if failures or not app.enter_station(now_us,42):check(false,app.status.text);done();return
	app.session.rebase_time(now_us)
	for tick in 20:if not step():done();return
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(docked.campaign_cursor==45 and docked.contracts.credits==original.contracts.credits and docked.contracts.mission==original.contracts.mission and docked.contracts.passengers==3,"Docking repeated the reward or discarded the passenger job")
	var saved: Dictionary=app._save_file.load_document(slot,bindings,cat,library)
	check(not saved.is_empty() and saved.station.campaign_cursor==45 and saved.career.credits==original.contracts.credits and saved.station.has("docking"),"Docking did not autosave the completed career: "+app._save_file.error)
	await capture("free-career-docked")
	var report:=FileAccess.open(captures.path_join("journey.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"source_save":earned,"saved_file":slot,"cursor":docked.campaign_cursor,"credits":docked.contracts.credits,"passengers":docked.contracts.passengers,"checks":checks,"failures":failures},"  "))
	done()

func visit_neighbour() -> bool:
	var before: Dictionary=app.session.snapshot()
	var destination:=-1
	var locations: RefCounted=app.session.flight_owner().contract_owner().location_owner()
	for candidate in cat.tables.systems[before.location.system_id].station_ids:
		if int(candidate)!=before.location.station_id and int(candidate)!=before.contracts.mission.station_id:
			if destination<0:destination=int(candidate)
			if locations.location(int(candidate)).is_empty():destination=int(candidate);break
	# A one-station system must be left through its existing jumpgate.
	if destination<0:
		var availability: Array=app.session.flight_owner().contract_owner().location_owner().snapshot().system_availability
		for system in cat.tables.systems[before.location.system_id].linked_system_ids:
			var candidate:=int(cat.tables.systems[system].fields[int(bindings.mido_travel.free_navigation.gate_station_field)])
			if availability[system] and candidate>=0 and candidate!=before.contracts.mission.station_id:
				destination=candidate;break
	if destination<0:check(false,"No neighbouring station for the completed career");return false
	if not app.open_map(now_us) or not app.switch_map_system(int(cat.tables.stations[destination].system_id)):check(false,app.status.text);return false
	app.map_panel.select_station(destination);app.map_panel.request_confirmation()
	await capture("free-career-neighbour-map")
	if not app.confirm_map_planet(destination,now_us):check(false,app.status.text);return false
	app.session.rebase_time(now_us)
	var deadline:=now_us+240000000
	while app.session.status=="running" and now_us<deadline:
		if not step():return false
		if frame_number%20==0:await process_frame
	var gate: bool=app.session.status=="gate_confirmation_required"
	if gate:
		await capture("free-career-gate-confirmation")
		if not app.choose_gate_confirmation(0,now_us):check(false,app.status.text);return false
		app.session.rebase_time(now_us);deadline=now_us+30000000
		while app.session.status=="running" and now_us<deadline:
			if not step():return false
			if frame_number%20==0:await process_frame
	check(app.session.status==("gate_arrival_transition_required" if gate else "local_arrival_transition_required"),"Completed career could not travel: "+app.session.status)
	if failures:return false
	var entered: bool=app.enter_gate_arrival(now_us,4096,1789100000) if gate else app.enter_local_arrival(now_us,4096,1789100000)
	if not entered:check(false,app.status.text);return false
	app.session.rebase_time(now_us);deadline=now_us+30000000
	while not app.session.can_control() and now_us<deadline:
		if not step():return false
		if frame_number%20==0:await process_frame
	var arrived: Dictionary=app.session.snapshot()
	check(app.session.can_control() and arrived.location.station_id==destination and arrived.campaign_cursor==45 and arrived.mission==original.mission,"Neighbouring arrival changed the completed career")
	check(arrived.contracts.credits==original.contracts.credits and arrived.contracts.mission==original.contracts.mission and arrived.contracts.passengers==3,"Travel changed the retained wallet or passenger job")
	print("Completed career travelled from ",before.location.station_id," to ",destination)
	await capture("free-career-neighbour-arrival")
	return failures==0

## A separate component branch checks new quotation saving. Native generation
## supplies a fresh lounge fixture if the earned cache has no supported offer;
## this does not claim an earned new-job journey or change its carried passengers.
func verify_new_quotation() -> void:
	var source: RefCounted=app.session.station_owner()
	var unchanged: Dictionary=source.snapshot()
	var unavailable:={}
	for fixture in 33:
		var candidate: RefCounted=source.fork() if fixture==0 else quotation_fixture(source,fixture)
		if candidate==null:return
		var offers: Dictionary=candidate.snapshot().contracts.offers
		for contact in offers:
			var row: Dictionary=offers[contact]
			if row.consumed or row.offer.context.campaign_cursor!=45:continue
			var branch: RefCounted=candidate.fork()
			var terms: Dictionary=branch.contract_preview(int(contact),bindings)
			if terms.is_empty() or not terms.can_accept:
				unavailable[row.offer.mission.kind]=branch.error if terms.is_empty() else str(terms)
				continue
			if not branch.accept_contract(int(contact),true,bindings):check(false,branch.error);return
			var archive=load("res://src/simulation/station_archive.gd").new()
			var document: Dictionary=archive.capture(branch,bindings)
			if document.is_empty():check(false,archive.error);return
			var restored: RefCounted=archive.restore(bindings,cat,library,document)
			check(restored!=null,"A newly accepted post-ending job could not be saved: "+archive.error)
			if restored!=null:
				check(restored.snapshot().contracts.accepted_contact==branch.snapshot().contracts.accepted_contact and restored.snapshot().mission==unchanged.mission,"New job restoration changed its client or completed campaign")
			check(source.snapshot()==unchanged,"A detached job acceptance changed the actual passenger journey")
			print("Post-ending quotation component: kind ",row.offer.mission.kind,"; native generation fixture ",fixture)
			return
	check(false,"No affordable supported post-ending quotation fixture: "+str(unavailable))

func quotation_fixture(source: RefCounted,seed_value: int) -> RefCounted:
	var state: Dictionary=source.snapshot()
	var retained: RefCounted=source.contract_owner().location_owner()
	var location: Dictionary=retained.location(state.loadout.station_id)
	var context: Dictionary=location.population.context.duplicate(true)
	context.erase("system_availability");context.erase("difficulty")
	var settings: Dictionary=location.stock.context.duplicate(true)
	settings.erase("station_id");settings.erase("campaign_cursor")
	var cache=load("res://src/simulation/lounge_cache.gd").new()
	if not cache.configure(bindings):check(false,cache.error);return null
	cache._state.system_availability=retained.snapshot().system_availability.duplicate()
	var random=load("res://src/simulation/seeded_random.gd").new();random.seed_from(seed_value)
	if not cache.select_location(bindings,cat,library,context,settings,random.snapshot(),1789100000+seed_value,source.mission_station_context_owner()):check(false,cache.error);return null
	var branch: RefCounted=source.fork()
	branch._contracts._state.offers={};branch._contracts._state.erase("population")
	if not branch._contracts.retain_locations(cache):check(false,branch._contracts.error);return null
	return branch
