extends "res://tests/mission_sky_render.gd"
## Source-channel sky input, not a matched original display or an earned route.
## Reuse the independent raw ray/triangle oracle, not the renderer's mesh arrays.
const View=preload("res://src/presentation/native_scene_view.gd")
const FlightFrame=preload("res://src/simulation/mission_flight_frame.gd")
const Scene=preload("res://src/presentation/mission_scene.gd")

func verify_component(world: RefCounted) -> void:
	if DisplayServer.get_name()=="headless":check(false,"Channel composition requires a GPU");return
	var before: Dictionary=world.snapshot()
	var visuals:=VisualLibrary.new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);return
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i.ZERO
	root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color.BLACK
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;root.add_child(environment)
	var camera:=Camera3D.new();camera.current=true;camera.near=0.1;camera.far=1000;camera.fov=60;root.add_child(camera)
	var sky:=SkyRenderer.new();root.add_child(sky)
	check(not sky.set_stored_channel_composition(true),"Unbuilt sky accepted a display mode")
	if not sky.build_void(library,visuals,bindings,world.environment_owner()):check(false,sky.error);sky.free();camera.free();environment.free();return
	check(not sky._stored_channels,"Ordinary sky silently changed channel arithmetic")
	var raw: Array=[];var images: Array[Image]=[];var textures: Array=[];var layers: Array=sky.layers.duplicate()
	for layer in sky.layers:
		var reader:=MeshReader.new()
		raw.append(reader.decode(library.read_resource(bindings.resolve(layer.get_meta("source_resource_id"),"mesh"),MeshReader.MAX_BYTES)))
		images.append(visuals.load_image(layer.get_meta("source_texture_path")))
		textures.append(layer.materials[0].get_shader_parameter("diffuse_texture"))
	camera.transform=Transform3D(sky.basis,Vector3.ZERO);sky.apply_view({"pose":camera.global_transform})
	var original:=await render_image();write_image(original,"channels-current-forward")
	var previous: Shader=sky.layers[1].materials[0].shader
	sky.layers[1].materials[0].shader=sky.STAR_SHADER
	check(not sky.set_stored_channel_composition(true) and sky.layers[0].materials[0].shader==sky.STAR_SHADER and not sky._stored_channels,"Foreign material caused a partial sky transition")
	sky.layers[1].materials[0].shader=previous
	check(sky.set_stored_channel_composition(true) and sky.set_stored_channel_composition(true),sky.error)
	check(sky.layers==layers,"Channel mode rebuilt sky nodes")
	for index in 2:check(sky.layers[index].materials[0].get_shader_parameter("diffuse_texture")==textures[index],"Channel mode replaced a source texture")
	await verify_uniform_channels(sky,textures)
	await inspect_copy_roundtrip(sky,textures)
	await verify_interpolation(sky,camera,raw[0],textures)
	var views:=[{"name":"forward","direction":Vector3.FORWARD,"up":Vector3.UP},{"name":"up","direction":Vector3.UP,"up":Vector3.BACK},{"name":"oblique","direction":Vector3(-1,0.35,-1).normalized(),"up":Vector3.UP}]
	for view in views:
		camera.transform=Transform3D(sky.basis*Basis.looking_at(view.direction,view.up),Vector3.ZERO)
		sky.apply_view({"pose":camera.global_transform})
		sky.set_stored_channel_composition(false);var ordinary:=await render_image()
		sky.set_stored_channel_composition(true)
		# Read each intermediate channel carrier, not two separately completed
		# and quantized sky images. The display encode is undone on these probes.
		sky.layers[1].hide();var stars:=await render_image()
		sky.layers[0].hide();sky.layers[1].show()
		for material in sky.layers[1].materials:material.shader=sky.STORED_STAR_SHADER
		var nebula:=await render_image()
		for material in sky.layers[1].materials:material.shader=sky.STORED_NEBULA_SHADER
		sky.layers[0].show();var combined:=await render_image()
		var row: Dictionary={"view":view.name,"raw_samples":0,"raw_mismatches":0,"raw_maximum":0.0,"sum_samples":0,"sum_mismatches":0,"raw_sum_to_display_maximum":0.0,"distinct_samples":0,"ordinary_outside_reference":0,"first_errors":[]}
		for index in 2:
			var image: Image=stars if index==0 else nebula
			for point in sample_points():
				var direction: Vector3=sky.global_basis.inverse()*camera.project_ray_normal(Vector2(point)+Vector2(0.5,0.5))
				var sample:=source_sample(raw[index],images[index],direction)
				if sample.is_empty() or not sample.smooth:continue
				var difference:=color_error(image.get_pixelv(point).srgb_to_linear(),sample.color)
				row.raw_samples+=1;row.raw_maximum=maxf(row.raw_maximum,difference)
				if difference>0.035:row.raw_mismatches+=1
		var reference:=await reference_output_range(sky,stars,nebula)
		for y in range(4,root.size.y,8):
			for x in range(4,root.size.x,8):
				var a:=stars.get_pixel(x,y).srgb_to_linear();var b:=nebula.get_pixel(x,y).srgb_to_linear()
				var expected:=channel_sum(a,b);var difference:=color_error(combined.get_pixel(x,y),expected)
				row.sum_samples+=1;row.raw_sum_to_display_maximum=maxf(row.raw_sum_to_display_maximum,difference)
				if not within_output_range(combined.get_pixel(x,y),reference[0].get_pixel(x,y),reference[1].get_pixel(x,y)):
					row.sum_mismatches+=1
					if row.first_errors.size()<3:row.first_errors.append({"point":[x,y],"actual":str(combined.get_pixel(x,y)),"lower":str(reference[0].get_pixel(x,y)),"upper":str(reference[1].get_pixel(x,y))})
				if not within_output_range(ordinary.get_pixel(x,y),reference[0].get_pixel(x,y),reference[1].get_pixel(x,y)):row.ordinary_outside_reference+=1
				if color_error(expected,super.additive_color(a,b))>0.02:row.distinct_samples+=1
		check(row.raw_samples>=120 and row.raw_mismatches==0,"Stored-channel raw samples disagree: "+JSON.stringify(row))
		check(row.sum_mismatches==0 and row.distinct_samples>=20,"Stored-channel addition lacks correct/distinct output: "+JSON.stringify(row))
		check(row.ordinary_outside_reference>=20,"Output reference cannot reject ordinary linear-light composition")
		diagnostics.append(row);write_image(combined,"channels-"+view.name)
		if view.name=="oblique":
			camera.position=Vector3(300000,-120000,500000);sky.apply_view({"pose":camera.global_transform})
			check(combined.get_data()==(await render_image()).get_data(),"Channel composition moved the infinite sky")
			await verify_foreground(camera)
			await verify_alpha_foreground(camera,sky,textures)
	camera.transform=Transform3D(sky.basis,Vector3.ZERO);sky.apply_view({"pose":camera.global_transform})
	check(sky.set_stored_channel_composition(false) and sky.set_stored_channel_composition(false),sky.error)
	var restored:=await render_image()
	check(original.get_data()==restored.get_data(),"Disabling source-channel composition did not restore accepted sky pixels")
	for index in 2:check(sky.layers[index].materials[0].get_shader_parameter("diffuse_texture")==textures[index],"Test failed to restore a source texture")
	sky.clear();check(not sky._stored_channels and sky.layers.is_empty(),"Cleared sky retained composition state")
	sky.free();camera.free();environment.free()
	await verify_burning_scene(world,visuals)
	check(world.snapshot()==before,"Sky composition changed the native mission world")
	var output:=OS.get_environment("GOF2_CAPTURE_DIR")
	if not output.is_empty():
		var file:=FileAccess.open(output.path_join("sky-channels.json"),FileAccess.WRITE)
		check(file!=null,"Cannot write channel diagnostics")
		if file!=null:file.store_string(JSON.stringify(diagnostics,"\t"));file.close()
	print("Sky channel observations: ",JSON.stringify(diagnostics))

