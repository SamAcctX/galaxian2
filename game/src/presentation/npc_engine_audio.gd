extends Node3D
## Other ships' engine loops: fighters, freighters and wingmen each loop their
## original engine event at the ship's position. Each event plays on at most its
## authored number of ships, the nearest first; loops fade in on start and out
## when a ship leaves, is destroyed or drops out of the nearest set.
const Audio=preload("res://src/content/audio_resources.gd")
const Adapter=preload("res://src/content/sequence_audio_resources.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const Sequence=preload("res://src/simulation/audio_sequence.gd")
const FIGHTER:=46
const FREIGHTER:=47
const WINGMAN:=48
var error:=""
var _clips:={}
var _players:={}
var _paused:=false
var _random:=RandomNumberGenerator.new()

func configure(library: RefCounted,bindings: RefCounted,seed_value:=0) -> bool:
	error="";_random.seed=seed_value
	var resources:=Audio.new()
	if not resources.configure(library,bindings):error=resources.error;return false
	var adapter:=Adapter.new()
	for id in [FIGHTER,FREIGHTER,WINGMAN]:
		var events: Array=resources._definitions.get("events",[])
		if id>=events.size():continue
		var clip:=adapter.prepare_actor_loop(resources,id,int(events[id].properties.max_playbacks),true)
		if not clip.is_empty():
			clip.max_playbacks=int(events[id].properties.max_playbacks);_clips[id]=clip
	if _clips.is_empty():error=adapter.error;return false
	return true

## Reads visible ships from a flight observation: ordinary and encounter actors
## (freighters carry a multi-body assembly) and paid wingmen.
static func sources(state: Dictionary) -> Array:
	var rows:=[]
	for actor in state.get("actors",[]):
		if not actor is Dictionary or not actor.get("visible",false) or not actor.get("position") is Vector3 or int(actor.get("hull_catalogue_id",-1))<0:continue
		if actor.has("current_hull") and int(actor.current_hull)<=0:continue
		rows.append({"key":"actor:"+str(actor.actor_id),"event":FREIGHTER if actor.has("assembly") else FIGHTER,"position":actor.position})
	# Freelance encounters keep their ships in the combat frame; a ship's engine
	# sounds while its exhaust is drawn.
	for actor in state.get("encounter",{}).get("combat",{}).get("actors",[]):
		if actor is Dictionary and actor.get("active",false) and actor.get("engine_draw_enabled",false) and actor.get("pose") is Transform3D and int(actor.get("hull_catalogue_id",-1))>=0:
			rows.append({"key":"encounter:"+str(actor.actor_id),"event":FREIGHTER if actor.has("assembly") else FIGHTER,"position":actor.pose.origin})
	for actor in state.get("wingman_actors",{}).get("actors",[]):
		if actor is Dictionary and actor.get("active",false) and actor.get("pose") is Transform3D:
			rows.append({"key":"wingman:"+str(actor.get("actor_id",actor.get("wingman_index",0))),"event":WINGMAN,"position":actor.pose.origin})
	return rows

func update(rows: Array,listener: Vector3,delta_ms: int) -> void:
	var wanted:={}
	for id in _clips:
		var near: Array=rows.filter(func(row):return row.event==id)
		near.sort_custom(func(a,b):return a.position.distance_squared_to(listener)<b.position.distance_squared_to(listener))
		for row in near.slice(0,int(_clips[id].max_playbacks)):wanted[row.key]=row
	for key in wanted:
		if not _players.has(key):_start(key,wanted[key].event)
		var record: Dictionary=_players[key]
		record.stopping=false;record.node.position=wanted[key].position
	for key in _players.keys():
		var record: Dictionary=_players[key]
		if not wanted.has(key):record.stopping=true
		if _paused:continue
		var clip: Dictionary=record.clip
		if record.stopping:record.level-=float(delta_ms)/maxf(1.0,float(clip.fade_out_ms))
		else:record.level+=float(delta_ms)/maxf(1.0,float(clip.fade_in_ms))
		record.level=clampf(record.level,0.0,1.0)
		if record.stopping and record.level<=0.0:
			record.node.queue_free();_players.erase(key);continue
		var distance: float=record.node.position.distance_to(listener)
		var rolloff: float=clampf((float(clip.max_distance)-distance)/(float(clip.max_distance)-float(clip.min_distance)),0.0,1.0)
		var gain: float=float(clip.gain)*record.gain*record.level*rolloff
		record.node.volume_db=linear_to_db(gain) if gain>0 else -80.0

func _start(key: String,id: int) -> void:
	var clip: Dictionary=_clips[id]
	var choice: Dictionary=Sequence.sample(clip.definition,_random,-1)
	var node: Node=Streams.player(choice.sample.stream,true)
	node.pitch_scale=float(choice.pitch)
	if float(clip.get("event_pitch_random",0.0))>0:node.pitch_scale*=Sequence.event_pitch(0.0,float(clip.event_pitch_random),_random.randi()&0x7fffffff)
	node.volume_db=-80.0;add_child(node);node.play()
	if _paused:node.stream_paused=true
	_players[key]={"clip":clip,"node":node,"level":0.0,"gain":float(choice.gain),"stopping":false}

func set_paused(value: bool) -> void:
	_paused=value
	for record in _players.values():record.node.stream_paused=value

func snapshot() -> Dictionary:
	var playing:={}
	for key in _players:playing[key]={"level":_players[key].level,"stopping":_players[key].stopping}
	return {"prepared":_clips.keys(),"playing":playing,"paused":_paused}
