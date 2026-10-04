extends "res://tests/mission_escape_sequence.gd"
## Application input over a native arrival. Only the preceding gate/portal is
## staged by the shared source fixture; this is not an earned battle or save.
const Host=preload("res://src/presentation/opening_preview.gd")
const FlightFrame=preload("res://src/simulation/mission_flight_frame.gd")
var visual_path: String
var now_us:=1000000

class PreparedWorld extends RefCounted:
	var world: RefCounted
	func world_owner() -> RefCounted:return world

func verify(args: Array) -> void:
	visual_path=args[2]
	await super.verify(args)

func verify_component(world: RefCounted) -> void:
	var original: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner()
	var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var before: Dictionary=frame.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	for kind in ["keyboard","keypad","controller","pointer","desktop_pointer"]:
		await verify_arrival(frame,kind)
		if failures:return
	check(frame.snapshot()==before and world.snapshot()==original,"Application arrival changed its retained source frame/world")

func make_host(frame: RefCounted) -> Control:
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);return null
	var app:=Host.new();root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(library,bindings,visuals);app.set_process(false)
	app._mouse_steering=false;app._focused=true;app.set_player_mode(true)
	var prepared:=PreparedWorld.new();prepared.world=frame.fork_for_frame()
	if not app.enter_mission_prepared(prepared,now_us):check(false,app.status.text);app.free();return null
	app.show();app.present_session()
	await process_frame;await process_frame
	app._focused=true
	for reason in ["hidden","focus","user"]:app.session.set_pause(reason,false,now_us)
	app.present_session()
	return app