func bind_texture(layer: Node3D,texture: Texture2D) -> void:
	for material in layer.materials:material.set_shader_parameter("diffuse_texture",texture)

func reference_output_range(sky: Node3D,stars: Image,nebula: Image) -> Array[Image]:
	# Carrier readbacks are eight-bit DISPLAY images, not the float values the
	# next GPU pass reads. Bracket their one-code readback uncertainty, calculate
	# the channel sum on the CPU, then send that already-composed linear color
	# through a separate passthrough material. It has no sky sampler or addition.
	# This includes the actual renderer's output precision without weakening a
	# fixed pixel tolerance to absorb unexplained dark-channel differences.
	check(stars.get_format() in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8] and nebula.get_format()==stars.get_format(),"Carrier interval requires matching eight-bit readbacks")
	var lower:=Image.create(root.size.x,root.size.y,false,Image.FORMAT_RGBAF);lower.fill(Color.BLACK)
	var upper:=Image.create(root.size.x,root.size.y,false,Image.FORMAT_RGBAF);upper.fill(Color.BLACK)
	for y in range(4,root.size.y,8):
		for x in range(4,root.size.x,8):
			var a:=stars.get_pixel(x,y);var b:=nebula.get_pixel(x,y)
			lower.set_pixel(x,y,channel_sum(carrier_bound(a,-1),carrier_bound(b,-1)).srgb_to_linear())
			upper.set_pixel(x,y,channel_sum(carrier_bound(a,1),carrier_bound(b,1)).srgb_to_linear())
	var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2)
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,blend_mix,depth_test_disabled,depth_draw_never,cull_disabled,fog_disabled;uniform sampler2D reference_color:filter_nearest,repeat_disable;uniform sampler2D copied_background:hint_screen_texture,filter_nearest;void vertex(){POSITION=vec4(VERTEX.xy,0.0,1.0);}void fragment(){ALBEDO=texture(reference_color,SCREEN_UV).rgb+texture(copied_background,SCREEN_UV).rgb*0.0;ALPHA=1.0;}"
	var material:=ShaderMaterial.new();material.shader=shader;quad.material_override=material
	quad.custom_aabb=AABB(Vector3.ONE*-1e9,Vector3.ONE*2e9);root.add_child(quad)
	for layer in sky.layers:layer.hide()
	var result: Array[Image]=[]
	for image in [lower,upper]:
		material.set_shader_parameter("reference_color",ImageTexture.create_from_image(image))
		result.append(await render_image())
	quad.free()
	for layer in sky.layers:layer.show()
	return result

