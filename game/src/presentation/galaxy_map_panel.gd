extends Control
## Original galaxy meshes and atlas, with native mouse, touch and pad input.
signal system_requested(system_id: int)
signal close_requested
const Sounds=preload("res://src/presentation/ui_sounds.gd")
const Navigation=preload("res://src/simulation/galaxy_map.gd")
const OriginalUI=preload("res://src/presentation/original_ui.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Model=preload("res://src/presentation/imported_model.gd")
const AEM=preload("res://src/content/aem.gd")
const Portal=preload("res://src/presentation/portal_geometry.gd")
const Playback=preload("res://src/simulation/model_playback.gd")
var error:=""
var _navigation: RefCounted
var _art: RefCounted
var _view: SubViewport
var _world: Node3D
var _camera: Camera3D
var _canvas: GalaxyCanvas
var _footer: TextureRect
var _header: TextureRect
var _title: Label
var _back: Button
var _open: Button
var _key: Button
var _notice: PanelContainer
var _message: Label
var _legend: PanelContainer
var _legend_rows: VBoxContainer
var _warning: Node3D
var _warning_state:={}
var _active:=false
var _mobile:=false
var _elapsed:=0.0
var _zoom:=1.0
var _pan:=Vector2.ZERO
var _center:=Vector2.ZERO
var _focus_target:=Vector2.ZERO
var _centering:=false
var _dragging:=false
var _pressed:=Vector2.ZERO
var _dragged:=false

class GalaxyCanvas extends Control:
	var rows:=[]
	var links:=[]
	var route:=[]
	var selected:=-1
	var sprites:={}
	var font: Font
	var mobile:=false
	var elapsed:=0.0
	func _draw() -> void:
		if font==null or sprites.is_empty():return
		var points:={}
		for row in rows:points[row.system_id]=row.pixels
		var current:=-1
		for row in rows:
			if row.current:current=row.system_id
		for edge in links:
			if points.has(edge[0]) and points.has(edge[1]):
				var alpha:=0.13
				if edge.has(current):alpha=0.45+0.4*sin(elapsed*3.0)
				draw_line(points[edge[0]],points[edge[1]],Color(0.5,0.75,0.8,alpha),1.0,true)
		if route.size()>1:
			var progress:=fmod(elapsed, float(route.size()-1))
			for i in range(route.size()-1):
				if not points.has(route[i]) or not points.has(route[i+1]):continue
				if i<int(progress):draw_line(points[route[i]],points[route[i+1]],Color.YELLOW,2.0,true)
				elif i==int(progress):draw_line(points[route[i]],points[route[i]].lerp(points[route[i+1]],progress-i),Color.YELLOW,2.0,true)
		var extent:=44.0 if mobile else 36.0
		var fs:=18 if mobile else 14
		var icon:=18.0 if mobile else 14.0
		for row in rows:
			var p: Vector2=row.pixels
			if not Rect2(Vector2(-60,-60),size+Vector2(120,120)).has_point(p):continue
			draw_texture_rect(sprites[1164 if row.system_id==selected else 1162],Rect2(p-Vector2.ONE*extent/2,Vector2.ONE*extent),false)
			if row.current:draw_texture_rect(sprites[1277],Rect2(p-Vector2.ONE*extent/2,Vector2.ONE*extent),false,Color(1,1,1,0.5+0.5*sin(elapsed*4)))
			var width:=font.get_string_size(row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
			var anchor:=p+Vector2(-(width+icon+3)/2,extent/2+fs)
			var tint:=Color.WHITE if selected<0 or row.system_id==selected else Color(1,1,1,0.55)
			draw_texture_rect(sprites[row.faction_image_id],Rect2(anchor-Vector2(0,icon-1),Vector2.ONE*icon),false,tint)
			anchor.x+=icon+3
			draw_string(font,anchor+Vector2.ONE,row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color.BLACK)
			draw_string(font,anchor,row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(1,0.5,0) if row.system_id==selected else tint)
			var markers:=[]
			if row.story_target:markers.append(1108)
			if row.contract_target:markers.append(1109)
			for index in markers.size():draw_texture_rect(sprites[markers[index]],Rect2(p+Vector2(extent/2,-extent/2+index*icon),Vector2.ONE*icon),false)

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true
	var container:=SubViewportContainer.new();container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(container);container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view=SubViewport.new();_view.own_world_3d=true;_view.handle_input_locally=false;_view.gui_disable_input=true
	_view.msaa_3d=Viewport.MSAA_4X;_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;container.add_child(_view)
	_world=Node3D.new();_view.add_child(_world)
	_camera=Camera3D.new();_camera.keep_aspect=Camera3D.KEEP_HEIGHT;_camera.near=200;_camera.far=64000;_camera.fov=rad_to_deg(1.1504);_world.add_child(_camera)
	_canvas=GalaxyCanvas.new();add_child(_canvas);_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_header=TextureRect.new();_header.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_header.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_header)
	_title=Label.new();_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_title)
	_footer=TextureRect.new();_footer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_footer)
	_back=Button.new();_open=Button.new();_key=Button.new()
	for button in [_back,_open,_key]:add_child(button);button.focus_mode=Control.FOCUS_NONE
	_back.pressed.connect(func():close_requested.emit());_open.pressed.connect(open_selected);_key.pressed.connect(func():_legend.visible=not _legend.visible;_layout())
	_notice=PanelContainer.new();add_child(_notice);_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_message=Label.new();_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_notice.add_child(_message)
	_legend=PanelContainer.new();add_child(_legend);_legend.visible=false
	_legend_rows=VBoxContainer.new();_legend.add_child(_legend_rows)
	resized.connect(_layout)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,cat: RefCounted,observation: Dictionary) -> bool:
	error=""
	var navigation:=Navigation.new();var art:=OriginalUI.new()
	if not navigation.configure(library,bindings,cat,observation) or not art.configure(library,bindings,visuals):return reject(navigation.error+art.error)
	var state:=navigation.snapshot()
	var extras:=art.load_regions(library,bindings,visuals,[1164]+state.ui.faction_image_ids,state.ui.atlas_resources)
	if extras.is_empty():return reject(art.error)
	art.sprites.merge(extras)
	var stage:=Node3D.new();var resources:=Models.new();var paths:=[]
	for id in state.visuals.background_model_ids:
		var path: String=bindings.resolve(int(id),"mesh")
		if path.is_empty():stage.free();return reject(bindings.error)
		paths.append(path)
	if not resources.prepare(paths,library,visuals,bindings,"high",true):stage.free();return reject(resources.error)
	for index in paths.size():
		var node: Node3D=resources.instantiate(paths[index]);node.position=Vector3(3000,-2500,0)
		node.set_meta("source_resource_id",int(state.visuals.background_model_ids[index]));stage.add_child(node)
	resources.clear()
	var meshes:={};var textures:={}
	for row in state.rows:
		var path: String=bindings.resolve(row.model_id,"mesh")
		if path.is_empty():stage.free();return reject(bindings.error)
		var registrations: Array=bindings.records[row.model_id]
		var material_id:=int(registrations[0].get("material_id",-1))
		if material_id<0 or not registrations.all(func(item):return int(item.get("material_id",-1))==material_id):stage.free();return reject("Galaxy star has ambiguous material ownership")
		var material: Dictionary=bindings.resolve_material(material_id,"high")
		if material.is_empty():stage.free();return reject(bindings.error)
		if not meshes.has(path):
			var reader:=AEM.new();meshes[path]=reader.decode(library.read_resource(path,AEM.MAX_BYTES))
			if meshes[path].is_empty():stage.free();return reject(reader.error)
		var texture_path: String=material.texture_paths[0]
		if not textures.has(texture_path):textures[texture_path]=visuals.load_image(texture_path)
		if textures[texture_path]==null:stage.free();return reject(visuals.error)
		var star:=Model.new();star.build(meshes[path],textures[texture_path],null,int(material.render_type))
		star.position=_position(row.position);star.scale=Vector3.ONE*0.012;stage.add_child(star)
		star.set_meta("source_system_id",row.system_id);star.set_meta("source_resource_id",row.model_id)
	var warning: Node3D;var warning_state:={}
	if not state.void_warning.is_empty():
		warning=Portal.new()
		var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"model_id":16994}
		if not warning._build_portal(library,visuals,bindings,identity):var message: String=warning.error;warning.free();stage.free();return reject(message)
		stage.add_child(warning)
		# Keep the screen-plane depth negligible without a singular GPU matrix.
		var pose:=Transform3D(Basis.from_scale(Vector3(1,1,0.0001)),Vector3.ZERO)
		for row in state.rows:
			if row.void_source:pose.origin=_position(row.position)+Vector3(0,0,1)
		var animation: Dictionary=warning._sampler.snapshot().range
		animation.time_ms=animation.start_ms;animation.playing=true
		warning_state=identity.duplicate();warning_state.merge({"pose":pose,"scale":0.02,"visible":true,"animation":animation})
	clear();_navigation=navigation;_art=art;_warning=warning;_warning_state=warning_state;_world.add_child(stage)
	for row in state.rows:
		if row.current:_center=Vector2(-row.position.x,row.position.y);break
	var style:=Theme.new();style.default_font=art.font;theme=style
	_canvas.font=art.font;_canvas.sprites=art.sprites;_canvas.links=state.links;_canvas.route=state.mission_route
	_footer.texture=art.sprites[int(state.ui.footer_image_id)]
	_header.texture=_footer.texture;_title.text=state.labels.title
	_back.text=state.labels.back;_open.text=state.labels.open;_key.text=state.labels.key
	for entry in state.ui.legend:
		var line:=HBoxContainer.new();_legend_rows.add_child(line)
		var icon:=TextureRect.new();icon.texture=art.sprites[int(entry.image_id)];icon.custom_minimum_size=Vector2(22,22);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(icon)
		var label:=Label.new();label.text=library.strings[int(entry.text_id)];line.add_child(label)
	visible=true;_camera.make_current();_layout();_present()
	return true

