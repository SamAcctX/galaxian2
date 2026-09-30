extends RefCounted
## Stationary story objects placed by a cast's `static_object` group option
## (the Valkyrie pirate outpost). This table is the one owner of which models
## a cast may place; unknown models are refused at mission entry.
const AEM=preload("res://src/content/aem.gd")
const Timing=preload("res://src/content/scenery_effect_resources.gd")
const Volumes=preload("res://src/content/station_collision_volumes.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")

## layers: hull, emissive and light meshes drawn together.
## collision: record in collision.bin; spheres x0.6, boxes x1.2, tested in the
## object's own (unrotated) axes. wreck_model: animation shown after death.
## wake_half_extent: an opposing active body this close on every axis wakes it.
## enemy_count_excluded: left out of the starting enemies-left count.
const MODELS:={
	14243:{"layers":[14243,14244,14245],"collision_resource":"resources/data/bin/collision.bin","collision_record":1002,
		"collision_record_limit":128,"sphere_scale":0.6,"box_scale":1.2,"wreck_model":14246,"death_sound":20,
		"wake_half_extent":50000,"hull":"outpost","enemy_count_excluded":true},
}
const WAKE_MODE:=1
const DEAD_MODE:=3
const WRECK_MODE:=4
const MAX_BOXES:=64

static func supported(model: Variant) -> bool:
	return model is int and MODELS.has(model)

static func rules(model: int) -> Dictionary:
	return MODELS.get(model,{}).duplicate(true)

## Outpost hull: ((level<21 ? level*15+20 : 320) + (game won ? 180 : cursor*4))
## * 5, scaled by the game difficulty the same way as ship hulls.
static func hull(model: int,rank: int,cursor: int,difficulty: float) -> int:
	if not supported(model) or MODELS[model].hull!="outpost" or rank<0 or cursor<0:return -1
	var level:=rank*15+20 if rank<21 else 320
	var bonus:=180 if cursor>=Valkyrie.FIRST_CURSOR else cursor*4
	var base:=Vitals.single(float((level+bonus)*5))
	return int(Vitals.single(Vitals.single(Vitals.single(difficulty-0.5)*base)+base))

## Wake test: the other body is closer than `reach` on every axis.
static func within_reach(center: Vector3,point: Vector3,reach: float) -> bool:
	for axis in 3:
		if absf(point[axis]-center[axis])>=reach:return false
	return true

## Mesh paths, collision boxes and the wreck animation range, read from the
## player's imported content. Returns {} with `error` set on any mismatch.
var error:=""
func resolve(library: RefCounted,bindings: RefCounted,model: int) -> Dictionary:
	error=""
	if not supported(model):error="Unsupported static object model %d"%model;return {}
	var data: Dictionary=MODELS[model]
	var layers:=[]
	for id in data.layers:
		var path: String=bindings.resolve(int(id),"mesh")
		if path.is_empty():error=bindings.error;return {}
		layers.append({"resource_id":int(id),"path":path})
	var wreck: String=bindings.resolve(int(data.wreck_model),"mesh")
	if wreck.is_empty():error=bindings.error;return {}
	var mesh: Dictionary=AEM.new().decode(library.read_resource(wreck,AEM.MAX_BYTES))
	var timing: Dictionary={} if mesh.is_empty() else Timing.playback_range(mesh.surfaces)
	if timing.is_empty() or int(timing.end_ms)<=int(timing.start_ms):error="Static object wreck animation is unavailable";return {}
	var reader:=Volumes.new()
	var shapes: Dictionary=reader.decode(library.read_resource(data.collision_resource,Volumes.MAX_BYTES),int(data.collision_record),int(data.collision_record_limit),float(data.sphere_scale),float(data.box_scale))
	if shapes.is_empty():error=reader.error;return {}
	var boxes:=[]
	for shape in shapes.get("shapes",shapes.boxes.map(func(box):return {"kind":1,"center":box.center,"half_extents":box.half_extents})):
		# The station reader returns station-frame centers (half-turned about
		# Y); a fixed object is unrotated. Spheres are tested as their cubes.
		var center: Vector3=shape.center;center=Vector3(-center.x,center.y,-center.z)
		var half: Vector3=shape.half_extents if int(shape.kind)==1 else Vector3.ONE*float(shape.radius)
		boxes.append({"offset":center,"half_extents":half})
	if boxes.is_empty() or boxes.size()>MAX_BOXES:error="Static object collision exceeds the supported box count";return {}
	return {"model":model,"layers":layers,"wreck":{"resource_id":int(data.wreck_model),"path":wreck,"start_ms":int(timing.start_ms),"end_ms":int(timing.end_ms)},
		"boxes":boxes,"death_sound":int(data.death_sound),"wake_half_extent":int(data.wake_half_extent),"enemy_count_excluded":bool(data.enemy_count_excluded)}