func carrier_bound(value: Color,direction: float) -> Color:
	var step:=direction/255.0
	return Color(clampf(value.r+step,0,1),clampf(value.g+step,0,1),clampf(value.b+step,0,1),1).srgb_to_linear()

func within_output_range(actual: Color,lower: Color,upper: Color) -> bool:
	var code:=1.0/255.0
	return actual.r>=lower.r-code and actual.r<=upper.r+code and actual.g>=lower.g-code and actual.g<=upper.g+code and actual.b>=lower.b-code and actual.b<=upper.b+code

func verify_uniform_channels(sky: Node3D,textures: Array) -> void:
	var a:=Image.create(1,1,false,Image.FORMAT_RGBA8);a.fill(Color(0.4,0.2,0.65))
	var b:=Image.create(1,1,false,Image.FORMAT_RGBA8);b.fill(Color(0.3,0.1,0.55))
	bind_texture(sky.layers[0],ImageTexture.create_from_image(a));bind_texture(sky.layers[1],ImageTexture.create_from_image(b))
	sky.set_stored_channel_composition(false);var ordinary:=await render_image()
	sky.set_stored_channel_composition(true);var result:=await render_image()
	var expected:=channel_sum(a.get_pixel(0,0),b.get_pixel(0,0));var point:=Vector2i(480,300)
	check(color_error(result.get_pixelv(point),expected)<=2.0/255.0,"Uniform stored-channel sum/clipping is wrong: actual %s expected %s"%[result.get_pixelv(point),expected])
	check(color_error(ordinary.get_pixelv(point),expected)>0.08,"Uniform oracle cannot distinguish the ordinary arithmetic")
	write_image(result,"channels-uniform-sum")
	for index in 2:bind_texture(sky.layers[index],textures[index])

