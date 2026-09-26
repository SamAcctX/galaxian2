extends RefCounted
## Detached native late-portal regression, NOT an earned campaign41 save.
## The caller's explicit phase fixture tests real source-owned transactions.
const Entry=preload("res://src/simulation/selected41_portal_entry.gd")
const Builder=preload("res://src/simulation/selected41_construction.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Body=preload("res://src/simulation/opening_combat_actor.gd")
const Rules=preload("res://src/content/selected41_population_definitions.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
const PlayerEntry=preload("res://src/content/player_entry_definitions.gd")

static func from_navigation(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,parent: RefCounted,visuals: RefCounted) -> void:
	var original: Dictionary=parent.snapshot()
	host.check(not parent.successor41_ready(bindings) and parent.prepare_successor41_entry(bindings)==null,"Actual arrival without a late portal granted mission41")
	var branch: RefCounted=parent.fork_for_frame()
	branch._encounter._selected40_sequence=branch._encounter._selected40_sequence.fork_for_frame()
	branch._encounter._selected40_sequence._state.phase=4
	# This explicit detached setup isolates portal construction, not a claim
	# that flight input earned the late phase, gamma loss or nearby position.
	branch._pose=Transform3D(Basis.IDENTITY,branch.portal_owner().portal_snapshot().position+Vector3(900,0,0))
	branch._statistics_pose=branch._pose;branch._player._state.gamma=73.75
	host.check(branch._portal.observe_contact({"player_pose":branch._pose,"environment_contact_enabled":true,"mining_active":false}) and branch.portal_transition_required(),branch._portal.error)
	host.check(branch._resolve_portal_tail(),branch.error)
	var builder: RefCounted=run(host.check,bindings,cat,branch)
	host.check(builder!=null,"Actual navigation owner did not construct source41 components")
	# A detached accepted native hit, not an earned combat result. The low
	# surviving hull must not shrink the successor's ordinary factory capacity.
	var wounded: RefCounted=branch.fork_for_frame()
	# The encounter intentionally shares its read-only combat owner until a
	# normal frame replaces it. This direct component stimulus must fork it.
	wounded._encounter._combat=wounded._encounter._combat.fork_for_frame()
	var target: RefCounted=wounded._encounter._combat._writable(0)
	var hit: Dictionary=target.normal_hit(int(target.snapshot().vitals.hull)-1,true)
	host.check(not hit.is_empty() and target.snapshot().vitals.hull==1,target.error)
	host.check(wounded._resolve_portal_tail(),wounded.error)
	var wounded_builder: RefCounted=run(host.check,bindings,cat,wounded)
	host.check(wounded_builder!=null,"Damaged freighter did not retain a native successor")
	if wounded_builder!=null:
		var body: Dictionary=wounded_builder.snapshot().actors[0]
		host.check(body.vitals.hull==1 and body.max_hull>1,"Source41 healed damage or shrank factory capacity to surviving hull")
	if wounded_builder!=null and OS.get_environment("GOF2_SELECTED41_WORLD_PROBE")=="1":await load("res://tests/fixtures/selected41_world_checks.gd").run(host,library,bindings,cat,wounded,visuals)
	elif wounded_builder!=null and DisplayServer.get_name()!="headless":await render(host,library,bindings,visuals,wounded_builder)
	host.check(parent.snapshot()==original,"Detached source41 regression changed the actual40 navigation result")

static func render(host: SceneTree,library: RefCounted,bindings: RefCounted,visuals: RefCounted,builder: RefCounted,world: RefCounted=null,native: RefCounted=null,radio_views: Array=[],sequence_view:=false) -> void:
	var original: Dictionary=builder.snapshot();var cast: Dictionary=original.construction
	var native_state: Dictionary={} if native==null else native.snapshot()
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;host.root.add_child(viewport)
	var camera:=Camera3D.new();camera.near=1;camera.far=500000;viewport.add_child(camera);camera.current=true
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
	var geometry=load("res://src/presentation/ship_geometry.gd")
	var nodes:=[]
	for row in cast.actors:
		var model: Node3D=geometry.new();viewport.add_child(model)
		var built: bool=model.build_population_assembly(row.assembly,library,visuals,bindings) if row.subtype==1 else model.build(row.hull_catalogue_id,library,visuals,bindings)
		if not built:host.check(false,model.error);viewport.free();return
		model.transform=row.body_pose if native==null else native_state.combat.actors[row.actor_id].body_pose;host.check(model.apply_selection({"visible":true,"level":0}),model.error)
		nodes.append(model)
	var ship: Node3D=geometry.new();viewport.add_child(ship)
	if not ship.build(cast.player_ship_id,library,visuals,bindings):host.check(false,ship.error);viewport.free();return
	ship.transform=original.player_pose if native==null else native_state.player_pose;host.check(ship.apply_selection({"visible":true,"level":0}),ship.error)
	var identities: Array=nodes.map(func(node):return node.get_instance_id())
	var void_geometry: Node3D
	var world_state: Dictionary={} if world==null else world.snapshot()
	if world!=null:
		void_geometry=load("res://src/presentation/void_environment_geometry.gd").new();viewport.add_child(void_geometry)
		if not void_geometry.build(library,visuals,bindings,world.environment_owner()):host.check(false,void_geometry.error);viewport.free();return
		var field_geometry: Node3D=load("res://src/presentation/scenery_geometry.gd").new();viewport.add_child(field_geometry)
		if not field_geometry.build(world_state.scenery,library,visuals,bindings,"high",true):host.check(false,field_geometry.error);viewport.free();return
		host.check(field_geometry.objects.size()==world_state.scenery.objects.size(),"Source41 GPU field differs from its native contact population")
	var label:=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",22);viewport.add_child(label)
	label.text="MISSION 41 | NATIVE CONSTRUCTION\nOriginal Vossk freighter and seven Void fighters; actual script positions.\nPlayer hull%d / armor%d / gamma%d; retained freighter hull%d / capacity%d.\nDetached construction check — full world/session not activated."%[original.player.vitals.hull,original.player.vitals.armor,original.player.gamma,original.actors[0].vitals.hull,original.actors[0].max_hull]
	var center: Vector3=cast.actors[0].body_pose.origin
	if world!=null:label.text="MISSION 41 | NATIVE WORLD INITIALIZATION\nOriginal Void environment, field, Vossk freighter and seven fighters.\nRetained player pools, separate passenger job; actual arrival camera.\nDetached native candidate — live flight and Host swap not activated."
	var views: Array=["player-entry","freighter"] if world==null else ["arrival-camera","freighter","void-field"]
	if native!=null:
		center=native_state.combat.actors[0].body_pose.origin
		label.text="MISSION 41 | LIVE NATIVE NPC COMPONENT\nOriginal eight bodies: automatic steering, pre-motion firing, ordered contacts.\nNative simulation %dms; player pools and separate passenger job retained.\nDiagnostic renderer only — campaign sequence / full flight / Host swap pending."%native_state.elapsed_ms
		views=["freighter","fighters"]
	var radio_panel: Control
	if not radio_views.is_empty():
		var radio_resources=load("res://src/presentation/opening_radio_resources.gd").new()
		if not radio_resources.prepare(library,bindings,visuals,41):host.check(false,radio_resources.error);viewport.free();return
		radio_panel=load("res://src/presentation/radio_panel.gd").new();viewport.add_child(radio_panel)
		radio_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);radio_panel.set_top_inset(150)
		if not radio_panel.configure_selected41(library,bindings,world,radio_resources.speakers) or not radio_panel.configure_art(library,bindings,visuals):host.check(false,radio_panel.error);viewport.free();return
		views=["radio-keith","radio-errkt"]
		label.text="MISSION 41 | ORIGINAL RADIO\nNative scheduler, original source text, portraits, font and speech assets.\nDetached clock-boundary fixture over the same initialized eight bodies.\nCinematic / full flight / Host transition are not activated."
	if sequence_view:
		views=["attack-camera"]
		label.text="MISSION 41 | NATIVE ATTACK SHOT\nOriginal event4-start placement, fighter resets and actual retained camera.\nSame eight native bodies; 2000ms ordinary motion after the shot begins.\nDetached boundary fixture; later cinematics / full flight / Host swap pending."
	for view in views:
		if radio_panel!=null:host.check(radio_panel.present(radio_views[views.find(view)]),radio_panel.error)
		var eye: Vector3=original.player_pose.origin+Vector3(-4000,3000,-5000) if view=="player-entry" else center+Vector3(7500,4500,-10000)
		camera.look_at_from_position(eye,center)
		if view=="arrival-camera":camera.transform=world.camera_owner().snapshot().pose
		if view=="attack-camera":camera.transform=native_state.sequence.camera.pose
		if view=="void-field":camera.look_at_from_position(Vector3(-45000,20000,-55000),Vector3(-30000,0,30000))
		if view=="fighters":
			var fighter: Vector3=native_state.combat.actors[1].body_pose.origin
			camera.look_at_from_position(fighter+Vector3(500,400,-1200),fighter)
		if void_geometry!=null:
			var actual_view: Dictionary=world.camera_owner().snapshot();actual_view.pose=camera.transform
			host.check(void_geometry.advance(0,actual_view),void_geometry.error)
		await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
		host.check(nodes.map(func(node):return node.get_instance_id())==identities and builder.snapshot()==original,"Source41 presentation rebuilt actors or altered the native transaction")
		var image: Image=viewport.get_texture().get_image()
		host.check(image!=null and not image.is_empty(),"Source41 original construction produced no GPU image")
		if image!=null and not host.captures.is_empty():host.check(image.save_png(host.captures.path_join(("selected41-sequence-" if sequence_view else "selected41-" if radio_panel!=null else "selected41-npc-" if native!=null else "selected41-construction-" if world==null else "selected41-world-")+view+".png"))==OK,"Could not capture source41 native construction")
	if native!=null:host.check(native.snapshot()==native_state,"Source41 diagnostic renderer changed live NPC state")
	viewport.free()

static func run(check: Callable,bindings: RefCounted,cat: RefCounted,departure: RefCounted) -> RefCounted:
	var before: Dictionary=departure.snapshot()
	var old_gear: Dictionary=departure.equipment_owner().snapshot()
	var old_career: Dictionary=departure.career_owner().snapshot()
	check.call(departure.successor41_ready(bindings),"Native late portal did not authorize source41 preparation")
	var entry: RefCounted=departure.prepare_successor41_entry(bindings)
	check.call(entry!=null,departure.error)
	if entry==null:return null
	var retained: Dictionary=entry.snapshot();var gear: Dictionary=entry.equipment_owner().snapshot();var career: Dictionary=entry.career_owner().snapshot()
	check.call(entry.matches_departure(departure) and retained.source_state==2 and retained.campaign_cursor==41 and retained.mission.kind==4 and retained.mission.station_id==-1 and not retained.application_committed,"Typed native entry lost its source41 identity")
	check.call(career.campaign_cursor==41 and career.progress.campaign_cursor==41 and career.station_id==-1 and not career.has("flight"),"Source41 retained an old flight ledger or failed to advance the detached career")
	for key in ["mission","accepted_contact","passengers","credits","active_offer_id","result_serial","completed_side_missions","pending_result","last_result","delivery_statistics","void_source","blueprints","lounges"]:
		check.call(career.get(key)==old_career.get(key),"Source41 altered independent career state: "+key)
	var expected: Dictionary=old_gear.duplicate(true);expected.loadout.station_id=-1;expected.loadout.system_id=-1
	check.call(gear==expected,"Portal changed more than the detached inventory location")
	check.call(Cache.matches(retained.player_cache,gear.loadout,41),"Actual successor cache lost its relocated inventory identity")
	var player: Dictionary=departure.player_owner().snapshot()
	check.call(retained.player_cache.values=={"hull":int(player.vitals.hull),"armor":int(player.vitals.armor),"shield":int(player.vitals.shield),"gamma":int(player.gamma)},"Portal did not capture actual surviving pools using source truncation")
	check.call(not PlayerEntry.new().configure(bindings,41,-1,true,gear.loadout.ship_id),"Component construction admitted a generic or fabricated cursor41 entry")
	for unrelated in [null,RefCounted.new(),load("res://src/simulation/selected40_flight_frame.gd").new()]:
		var invalid:=Entry.new()
		check.call(not invalid.prepare(bindings,unrelated) and invalid.snapshot().is_empty(),"Unrelated object obtained a native successor")
	var observed: Dictionary=entry.snapshot();observed.player_cache.values.hull=1;observed.context.rank=0
	check.call(entry.snapshot()==retained,"Native portal observation aliases its state")
	check.call(not entry.prepare(bindings,departure) and entry.snapshot()==retained,"Repeated preparation replaced its native transaction")
	var repeated: RefCounted=departure.prepare_successor41_entry(bindings)
	check.call(repeated!=null and repeated.snapshot()==retained and repeated.career_owner().snapshot()==career,"Preparing another candidate consumed the live source career or advanced twice")
	var broken: RefCounted=departure.fork_for_frame();broken._state.portal_outcome.freighter_hull+=1
	check.call(not broken.successor41_ready(bindings) and broken.prepare_successor41_entry(bindings)==null,"A modified observation replaced actual freighter state")
	broken=departure.fork_for_frame();broken._state.portal_outcome.next_cursor=42
	check.call(broken.prepare_successor41_entry(bindings)==null,"A modified observation chose another campaign")
	broken=departure.fork_for_frame();broken._career=broken._career.fork();broken._career._state.passengers+=1
	check.call(broken.prepare_successor41_entry(bindings)==null,"A mismatched independent passenger branch obtained successor41")
	# The cast consumes a deliberately explicit component RNG, not a claimed
	# source41 environment/field. The future enclosing constructor supplies it.
	var builder:=Builder.new()
	check.call(not builder.prepare(bindings,cat,entry,{"state":-1}) and builder.snapshot().is_empty(),"Invalid cast RNG partially committed native successor components")
	if not builder.prepare(bindings,cat,entry,{"state":42}):check.call(false,builder.error);return null
	var result: Dictionary=builder.snapshot();var cast: Dictionary=result.construction
	check.call(builder.matches_departure(departure) and cast.campaign_cursor==41 and cast.station_id==-1 and cast.system_id==-1 and cast.actors.size()==8,"Source41 construction impersonated another mission or world")
	check.call(not cast.has("selected40_context") and not cast.has("sahi_context") and not cast.has("void_context"),"Source41 reused a false40/25/29/33 identity")
	check.call(result.player_pose==Transform3D(Basis.IDENTITY,Vector3(3000,2000,-320000)),"Source41 omitted the script's actual player placement")
	check.call(result.player.vitals.hull==retained.player_cache.values.hull and result.player.vitals.armor==retained.player_cache.values.armor and result.player.vitals.shield==retained.player_cache.values.shield and result.player.gamma==retained.player_cache.values.gamma,"Source41 player construction reset surviving pools or gamma")
	for id in 8:
		var row: Dictionary=cast.actors[id];var body: Dictionary=result.actors[id]
		check.call(row.actor_id==id and row.actor_kind==(1 if id==0 else 9) and row.subtype==(1 if id==0 else 0) and row.hull_catalogue_id==(13 if id==0 else 8),"Source41 changed its original eight-actor factory order")
		var point: Array=Rules.VALUES.positions[id]
		check.call(row.body_pose==Transform3D(Basis.IDENTITY,Vector3(point[0],point[1],point[2])) and row.statistics_pose==row.body_pose,"Source41 changed fixed script placement")
		check.call(body.campaign_cursor==41 and body.station_id==-1 and body.active and body.selected41_component,"Source41 body has a stale world/activity identity")
		check.call(body.friendly==(id==0) and body.hostile==(id!=0),"Source41 body lost friendly freighter or persistent Void hostility")
		if id==0:
			check.call(row.assembly==bindings.mido_travel.vossk_traffic.assembly and row.cruise_enabled and row.cargo.size()>0 and row.retained_current_hull==retained.freighter_hull,"Source41 reused Terran assembly or discarded freighter state/cargo")
			var profile:=Rules.body_profile(bindings,cast)
			var base:=int(profile.rank_base)+int(profile.rank_multiplier)*int(profile.rank)+int(profile.cursor_multiplier)*41
			var capacity:=Body.scaled_hull(float(base*int(profile.freighter.hull_multiplier)),float(profile.difficulty),float(profile.difficulty_offset))
			check.call(body.vitals.hull==retained.freighter_hull and body.max_hull==maxi(capacity,retained.freighter_hull) and body.point_boxes.size()==5,"Freighter restoration shrank capacity or used Terran collision boxes")
		else:check.call(builder.npc_construction_owner().route(id).snapshot().campaign_cursor==41,"Source41 fighter route carries a false predecessor identity")
	check.call(not builder.prepare(bindings,cat,entry,{"state":2}) and builder.snapshot()==result,"Repeated native construction replaced a prepared cast")
	for value in [-2147483648,-1,0,1,1800,2147483647]:
		check.call(Rules.freighter_hull(value,0)==(value if value>0 else 1260),"Source41 positive hull carry or missing-state fallback changed")
	check.call(Rules.freighter_hull(0,21)==-1 and Rules.freighter_hull(2147483648,0)==-1,"Source41 accepted unsupported rank or hull overflow")
	check.call(entry.snapshot()==retained and departure.snapshot()==before and departure.equipment_owner().snapshot()==old_gear and departure.career_owner().snapshot()==old_career,"Source41 construction mutated its retained departure instead of staging a candidate")
	print("Source41 native transaction:8 actors,Vossk5boxes,hull%d/capacity%d,player%s,passengers%d,credits%d,serial%d; detached component only"%[retained.freighter_hull,result.actors[0].max_hull,result.player.vitals,career.passengers,career.credits,career.result_serial])
	return builder
