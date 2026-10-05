extends Control
const Distance=preload("res://src/presentation/flight_distance.gd")
const HudStyle=preload("res://src/presentation/flight_hud_style.gd")
## Original route marker art with native distance text. Arrival belongs to the
## flight owner; projecting or resizing the HUD never advances the route.
const Story=preload("res://src/content/combat_training_story_definitions.gd")
const Rescue=preload("res://src/content/kappa_rescue_definitions.gd")
const Atlas=preload("res://src/content/atlas_region.gd")
const TargetFrame=preload("res://src/presentation/flight_target_frame.gd")
const TargetProjection=preload("res://src/presentation/target_projection.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _rules:={}
var _identity:={}
var _points:=[]
var _perspective:={}
var _quarter_size:=Vector2.ZERO
var _textures:={}
var _sample:={}
var _mobile:=false
var _cursor:=7

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true;visible=false

func prepare(library: RefCounted, bindings: RefCounted, visuals: RefCounted, cursor:=7) -> bool:
	error=""
	# Story courses (Supernova) mark one point the flight gives at run time.
	var story:=cursor>=84
	if not story and cursor!=7 and (cursor!=21 or not Rescue.available(bindings)):return reject("This flight has no supported authored player route")
	var rules:=Story.navigation(bindings)
	if rules.is_empty() or visuals==null or visuals.base_content_id!=bindings.base_content_id:return reject("Waypoint art requires its supported source profile")
	var frame:=TargetFrame.source_geometry(library,bindings)
	if frame.has("error"):return reject(frame.error)
	if int(frame.texture_id)!=int(rules.marker_texture_id):return reject("Waypoint and center-frame atlases disagree")
	var textures:={};var reader:=Atlas.new()
	for name in ["in_view","outside"]:
		var alias: Dictionary=bindings.resolve_image_region(int(rules[name+"_image_id"]),int(rules.marker_texture_id))
		if alias.is_empty() or int(alias.region)!=int(rules[name+"_region"]):return reject("Waypoint image alias is unsupported")
		var texture:=reader.load(library,visuals,frame.resource,int(alias.region))
		if texture==null:return reject(reader.error)
		textures[name]=texture
	_rules=rules;_textures=textures;_quarter_size=frame.quarter_size
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	var points: Array=[] if story else bindings.mido_travel.kappa_rescue.population.waypoints if cursor==21 else bindings.combat_training.waypoints
	_points=points.map(func(point):return Vector3(point[0],point[1],point[2]));_cursor=cursor
	_perspective=bindings.flight_projection.duplicate(true);_sample={};visible=false
	return true

func present(route: Dictionary, camera: Transform3D, viewport: Vector2i, hud_enabled: bool) -> bool:
	error=""
	if _rules.is_empty():return reject("Prepare waypoint art before presenting it")
	if route.is_empty():_sample={};visible=false;queue_redraw();return true
	for key in _identity:
		if route.get(key)!=_identity[key]:return reject("Waypoint route belongs to another flight")
	if route.get("story",false) and route.get("point") is Vector3:route={"owner":"player","campaign_cursor":_cursor,"loop":false,"waypoints":[route.point],"index":0,"completed":false};_points=[route.waypoints[0]]
	if route.get("owner")!="player" or route.get("campaign_cursor")!=_cursor or route.get("loop")!=false or route.get("waypoints")!=_points or not Numbers.integer(route.get("index"),0,_points.size()) or route.get("completed")!=(route.index==_points.size()):return reject("Unsupported player waypoint route")
	var sample:={"visible":false,"index":route.index}
	if route.index<_points.size():
		var projection:=TargetProjection.new()
		if not projection.configure(_perspective,viewport,TargetFrame.logical_radii(_quarter_size,_mobile)):return reject(projection.error)
		var point: Vector3=_points[route.index]
		var projected:=projection.project(camera,point)
		if projected.has("error"):return reject(projected.error)
		var meters:=distance_meters(point,camera.origin)
		if meters<0:return reject("Waypoint distance exceeds supported coordinates")
		sample.merge({"visible":hud_enabled and (projected.in_view or projected.ellipse_clamped),"in_view":projected.in_view,"pixels":projected.pixels,"distance_meters":meters,"distance_text":distance_text(meters),"viewport":viewport},true)
	_sample=sample;visible=sample.visible;queue_redraw()
	return true

func distance_meters(point: Vector3,eye: Vector3) -> int:return Distance.meters(point,eye,_rules)
func distance_text(meters: int) -> String:return Distance.label(meters,_rules)

func set_mobile_layout(value: bool) -> void:_mobile=value;queue_redraw()
func snapshot() -> Dictionary:return _sample.duplicate(true)

func _draw() -> void:
	if _sample.is_empty() or not _sample.visible:return
	# One phone composition uses the original center frame as its scale anchor.
	texture_filter=HudStyle.filtering()
	var scale_factor:=TargetFrame.logical_radii(_quarter_size,_mobile).x/_quarter_size.x*HudStyle.multiplier
	var texture: Texture2D=_textures.in_view if _sample.in_view else _textures.outside
	var extent:=texture.get_size()*scale_factor
	var point:=Vector2(_sample.pixels)
	if not _sample.in_view:point=(size*0.5+(point-size*0.5)*HudStyle.multiplier).clamp(Vector2.ONE*16,size-Vector2.ONE*16)
	draw_texture_rect(texture,Rect2(point-extent*0.5,extent),false)
	if _sample.in_view:
		var font:=get_theme_font("font");var font_size:=HudStyle.font_size(22 if _mobile else 14)
		var text_width:=font.get_string_size(_sample.distance_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var label_position:=point+Vector2(-text_width*0.5,extent.y*0.5+font.get_ascent(font_size)+2)
		draw_string_outline(font,label_position,_sample.distance_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(0,0,0,.8))
		draw_string(font,label_position,_sample.distance_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)

func reject(message: String) -> bool:error=message;return false
