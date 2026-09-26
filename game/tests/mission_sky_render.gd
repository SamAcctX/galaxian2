extends "res://tests/mission_escape_sequence.gd"
## Isolated GPU sky component over an admitted environment. Raw source rays,
## not rebuilt GPU mesh arrays, provide the sampling reference. This is not
## an earned battle or an original-framebuffer comparison.
const SkyRenderer = preload("res://src/presentation/opening_sky.gd")
const MeshReader = preload("res://src/content/aem.gd")
const VisualLibrary = preload("res://src/content/visual_library.gd")
var visual_path := ""
var diagnostics: Array = []

func verify(args: Array) -> void:
	visual_path=args[2]
	await super.verify(args)

func verify_component(world: RefCounted) -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Sky final-pixel comparison requires a GPU viewport");return
	var before: Dictionary=world.snapshot()
	var visuals := VisualLibrary.new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);return
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i.ZERO
	root.msaa_3d=Viewport.MSAA_DISABLED
	root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color.BLACK
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	root.add_child(environment)
	var camera := Camera3D.new();camera.current=true;camera.near=0.1;camera.far=1000.0;camera.fov=60.0
	root.add_child(camera)
	var sky := SkyRenderer.new();root.add_child(sky)
	if not sky.build_void(library,visuals,bindings,world.environment_owner()):
		check(false,sky.error);sky.free();camera.free();environment.free();return
	var raw: Array=[];var images: Array[Image]=[]
	for layer in sky.layers:
		var reader := MeshReader.new()
		var data: Dictionary=reader.decode(library.read_resource(bindings.resolve(layer.get_meta("source_resource_id"),"mesh"),MeshReader.MAX_BYTES))
		var image := visuals.load_image(layer.get_meta("source_texture_path"))
		if data.is_empty() or image==null:
			check(false,reader.error+visuals.error);sky.free();camera.free();environment.free();return
		raw.append(data);images.append(image)
	var views := [
		{"name":"forward","direction":Vector3.FORWARD,"up":Vector3.UP},
		{"name":"right","direction":Vector3.RIGHT,"up":Vector3.UP},
		{"name":"back","direction":Vector3.BACK,"up":Vector3.UP},
		{"name":"left","direction":Vector3.LEFT,"up":Vector3.UP},
		{"name":"up","direction":Vector3.UP,"up":Vector3.BACK},
		{"name":"down","direction":Vector3.DOWN,"up":Vector3.FORWARD},
		{"name":"oblique","direction":Vector3(-1.0,0.35,-1.0).normalized(),"up":Vector3.UP}]
	var points := sample_points()
	var coordinate_image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in coordinate_image.get_height():
		for x in coordinate_image.get_width():
			coordinate_image.set_pixel(x,y,Color(0.15+0.6*x/127.0,0.2+0.55*y/127.0,0.3+0.15*x/127.0+0.2*y/127.0))
	var composite_points: Array[Vector2i]=[]
	for y in range(4,root.size.y,8):
		for x in range(4,root.size.x,8):composite_points.append(Vector2i(x,y))
	var signal_counts:=[0,0]
	for view in views:
		camera.transform=Transform3D(sky.basis*Basis.looking_at(view.direction,view.up),Vector3.ZERO)
		check(sky.apply_view({"pose":camera.global_transform}),sky.error)
		sky.layers[1].hide()
		var stars := await render_image()
		sky.layers[0].hide();sky.layers[1].show()
		var nebula := await render_image()
		sky.layers[0].show()
		var combined := await render_image()
		var frame: Dictionary={"view":view.name,"layers":[],"composition_max_error":0.0,"composition_samples":0,"distinct_samples":0}
		for index in 2:
			var actual: Image=stars if index==0 else nebula
			var compared:=0;var maximum:=0.0;var mismatches:=0;var signal_samples:=0
			for point in points:
				var direction: Vector3=sky.global_basis.inverse()*camera.project_ray_normal(Vector2(point)+Vector2(0.5,0.5))
				var sample := source_sample(raw[index],images[index],direction)
				if sample.is_empty() or not sample.smooth:continue
				compared+=1
				if maxf(sample.color.r,maxf(sample.color.g,sample.color.b))>0.02:signal_samples+=1
				var difference := color_error(actual.get_pixelv(point),sample.color)
				maximum=maxf(maximum,difference)
				if difference>0.035:mismatches+=1
			check(compared>=60,"Insufficient smooth raw-source samples for %s layer %d: %d"%[view.name,index,compared])
			check(mismatches==0,"Final sky pixels disagree with raw source in %s layer %d: %d/%d, max %.6f"%[view.name,index,mismatches,compared,maximum])
			signal_counts[index]+=signal_samples
			frame.layers.append({"compared":compared,"signal_samples":signal_samples,"mismatches":mismatches,"maximum_error":maximum})
		var composition_failures:=0
		for point in composite_points:
			var star_color := stars.get_pixelv(point)
			var nebula_color := nebula.get_pixelv(point)
			var expected := additive_color(star_color,nebula_color)
			var difference := color_error(combined.get_pixelv(point),expected)
			frame.composition_samples+=1
			frame.composition_max_error=maxf(frame.composition_max_error,difference)
			if difference>3.0/255.0:composition_failures+=1
			if color_error(expected,star_color)>0.02 and color_error(expected,nebula_color)>0.02:frame.distinct_samples+=1
		check(composition_failures==0,"Sky additive composition mismatch in %s: %d, max %.6f"%[view.name,composition_failures,frame.composition_max_error])
		check(frame.distinct_samples>=20,"Composition reference cannot distinguish missing layers in "+view.name)
		frame.coordinate_reference=await verify_coordinates(sky,camera,raw,coordinate_image,points,view.name)
		diagnostics.append(frame)
		write_image(combined,"sky-"+view.name)
		if view.name=="oblique":
			write_image(stars,"sky-oblique-stars");write_image(nebula,"sky-oblique-nebula")
			camera.position=Vector3(300000.0,-120000.0,500000.0)
			check(sky.apply_view({"pose":camera.global_transform}),sky.error)
			var moved := await render_image()
			check(combined.get_data()==moved.get_data(),"Camera translation changes infinite sky pixels")
			await verify_foreground(camera)
	check(signal_counts[1]>=8,"Raw-source nebula oracle only sampled black texels")
	check(world.snapshot()==before,"Sky rendering mutated the retained mission world")
	var output := OS.get_environment("GOF2_CAPTURE_DIR")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("sky-composition.json"),FileAccess.WRITE)
		check(file!=null,"Cannot write sky composition diagnostics")
		if file!=null:file.store_string(JSON.stringify(diagnostics,"\t"));file.close()
	print("Sky composition views: ",JSON.stringify(diagnostics))
	sky.free();camera.free();environment.free()

