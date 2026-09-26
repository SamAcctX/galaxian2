extends "res://tests/mission_escape_sequence.gd"
## Opt-in display effect over real GPU textures and the admitted Void scene.
## The staged scene is not an input-earned battle or an original frame capture.
const View=preload("res://src/presentation/native_scene_view.gd")
const Bloom=preload("res://src/presentation/scene_bloom.gd")
const FlightFrame=preload("res://src/simulation/mission_flight_frame.gd")
const Scene=preload("res://src/presentation/mission_scene.gd")
var visual_path:=""
var output_path:=""
var observations: Array=[]

func verify(args: Array) -> void:
	visual_path=args[2];output_path=OS.get_environment("GOF2_CAPTURE_DIR")
	await super.verify(args)

func verify_component(world: RefCounted) -> void:
	if DisplayServer.get_name()=="headless":check(false,"Bloom requires a GPU viewport");return
	root.size=Vector2i(768,512);root.content_scale_size=Vector2i.ZERO
	var unready:=View.new()
	check(not unready.set_bloom_enabled(true),"Unattached scene view accepted Bloom")
	unready.free()
	var view:=View.new();view.size=Vector2(root.size);root.add_child(view)
	view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var retained_viewport: SubViewport=view.viewport
	var retained_texture: Texture2D=view.texture
	check(view.material==null and view._bloom==null,"Ordinary views silently enabled Bloom")
	var background:=ColorRect.new();background.size=view.size;background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.color=Color(0.12,0.2,0.3);view.viewport.add_child(background)
	var off:=await rendered()
	var unrelated:=CanvasItemMaterial.new();view.material=unrelated
	check(not view.set_bloom_enabled(true) and view.material==unrelated,"Bloom overwrote a different display effect")
	view.material=null
	if not view.set_bloom_enabled(true):check(false,view.error);view.free();return
	var owner: Node=view._bloom
	check(view.set_bloom_enabled(true) and view._bloom==owner,"Repeated enable rebuilt the filter graph")
	check(not owner.build(view.texture),"Repeated graph build was accepted")
	check(owner.target_count()==13,"Display filter graph is incomplete")
	var dim:=await rendered()
	check(off.get_data()==dim.get_data(),"Bloom repainted a uniformly dim picture")
	check(view.viewport==retained_viewport and view.texture==retained_texture,"Bloom replaced the scene viewport or texture")
	for channel in [0.0,0.3,0.5,0.6,0.7,1.0]:
		background.color=Color(channel,0.1,0.1)
		var first:=await rendered()
		var stable:=await rendered()
		check(first.get_data()==stable.get_data(),"Bloom has previous-frame data after a uniform color change")
		var source: Image=view.viewport.get_texture().get_image()
		var glare: Image=owner.glare_texture().get_image()
		var point:=Vector2i(384,256)
		var base:=source.get_pixelv(point);var displayed:=first.get_pixelv(point)
		var glow:=glare.get_pixel(128,128)
		check(absf(displayed.g-base.g)<=1.0/255.0 and absf(displayed.b-base.b)<=1.0/255.0,"Red highlights created green or blue glare")
		if channel<=0.5:check(glow.r==0.0 and color_error(displayed,base)<=1.0/255.0,"Dim channels unexpectedly glow")
		elif channel==0.6:check(glow.r>0.14 and glow.r<0.20,"Soft highlight onset is missing")
		elif channel==0.7:check(glow.r>0.28 and glow.r<0.35,"Mid highlight response is wrong")
		else:check(glow.r>0.56 and glow.r<0.62 and displayed.r==1.0,"White highlights lack bounded glare/clipping")
		observations.append({"input":channel,"base":base.r,"glare":glow.r,"displayed":displayed.r})
		verify_composite(source,glare,first,"uniform "+str(channel))
	# Moving a bright source must move its glow in the very next rendered frame.
	background.color=Color(0.04,0.05,0.06)
	var patch:=ColorRect.new();patch.mouse_filter=Control.MOUSE_FILTER_IGNORE
	patch.position=Vector2(336,216);patch.size=Vector2(96,80);patch.color=Color(0.9,0.1,0.1)
	view.viewport.add_child(patch)
	var bright:=await rendered();write_image(bright,"bloom-red-patch")
	var halo:=bright.get_pixel(325,256);var distant:=bright.get_pixel(40,40)
	check(halo.r>distant.r+0.015,"Bright patch has no visible spatial glow")
	check(absf(halo.g-distant.g)<=1.0/255.0 and absf(halo.b-distant.b)<=1.0/255.0,"Spatial red glow leaked into other channels")
	verify_composite(view.viewport.get_texture().get_image(),owner.glare_texture().get_image(),bright,"red patch")
	patch.position=Vector2(96,216);patch.color=Color(0.1,0.9,0.1)
	var moved:=await rendered()
	check(moved.get_pixel(384,256).r<0.06 and moved.get_pixel(84,256).g>0.06,"Moved light left a stale red trail or lost new green glow")
	check(moved.get_data()==(await rendered()).get_data(),"Moving highlights require extra filter frames")
	patch.free()
	background.color=Color(0.15,0.2,0.25)
	var filtered_dim:=await rendered()
	check(view.set_bloom_enabled(false),view.error)
	var restored:=await rendered()
	check(filtered_dim.get_data()==restored.get_data(),"Disabling Bloom changes a dim scene")
	check(view.material==null and view._bloom==null and not is_instance_valid(owner),"Disable retained filter targets or display material")
	check(view.viewport==retained_viewport and view.texture==retained_texture,"Disable replaced the original viewport")
	await verify_pointer(view)
	view.size=Vector2(640,400);view.refresh_size();background.size=view.size
	check(view.viewport.size==Vector2i(640,400),"Resizing the view lost physical resolution")
	check(view.set_bloom_enabled(true),view.error)
	await rendered()
	check(view._bloom.glare_texture().get_size()==Vector2(256,256),"Bloom resolution incorrectly follows window aspect")
	view.hide()
	check(not view._bloom._active,"Hidden scene retained active filter targets")
	view.show();background.color=Color(0.1,0.9,0.1)
	var shown:=await rendered()
	check(shown.get_pixel(200,200).g==1.0 and shown.get_pixel(200,200).r<0.11,"Showing the view retained stale glare")
	view.set_bloom_enabled(false);background.free()
	view.size=Vector2(root.size);view.refresh_size()
	await verify_void(view,world)
	view.free()
	if not output_path.is_empty():
		var file:=FileAccess.open(output_path.path_join("bloom-observations.json"),FileAccess.WRITE)
		check(file!=null,"Cannot write Bloom observations")
		if file!=null:file.store_string(JSON.stringify(observations,"\t"));file.close()
	print("Bloom observations: ",JSON.stringify(observations))

