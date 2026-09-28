extends SubViewport
## A completed 3D background, including transparent skies and planets.
## Layer 20 belongs to the cloaked player while this capture is active.
const PLAYER_LAYER:=1<<19
var _source: Viewport
var _camera: Camera3D
var _meshes: Array=[]
var _active:=false

func prepare(ship: Node3D) -> void:
	_source=ship.get_viewport()
	for node in ship.find_children("*","MeshInstance3D",true,false):
		_meshes.append({"node":node,"layers":node.layers})
	world_3d=ship.get_world_3d();gui_disable_input=true;handle_input_locally=false
	render_target_update_mode=UPDATE_DISABLED
	ship.add_child(self)
	_camera=Camera3D.new();add_child(_camera);_camera.current=true
	RenderingServer.frame_pre_draw.connect(_sync_camera)
	tree_exiting.connect(func():RenderingServer.frame_pre_draw.disconnect(_sync_camera))

func set_active(value: bool) -> void:
	if value!=_active:
		for row in _meshes:row.node.layers=PLAYER_LAYER if value else row.layers
	_active=value
	render_target_update_mode=UPDATE_WHEN_VISIBLE if value else UPDATE_DISABLED

func _sync_camera() -> void:
	if not _active or not is_instance_valid(_source):return
	var camera:=_source.get_camera_3d()
	if camera==null:return
	size=Vector2i(_source.get_visible_rect().size)
	msaa_3d=_source.msaa_3d;screen_space_aa=_source.screen_space_aa
	_camera.projection=camera.projection;_camera.keep_aspect=camera.keep_aspect
	_camera.fov=camera.fov;_camera.size=camera.size
	_camera.near=camera.near;_camera.far=camera.far
	_camera.h_offset=camera.h_offset;_camera.v_offset=camera.v_offset
	_camera.frustum_offset=camera.frustum_offset
	_camera.environment=camera.environment;_camera.attributes=camera.attributes
	_camera.cull_mask=camera.cull_mask & ~PLAYER_LAYER
	_camera.global_transform=camera.global_transform
