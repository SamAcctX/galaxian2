extends "res://tests/ordinary_void_combat.gd"
## Reuse the explicitly unsaved selected world and immutable paid32 parent.
## This checks a real session/drill, not earned source travel or the full50 hand-in.
const Session=preload("res://src/presentation/first_flight_session.gd")
const Placement=preload("res://tests/mining_session_placement.gd")
var now_us:=1000000

func test_label() -> String:return "Ordinary Void session and mining"

func prepare_player_station(library: RefCounted,bindings: RefCounted,cat: RefCounted,station: RefCounted) -> RefCounted:
	var original: Dictionary=station.snapshot();var branch: RefCounted=station.fork()
	var timestamps: Array=[1789100000,1789100000,1789100000]
	if not branch.open_equipment(bindings,cat,library,timestamps):check(false,branch.error);return null
	var inventory: Dictionary=branch.equipment_owner().snapshot()
	var rules: Dictionary=bindings.mining_targeting;var drill:={};var scanner:=-1
	for row in inventory.market_rows:
		var properties: Dictionary=cat.tables.items[int(row.item_id)].properties
		if properties.get(int(rules.item_kind_property))==int(rules.equipment_kind) and properties.get(int(rules.category_property))==int(rules.drill_category) and row.owned>0:
			drill=row;break
	for id in inventory.loadout.equipment_ids:
		var properties: Dictionary=cat.tables.items[int(id)].properties
		if properties.get(int(rules.item_kind_property))==int(rules.equipment_kind) and properties.get(int(rules.category_property))==int(rules.scanner_category):scanner=int(id)
	print("Mining hangar: cargo=",inventory.cargo.entries," slots=",inventory.loadout.slots," owned drill=",drill," scanner=",scanner)
	if drill.is_empty():check(false,"The earned inventory has no owned mining drill to fit");return null
	if not branch.equipment_action("mount",int(drill.item_id),bindings,cat):
		if scanner<0 or not branch.equipment_action("unmount",scanner,bindings,cat) or not branch.equipment_action("mount",int(drill.item_id),bindings,cat):check(false,branch.error);return null
	if not branch.close_equipment():check(false,branch.error);return null
	var fitted: Dictionary=branch.snapshot()
	check(station.snapshot()==original and fitted.contracts.credits==original.contracts.credits and fitted.campaign_cursor==32 and fitted.contracts.passengers==original.contracts.passengers,"Fitting an owned drill changed the parent save, wallet, passengers or campaign")
	check(int(drill.item_id) in fitted.loadout.equipment_ids,"The native hangar did not retain the equipped drill")
	return branch