func sample_points() -> Array[Vector2i]:
	var points: Array[Vector2i]=[]
	for y in 13:
		for x in 19:
			points.append(Vector2i(20+x*50,17+y*47))
	return points

func source_sample(decoded: Dictionary,image: Image,direction: Vector3) -> Dictionary:
	var nearest:=INF;var selected:=Vector2.ZERO;var edge:=0.0
	for surface in decoded.surfaces:
		for offset in range(0,surface.indices.size(),3):
			var ia: int=surface.indices[offset];var ib: int=surface.indices[offset+1];var ic: int=surface.indices[offset+2]
			var a: Vector3=surface.positions[ia];var u: Vector3=surface.positions[ib]-a;var v: Vector3=surface.positions[ic]-a
			if u.cross(v).dot(direction)>=0.0:continue
			var hit: Variant=Geometry3D.ray_intersects_triangle(Vector3.ZERO,direction,a,a+u,a+v)
			if hit==null:continue
			var distance: float=hit.length_squared()
			if distance>=nearest:continue
			var delta: Vector3=hit-a
			var determinant:=u.dot(u)*v.dot(v)-u.dot(v)*u.dot(v)
			if absf(determinant)<0.000001:continue
			var b: float=(v.dot(v)*delta.dot(u)-u.dot(v)*delta.dot(v))/determinant
			var c: float=(u.dot(u)*delta.dot(v)-u.dot(v)*delta.dot(u))/determinant
			nearest=distance;edge=minf(1.0-b-c,minf(b,c))
			selected=surface.uvs[ia]*(1.0-b-c)+surface.uvs[ib]*b+surface.uvs[ic]*c
	if nearest==INF or edge<0.03:return {}
	# Raw decoder coordinates remain untouched. The source shader path uses V4/5
	# image coordinates; this independent reference never reads Model's arrays.
	if int(decoded.version) in [4,5]:selected.y=1.0-selected.y
	var color := sample_linear(image,selected).linear_to_srgb()
	var smooth:=true
	# Exclude steep texel neighborhoods where anisotropic footprint selection,
	# not triangle ownership, dominates a point comparison. Count coverage above.
	var texel := Vector2i(floori(selected.x*image.get_width()),floori(selected.y*image.get_height()))
	for y in range(-2,3):
		for x in range(-2,3):
			var adjacent := texel_linear(image,texel+Vector2i(x,y)).linear_to_srgb()
			if color_error(color,adjacent)>0.06:smooth=false
	return {"color":color,"smooth":smooth}

