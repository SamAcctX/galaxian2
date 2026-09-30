extends RefCounted
## Supernova gas clouds and plasma sparks. Plain Dictionary state so a flight
## frame can duplicate/fork it; a given seed replays the same clouds/sparks.
## The caller decides whether clouds exist at all (spectral filter fitted,
## not in the Void) and turns picked plasma into cargo, sound and HUD.
##
## - A system's plasma is the top entry of its probability list: per plasma,
##   100 - trunc(galaxy-map distance to the plasma's origin system), 0 below
##   50, sorted descending (ties keep item order), minus 2 per rank.
## - Red as top type gives no clouds in a system with no jump routes, except
##   Y'mirr.
## - Cloud count floor((4..7) x top% / 100) (+ extra); each placed uniformly
##   in the +-80000 cube, more than 25000 from the origin.
## - An ion blast ionizes each cloud whose centre is inside its radius into
##   sparks that fly toward the cloud centre, slow down, live 8..22 s, fade
##   over 1.5 s. From 2 s after ionizing, in turret view, sparks within 800
##   are taken (1 plasma each, lost when the hold is full) and a collector
##   pulls sparks inside its capture box and range straight at the player.
const Random=preload("res://src/simulation/seeded_random.gd")
const PLASMA_IDS:=[201,202,203,204]
const RED:=204
const YMIRR:=10
const ORIGIN_PROPERTY:=4
const MAP_X_FIELD:=3
const MAP_Y_FIELD:=4
const MIN_PERCENT:=50
const RANK_PENALTY:=2
const BASE_COUNT:=4
const COUNT_SPREAD:=4
const CUBE_HALF:=80000
const MIN_ORIGIN_DISTANCE:=25000.0
const SPARK_SCALE:=130.0
const SPARK_BASE:=10.0
const DEFAULT_STRENGTH:=50
const SPARK_CUBE:=5000.0
const SPEED_MIN:=3
const SPEED_SPREAD:=4
const SPEED_BOOST:=7.0
const SPEED_DECAY:=0.08
const LIFE_MIN:=8000
const LIFE_SPREAD:=14000
const FADE_MS:=1500
const READY_MS:=2000
const PICKUP_RANGE:=800.0
const NEAR_FADE:=3500.0
const NEAR_FADE_SPAN:=2700.0
## Assumption: the collector's centred capture box (screen/9 x property 50 %
## half-size) is approximated as a cone around the aim direction, with a
## 35 degree half field of view: tan(half) = tan(35) x (2/9) x property50/100.
const HALF_FOV_DEG:=35.0
const BOX_FRACTION:=2.0/9.0

static func plasma_type(cat: RefCounted,system_id: int) -> Dictionary:
	var systems: Array=cat.tables.systems
	if system_id<0 or system_id>=systems.size():return {}
	var here: Dictionary=systems[system_id]
	var rows:=[]
	for id in PLASMA_IDS:
		var origin: Dictionary=systems[int(cat.tables.items[id].properties[ORIGIN_PROPERTY])]
		var d:=Vector2(int(here.fields[MAP_X_FIELD])-int(origin.fields[MAP_X_FIELD]),int(here.fields[MAP_Y_FIELD])-int(origin.fields[MAP_Y_FIELD])).length()
		var value:=100-int(d)
		rows.append({"item_id":id,"percent":value if value>=MIN_PERCENT else 0})
	# Stable descending sort: ties keep item order.
	for i in range(1,rows.size()):
		var j:=i
		while j>0 and rows[j].percent>rows[j-1].percent:
			var swap: Dictionary=rows[j];rows[j]=rows[j-1];rows[j-1]=swap;j-=1
	for rank in rows.size():
		if rows[rank].percent>0:rows[rank].percent-=RANK_PENALTY*rank
	var top: Dictionary=rows[0]
	if top.percent<=0:return {}
	if top.item_id==RED and system_id!=YMIRR and here.linked_system_ids.is_empty():return {}
	return top

static func spawn(cat: RefCounted,system_id: int,seed_value: int,extra: int=0,first_position=null) -> Dictionary:
	var state:={"clouds":[],"sparks":[],"ionized":false,"elapsed_ms":0}
	var plasma:=plasma_type(cat,system_id)
	if plasma.is_empty():return state
	var random:=Random.new();random.seed_from(seed_value)
	@warning_ignore("integer_division")
	var count:=(BASE_COUNT+random.next_int(COUNT_SPREAD))*int(plasma.percent)/100+extra
	for index in count:
		var position:=Vector3.ZERO
		while position.length()<=MIN_ORIGIN_DISTANCE:
			position=Vector3(random.next_int(2*CUBE_HALF)-CUBE_HALF,random.next_int(2*CUBE_HALF)-CUBE_HALF,random.next_int(2*CUBE_HALF)-CUBE_HALF)
		if index==0 and first_position is Vector3:position=first_position
		state.clouds.append({"position":position,"item_id":int(plasma.item_id),"ionized":false})
	return state