func verify_interpolation(sky: Node3D,camera: Camera3D,raw: Dictionary,textures: Array) -> void:
	var ramp:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	for y in 2:ramp.set_pixel(0,y,Color(0.1,0.2,0.9));ramp.set_pixel(1,y,Color(0.9,0.7,0.1))
	bind_texture(sky.layers[0],ImageTexture.create_from_image(ramp));sky.layers[1].hide()
	sky.set_stored_channel_composition(false);var ordinary:=await render_image()
	sky.set_stored_channel_composition(true);var actual:=await render_image()
	var count:=0;var errors:=0;var distinct:=0;var maximum:=0.0
	for point in sample_points():
		var direction: Vector3=sky.global_basis.inverse()*camera.project_ray_normal(Vector2(point)+Vector2(0.5,0.5))
		var sample:=source_sample(raw,ramp,direction)
		if sample.is_empty():continue
		count+=1;var difference:=color_error(actual.get_pixelv(point).srgb_to_linear(),sample.color);maximum=maxf(maximum,difference)
		if difference>0.015:errors+=1
		if color_error(ordinary.get_pixelv(point),sample.color)>0.02:distinct+=1
	check(count>=100 and errors==0 and distinct>=20,"Raw-channel interpolation mismatch: %d/%d, distinct%d, max%.6f"%[errors,count,distinct,maximum])
	diagnostics.append({"interpolation_samples":count,"mismatches":errors,"distinct_from_linear":distinct,"maximum_error":maximum})
	bind_texture(sky.layers[0],textures[0]);sky.layers[1].show()

func inspect_copy_roundtrip(sky: Node3D,textures: Array) -> void:
	var black:=Image.create(1,1,false,Image.FORMAT_RGBA8);black.fill(Color.BLACK)
	bind_texture(sky.layers[1],ImageTexture.create_from_image(black))
	var values: Array=[]
	for value in [0.0,0.03,0.05,0.07,0.1,0.3,0.5,1.0]:
		var source:=Image.create(1,1,false,Image.FORMAT_RGBA8);source.fill(Color(value,0,0))
		bind_texture(sky.layers[0],ImageTexture.create_from_image(source))
		sky.layers[1].hide();var first:=await render_image()
		sky.layers[1].show();var copied:=await render_image()
		var carrier:=first.get_pixel(480,300).srgb_to_linear().r
		check(absf(carrier-source.get_pixel(0,0).r)<=1.0/255.0,"Opaque carrier loses stored channel precision")
		check(absf(copied.get_pixel(480,300).r-source.get_pixel(0,0).r)<=2.0/255.0,"Completed sky fails a dark-channel round trip")
		values.append({"input":source.get_pixel(0,0).r,"carrier":carrier,"completed":copied.get_pixel(480,300).r})
	for index in 2:bind_texture(sky.layers[index],textures[index])
	diagnostics.append({"copy_roundtrip":values});print("Copy roundtrip: ",JSON.stringify(values))

func sample_at_uv(image: Image,selected: Vector2) -> Dictionary:
	var color:=sample_linear(image,selected);var smooth:=true
	var texel:=Vector2i(floori(selected.x*image.get_width()),floori(selected.y*image.get_height()))
	for y in range(-2,3):
		for x in range(-2,3):
			if color_error(color,texel_linear(image,texel+Vector2i(x,y)))>0.06:smooth=false
	return {"color":color,"smooth":smooth}

func texel_linear(image: Image,at: Vector2i) -> Color:
	# This oracle interpolates stored channels, without an implicit color decode.
	return image.get_pixel(posmod(at.x,image.get_width()),posmod(at.y,image.get_height()))

func channel_sum(a: Color,b: Color) -> Color:
	return Color(minf(a.r+b.r,1),minf(a.g+b.g,1),minf(a.b+b.b,1),1)

