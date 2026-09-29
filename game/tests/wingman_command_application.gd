extends "res://tests/wingman_primary_application.gd"
## Earned flight only: the application input path selects the companion group.
## No opponent, projectile, damage, contract time or random state is injected.
var systems_shots:=0
var systems_hits:=0
var systems_cues:=0
var systems_starts:=0
var systems_rendered:=false
var systems_first_hit:={}

func command_key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
		app._unhandled_input(event)

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"));app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==entry.contracts.wingmen and not entry.contracts.wingmen.active.is_empty(),"Resume lost the earned paid crew")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var scene:=find_flight_scene(app)
	check(scene!=null and scene.wingmen!=null and scene.wingmen.systems_projectiles!=null and scene.wingmen.systems_impacts!=null,"Systems geometry is absent from actual flight")
	if failures:return
	var resumed:=OS.get_environment("GOF2_WINGMEN_COMMAND_STAGE")=="resume"
	if not await verify_command_controls():return
	if resumed:
		for tick in 80:
			if not pirate_step({"commands":Vector2(.3,0),"throttle":0.0,"fire":false,"strafe":0.0}):return
		check(app.session.snapshot().wingman_actors.weapon_groups.all(func(group):return group==1),"Fresh flight forgot the real command")
		await capture_free_application("wingman-command-resumed")
	elif not await acquire_live_systems_hits(scene):return
	var paused: Dictionary=app.session.flight_owner().snapshot().wingman_actors
	check(app.session.set_pause("user",true,now_us),app.session.error)
	command_key(KEY_V)
	check(not app.flight_menu.visible,"User pause admitted a wingman menu")
	for tick in 8:
		if not application_step():return
	check(app.session.flight_owner().snapshot().wingman_actors==paused,"Pause advanced wingman shots, contacts or selection")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures:return
	var airborne: Dictionary=app.session.snapshot()
	if airborne.encounter.combat.actors.any(func(row):return row.active and row.hostile and row.vitals.hull>0):
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==airborne.location.system_id:stations.append(id)
		check(stations.size()>1,"No ordinary withdrawal destination")
		if failures or not await travel_application(stations[(stations.find(airborne.location.station_id)+1)%stations.size()]):return
	if not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	for key in ["mission","passengers","blueprints"]:check(returned.contracts[key]==entry.contracts[key],"Commands changed unrelated career field "+key)
	check(returned.cargo==entry.cargo and returned.loadout.equipment_ids==entry.loadout.equipment_ids and returned.campaign_cursor==entry.campaign_cursor,"Commands changed cargo, fitting or campaign")
	check(returned.contracts.credits>=entry.contracts.credits,"Wingman command charged unearned credits")
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"Commands changed the paid roster")
	check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Flight failed to bank real elapsed hire time")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Autosave lost the commanded crew")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Command acceptance changed its earned input")
	await capture_free_application("wingman-command-returned")
	print("Earned wingman command: ",{"input_sha256":input_hash,"resumed":resumed,"shots":systems_shots,"hits":systems_hits,"cues":systems_cues,"backend_starts":systems_starts,"rendered":systems_rendered,"first_hit":systems_first_hit,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"credits":returned.contracts.credits,"timing":_pilot_deltas,"full_weapons_accepted":false})

func verify_command_controls() -> bool:
	var parent: RefCounted=app.session.flight_owner();var before: Dictionary=parent.snapshot().wingman_actors
	check(before.weapon_groups.all(func(group):return group==0),"Fresh construction retained an earlier flight's selection")
	command_key(KEY_V)
	check(app.flight_menu.visible and app.session.is_paused(),"V did not open the paused wingman menu")
	if failures:return false
	var rows: Array=app.flight_menu.snapshot().rows
	check(rows.map(func(row):return row.label)==[app.library.strings[296],app.library.strings[297],app.library.strings[298],app.library.strings[300]],"The menu lost its original command labels/order")
	command_key(KEY_1)
	check(app.flight_menu.visible and app.session.flight_owner().snapshot().wingman_actors==before,"An unsupported order changed flight")
	command_key(KEY_V)
	check(not app.flight_menu.visible and app.session.flight_owner().snapshot().wingman_actors==before,"Cancel changed the crew")
	app.session.rebase_time(now_us)
	command_key(KEY_E)
	var action_rows: Array=app.flight_menu.snapshot().rows
	var index: int=action_rows.map(func(row):return row.action).find("wingmen")
	check(index>=0,"The ordinary action menu has no wingmen entry")
	if failures:return false
	command_key(KEY_1+index)
	check(app.flight_menu.visible and app.flight_menu.snapshot().rows[3].action=="wingman_weapon_switch","The action-menu entry did not open crew orders")
	await capture_free_application("wingman-command-menu")
	resume_application_focus()
	command_key(KEY_4)
	app.session.rebase_time(now_us)
	var after: Dictionary=app.session.flight_owner().snapshot().wingman_actors
	check(not app.flight_menu.visible and after.weapon_groups.all(func(group):return group==1),"The fourth command did not select the native systems group")
	for key in ["actors","following","targeting","weapon_world","systems_weapon_world"]:check(after[key]==before[key],"Weapon selection changed retained "+key)
	check(parent.snapshot().wingman_actors==before,"The published command mutated its retained parent")
	check(after.weapon_command_input_connected and after.systems_audio_connected and not after.weapons_connected,"The capability flags misstate command scope")
	command_key(KEY_V)
	check(app.flight_menu.snapshot().rows[3].label==app.library.strings[299],"The selected EMP group did not offer the laser alternative")
	var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=true;app._unhandled_input(pad)
	app.session.rebase_time(now_us)
	check(app.session.snapshot().wingman_actors.weapon_groups.all(func(group):return group==0),"Controller confirmation did not restore primaries")
	command_key(KEY_V);command_key(KEY_ENTER);app.session.rebase_time(now_us)
	check(app.session.snapshot().wingman_actors.weapon_groups.all(func(group):return group==1),"Keyboard confirmation did not restore systems")
	return failures==0

