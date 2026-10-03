extends RefCounted
## Actual application travel from the unmodified earned20240 checkpoint.
## The test chooses courses and advances ordinary controls/clocks, never poses,
## location/cursor fields, equipment, damage or encounter completion flags.
const Host=preload("res://src/presentation/opening_preview.gd")
const StationSession=preload("res://src/presentation/station_session.gd")
const SelectedSession=preload("res://src/presentation/mission_session.gd") # selected flights run in the shared mission session
const Visuals=preload("res://src/content/visual_library.gd")
const Navigation=preload("res://src/simulation/system_navigation.gd")
var host: SceneTree
var app: Control
var library: RefCounted
var bindings: RefCounted
var cat: RefCounted
var now:=1000000
var hops:=[]

static func run(tree: SceneTree,content: RefCounted,definitions: RefCounted,catalogues: RefCounted,station: RefCounted,visual_path: String) -> void:
	var probe=load("res://tests/fixtures/selected40_navigation_checks.gd").new()
	probe.host=tree;probe.library=content;probe.bindings=definitions;probe.cat=catalogues
	await probe.verify(station,visual_path)
	if is_instance_valid(probe.app):probe.app.free()

func verify(station: RefCounted,visual_path: String) -> void:
	var original: Dictionary=station.snapshot()
	if not verify_source_selection(station):return
	var art:=Visuals.new()
	if not art.open(visual_path,library.manifest):host.check(false,art.error);return
	host.root.content_scale_size=Vector2i.ZERO;host.root.size=Vector2i(1440,960)
	app=Host.new();host.root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(library,bindings,art);app.set_process(false);app._focused=true
	var restored:=StationSession.new();app.viewport.add_child(restored);restored._world=station.fork()
	if not restored._build_scene(library,bindings,art,cat,now,17) or not app.station_panel.configure_empty(library,bindings) or not restored.activate():host.check(false,restored.error+app.station_panel.error);return
	app.session=restored;app._locations=restored.location_owner()
	app.show();app.present_session();await host.process_frame;focus()
	host.check(not Host.FirstFlightSession.FreeFlight.Campaign.supported(bindings.mido_travel,40),"Raw merged declarations admitted optional40 navigation")
	if not app.request_departure():host.check(false,app.status.text);return
	var launch: Dictionary=app._launch_packet.duplicate(true)
	app.cancel_departure()
	# Requesting departure banks the docked ship's career stats (medals); nothing else changes.
	var after_cancel: Dictionary=app.session.station_owner().snapshot()
	var banked: Dictionary=after_cancel.contracts.get("stats",{})
	after_cancel.contracts.erase("stats")
	var unbanked: Dictionary=original.duplicate(true);unbanked.contracts.erase("stats")
	host.check(station.snapshot()==original and after_cancel==unbanked and banked.has("max_primaries"),"Cancelled launch changed the earned station")
	if not app.request_departure() or not app.enter_first_flight(now,4096,123):host.check(false,app.status.text);return
	var departure: Dictionary=app.session.snapshot()
	host.check(departure.location.station_id==original.loadout.station_id and departure.location.system_id==original.loadout.system_id and departure.campaign_cursor==40,"Actual launch teleported the retained station")
	host.check(launch.mission==original.mission and departure.mission==original.mission,"Launch rewrote the pending -1 story target")
	# Ordinary station departure starts with full armor/shield (prepare_free passes no flight cache).
	host.check(departure.player.vitals.hull==original.player_cache.values.hull,"Departure repaired retained hull")
	check_career(departure.contracts,original.contracts)
	if not await release_entry():return
	await capture("navigation40-nehma-departure")
	for leg in 24:
		if app.session is SelectedSession:break
		var frame: RefCounted=app.session.flight_owner();var before: Dictionary=frame.snapshot()
		var career: RefCounted=career_of(frame);var saved_source: Dictionary=career.void_source_state()
		var navigation:=Navigation.new()
		if not navigation.configure(bindings,cat,career.location_owner().snapshot().system_availability):host.check(false,navigation.error);return
		var destination: int=saved_source.source_station_id
		var detour: bool=OS.get_environment("GOF2_SELECTED40_NAVIGATION_DETOUR")=="1"
		if detour:
			for id in cat.tables.systems[before.location.system_id].station_ids:
				if id!=before.location.station_id and id!=saved_source.source_station_id and id!=original.contracts.mission.station_id:destination=int(id);break
			if destination==saved_source.source_station_id:host.check(false,"No ordinary local destination to exercise reroll arrival");return
		var course: Dictionary=navigation.course(before.location.station_id,destination)
		if course.is_empty():host.check(false,navigation.error);return
		print("Native40 course ",leg,": ",course,"; source before ",saved_source)
		if not app.open_map(now) or not app.switch_map_system(int(cat.tables.stations[destination].system_id)):host.check(false,app.status.text);return
		app.map_panel.select_station(destination);app.map_panel.request_confirmation()
		if leg==0:await capture("navigation40-retained-source-map")
		if not app.confirm_map_planet(destination,now):host.check(false,app.status.text+app.map_panel.error);return
		app.session.rebase_time(now)
		if not await advance_to_boundary(2400):return
		var gate: bool=app.session.status=="gate_confirmation_required"
		if gate:
			if not app.choose_gate_confirmation(0,now):host.check(false,app.status.text);return
			app.session.rebase_time(now)
			if not await advance_to_boundary(120):return
		var expected: String="gate_arrival_transition_required" if gate else "local_arrival_transition_required"
		if app.session.status!=expected:host.check(false,"Native travel stopped at "+app.session.status);return
		var source_frame: RefCounted=app.session.flight_owner();var frozen: Dictionary=source_frame.snapshot()
		var arriving: Dictionary=source_frame.prepare_gate_arrival() if gate else source_frame.prepare_local_arrival()
		var prepare: Callable=app.enter_gate_arrival if gate else app.enter_local_arrival
		if leg==0:
			host.check(not prepare.call(now,-1,123) and app.session.flight_owner().snapshot()==frozen,"Failed construction partially committed travel")
		if not prepare.call(now,4096,123):host.check(false,app.status.text);return
		host.check(source_frame.snapshot()==frozen,"Destination construction mutated the retained departing world")
		hops.append({"from":before.location.station_id,"arrival":arriving,"gate":gate,"source_before":saved_source})
		if app.session is SelectedSession:
			var world: RefCounted=app.session.flight_owner();var selected: Dictionary=world.environment_state().entry
			host.check(selected.source_before==saved_source and selected.station_id==saved_source.source_station_id and selected.selected40,"Actual selected arrival used the rerolled source or guessed a destination")
			host.check(world.player_owner().loadout().station_id==selected.station_id,"Native equipment did not follow its completed travel")
			check_career(world.career_owner().snapshot(),original.contracts)
			host.check(world.player_owner().loadout().equipment_ids==original.loadout.equipment_ids,"Travel granted or removed equipment")
			host.check(world.frame_context().encounter.view.player_aim.viewport_size==app.viewport.size,"Selected arrival replaced the native viewport with a fixture size")
			host.check(world.career_owner().snapshot().travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+1,"The actual gate arrival was counted more or less than once")
			await capture("navigation40-actual-selected-arrival")
			if not await continue_selected(original.contracts):return
			break
		var arrived: Dictionary=app.session.snapshot()
		# The flight snapshot no longer carries the career; read its owner.
		var arrived_frame: RefCounted=app.session.flight_owner()
		arrived.contracts=career_of(arrived_frame).snapshot()
		check_career(arrived.contracts,original.contracts)
		if not await release_entry():return
		await capture("navigation40-leg-%02d"%leg)
		if detour:
			var selected: RefCounted=career_of(app.session.flight_owner()).selected40_entry_owner()
			var entry: Dictionary=selected.snapshot() if selected!=null else {}
			host.check(not gate and arrived.location.station_id==destination and entry.get("selected40")==false,"Actual local reroll arrival did not construct the ordinary destination")
			host.check(entry.get("source_before")==saved_source and entry.get("source_after")==arrived.contracts.void_source and entry.get("source_event") not in ["unchanged","skipped"],"Actual local arrival selected or rerolled the source twice")
			host.check(arrived.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used,"Local travel counted a jumpgate")
			for tick in 20:
				if not step():return
			host.check(app.session.can_control() and app.session.flight_hud_visible(),"Ordinary local arrival never returned native flight controls")
			host.check(station.snapshot()==original,"Ordinary local travel changed its canonical checkpoint parent")
			print("Native40 ordinary local arrival: ",hops,"; selection ",entry)
			return
	host.check(app.session is SelectedSession,"Native navigation never reached its current retained source")
	host.check(station.snapshot()==original,"Navigation rewrote the source station owner")
	print("Native40 completed travel legs: ",hops)