func verify_alpha_foreground(camera: Camera3D,sky: Node3D,textures: Array) -> void:
	# A well-resolved colored background makes this an ordering test, not an
	# assertion about the renderer's near-black alpha-target quantization.
	var source:=Image.create(1,1,false,Image.FORMAT_RGBA8);source.fill(Color(0.3,0.25,0.2))
	for layer in sky.layers:bind_texture(layer,ImageTexture.create_from_image(source))
	var base:=await render_image();var point:=root.size/2
	var box:=MeshInstance3D.new();box.mesh=BoxMesh.new();box.mesh.size=Vector3.ONE*3
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,blend_mix;void fragment(){ALBEDO=vec3(0,0,1);ALPHA=0.5;}"
	var material:=ShaderMaterial.new();material.shader=shader;material.render_priority=0;box.material_override=material
	root.add_child(box);box.global_transform=camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-10))
	var rendered:=await render_image();var expected:=base.get_pixelv(point).srgb_to_linear().lerp(Color.BLUE,0.5).linear_to_srgb()
	check(color_error(rendered.get_pixelv(point),expected)<=3.0/255.0,"Sky composition overwrites later alpha geometry: base %s actual %s expected %s"%[base.get_pixelv(point),rendered.get_pixelv(point),expected])
	var overlay:=ColorRect.new();overlay.size=Vector2(32,32);overlay.color=Color.GREEN;root.add_child(overlay)
	var with_ui:=await render_image();check(color_error(with_ui.get_pixel(8,8),Color.GREEN)<=1.0/255.0,"Sky composition alters later UI")
	write_image(with_ui,"channels-alpha-and-ui");overlay.free();box.free()
	for index in 2:bind_texture(sky.layers[index],textures[index])

func verify_burning_scene(world: RefCounted,visuals: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var active:=FlightFrame.new()
	if not active.configure(bindings,catalogues,library,context,world):check(false,active.error);return
	var view:=View.new();view.size=Vector2(root.size);root.add_child(view);view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var scene:=Scene.new();view.viewport.add_child(scene)
	if not scene.configure(library,bindings,visuals,catalogues,active,root.size):check(false,scene.error);view.free();return
	active=stage_burning_shot(active,scene)
	if active==null:view.free();return
	var before: Dictionary=active.snapshot();var camera: Camera3D=scene.camera;var lights: Node3D=scene.environment.lights
	var sky: Node3D=scene.environment._void.sky
	var off:=await render_image();write_image(off,"channels-burning-current")
	check(sky.set_stored_channel_composition(true),sky.error)
	var on:=await render_image();write_image(on,"channels-burning-source")
	check(sky.set_stored_channel_composition(false),sky.error)
	var restored:=await render_image();var mismatches:=0;var changed:=0
	for y in range(3,root.size.y,7):
		for x in range(3,root.size.x,7):
			if color_error(off.get_pixel(x,y),restored.get_pixel(x,y))>2.0/255.0:mismatches+=1
			if color_error(off.get_pixel(x,y),on.get_pixel(x,y))>0.01:changed+=1
	check(mismatches==0,"Disabling channel mode failed to restore the burning scene")
	check(changed>10,"Burning scene did not exercise the new channel policy")
	check(active.snapshot()==before and scene.camera==camera and scene.environment.lights==lights,"Sky mode changed simulation, camera or lighting owners")
	check(view._bloom==null and view.material==null,"Channel choice silently enabled a screen effect")
	diagnostics.append({"burning_changed_samples":changed,"restoration_mismatches":mismatches});view.free()

func stage_burning_shot(active: RefCounted,scene: Node3D) -> RefCounted:
	# Detached preceding radio completion only; native frames create the burn,
	# cast motion and pullback. This is a renderer component, not earned combat.
	active=active.skip_entry()
	if active==null:check(false,"Cannot stage admitted flight");return null
	if not scene.present(active,root.size):check(false,scene.error);return null
	while active.campaign_dialogue_visible():
		var acknowledged: RefCounted=active.navigate("next")
		if acknowledged==null:check(false,active.error);return null
		active=acknowledged
		if not scene.present(active,root.size):check(false,scene.error);return null
	active._encounter=active._encounter.fork_for_frame();active._encounter._hook=active._encounter._hook.fork_for_frame()
	for index in 5:active._encounter._hook._radio._started[index]=true;active._encounter._hook._radio._finished[index]=true
	var pullback_ms:=0
	for tick in 900:
		var next: RefCounted=active.evaluate(100,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id())
		if next==null:check(false,active.error);return null
		active=next
		if not scene.present(active,root.size):check(false,scene.error);return null
		if int(active.frame_context().encounter.sequence.phase)==4:
			pullback_ms+=100
			if pullback_ms>=6000:return active
	check(false,"Renderer component did not reach native burning pullback");return null