func acquire_live_systems_hits(scene: Node3D) -> bool:
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var captured:=false;var hit_time:=-1
	while now_us-started<150000000:
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The real player died during command acceptance");return false
		var chosen: int=state.wingman_actors.targeting.selections[0].target_actor_id
		var targets: Array=state.encounter.combat.actors.filter(func(row):return row.active and row.vitals.hull>0 and not row.get("contract_debris",false)).map(func(row):return row.actor_id)
		if targets.is_empty():check(false,"No real NPC remains for command acceptance");return false
		var input: Dictionary
		if chosen<0:
			var gun: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
			var reach:=float(gun.speed_units_per_millisecond)*float(gun.lifetime_ms)
			pilot.firing_range=reach*.9;input=pilot.controls_at_time(state,float(state.world_elapsed_ms),targets,false)
			input.throttle=1.0 if input.distance>minf(18000.0,reach*.6) else 0.0
		else:input={"commands":PiratePilot.Steering.steering_toward(state.player_pose,state.wingman_actors.actors[0].pose.origin),"throttle":0.0,"fire":false,"strafe":0.0}
		var previous_revision: int=app.session.flight_audio.snapshot().revision
		if not pirate_step(input):return false
		var next: Dictionary=app.session.snapshot();var cast: Dictionary=next.wingman_actors
		for event in cast.systems_firing.actors:
			if event.outcome.fired:systems_shots+=1;systems_cues+=event.audio_events.size()
		for operation in app.session.flight_audio.snapshot().history:
			if operation.revision>previous_revision and operation.get("weapon_group",-1)==1 and operation.action=="start_spatial":
				systems_starts+=1
				var audio: Dictionary=cast.systems_weapon_world.weapons.actors[int(operation.wingman_index)].audio
				check(operation.source_id==audio.source_id and operation.pitch_raw==audio.pitch_raw,"The committed EMP sound lost its faction or pitch")
		for event in cast.systems_contacts:
			for hit in event.npc_contacts:
				var damage: Dictionary=hit.damage.get("systems",{})
				if damage.get("accepted",false) and damage.after.integrity<damage.before.integrity:
					systems_hits+=1
					if systems_first_hit.is_empty():systems_first_hit={"actor_id":hit.actor_id,"damage":damage};hit_time=now_us
		for i in scene.wingmen.systems_projectiles.guns.size():
			var gun: Dictionary=scene.wingmen.systems_projectiles.guns[i]
			for j in gun.slots.size():
				if not gun.slots[j].is_visible_in_tree():continue
				var shot: Variant=cast.systems_weapon_world.weapons.actors[i].projectiles.slots[j]
				if shot is Dictionary and not scene.camera.is_position_behind(shot.position) and scene.camera.get_viewport().get_visible_rect().has_point(scene.camera.unproject_position(shot.position)):systems_rendered=true
		if systems_rendered and not captured:await capture_free_application("wingman-command-emp-shot");captured=true
		if systems_shots>0 and systems_hits>0 and captured and now_us-hit_time>=100000:
			check(systems_cues==systems_shots and systems_starts==systems_shots,"Actual systems launches and committed sound starts differ")
			check(cast.primary_firing.actors.is_empty(),"An EMP-selected crew also requested primaries")
			await capture_free_application("wingman-command-emp-hit")
			print("Actual earned systems combat: ",{"shots":systems_shots,"hits":systems_hits,"cues":systems_cues,"backend_starts":systems_starts,"seconds":(now_us-started)/1000000.0,"first_hit":systems_first_hit})
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+500000
		if now_us>=next_log:
			print("Wingman command pilot: ",{"seconds":(now_us-started)/1000000.0,"target":chosen,"shots":systems_shots,"hits":systems_hits,"rendered":systems_rendered,"hull":next.player.vitals.hull});next_log=now_us+30000000
	check(false,"Bounded earned flight did not produce visible systems emissions and genuine systems damage")
	return false
