extends RefCounted
## Destruction of a cast static object. The lethal update plays its death
## sound and replaces the body with the wreck animation; when the animation
## ends the wreck stays. No cargo, tumble, fragments or expiry.
const Statics=preload("res://src/content/static_object_definitions.gd")
const Construction=preload("res://src/simulation/opening_npc_construction.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _state:={}
var _max_ms:=0

func configure(bindings: RefCounted,resources: RefCounted,construction: RefCounted,actor_id: int) -> bool:
	error="";_state={}
	if not construction is Construction or not resources is Resources:return reject("Static destruction requires its staged resources and construction")
	var packet: Dictionary=construction.snapshot();var models: Dictionary=resources.snapshot()
	if models.get("contract_encounter")!=packet.get("contract_encounter") or actor_id<0 or actor_id>=packet.get("actors",[]).size():return reject("Static resources belong to another encounter")
	var row: Dictionary=packet.actors[actor_id]
	if row.get("population_group")!="static":return reject("Static destruction names another actor")
	var placed: Dictionary=models.get("static_objects",{}).get(int(row.static_model),{})
	if placed.is_empty():return reject("Static object resources were not staged")
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(packet.contract_encounter.context.campaign_cursor)}
	return setup(identity,actor_id,row.body_pose,placed,Frames.simulation_limit(bindings))

## Shared entry once resources are resolved (also used by the component test).
func setup(identity: Dictionary,actor_id: int,pose: Transform3D,placed: Dictionary,max_ms: int) -> bool:
	error=""
	if not pose.is_finite() or max_ms<=0 or not placed.get("wreck") is Dictionary:return reject("Invalid static destruction setup")
	_state=identity.duplicate()
	_state.merge({"actor_id":actor_id,"static_model":int(placed.model),"phase":"ready","mode":-1,"pose":pose,"elapsed_ms":0,
		"death_sound":int(placed.death_sound),"wreck":placed.wreck.duplicate(),"animation":{"start_ms":int(placed.wreck.start_ms),"end_ms":int(placed.wreck.end_ms),"time_ms":int(placed.wreck.start_ms)}})
	_max_ms=max_ms
	return true

func advance(delta_ms: Variant,actor: Dictionary) -> Dictionary:
	error=""
	if _state.is_empty() or not Numbers.integer(delta_ms,0,_max_ms):return fail("Static destruction needs a configured owner and bounded whole milliseconds")
	for key in ["base_content_id","binding_id","campaign_cursor","actor_id","static_model"]:
		if actor.get(key)!=_state[key]:return fail("Static destruction update belongs to another object")
	if actor.get("body_pose")!=_state.pose:return fail("A static object moved")
	var hull: Variant=actor.get("vitals",{}).get("hull")
	if not hull is int:return fail("Static object lost its hull")
	var next:=_state.duplicate(true);var started:=false;var sounds:=[]
	if _state.phase=="ready":
		if hull==0:
			started=true;sounds.append(int(_state.death_sound))
			next.phase="wrecking";next.mode=Statics.DEAD_MODE
	elif hull!=0:return fail("A destroyed static object cannot regain hull")
	else:
		next.elapsed_ms+=int(delta_ms)
		next.animation.time_ms=mini(int(next.animation.start_ms)+int(next.elapsed_ms),int(next.animation.end_ms))
		if next.phase=="wrecking" and next.animation.time_ms>=int(next.animation.end_ms):
			next.phase="wreck";next.mode=Statics.WRECK_MODE
	_state=next
	return {"state":snapshot(),"started":started,"breakup":false,"sound_events":sounds,
		"audio_events":sounds.map(func(id):return {"source_id":id,"position":_state.pose.origin}),"bursts":[]}

func snapshot() -> Dictionary:return _state.duplicate(true)

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true);copy._max_ms=_max_ms
	return copy

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