func key(code: Key,echo:=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code
	event.pressed=true;event.echo=echo;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;event.echo=false;root.push_input(event,true)
	await process_frame

func pad() -> void:
	var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A
	event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	await process_frame

func click_at(position: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	event.position=position;event.global_position=position;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	await process_frame

func verify_arrival(frame: RefCounted,kind: String) -> void:
	var app: Control=await make_host(frame)
	if app==null:return
	var session: Node3D=app.session;var camera: Camera3D=session.camera;var scene: Node3D=session.scene
	var audio: Node3D=scene.feedback.audio;var lighting: Node3D=scene.environment.lights
	if not session.step(now_us+100000):check(false,session.error);app.free();return
	now_us+=100000;app.present_session()
	var before: Dictionary=session.snapshot()
	check(not session.can_control() and not session.flight_hud_visible(),"Arrival admitted flight before release")
	if kind=="keyboard":
		await key(KEY_ENTER,true)
		check(session.snapshot()==before,"An echoed key skipped the ordinary arrival")
		app.set_user_paused(true);var paused: Dictionary=session.snapshot()
		await key(KEY_ENTER)
		check(session.snapshot()==paused,"Paused arrival accepted skip input")
		app.set_user_paused(false);app._focused=false;app.refresh_render_mode()
		await key(KEY_ENTER)
		check(session.snapshot()==before,"Unfocused arrival accepted skip input")
		app._focused=true;app.hide();await process_frame
		var hidden: Dictionary=session.snapshot();await key(KEY_ENTER)
		check(session.snapshot()==hidden,"Hidden arrival accepted skip input")
		app.show();await process_frame
		app._focused=true;session.set_pause("hidden",false,now_us);session.set_pause("focus",false,now_us)
		app.present_session()
	if kind=="pointer":
		app._touch_detected=true;app.set_touch_controls(true);app.present_session()
		await process_frame;await process_frame
		check(app._skip_button.is_visible_in_tree() and app._skip_button.size.y>=44,"Arrival omitted its pointer/touch skip action")
		await capture(app,"arrival-pointer-skip")
		await click_at(app._skip_button.get_global_rect().get_center())
	else:
		check(app._flight_hint.is_visible_in_tree() and "Skip cinematic" in app._flight_hint.text,"Arrival omitted its desktop skip hint")
		if kind=="keyboard":await capture(app,"arrival-keyboard-skip")
		if kind=="controller":await pad()
		elif kind=="desktop_pointer":
			check(not app._mouse_captured and not app._skip_button.visible,"Desktop cinematic retained captured flight input or touch controls")
			await click_at(Vector2(640,360))
		else:await key(KEY_KP_ENTER if kind=="keypad" else KEY_ENTER)
	var after: Dictionary=session.snapshot()
	check(after.entry_released and after.entry_skipped and after.dialogue.get("text_id")==2038 and after.dialogue.get("voice_event_id")==185,"Actual "+kind+" skip did not open exactly the first arrival briefing page")
	if failures:app.free();return
	check(after.elapsed_ms==before.elapsed_ms and after.encounter.elapsed_ms==before.encounter.elapsed_ms and after.revision==before.revision+1,"Skip simulated missing flight time or committed more than one frame")
	check(after.player_pose==before.player_pose and after.player.vitals==before.player.vitals and after.equipment==before.equipment and after.career==before.career,"Arrival skip moved/repaired the player or changed paid equipment/career")
	for index in before.encounter.combat.actors.size():
		var first: Dictionary=before.encounter.combat.actors[index];var second: Dictionary=after.encounter.combat.actors[index]
		check(first.position==second.position and first.vitals==second.vitals,"Skip simulated omitted NPC movement or damage")
	check(app.session==session and session.scene==scene and session.camera==camera and scene.feedback.audio==audio and scene.environment.lights==lighting and session.flight_owner().initialized_world_owner()==frame.initialized_world_owner(),"Skip rebuilt a retained world, scene, camera, audio or lighting owner")
	check(not session.can_skip_cinematic() and not app._flight_hint.visible and not app._skip_button.visible and not session.can_control(),"Briefing retained the arrival action or released flight too early")
	await key(KEY_ENTER,true)
	check(session.snapshot()==after,"Key echo advanced the freshly opened briefing")
	await capture(app,"arrival-"+kind+"-briefing")
	# Navigate the actual scene buttons/Host, not the simulation's navigate method.
	for page in 3:
		check(session.snapshot().dialogue.get("text_id")==2038+page,"Arrival briefing omitted or duplicated a page")
		if kind in ["pointer","desktop_pointer"]:
			var button: Control=scene.feedback.dialogue._next
			var view: Control=app.viewport.get_parent()
			await click_at(view.get_global_transform_with_canvas()*button.get_global_rect().get_center())
		elif kind=="controller":await pad()
		else:await key(KEY_ENTER)
	check(not session.snapshot().dialogue.visible and session.can_control() and session.snapshot().campaign_cursor==41,"Arrival briefing did not release the same mission into flight")
	if not failures and kind=="keyboard":await verify_attack_rejects_skip(app)
	print("Arrival input ",kind,": elapsed ",before.elapsed_ms," -> ",after.elapsed_ms,"; briefing 2038-2040; retained world")
	app.free();await process_frame

func verify_attack_rejects_skip(app: Control) -> void:
	var session: Node3D=app.session
	var active: RefCounted=session.flight_owner();var original: Dictionary=active.snapshot()
	# Only the preceding radio dependency is detached. Native updates select
	# every shot; the application must not fast-forward any of them.
	var stimulus: RefCounted=active.fork_for_frame()
	stimulus._encounter=stimulus._encounter.fork_for_frame()
	stimulus._encounter._hook=stimulus._encounter._hook.fork_for_frame()
	for index in 5:
		stimulus._encounter._hook._radio._started[index]=true
		stimulus._encounter._hook._radio._finished[index]=true
	session._accepted_world(stimulus);session.rebase_time(now_us)
	var inspected:={}
	for tick in 350:
		now_us+=100000
		if not session.step(now_us):check(false,session.error);return
		var state: Dictionary=session.snapshot();var phase: int=state.encounter.sequence.phase
		if phase in [1,2,4] and not inspected.has(phase):
			inspected[phase]=true;app.present_session()
			check(not session.can_skip_cinematic() and not app._flight_hint.visible and not app._skip_button.visible,"Scripted attack offered ordinary arrival skip")
			await key(KEY_ENTER);await pad()
			check(session.snapshot()==state and not session.request_cinematic_skip() and session.snapshot()==state,"Skip input fast-forwarded a scripted attack shot")
			if phase==2:await capture(app,"arrival-skip-disabled-drift")
		if inspected.size()==3:break
	check(inspected.has(1) and inspected.has(2) and inspected.has(4),"Skip rejection did not visit attack, drift and pullback")
	check(active.snapshot()==original,"Detached radio stimulus mutated its live parent")

func capture(app: Control,label: String) -> void:
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":return
	app.present_session();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"Could not capture "+label)
