extends "res://tests/wingman_primary_application.gd"
## New systems capability checks use detached owners. The earned application
## never receives a fabricated weapon command, target, projectile or save edit.
var systems_components:={}

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"));app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==entry.contracts.wingmen and not entry.contracts.wingmen.active.is_empty(),"Systems continuation lost its earned paid crew")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	var crew: RefCounted=app.session.flight_owner().wingman_owner()
	var cast: Dictionary=crew.snapshot()
	check(cast.primary_weapons_connected and cast.systems_weapons_connected and not cast.weapons_connected and not cast.weapon_command_input_connected,"Systems capability has missing owners or overstates command/full-combat acceptance")
	check(cast.weapon_groups==entry.contracts.wingmen.active.names.map(func(_pilot):return 0),"Departure did not start with the ordinary primary group")
	var resumed:=OS.get_environment("GOF2_WINGMEN_SYSTEMS_STAGE")=="resume"
	if failures or not await release_application_flight():return
	# Ordinary reaction randomness is installed by a real flight frame, not
	# by the constructor. Never seed or replace the live combat owner in a test.
	if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return
	initial=app.session.flight_owner().snapshot();crew=app.session.flight_owner().wingman_owner()
	if not resumed:
		verify_systems_components(crew,initial)
		check(app.session.flight_owner().snapshot()==initial,"Detached systems checks mutated the real flight")
	if failures:return
	var scene:=find_flight_scene(app)
	check(scene!=null and scene.wingmen!=null and scene.wingmen.systems_projectiles!=null and scene.wingmen.systems_impacts!=null,"The live flight did not build original systems projectile/impact nodes")
	if failures:return
	for tick in 60:
		if not pirate_step({"commands":Vector2(.2,0),"throttle":0.0,"fire":false,"strafe":0.0}):return
	cast=app.session.snapshot().wingman_actors
	check(cast.systems_weapon_world.elapsed_ms==cast.weapon_world.elapsed_ms and cast.systems_weapon_world.elapsed_ms>0,"The two retained gun groups lost their common accepted flight clock")
	check(cast.weapon_groups==entry.contracts.wingmen.active.names.map(func(_pilot):return 0) and cast.systems_firing.actors.is_empty(),"Ordinary flight fabricated a systems command or simultaneous emission")
	check(cast.systems_weapon_world.projectile_visuals.models[0].model_id==6794 and cast.systems_weapon_world.impact_visuals.weapons[0].model_id==14604,"Systems presentation substituted a non-original model")
	var paused: Dictionary=app.session.flight_owner().snapshot()
	check(app.session.set_pause("user",true,now_us),app.session.error)
	for tick in 5:
		if not application_step():return
	check(app.session.flight_owner().snapshot().wingman_actors==paused.wingman_actors,"Pause advanced either companion gun group")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures:return
	await capture_free_application("wingman-systems-resumed" if resumed else "wingman-systems-ready")
	var airborne: Dictionary=app.session.snapshot()
	if airborne.encounter.combat.actors.any(func(row):return row.active and row.hostile and row.vitals.hull>0):
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==airborne.location.system_id:stations.append(id)
		check(stations.size()>1,"No native withdrawal destination exists")
		if failures or not await travel_application(stations[(stations.find(airborne.location.station_id)+1)%stations.size()]):return
	if not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	for key in ["mission","passengers","blueprints"]:
		check(returned.contracts[key]==entry.contracts[key],"Systems continuation changed unrelated career field "+key)
	check(returned.contracts.credits==entry.contracts.credits and returned.cargo==entry.cargo and returned.loadout.equipment_ids==entry.loadout.equipment_ids and returned.campaign_cursor==entry.campaign_cursor,"Unfired systems flight changed credits, cargo, fitting or campaign")
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"Systems construction changed the paid roster")
	check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Systems flight did not bank earned hire time")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Docking autosave lost the paid crew")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Systems continuation changed its earned input")
	await capture_free_application("wingman-systems-returned")
	print("Wingman systems capability: ",{"input_sha256":input_hash,"resumed":resumed,"components":systems_components,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"credits":returned.contracts.credits,"timing":_pilot_deltas,"earned_secondary_firing":false,"command_input_connected":false,"full_weapons_accepted":false})

