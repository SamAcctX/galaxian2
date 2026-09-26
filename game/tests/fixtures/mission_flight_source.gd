extends "res://tests/fixtures/selected40_navigation_checks.gd"
## Actual earned station/navigation, then an explicit detached late-portal
## stimulus. This is component coverage, never an input-earned mission41 claim.
var initialized: RefCounted
var departure: RefCounted
var retained_parent: RefCounted
var parent_snapshot:={}

## Exercise the native application route without assuming an adapter-specific
## snapshot's career field name. The native retained career owns that state.
func verify(station: RefCounted,visual_path: String) -> void:
	var original: Dictionary=station.snapshot();var art:=Visuals.new()
	if not art.open(visual_path,library.manifest):host.check(false,art.error);return
	host.root.content_scale_size=Vector2i.ZERO;host.root.size=Vector2i(1440,960)
	app=Host.new();host.root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(library,bindings,art);app.set_process(false);app._focused=true
	var restored:=StationSession.new();app.viewport.add_child(restored);restored._world=station.fork()
	if not restored._build_scene(library,bindings,art,cat,now,17) or not app.station_panel.configure_empty(library,bindings) or not restored.activate():host.check(false,restored.error+app.station_panel.error);return
	app.session=restored;app._locations=restored.location_owner()
	app.show();app.present_session();await host.process_frame;focus()
	if not app.request_departure() or not app.enter_first_flight(now,4096,123):host.check(false,app.status.text);return
	if not await release_entry():return
	for _leg in 24:
		var frame: RefCounted=app.session.flight_owner()
		if is_instance_of(frame,load("res://src/simulation/selected40_flight_frame.gd")):break
		var career: RefCounted=frame.contract_owner();var retained: Dictionary=career.void_source_state()
		var destination: int=retained.source_station_id
		if not app.open_map(now) or not app.switch_map_system(int(cat.tables.stations[destination].system_id)):host.check(false,app.status.text);return
		app.map_panel.select_station(destination);app.map_panel.request_confirmation()
		if not app.confirm_map_planet(destination,now):host.check(false,app.status.text+app.map_panel.error);return
		app.session.rebase_time(now)
		if not await advance_to_boundary(2400):return
		var gate: bool=app.session.status=="gate_confirmation_required"
		if gate:
			if not app.choose_gate_confirmation(0,now):host.check(false,app.status.text);return
			app.session.rebase_time(now)
			if not await advance_to_boundary(120):return
		var expected: String="gate_arrival_transition_required" if gate else "local_arrival_transition_required"
		if app.session.status!=expected:host.check(false,"Mission source travel stopped at "+app.session.status);return
		var prepare: Callable=app.enter_gate_arrival if gate else app.enter_local_arrival
		if not prepare.call(now,4096,123):host.check(false,app.status.text);return
		if not is_instance_of(app.session.flight_owner(),load("res://src/simulation/selected40_flight_frame.gd")) and not await release_entry():return
	if not is_instance_of(app.session.flight_owner(),load("res://src/simulation/selected40_flight_frame.gd")):host.check(false,"Earned navigation did not reach the selected source");return
	if not await continue_selected(original.contracts):return
	host.check(station.snapshot()==original,"Native navigation changed its earned station parent")

func continue_selected(original_career: Dictionary) -> bool:
	if not await super.continue_selected(original_career):return false
	retained_parent=app.session.flight_owner();parent_snapshot=retained_parent.snapshot()
	var branch: RefCounted=retained_parent.fork_for_frame()
	branch._encounter._selected40_sequence=branch._encounter._selected40_sequence.fork_for_frame()
	branch._encounter._selected40_sequence._state.phase=4
	branch._pose=Transform3D(Basis.IDENTITY,branch.portal_owner().portal_snapshot().position+Vector3(900,0,0))
	branch._statistics_pose=branch._pose
	var pools: Dictionary=branch.player_owner().snapshot().vitals
	if branch._player.normal_hit(int(pools.shield+pools.armor+pools.hull)-50).is_empty():host.check(false,branch._player.error);return false
	if not branch._portal.observe_contact({"player_pose":branch._pose,"environment_contact_enabled":true,"mining_active":false}) or not branch._resolve_portal_tail():host.check(false,branch.error+branch._portal.error);return false
	var entry: RefCounted=branch.prepare_successor41_entry(bindings)
	if entry==null:host.check(false,branch.error);return false
	var world: RefCounted=load("res://src/simulation/selected41_world_initialization.gd").new()
	if not world.prepare(bindings,cat,library,entry,1700000001,1700000002):host.check(false,world.error);return false
	departure=branch;initialized=world
	host.check(retained_parent.snapshot()==parent_snapshot,"Mission fixture changed the earned navigation parent")
	return true
