extends "res://tests/ordinary_void_session.gd"
## Selected integration, not a saved or earned mission33. The inherited fixture
## explicitly proposes Alioth98 as the portal source while its immutable paid32
## parent keeps the actual Dima91 source. Exercise both routes, without crediting
## that proposal as travel, a campaign result, a blueprint or a saved checkpoint.

func test_label() -> String:return "Ordinary Void selected portal roundtrip"

func selected_void_career(bindings: RefCounted,cat: RefCounted,departure: RefCounted,source: RefCounted) -> RefCounted:
	var parent: RefCounted=departure.contract_owner()
	var original: Dictionary=parent.snapshot()
	var proposal: RefCounted=parent.fork()
	# This component's selected cursor matches the inherited selected progress.
	# Use the existing counter validator; never persist or label it earned.
	if not proposal._retain_story_progress(bindings,original.progress,32,33,original.station_id,original.station_id,false):check(false,proposal.error);return null
	if not proposal.restore_void_career(bindings,cat,source.snapshot(),original.blueprints):check(false,proposal.error);return null
	var selected: Dictionary=proposal.snapshot()
	if not proposal.transfer_ordinary_void(bindings,selected.progress,source,true):check(false,proposal.error);return null
	check(parent.snapshot()==original and original.campaign_cursor==32 and original.void_source.source_station_id==91,"Selecting the component changed its actual paid32 parent")
	var entered: Dictionary=proposal.snapshot()
	check(entered.station_id==-1 and entered.campaign_cursor==33 and entered.progress==selected.progress and entered.lounges==selected.lounges,"The selected portal changed progress or selected a synthetic cached station")
	for key in ["credits","mission","passengers","blueprints","travel_statistics","void_source"]:
		check(entered[key]==selected[key],"The ordinary portal changed retained "+key)
	check(not proposal.transfer_ordinary_void(bindings,selected.progress,source,true) and proposal.snapshot()==entered,"The career accepted a duplicate entry")
	return proposal

func verify_session_portal(library: RefCounted,bindings: RefCounted,visuals: RefCounted,live: Node) -> void:
	var initial: Dictionary=live.snapshot()
	if not initial.has("contracts"):check(false,"The native Void frame dropped its supplied career");return
	check(initial.contracts.station_id==-1 and initial.contracts.campaign_cursor==33 and initial.contracts.progress==initial.progress,"Void gameplay lost its relocated career or live counters")
	if not contact_portal(live,bindings):return
	var departing: RefCounted=live.flight_owner();var retained: Dictionary=live.snapshot()
	var sound: Dictionary=live.flight_audio.snapshot()
	var dead: RefCounted=departing.fork_for_frame()
	if dead._player.normal_hit(1000000).is_empty():check(false,dead._player.error);return
	check(not dead.void_return_required() and dead.construct_void_return(bindings,Catalogues.new(),1789100000,1789100000)==null,"A destroyed ship used an entered ordinary portal")
	var rejected:=Session.new();root.add_child(rejected)
	check(not rejected.configure_void_return(library,bindings,visuals,departing,now_us,-1,1789100000,false),"An invalid environment time produced a return world")
	check(live.snapshot()==retained,"Rejected return changed the accepted simulation")
	check_retained_audio(live,sound,"Rejected return changed the accepted audio")
	check(root.get_camera_3d()==live.camera,"Rejected return changed the accepted camera")
	rejected.free()
	var returned:=Session.new();root.add_child(returned)
	if not returned.configure_void_return(library,bindings,visuals,departing,now_us,1789100000,1789100000,false):check(false,returned.error);returned.free();return
	var arrival: Dictionary=returned.snapshot()
	check(live.snapshot()==retained,"Preparing a valid return changed the accepted simulation")
	check_retained_audio(live,sound,"Preparing a valid return changed the accepted audio")
	check(root.get_camera_3d()==live.camera,"Preparing a valid return changed the accepted camera")
	check_transfer(retained,arrival,false)
	check(returned.scene.station!=null and returned.scene.planets!=null and returned.scene.portal!=null and returned.scene.void_environment==null,"The ordinary return did not rebuild its real station, planets and source portal")
	check(arrival.void_portal_contact.ordinary_mode=="source_entry" and not returned.flight_owner().void_return_required(),"The return reused its already-entered portal contact")
	if not returned.activate():check(false,returned.error);returned.free();return
	live.clear()
	check(root.get_camera_3d()==returned.camera,"Retiring the old Void session cleared the new source camera")
	for _tick in 400:
		if returned.can_control():break
		if not session_step(returned):returned.free();return
	check(returned.can_control(),"The ordinary source return never released native flight control")
	if not returned.can_control():returned.free();return
	await capture_session(returned,"void-source-return")
	if not contact_portal(returned,bindings):returned.free();return
	var source_departure: Dictionary=returned.snapshot()
	var again:=Session.new();root.add_child(again)
	if not again.configure_void_return(library,bindings,visuals,returned.flight_owner(),now_us,1789100001,1789100001,false):check(false,again.error);again.free();returned.free();return
	var second: Dictionary=again.snapshot()
	check_transfer(source_departure,second,true)
	check(second.void_portal_contact.ordinary_mode=="void_return" and again.scene.station==null and again.scene.void_environment!=null,"A second source entry fell into the old story return or ordinary space")
	check(second.cargo.entries==retained.cargo.entries,"Returning and re-entering duplicated or discarded mined crystals")
	check(returned.snapshot()==source_departure and root.get_camera_3d()==returned.camera,"Preparing re-entry consumed the current source flight")
	if again.activate():
		returned.clear()
		check(root.get_camera_3d()==again.camera,"Re-entry failed to transfer the active camera")
		if session_step(again):await capture_session(again,"void-source-reentry")
	else:check(false,again.error)
	again.free();returned.free()

