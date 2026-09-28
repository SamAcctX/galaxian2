extends "res://tests/bakka_session.gd"
## Real primary-fire victory in the selected component world. The independent
## defeat branch still uses the base controlled-contact diagnostic. Neither
## branch substitutes for an earned campaign route or checkpoint retry.
## Post-victory return retains the battle's final position and uses native
## session inputs all the way to contact; no close-approach pose is supplied.
const Pilot=preload("res://tests/fixtures/expedition_flight_pilot.gd")

func composition_seed(bindings: RefCounted) -> Dictionary:
	var seed:=super.composition_seed(bindings)
	# Explicit shielded component preset, not a purchase or an earned save.
	# Native catalogue/slot/capacity owners derive every equipment statistic.
	seed.equipment_ids=[22,50,81,55]
	return seed

func return_to_station(session: Node3D) -> RefCounted:
	var initial: RefCounted=session.flight_owner()
	var before: Dictionary=initial.snapshot()
	var retained: Dictionary=initial.contract_owner().snapshot()
	var station_position: Vector3=initial._station.snapshot().pose.origin
	var start_distance: float=before.player_pose.origin.distance_to(station_position)
	check(before.campaign_cursor==37 and initial.prepare_station().is_empty() and start_distance>18000.0 and initial._station.point_volume(before.player_pose.origin)<0,
		"The live return must start at the distant acknowledged battle position")
	if failures:return null
	if not session.action("station_autopilot"):check(false,"Live return guidance: "+session.error);return null
	var guided: Dictionary=session.snapshot()
	check(guided.player_pose==before.player_pose and guided.progress==before.progress and guided.station_autopilot.active and guided.station_autopilot.station_id==27 and guided.input_throttle==1.0,
		"Starting return guidance moved the player, advanced progress or selected another station")
	if not session.action("cancel_autopilot"):check(false,"Live return cancellation: "+session.error);return null
	check(not session.snapshot().station_autopilot.active and session.snapshot().player_pose==before.player_pose,"Cancelling guidance moved the live ship")
	if failures or not session.action("station_autopilot"):check(false,"Live return restart: "+session.error);return null
	var travelled:=0.0
	var previous_position: Vector3=before.player_pose.origin
	for tick in 6000:
		app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		pilot_now_us+=100000
		if not session.step(pilot_now_us):check(false,"Live return frame: "+session.error);return null
		var frame: RefCounted=session.flight_owner()
		var state: Dictionary=frame.snapshot()
		travelled+=previous_position.distance_to(state.player_pose.origin)
		previous_position=state.player_pose.origin
		if frame.death_active():check(false,"The live return pilot died at frame "+str(tick));return null
		var packet: Dictionary=frame.prepare_station()
		if not packet.is_empty():
			check(packet.campaign_cursor==37 and packet.source_state==5 and packet.mission==before.mission and packet.docking.station_id==27,
				"The complete return changed its source mission or destination")
			check(packet.docking.pre_motion_contact or packet.docking.post_motion_volume_index>=0,"The complete return bypassed native station contact")
			check(travelled>18000.0 and state.world_elapsed_ms>before.world_elapsed_ms and state.player.vitals.hull>0,"The complete return skipped its physical flight")
			check(packet.contracts==frame.contract_owner().snapshot() and packet.progress==packet.contracts.progress and packet.progress==state.progress,
				"The full return lost its actual flight career")
			for field in ["credits","passengers","mission","accepted_contact","active_offer_id","completed_side_missions","delivery_statistics","travel_statistics","pending_result","result_serial"]:
				check(packet.contracts[field]==retained[field],"Full return changed the independent career: "+field)
			check(packet.cargo==before.cargo and packet.equipment==before.equipment and packet.player_cache.campaign_cursor==37,
				"Full return changed retained cargo, equipment or cache cursor")
			check(packet.player_cache.values.hull==packet.player.vitals.hull and packet.player_cache.values.armor==packet.player.vitals.armor and packet.player_cache.values.shield==int(packet.player.vitals.shield) and packet.player_cache.values.gamma==int(packet.player.gamma),
				"Full return failed to retain actual player pools")
			check(initial.snapshot()==before and initial.contract_owner().snapshot()==retained,"Full return mutated its acknowledged parent")
			pilot_now_us+=100000
			if not session.step(pilot_now_us):check(false,"Pending arrival frame: "+session.error);return null
			check(session.flight_owner().snapshot()==state and session.flight_owner().prepare_station()==packet,"Pending full arrival advanced or paid twice")
			print("Bakka full return: ",tick+1," input frames; initial distance ",int(start_distance),"; actual travelled ",int(travelled),"; contact distance ",int(previous_position.distance_to(station_position)),"; player ",state.player.vitals)
			return session.flight_owner() if failures==0 else null
		if tick%200==0:print("Bakka return pilot ",tick," distance ",int(previous_position.distance_to(station_position))," guidance ",state.station_autopilot.active," player ",state.player.vitals)
		if tick%20==0:await process_frame
	check(false,"The normal-input B'akka return never reached the actual station")
	return null

