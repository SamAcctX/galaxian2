extends "res://tests/wingman_target_application.gd"
## Primary-only acceptance: native earned play supplies all live targets and
## damage. Component candidates never replace the application or its save.
var primary_shots:=0
var primary_hits:=0
var primary_cues:=0
var rendered_shot:=false
var first_hit:={}

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==entry.contracts.wingmen and not entry.contracts.wingmen.active.is_empty(),"Resume lost the genuinely paid crew")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	var crew: RefCounted=app.session.flight_owner().wingman_owner()
	check(crew!=null and crew.snapshot().primary_weapons_connected and not crew.snapshot().weapons_connected,"Primary support is missing or falsely claims the second weapon")
	check(crew.snapshot().weapon_world.weapons.actors.size()==entry.contracts.wingmen.active.names.size(),"The paid cast did not receive its own primary pools")
	var resumed:=OS.get_environment("GOF2_WINGMEN_PRIMARY_STAGE")=="resume"
	if not resumed:
		verify_primary_components(crew,initial)
		check(app.session.flight_owner().snapshot()==initial,"Component weapon checks changed the real flight")
	if failures or not await release_application_flight():return
	var scene:=find_flight_scene(app)
	check(scene!=null and scene.wingmen!=null and scene.wingmen.projectiles!=null and scene.wingmen.impacts!=null,"The live primary lacks original projectile/impact geometry")
	if failures:return
	if resumed:
		for tick in 60:
			if not pirate_step({"commands":Vector2(.3,0),"throttle":0.0,"fire":false,"strafe":0.0}):return
		var fresh: Dictionary=app.session.snapshot().wingman_actors
		check(fresh.weapon_world.elapsed_ms>0 and fresh.actors[0].name==entry.contracts.wingmen.active.names[0],"Fresh Resume lost the pilot or primary clock")
		await capture_free_application("wingman-primary-resumed")
	else:
		if not await acquire_live_primary_hits(scene):return
		var paused: Dictionary=app.session.flight_owner().snapshot()
		check(app.session.set_pause("user",true,now_us),app.session.error)
		for tick in 8:
			if not application_step():return
		check(app.session.flight_owner().snapshot().wingman_actors==paused.wingman_actors,"Pause advanced companion shots, hits or animation")
		check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures:return
	var airborne: Dictionary=app.session.snapshot()
	if airborne.encounter.combat.actors.any(func(row):return row.active and row.hostile and row.vitals.hull>0):
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==airborne.location.system_id:stations.append(id)
		check(stations.size()>1,"No ordinary withdrawal destination exists")
		if failures or not await travel_application(stations[(stations.find(airborne.location.station_id)+1)%stations.size()]):return
	if not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	for key in ["mission","passengers","blueprints"]:
		check(returned.contracts[key]==entry.contracts[key],"Primary acceptance changed unrelated career field "+key)
	check(returned.contracts.credits>=entry.contracts.credits,"Combat or docking unexpectedly deducted credits")
	check(returned.cargo==entry.cargo and returned.loadout.equipment_ids==entry.loadout.equipment_ids and returned.campaign_cursor==entry.campaign_cursor,"Primary acceptance changed cargo, fitting or campaign")
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"Combat or docking replaced the paid roster")
	check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Flight did not bank elapsed hire time")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Docking autosave lost the armed pilot")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Primary acceptance changed its earned input")
	await capture_free_application("wingman-primary-returned")
	print("Earned wingman primary: ",{"input_sha256":input_hash,"resumed":resumed,"shots":primary_shots,"hits":primary_hits,"cues":primary_cues,"rendered_shot":rendered_shot,"first_hit":first_hit,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"credits_before":entry.contracts.credits,"credits_after":returned.contracts.credits,"timing":_pilot_deltas,"full_weapons_accepted":false})