func verify_coordinates(sky: Node3D,camera: Camera3D,raw: Array,image: Image,points: Array[Vector2i],label: String) -> Array:
	# Sparse stars mostly expose black texels to a smooth-sample oracle. A test-
	# owned smooth color ramp makes every tested UV informative, without changing
	# source meshes, the real sampler/shader, content packs or saved captures.
	var texture := ImageTexture.create_from_image(image)
	var result: Array=[]
	for index in sky.layers.size():
		for other in sky.layers.size():sky.layers[other].visible=other==index
		var originals: Array=[]
		for material in sky.layers[index].materials:
			originals.append(material.get_shader_parameter("diffuse_texture"))
			material.set_shader_parameter("diffuse_texture",texture)
		var rendered := await render_image()
		var count:=0;var mismatches:=0;var maximum:=0.0
		for point in points:
			var direction: Vector3=sky.global_basis.inverse()*camera.project_ray_normal(Vector2(point)+Vector2(0.5,0.5))
			var sample := source_sample(raw[index],image,direction)
			if sample.is_empty() or not sample.smooth:continue
			count+=1
			var difference := color_error(rendered.get_pixelv(point),sample.color)
			maximum=maxf(maximum,difference)
			if difference>0.015:mismatches+=1
		for material_index in originals.size():sky.layers[index].materials[material_index].set_shader_parameter("diffuse_texture",originals[material_index])
		check(count>=100,"Insufficient informative UV probes for %s layer %d"%[label,index])
		check(mismatches==0,"Sky coordinate ramp differs from raw mesh in %s layer %d: %d, max %.6f"%[label,index,mismatches,maximum])
		result.append({"samples":count,"mismatches":mismatches,"maximum_error":maximum})
	for layer in sky.layers:layer.show()
	return result

func sample_linear(image: Image,uv: Vector2) -> Color:
	var at := uv*Vector2(image.get_size())-Vector2(0.5,0.5)
	var base := Vector2i(floori(at.x),floori(at.y));var fraction:=at-Vector2(base)
	var top := texel_linear(image,base).lerp(texel_linear(image,base+Vector2i.RIGHT),fraction.x)
	var bottom := texel_linear(image,base+Vector2i.DOWN).lerp(texel_linear(image,base+Vector2i.ONE),fraction.x)
	return top.lerp(bottom,fraction.y)

func texel_linear(image: Image,at: Vector2i) -> Color:
	return image.get_pixel(posmod(at.x,image.get_width()),posmod(at.y,image.get_height())).srgb_to_linear()

func additive_color(stars: Color,nebula: Color) -> Color:
	var sum := stars.srgb_to_linear()+nebula.srgb_to_linear()
	return Color(minf(sum.r,1.0),minf(sum.g,1.0),minf(sum.b,1.0),1.0).linear_to_srgb()

func color_error(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func verify_foreground(camera: Camera3D) -> void:
	var box := MeshInstance3D.new();box.mesh=BoxMesh.new();box.mesh.size=Vector3.ONE*3.0
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color.RED
	box.material_override=material;root.add_child(box)
	box.global_transform=camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-10))
	var image := await render_image()
	var center := image.get_pixelv(root.size/2)
	check(center.r>0.98 and center.g<0.02 and center.b<0.02,"Sky layers overwrite opaque foreground")
	write_image(image,"sky-foreground");box.free()

func render_image() -> Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func write_image(image: Image,name: String) -> void:
	var output := OS.get_environment("GOF2_CAPTURE_DIR")
	if output.is_empty():return
	check(image.save_png(output.path_join(name+".png"))==OK,"Cannot save "+name)