static func _position(source: Vector3) -> Vector3:return Vector3(-source.x,source.y,-source.z)

func _process(delta: float) -> void:
	if not visible or not _active or _navigation==null:return
	_elapsed+=delta;_canvas.elapsed=_elapsed;_canvas.queue_redraw()
	if _centering:
		_pan=_pan.lerp(_focus_target,1.0-exp(-delta*8.0))
		if _pan.distance_to(_focus_target)<1:_pan=_focus_target;_centering=false
		_project()
	for stage in _world.get_children():
		if stage==_camera:continue
		for model in stage.get_children():
			if model.has_method("set_source_time"):model.set_source_time(_elapsed*1000.0)
	if _warning!=null:
		Playback.advance([_warning_state.animation],int(delta*1000.0),true)
		var prepared: Dictionary=_warning.prepare_state(_warning_state)
		if not prepared.is_empty():_warning.commit_state(prepared)

func _gui_input(event: InputEvent) -> void:
	if not _active:return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom=clampf(_zoom*(0.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/0.85),0.4,8.0);_project();accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:_pointer(event.position,event.pressed)
	elif event is InputEventScreenTouch:_pointer(event.position,event.pressed)
	elif (event is InputEventMouseMotion and _dragging) or event is InputEventScreenDrag:
		if event.position.distance_to(_pressed)>5:_dragged=true
		if _dragged:
			_centering=false;_pan+=Vector2(-event.relative.x,event.relative.y)*(2500*_zoom+5000)/maxf(1,size.y);_project();accept_event()
	elif event is InputEventMagnifyGesture:_zoom=clampf(_zoom/event.factor,0.4,8.0);_project();accept_event()

