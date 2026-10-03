extends RefCounted
## Second-trip particle ownership. The player tail precedes the early particle
## managers, the death poll follows them, and the NPC pass updates next-frame
## roots and flags. Each registered emitter has an independent random stream.
const FrameTransaction=preload("res://src/simulation/frame_transaction.gd")
const Definitions=preload("res://src/content/full_hold_particle_definitions.gd")
const Smoke=preload("res://src/simulation/opening_damage_particles.gd")
const Emitter=preload("res://src/simulation/damage_particle_emitter.gd")
const Death=preload("res://src/simulation/player_destruction.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const ConvoyEffects=preload("res://src/content/convoy_effect_definitions.gd")
const Capture=preload("res://src/simulation/convoy_capture.gd")
var error:=""
var _txn:=0
var _identity:={}
var _smoke: RefCounted
var _emitters:={}
var _manager_ms:=0
var _elapsed_ms:=0
var _burst_count:=0
var _births:={}
var _death_identity: RefCounted
var _presentation_identity: RefCounted
var _emp:={}
var _emp_bound:=false
var _emp_capture_ms:=-1
var _emp_phase:=0
var _attached:={}

func configure(bindings: RefCounted,combat: Dictionary,death: RefCounted,seed_seconds: Variant,mission_context: RefCounted=null) -> bool:
	error=""
	if bindings==null or not Definitions.parameters(bindings.full_hold_particles) or not death is Death or death.presentation_identity()==null or not seed_seconds is int:return reject("Second-flight particles require their declared population, player death owner and seed")
	var initial: Dictionary=death.snapshot()
	for key in ["base_content_id","binding_id"]:
		if initial.get(key)!=bindings.get(key) or combat.get(key)!=bindings.get(key):return reject("Second-flight particles belong to another departure")
	var training: bool=combat.get("campaign_cursor")==7
	var local_flight: bool=load("res://src/content/ordinary_flight_definitions.gd").combat_population(bindings,combat,mission_context)
	if initial.get("phase")!="ready" or (initial.get("departure_cursor")!=(int(combat.campaign_cursor) if local_flight else (7 if training else 4)) and not (local_flight and death.covers_cursor(int(combat.campaign_cursor)))):return reject("Register ordinary-flight particles before player death in the same encounter")
	var smoke:=Smoke.new()
	var ready:=smoke.configure_local_traffic(bindings,combat,seed_seconds,mission_context) if local_flight else (smoke.configure_combat_training(bindings,combat,seed_seconds) if training else smoke.configure_full_hold(bindings,combat,seed_seconds))
	if not ready:return reject(smoke.error)
	return _configure_registered(bindings,combat,death,int(seed_seconds),smoke)

func configure_first_mining(bindings: RefCounted,death: RefCounted,seed_seconds: Variant) -> bool:
	error=""
	if bindings==null or bindings.source_architecture!="x86_64" or not Definitions.parameters(bindings.full_hold_particles) or not death is Death or death.presentation_identity()==null or not seed_seconds is int:
		return reject("First mining particles require verified Mac sprite presets and player destruction")
	var state: Dictionary=death.snapshot()
	for key in ["base_content_id","binding_id"]:
		if state.get(key)!=bindings.get(key):return reject("First mining particles belong to another departure")
	if state.get("phase")!="ready" or state.get("departure_cursor")!=2 or state.get("campaign_cursor")!=2 or state.get("equipment_ids")!=[90,81]:
		return reject("First mining particles require the fresh Betty departure and its retained equipment")
	var smoke:=Smoke.new()
	if not smoke.configure_first_mining(bindings,seed_seconds):return reject(smoke.error)
	return _configure_registered(bindings,{"campaign_cursor":2,"actors":[]},death,int(seed_seconds),smoke)

func configure_selected40(bindings: RefCounted,combat: RefCounted,death: RefCounted,seed_seconds: Variant) -> bool:
	error=""
	if not _identity.is_empty() or bindings==null or not Definitions.parameters(bindings.full_hold_particles) or not death is Death or not seed_seconds is int or not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")):return reject("Selected40 particles require fresh native combat and player destruction")
	var world: RefCounted=combat.selected40_world_owner()
	if world==null or death.selected40_construction_owner()==null or death.selected40_construction_owner()!=world.npc_construction_owner():return reject("Selected40 particles cannot join unrelated constructor generations")
	var initial: Dictionary=death.snapshot()
	if initial.get("phase")!="ready" or initial.get("departure_cursor")!=40:return reject("Register selected40 particles before native player destruction")
	for key in ["base_content_id","binding_id"]:
		if initial.get(key)!=bindings.get(key):return reject("Selected40 particle resources belong to another source")
	var smoke:=Smoke.new()
	if not smoke.configure_selected40(bindings,combat,seed_seconds):return reject(smoke.error)
	return _configure_registered(bindings,combat.snapshot(),death,seed_seconds,smoke)

func configure_mission(bindings: RefCounted,context: RefCounted,combat: RefCounted,death: RefCounted,seed_seconds: Variant) -> bool:
	error=""
	if not _identity.is_empty() or bindings==null or not Definitions.parameters(bindings.full_hold_particles) or not death is Death or not seed_seconds is int or not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")):return reject("Mission particles require fresh admitted combat, player death owner and seed")
	var initial: Dictionary=death.snapshot()
	if initial.get("phase")!="ready" or initial.get("departure_cursor")!=int(context.recipe().cursor):return reject("Register mission particles before native player destruction")
	for key in ["base_content_id","binding_id"]:
		if initial.get(key)!=bindings.get(key):return reject("Mission particle resources belong to another source")
	var smoke:=Smoke.new()
	if not smoke.configure_mission(bindings,context,combat,seed_seconds):return reject(smoke.error)
	return _configure_registered(bindings,combat.snapshot(),death,seed_seconds,smoke,context.recipe().get("sequence_particles",[]))

func _configure_registered(bindings: RefCounted,combat: Dictionary,death: RefCounted,seed_seconds: int,smoke: RefCounted,attachments: Array=[]) -> bool:
	var emitters:={}
	var keys:=["player"]
	for id in combat.actors.size():
		if combat.actors[id].get("population_group") not in ["freighter","capital","debris","static"]:keys.append("npc%d"%id)
	keys.append("world")
	for key in keys:
		var emitter:=Emitter.new()
		if not emitter.configure_full_hold(bindings,bindings.base_content_id,11 if key=="world" else 9,seed_seconds):return reject(emitter.error)
		emitters[key]=emitter
	if combat.actors.any(func(actor):return actor.get("population_group")=="debris"):
		var emitter:=Emitter.new()
		if not emitter.configure_junk(bindings,seed_seconds):return reject(emitter.error)
		emitters.junk=emitter
	var emp:={}
	if combat.get("campaign_cursor")==14 and combat.actors.any(func(actor):return actor.get("convoy",false)) and ConvoyEffects.available(bindings):
		for id in bindings.mido_travel.convoy_effects.actor_ids:
			var key:="npc%d"%int(id)
			if not emitters.has(key):return reject("Convoy EMP registration lost its fighter")
			emp[key]={}
			for preset in bindings.mido_travel.convoy_effects.preset_ids:
				var emitter:=Emitter.new()
				if not emitter.configure_convoy_emp(bindings,int(preset),seed_seconds):return reject(emitter.error)
				emp[key]["emp%d"%int(preset)]=emitter
	var attached:={}
	if attachments.size()>32:return reject("Too many attached sprite declarations")
	for declaration in attachments:
		if not declaration is Dictionary or declaration.size()!=5 or declaration.get("kind") not in ["smoke","fire"] or not Numbers.integer(declaration.get("actor_id"),0,combat.actors.size()-1) or not declaration.get("preset") is Dictionary or not declaration.get("fade_in_rgb") is bool:return reject("Invalid attached sprite declaration")
		var id:=int(declaration.actor_id);var actor: Dictionary=combat.actors[id]
		if actor.get("actor_id")!=id or not Flight.rigid_pose(actor.get("body_pose")):return reject("Attached sprite lost its physical actor root")
		var emitter:=Emitter.new()
		if not emitter.configure_declared(bindings,declaration.preset,seed_seconds,declaration.fade_in_rgb) or not emitter.set_emitting(declaration.get("initial_emitting")):return reject(emitter.error)
		var effect:=int(declaration.preset.preset_id);var key:="attached%d_%d"%[id,effect]
		if attached.has(key):return reject("Duplicate attached sprite registration")
		attached[key]={"actor_id":id,"effect_type":effect,"kind":declaration.kind,"pose":actor.body_pose,"emitter":emitter}
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_smoke=smoke;_emitters=emitters;_manager_ms=0;_elapsed_ms=0;_burst_count=0;_births={}
	_death_identity=death.presentation_identity();_presentation_identity=RefCounted.new()
	_emp=emp;_emp_bound=false;_emp_capture_ms=-1;_emp_phase=0
	_attached=attached
	return true

## Consume native directives and current physical roots transactionally. Merely
## displaying a frame never advances, re-enables or resets these emitters.
func apply_sequence(effects: Array,actors: Array) -> bool:
	error=""
	if _identity.is_empty():return reject("Configure attached sprites before their native frame")
	if _attached.is_empty():return true if effects.is_empty() else reject("Sequence requested an unregistered sprite")
	var next: RefCounted=self if FrameTransaction.owns(_txn) else fork_for_frame()
	for record in next._attached.values():
		var id:=int(record.actor_id)
		if id>=actors.size() or not actors[id] is Dictionary or actors[id].get("actor_id")!=id or not Flight.rigid_pose(actors[id].get("body_pose")):return reject("Attached sprite frame lost its registered physical root")
		record.pose=actors[id].body_pose
	for cue in effects:
		if not cue is Dictionary or cue.size()!=4 or cue.get("action")!="set_enabled" or not Numbers.integer(cue.get("actor_id"),0,65535) or not Numbers.integer(cue.get("effect_type"),0,47) or not cue.get("enabled") is bool:return reject("Invalid attached sprite directive")
		var key:="attached%d_%d"%[int(cue.actor_id),int(cue.effect_type)]
		if not next._attached.has(key):return reject("Sequence requested an unregistered sprite")
		if not next._attached[key].emitter.set_emitting(cue.enabled):return reject(next._attached[key].emitter.error)
	adopt(next);return true

func has_convoy_emp() -> bool:return not _emp.is_empty()

func apply_convoy_capture(capture: RefCounted) -> bool:
	error=""
	if not has_convoy_emp() or not capture is Capture:return reject("Convoy sprites require their native capture owner")
	var state: Dictionary=capture.snapshot()
	for key in ["base_content_id","binding_id"]:
		if state.get(key)!=_identity.get(key):return reject("EMP capture belongs to another departure")
	if state.get("campaign_cursor")!=14 or int(state.phase)<_emp_phase or int(state.elapsed_ms)<=_emp_capture_ms:return reject("EMP capture is stale or regressed")
	var target: Dictionary=state.frame.get("emp_target",{})
	if not target.is_empty():
		if _emp_bound or target.get("actor_id")!=0 or state.phase!=Capture.Stage.PULSE:return reject("EMP target does not match its single source activation")
		var next: RefCounted=self if FrameTransaction.owns(_txn) else fork_for_frame()
		for emitter in next._emp.npc0.values():
			if not emitter.rebind_transform() or not emitter.set_emitting(true) or not emitter.set_visible(true):return reject(emitter.error)
		next._emp_bound=true
		adopt(next)
	# The Mac capture-view stop addresses the nozzle manager, not this effects
	# manager. Do not redirect it here or clear the attached EMP sprites.
	_emp_capture_ms=int(state.elapsed_ms);_emp_phase=int(state.phase)
	return true

func apply_player_tail(death: RefCounted) -> bool:
	error=""
	if not matches_death(death):return reject("Particle tail lost its configured player destruction")
	var state: Dictionary=death.snapshot()
	if not state.events.get("breakup",false) or _burst_count>0:return true
	if not Flight.rigid_pose(state.statistics_pose):return reject("Player burst requires the retained statistics position")
	var next: RefCounted=self if FrameTransaction.owns(_txn) else fork_for_frame()
	next._emitters.player.set_emitting(false);next._emitters.player.set_visible(false)
	var result: Dictionary=next._emitters.world.emit_once(state.statistics_pose.origin)
	if result.has("error"):return reject(next._emitters.world.error)
	next._burst_count=1
	adopt(next);return true

func apply_player_poll(death: RefCounted) -> bool:
	error=""
	if not matches_death(death):return reject("Particle poll lost its configured player destruction")
	var state: Dictionary=death.snapshot()
	# Only the emitted poll cue can re-enable the trail. Reading a retained flag
	# on an action-only frame must not become an extra source operation.
	var cues: Array=state.events.get("particle_events",[])
	if not cues.is_empty() and cues.back()=={"emitting":true}:
		if not _emitters.player.set_emitting(true):return reject(_emitters.player.error)
	return true

## Rockets and missiles emit the same original world burst as other manual
## explosion sources. Their contact pass, not presentation, decides births.
func apply_weapon_impacts(contacts: Array) -> bool:
	error=""
	if contacts.is_empty():return true
	if _identity.is_empty() or not _emitters.has("world"):return reject("Weapon impacts require the registered world sprite pool")
	var next: RefCounted=self if FrameTransaction.owns(_txn) else fork_for_frame()
	for contact in contacts:
		if not contact is Dictionary or contact.get("action")!="impact" or not contact.get("position") is Vector3 or not contact.position.is_finite():return reject("Invalid weapon impact position")
		var result: Dictionary=next._emitters.world.emit_once(contact.position)
		if result.has("error"):return reject(next._emitters.world.error)
	adopt(next);return true

## The world can finish before its late particle pass. Publish the retained
## population at that frame without ageing slots, moving roots or consuming RNG.
func retain_frame(delta_ms: Variant) -> bool:
	error=""
	if _identity.is_empty() or not Numbers.integer(delta_ms,0,1000) or _elapsed_ms>2147483647-int(delta_ms):return reject("Invalid retained particle frame clock")
	_elapsed_ms+=int(delta_ms)
	return true

func advance(player_root: Variant,delta_ms: Variant) -> bool:
	error=""
	if _identity.is_empty() or not Flight.rigid_pose(player_root) or not Numbers.integer(delta_ms,0,1000):return reject("Second-flight particles require a rigid player root and bounded milliseconds")
	if delta_ms==0:return true
	var next: RefCounted=self if FrameTransaction.owns(_txn) else fork_for_frame();var interval:=_manager_ms+int(delta_ms)
	next._births={}
	# General sprites precede smoke and fire. The root already retained by the
	# shared NPC smoke/fire owner is also the preset-9 emitter's logical root.
	for key in _emitters:
		var pose: Transform3D=player_root if key=="player" else _smoke.npc_root(int(key.trim_prefix("npc"))) if key.begins_with("npc") else Transform3D.IDENTITY
		var result: Dictionary=next._emitters[key].advance_in_frame(pose,delta_ms,interval)
		if result.has("error"):return reject(next._emitters[key].error)
		next._births[key]=int(result.births)
	for key in next._attached:
		var record: Dictionary=next._attached[key]
		var result: Dictionary=record.emitter.advance_in_frame(record.pose,delta_ms,interval)
		if result.has("error"):return reject(record.emitter.error)
		next._births[key]=int(result.births)
	if not next._smoke.advance(player_root,delta_ms):return reject(next._smoke.error)
	for key in _emp:
		var pose: Transform3D=player_root if _emp_bound and key=="npc0" else _smoke.npc_root(int(key.trim_prefix("npc")))
		for kind in _emp[key]:
			var result: Dictionary=next._emp[key][kind].advance_in_frame(pose,delta_ms,interval)
			if result.has("error"):return reject(next._emp[key][kind].error)
			next._births[key+"_"+kind]=int(result.births)
	next._manager_ms=0 if interval>=10 else interval
	next._elapsed_ms+=int(delta_ms)
	adopt(next);return true

func finish_npc_pass(before: Dictionary,after: Dictionary,events: Array,delta_ms: Variant,detail: Variant) -> bool:
	error=""
	if _smoke==null:return reject("Configure second-flight particles before the NPC pass")
	var next: RefCounted=self if FrameTransaction.owns(_txn) else fork_for_frame()
	if not next._smoke.finish_npc_pass(before,after,events,delta_ms,detail):return reject(next._smoke.error)
	for event in events:
		var death: Dictionary=event.get("destruction",{})
		if not death.is_empty():
			for burst in death.get("bursts",[]):
				if not next._emitters.has("junk") or burst.get("preset_id")!=21 or burst.get("member_index")!=0 or burst.get("count")!=1 or burst.get("size_override")!=-1:return reject("The debris burst changed its verified sprite operation")
				var emitted: Dictionary=next._emitters.junk.emit_once(burst.position)
				if emitted.has("error"):return reject(next._emitters.junk.error)
			var key:="npc%d"%int(event.actor_id)
			if not next._emitters.has(key):continue
			if death.started:next._emitters[key].set_emitting(true)
			if death.breakup:next._emitters[key].set_emitting(false)
	adopt(next);return true

func matches_death(death: RefCounted) -> bool:
	return not _identity.is_empty() and death is Death and death.presentation_identity()==_death_identity

func presentation_identity() -> RefCounted:return _presentation_identity

func snapshot(shared:=false) -> Dictionary:
	if _identity.is_empty():return {}
	var result:=_identity.duplicate()
	var smoke: Dictionary=_smoke.snapshot(shared)
	result.manager_ms=_manager_ms;result.elapsed_ms=_elapsed_ms;result.burst_count=_burst_count
	result.births=_births.duplicate(true);result.smoke_fire_births=smoke.births
	result.owners={}
	for key in _emitters:
		result.owners[key]=smoke.owners.get(key,{})
		result.owners[key]["junk_burst" if key=="junk" else "burst" if key=="world" else "trail"]=_emitters[key].snapshot(shared)
	for key in _attached:
		var record: Dictionary=_attached[key]
		result.owners[key]={"actor_id":record.actor_id,"root":record.pose}
		result.owners[key][record.kind]=record.emitter.snapshot(shared)
	if has_convoy_emp():
		result.emp={"bound_to_player":_emp_bound,"capture_elapsed_ms":_emp_capture_ms,"phase":_emp_phase}
		for key in _emp:
			for kind in _emp[key]:result.owners[key][kind]=_emp[key][kind].snapshot(shared)
	return result

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._txn=FrameTransaction.current
	copy._identity=_identity.duplicate();copy._manager_ms=_manager_ms;copy._elapsed_ms=_elapsed_ms;copy._burst_count=_burst_count;copy._births=_births.duplicate(true)
	if _smoke!=null:copy._smoke=_smoke.fork_for_frame()
	for key in _emitters:copy._emitters[key]=_emitters[key].fork_for_frame()
	for key in _attached:
		copy._attached[key]=_attached[key].duplicate()
		copy._attached[key].emitter=_attached[key].emitter.fork_for_frame()
	for key in _emp:
		copy._emp[key]={}
		for kind in _emp[key]:copy._emp[key][kind]=_emp[key][kind].fork_for_frame()
	copy._emp_bound=_emp_bound;copy._emp_capture_ms=_emp_capture_ms;copy._emp_phase=_emp_phase
	copy._death_identity=_death_identity;copy._presentation_identity=_presentation_identity
	return copy

func adopt(next: RefCounted) -> void:
	_smoke=next._smoke;_emitters=next._emitters;_manager_ms=next._manager_ms;_elapsed_ms=next._elapsed_ms;_burst_count=next._burst_count;_births=next._births
	_emp=next._emp;_emp_bound=next._emp_bound;_emp_capture_ms=next._emp_capture_ms;_emp_phase=next._emp_phase
	_attached=next._attached

func clear() -> void:
	error="";_identity={};_smoke=null;_emitters={};_manager_ms=0;_elapsed_ms=0;_burst_count=0;_births={};_death_identity=null;_presentation_identity=null
	_emp={};_emp_bound=false;_emp_capture_ms=-1;_emp_phase=0
	_attached={}

func reject(message: String) -> bool:error=message;return false
