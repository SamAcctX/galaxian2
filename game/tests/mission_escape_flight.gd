extends "res://tests/mission_continuation.gd"
## Detached arrival/radio setup inherited from the continuation component.
## Only initial aiming/approach poses are stimuli below: damage, radio gates,
## portal contact/pull, cinematic clocks and the pending return are live frames.
## This does not replace the earned application journey or a station save.

func verify_retained_flight() -> void:
	var before: Dictionary=active.snapshot()
	var native_world: RefCounted=active.initialized_world_owner()
	var portal_identity: RefCounted=active.portal_owner().retained_identity()
	check(active.escape_state().phase==5 and not active.portal_owner().portal_snapshot().visible,"Escape did not retain the disabled exit portal")
	# Aim the actual equipped gun at the actual disabled hull. No damage setter,
	# radio flag, result flag, cast replacement or inventory edit is used.
	var target: Dictionary=active.combat_owner().actor_snapshot(0)
	active=active.fork_for_frame()
	active._pose=Transform3D(Basis.IDENTITY,target.body_pose.origin+Vector3(0,0,2400))
	active._pilot.angular_units=Vector2.ZERO;active._pilot.lateral_units_per_millisecond=0
	for tick in 120:
		if active.combat_owner().actor_snapshot(0).vitals.hull<=0:break
		if not advance_flight(true):return
	check(active.combat_owner().actor_snapshot(0).vitals.hull<=0,"Installed gun did not destroy the disabled freighter")
	if failures:return
	await capture("escape-freighter-destroyed")
	var heard6:=false;var heard7:=false;var opened:=false
	for tick in 900:
		var speech: RefCounted=active.encounter_owner().radio_owner()
		heard6=heard6 or speech.event_state(6).condition_satisfied
		heard7=heard7 or speech.event_state(7).condition_satisfied
		if active.escape_state().phase==6:
			check(speech.event_state(7).playback_finished,"Exit opened before the escape warning finished")
			opened=true;break
		if not advance_flight(false):return
	check(heard6 and heard7 and opened,"Live radio6/7 did not release the exit portal")
	if failures:return
	check(active.frame_context().campaign_cursor==42 and active.frame_context().boundary.is_empty(),"Freighter destruction repeated the ambush result")
	for tick in 32:
		if not advance_flight(false):return
	check(active.portal_owner().portal_snapshot().visible and active.portal_owner().portal_snapshot().scale==1.0,"Portal did not open at full extent")
	var waiting: Dictionary=active.snapshot()
	check(waiting.escape.shake_strength>0 and waiting.input.enabled,"Escape wait lost camera shake or player control")
	check(scene.sequence_audio.snapshot().active.has(153),"Escape rumble was not played by the scene")
	var sounds_before: Dictionary=scene.sequence_audio.snapshot()
	if not present():return
	check(scene.sequence_audio.snapshot()==sounds_before,"Repeated display replayed the escape sound")
	var paused_before: Dictionary=active.snapshot()
	scene.set_paused(true)
	var paused: RefCounted=active.evaluate(100,Vector2.ONE,1,true,true)
	check(paused!=null and paused.snapshot()==paused_before,"Paused escape advanced its radio, portal, camera or random stream")
	if not present():return
	check(scene.sequence_audio.snapshot().paused,"Pause did not reach retained escape sound")
	scene.set_paused(false)
	# Start outside the contact sphere and let ordinary flight plus portal pull
	# perform the departure. This is a focused approach, not earned navigation.
	active=active.fork_for_frame()
	active._pose=Transform3D(Basis.IDENTITY,active.portal_owner().portal_snapshot().position+Vector3(0,0,-16000))
	active._pilot.angular_units=Vector2.ZERO;active._pilot.lateral_units_per_millisecond=0
	# Give the real following camera time to settle after detached positioning;
	# portal pull remains active throughout. Do not manufacture a camera pose.
	for tick in 24:
		if not advance_flight(false,0.0):return
	await capture("escape-portal-open")
	var departure_parent: RefCounted
	var departure_before: Dictionary
	for tick in 100:
		departure_parent=active;departure_before=active.snapshot()
		if not advance_flight(false,1.0):return
		if active.escape_state().phase==7:break
	check(active.escape_state().phase==7 and active.portal_owner().transition_ready(active.player_owner().snapshot().vitals.hull),"Real portal contact did not start departure")
	if failures:return
	check(departure_parent.snapshot()==departure_before,"Departure mutated the previous player/world frame")
	check(not scene.player.visible and not scene.exhaust.visible and not active.frame_context().input.enabled and not active.player_owner().snapshot().damage_allowed,"Departure failed to hide/protect the player or cancel controls")
	check(scene.sequence_effects.snapshot().models.all(func(model):return model.visible) and scene.sequence_audio.snapshot().active.has(154),"Departure did not draw/play the mothership explosion")
	check(active.select_secondary(42)==null,"Cinematic accepted a weapon selection")
	check(is_equal_approx(scene.camera.fov,rad_to_deg(active.escape_state().vertical_fov_radians)),"Departure camera ignored its cinematic projection")
	await capture("escape-explosion-start")
	var mid_captured:=false;var fade_captured:=false
	var protected_hull: int=active.player_owner().snapshot().vitals.hull
	var departure_pose: Transform3D=active.frame_context().player_pose
	for tick in 230:
		var candidate: RefCounted=active.evaluate(100,Vector2.ONE,1,true,false,Vector2i.ZERO,1,true)
		if candidate==null:check(false,active.error);return
		active=candidate
		if not active.frame_context().boundary.is_empty():break
		if not present():return
		var escape: Dictionary=active.escape_state()
		if escape.explosion_elapsed_ms>4000 and not mid_captured:
			check(not scene.environment._void.station.visible,"Mothership remained visible after the explosion covered it")
			await capture("escape-explosion-mid");mid_captured=true
		if escape.fade_requested and escape.fade.elapsed_ms>=2000 and not fade_captured:
			check(scene.sequence_fade.visible and scene.sequence_fade.color.a>0,"Requested escape fade was not drawn")
			await capture("escape-fade");fade_captured=true
	check(mid_captured and fade_captured and active.frame_context().boundary=="normal_space_return_required","Escape did not finish its animation and fade into the return boundary")
	check(active.player_owner().snapshot().vitals.hull==protected_hull,"Hidden departure player took combat damage")
	check(active.frame_context().player_pose!=departure_pose,"Automatic departure did not keep moving the hidden player")
	var packet: Dictionary=active.prepare_portal_transition()
	var entry: Dictionary=native_world.entry_owner().snapshot()
	check(not packet.is_empty() and packet.return_station_id==entry.return_station_id and packet.return_system_id==entry.return_system_id,"Escape discarded the actual retained normal-space location")
	check(active.initialized_world_owner()==native_world and active.portal_owner().retained_identity()==portal_identity,"Escape replaced the world or portal generation")
	check(active.equipment_owner().snapshot()==before.equipment and active.career_owner().snapshot().mission==before.career.mission and active.career_owner().snapshot().credits==before.career.credits,"Escape altered equipment, independent passenger job or credits")
	check(active.frame_context().campaign_cursor==42 and not active.campaign_dialogue_visible(),"Pending normal-space return forged result43 or docking")
	print("Live escape reached retained return station ",packet.get("return_station_id")," at revision ",active.frame_context().revision)

func advance_flight(fire: bool,throttle:=0.0) -> bool:
	var candidate: RefCounted=active.evaluate(100,Vector2.ZERO,throttle,fire)
	if candidate==null:check(false,active.error);return false
	active=candidate
	if active.player_owner().snapshot().vitals.hull<=0:check(false,"Component pilot died during the live escape");return false
	return present()

func capture(label: String) -> void:
	if label.begins_with("escape-"):await super.capture(label)