## strength = the ion missile's property 56 (Ion Lambda Mk1: 50).
static func ionize(state: Dictionary,center: Vector3,radius: float,seed_value: int,strength: int=DEFAULT_STRENGTH) -> Dictionary:
	var next:=state.duplicate(true)
	if radius<=0.0:return next
	var random:=Random.new();random.seed_from(seed_value)
	for cloud in next.clouds:
		var distance: float=center.distance_to(cloud.position)
		if cloud.ionized or distance>radius:continue
		cloud.ionized=true;next.ionized=true
		var f:=1.5-distance/radius
		var count:=int(floor((f*SPARK_SCALE/1.5+SPARK_BASE)*strength/100.0))
		var half:=int(SPARK_CUBE*f)
		for unused in count:
			var offset:=Vector3(random.next_int(2*half+1)-half,random.next_int(2*half+1)-half,random.next_int(2*half+1)-half) if half>0 else Vector3.ZERO
			var position:=center+offset
			var direction: Vector3=(cloud.position-position).normalized()
			if direction==Vector3.ZERO:direction=Vector3.FORWARD
			var base:=float(SPEED_MIN+random.next_int(SPEED_SPREAD))
			next.sparks.append({"position":position,"velocity":direction*base*SPEED_BOOST,"base_speed":base,"age_ms":0,
				"life_ms":LIFE_MIN+random.next_int(LIFE_SPREAD),"item_id":int(cloud.item_id),"ready_ms":int(next.elapsed_ms)+READY_MS,"alpha":1.0})
	return next

## collector = {"speed": property 49, "box": property 50, "range": property 51}
## or {} when none is fitted. aim = the turret view direction.
static func step(state: Dictionary,delta_ms: int,player_position: Vector3,turret_view: bool,aim: Vector3,collector: Dictionary,free_capacity: int) -> Dictionary:
	var next:=state.duplicate(true)
	next.elapsed_ms=int(next.elapsed_ms)+delta_ms
	var picked:={};var lost:=0;var taken:=0
	var cone_tan:=tan(deg_to_rad(HALF_FOV_DEG))*BOX_FRACTION*float(collector.get("box",0))/100.0
	var forward:=aim.normalized()
	var kept:=[]
	for spark in next.sparks:
		spark.age_ms=int(spark.age_ms)+delta_ms
		if spark.age_ms>=int(spark.life_ms)+FADE_MS:continue
		var ready: bool=turret_view and int(next.elapsed_ms)>=int(spark.ready_ms)
		var to_player: Vector3=player_position-spark.position
		var distance:=to_player.length()
		var pulled:=false
		if ready and not collector.is_empty() and distance>0.0 and distance<=float(collector.range) and forward!=Vector3.ZERO:
			var along:=-to_player.dot(forward)
			var across:=(-to_player-forward*along).length()
			pulled=along>0.0 and across<=along*cone_tan
		if pulled:spark.velocity=to_player/distance*float(collector.speed)
		else:
			var speed: float=spark.velocity.length()
			if speed>0.0:spark.velocity*=maxf(float(spark.base_speed),speed-SPEED_DECAY*delta_ms)/speed
		spark.position+=spark.velocity*delta_ms
		distance=player_position.distance_to(spark.position)
		if ready and distance<=PICKUP_RANGE:
			if taken<free_capacity:taken+=1;picked[spark.item_id]=int(picked.get(spark.item_id,0))+1
			else:lost+=1
			continue
		var alpha:=1.0
		if spark.age_ms>int(spark.life_ms):alpha=1.0-float(spark.age_ms-int(spark.life_ms))/FADE_MS
		if distance<NEAR_FADE:alpha*=clampf((distance-PICKUP_RANGE)/NEAR_FADE_SPAN,0.0,1.0)
		spark.alpha=alpha
		kept.append(spark)
	next.sparks=kept
	return {"state":next,"picked":picked,"lost":lost}

static func snapshot_for_view(state: Dictionary) -> Dictionary:
	return {"clouds":state.clouds.map(func(cloud):return {"position":cloud.position,"item_id":int(cloud.item_id),"ionized":bool(cloud.ionized)}),
		"sparks":state.sparks.map(func(spark):return {"position":spark.position,"item_id":int(spark.item_id),"alpha":float(spark.get("alpha",1.0))})}
