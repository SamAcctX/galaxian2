extends "res://tests/mission_bloom_render.gd"
## Root-event keyboard routing; no replay of the effect or pixel-math suites.
const Overlay=preload("res://src/presentation/scene_overlay.gd")

class InputFallback extends Node:
	var joy_events: Array=[]
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventJoypadButton:
			joy_events.append({"button":event.button_index,"pressed":event.pressed})
			get_viewport().set_input_as_handled()

func verify_component(world: RefCounted) -> void:
	if DisplayServer.get_name()=="headless":check(false,"Overlay input requires a GPU window");return
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i.ZERO
	await verify_keyboard()
	if failures>0:print("Overlay keyboard observations: ",JSON.stringify(observations));return
	await verify_native_keyboard(world)
	print("Overlay keyboard observations: ",JSON.stringify(observations))

func key(code: Key,shift:=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.shift_pressed=shift
	event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	await process_frame

func click_control(view: Node,button: Control) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	event.position=button.get_global_rect().get_center()
	if view is Control:event.position=view.get_global_transform_with_canvas()*event.position
	event.global_position=event.position;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	await process_frame

func pad(button: JoyButton) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=button
	event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	await process_frame

func add_button(parent: Node,label: String,at: Vector2,clicks: Array) -> Button:
	var button:=Button.new();button.text=label;button.position=at;button.size=Vector2(200,60)
	button.pressed.connect(func():clicks.append(label));parent.add_child(button);return button

func verify_keyboard() -> void:
	var fallback:=InputFallback.new();root.add_child(fallback)
	var view:=View.new();view.size=Vector2(root.size);fallback.add_child(view)
	view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var canvas:=Overlay.new();view.viewport.add_child(canvas)
	var clicks: Array=[];var covered_clicks: Array=[]
	var covered:=add_button(view.viewport,"Covered world",Vector2(80,180),covered_clicks)
	var first:=add_button(canvas,"First",Vector2(80,180),clicks)
	var second:=add_button(canvas,"Second",Vector2(340,180),clicks)
	first.focus_next=first.get_path_to(second);second.focus_next=second.get_path_to(first)
	first.focus_previous=first.get_path_to(second);second.focus_previous=second.get_path_to(first)
	await rendered()
	for enabled in [false,true,false]:
		check(view.set_bloom_enabled(enabled),view.error)
		await rendered();clicks.clear();covered_clicks.clear()
		await click_control(view,first)
		check(clicks==["First"] and covered_clicks.is_empty(),"Pointer did not select the visible scene control")
		await key(KEY_ENTER)
		check(clicks==["First","First"],"Enter lost the selected scene control (Bloom=%s)"%enabled)
		await key(KEY_TAB);await key(KEY_ENTER)
		check(clicks==["First","First","Second"],"Tab/Enter did not navigate within scene controls (Bloom=%s)"%enabled)
		await key(KEY_TAB,true);await key(KEY_SPACE)
		check(clicks==["First","First","Second","First"] and covered_clicks.is_empty(),"Reverse Tab/Space lost or duplicated the scene action (Bloom=%s)"%enabled)
		observations.append({"bloom":enabled,"clicks":clicks.duplicate(),"covered":covered_clicks.duplicate(),"first_focused":first.has_focus(),"second_focused":second.has_focus()})
	# No reclick: the actual selected control survives destination changes.
	clicks.clear()
	for enabled in [true,false,true]:
		check(view.set_bloom_enabled(enabled),view.error)
		await rendered();await key(KEY_ENTER)
	check(clicks==["First","First","First"],"Changing the effect lost keyboard focus")
	clicks.clear();await pad(JOY_BUTTON_DPAD_RIGHT);await pad(JOY_BUTTON_A)
	check(clicks.is_empty() and fallback.joy_events==[
		{"button":JOY_BUTTON_DPAD_RIGHT,"pressed":true},{"button":JOY_BUTTON_DPAD_RIGHT,"pressed":false},
		{"button":JOY_BUTTON_A,"pressed":true},{"button":JOY_BUTTON_A,"pressed":false}],
		"Keyboard routing stole or duplicated the application's controller events")
	observations.append({"controller_passthrough":fallback.joy_events.duplicate()})
	await click_control(view,second);clicks.clear()
	var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.physical_keycode=KEY_ENTER;event.pressed=true
	root.push_input(event,true);event=event.duplicate();event.echo=true
	root.push_input(event,true);root.push_input(event,true)
	event=event.duplicate();event.echo=false;event.pressed=false;root.push_input(event,true)
	await process_frame
	check(clicks==["Second"],"Held/echoed Enter duplicated the action")
	observations.append({"held_enter_clicks":clicks.duplicate()})
	write_image(await rendered(),"overlay-keyboard-focused")
	# Root GUI gets first refusal, even if the scene still remembers focus.
	var outer_clicks: Array=[]
	var outer:=add_button(root,"Outer interface",Vector2(620,80),outer_clicks)
	await rendered();clicks.clear();await click_control(root,outer)
	await key(KEY_ENTER)
	check(outer_clicks==["Outer interface","Outer interface"] and clicks.is_empty(),"Scene stole a focused outer control's key")
	outer.free();await click_control(view,first);clicks.clear()
	view.hide();await key(KEY_ENTER);await pad(JOY_BUTTON_A)
	check(clicks.is_empty(),"Hidden scene still consumes activation")
	view.show();await rendered();await click_control(view,first);clicks.clear()
	canvas.hide();await key(KEY_ENTER)
	check(clicks.is_empty(),"Hidden scene canvas still activates its controls")
	canvas.show();await rendered();await click_control(view,first);clicks.clear()
	first.free();second.free();await key(KEY_ENTER);await pad(JOY_BUTTON_A)
	check(clicks.is_empty() and covered_clicks.is_empty(),"Removed interface retained focus or activated a covered control")
	covered.free()
	view.free()
	fallback.free()

func verify_native_keyboard(world: RefCounted) -> void:
	var view:=View.new();view.size=Vector2(root.size);root.add_child(view)
	view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);view.free();return
	var active:=FlightFrame.new()
	if not active.configure(bindings,catalogues,library,context,world):check(false,active.error);view.free();return
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);view.free();return
	var scene:=Scene.new();view.viewport.add_child(scene)
	if not scene.configure(library,bindings,visuals,catalogues,active,root.size):check(false,scene.error);view.free();return
	active=stage_burning_shot(active,scene)
	if active==null:view.free();return
	for tick in 600:
		if active.campaign_dialogue_visible():break
		var next: RefCounted=active.evaluate(100,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id())
		if next==null:check(false,active.error);view.free();return
		active=next
		if not scene.present(active,root.size):check(false,scene.error);view.free();return
	if not active.campaign_dialogue_visible():check(false,"Native staging did not reach result dialogue");view.free();return
	var initial: Dictionary=active.snapshot();var original: Dictionary=world.snapshot()
	var camera: Camera3D=scene.camera;var audio: Node3D=scene.feedback.audio;var lighting: Node3D=scene.environment.lights
	var panel: Control=scene.feedback.dialogue;var revision: int=scene.world_owner().frame_context().revision
	check(view.set_bloom_enabled(true),view.error);await rendered()
	await click_control(view,panel._next);revision+=1
	check(panel._snapshot.index==1 and scene.world_owner().frame_context().revision==revision,"Native Next click did not select exactly one result page")
	await key(KEY_ENTER);revision+=1
	check(panel._snapshot.index==2 and scene.world_owner().frame_context().revision==revision,"Native focused Next did not accept Enter exactly once")
	write_image(await rendered(),"overlay-native-keyboard-next")
	check(view.set_bloom_enabled(false),view.error);await rendered();await key(KEY_SPACE);revision+=1
	check(panel._snapshot.index==3 and scene.world_owner().frame_context().revision==revision,"Native Next lost focus when disabling the effect")
	check(view.set_bloom_enabled(true),view.error);await rendered();await key(KEY_ENTER);revision+=1
	check(panel._snapshot.index==4 and scene.world_owner().frame_context().revision==revision,"Native Next lost focus when enabling the effect")
	write_image(await rendered(),"overlay-native-keyboard-last-page")
	await click_control(view,panel._previous);revision+=1
	await key(KEY_ENTER);revision+=1
	check(panel._snapshot.index==2 and scene.world_owner().frame_context().revision==revision,"Focused native Previous used the global Next action or duplicated input")
	write_image(await rendered(),"overlay-native-keyboard-previous")
	var before_hide: int=scene.world_owner().frame_context().revision
	view.hide();await key(KEY_ENTER)
	check(scene.world_owner().frame_context().revision==before_hide,"Hidden native dialogue still changed the living world")
	view.show();await rendered()
	check(active.snapshot()==initial and world.snapshot()==original,"Input mutated a retained parent world/save snapshot")
	check(scene.camera==camera and scene.feedback.audio==audio and scene.environment.lights==lighting,"Keyboard navigation rebuilt camera/audio/lighting owners")
	observations.append({"native_result_revision":revision,"native_result_index":panel._snapshot.index,"navigation_actions":6})
	scene.free();await key(KEY_ENTER);await pad(JOY_BUTTON_A)
	check(view._overlays.is_empty() and view._overlay_viewport==null,"Scene removal left keyboard-target controls behind")
	view.free()
