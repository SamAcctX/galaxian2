extends "res://tests/mission_pilot_input.gd"
## Fractional-millisecond desktop input with native weapon emission.
## Detached one-second flight, not earned survival or measured render FPS.

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var app: Control=await make_host(frame)
	if app==null:return
	app._mouse_steering=true;app.present_session()
	for page in 4:await key(KEY_ENTER)
	check(app.session.can_control() and app._mouse_captured,"High-rate pilot did not enter ordinary mouse flight")
	if failures:app.free();return
	app.session.rebase_time(now_us)
	var session: Node3D=app.session;var scene: Node3D=session.scene;var camera: Camera3D=session.camera
	var parent: RefCounted=session.flight_owner();var initial: Dictionary=parent.snapshot()
	var start_us:=now_us;var steps:={};var samples:={};var strafes:={};var throttles:={};var held:={}
	var emitted:=0;var captured:=false
	var levels:=[0.3,0.0,0.8,1.0,1.0,0.3,0.3,0.0,1.0,0.0,0.8,1.0]
	for index in 144:
		var end_us: int=start_us+(index+1)*1000000/144
		var delta_us:=end_us-now_us
		var input:={"commands":Vector2(.2,-.4) if index%2==0 else Vector2(-.1,.3),"throttle":levels[index/12],"fire":index<72 or index>=108,"strafe":float((index/12)%3-1)}
		var before: Dictionary=session.snapshot()
		var delivered:=DesktopPilot.apply(app,root,input,delta_us)
		check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"High-rate root events changed the requested controls")
		check(session.snapshot()==before,"Pending high-rate controls mutated the accepted world")
		now_us=end_us;app._selected40_tick(now_us)
		check(not app._transition_failed,app.status.text)
		if failures:app.free();return
		var after: Dictionary=session.snapshot()
		if index==0:check(after.player_pose.basis.z.distance_to(before.player_pose.basis.z)>0.00001,"Recipe mouse input waited for another frame")
		check(after.elapsed_ms-initial.elapsed_ms==(now_us-start_us)/1000,"High-rate Host lost fractional time at sample "+str(index))
		check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire and not after.input.secondary_requested,"High-rate native controls lost steering/trigger or requested paid ammunition")
		check(is_equal_approx(float(after.throttle),float(input.throttle)),"High-rate throttle edges did not reach the native frame")
		steps[after.elapsed_ms-before.elapsed_ms]=true;samples[delta_us]=true
		strafes[delivered.strafe]=true;throttles[roundi(input.throttle*10.0)]=true;held[input.fire]=true
		for shot in after.encounter.get("primary_fire",{}).get("weapons",[]):
			if not shot.result.get("fired",false):continue
			check(input.fire and delivered.held.fire and after.input.primary_held,"High-rate emission bypassed the ordinary held trigger")
			var mounts: Array=after.encounter.primaries.guns.filter(func(gun):return gun.mount_id==shot.mount_id)
			check(mounts.size()==1 and mounts[0].projectiles.slots.any(func(slot):return slot!=null),"High-rate emission lacked a matching mounted live projectile")
			emitted+=1
			print("High-rate actual primary ",emitted," at ",after.elapsed_ms,"ms; mount ",shot.mount_id," item ",shot.item_id,"; no hit claim")
		if failures:app.free();return
		if emitted>0 and not captured and DisplayServer.get_name()!="headless":
			await capture(app,"mission-pilot-high-rate-primary")
			captured=true
	var final: Dictionary=session.snapshot()
	check(now_us-start_us==1000000 and final.elapsed_ms-initial.elapsed_ms==1000,"144 desktop samples did not advance exactly one second")
	check(samples.has(6944) and samples.has(6945) and samples.size()==2 and steps.has(6) and steps.has(7) and steps.size()==2,"High-rate input omitted the fractional cadence boundary")
	check(strafes.has(-1.0) and strafes.has(1.0) and throttles.has(0) and throttles.has(10) and held.has(true) and held.has(false),"High-rate flight omitted evasion, throttle extremes or trigger release")
	check(emitted>0,"High-rate controls never emitted a native primary")
	if DisplayServer.get_name()!="headless":check(captured,"High-rate GPU emission was not captured")
	check(app.session==session and session.scene==scene and session.camera==camera and session.can_control() and final.campaign_cursor==41,"High-rate input replaced the mission or its presentation owners")
	check(parent.snapshot()==initial and final.equipment==initial.equipment and final.career==initial.career,"High-rate input changed its retained parent, inventory or career")
	check(not final.player_pose.is_equal_approx(initial.player_pose),"High-rate controls did not move the actual player")
	if not failures:print("High-rate desktop input: 144 Host frames / 1000ms; native steps ",steps.keys()," primary emissions ",emitted,"; detached flight, not earned battle or render FPS")
	app.free();await process_frame
