extends Control
## Directional hit arcs on the centre-frame ellipse. A drop in the player's
## combined pools is a hit; the arc faces the nearest active hostile and fades
## out over the original 300 ms. Blue art while shields hold, red without.
const Definitions=preload("res://src/content/flight_hud_definitions.gd")
const OriginalUI=preload("res://src/presentation/original_ui.gd")
const TargetFrame=preload("res://src/presentation/flight_target_frame.gd")
const HudStyle=preload("res://src/presentation/flight_hud_style.gd")
var error:=""
var mobile_layout:=false
var _textures:={}
var _quarter:=Vector2.ZERO
var _last_total:=-1.0
var _now_ms:=0
var _blue:=true
## Side -> flight time (ms) of the latest hit lighting it.
var _lit:={}

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	visible=false

func prepare(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	error="";_textures={};_lit={};_last_total=-1.0
	var frame:=TargetFrame.source_geometry(library,bindings)
	if frame.has("error"):return reject(frame.error)
	var ui: Dictionary=bindings.mido_travel.get("map",{}).get("ui",{})
	if not ui.has("atlas_resources"):return reject("This content has no hit-arc art")
	var art:=OriginalUI.new()
	var images:=art.load_regions(library,bindings,visuals,Definitions.HIT_ARC_IMAGES.values(),ui.atlas_resources)
	if images.is_empty():return reject(art.error)
	for key in Definitions.HIT_ARC_IMAGES:_textures[key]=images[Definitions.HIT_ARC_IMAGES[key]]
	_quarter=frame.quarter_size
	return true

## Reads one flight snapshot. Returns false only for unusable input.
func present(state: Dictionary,tangents: Vector2) -> bool:
	error=""
	if _textures.is_empty():return reject("Prepare the hit arcs before presenting them")
	var vitals: Variant=state.get("player",{}).get("vitals")
	if not vitals is Dictionary:_last_total=-1.0;visible=false;return true
	_now_ms=int(state.get("world_phase_elapsed_ms",0))
	var total:=float(vitals.get("hull",0))+float(vitals.get("armor",0))+float(vitals.get("shield",0.0))
	_blue=float(vitals.get("shield",0.0))>0.0
	if _last_total>=0.0 and total<_last_total-0.001 and float(vitals.get("hull",0))>0.0:
		var camera: Variant=state.get("camera_view",{}).get("pose")
		var shooter: Variant=nearest_hostile(state)
		if camera is Transform3D and shooter is Vector3:
			register_hit(Definitions.hit_sides(camera.affine_inverse()*shooter,tangents),_now_ms)
	_last_total=total
	visible=not _lit.is_empty()
	queue_redraw()
	return true

static func nearest_hostile(state: Dictionary) -> Variant:
	var player: Variant=state.get("player_pose")
	if not player is Transform3D:return null
	var best: Variant=null;var distance:=INF
	for actor in state.get("actors",[]):
		if not actor is Dictionary or not actor.get("hostile",false) or not actor.get("active",true) or not actor.get("pose") is Transform3D:continue
		var gap: float=actor.pose.origin.distance_squared_to(player.origin)
		if gap<distance:distance=gap;best=actor.pose.origin
	return best

func register_hit(sides: Array,now_ms: int) -> void:
	for side in sides:_lit[side]=now_ms
	_now_ms=now_ms

func arc_alpha(side: String,now_ms: int) -> float:
	if not _lit.has(side):return 0.0
	var age:=now_ms-int(_lit[side])
	if age<0 or age>=Definitions.HIT_ARC_MS:return 0.0
	return 1.0-float(age)/float(Definitions.HIT_ARC_MS)

func set_mobile_layout(value: bool) -> void:
	mobile_layout=value;queue_redraw()

func _draw() -> void:
	if _quarter==Vector2.ZERO:return
	texture_filter=HudStyle.filtering()
	var radii:=TargetFrame.logical_radii(_quarter,mobile_layout)*HudStyle.multiplier
	var scale_factor:=radii.x/_quarter.x
	var center:=Vector2(floorf(size.x*0.5),floorf(size.y*0.5))
	var colour:="blue" if _blue else "red"
	for side in _lit.keys():
		var alpha:=arc_alpha(side,_now_ms)
		if alpha<=0.0:_lit.erase(side);continue
		var vertical: bool=side in ["top","bottom"]
		var texture: Texture2D=_textures[("top_" if vertical else "side_")+colour]
		var extent:=texture.get_size()*scale_factor
		# The atlas holds the right and top arcs; left and bottom are mirrored.
		# Each arc's outer edge touches the ellipse end and the art lies inside.
		var anchor: Vector2=center+{"left":Vector2(-radii.x,0),"right":Vector2(radii.x,0),"top":Vector2(0,-radii.y),"bottom":Vector2(0,radii.y)}[side]
		var flip:=Vector2(-1 if side=="left" else 1,-1 if side=="bottom" else 1)
		var corner:=Vector2(-extent.x*0.5,0) if vertical else Vector2(-extent.x,-extent.y*0.5)
		draw_set_transform(anchor,0.0,flip)
		draw_texture_rect(texture,Rect2(corner,extent),false,Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)

func clear() -> void:
	_lit={};_last_total=-1.0;visible=false;queue_redraw()

func reject(message: String) -> bool:error=message;return false
