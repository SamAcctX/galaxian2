extends "res://tests/wingman_route_application.gd"
## Construct native owners from the earned flight, then exercise detached
## contacts and destruction. No diagnostic casualty enters the live career.
const IncomingGeometry=preload("res://src/presentation/wingman_geometry.gd")
const IncomingAudio=preload("res://src/presentation/opening_audio.gd")
var incoming_metrics:={}

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var original: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==original.contracts.wingmen and document.career.mission==original.contracts.mission and document.career.credits==original.contracts.credits,"Incoming Resume changed the earned crew, wallet or unfinished job")
	check(original.contracts.wingmen.active.get("names",[]).size()==3 and original.contracts.mission.get("kind")==2 and original.contracts.mission.station_id==original.loadout.station_id,"Incoming acceptance requires the actual paid cast and local Protection job")
	if failures or not await depart_for_lifetime():return
	var parent: RefCounted=app.session.flight_owner()
	var before: Dictionary=parent.snapshot()
	check(before.wingman_actors.destruction_connected and before.wingman_actors.incoming_contacts_connected,"The actual departure did not connect native incoming contacts and destruction")
	check(not before.wingman_actors.interactions_connected,"Contact support must not advertise unimplemented reciprocal aiming")
	if not failures:await verify_incoming_components(parent)
	check(parent.snapshot()==before and app.session.flight_owner().snapshot()==before,"A detached incoming diagnostic modified the live flight")
	if failures:return
	await capture_free_application("wingman-incoming-live")
	check(FileAccess.get_sha256(input_path)==input_hash,"Incoming acceptance modified its immutable earned input")
	if failures:return
	print("Incoming companion components accepted: ",{"input_sha256":input_hash,"earned_casualties":0,"earned_damage_verified":false,"components":incoming_metrics})

