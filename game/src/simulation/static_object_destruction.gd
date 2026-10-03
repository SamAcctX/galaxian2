extends RefCounted
## Destruction of a cast static object. The lethal update plays its death
## sound and replaces the body with the wreck animation; when the animation
## ends the wreck stays. A fixed cargo list (pirate bases) appears as one
## container at the object's position on death; the wreck itself never moves
## or retires. No tumble, fragments or expiry.
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
	if not setup(identity,actor_id,row.body_pose,placed,Frames.simulation_limit(bindings)):return false
	var entries: Variant=row.get("cargo",[])
	if not entries is Array or entries.is_empty():return true
	var model: Variant=models.get("cargo_models",[])[actor_id] if models.get("cargo_models",[]).size()>actor_id else null
	if not model is Dictionary or not model.get("resource") is String:return reject("Static cargo lacks its container model")
	for entry in entries:
		if not entry is Dictionary or not Numbers.integer(entry.get("item_id"),0,232) or not Numbers.integer(entry.get("quantity"),1,2147483647):return reject("Invalid static cargo entry")
	_state.cargo={"entries":entries.duplicate(true),"eligible":false,"model_exists":false,"model_id":int(model.model_id),"resource":String(model.resource),"pose":_state.pose}
	return true

## Shared entry once resources are resolved (also used by the component test).
func setup(identity: Dictionary,actor_id: int,pose: Transform3D,placed: Dictionary,max_ms: int) -> bool:
	error=""
	if not pose.is_finite() or max_ms<=0 or not placed.get("wreck") is Dictionary:return reject("Invalid static destruction setup")
	_state=identity.duplicate()
	_state.merge({"actor_id":actor_id,"static_model":int(placed.model),"phase":"ready","mode":-1,"pose":pose,"statistics_pose":pose,"active":true,"retire_on_transfer":false,"elapsed_ms":0,
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
			started=true
			if int(_state.death_sound)>=0:sounds.append(int(_state.death_sound))
			next.phase="wrecking";next.mode=Statics.DEAD_MODE
			if next.has("cargo"):next.cargo.eligible=true;next.cargo.model_exists=true
	elif hull!=0:return fail("A destroyed static object cannot regain hull")
	else:
		next.elapsed_ms+=int(delta_ms)
		next.animation.time_ms=mini(int(next.animation.start_ms)+int(next.elapsed_ms),int(next.animation.end_ms))
		if next.phase=="wrecking" and next.animation.time_ms>=int(next.animation.end_ms):
			next.phase="wreck";next.mode=Statics.WRECK_MODE
	_state=next
	return {"state":snapshot(),"started":started,"breakup":false,"sound_events":sounds,
		"audio_events":sounds.map(func(id):return {"source_id":id,"position":_state.pose.origin}),"bursts":[]}

## Tractor recovery changes only the container; the wreck stays in place.
func _retain_recovery_frame(frame: Dictionary) -> void:
	var changes: Dictionary=frame.actor_changes
	if not _state.has("cargo"):return
	if changes.has("cargo_pose"):_state.cargo.pose=changes.cargo_pose
	if changes.has("cargo_model_exists"):_state.cargo.model_exists=changes.cargo_model_exists
	if changes.has("cargo_eligible"):_state.cargo.eligible=changes.cargo_eligible
	if changes.has("cargo_entries"):_state.cargo.entries=changes.cargo_entries.duplicate(true)

func snapshot() -> Dictionary:return _state.duplicate(true)

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true);copy._max_ms=_max_ms
	return copy

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
