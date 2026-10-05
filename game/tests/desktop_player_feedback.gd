extends SceneTree
const Controls=preload("res://src/input/flight_controls.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const Style=preload("res://src/presentation/flight_hud_style.gd")
const Reticle=preload("res://src/presentation/flight_aim_reticle.gd")
const Frame=preload("res://src/presentation/flight_target_frame.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Visuals=preload("res://src/content/visual_library.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Supply the imported desktop content");quit(1);return
	var lib:=Library.new();var bindings:=Bindings.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+visuals.error);quit(1);return
	var aim:=Aim.new();check(aim.configure(bindings),aim.error)
	var player:=Transform3D(Basis(Vector3.LEFT,Vector3.UP,Vector3.FORWARD),Vector3.ZERO)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160)]:
		for cadence in [1.0/60.0,1.0/144.0,0.031]:
			var controls:=Controls.new();controls.set_mouse_active(true)
			var mouse:=InputEventMouseMotion.new();mouse.screen_relative=Vector2(48,27)
			check(controls.accept(mouse),"Captured mouse input was rejected")
			controls.advance_mouse(cadence,Vector2(resolution))
			var command: Vector2=controls.snapshot().command
			check(aim.advance(player,Transform3D.IDENTITY,resolution,command,true,true,true),aim.error)
			var point: Vector3=aim.snapshot().point
			check(Vector2(point.x,point.y).is_equal_approx(Vector2(resolution)*0.5+mouse.screen_relative),"Mouse cursor did not follow the same physical distance on this frame")
			var camera:=Transform3D(Basis(Vector3.UP,0.2),Vector3(10,0,0))
			check(aim.advance(player,camera,resolution,command,true,true,true),aim.error)
			check(Vector2(aim.snapshot().point.x,aim.snapshot().point.y)==Vector2(point.x,point.y),"Camera follow applied a second delay to the pointer")
			controls.advance_mouse(cadence,Vector2(resolution))
			check(controls.snapshot().command==command,"Stopping the mouse lost its retained flight deflection")
			mouse.screen_relative=Vector2(-48,-27);controls.accept(mouse);controls.advance_mouse(cadence,Vector2(resolution))
			check(controls.snapshot().command.is_zero_approx(),"Recentring the mouse kept steering")
			mouse.screen_relative=Vector2(resolution);controls.accept(mouse);controls.advance_mouse(cadence,Vector2(resolution))
			var edge: Vector2=controls.snapshot().command
			check(aim.advance(player,camera,resolution,edge,true,true,true),aim.error)
			var mouse_point: Vector3=aim.snapshot().point
			for pair in [[JOY_AXIS_LEFT_X,1.0],[JOY_AXIS_LEFT_Y,1.0]]:
				var stick:=InputEventJoypadMotion.new();stick.device=5;stick.axis=pair[0];stick.axis_value=pair[1];controls.accept(stick)
			check(aim.advance(player,camera,resolution,controls.snapshot().command,false,true,true),aim.error)
			check(aim.snapshot().point==mouse_point,"Controller could not reach the mouse's aim area")
			check(mouse_point.x<resolution.x and mouse_point.y<resolution.y,"Flight aim escaped the centered area")
	# UI scaling changes logical coordinates without changing physical pointer travel.
	var physical:=Vector2(1920,1080);var scaled:=Controls.new();scaled.set_mouse_active(true)
	var move:=InputEventMouseMotion.new();move.screen_relative=Vector2(64,32);scaled.accept(move);scaled.advance_mouse(1.0/60.0,physical)
	check(aim.advance(player,Transform3D.IDENTITY,Vector2i(physical/2),scaled.snapshot().command,true,true,true),aim.error)
	var logical: Vector3=aim.snapshot().point
	check((Vector2(logical.x,logical.y)*2-physical*0.5).is_equal_approx(move.screen_relative),"Menu scaling changed physical mouse travel")
	var reticle:=Reticle.new();root.add_child(reticle);reticle.size=Vector2(1920,1080)
	var frame:=Frame.new();root.add_child(frame);frame.size=reticle.size
	check(reticle.prepare(lib,bindings,visuals) and frame.prepare(lib,bindings,visuals),reticle.error+frame.error)
	var sample:=aim.snapshot();sample.visible=true
	Style.apply({"flight_hud_scale":1});reticle.present(sample);frame.reflow()
	var base_size:=reticle.sprite.size;var base_frame:=frame.marker_radii()
	var acquisition:=Frame.logical_radii(frame._quarter_size,false)
	for factor in [2,3,4]:
		Style.apply({"flight_hud_scale":factor,"flight_hud_filter":"nearest"});reticle.present(sample);frame.reflow()
		check(reticle.sprite.size==base_size*factor and frame.marker_radii()==base_frame*factor,"Flight HUD art ignored its separate integer scale")
		check((reticle.sprite.position+reticle.sprite.size*0.5).is_equal_approx(Vector2(sample.point.x,sample.point.y)),"Enlarging the cursor moved its aiming point")
		check(reticle.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Enlarged flight art retained blurry filtering")
		check(Frame.logical_radii(frame._quarter_size,false)==acquisition,"Flight HUD size enlarged the gameplay acquisition window")
	Style.apply({"flight_hud_scale":2,"flight_hud_filter":"linear"});reticle.present(sample)
	check(reticle.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"Smooth filtering option did not apply")
	Style.apply({});reticle.free();frame.free()
	print("Desktop player feedback: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
