extends "res://tests/mission_bloom_render.gd"
## Only the changed world/interface boundary; not the established filter math.
const Overlay=preload("res://src/presentation/scene_overlay.gd")

func verify_component(world: RefCounted) -> void:
	if DisplayServer.get_name()=="headless":check(false,"Overlay boundary requires GPU rendering");return
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i.ZERO
	await verify_layers()
	await verify_mission_layers(world)
	print("Overlay observations: ",JSON.stringify(observations))

func colored(parent: Node,position: Vector2,size: Vector2,color: Color) -> ColorRect:
	var node:=ColorRect.new();node.position=position;node.size=size;node.color=color
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func verify_layers() -> void:
	var view:=View.new();view.size=Vector2(root.size);root.add_child(view)
	view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var source_viewport: SubViewport=view.viewport;var source_texture: Texture2D=view.texture
	var background:=colored(view.viewport,Vector2.ZERO,view.size,Color(0.1,0.13,0.16))
	var canvas:=CanvasLayer.new();view.viewport.add_child(canvas)
	var ui:=colored(canvas,Vector2(300,190),Vector2(128,96),Color(0.2,0.8,0.9))
	var panel:=colored(canvas,Vector2(80,190),Vector2(128,96),Color(0.1,0.2,0.5,0.5))
	var baseline:=await rendered()
	check(view.set_bloom_enabled(true),view.error)
	# Actual old composition is the negative control, not a copied constant.
	var mixed:=await rendered()
	check(color_error(mixed.get_pixel(350,230),baseline.get_pixel(350,230))>0.05,
		"Negative control did not expose bright interface entering scene glare")
	check(view.register_overlay(canvas),view.error)
	var target: SubViewport=view._overlay_viewport;var graph: Node=view._bloom
	check(view.register_overlay(canvas) and view._overlay_viewport==target,"Repeated registration rebuilt the UI destination")
	var separated:=await rendered();write_image(separated,"overlay-sharp-ui")
	compare_images(baseline,separated,1.0/255.0,"dim world with bright and translucent UI")
	check(view.viewport==source_viewport and view.texture==source_texture,"Overlay routing replaced the world viewport/texture")
	check(canvas.get_parent()==source_viewport and ui.get_parent()==canvas,"Overlay routing reparented scene controls")
	var world_before: Image=view.viewport.get_texture().get_image()
	canvas.hide();await rendered()
	check(world_before.get_data()==view.viewport.get_texture().get_image().get_data(),"Interface still enters the filtered world texture")
	canvas.show()
	var highlight:=colored(view.viewport,Vector2(80,190),Vector2(128,96),Color(0.9,0.4,0.1))
	canvas.hide();var filtered:=await rendered();canvas.show()
	var alpha:=await rendered();var at:=Vector2i(140,230)
	var expected:=filtered.get_pixelv(at).lerp(Color(0.1,0.2,0.5),0.5)
	check(color_error(alpha.get_pixelv(at),expected)<=2.0/255.0,"Translucent UI does not blend once over the already-filtered world")
	var fade:=colored(canvas,Vector2.ZERO,view.size,Color(0,0,0,1))
	var black:=await rendered()
	check(color_error(black.get_pixelv(at),Color.BLACK)==0.0,"Full fade leaves scene glare visible")
	ui.hide();panel.hide();fade.color.a=0.5
	var half:=await rendered()
	check(color_error(half.get_pixelv(at),filtered.get_pixelv(at).lerp(Color.BLACK,0.5))<=2.0/255.0,"Half fade is applied before scene glare")
	fade.free();ui.show();panel.show()
	await verify_overlay_pointer(view,canvas)
	view.size=Vector2(640,400);view.refresh_size();background.size=view.size
	check(target.size==view.viewport.size and target.size_2d_override==view.viewport.size_2d_override,"Overlay lost physical/logical resize alignment")
	view.scale=Vector2(1.25,1.25);view.refresh_size()
	check(target.size==Vector2i(800,500) and target.size_2d_override==Vector2i(640,400),"Scaled interface lost physical pixels or logical coordinates")
	await verify_overlay_pointer(view,canvas)
	view.scale=Vector2.ONE;view.refresh_size()
	view.hide()
	check(target.render_target_update_mode==SubViewport.UPDATE_DISABLED and not graph._active,"Hidden view keeps overlay/effect targets active")
	view.show();ui.color=Color(0.8,0.2,0.3)
	var shown:=await rendered()
	check(color_error(shown.get_pixel(350,230),ui.color)<=1.0/255.0,"Shown interface uses stale colors")
	var owner:=Node3D.new();view.viewport.add_child(owner)
	var dynamic:=Overlay.new();owner.add_child(dynamic)
	check(dynamic.error.is_empty() and dynamic.custom_viewport==target,"New scene canvas was not routed while the effect was active")
	owner.free()
	check(view._overlays.size()==1 and view._overlay_viewport==target,"Freeing one scene discarded another scene's UI destination")
	check(view.set_bloom_enabled(false),view.error)
	check(canvas.custom_viewport==source_viewport and view._overlay_viewport==null and not is_instance_valid(target),"Disable failed to restore/release the overlay target")
	view.size=Vector2(root.size);view.refresh_size();background.size=view.size
	highlight.free();ui.color=Color(0.2,0.8,0.9)
	var restored:=await rendered()
	check(restored.get_data()==baseline.get_data(),"Effect-off did not restore the exact original composite")
	var foreign:=SubViewport.new();foreign.size=Vector2i(16,16);root.add_child(foreign)
	canvas.custom_viewport=foreign
	check(not view.set_bloom_enabled(true) and canvas.custom_viewport==foreign and view._bloom==null,"Enable overwrote a foreign canvas destination")
	canvas.custom_viewport=source_viewport;foreign.free()
	view.unregister_overlay(canvas);canvas.free();view.free()