func _pointer(point: Vector2,pressed: bool) -> void:
	if pressed:_dragging=true;_dragged=false;_pressed=point
	else:
		if _dragging and not _dragged:
			var closest:=-1;var distance:=34.0 if _mobile else 26.0
			for row in _canvas.rows:
				var d: float=row.pixels.distance_to(point)
				if d<distance:distance=d;closest=row.system_id
			if closest>=0:
				if _navigation.snapshot().selected_system_id==closest:open_selected()
				else:_navigation.select_system(closest);_center_selected();_present();Sounds.event(self,Sounds.MAP_SYSTEM)
		_dragging=false
	accept_event()

func handle_event(event: InputEvent) -> bool:
	if not visible:return false
	if not _active:return true
	var direction:=Vector2.ZERO;var open:=false;var back:=false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		back=key in [KEY_ESCAPE,KEY_M];open=key in [KEY_ENTER,KEY_KP_ENTER]
		if key in [KEY_LEFT,KEY_A]:direction=Vector2.LEFT
		elif key in [KEY_RIGHT,KEY_D,KEY_TAB]:direction=Vector2.RIGHT
		elif key in [KEY_UP,KEY_W]:direction=Vector2.UP
		elif key in [KEY_DOWN,KEY_S]:direction=Vector2.DOWN
	elif event is InputEventJoypadButton and event.pressed:
		back=event.button_index==JOY_BUTTON_B;open=event.button_index==JOY_BUTTON_A
		if event.button_index==JOY_BUTTON_DPAD_LEFT:direction=Vector2.LEFT
		elif event.button_index==JOY_BUTTON_DPAD_RIGHT:direction=Vector2.RIGHT
		elif event.button_index==JOY_BUTTON_DPAD_UP:direction=Vector2.UP
		elif event.button_index==JOY_BUTTON_DPAD_DOWN:direction=Vector2.DOWN
	if back:close_requested.emit()
	elif open:open_selected()
	elif not direction.is_zero_approx():_navigation.move_selection(direction);_center_selected();_present();Sounds.event(self,Sounds.MAP_SYSTEM)
	return true