func check_retained_audio(live: Node,before: Dictionary,label: String) -> void:
	var after: Dictionary=live.flight_audio.snapshot()
	# Hardware playback continues while a candidate is built. Only an already
	# playing finite clip may naturally finish; retain every owner, event, loop,
	# pause flag, gain, random state and history entry, and forbid restarts.
	for id in before.active:
		if not after.active.has(id):continue
		if not before.active[id].looping and before.active[id].playing and not after.active[id].playing:
			print("Finite clip completed during portal preparation: ",id," ",before.active[id].name)
			after.active[id].playing=true
	check(after==before,label)

func check_transfer(before: Dictionary,after: Dictionary,entering: bool) -> void:
	var source: Dictionary=before.contracts.void_source
	var station: int=-1 if entering else int(source.source_station_id)
	var system: int=-1 if entering else int(source.source_system_id)
	check(after.campaign_cursor==33 and after.progress==before.progress and after.mission==before.mission,"An ordinary portal advanced or rewarded the story")
	check(after.equipment.loadout.station_id==station and after.equipment.loadout.system_id==system and after.contracts.station_id==station,"The portal selected a location other than its recorded source")
	check(after.player.vitals.hull==before.player.vitals.hull and after.player.vitals.armor==before.player.vitals.armor and after.player.vitals.shield==int(before.player.vitals.shield) and after.player.gamma==int(before.player.gamma),"The portal repaired, refilled or lost surviving ship pools")
	check(after.cargo.entries==before.cargo.entries and after.equipment.loadout.equipment_ids==before.equipment.loadout.equipment_ids and after.equipment.loadout.slots==before.equipment.loadout.slots,"The portal changed mined cargo, equipment or ammunition")
	for key in ["credits","mission","passengers","blueprints","travel_statistics","void_source","lounges"]:
		check(after.contracts[key]==before.contracts[key],"The portal changed retained "+key)

func contact_portal(live: Node,bindings: RefCounted) -> bool:
	# Wait for the generated portal clock; place only a physical contact sample.
	# The real frame loop, not this test, must set its entered/transition state.
	for _tick in 1000:
		var owner: RefCounted=live.flight_owner().void_portal_owner()
		var portal: Dictionary=owner.portal_snapshot()
		if portal.visible and portal.elapsed_ms<int(owner._rules.portal.close_start_ms)-1000:break
		if not session_step(live):return false
	var world: RefCounted=live.flight_owner()
	var portal: Dictionary=world.void_portal_owner().portal_snapshot()
	Placement.place_pose(world,Transform3D(Basis.IDENTITY,portal.position),bindings)
	if not live._commit(world,false):check(false,live.error);return false
	if not session_step(live):return false
	var contacted: bool=live.flight_owner().void_return_required()
	check(contacted and live.snapshot().void_portal_contact.portal_entered and live.snapshot().boundary=="void_return_transition_required","Physical ordinary portal contact did not request its native transition")
	return contacted