func resolve_contest(session: Node3D,player_wins: bool) -> RefCounted:
	if not player_wins:return await super.resolve_contest(session,false)
	var before: Dictionary=session.snapshot()
	check(before.player.vitals=={"hull":95,"armor":40,"shield":50.0},"The source shielded combat preset changed its native capacities")
	if failures:return null
	var target_id:=-1
	var previous: Variant=null
	var shots:=0
	# The source contest waits for all seven pirates, not only a majority.
	# Include the real inter-group flights as well as normal weapon cooldowns.
	for tick in 12000:
		app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		var state: Dictionary=session.snapshot()
		var actors: Array=state.encounter.combat.actors
		var living: Array=actors.filter(func(actor):return actor.actor_id>0 and actor.vitals.hull>0)
		var defeated_pirates: int=7-living.size()
		var player_kills: int=int(state.progress.player_kills)-int(before.progress.player_kills)
		if state.dialogue.visible:
			check(state.phase=="return_instructions" and state.combat_objective_satisfied,"The real-input contest pilot did not win: "+str(state.dialogue))
			check(shots>0 and player_kills>=4 and defeated_pirates==7 and state.player.vitals.hull>0,"The live contest result lacks surviving player-fire victories")
			check(state.campaign_cursor==36 and state.contracts.credits==before.contracts.credits,"Live combat paid or advanced before final acknowledgement")
			print("Bakka real-input result: ",tick," frames; ",shots," firing frames; ",player_kills," player kills; ",defeated_pirates," pirate deaths; ",state.progress)
			return session.flight_owner() if failures==0 else null
		if session.flight_owner().death_active():check(false,"The live B'akka pilot died at frame "+str(tick));return null
		var command:=Vector2.ZERO
		var throttle:=0.0
		var fire:=false
		var strafe:=0.0
		if not living.is_empty():
			if target_id<0 or actors[target_id].vitals.hull<=0:
				living.sort_custom(func(a,b):return a.position.distance_squared_to(state.player_pose.origin)<b.position.distance_squared_to(state.player_pose.origin))
				target_id=living[0].actor_id;previous=null
			var target: Dictionary=actors[target_id]
			var offset: Vector3=target.position-state.player_pose.origin
			var aim: Vector3=target.position
			var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
			if previous!=null:aim+=(target.position-previous)/100.0*minf(offset.length()/float(weapon.speed_units_per_millisecond),2000.0)
			previous=target.position
			command=Pilot.steering_toward(state.player_pose,aim)
			throttle=1.0 if offset.length()>6000.0 else 0.0
			# Alternate the actual lateral input while approaching gun range;
			# steering alone leaves the approach in incoming fire.
			if offset.length()<35000.0:strafe=1.0 if tick%20<10 else -1.0
			fire=offset.length()<22000.0 and state.player_pose.basis.z.angle_to(aim-state.player_pose.origin)<0.15
			if tick%200==0:print("Bakka live pilot ",tick," target ",target_id," distance ",int(offset.length())," enemy hull ",target.vitals.hull," player ",state.player.vitals," defeated ",defeated_pirates," player kills ",player_kills)
		while absf(float(session.snapshot().input_throttle)-throttle)>0.05:
			if not session.action("throttle_up" if throttle>0 else "throttle_down"):check(false,session.error);return null
		pilot_now_us+=100000
		if not session.step(pilot_now_us,command,fire,false,strafe):check(false,"Bakka live flight: "+session.error);return null
		if fire:shots+=1
		if tick%20==0:await process_frame
	var exhausted: Dictionary=session.snapshot()
	check(false,"Bakka normal-input allowance exhausted: "+str({"phase":exhausted.phase,"world_ms":exhausted.world_elapsed_ms,"player":exhausted.player.vitals,"progress":exhausted.progress,"living":exhausted.encounter.combat.actors.filter(func(actor):return actor.actor_id>0 and actor.vitals.hull>0).map(func(actor):return actor.actor_id)}))
	return null