func verify_systems_components(crew: RefCounted,initial: Dictionary) -> void:
	var original: Dictionary=crew.snapshot();var sibling: RefCounted=crew.fork_for_frame()
	var weapon: Dictionary=original.systems_weapon_world.weapons.actors[0].projectiles.weapon
	check(weapon.item_id==18 and weapon.kind==1 and weapon.damage==0 and weapon.projectile_capacity==4 and weapon.interval_ms==400 and weapon.lifetime_ms==3000 and weapon.speed_units_per_millisecond==16.0 and weapon.nonplayer_source and weapon.ordinary_hit_policy.additional_damage_required and weapon.ordinary_hit_policy.additional_damage>0,"Systems gun differs from its imported native declaration")
	var candidate: RefCounted=crew.fork_for_frame()
	check(candidate.toggle_weapon_group(0),candidate.error)
	check(candidate.snapshot().weapon_groups[0]==1 and candidate.snapshot().actors==original.actors and candidate.snapshot().following==original.following and candidate.snapshot().targeting==original.targeting,"Switching weapons replaced behavior, bodies, movement or targeting")
	var random:=CrewActors.Random.new();check(random.seed_from(17),random.error)
	var target: Dictionary=original.actors[0].duplicate(true)
	target.actor_id=0;target.hostile=true;target.pose.origin+=target.pose.basis.z*4000.0
	var shots:=0
	for tick in 18:
		check(not candidate.advance_weapons(100,null).is_empty(),candidate.error)
		var step: Dictionary=candidate.advance_targeting(100,initial.player_pose,initial.player,[target],random.snapshot())
		check(not step.is_empty(),candidate.error)
		if failures:return
		check(random.restore(step.random_state),random.error)
		check(candidate.snapshot().primary_firing.actors.is_empty(),"A selected systems gun also requested primary fire")
		for event in candidate.snapshot().systems_firing.actors:
			if event.outcome.fired:shots+=1
	check(shots>0,"Aligned selected systems requests emitted no travelling projectile")
	check(crew.snapshot()==original and sibling.snapshot()==original,"Systems clocks, selection or shots mutated a retained parent/sibling")
	var stable: Dictionary=candidate.snapshot()
	check(not candidate.toggle_weapon_group(-1) and candidate.snapshot()==stable,"An invalid weapon command partially changed the cast")
	check(candidate.advance_weapons(-1,null).is_empty() and candidate.snapshot()==stable,"Rejected time changed systems clocks or slots")
	var exported: Dictionary=candidate.snapshot();exported.systems_weapon_world.weapons.actors[0].projectiles.weapon.ordinary_hit_policy.additional_damage=999999;exported.weapon_groups[0]=0
	check(candidate.snapshot()==stable,"Systems observations expose writable declarations or selections")
	target.targeting_blocked=true
	check(not candidate.advance_targeting(100,initial.player_pose,initial.player,[target],random.snapshot()).is_empty(),candidate.error)
	check(candidate.snapshot().systems_firing.actors.is_empty(),"A blocked target received systems fire")
	check(candidate.toggle_weapon_group(0) and candidate.snapshot().weapon_groups[0]==0,"The native toggle did not restore the primary group")
	if failures:return
	var combat: RefCounted=app.session.flight_owner().encounter_owner().combat_owner()
	check(not combat.contact_random_state().is_empty(),"The real flight has not initialized its native reaction owner")
	var before: Dictionary=combat.snapshot();var pool: RefCounted=crew.systems_weapon_owner()
	check(not combat.bind_wingman_systems(RefCounted.new()),"A foreign object admitted systems damage")
	check(combat.bind_wingman_systems(pool) and combat.supports_weapon_hit(weapon),combat.error)
	var forged:=weapon.duplicate(true);forged.ordinary_hit_policy.additional_damage+=1
	check(not combat.supports_weapon_hit(forged),"Unregistered systems damage passed hit admission")
	var targets: Array=combat.actor_snapshots().filter(func(row):return row.active and row.vitals.hull>0 and not row.get("contract_debris",false))
	check(not targets.is_empty(),"No retained active NPC body exists for the detached contact check")
	if failures:return
	var id: int=targets[0].actor_id
	var context: Dictionary=combat.collision_context(id)
	var gun:=preload("res://src/simulation/ordinary_projectiles.gd").new()
	var invalid:=weapon.duplicate(true);invalid.item_id=0
	check(not gun.configure(invalid),"A primary catalogue item retained the systems marker")
	check(gun.configure(weapon),gun.error)
	check(not gun.advance(500).is_empty(),gun.error)
	var fired: Dictionary=gun.fire(context.center,Vector3(0,0,1),true)
	check(not fired.is_empty() and fired.fired,"The detached native systems projectile was not emitted")
	var contacts:=preload("res://src/simulation/ordinary_npc_contacts.gd").new()
	var hit: Dictionary=contacts.evaluate(gun,combat,[id])
	check(not hit.is_empty() and hit.contacts.size()==1,contacts.error)
	if failures:return
	var damage: Dictionary=hit.contacts[0].damage.systems
	check(damage.accepted and damage.after.integrity==maxi(0,int(damage.before.integrity)-int(weapon.ordinary_hit_policy.additional_damage)) and damage.after.integrity<damage.before.integrity,"A geometric systems hit did not apply its imported additional damage")
	var after: Dictionary=hit.combat.actor_snapshots()[id]
	check(after.vitals.hull==targets[0].vitals.hull and after.vitals.shield==targets[0].vitals.shield,"A zero-normal systems projectile damaged hull or shield")
	check(combat.snapshot()==before and crew.snapshot()==original,"Detached contact committed damage into the retained application")
	var primary: RefCounted=crew.primary_weapon_owner()
	check(primary.evaluate_wingman_contacts(combat,100,primary).is_empty(),"A primary owner masqueraded as the second group")
	var paired: Dictionary=primary.evaluate_wingman_contacts(combat,100,pool)
	check(not paired.is_empty() and paired.actors.size()==original.actors.size() and paired.systems_actors.size()==original.actors.size() and combat.snapshot()==before,"Paired contact clocks lost ordering, membership or isolation")
	systems_components={"shots":shots,"systems_before":damage.before.integrity,"systems_after":damage.after.integrity,"additional_damage":weapon.ordinary_hit_policy.additional_damage,"native_target":id,"normal_damage":0,"input_command_tested_on_detached_owner_only":true}