func verify_source_selection(station: RefCounted) -> bool:
	# A detached selector check, not a second earned journey. Its location
	# generation must keep the old-source decision through a qualifying reroll.
	var career: RefCounted=station.contract_owner();var before: Dictionary=career.snapshot()
	var other:=-1
	for id in cat.tables.systems[station.snapshot().loadout.system_id].station_ids:
		if id!=before.station_id and id!=before.void_source.source_station_id:other=int(id);break
	if other<0:host.check(false,"No local ordinary destination for the selector regression");return false
	var candidate: RefCounted=career.fork()
	var settings: Dictionary=Host.BASE_STOCK_SETTINGS.duplicate(true);settings.ship_price_percent=0;settings.difficulty=before.difficulty
	var random: Dictionary=career.location_owner().selection_state().random
	if not candidate.select_location(bindings,cat,library,other,settings,random,123):host.check(false,candidate.error);return false
	var entry: RefCounted=candidate.selected40_entry_owner();var observed: Dictionary=entry.snapshot() if entry!=null else {}
	host.check(not observed.is_empty() and observed.get("selected40")==false and observed.source_before==before.void_source,"Ordinary selection tested the rerolled source instead of its old source")
	host.check(observed.get("source_event") not in ["unchanged","skipped"] and observed.source_after==candidate.void_source_state(),"The native location selection lost its qualifying counter/reroll")
	host.check(candidate.location_owner().selection_state().random==observed.random_state,"Location and source committed different random streams")
	var accepted: Dictionary=candidate.snapshot();var accepted_entry: Dictionary=observed.duplicate(true)
	var bad: Dictionary=settings.duplicate(true);bad.difficulty=99.0
	host.check(not candidate.select_location(bindings,cat,library,other,bad,random,123) and candidate.snapshot()==accepted and candidate.selected40_entry_owner().snapshot()==accepted_entry,"Rejected location changed the prepared source decision")
	host.check(career.snapshot()==before and station.contract_owner().snapshot()==before,"Detached source selection changed its retained canonical parent")
	return true