func verify_incoming_components(parent: RefCounted) -> void:
	var before: Dictionary=parent.snapshot()
	var crew: RefCounted=parent.wingman_owner()
	var cast_before: Dictionary=crew.snapshot()
	var enemies: RefCounted=parent.encounter_owner()
	var source_weapons: RefCounted=enemies._weapons
	check(crew.bind_incoming_weapons(source_weapons),crew.error)
	for index in 3:
		var body: Dictionary=crew.body_owner(index).snapshot()
		var systems: RefCounted=crew.body_owner(index).systems_for_frame()
		var death: Dictionary=crew.destruction_owner(index).snapshot()
		check(systems!=null and systems.snapshot().integrity>0 and body.permanent_friendly and body.friendly and not body.hostile and body.actor_mode in [0,1],"Ordinary initialization lost the paid pilot's allegiance, integrity or live lifecycle")
		check(death.phase=="ready" and death.fragments.size()>=3 and death.fragments.size()<=9 and death.fragments.all(func(piece):return piece.resource_id==14292 and piece.scale>=0.5 and piece.scale<1.0),"Companion destruction did not retain the original fragment population")
	var shooter:=-1
	var peer:=1
	var orders:=[]
	for id in source_weapons._guns.size():
		if source_weapons._guns[id]==null:continue
		var original: Array=source_weapons._training.target_memberships[id]
		var ordered: Array=source_weapons.companion_target_order(id,crew)
		check(ordered.filter(func(target):return target is int)==original,"Adding companions reordered existing native target members")
		var companions: Array=ordered.filter(func(target):return target is Dictionary)
		if id in source_weapons._training.get("companion_player_only_ids",[]):
			check(companions.is_empty(),"A player-only Protection shooter acquired companion contacts")
		else:
			check(companions.map(func(target):return int(target.index))==crew.contact_memberships(int(source_weapons._definitions[id].actor_kind)),"Companion contacts changed faction exclusion or paid-cast order")
			if id in source_weapons._training.get("companion_player_last_ids",[]):check(ordered.back()==-1,"Protection companion contacts were placed after the player")
		if shooter<0 and companions.any(func(target):return target.index==peer):shooter=id
		orders.append({"actor_id":id,"members":ordered})
	check(shooter>=0,"The earned Protection population has no eligible incoming diagnostic weapon")
	if failures:return
	var native_weapon: Dictionary=source_weapons._guns[shooter].snapshot().weapon
	check(enemies.combat_owner().supports_weapon_hit(native_weapon),"The incoming declaration differs from its native encounter")
	var forged: Dictionary=native_weapon.duplicate(true)
	forged.ordinary_hit_policy.nonplayer_damage+=1
	var unchanged: Dictionary=crew.snapshot()
	check(crew.weapon_hit(peer,forged).is_empty() and crew.snapshot()==unchanged,"An altered incoming damage declaration changed the cast")
	check(crew.weapon_hit(-1,native_weapon).is_empty() and crew.snapshot()==unchanged,"An invalid incoming target changed the cast")
	var emitted: RefCounted=source_weapons._guns[shooter].fork_state()
	var target: Dictionary=crew.body_owner(peer).snapshot()
	var fired:=false
	for attempt in 60:
		var shot: Dictionary=emitted.fire(target.pose.origin,target.pose.basis.z,true)
		if shot.is_empty():check(false,emitted.error);return
		if shot.fired:fired=true;break
		if emitted.advance(100).is_empty():check(false,emitted.error);return
	check(fired,"The detached native enemy gun could not emit its diagnostic round")
	if failures:return
	# Replace only a detached gun OWNER after native emission, never a slot
	# dictionary and never the application's encounter or earned statistics.
	var encounter: RefCounted=enemies.fork_for_frame()
	encounter._weapons=source_weapons.fork_for_frame()
	encounter._weapons._guns[shooter]=emitted
	var result: Dictionary=encounter.evaluate_weapons(parent._player,before.player_pose,0,parent._scenery,parent._random,true,true,-1,crew)
	check(not result.is_empty(),encounter.error)
	if failures:return
	crew=result.wingmen
	var contacts: Array=result.encounter.snapshot().weapon_events.filter(func(event):return event.actor_id==shooter)[0].wingman_contacts
	check(contacts.any(func(contact):return contact.actor_id==peer),"The mixed enemy pass omitted its eligible companion contact")
	var damaged: Dictionary=crew.body_owner(peer).snapshot()
	check(damaged.vitals.hull<target.vitals.hull and damaged.contact,"The admitted native projectile did not change hull and contact metadata")
	if native_weapon.ordinary_hit_policy.additional_damage_required:
		check(crew.body_owner(peer).systems_for_frame().snapshot().integrity<parent.wingman_owner().body_owner(peer).systems_for_frame().snapshot().integrity,"The native systems round omitted companion systems damage")
	check(result.encounter.snapshot().impact_visuals.hits.any(func(hit):return hit.key=="npc:%d"%shooter),"Incoming companion contact did not trigger its original impact model")
	check(result.encounter.combat_snapshot().actors.size()==before.encounter.combat.actors.size(),"Companion contact changed the mission population")
	check(parent.snapshot()==before and parent.wingman_owner().snapshot()==cast_before,"Incoming contact leaked into the retained parent or sibling")
	if failures:return
	var sibling: RefCounted=crew.fork_for_frame()
	var sibling_before: Dictionary=sibling.snapshot()
	var rounds:=0
	while crew.body_owner(peer).snapshot().vitals.hull>0 and rounds<2000:
		if crew.weapon_hit(peer,native_weapon).is_empty():check(false,crew.error);return
		rounds+=1
	check(crew.body_owner(peer).snapshot().vitals.hull==0 and crew.body_owner(peer).snapshot().nonplayer_kill,"Repeated canonical component rounds did not retain native lethal attribution")
	check(sibling.snapshot()==sibling_before and parent.snapshot()==before,"Lethal component damage escaped its detached branch")
	check(crew.casualty_bodies().size()==1,"The new incoming path did not expose exactly its depleted paid pilot")
	if failures:return
	incoming_metrics={"shooter":shooter,"orders":orders,"contact_count":contacts.size(),"canonical_component_rounds":rounds,"earned_rounds":0}
	await verify_detached_destruction(parent,crew,peer)
	check(parent.snapshot()==before,"Native destruction diagnostics changed the live earned flight")