func verify_live_void_frame(library: RefCounted,bindings: RefCounted,_cat: RefCounted,construction: RefCounted) -> void:
	var visuals:=Visuals.new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check(false,visuals.error);return
	var live:=Session.new();root.size=Vector2i(1280,720);root.add_child(live)
	var current:=Camera3D.new();root.add_child(current);current.make_current()
	if not live.has_method("configure_ordinary_void_selected"):
		check(false,"The selected ordinary Void has no public session constructor");live.free();current.free();return
	var prepared: Dictionary=construction.snapshot()
	if not live.configure_ordinary_void_selected(library,bindings,visuals,construction,now_us,1789100000,false):
		check(false,live.error);live.free();current.free();return
	check(root.get_camera_3d()==current and not live.can_control() and live.flight_audio!=null and live.flight_audio.snapshot().history.is_empty(),"Preparing the selected Void stole the camera or played unaccepted audio")
	var navigation=load("res://src/content/free_navigation_definitions.gd")
	check(navigation.destination_supported(bindings,34,navigation.Campaign.mission(bindings.mido_travel,34),30)==navigation.Campaign.nehma_available(bindings.mido_travel),"Selected Void support bypassed Nehma's separate station capability")
	check(not navigation.destination_supported(bindings,35,navigation.Campaign.mission(bindings.mido_travel,35),29),"Selected Void support opened the unimplemented Gakkrr35 campaign path")
	var initial: Dictionary=live.snapshot()
	check(initial.player.vitals==prepared.player.vitals and initial.cargo.entries==prepared.departure.cargo.entries,"Session setup reset the retained ship or cargo")
	check(live.flight_audio._npc_count==initial.actors.size() and live.flight_audio._npc_weapon_sounds.size()==initial.actors.size() and live.flight_audio._local_radio_rules.is_empty() and live.flight_audio._radio_voice.is_empty(),"Ordinary Void sound lost generated fighters or invented traffic/story speech")
	var rejected:=Session.new();root.add_child(rejected)
	check(not rejected.configure_ordinary_void_selected(library,bindings,visuals,FlightConstruction.new(),now_us,1789100000,false) and root.get_camera_3d()==current and live.snapshot()==initial,"Rejected selected construction replaced the accepted candidate")
	rejected.free()
	if not live.activate():check(false,live.error);live.free();current.free();return
	check(root.get_camera_3d()==live.camera and live.flight_audio._flight_serial==0,"Activation did not adopt the prepared Void presentation and audio together")
	check(not live.configure_ordinary_void_selected(library,bindings,visuals,construction,now_us,1789100000,false) and live.snapshot()==initial and root.get_camera_3d()==live.camera,"In-place selected preparation destroyed an active session")
	for _tick in 90:
		if not session_step(live,Vector2(0.2,-0.1)):live.free();current.free();return
	var flying: Dictionary=live.snapshot()
	check(live.can_control() and flying.world_phase_elapsed_ms==9000 and flying.player_pose!=initial.player_pose and flying.campaign_cursor==33,"Selected session failed to release real flight input")
	check(live.briefing_audio.snapshot().history.is_empty() and live.objective_audio.snapshot().history.is_empty() and flying.cargo.entries==initial.cargo.entries,"Ordinary session invented briefing, result speech or cargo")
	for reason in ["user","focus","hidden"]:
		check(live.set_pause(reason,true,now_us),live.error)
		var paused: Dictionary=live.snapshot()
		check(session_step(live) and live.snapshot()==paused and live.flight_audio.snapshot().paused and not live.action("missiles"),"Paused Void session advanced or accepted weapon input: "+reason)
		check(live.set_pause(reason,false,now_us),live.error)
	var accepted: Dictionary=live.snapshot();var sound: Dictionary=live.flight_audio.snapshot()
	var panel_identity: Dictionary=live.scene.game_over._identity.duplicate(true)
	live.scene.game_over._identity.binding_id="foreign"
	check(not live.step(now_us+100000) and live.snapshot()==accepted and live.flight_audio.snapshot()==sound,"Rejected Void rendering committed simulation, audio or random draws")
	live.scene.game_over._identity=panel_identity
	if not session_step(live,Vector2.ZERO,true):live.free();current.free();return
	check(live.flight_audio._flight_serial==live.snapshot().flight_audio.serial and not live.snapshot().encounter.primary_fire.is_empty(),"Retry did not commit the actual primary-weapon frame once")
	await capture_session(live,"void-session-flight")
	await verify_session_mining(live,bindings)
	var retained: Dictionary=live.snapshot();sound=live.flight_audio.snapshot()
	var candidate:=Session.new();root.add_child(candidate)
	check(not candidate.configure_void_return(library,bindings,visuals,live.flight_owner(),now_us,1789100000,1789100000,false) and live.snapshot()==retained and live.flight_audio.snapshot()==sound and root.get_camera_3d()==live.camera,"Rejected premature return lost the accepted session or fabricated a story return")
	candidate.free()
	await verify_session_portal(library,bindings,visuals,live)
	check(construction.snapshot()==prepared,"Running the session changed its prepared construction")
	live.free();current.free()

func verify_session_portal(_library: RefCounted,_bindings: RefCounted,_visuals: RefCounted,_live: Node) -> void:pass

func session_step(live: Node,command:=Vector2.ZERO,primary:=false) -> bool:
	now_us+=100000
	if not live.step(now_us,command,primary):check(false,live.error);return false
	return true

