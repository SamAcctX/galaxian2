extends RefCounted
const Frames=preload("res://src/simulation/frame_clock.gd")
const Readonly=preload("res://src/simulation/readonly_state.gd")
const FreeLife=preload("res://src/content/free_lifecycle_definitions.gd")
## A periodic source traffic check selects at most one inactive travel actor.
## The world supplies its retained clock and commits the returned request with
## actor reinitialization, cargo, route, motion and RNG in its logic phase.
const Definitions=preload("res://src/content/ambient_lifecycle_definitions.gd")
const Construction=preload("res://src/simulation/opening_npc_construction.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _identity:={}
var _rules:={}
var _actors:=[]
var _elapsed:=0
var _patrol_elapsed:=0
var _max_ms:=0
var _security:=-1
var _hostile_waves:=0
var _hostile_launches:=0
# Separate source budgets: two waves, and three replacements in security 1.
const HOSTILE_WAVES=2
const LIMITED_HOSTILE_LAUNCHES=3
const MINIMUM_RETIRED_HOSTILES=2
const HOSTILE_OFFSET_BOUNDS=[60000,5000,60000]

func configure(bindings: RefCounted,construction: RefCounted,elapsed_ms: Variant,patrol_elapsed_ms: Variant=0) -> bool:
	clear()
	if bindings==null or not construction is Construction or not Definitions.parameters(bindings.ambient_lifecycle):return reject("Station traffic launch is unavailable in this pack")
	if not Numbers.integer(elapsed_ms,0,2147483647):return reject("Supply the retained world traffic clock")
	if not Numbers.integer(patrol_elapsed_ms,0,2147483647):return reject("Supply the retained patrol clock")
	var packet: Dictionary=construction.snapshot()
	if packet.has("free_context"):
		if FreeLife.population(bindings,packet).is_empty():return reject("Unsupported ordinary traffic launch location")
		_security=int(packet.population.security)
	elif Definitions.Combat.for_context(bindings,packet.get("campaign_cursor"),packet.get("population",{}).get("station_id")).is_empty():return reject("Unsupported traffic launch location")
	for key in ["base_content_id","binding_id"]:
		if packet.get(key)!=bindings.get(key):return reject("Traffic launch belongs to another content identity")
	_actors=packet.actors.duplicate(true)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(packet.campaign_cursor)}
	_rules=bindings.ambient_lifecycle.duplicate(true);_elapsed=elapsed_ms
	_rules.campaign_cursor=int(packet.campaign_cursor);_rules.station_id=int(packet.population.station_id)
	_patrol_elapsed=patrol_elapsed_ms
	_max_ms=Frames.simulation_limit(bindings)
	return true

func advance(delta_ms: Variant,combat: Dictionary) -> Dictionary:
	error=""
	if _identity.is_empty() or not Numbers.integer(delta_ms,0,_max_ms) or _elapsed>2147483647-delta_ms:return fail("Invalid traffic clock duration")
	if _rules.has("recycling") and _patrol_elapsed>2147483647-delta_ms:return fail("Patrol clock overflow")
	for key in _identity:
		if combat.get(key)!=_identity[key]:return fail("Traffic clock belongs to another encounter")
	var actors: Variant=combat.get("actors")
	if not actors is Array or actors.size()!=_actors.size():return fail("Traffic launch requires the complete generated population")
	for id in actors.size():
		var actor: Variant=actors[id]
		if not actor is Dictionary:return fail("Invalid traffic actor")
		for key in ["actor_id","actor_kind","hull_catalogue_id","population_group","subtype"]:
			if actor.get(key)!=_actors[id].get(key):return fail("Traffic launch population changed")
		for key in _identity:
			if actor.get(key)!=_identity[key]:return fail("Traffic actor belongs to another encounter")
		if not actor.get("active") is bool or not Numbers.integer(actor.get("actor_mode"),0,9):return fail("Traffic launch requires current activity and mode")
	var next:=_elapsed+int(delta_ms)
	var checked: bool=next>int(_rules.launch_check_after_ms)
	var selected:=-1
	if checked:
		next=0
		for id in actors.size():
			if _actors[id].get("travel_flag",false) and not actors[id].active and actors[id].actor_mode==int(_rules.initial_mode):
				selected=id;break
	_elapsed=next
	var result:=snapshot();result.checked=checked;result.actor_id=selected
	if _rules.has("recycling"):
		_patrol_elapsed+=int(delta_ms)
		var patrol_checked: bool=_patrol_elapsed>int(_rules.recycling.patrol_check_after_ms)
		var patrol_ids:=[]
		if patrol_checked:
			_patrol_elapsed=0
			for id in actors.size():
				if _actors[id].population_group=="patrol" and not actors[id].active and actors[id].actor_mode==int(_rules.initial_mode):patrol_ids.append(id)
		var hostile_ids:=[]
		if patrol_checked and _security>=0 and _hostile_waves<HOSTILE_WAVES:
			var retired:=[]
			# Generated ordinary hostiles exclude authored/contract actors. Their
			# mission-script flag is clear; persistent hostility is not that flag.
			for id in actors.size():
				if _actors[id].population_group=="hostile" and not actors[id].active and actors[id].actor_mode==int(_rules.initial_mode):retired.append(id)
			if retired.size()>=MINIMUM_RETIRED_HOSTILES:
				for id in retired:
					if _security==0 or _actors[id].actor_kind==int(FreeLife.VALUES.unrestricted_relaunch_faction) or (_security==1 and _hostile_launches<LIMITED_HOSTILE_LAUNCHES):
						hostile_ids.append(id);_hostile_launches+=1
			if not hostile_ids.is_empty():_hostile_waves+=1
		result.patrol_elapsed_ms=_patrol_elapsed;result.patrol_checked=patrol_checked;result.patrol_actor_ids=patrol_ids
		result.hostile_actor_ids=hostile_ids
		if _security>=0:
			result.hostile_waves=_hostile_waves;result.hostile_launches=_hostile_launches
	return result

func snapshot() -> Dictionary:
	if _identity.is_empty():return {}
	var result:=_identity.duplicate();result.elapsed_ms=_elapsed
	if _rules.has("recycling"):result.patrol_elapsed_ms=_patrol_elapsed
	if _security>=0:
		result.hostile_waves=_hostile_waves;result.hostile_launches=_hostile_launches
	return result

static func hostile_origin(random: RefCounted,player_origin: Vector3) -> Vector3:
	# The caller has already redrawn this life's cargo on the same stream.
	var offset:=Vector3.ZERO
	for axis in 3:
		var bound: int=HOSTILE_OFFSET_BOUNDS[axis]
		var magnitude: int=bound+random.next_int(bound)
		offset[axis]=float(magnitude)*(1.0 if random.next_int(2)==0 else -1.0)
	return player_origin+offset

func fork_for_frame() -> RefCounted:
	# Configuration is fixed after preparation; detach live state only.
	var copy: RefCounted=get_script().new()
	copy._identity=_identity.duplicate();copy._rules=_rules;copy._actors=Readonly.freeze(_actors)
	copy._elapsed=_elapsed;copy._max_ms=_max_ms
	copy._patrol_elapsed=_patrol_elapsed
	copy._security=_security;copy._hostile_waves=_hostile_waves;copy._hostile_launches=_hostile_launches
	return copy

func clear() -> void:error="";_identity={};_rules={};_actors=[];_elapsed=0;_patrol_elapsed=0;_max_ms=0;_security=-1;_hostile_waves=0;_hostile_launches=0
func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