func verify_pointer(view: Control) -> void:
	var clicked: Array=[]
	var button:=Button.new();button.position=Vector2(24,24);button.size=Vector2(150,50)
	button.text="Input probe";button.pressed.connect(func():clicked.append(true))
	view.viewport.add_child(button);check(view.set_bloom_enabled(true),view.error)
	await rendered()
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	event.position=Vector2(50,45);event.global_position=event.position;event.pressed=true
	view._gui_input(event);event.pressed=false;view._gui_input(event)
	check(clicked.size()==1,"Bloom intercepted embedded scene pointer input")
	button.free();view.set_bloom_enabled(false)

func verify_void(view: Control,world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var active:=FlightFrame.new()
	if not active.configure(bindings,catalogues,library,context,world):check(false,active.error);return
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);return
	var scene:=Scene.new();view.viewport.add_child(scene)
	if not scene.configure(library,bindings,visuals,catalogues,active,root.size):check(false,scene.error);scene.free();return
	active=stage_burning_shot(active,scene)
	if active==null:scene.free();return
	var before: Dictionary=active.snapshot();var world_before: Dictionary=world.snapshot()
	var viewport_before: SubViewport=view.viewport;var camera_before: Camera3D=scene.camera
	var off:=await rendered();write_image(off,"bloom-void-off")
	# Compare the display effect against one exact rendered source, rather than
	# asking two independent 3D draws to be byte-identical. Live first-frame
	# freshness is checked separately above with changing source colors/poses.
	var source_before: Image=view.viewport.get_texture().get_image()
	view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	check(view.set_bloom_enabled(true),view.error)
	var on:=await rendered();write_image(on,"bloom-void-on")
	var source: Image=view.viewport.get_texture().get_image()
	check(source.get_data()==source_before.get_data(),"Bloom rewrote the supplied scene framebuffer")
	var glare: Image=view._bloom.glare_texture().get_image()
	verify_composite(source,glare,on,"actual Void")
	var brighter:=0;var darker:=0
	for y in range(2,on.get_height(),4):
		for x in range(2,on.get_width(),4):
			var a:=off.get_pixel(x,y);var b:=on.get_pixel(x,y)
			if maxf(b.r-a.r,maxf(b.g-a.g,b.b-a.b))>0.01:brighter+=1
			if minf(b.r-a.r,minf(b.g-a.g,b.b-a.b)) < -2.0/255.0:darker+=1
	check(brighter>10,"Actual Void scene does not exercise the added glare")
	check(darker==0,"Bloom darkened the actual Void scene")
	observations.append({"scene":"Void burning freighter","brightened_samples":brighter,"darkened_samples":darker})
	check(view.set_bloom_enabled(false),view.error)
	var restored:=await rendered();write_image(restored,"bloom-void-restored")
	check(off.get_data()==restored.get_data(),"Disabling Bloom did not restore exact Void pixels")
	check(active.snapshot()==before and world.snapshot()==world_before,"Rendering Bloom changed the retained flight/world")
	check(view.viewport==viewport_before and scene.camera==camera_before,"Bloom rebuilt the retained scene or camera")
	scene.free()