func verify_session_mining(live: Node,bindings: RefCounted) -> void:
	var world: RefCounted=live.flight_owner();var before: Dictionary=world.snapshot()
	var asteroid:={}
	# Keep every generated fighter active. Choose a real large asteroid and
	# isolate only approach placement, using the shared mining regression helper.
	for body in before.scenery.bodies.objects:
		if not body.get("mined",false) and (asteroid.is_empty() or body.source_size_value>asteroid.source_size_value):asteroid=body
	if asteroid.is_empty():check(false,"The actual Void field has no mineable crystal asteroid");return
	Placement.place(world,asteroid,bindings)
	if not live._commit(world,false) or not live.action("dock"):check(false,live.error);return
	for _tick in 200:
		if live.flight_owner().drill_owner()!=null:break
		if not session_step(live):return
	if live.flight_owner().drill_owner()==null:check(false,"The actual Void approach never reached drilling");return
	var drilling: Dictionary=live.snapshot()
	check(drilling.mining_session.drill.item_id==164 and drilling.cargo.entries==before.cargo.entries and drilling.actors.size()==before.actors.size(),"Drill setup changed the crystal identity, hold or generated fighter population")
	check(live.flight_audio.snapshot().active.has(1),"The accepted crystal drill did not start its original parameter-controlled sound")
	check(live.set_pause("user",true,now_us),live.error)
	var paused: Dictionary=live.snapshot()
	check(session_step(live) and live.snapshot()==paused and live.flight_audio.snapshot().paused,"Pause advanced the crystal drill or its cargo")
	check(live.set_pause("user",false,now_us),live.error)
	await capture_session(live,"void-session-drilling")
	for _tick in 800:
		var drill: Dictionary=live.snapshot().mining_session.drill
		if drill.is_empty():break
		var desired: Vector2=-(drill.point+(drill.input+drill.drift)*5.0)*.2-drill.drift
		var command:=Vector2.ZERO
		for axis in 2:command[axis]=signf(desired[axis])*sqrt(minf(1,absf(desired[axis])/3.0))
		if not session_step(live,command):return
	var mined: Dictionary=live.snapshot();var receipt: Dictionary=mined.mining_session.extraction
	if receipt.is_empty():check(false,"Actual crystal drilling did not produce an extraction receipt");return
	check(receipt.ore_item_id==164 and receipt.ore_tons>0 and receipt.cargo_added<=before.cargo.free_space and mined.cargo.used==before.cargo.used+receipt.cargo_added,"Crystal yield was missing, fabricated or exceeded the retained hold")
	check(mined.scenery.mined_count==before.scenery.mined_count+1 and mined.mining_session.drill.is_empty() and not live.flight_audio.snapshot().active.has(1),"Crystal extraction did not retire its asteroid and stop the drill once")
	# Mining statistics (medal producers) are recorded; the story progress is unchanged.
	var story: Dictionary=mined.progress.duplicate()
	for key in ["mined_ore_tons","mined_cores","mined_ore_types_mask","mined_core_types_mask"]:story.erase(key)
	check(mined.campaign_cursor==33 and mined.mission==before.mission and story==before.progress and mined.player.vitals.hull>0,"Crystal extraction completed the mission, granted progress or lost the living player")
	var held: Dictionary=live.snapshot();var sound: Dictionary=live.flight_audio.snapshot()
	check(live.flight_owner().stop_mining()==null and live.snapshot()==held and live.flight_audio.snapshot()==sound,"Repeating extraction changed the hold or sound")
	var inventory: RefCounted=live.flight_owner().equipment_owner()
	if not inventory.retain_flight_cargo(mined.cargo):check(false,inventory.error);return
	check(inventory.snapshot().cargo.entries==mined.cargo.entries,"The actual mined rows could not be retained for a future source-world return")
	print("Void crystal receipt: ",receipt)
	await capture_session(live,"void-session-mined")

func capture_session(live: Node,label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var args:=OS.get_cmdline_user_args()
	var directory: String=args[4] if args.size()==5 else OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	var retained: Dictionary=live.snapshot()
	for mobile in [false,true]:
		live.scene.set_mobile_layout(mobile)
		check(live.present_current(),live.error)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join("%s-%s.png"%[label,"phone" if mobile else "desktop"]))==OK,"Void session capture failed")
	live.scene.set_mobile_layout(false)
	check(live.snapshot()==retained,"Session capture changed the accepted simulation")
