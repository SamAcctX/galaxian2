extends SceneTree
## Synthetic native combat components, never an earned journey or saved career.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Rules=preload("res://src/content/dekato_convoy_definitions.gd")
const Story=preload("res://src/content/story_encounter_definitions.gd")
const World=preload("res://src/simulation/opening_world_initialization.gd")
const NativeControl=preload("res://src/simulation/combat_training_control.gd")
const Actor=preload("res://src/simulation/opening_combat_actor.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const FreightResources=preload("res://src/content/freighter_destruction_resources.gd")
const InventoryFixture=preload("res://tests/fixtures/bakka_equipment.gd")
const Objective=preload("res://src/simulation/dekato_convoy_objective.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Geometry=preload("res://src/presentation/ship_geometry.gd")
const FreightGeometry=preload("res://src/presentation/freighter_destruction_geometry.gd")
const Reputation=preload("res://src/simulation/faction_reputation.gd")
const TargetMembership=preload("res://src/content/contract_ship_combat_definitions.gd")
const MEMBERSHIPS=[[-1,2,3,4,5,6],[-1,2,3,4,5,6],[-1,0,1],[-1,0,1],[-1,0,1],[-1,0,1],[-1,0,1]]
const ENTRY={"companions_empty":true,"location_match":false,"special_placement":false}
var checks:=0
var failures:=0
var captures:=""
var art:=""

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size() not in [3,4]:check(false,"Expected content, bindings, visuals and optional captures");finish();return
	art=args[2]
	if args.size()==4:captures=args[3]
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);finish();return
	check(TargetMembership.target_memberships([3,3])==[[-1],[-1]],"Shared membership added same-faction peers")
	check(TargetMembership.target_memberships([8,0,8,0],[1,3])==[[-1,1,3],[0,2,-1],[-1,1,3],[0,2,-1]],"Shared contract player-last exception changed")
	check(Story.compose_dekato(bindings,cat,null).is_empty(),"Unconstructed combat was admitted")
	if not Rules.available(bindings):
		check(Story.compose_dekato(bindings,cat,load("res://src/simulation/opening_npc_construction.gd").new()).is_empty(),"Earlier bindings admitted Dekato combat")
		check(not Reputation.new().configure(bindings,38,[2,2,3,3,3,3,3],0.5,false,null,null,false,true),"Earlier bindings admitted Dekato's fixed reputation cast")
		finish();return
	for difficulty in [0.5,1.0]:await verify(library,bindings,cat,difficulty)
	finish()

func verify(library: RefCounted,bindings: RefCounted,cat: RefCounted,difficulty: float) -> void:
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,"station_id":22,"system_id":4,
		"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false,"rank":10,"difficulty":difficulty}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,"station_id":22,"system_id":4,"ship_id":0,"equipment_ids":[]}
	var world:=World.new()
	if not world.configure_dekato(bindings,cat,seed,context,ENTRY):check(false,world.error);return
	var generated:=world.generate({"state":42})
	if generated.is_empty():check(false,world.error);return
	var construction: RefCounted=world.npc_construction_owner()
	var packet: Dictionary=construction.snapshot()
	var data:=Story.compose_dekato(bindings,cat,construction)
	if data.is_empty():check(false,"Accepted Dekato world did not compose combat");return
	check(data.context_key=="dekato_context" and data.context==context and data.actor_count==7,"Combat lost selected world identity")
	check(data.player_weapon_targets==range(7) and data.target_memberships==MEMBERSHIPS,"Dekato inherited Void/player-last or same-faction targets")
	check(data.npc_weapons.slice(0,2).all(func(row):return row.get("unarmed",false)),"Freighters acquired weapons")
	check(data.npc_weapons.slice(2).all(func(row):return row.item_id==25 and row.catalogue_kind==2 and row.model_resource_id==6802 and row.nonplayer_source),"Mido escorts inherited Void weapons")
	check(data.freighter.hull_multiplier==5 and data.freighter.shield_multiplier==3 and data.freighter_death.model_id==18301 and data.freighter_death.actor_kind==2,"Nivelian combat/death profile changed")
	var fixture:=InventoryFixture.new();var equipment: RefCounted=fixture.create(bindings,cat,seed)
	if equipment==null:check(false,fixture.error);return
	var kept_equipment: Dictionary=equipment.snapshot()
	var reputation:={"axes":[0,0],"override":-1}
	var control:=NativeControl.new();var resources:=Resources.new();var freight:=FreightResources.new();var weapons:=Weapons.new()
	if not control._configure_story(bindings,cat,construction,equipment,reputation,data):check(false,control.error);return
	if not resources._configure_story(library,bindings,construction,data) or not freight._configure_story(library,bindings,data):check(false,resources.error+freight.error);return
	if not control.set_destruction(bindings,resources,freight) or not weapons._configure_encounter_weapons(bindings,cat,data):check(false,control.error+weapons.error);return
	var initial: Dictionary=control.snapshot()
	check(initial.combat.reputation.system_id==4 and initial.combat.reputation.actor_kinds==[2,2,3,3,3,3,3],"Combat reputation belongs to another system/cast")
	check(initial.combat.reputation.get("dekato_convoy",false) and not initial.combat.reputation.has("spawn_generations"),"Fixed story cast acquired recycled-traffic generations")
	var ordinary_history:=Reputation.new()
	check(ordinary_history.configure(bindings,38,[2,2,3,3,3,3,3],difficulty) and ordinary_history.snapshot().has("spawn_generations") and not ordinary_history.snapshot().get("dekato_convoy",false),"An ordinary cast with the same kinds was mistaken for Dekato")
	check(initial.combat.provocation.forced_hostile==[false,false,true,true,true,true,true] and initial.combat.provocation.permanent_hostile==[false,false,true,true,true,true,true],"Body and reaction force flags differ")
	for id in 7:
		var body: Dictionary=initial.combat.actors[id]
		check(body.active and body.actor_mode==0 and body.has("systems"),"Force flags replaced factory activity or systems")
		check(body.hostile==(id>=2) and body.friendly==(id<2) and body.permanent_friendly==(id<2),"Initial allegiance lost the source setter")
		check(body.script_hostile==(id>=2) and body.forced_hostile==(id>=2),"Persistent escort hostility missing")
		check(initial.destruction[id].cargo.entries==packet.actors[id].cargo,"Combat regenerated or discarded retained cargo")
		if id<2:check(body.point_boxes.size()==3 and body.point_box_index==0 and body.body_pose==packet.actors[id].body_pose,"Freighter lost original combat boxes or pose")
		var isolated:=Actor.new()
		if not isolated._configure_story(bindings,data,packet.actors[id]):check(false,isolated.error);continue
		for axis in [-100,0,100]:
			for forced in [false,true]:
				check(isolated.apply_free_hostility({"axes":[0,axis],"override":-1},forced,data.standing),isolated.error)
				check(isolated.snapshot().hostile==(id>=2) and isolated.snapshot().friendly==(id<2),"Standing/retaliation erased authored allegiance")
	var target:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"pose":Transform3D(Basis.IDENTITY,packet.actors[2].body_pose.origin+Vector3(0,0,4000)),
		"ship_id":0,"active":true,"hull":95,"special_flight":false,"targeting_blocked":false,"alternate_position":null}
	var random: Dictionary=generated.random_state
	var fired:=0;var convoy_requests:=0
	for tick in 80:
		# Explicit component input: later hide the player target to exercise
		# the same live selector against the stationary friendly freighters.
		target.active=tick<20
		if weapons.advance(100).is_empty():check(false,weapons.error);return
		var frame:=control.evaluate(null,weapons,100,target,random)
		if frame.is_empty():check(false,control.error);return
		control=frame.controller;weapons=frame.weapons;random=frame.random_state
		for event in frame.actors:
			if event.decision.get("fire_requested",false) and event.decision.get("target_actor_id",-1) in [0,1]:convoy_requests+=1
			for shot in event.firing.get("actors",[]):
				if shot.outcome.fired:fired+=1
	var live: Dictionary=control.snapshot()
	check(fired>0 and convoy_requests>0,"Live Mido guidance did not fire or select a convoy target")
	check(weapons.snapshot().actors.slice(0,2).all(func(row):return row.projectiles.is_empty() and row.definition.unarmed),"A stationary freighter produced a projectile pool")
	check(live.combat.actors.slice(2).all(func(row):return row.actor_mode==1 and row.active and row.hostile and not row.friendly),"Live fighter updates lost source allegiance/activity")
	for id in 2:check(live.combat.actors[id].body_pose==initial.combat.actors[id].body_pose and live.combat.actors[id].friendly,"Live convoy drifted or became hostile")
	check(live.combat.actors[2].body_pose!=initial.combat.actors[2].body_pose,"Fighter guidance never moved the live actor")
	if difficulty==0.5 and DisplayServer.get_name()!="headless":
		await render_native(library,bindings,packet,control,freight,"live",-1)
		await render_native(library,bindings,packet,control,freight,"escort",2)
	check(control.advance(-1,target,null,random).is_empty() and control.snapshot()==live,"Rejected frame partially committed combat")
	var hit: RefCounted=control.combat_owner()
	if not hit.begin_contact_pass(random,true) or hit.normal_hit(0,20,false).is_empty() or not hit.refresh_hostility(0):check(false,hit.error);return
	check(hit.snapshot().provocation.requested_damage[0]>0 and hit.actor_snapshot(0).friendly and not hit.actor_snapshot(0).hostile,"Friendly override discarded hit history or became hostile")
	var contact:=control.advance(100,target,hit,hit.contact_random_state())
	if contact.is_empty():check(false,control.error);return
	check(control.snapshot().combat.actors[0].friendly and not control.snapshot().combat.actors[0].hostile,"Native freighter update lost persistent friendliness after a hit")
	var objective:=Objective.new()
	if not objective.configure(bindings.mido_travel.dekato_convoy):check(false,objective.error);return
	var preserved: Dictionary=control.snapshot()
	var branch: RefCounted=control.fork_for_frame();var lethal: RefCounted=branch.combat_owner()
	if not lethal.begin_contact_pass(contact.random_state,true):check(false,lethal.error);return
	# Lethal inputs here are disclosed component stimuli, not pilot evidence.
	for id in range(2,7):
		if lethal.normal_hit(id,1000000,false).is_empty():check(false,lethal.error);return
	var first: Dictionary=branch.advance(100,target,lethal,lethal.contact_random_state())
	if first.is_empty():check(false,branch.error);return
	var status:=objective.observe(branch.snapshot().combat.actors)
	check(not status.satisfied and not status.failed and branch.snapshot().combat.actors.slice(2).all(func(row):return row.vitals.hull==0),"Zero hull skipped native fighter destruction")
	check(branch.snapshot().accounting.events.size()==5 and branch.snapshot().accounting.counter_deltas.player_kills==5 and branch.snapshot().accounting.counter_deltas.pirate_kills==0,"Mido deaths were counted as pirates or double-credited")
	random=first.random_state
	for _tick in 300:
		if status.satisfied:break
		var frame: Dictionary=branch.advance(100,target,null,random)
		if frame.is_empty():check(false,branch.error);return
		random=frame.random_state;status=objective.observe(branch.snapshot().combat.actors)
	check(status.satisfied and not status.failed,"Original fighter retirement did not satisfy condition18")
	lethal=branch.combat_owner()
	if not lethal.begin_contact_pass(random,true):check(false,lethal.error);return
	for id in 2:
		if lethal.normal_hit(id,1000000,false).is_empty():check(false,lethal.error);return
	first=branch.advance(100,target,lethal,lethal.contact_random_state())
	if first.is_empty():check(false,branch.error);return
	status=objective.observe(branch.snapshot().combat.actors)
	check(status.satisfied and not status.failed,"Zero-hull freighters bypassed their native animation")
	check(branch.snapshot().destruction.slice(0,2).all(func(row):return row.phase=="animation" and not row.fragments.is_empty()),"Live freighter death failed to sample delayed debris")
	if difficulty==0.5 and DisplayServer.get_name()!="headless":await render_native(library,bindings,packet,branch,freight,"freighter-destruction",0)
	random=first.random_state
	for _tick in 600:
		if status.failed:break
		var frame: Dictionary=branch.advance(100,target,null,random)
		if frame.is_empty():check(false,branch.error);return
		random=frame.random_state;status=objective.observe(branch.snapshot().combat.actors)
	check(status.satisfied and status.failed and status.convoy_destroyed==2,"Native freighter mode4 did not satisfy the independent failure condition")
	if difficulty==0.5 and DisplayServer.get_name()!="headless":await render_native(library,bindings,packet,branch,freight,"freighter-wreck",0)
	check(branch.snapshot().accounting.events.size()==7 and branch.snapshot().accounting.counter_deltas.player_kills==5,"Friendly freight deaths duplicated hostile kill rewards")
	var restored:=Reputation.new();var history: Dictionary=branch.snapshot().combat.reputation
	check(restored.restore(bindings,history) and restored.snapshot()==history,"Fixed-cast lethal history failed native restore")
	var exhausted: Dictionary=branch.snapshot().combat.actors[2]
	check(not restored.record_lethal(exhausted) and restored.snapshot()==history,"Duplicate lethal hit changed the fixed-cast reputation ledger")
	check(control.snapshot()==preserved,"A lethal component fork changed the live parent")
	check(world.snapshot()==generated and construction.snapshot()==packet and equipment.snapshot()==kept_equipment,"Combat mutated its generated world or detached inventory")

