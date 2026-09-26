extends Node3D
## Shared sequence effects and independently actor-owned spatial loops.
const Context=preload("res://src/simulation/mission_context.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const Resources=preload("res://src/content/sequence_audio_resources.gd")
const Layered=preload("res://src/presentation/layered_audio.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const Envelope=preload("res://src/content/audio_envelope.gd")
const Numbers=preload("res://src/content/audio_definitions.gd")
const Sequence=preload("res://src/simulation/audio_sequence.gd")
var error:=""
var _context: Context
var _identity: RefCounted
var _clips:={}
var _players:={}
var _sample:={}
var _seed:=0
var _serial:=0
var _paused:=false
var _listener:=Transform3D.IDENTITY
var _history: Array=[]
var _directives: Array=[]
var _epoch:=0
var _actor_engines:={}
var _pitch_random:=RandomNumberGenerator.new()
var _last_samples:={}

func configure(context: Context,resources: Audio,bindings: RefCounted,event_ids: Array,seed_value:=0) -> bool:
	error=""
	if _context!=null or context==null or context.recipe().is_empty() or resources==null or resources._library==null:return reject("Sequence audio requires a fresh admitted mission and prepared audio resources")
	for key in ["base_content_id","binding_id"]:
		if context.identity().get(key)!=bindings.get(key):return reject("Sequence audio belongs to another admitted source")
	if resources._library.manifest.get("content_id")!=bindings.base_content_id or resources._definitions.get("source_sha256")!=bindings.audio.get("source_sha256"):return reject("Sequence audio cache belongs to another source")
	if event_ids.is_empty() or event_ids.size()>32:return reject("Invalid sequence audio population")
	var adapter:=Resources.new();var clips:={}
	for id in event_ids:
		if not id is int or clips.has(id):return reject("Duplicate or invalid sequence sound identifier")
		var clip:=adapter.prepare(resources,id)
		if clip.is_empty():return reject(adapter.error)
		if clip.get("voice",false) or clip.get("kind","") not in ["","layered","sequence_layers"]:return reject("Sequence SFX require a static clip or supported layers")
		clips[id]=clip
	var actors:={};var counts:={}
	for declaration in context.recipe().get("actor_engines",[]):
		if not declaration is Dictionary or declaration.size()!=2 or not Numbers.integer(declaration.get("actor_id"),0,65535) or not Numbers.integer(declaration.get("sound_id"),0,19999):return reject("Invalid actor engine declaration")
		var actor_id: int=int(declaration.actor_id);var sound_id: int=int(declaration.sound_id)
		if actors.has(actor_id) or clips.has(sound_id):return reject("Actor engine requires an independent declared handle")
		actors[actor_id]=sound_id;counts[sound_id]=int(counts.get(sound_id,0))+1
	for actor_id in actors:
		var clip:=adapter.prepare_actor_loop(resources,actors[actor_id],counts[actors[actor_id]])
		if clip.is_empty():return reject(adapter.error)
		clips[actor_key(actor_id)]=clip
	_clips=clips;_actor_engines=actors;_seed=seed_value;_pitch_random.seed=seed_value;_context=context;_identity=RefCounted.new()
	return true

## Frame: revision, delta_ms, cues. Optional stopped ends the world/death audio.
## Cues: play/stop(sound_id), position(sound_id,position,velocity=ZERO),
## parameter(sound_id,index,value), stop_actor_engine(actor_id).
func prepare_frame(context: Context,state: Dictionary,listener: Transform3D) -> Dictionary:
	error=""
	if context!=_context or _identity==null:return failed("Sequence audio requires its retained admitted context")
	if not state.get("revision") is int or state.revision<0 or not Numbers.integer(state.get("delta_ms"),0,1000) or not state.get("cues") is Array or state.cues.size()>64 or not listener.is_finite():return failed("Invalid sequence audio frame")
	if state.has("stopped") and not state.stopped is bool:return failed("Invalid sequence audio teardown flag")
	var sample:=state.duplicate(true);sample.listener=listener
	if not _sample.is_empty():
		if sample.revision<_sample.revision or (sample.revision==_sample.revision and sample!=_sample):return failed("Sequence audio revision regressed or changed")
		if sample==_sample:return {"identity":_identity,"repeat":true}
	if _paused and (state.delta_ms!=0 or not state.cues.is_empty()) and not state.get("stopped",false):return failed("Paused sequence audio cannot advance or consume cues")
	var cues: Array=state.cues.duplicate(true);var directives:=[]
	var engines: Variant=state.get("actor_engines",{})
	if not engines is Dictionary or engines.size()!=_actor_engines.size():return failed("Sequence frame lost its declared actor engine population")
	for actor_id in _actor_engines:
		var actor: Variant=engines.get(actor_id)
		if not actor is Dictionary or actor.size()!=2 or not actor.get("enabled") is bool or not actor.get("position") is Vector3 or not actor.position.is_finite():return failed("Actor engine requires its native physical position and motion permission")
	engines=engines.duplicate(true)
	for cue in cues:
		if not cue is Dictionary:return failed("Invalid sequence audio cue")
		if cue.get("action")=="stop_actor_engine":
			if cue.size()!=2 or not cue.get("actor_id") is int or not _actor_engines.has(cue.actor_id):return failed("Actor-engine stop names an unprepared actor")
			engines[cue.actor_id].enabled=false
			directives.append(cue.duplicate(true));continue
		if not cue.get("sound_id") is int:return failed("Sequence cue has no sound identifier")
		var id: int=cue.sound_id
		if cue.get("action")=="stop":
			if id<0:return failed("Invalid sequence stop identifier")
			continue
		if not _clips.has(id):return failed("Sequence sound was not prepared at entry")
		match cue.get("action"):
			"play":
				if cue.has("position") and (not cue.position is Vector3 or not cue.position.is_finite()):return failed("Invalid sequence sound position")
			"position":
				if not cue.get("position") is Vector3 or not cue.position.is_finite() or cue.get("velocity",Vector3.ZERO)!=Vector3.ZERO:return failed("Sequence sound requires finite position and zero velocity")
			"parameter":
				if _clips[id].get("kind")!="sequence_layers" or cue.get("index")!=1 or not Numbers.number(cue.get("value"),0,1):return failed("Unsupported external sequence parameter")
			_:return failed("Unknown sequence audio action")
	var layers:=[]
	if not state.get("stopped",false):
		for record in _players.values():
			for node in record.nodes:
				if node is Layered:
					var frame: Dictionary=node.prepare_step(int(state.delta_ms))
					if frame.is_empty():return failed(node.error)
					layers.append({"node":node,"frame":frame})
	return {"identity":_identity,"epoch":_epoch,"previous_revision":_sample.get("revision",-1),"sample":sample,"cues":cues,"directives":directives,"layers":layers,"actor_engines":engines}

func commit_frame(frame: Dictionary) -> bool:
	if frame.get("identity")!=_identity or frame.get("epoch")!=_epoch or frame.get("repeat",false) or frame.get("previous_revision")!=_sample.get("revision",-1):return false
	_sample=frame.sample.duplicate(true);_listener=_sample.listener;_directives=frame.directives.duplicate(true)
	if _sample.get("stopped",false):stop_all();return true
	for id in _players.keys():
		var record: Dictionary=_players[id]
		record.age_ms+=int(_sample.delta_ms)
		if record.stopping:
			record.remaining_ms=maxi(0,record.remaining_ms-int(_sample.delta_ms))
			if record.remaining_ms==0:_remove(id)
	for layer in frame.layers:
		if is_instance_valid(layer.node) and not layer.node.is_queued_for_deletion():layer.node.commit_step(layer.frame)
	for cue in frame.cues:
		var id: int=int(cue.get("sound_id",-1))
		match cue.action:
			"play":_play(id,cue.get("position"))
			"stop":_stop(id)
			"position":
				if _players.has(id):_players[id].position=cue.position
			"parameter":
				if _players.has(id):_players[id].parameter=float(cue.value)
		var entry: Dictionary=cue.duplicate(true);entry.revision=_sample.revision;_history.append(entry)
		if _history.size()>64:_history.pop_front()
	for actor_id in frame.actor_engines:
		var key:=actor_key(actor_id);var actor: Dictionary=frame.actor_engines[actor_id]
		if actor.enabled:_play(key,actor.position)
		else:_stop(key)
		if _players.has(key):_players[key].position=actor.position
	_refresh_levels()
	return true

func _play(id: Variant,position_value: Variant) -> void:
	if _players.has(id):
		var old: Dictionary=_players[id]
		if not old.stopping and old.nodes.any(func(node):return node.playing or _paused):
			if position_value!=null:old.position=position_value
			return
		_remove(id)
	var clip: Dictionary=_clips[id];var nodes: Array=[]
	if clip.get("kind")=="playlist":
		var definition: Dictionary=clip.definition
		var last: int=_last_samples.get(id,-1) if definition.playlist_flags!=8 else -1
		var choice:=Sequence.sample(definition,_pitch_random,last)
		_last_samples[id]=choice.playlist_index
		clip=clip.duplicate();clip.merge(choice.sample);clip.gain*=choice.gain
		clip.pitch=choice.pitch;clip.playlist_index=choice.playlist_index
	if clip.get("kind") in ["layered","sequence_layers"]:
		var groups: Array=clip.groups if clip.get("kind")=="sequence_layers" else [{"definition":clip}]
		for group in groups:
			var node:=Layered.new();node.configure(group.definition,_seed+_serial);_serial+=1
			nodes.append(node)
	else:nodes.append(Streams.player(clip.stream,clip.spatial))
	var record:={"clip":clip,"nodes":nodes,"position":Vector3.ZERO if position_value==null else position_value,"parameter":0.0,"age_ms":0,"remaining_ms":0,"stopping":false,"stop_gain":1.0,"pause_records":[]}
	_players[id]=record
	for node in nodes:
		add_child(node)
		if id is String:node.pitch_scale=float(clip.get("pitch",1.0))
		if id is String and float(clip.get("event_pitch_random",0.0))>0:
			node.pitch_scale*=Sequence.event_pitch(0.0,float(clip.event_pitch_random),_pitch_random.randi()&0x7fffffff)
		var pause:={"node":node,"pending_resume":false,"resume_position":0.0}
		record.pause_records.append(pause)
		if _paused:pause.pending_resume=true
		else:node.play()

func _stop(id: Variant) -> void:
	if not _players.has(id) or _players[id].stopping:return
	var record: Dictionary=_players[id]
	if record.clip.fade_out_ms==0:_remove(id);return
	record.stopping=true;record.remaining_ms=int(record.clip.fade_out_ms)
	record.stop_gain=1.0 if record.clip.fade_in_ms==0 else minf(1.0,float(record.age_ms)/record.clip.fade_in_ms)

func _refresh_levels() -> void:
	for record in _players.values():
		var clip: Dictionary=record.clip
		var fade: float=record.stop_gain*float(record.remaining_ms)/clip.fade_out_ms if record.stopping else 1.0 if clip.fade_in_ms==0 else minf(1.0,float(record.age_ms)/clip.fade_in_ms)
		var gain: float=clip.gain*fade
		if clip.spatial:gain*=clampf((clip.max_distance-_listener.origin.distance_to(record.position))/(clip.max_distance-clip.min_distance),0.0,1.0)
		for i in record.nodes.size():
			var node: Node=record.nodes[i];var level:=gain
			if clip.spatial:node.position=record.position
			if clip.get("kind")=="sequence_layers":
				for envelope in clip.groups[i].envelopes:level*=Envelope.evaluate(envelope,record.parameter)
			node.volume_db=linear_to_db(level) if level>0 else -80.0

func set_paused(value: bool) -> void:
	if _paused==value:return
	_paused=value;_epoch+=1
	for record in _players.values():
		for pause in record.pause_records:Streams.pause(pause,value)

func directives() -> Array:return _directives.duplicate(true)
static func actor_key(actor_id: int) -> String:return "actor:"+str(actor_id)
func snapshot() -> Dictionary:
	var active:={};var actors:={}
	for id in _players:
		var record: Dictionary=_players[id];var layers:=[]
		for node in record.nodes:
			if node is Layered:layers.append(node.snapshot())
		var entry:={"position":record.position,"parameter":record.parameter,"age_ms":record.age_ms,"stopping":record.stopping,"remaining_ms":record.remaining_ms,"layers":layers,"gains_db":record.nodes.map(func(node):return node.volume_db)}
		if id is String:
			entry.sound_id=int(record.clip.id);entry.playing=record.nodes.any(func(node):return node.playing or _paused)
			actors[int(id.trim_prefix("actor:"))]=entry
		else:active[id]=entry
	return {"state":_sample.duplicate(true),"active":active,"actor_engines":actors,"paused":_paused,"history":_history.duplicate(true),"directives":directives()}

func _remove(id: Variant) -> void:
	for node in _players[id].nodes:node.stop();node.queue_free()
	_players.erase(id)
func stop_all() -> void:
	for id in _players.keys():_remove(id)
	_directives=[];_epoch+=1
func _exit_tree() -> void:stop_all()
func failed(message: String) -> Dictionary:error=message;return {}
func reject(message: String) -> bool:error=message;return false