func continue_selected(original_career: Dictionary) -> bool:
	app.session.rebase_time(now)
	var scene_id: int=app.session.scene.get_instance_id()
	for tick in 560:
		if not step():return false
		if tick in [70,539]:await capture("navigation40-selected-live-%d"%(tick+1))
		if tick%100==0:await host.process_frame
	var state: Dictionary=app.session.flight_owner().frame_context()
	host.check(app.session.scene.get_instance_id()==scene_id and state.elapsed_ms==56000 and state.boundary.is_empty(),"The reached encounter was only a screenshot or replaced its persistent scene")
	host.check(app.session.can_control() and app.session.flight_hud_visible(),"The actual selected encounter did not release flight controls and HUD")
	check_career(app.session.flight_owner().career_owner().snapshot(),original_career)
	if OS.get_environment("GOF2_SELECTED41_CONSTRUCTION_PROBE")=="1":
		# Separate, explicitly labelled detached regression. The actual40
		# journey above remains untouched; this does not earn its late phase.
		await load("res://tests/fixtures/selected41_construction_checks.gd").from_navigation(host,library,bindings,cat,app.session.flight_owner(),app.visuals)
	return true

func focus() -> void:
	app._focused=true
	for reason in ["user","hidden","focus"]:app.session.set_pause(reason,false,now)

func release_entry() -> bool:
	app.session.rebase_time(now)
	for tick in 90:
		if app.session.can_control():return true
		if not step():return false
		if tick%30==0:await host.process_frame
	host.check(false,"Native arrival controls never released: "+app.session.status)
	return false

func step() -> bool:
	focus();now+=100000
	if not app.session.step(now):host.check(false,app.session.error);return false
	return true

func advance_to_boundary(limit: int) -> bool:
	for tick in limit:
		if app.session.status!="running":return true
		if not step():return false
		if tick%200==0:await host.process_frame
	host.check(false,"Native guidance did not reach a travel boundary: "+str(app.session.snapshot().get("station_autopilot")))
	return false

## Ordinary flights name their career owner contract_owner; selected40 frames career_owner.
func career_of(frame: RefCounted) -> RefCounted:
	return frame.career_owner() if frame.has_method("career_owner") else frame.contract_owner()

func check_career(current: Dictionary,original: Dictionary) -> void:
	for key in ["campaign_cursor","credits","mission","passengers","completed_side_missions","delivery_statistics","serial"]:
		host.check(current.get(key)==original.get(key),"Navigation changed independent career field "+key)
	host.check(current.get("passengers")==3 and current.get("mission",{}).get("station_id")==99,"Story navigation settled the separate three-passenger job")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless" or host.captures.is_empty():return
	DirAccess.make_dir_recursive_absolute(host.captures)
	focus();app.present_session();await host.process_frame
	RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
	host.check(host.root.get_texture().get_image().save_png(host.captures.path_join(label+".png"))==OK,"Native navigation capture failed: "+label)
