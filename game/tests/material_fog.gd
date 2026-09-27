extends SceneTree
## Render distance, blend order, transparency and pass exclusions on the GPU.
const Fog=preload("res://src/presentation/material_fog.gd")
const Materials=preload("res://src/presentation/material_library.gd")
const Response=preload("res://src/presentation/surface_response.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
var plane: MeshInstance3D
var camera: Camera3D
var reference: ShaderMaterial
var fog:={"color":Vector3(0.1,0.6,0.2),"end":10.0}

func _initialize() -> void:
	create_timer(90).timeout.connect(func():push_error("Fog render checks timed out");quit(1))
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Fog checks require a GPU");quit(1);return
	viewport=SubViewport.new();viewport.size=Vector2i(65,65);viewport.own_world_3d=true
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.current=true;viewport.add_child(camera)
	plane=MeshInstance3D.new();plane.mesh=QuadMesh.new();plane.mesh.size=Vector2(2,2);plane.position.z=-4;viewport.add_child(plane)
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, fog_disabled; uniform vec4 value:source_color; void fragment(){ALBEDO=value.rgb;}"
	reference=ShaderMaterial.new();reference.shader=shader
	var pigment:=Color(0.2,0.4,0.6)
	var halfway:=Vector3(pigment.r,pigment.g,pigment.b).lerp(fog.color,sqrt(18.0)/10.0)
	for mode in [0,1,6,10,18]:
		var material:=Materials.create(mode,texture(pigment),null,false)
		if mode==6:
			material.set_shader_parameter("ambient_color",Vector3.ONE)
			material.set_shader_parameter("diffuse_color",Vector3.ZERO)
		Fog.apply(material,fog)
		await probe(material,halfway,"mode %d interpolates radial fog in display channels"%mode)
		plane.position.z=-20
		await probe(material,fog.color,"mode %d reaches full distance fog"%mode)
		plane.position.z=-4
		if mode in [0,1,10,18]:
			material.set_shader_parameter("surface_tint",Vector4(0.2,0.3,0.4,1))
			await probe(material,halfway,"fogged texture pass retains its pigment independently of RGB tint")
			material.set_shader_parameter("surface_tint",Vector4.ONE)
		Fog.apply(material,{})
		await probe(material,Vector3(0.2,0.4,0.6),"mode %d clears fog on location change"%mode)
	var transparent:=Materials.create(1,texture(Color(0.2,0.4,0.6,0.4)),null,false)
	plane.material_override=transparent
	var clear_alpha: Color=await sample()
	Fog.apply(transparent,fog)
	var fog_alpha: Color=await sample()
	check(absf(clear_alpha.a-fog_alpha.a)<0.005 and fog_alpha.a>0.2 and fog_alpha.a<0.8,"Fog changed a transparent surface's opacity")
	var cutout:=Materials.create(10,texture(Color(0.2,0.4,0.6,0.2)),null,false)
	Fog.apply(cutout,fog);plane.material_override=cutout
	check((await sample()).a<0.01,"Fog filled an alpha-cutout hole")
	for mode in [2,3]:
		var glow:=Materials.create(mode,texture(Color(0.1,0.2,0.1)),null,false)
		plane.material_override=glow
		var before: Color=await sample()
		Fog.apply(glow,fog)
		check(before.is_equal_approx(await sample()),"Fog changed an additive glow")
	var planet:=Materials.create(1,texture(pigment),null,false)
	planet.shader=preload("res://src/presentation/sky_planet.gdshader")
	Fog.apply(planet,fog)
	await probe(planet,halfway,"planet fog uses finite plane distance despite background depth")
	var effect:=ShaderMaterial.new();effect.shader=preload("res://src/presentation/scenery_effect_alpha.gdshader")
	effect.set_shader_parameter("diffuse_texture",texture(pigment))
	effect.set_shader_parameter("darken_value",0.6);Fog.apply(effect,fog)
	effect.set_shader_parameter("effect_tint",Vector4(0.2,0.3,0.4,1))
	await probe(effect,halfway*0.6,"effect darkening follows the fog blend")
	var cube:=Cubemap.new();var faces: Array[Image]=[]
	for index in 6:
		var face:=Image.create(2,2,false,Image.FORMAT_RGBA8);face.fill(Color.BLACK);faces.append(face)
	check(cube.create_from_images(faces)==OK,"Could not create black reflection fixture")
	var surface:={"ambient_rgb":[1,1,1],"diffuse_rgb":[1,1,1],"specular_rgb":[1,1,1],"specular_power":20}
	var state:={"global_ambient":Vector3.ONE*0.5,"rim_color":Vector3.ZERO,"fog":fog,"lights":[]}
	for index in 2:state.lights.append({"direction_to_light":Vector3.BACK,"ambient":Vector3.ZERO,"diffuse":Vector3.ZERO,"specular":Vector3.ZERO})
	var response:=Response.new()
	check(response.build(surface,state,texture(pigment),texture(Color(0.5,0.5,1,0)),cube,0,0,"two_light_cube"),response.error)
	if response.material!=null:
		await probe(response.material,halfway,"lit surfaces blend fog after illumination")
		# Uniform object scaling leaves camera-to-vertex distance in model space.
		plane.scale=Vector3.ONE*2
		await probe(response.material,Vector3(0.2,0.4,0.6).lerp(fog.color,sqrt(6.0)/10.0),"scaled geometry uses its retained model coordinates")
		plane.scale=Vector3.ONE
		camera.position.x=3
		# At screen center x=3 no quad is visible; move the camera and object
		# together to check translation without changing the relative view.
		plane.position.x=3
		await probe(response.material,halfway,"camera translation preserves fog distance")
	for bad in [{"color":Vector3.ONE,"end":0},{"color":Vector3(NAN,0,0),"end":10},{"color":Vector3.ONE*2,"end":10}]:
		state.fog=bad
		check(not response.build(surface,state,texture(pigment),texture(Color(0.5,0.5,1,0)),cube,0,0,"two_light_cube") and response.material==null,"Invalid fog retained a drawable material")
	viewport.free()
	print("Material fog: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func probe(material: ShaderMaterial, expected: Vector3, label: String) -> void:
	plane.material_override=material
	var actual: Color=await sample()
	reference.set_shader_parameter("value",Color(expected.x,expected.y,expected.z));plane.material_override=reference
	var control: Color=await sample()
	check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(control.r,control.g,control.b))<0.018,label+": "+str(actual)+" expected "+str(control))

func sample() -> Color:
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image().get_pixel(32,32)

func texture(color: Color) -> Texture2D:
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(color)
	return ImageTexture.create_from_image(image)

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
