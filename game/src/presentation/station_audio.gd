extends Node
## Shared acknowledged speech for the station, mining briefing and return.
## Explicit navigation replaces the prior voice; duration never acknowledges it.
const Resources=preload("res://src/content/audio_resources.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const MiningStory=preload("res://src/content/ordinary_flight_definitions.gd")
const StationReturn=preload("res://src/content/ordinary_flight_definitions.gd")
const StationEntry=preload("res://src/content/station_entry_definitions.gd")
const MissionContext=preload("res://src/simulation/mission_context.gd")
var error:=""
var diagnostics:={}
var _resources: RefCounted
var _clips: Array=[]
var _player: Node
var _paused:=false
var _line:=-1
var _history: Array=[]
var _effect_clips:={}
var _effects:={}
var _effect_history:=[]
var _mission_voice_lines:={}

func configure_mission(library: RefCounted,bindings: RefCounted,context: RefCounted) -> bool:
	if not context is MissionContext:return reject("Mission speech requires its admitted context")
	var recipe: Dictionary=context.recipe()
	return configure_events(library,bindings,recipe.briefing+recipe.result.lines)

func configure_events(library: RefCounted,bindings: RefCounted,events: Array) -> bool:
	clear();_resources=Resources.new()
	for event in events:
		if not event is Dictionary or not preload("res://src/content/opening_definitions.gd").integer(event.get("voice_event_id"),-1,65535):return reject("Speech requires declared voice events")
	if not _resources._configure_campaign(library,bindings,{"events":events}):return reject(_resources.error)
	var ids:=[-1]
	for event in events:
		var id:=int(event.voice_event_id)
		if not ids.has(id):ids.append(id)
	for index in ids.size():_mission_voice_lines[ids[index]]=index
	return _prepare_voices(ids)

func present_mission(dialogue: Dictionary) -> bool:
	if not dialogue.get("visible",false):return present(-1)
	var id:=int(dialogue.get("voice_event_id",-1))
	if not _mission_voice_lines.has(id):return reject("Mission dialogue selected an unprepared voice")
	return present(int(_mission_voice_lines[id]))

func configure(library: RefCounted, bindings: RefCounted) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_station(library,bindings):return reject(_resources.error)
	if not StationEntry.parameters(bindings.station_entry):return reject("Initial station dialogue declarations are unavailable")
	# The initial presentation stores spoken event IDs separately from its
	# full dialogue. Resolve the explicitly declared silent instruction into
	# a real slot, just like later briefings with voice_event_id = -1.
	var presentation: Dictionary=bindings.station_presentation.dialogue
	var spoken: Array=presentation.voice_event_ids
	var ids:=[];var voice_index:=0
	for event in bindings.station_entry.dialogue.events:
		if event.text_id==presentation.silent_text_id:ids.append(-1)
		else:
			if voice_index>=spoken.size():return reject("Initial station dialogue has an unbound voice")
			ids.append(int(spoken[voice_index]));voice_index+=1
	if voice_index!=spoken.size():return reject("Initial station has unused voice declarations")
	if not _prepare_voices(ids):return false
	# This event has authored envelopes that require their own native owner.
	# Keep its unsupported status explicit rather than substituting another loop.
	diagnostics.atmosphere="Station atmosphere envelopes are not connected"
	return true

func configure_mining_briefing(library: RefCounted, bindings: RefCounted, campaign_cursor:=2) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_mining_briefing(library,bindings,campaign_cursor):return reject(_resources.error)
	var ids:=[]
	for event in MiningStory.briefing_presentation(bindings,campaign_cursor).events:
		ids.append(int(event.voice_event_id))
	return _prepare_voices(ids)

func configure_mining_objective(library: RefCounted, bindings: RefCounted, campaign_cursor:=2, failed:=false) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_mining_objective(library,bindings,campaign_cursor):return reject(_resources.error)
	var rules:=MiningStory.objective(bindings,campaign_cursor)
	if failed:
		if not rules.has("campaign_failure"):return reject("This objective has no connected failure speech")
		# The shared source failure is one silent page, not a victory voice.
		return _prepare_voices([int(rules.campaign_failure.voice_event_id)])
	var ids:=[]
	for event in rules.events:
		ids.append(int(event.voice_event_id))
	return _prepare_voices(ids)

func configure_campaign_visit(library: RefCounted,bindings: RefCounted,cursor: int,mission: Dictionary,station_only:=false) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_campaign_visit(library,bindings,cursor,mission,station_only):return reject(_resources.error)
	var ids:=[]
	for event in load("res://src/content/free_campaign_definitions.gd").dialogue_rules(bindings,cursor,mission,station_only).events:ids.append(int(event.voice_event_id))
	return _prepare_voices(ids)

func configure_campaign_result(library: RefCounted,bindings: RefCounted,cursor: int,mission: Dictionary,failed:=false) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_campaign_result(library,bindings,cursor,mission,failed):return reject(_resources.error)
	var events: Array=load("res://src/content/free_campaign_definitions.gd").result_presentation(bindings,cursor,mission,failed).events
	return _prepare_voices(events.map(func(event):return int(event.voice_event_id)))

func configure_station_return(library: RefCounted, bindings: RefCounted, campaign_cursor:=3) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_station_return(library,bindings,campaign_cursor):return reject(_resources.error)
	var ids:=[]
	for event in StationReturn.station_conversation(bindings,campaign_cursor).events:
		ids.append(int(event.voice_event_id))
	return _prepare_voices(ids)

func adopt_conversation(prepared: Node) -> void:
	# Retain currently playing payment/equipment effects when story speech opens.
	if _player!=null:_player.free();_player=null
	_resources=prepared._resources;_clips=prepared._clips.duplicate();_line=-1
	diagnostics=prepared.diagnostics.duplicate(true)

func _prepare_voices(ids: Array) -> bool:
	for id in ids:
		# Silent instructions occupy a dialogue position as well. Compacting
		# voices would shift later lines or reject an acknowledged silent line.
		if id==-1:_clips.append(null);continue
		var clip: Dictionary=_resources.prepare(int(id))
		if clip.is_empty():return reject(_resources.error)
		if clip.has("unsupported") or not clip.get("stream") is AudioStream or not clip.get("voice",false) or clip.spatial or clip.looping:return reject("Unsupported station voice: "+str(clip.get("unsupported",id)))
		_clips.append(clip)
	return true

func configure_station_equipment(library: RefCounted, bindings: RefCounted) -> bool:
	clear();_resources=Resources.new()
	if not _resources.configure_station_equipment(library,bindings):return reject(_resources.error)
	var ids:=[]
	for event in bindings.station_equipment.events:ids.append(int(event.voice_event_id))
	return _prepare_voices(ids)

func prepare_equipment_effects(rules: Dictionary,library: RefCounted=null,bindings: RefCounted=null) -> bool:
	var resources: RefCounted=_resources
	if resources==null:
		if library==null or bindings==null:return reject("Station audio is unavailable")
		resources=Resources.new()
		if not resources.configure_station(library,bindings):return reject(resources.error)
	var clips:={}
	for key in ["mount_audio_id","unmount_audio_id"]:
		var id:=int(rules[key]);var clip: Dictionary=resources.prepare(id)
		if clip.is_empty():return reject(resources.error)
		if clip.has("unsupported") or not clip.get("stream") is AudioStream or clip.get("voice",false) or clip.spatial or clip.looping:return reject("Unsupported equipment sound")
		clips[id]=clip
	_effect_clips=clips
	return true

func play_equipment_effect(id: int) -> void:
	if not _effect_clips.has(id):return
	if _effects.has(id):_effects[id].free()
	var clip: Dictionary=_effect_clips[id]
	var player: Node=Streams.player(clip.stream,false);add_child(player);_effects[id]=player
	player.volume_db=linear_to_db(clip.gain);player.play();player.stream_paused=_paused
	player.finished.connect(func():_effects.erase(id);player.queue_free())
	_effect_history.append(id)

func prepare_contract_effect(library: RefCounted,bindings: RefCounted) -> bool:
	var resources:=Resources.new()
	if not resources.configure_station(library,bindings):return reject(resources.error)
	var id:=int(bindings.early_contracts.delivery_results.notification_sound_id)
	var clip: Dictionary=resources.prepare(id)
	if clip.is_empty() or clip.has("unsupported") or not clip.get("stream") is AudioStream or clip.get("voice",false) or clip.spatial or clip.looping:return reject("The contract payment sound is unavailable")
	_effect_clips[id]=clip
	return true

# Silent pages occupy real null slots. Only -1 closes a conversation; accepting
# the one-past-end index would silently stop a valid voice on a malformed frame.
func valid_line(line: int) -> bool:return line>=-1 and line<_clips.size()

func present(line: int) -> bool:
	if not valid_line(line):return reject("Invalid station speech line")
	if line==_line:return true
	if _player!=null:_player.free();_player=null
	_line=line
	if line<0 or line>=_clips.size():return true
	if _clips[line]==null:return true
	var clip: Dictionary=_clips[line]
	_player=Streams.player(clip.stream,false,"Voice");add_child(_player)
	_player.volume_db=linear_to_db(clip.gain);_player.play();_player.stream_paused=_paused
	_history.append({"line":line,"source_id":clip.id,"source_bank":clip.source_bank,"source_index":clip.source_index})
	return true

func set_paused(value: bool) -> void:
	_paused=value
	if _player!=null:_player.stream_paused=value
	for player in _effects.values():player.stream_paused=value

func snapshot() -> Dictionary:return {"line":_line,"paused":_paused,"history":_history.duplicate(true),"diagnostics":diagnostics.duplicate(true),"equipment_effects":_effect_history.duplicate()}
func clear() -> void:
	for child in get_children():child.free()
	error="";diagnostics={};_resources=null;_clips=[];_player=null;_paused=false;_line=-1;_history=[]
	_effect_clips={};_effects={};_effect_history=[]
	_mission_voice_lines={}
func reject(message: String) -> bool:error=message;return false