func verify_detached_destruction(parent: RefCounted,crew: RefCounted,peer: int) -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var geometry:=IncomingGeometry.new();viewport.add_child(geometry)
	if not geometry.build(crew,source,visual,definitions):check(false,geometry.error);viewport.queue_free();return
	var live_scene: Node
	for node in app.find_children("*","",true,false):
		if node.get_script()==load("res://src/presentation/first_flight_scene.gd"):live_scene=node;break
	if live_scene==null:check(false,"The diagnostic lost its actual system's surface lighting");viewport.queue_free();return
	var surfaces=load("res://src/presentation/surface_response.gd").new()
	if not surfaces.apply_branches([geometry],definitions,live_scene.lighting.state,live_scene.reflection):check(false,surfaces.error);viewport.queue_free();return
	var camera:=Camera3D.new();camera.near=5.0;camera.far=2000000.0;camera.fov=55.0;viewport.add_child(camera);camera.current=true
	var audio: Node
	for node in app.find_children("*","",true,false):
		if node.get_script()==IncomingAudio:audio=node;break
	check(audio!=null,"The actual flight has no native audio owner for diagnostic cue validation")
	var random: Dictionary=parent._random.duplicate(true)
	var phases:=[];var cue_count:=0;var frames:=0;var captured:={}
	for tick in 800:
		var milliseconds: int=[0,17,41,100,16,6][tick%6]
		if crew.advance_weapons(milliseconds,null).is_empty():check(false,crew.error);break
		var frame: Dictionary=crew.advance_targeting(milliseconds,parent.snapshot().player_pose,parent._player.snapshot(),[],random)
		if frame.is_empty():check(false,crew.error);break
		random=frame.random_state;frames+=1
		var state: Dictionary=crew.snapshot();var death: Dictionary=state.destruction[peer]
		var body: Dictionary=state.actors[peer]
		if body.vitals.hull!=0 or body.engine_draw_enabled:check(false,"The native death pass healed a pilot or retained its engine");break
		var pose: Transform3D=death.pose
		var center: Vector3=death.effect.position if death.phase=="explosion" else pose.origin
		camera.position=center+pose.basis.x*5500.0+pose.basis.z*7000.0
		camera.look_at(center,Vector3.UP)
		var prepared: Dictionary=geometry.prepare(state,crew,camera.global_transform)
		if prepared.is_empty():check(false,geometry.error);break
		geometry.commit(prepared)
		if audio!=null:
			var cues: Dictionary=audio.prepare_wingman_weapons(crew,state)
			if cues.is_empty():check(false,audio.error);break
			cue_count+=cues.operations.filter(func(operation):return operation.action=="start_spatial").size()
		if death.phase not in phases:
			phases.append(death.phase)
		var capture: bool=death.phase=="tumble" or (death.phase=="explosion" and death.countdown_ms>=350)
		if capture and not captured.has(death.phase):
			await process_frame;await process_frame
			var path:=OS.get_environment("GOF2_INCOMING_CAPTURE_DIRECTORY").path_join("unearned-companion-%s.png"%death.phase)
			check(viewport.get_texture().get_image().save_png(path)==OK,"Could not retain the labelled native destruction diagnostic")
			captured[death.phase]=int(death.countdown_ms)
		if death.phase=="retired":
			check(not body.active and not prepared.actors[peer].visible and not prepared.deaths[peer].visible,"The retired companion retained active or visible geometry")
			break
	check(phases==["tumble","explosion","retired"],"Companion destruction skipped or failed to finish an original phase")
	check(cue_count==2,"Companion destruction did not emit exactly its two native transition cues")
	check(captured.has("tumble") and captured.has("explosion"),"The native diagnostic omitted a visible hull or developed explosion")
	incoming_metrics.death_phases=phases;incoming_metrics.death_frames=frames;incoming_metrics.death_cues=cue_count
	viewport.queue_free();await process_frame
	print("Detached incoming contacts and destruction: ",{"failures":failures,"metrics":incoming_metrics})