func verify_primary_components(crew: RefCounted,initial: Dictionary) -> void:
	var original: Dictionary=crew.snapshot();var sibling: RefCounted=crew.fork_for_frame()
	var weapon: Dictionary=original.weapon_world.weapons.actors[0].projectiles.weapon
	check(weapon.nonplayer_source and weapon.projectile_capacity==4 and weapon.lifetime_ms==3000,"Companion primary lost its ordinary nonplayer factory")
	var candidate: RefCounted=crew.fork_for_frame();var random:=CrewActors.Random.new()
	check(random.seed_from(17),random.error)
	var target: Dictionary=original.actors[0].duplicate(true)
	target.actor_id=0;target.hostile=true;target.pose.origin+=target.pose.basis.z*4000.0
	var elapsed:=0;var shots:=0
	while elapsed<1200:
		check(not candidate.advance_weapons(100,null).is_empty(),candidate.error)
		var next: Dictionary=candidate.advance_targeting(100,initial.player_pose,initial.player,[target],random.snapshot())
		check(not next.is_empty(),candidate.error)
		if failures:return
		check(random.restore(next.random_state),random.error)
		for event in candidate.snapshot().primary_firing.actors:
			if event.outcome.fired:shots+=1
		elapsed+=100
	check(shots>0,"Aligned native primary requests emitted no actual shots")
	check(crew.snapshot()==original and sibling.snapshot()==original,"Primary firing mutated a retained parent or sibling")
	var stable: Dictionary=candidate.snapshot()
	check(candidate.advance_weapons(-1,null).is_empty() and candidate.snapshot()==stable,"Rejected duration changed primary clocks or slots")
	var exported: Dictionary=candidate.snapshot();exported.weapon_world.weapons.actors[0].projectiles.weapon.damage=999999
	check(candidate.snapshot()==stable,"Primary observations expose writable damage declarations")
	target.targeting_blocked=true
	check(not candidate.advance_targeting(100,initial.player_pose,initial.player,[target],random.snapshot()).is_empty(),candidate.error)
	check(candidate.snapshot().primary_firing.actors.is_empty(),"A targeting-blocked opponent received a primary firing request")
	var combat: RefCounted=app.session.flight_owner().encounter_owner().combat_owner()
	var before: Dictionary=combat.snapshot()
	check(not combat.bind_wingman_primaries(RefCounted.new()) and combat.snapshot()==before,"A foreign object authorized companion damage")
	var pool: RefCounted=crew.primary_weapon_owner()
	check(combat.bind_wingman_primaries(pool),combat.error)
	check(combat.supports_weapon_hit(weapon),combat.error)
	var forged:=weapon.duplicate(true);forged.damage+=1;forged.ordinary_hit_policy.nonplayer_damage+=1
	check(not combat.supports_weapon_hit(forged),"An unregistered companion damage value passed hit admission")
	var advanced: Dictionary=pool.evaluate_wingman_contacts(combat,100)
	check(not advanced.is_empty() and crew.snapshot()==original and combat.snapshot()==before,"Detached contact evaluation mutated live owners")

func acquire_live_primary_hits(scene: Node3D) -> bool:
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var captured_shot:=false;var hit_time:=-1
	while now_us-started<180000000:
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The real player died before primary acceptance");return false
		var chosen: int=state.wingman_actors.targeting.selections[0].target_actor_id
		var targets: Array=state.encounter.combat.actors.filter(func(row):return row.active and row.vitals.hull>0 and not row.get("contract_debris",false)).map(func(row):return row.actor_id)
		if targets.is_empty():check(false,"No real NPC is available for primary acceptance");return false
		var input: Dictionary
		if chosen<0:
			var gun: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
			var reach:=float(gun.speed_units_per_millisecond)*float(gun.lifetime_ms)
			pilot.firing_range=reach*.9
			input=pilot.controls_at_time(state,float(state.world_elapsed_ms),targets,false)
			input.throttle=1.0 if input.distance>minf(18000.0,reach*.6) else 0.0
		else:
			input={"commands":PiratePilot.Steering.steering_toward(state.player_pose,state.wingman_actors.actors[0].pose.origin),"throttle":0.0,"fire":false,"strafe":0.0}
		if not pirate_step(input):return false
		var next: Dictionary=app.session.snapshot();var cast: Dictionary=next.wingman_actors
		for event in cast.primary_firing.actors:
			if event.outcome.fired:
				primary_shots+=1;primary_cues+=event.audio_events.size()
		for event in cast.primary_contacts:
			for hit in event.npc_contacts:
				primary_hits+=1
				if first_hit.is_empty():
					first_hit={"actor_id":hit.actor_id,"projectile_id":hit.projectile_id,"damage":hit.damage,"before":state.encounter.combat.actors[hit.actor_id].vitals,"after":next.encounter.combat.actors[hit.actor_id].vitals}
					hit_time=now_us
		for i in scene.wingmen.projectiles.guns.size():
			var gun: Dictionary=scene.wingmen.projectiles.guns[i]
			for j in gun.slots.size():
				if not gun.slots[j].is_visible_in_tree():continue
				var shot: Variant=cast.weapon_world.weapons.actors[i].projectiles.slots[j]
				if shot is Dictionary and not scene.camera.is_position_behind(shot.position) and scene.camera.get_viewport().get_visible_rect().has_point(scene.camera.unproject_position(shot.position)):rendered_shot=true
		if rendered_shot and not captured_shot:
			await capture_free_application("wingman-primary-shot");captured_shot=true
		if primary_shots>0 and primary_hits>0 and captured_shot and now_us-hit_time>=100000:
			check(primary_cues==primary_shots,"Successful companion launches did not emit their native cue")
			check(not first_hit.damage.is_empty() and first_hit.before!=first_hit.after,"A native projectile contact did not change target vitals")
			check(not cast.weapons_connected,"Primary-only acceptance claimed the second weapon")
			await capture_free_application("wingman-primary-hit")
			print("Actual companion primary combat: ",{"shots":primary_shots,"hits":primary_hits,"cues":primary_cues,"seconds":(now_us-started)/1000000.0,"first_hit":first_hit})
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+500000
		if now_us>=next_log:
			print("Wingman primary pilot: ",{"seconds":(now_us-started)/1000000.0,"target":chosen,"shots":primary_shots,"hits":primary_hits,"rendered":rendered_shot,"hull":next.player.vitals.hull})
			next_log=now_us+30000000
	check(false,"Bounded native flight did not produce a visible wingman shot and actual NPC damage")
	return false
