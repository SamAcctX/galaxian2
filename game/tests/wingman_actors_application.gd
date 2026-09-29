extends "res://tests/wingman_lifetime_application.gd"
## Spawn acceptance only. Resume an unchanged paid career and pilot normally;
## never inject a pilot, alter the save, reposition a ship or replace the camera.
const CrewActors=preload("res://src/simulation/wingman_actors.gd")
const FlightScene=preload("res://src/presentation/first_flight_scene.gd")

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var paid: Dictionary=entry.contracts.wingmen
	check(not paid.active.is_empty() and paid.active.names.size()==1,"The actor input must retain its genuine one-pilot hire")
	if failures:return
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==paid,"Fresh Resume changed the paid crew")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	var crew: RefCounted=app.session.flight_owner().wingman_owner()
	check(crew!=null and initial.has("wingman_actors"),"The paid pilot has no native actor owner")
	if failures:return
	var cast: Dictionary=crew.snapshot()
	check(cast.actors.size()==paid.active.names.size(),"Departure lost or duplicated a paid pilot")
	var actor: Dictionary=cast.actors[0]
	check(actor.name==paid.active.names[0] and actor.actor_kind==paid.active.faction,"The actor lost its retained name or faction")
	check(actor.wingman and actor.wingman_index==0 and actor.wingman_command==1 and actor.friendly and not actor.hostile,"Wingman tag, roster index, initial command or friendliness differs")
	check(actor.vitals.hull==600 and actor.max_hull>=600,"The hired fighter lost its source hull override")
	check(actor.hull_catalogue_id==CrewActors.hull_for_pilot(definitions,actor.name,actor.actor_kind),"The hired fighter ignored its stable native hull choice")
	var expected: Vector3=initial.player_pose.origin-initial.player_pose.basis.x*1000.0-initial.player_pose.basis.z*2000.0
	check(actor.pose.origin.distance_to(expected)<0.1 and actor.pose.basis.z.dot(initial.player_pose.basis.z)>.9999,"The first pilot did not spawn left/behind facing the player heading")
	check(not cast.interactions_connected,"Construction falsely claims combat/follow acceptance")
	verify_actor_components(crew,initial.player_pose)
	if failures or not await release_application_flight():return
	var scene: Node3D=find_flight_scene(app)
	check(scene!=null and scene.wingmen!=null and scene.wingmen.actors.size()==cast.actors.size(),"The live flight did not build its original wingman hull")
	if failures:return
	var geometry: Node3D=scene.wingmen.actors[0].ship
	check(geometry.get_meta("source_ship_id")==actor.hull_catalogue_id and geometry.get_meta("wingman_name")==actor.name,"The rendered ship is not the retained native pilot")
	if not await inspect_pilot_in_flight(actor.pose.origin,scene):return
	var observed: Dictionary=app.session.snapshot()
	check(observed.wingman_actors.actors[0].pose==actor.pose,"Construction-only actor unexpectedly invented a flight path")
	check(observed.contracts.wingmen.active.remaining_ms<paid.active.remaining_ms,"Real actor inspection did not consume ordinary hired flight time")
	var paused: Dictionary=app.session.flight_owner().snapshot().wingman_actors
	check(app.session.set_pause("user",true,now_us),app.session.error)
	for tick in 10:
		if not application_step():return
	check(app.session.flight_owner().snapshot().wingman_actors==paused,"Paused flight mutated the constructed crew")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	verify_retained_career(entry,returned)
	check(returned.contracts.wingmen.active.names==paid.active.names and returned.contracts.wingmen.hired_total==paid.hired_total,"Docking lost the actual pilot or changed the hired total")
	if failures or not retain_recovery_save("returned"):return
	var saved: Dictionary=app._save_file.load_document(directory.path_join("returned.gof2save"),definitions,catalogue,source)
	check(saved.career.wingmen==returned.contracts.wingmen,"The native actor-return checkpoint lost the retained hire")
	check(FileAccess.get_sha256(input_path)==input_hash,"Actor acceptance modified its earned input")
	await capture_free_application("wingman-actor-returned")
	print("Earned wingman construction: ",{"input_sha256":input_hash,"name":actor.name,"faction":actor.actor_kind,"hull":actor.hull_catalogue_id,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"follow_combat_accepted":false})

func verify_actor_components(crew: RefCounted,player: Transform3D) -> void:
	var before: Dictionary=crew.snapshot()
	var exported: Dictionary=crew.snapshot();exported.actors[0].name="Detached observation"
	var body: RefCounted=crew.body_owner(0)
	check(body.set_permissions(false,false,false),body.error)
	check(crew.snapshot()==before and crew.fork_for_frame().snapshot()==before,"A detached body or observation mutated the retained actor")
	for faction in 8:
		var hull:=CrewActors.hull_for_pilot(definitions,"Eugene York",faction)
		var rules: Dictionary=definitions.early_contracts.encounter_construction.hulls
		check(hull>=0 and int(rules.factions[hull])==(faction if faction<=3 else 8),"A hired faction selected a fighter from the wrong pool")
	var rotated:=Transform3D(Basis(Vector3.UP,1.1)*Basis(Vector3.FORWARD,.4),player.origin)
	for index in 3:
		var pose:=CrewActors.spawn_pose(rotated,index)
		var expected:=rotated.origin-rotated.basis.z*2000.0
		expected+=rotated.basis.x*[-1000.0,2000.0,0.0][index]
		if index==2:expected.y+=1000.0
		check(pose.origin.distance_to(expected)<.1 and absf(pose.basis.x.dot(Vector3.UP))<.0001,"A rotated spawn used world axes or inherited player roll")
	check(crew.snapshot()==before,"Detached spawn tests contaminated the native application")

func inspect_pilot_in_flight(position: Vector3,scene: Node3D) -> bool:
	for tick in 1800:
		var state: Dictionary=app.session.snapshot()
		var distance: float=state.player_pose.origin.distance_to(position)
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,position),"throttle":1.0 if distance>2800.0 else 0.0,"fire":false,"strafe":0.0}
		if not pirate_step(input):return false
		if tick%30==0:await process_frame
		if distance<4200.0 and not scene.camera.is_position_behind(position):
			var screen: Vector2=scene.camera.unproject_position(position)
			var area: Rect2=scene.camera.get_viewport().get_visible_rect().grow(-120)
			if area.has_point(screen):
				for settle in 10:
					if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
				check(scene.wingmen.actors[0].ship.is_visible_in_tree(),"The paid fighter is hidden in the active scene")
				await capture_free_application("wingman-actor-visible")
				return failures==0
	check(false,"Ordinary piloting never brought the spawned wingman into view")
	return false

func find_flight_scene(node: Node) -> Node3D:
	if node.get_script()==FlightScene:return node
	for child in node.get_children():
		var found:=find_flight_scene(child)
		if found!=null:return found
	return null