func stage_burning_shot(active: RefCounted,scene: Node3D) -> RefCounted:
	# Only preceding radio completion is detached. Native frames still create
	# the damaged ship, particles and pullback camera. This setup exists to
	# exercise the new display filter, not to repeat battle/cinematic acceptance.
	active=active.skip_entry()
	if active==null:check(false,"Cannot stage the admitted flight");return null
	if not scene.present(active,root.size):check(false,scene.error);return null
	while active.campaign_dialogue_visible():
		var acknowledged: RefCounted=active.navigate("next")
		if acknowledged==null:check(false,active.error);return null
		active=acknowledged
		if not scene.present(active,root.size):check(false,scene.error);return null
	active._encounter=active._encounter.fork_for_frame()
	active._encounter._hook=active._encounter._hook.fork_for_frame()
	for index in 5:
		active._encounter._hook._radio._started[index]=true
		active._encounter._hook._radio._finished[index]=true
	var pullback_ms:=0
	for tick in 900:
		var next: RefCounted=active.evaluate(100,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id())
		if next==null:check(false,active.error);return null
		active=next
		if not scene.present(active,root.size):check(false,scene.error);return null
		if int(active.frame_context().encounter.sequence.phase)==4:
			pullback_ms+=100
			if pullback_ms>=6000:return active
	check(false,"New display test did not reach the native burning pullback");return null

func verify_composite(base: Image,glare: Image,actual: Image,label: String) -> void:
	var maximum:=0.0;var mismatches:=0;var compared:=0
	for y in range(5,actual.get_height(),19):
		for x in range(7,actual.get_width(),23):
			var uv:=(Vector2(x,y)+Vector2(0.5,0.5))/Vector2(actual.get_size())
			var extra:=bilinear(glare,uv);var original:=base.get_pixel(x,y)
			var expected:=Color(minf(1,original.r+extra.r),minf(1,original.g+extra.g),minf(1,original.b+extra.b))
			var difference:=color_error(actual.get_pixel(x,y),expected)
			maximum=maxf(maximum,difference);compared+=1
			if difference>2.0/255.0:mismatches+=1
	check(mismatches==0,"Final Bloom composite disagrees with displayed source + glare in %s: %d, max%.6f"%[label,mismatches,maximum])
	observations.append({"composite":label,"samples":compared,"mismatches":mismatches,"maximum_error":maximum})

func bilinear(image: Image,uv: Vector2) -> Color:
	var position:=uv*Vector2(image.get_size())-Vector2(0.5,0.5)
	var cell:=Vector2i(floori(position.x),floori(position.y));var fraction:=position-Vector2(cell)
	var a:=texel(image,cell).lerp(texel(image,cell+Vector2i.RIGHT),fraction.x)
	var b:=texel(image,cell+Vector2i.DOWN).lerp(texel(image,cell+Vector2i.ONE),fraction.x)
	return a.lerp(b,fraction.y)

func texel(image: Image,at: Vector2i) -> Color:
	return image.get_pixel(clampi(at.x,0,image.get_width()-1),clampi(at.y,0,image.get_height()-1))

func color_error(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func rendered() -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func write_image(image: Image,label: String) -> void:
	if output_path.is_empty():return
	DirAccess.make_dir_recursive_absolute(output_path)
	check(image.save_png(output_path.path_join(label+".png"))==OK,"Cannot write "+label)
