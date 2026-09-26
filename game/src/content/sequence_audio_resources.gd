extends RefCounted
## Explicit two-parameter adapter; decoding, playlists and FEV curves stay shared.
const Audio=preload("res://src/content/audio_resources.gd")
const Numbers=preload("res://src/content/audio_definitions.gd")
const Envelope=preload("res://src/content/audio_envelope.gd")
var error:=""

func prepare(resources: Audio,id: int) -> Dictionary:
	error=""
	var ordinary:=resources.prepare(id)
	if ordinary.is_empty():return failed(resources.error)
	if not ordinary.has("unsupported"):return ordinary
	# AudioResources is the already validated import/cache owner. Its parsed FEV
	# declarations are read here, never replaced or approximated by new constants.
	var events: Array=resources._definitions.get("events",[])
	if id<0 or id>=events.size():return failed("Sequence sound declaration is absent")
	var event: Dictionary=events[id]
	if event.get("type")!=8 or event.get("categories")!=["sfx"] or not resources.compatible_category(event.categories,id) or event.get("parameters",[]).size()!=2:return failed(ordinary.unsupported)
	var p: Dictionary=event.properties
	if p.mode!=0x280010 or p.flags!=0 or p.max_playbacks!=1 or p.max_playbacks_behavior!=1 or p.pitch!=0 or p.pitch_random!=0 or p.volume_random!=0:return failed("Unsupported multivariate event instance")
	for key in ["distance_filter","speaker_spread","position_random_min","position_random_max","spawn_random"]:
		if p.get(key)!=0:return failed("Unsupported multivariate spatial behavior")
	if p.cone_inside!=360 or p.cone_outside!=360 or p.cone_outside_volume!=1 or p.pan_level!=1 or p.spawn_intensity!=1 or not Numbers.number(p.volume,0,4) or not Numbers.number(p.min_distance,0,1000000) or not Numbers.number(p.max_distance,p.min_distance+0.000001,1000000) or not Numbers.integer(p.fade_in_ms,0,60000) or not Numbers.integer(p.fade_out_ms,0,60000):return failed("Unsupported multivariate event level or range")
	var clock: Dictionary=event.parameters[0];var control: Dictionary=event.parameters[1]
	if clock.flags!=9 or clock.min!=0 or clock.max!=1 or clock.envelopes!=0 or not Numbers.number(clock.velocity,0.000001,1) or not Numbers.number(clock.seek_speed,0,1) or clock.sustain_points!=[]:return failed("Unsupported autonomous audio parameter")
	if control.flags!=2 or control.min!=0 or control.max!=1 or control.velocity!=0 or control.seek_speed!=0 or control.sustain_points!=[]:return failed("Unsupported external audio parameter")
	if event.layers.is_empty() or event.layers.size()>8:return failed("Unsupported multivariate layer count")
	var groups:=[];var envelope_count:=0;var sound_count:=0
	for layer in event.layers:
		if layer.flags!=2 or layer.priority!=65535 or layer.parameter!=0 or layer.envelopes.size()>1:return failed("Unsupported multivariate layer control")
		for envelope in layer.envelopes:
			if not Envelope.supported(envelope,2) or envelope.flags!=12 or envelope.parameter_index!=1:return failed("Unsupported multivariate layer envelope")
			envelope_count+=1
		var sounds:=[];var previous_end:=-1.0
		for sound in layer.sounds:
			sound_count+=1
			if sound_count>32 or not Numbers.number(sound.x,0,1) or not Numbers.number(sound.width,0.000001,1) or sound.x<previous_end or sound.x+sound.width>1.0000001:return failed("Unsupported overlapping audio windows")
			previous_end=sound.x+sound.width
			if int(sound.flags) not in [0,1] or sound.flags2!=0 or sound.loop_count!=-1 or sound.auto_pitch!=0 or sound.fine_tune!=0 or not Numbers.number(sound.volume,0,1) or sound.fade_in!=-1 or sound.fade_out!=-1:return failed("Unsupported multivariate sound automation")
			var playlist:=resources.cached_playlist(int(sound.sound_def),sound.flags==0)
			if playlist.is_empty():return failed(resources.error)
			if playlist.has("unsupported"):return failed(playlist.unsupported)
			sounds.append({"key":str(groups.size())+":"+str(sounds.size()),"start":float(sound.x),"width":float(sound.width),"volume":float(sound.volume),"looping":sound.flags==0,"definition":playlist})
		if sounds.is_empty():return failed("Empty multivariate audio layer")
		groups.append({"definition":{"spatial":true,"parameter":{"velocity":float(clock.velocity)},"layers":[sounds]},"envelopes":layer.envelopes.duplicate(true)})
	if envelope_count!=int(control.envelopes):return failed("Multivariate envelope count differs from its parameter")
	var result:=resources.event_header(event)
	result.merge({"kind":"sequence_layers","groups":groups,"parameters":event.parameters.duplicate(true),"looping":true})
	return result

## Actor instances retain separate handles. Admit only a bounded population,
## so an authored overflow policy is never replaced with invented stealing.
func prepare_actor_loop(resources: Audio,id: int,population: int) -> Dictionary:
	error=""
	var events: Array=resources._definitions.get("events",[])
	if id<0 or id>=events.size() or population<1:return failed("Actor loop requires a declared source event and population")
	var event: Dictionary=events[id];var p: Dictionary=event.properties
	if event.get("type")!=16 or event.get("simple_flags")!=1 or event.get("categories")!=["sfx"] or not resources.compatible_category(event.categories,id) or not event.get("sound") is Dictionary:return failed("Actor engine requires a static source effect")
	if p.mode!=0x280010 or p.flags!=0 or p.doppler!=0 or p.pitch!=0 or not Numbers.number(p.pitch_random,0,1) or p.volume_random!=0 or not Numbers.integer(p.max_playbacks,1,32) or population>p.max_playbacks or int(p.max_playbacks_behavior) not in [1,5]:return failed("Unsupported actor loop spatial or instance policy")
	for key in ["distance_filter","speaker_spread","position_random_min","position_random_max","spawn_random"]:
		if p.get(key)!=0:return failed("Unsupported actor loop spatial modulation")
	if not Numbers.number(p.cone_inside,0,360) or not Numbers.number(p.cone_outside,0,360) or p.cone_outside_volume!=1 or p.pan_level!=1 or p.spawn_intensity!=1 or not Numbers.number(p.volume,0,4) or not Numbers.number(p.min_distance,0,1000000) or not Numbers.number(p.max_distance,p.min_distance+0.000001,1000000) or not Numbers.integer(p.fade_in_ms,0,60000) or not Numbers.integer(p.fade_out_ms,0,60000):return failed("Unsupported actor loop level or range")
	var sound: Dictionary=event.sound
	if sound.flags!=0 or sound.flags2!=0 or sound.loop_count!=-1 or sound.auto_pitch!=0 or sound.fine_tune!=0 or sound.x!=0 or sound.width!=1 or float(sound.fade_in) not in [-1.0,0.0] or float(sound.fade_out) not in [-1.0,0.0] or not Numbers.number(sound.volume,0,4):return failed("Unsupported actor loop scheduling")
	var definition:=resources.cached_playlist(int(sound.sound_def),true)
	if definition.is_empty():return failed(resources.error)
	if definition.has("unsupported"):return failed(definition.unsupported)
	var result:=resources.event_header(event)
	result.gain*=float(sound.volume);result.merge({"kind":"playlist","definition":definition,"looping":true})
	return result

func failed(message: String) -> Dictionary:error=message;return {}
