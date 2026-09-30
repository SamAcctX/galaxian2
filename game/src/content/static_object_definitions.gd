extends RefCounted
## Stationary story objects placed by a cast's `static_object` group option
## (the Valkyrie pirate outpost). This table is the one owner of which models
## a cast may place; unknown models are refused at mission entry.
const AEM=preload("res://src/content/aem.gd")
const Timing=preload("res://src/content/scenery_effect_resources.gd")
const Volumes=preload("res://src/content/station_collision_volumes.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")

## layers: hull, emissive and light meshes drawn together; a [mesh, offset]
## entry places that mesh at an offset in the model's own coordinates.
## collision: record in collision.bin; spheres x0.6, boxes x1.2, tested in the
## object's own (unrotated) axes. wreck_model: animation shown after death.
## wake_half_extent: an opposing active body this close on every axis wakes it.
## enemy_count_excluded: left out of the starting enemies-left count.
const MODELS:={
	14243:{"layers":[14243,14244,14245],"collision_resource":"resources/data/bin/collision.bin","collision_record":1002,
		"collision_record_limit":128,"sphere_scale":0.6,"box_scale":1.2,"wreck_model":14246,"death_sound":20,
		"wake_half_extent":50000,"hull":"outpost","enemy_count_excluded":true},
	# 80: the Valkyrie battlestation over Kothar. Station collision (record 101,
	# station frame and scales), cannot die in practice, no wreck.
	16928:{"layers":[16928,16929,16930],"collision_resource":"resources/data/bin/collision.bin","collision_record":101,
		"collision_record_limit":128,"sphere_scale":0.5,"box_scale":1.0,"station_frame":true,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# Its weak points: turret and shield. Hit as a 1000-unit cube, no wreck;
	# they vanish on death. Awake from the start (no sleeping).
	14363:{"layers":[14363],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":22,
		"wake_half_extent":100000000,"hull":"weak_point","enemy_count_excluded":false},
	14365:{"layers":[14365],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":22,
		"wake_half_extent":100000000,"hull":"weak_point","enemy_count_excluded":false},
	# 89: Naneroh's Midorian station, its burning twin after the blast, and a
	# container floating at the origin. Scenery only (no collision, no death).
	21076:{"layers":[21076,21876,22076],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# Assumption: the fire meshes (18832/18833, a registration type with no
	# loader yet) are left out: the twin is the station with its lights out.
	21876:{"layers":[21076,21876],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# 91: Valpatro's damaged freighter; the script ends it with an explosion.
	18766:{"layers":[18766],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":20,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# 92/94: the Midorian freighter: hull, two fixed parts and three cargo pods
	# in a row along its length (verified createStaticObject 17049). Hit as a
	# box over its length (its two bounding volumes are not decoded yet); the
	# 35 km LOD mesh is not used; death sound as the outpost's (assumption).
	17049:{"layers":[17049,17055,17054,[17052,Vector3(0,0,-2150)],[17053,Vector3(0,0,-2150)],[17052,Vector3.ZERO],[17053,Vector3.ZERO],
		[17052,Vector3(0,0,2150)],[17053,Vector3(0,0,2150)]],"collision_record":-1,"hit_radius":1000,"hit_extents":Vector3(1000,1000,3500),
		"wreck_model":18300,"death_sound":20,"wake_half_extent":0,"hull":"story_freighter","enemy_count_excluded":true},
	# 94: Luur's station platform: the Midorian station body with its platform
	# parts (verified createStaticObject 18781). It cannot die. The burning
	# parts 18781-18784 (registration type 6, no loader yet) are left out.
	18781:{"layers":[21076,21876,22076],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# 102: the Terran carrier, its hull and six parts (verified
	# createStaticObject 18804); the story keeps it unharmed.
	18804:{"layers":[18804,18805,18807,18808,18809,18810,18806],"collision_record":-1,"hit_radius":1500,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# 102: Tadram's exterior, drawn with station mesh 16800 (verified
	# createStaticObject 21113); invulnerable.
	21113:{"layers":[16800],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# 145/157: the plasma array platform (verified model 19050); its damaged
	# twin's model is open, so both draw 19050. The story keeps it unharmed.
	19050:{"layers":[19050],"collision_record":-1,"hit_radius":1500,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	# 158: three hostile objects at Luur with 100 hull each (model 18882; what
	# it depicts is open). Destroyable, no wreck.
	18882:{"layers":[18882],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":20,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
	16992:{"layers":[16992],"collision_record":-1,"hit_radius":1000,"wreck_model":-1,"death_sound":-1,
		"wake_half_extent":0,"hull":"indestructible","enemy_count_excluded":true},
}
const WAKE_MODE:=1
const DEAD_MODE:=3
const WRECK_MODE:=4
const MAX_BOXES:=64

static func supported(model: Variant) -> bool:
	return model is int and MODELS.has(model)

## The object's first drawn mesh (its body in target lists).
static func body_mesh(model: int) -> int:
	if not supported(model):return -1
	var first: Variant=MODELS[model].layers[0]
	return int(first[0]) if first is Array else int(first)

## How far the object reaches from its centre (its hit box), for docking.
static func reach(model: int) -> float:
	if not supported(model):return 0.0
	var extents: Vector3=MODELS[model].get("hit_extents",Vector3.ONE*float(MODELS[model].get("hit_radius",0)))
	return maxf(extents.x,maxf(extents.y,extents.z))

static func rules(model: int) -> Dictionary:
	return MODELS.get(model,{}).duplicate(true)

## Outpost hull: ((level<21 ? level*15+20 : 320) + (game won ? 180 : cursor*4))
## * 5, scaled by the game difficulty the same way as ship hulls.
static func hull(model: int,rank: int,cursor: int,difficulty: float) -> int:
	if not supported(model) or rank<0 or cursor<0:return -1
	match MODELS[model].hull:
		"indestructible":return 9999999
		# 80's weak points: no difficulty scale.
		"weak_point":return rank*15+220 if rank<21 else 520
		"outpost","story_freighter":pass
		_:return -1
	# The story freighter (92/94) uses the outpost rule with a larger base.
	var level:=(rank*15+20 if rank<21 else 320) if MODELS[model].hull=="outpost" else (rank*15+100 if rank<21 else 400)
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
	for entry in data.layers:
		var id: int=int(entry[0]) if entry is Array else int(entry)
		var path: String=bindings.resolve(id,"mesh")
		if path.is_empty():error=bindings.error;return {}
		layers.append({"resource_id":id,"path":path,"offset":entry[1] if entry is Array else Vector3.ZERO})
	# No wreck model: the object simply vanishes (an empty wreck path).
	var wreck:="";var timing:={"start_ms":0,"end_ms":0}
	if int(data.wreck_model)>=0:
		wreck=bindings.resolve(int(data.wreck_model),"mesh")
		if wreck.is_empty():error=bindings.error;return {}
		var mesh: Dictionary=AEM.new().decode(library.read_resource(wreck,AEM.MAX_BYTES))
		timing={} if mesh.is_empty() else Timing.playback_range(mesh.surfaces)
		if timing.is_empty() or int(timing.end_ms)<=int(timing.start_ms):error="Static object wreck animation is unavailable";return {}
	var result:={"model":model,"layers":layers,"wreck":{"resource_id":int(data.wreck_model),"path":wreck,"start_ms":int(timing.start_ms),"end_ms":int(timing.end_ms)},
		"death_sound":int(data.death_sound),"wake_half_extent":int(data.wake_half_extent),"enemy_count_excluded":bool(data.enemy_count_excluded)}
	# No collision record: hit as a cube of the hit radius, like a ship.
	if int(data.collision_record)<0:
		result.boxes=[{"offset":Vector3.ZERO,"half_extents":data.get("hit_extents",Vector3.ONE*float(data.hit_radius))}]
		return result
	var reader:=Volumes.new()
	var shapes: Dictionary=reader.decode(library.read_resource(data.collision_resource,Volumes.MAX_BYTES),int(data.collision_record),int(data.collision_record_limit),float(data.sphere_scale),float(data.box_scale))
	if shapes.is_empty():error=reader.error;return {}
	var boxes:=[]
	for shape in shapes.get("shapes",shapes.boxes.map(func(box):return {"kind":1,"center":box.center,"half_extents":box.half_extents})):
		# The station reader returns station-frame centers (half-turned about
		# Y); a fixed object is unrotated. Spheres are tested as their cubes.
		var center: Vector3=shape.center
		if not data.get("station_frame",false):center=Vector3(-center.x,center.y,-center.z)
		var half: Vector3=shape.half_extents if int(shape.kind)==1 else Vector3.ONE*float(shape.radius)
		boxes.append({"offset":center,"half_extents":half})
	if boxes.is_empty() or boxes.size()>MAX_BOXES:error="Static object collision exceeds the supported box count";return {}
	result.boxes=boxes
	return result