func verify_overlay_pointer(view: Control,canvas: CanvasLayer) -> void:
	var clicks: Array=[];var under_clicks: Array=[]
	var under:=Button.new();under.position=Vector2(24,24);under.size=Vector2(150,50)
	under.pressed.connect(func():under_clicks.append(true));view.viewport.add_child(under)
	var button:=Button.new();button.position=under.position;button.size=under.size
	button.text="Sharp interface";button.pressed.connect(func():clicks.append(true));canvas.add_child(button)
	await rendered()
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	event.position=view.get_global_transform_with_canvas()*Vector2(70,45);event.global_position=event.position
	event.pressed=true;root.push_input(event,true);event.pressed=false;root.push_input(event,true)
	await process_frame
	check(clicks.size()==1 and under_clicks.is_empty(),"Overlay click was lost or also reached the covered world control")
	button.free();under.free()

func compare_images(expected: Image,actual: Image,tolerance: float,label: String) -> void:
	var mismatches:=0;var maximum:=0.0;var samples:=0
	for y in range(2,actual.get_height(),3):
		for x in range(2,actual.get_width(),3):
			var delta:=color_error(expected.get_pixel(x,y),actual.get_pixel(x,y))
			maximum=maxf(maximum,delta);samples+=1
			if delta>tolerance:mismatches+=1
	check(mismatches==0,"%s: %d mismatches, max%.6f"%[label,mismatches,maximum])
	observations.append({"boundary":label,"samples":samples,"mismatches":mismatches,"maximum_error":maximum})

func verify_mission_layers(world: RefCounted) -> void:
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
	check(view._overlays.size()==1 and scene.overlay_layer.custom_viewport==null,"Ordinary mission did not register its scene-owned interface")
	active=stage_burning_shot(active,scene)
	if active==null:view.free();return
	check(view.set_bloom_enabled(true),view.error)
	write_image(await rendered(),"overlay-native-burning")
	for tick in 600:
		if active.campaign_dialogue_visible():break
		var next: RefCounted=active.evaluate(100,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id())
		if next==null:check(false,active.error);view.free();return
		active=next
		if not scene.present(active,root.size):check(false,scene.error);view.free();return
	if not active.campaign_dialogue_visible():check(false,"Native staging did not reach result dialogue");view.free();return
	var before: Dictionary=active.snapshot();var world_before: Dictionary=world.snapshot()
	var camera_before: Camera3D=scene.camera;var lights_before: Node3D=scene.environment.lights
	var audio_before: Node3D=scene.feedback.audio;var ui_parent: Node=scene.overlay.get_parent()
	var on:=await rendered();write_image(on,"overlay-native-result-bloom")
	var overlay_image: Image=view._overlay_viewport.get_texture().get_image()
	check(view.set_bloom_enabled(false),view.error)
	var off:=await rendered();write_image(off,"overlay-native-result-plain")
	var opaque:=0;var mismatches:=0;var maximum:=0.0
	for y in range(2,on.get_height(),3):
		for x in range(2,on.get_width(),3):
			if overlay_image.get_pixel(x,y).a<0.999:continue
			opaque+=1
			var delta:=color_error(on.get_pixel(x,y),off.get_pixel(x,y))
			maximum=maxf(maximum,delta)
			if delta>2.0/255.0:mismatches+=1
	check(opaque>100 and mismatches==0,"Native result opaque art/text changes under Bloom: %d/%d, max%.6f"%[mismatches,opaque,maximum])
	observations.append({"native_result_opaque_samples":opaque,"mismatches":mismatches,"maximum_error":maximum})
	check(active.snapshot()==before and world.snapshot()==world_before,"Rendering result UI changed flight/world/save state")
	check(scene.camera==camera_before and scene.environment.lights==lights_before and scene.feedback.audio==audio_before,"Overlay routing rebuilt camera, lighting or audio owners")
	check(scene.overlay.get_parent()==ui_parent and ui_parent==scene.overlay_layer and ui_parent.get_parent()==scene,"Overlay left its scene lifetime owner")
	check(view.set_bloom_enabled(true),view.error)
	await verify_dialogue_pointer(view,scene)
	var graph: Node=view._bloom
	scene.free()
	check(view._overlays.is_empty() and view._overlay_viewport==null and view._bloom==graph,"Scene removal left orphan controls or destroyed the retained filter")
	view.free()

func verify_dialogue_pointer(view: Control,scene: Node3D) -> void:
	await rendered()
	var panel: Control=scene.feedback.dialogue
	var revision: int=scene.world_owner().frame_context().revision
	for instruction in [[panel._next,1],[panel._previous,0]]:
		var button: Button=instruction[0]
		check(button.is_visible_in_tree() and not button.disabled,"Native result navigation is unavailable")
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		event.position=view.get_global_transform_with_canvas()*button.get_global_rect().get_center()
		event.global_position=event.position
		event.pressed=true;root.push_input(event,true);event.pressed=false;root.push_input(event,true)
		var image:=await rendered();revision+=1
		check(panel._snapshot.index==instruction[1] and scene.world_owner().frame_context().revision==revision,
			"Native result click was lost, duplicated or advanced a different owner")
		if instruction[1]==1:write_image(image,"overlay-native-result-next-click")
