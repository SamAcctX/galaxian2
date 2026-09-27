extends SceneTree
## An asymmetric image must stay upright on every supported mesh encoding.
const Model=preload("res://src/presentation/imported_model.gd")
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(128,128);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.position.z=3;camera.set_orthogonal(2,0.1,10);camera.current=true
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:image.set_pixel(x,y,[Color.RED,Color.GREEN,Color.BLUE,Color.WHITE][int(y/8)*2+int(x/8)])
	var surface:={"positions":PackedVector3Array([Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)]),
		"indices":PackedInt32Array([0,1,2,0,2,3]),"uvs":PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),
		"normals":PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK]),"colors":PackedColorArray(),"pivot":Vector3.ZERO,"tracks":{}}
	for version in [2,3,4,5]:
		var decoded:={"version":version,"surfaces":[surface]}
		var original: Dictionary=decoded.duplicate(true)
		var model:=Model.new();viewport.add_child(model);model.build(decoded,image,null,0)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var frame:=viewport.get_texture().get_image()
		for row in [[Vector2i(32,32),Color.RED],[Vector2i(96,32),Color.GREEN],[Vector2i(32,96),Color.BLUE],[Vector2i(96,96),Color.WHITE]]:
			var actual:=frame.get_pixelv(row[0]);var expected: Color=row[1]
			check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(expected.r,expected.g,expected.b))<0.05,"Mesh%d mirrored or inverted the displayed image at%s"%[version,row[0]])
		check(decoded==original,"Rendering changed the raw mesh coordinates")
		model.free()
	viewport.free()
	print("Imported UV: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