func render_native(library: RefCounted,bindings: RefCounted,packet: Dictionary,control: RefCounted,freight: RefCounted,label: String,focus: int) -> void:
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var state: Dictionary=control.snapshot()
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=10;camera.far=400000
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var center: Vector3=state.combat.actors[focus].body_pose.origin if focus>=0 else Vector3(90000,10000,80000)
	camera.look_at_from_position(center+Vector3(47000,64000,-72000),center)
	camera.size=42000 if focus<0 else (10000 if focus<2 else 1600)
	if label=="freighter-wreck":camera.size=16000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.65;viewport.add_child(environment)
	var labels:=[]
	for row in packet.actors:
		var id: int=row.actor_id
		if focus>=0 and id!=focus:continue
		var body: Dictionary=state.combat.actors[id]
		var death: RefCounted=control.destruction_owner(id)
		if id<2 and death.snapshot().phase in ["animation","wreck"]:
			var wreck:=FreightGeometry.new();viewport.add_child(wreck)
			check(wreck.build(library,visuals,bindings,freight,death) and wreck.apply_state(death,camera.global_transform),wreck.error)
		elif death.snapshot().phase=="ready":
			var ship:=Geometry.new();viewport.add_child(ship)
			var ready: bool=ship.build_population_assembly(row.assembly,library,visuals,bindings) if id<2 else ship.build(int(row.hull_catalogue_id),library,visuals,bindings)
			check(ready,ship.error)
			if ready:ship.transform=body.body_pose;check(ship.apply_selection({"visible":true,"level":0}),ship.error)
		if focus<0:
			var marker:=Label.new();marker.text="%d | %s"%[id,"FRIENDLY" if body.friendly else "HOSTILE"]
			var rect:=Rect2(camera.unproject_position(body.body_pose.origin)+Vector2(8,-22),Vector2(150,22))
			while labels.any(func(other):return rect.intersects(other)):rect.position.y-=24
			marker.position=rect.position;labels.append(rect);viewport.add_child(marker)
	var title:=Label.new();title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22)
	title.text="DEKATO 38 | NATIVE COMBAT COMPONENT: %s\nOriginal actor poses, allegiance and destruction. Campaign route remains closed."%label.to_upper();viewport.add_child(title)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();check(not image.is_empty(),"Live native combat did not render")
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
		var path:=captures.path_join("dekato38-combat-%s.png"%label)
		check(not FileAccess.file_exists(path) and image.save_png(path)==OK,"Capture already exists or cannot be saved")
	viewport.free()

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)

func finish() -> void:
	print("Dekato combat: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