func _center_selected() -> void:
	var state: Dictionary=_navigation.snapshot()
	for row in state.rows:
		if row.system_id==state.selected_system_id:
			_focus_target=Vector2(-row.position.x,row.position.y)-_center;_centering=true;return

func open_selected() -> void:
	if not _active or _navigation==null:return
	var id: int=_navigation.open_selected()
	_present()
	if id>=0:system_requested.emit(id)

func _present() -> void:
	if _navigation==null:return
	var state: Dictionary=_navigation.snapshot();_canvas.selected=state.selected_system_id
	_message.text=error if not error.is_empty() else state.diagnostic;_notice.visible=not _message.text.is_empty()
	for button in [_back,_open,_key]:button.disabled=not _active
	_canvas.queue_redraw();_layout()

func _layout() -> void:
	if not visible or _art==null:return
	var height:=60.0 if _mobile else 44.0
	_header.size=Vector2(size.x,44 if _mobile else 30)
	_title.position=Vector2(14,5);_title.add_theme_font_size_override("font_size",20 if _mobile else 14)
	_footer.position=Vector2(0,size.y-height);_footer.size=Vector2(size.x,height)
	for button in [_back,_open,_key]:_art.apply_button(button,_mobile,button==_back);button.size=Vector2(112,44 if _mobile else 30)
	_back.position=Vector2(8,size.y-height+7);_open.position=Vector2(size.x-120,size.y-height+7);_key.position=Vector2(size.x/2-56,size.y-height+7)
	for panel in [_notice,_legend]:panel.add_theme_stylebox_override("panel",_art.styles[_mobile].panel)
	_message.add_theme_font_size_override("font_size",18 if _mobile else 14)
	var message_width:=minf(size.x-64,560.0)
	_message.custom_minimum_size=Vector2(message_width-32,0)
	_notice.size=Vector2(message_width,70);_notice.position=Vector2((size.x-_notice.size.x)/2,_header.size.y+12)
	_legend.size=_legend.get_combined_minimum_size();_legend.position=Vector2(size.x-_legend.size.x-8,size.y-height-_legend.size.y-8)
	_canvas.mobile=_mobile;_project()

func _project() -> void:
	if _navigation==null or size.x<1 or size.y<1:return
	var state: Dictionary=_navigation.snapshot()
	_camera.position=Vector3(_center.x+_pan.x,_center.y+_pan.y,2500*_zoom)
	var rows:=[]
	for row in state.rows:
		row.pixels=_camera.unproject_position(_position(row.position));rows.append(row)
	_canvas.rows=rows;_canvas.queue_redraw()

func set_active(value: bool) -> void:
	_active=value and visible
	_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if _active else SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED
	_present()
func set_mobile_layout(value: bool) -> void:_mobile=value;_layout()
func snapshot() -> Dictionary:return {} if _navigation==null else _navigation.snapshot()
func set_error(message: String) -> void:error=message;_present()
func clear() -> void:
	visible=false;_active=false;_navigation=null;_art=null;_warning=null;_warning_state={};_elapsed=0;_pan=Vector2.ZERO;_center=Vector2.ZERO;_zoom=1.0;_centering=false
	for child in _world.get_children():
		if child!=_camera:child.free()
	for child in _legend_rows.get_children():child.free()
	_canvas.rows=[];_canvas.font=null;_canvas.sprites={};_notice.visible=false;_legend.visible=false
	_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;error=""
func reject(message: String) -> bool:error=message;return false
