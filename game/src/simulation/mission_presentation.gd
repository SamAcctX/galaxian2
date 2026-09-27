extends RefCounted
## A recipe-owned presentation clock. It never mutates the career or grants a
## reward; its completed state permits the enclosing runner's next boundary.
const Radio=preload("res://src/simulation/radio_sequence.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _spec:={}
var _identity:={}
var _radio: RefCounted
var _elapsed_ms:=0
var _credits_started_ms:=-1
var _complete:=false
var _completion:=""
var _events:=[]

func configure(bindings: RefCounted,library: RefCounted,layout: RefCounted,cursor: int,spec: Dictionary) -> bool:
	if not _identity.is_empty():return reject("A presentation is prepared only once")
	if not valid_spec(spec):return reject("Invalid presentation timing or artwork declarations")
	var radio:=Radio.new()
	if not radio.configure_scripted(bindings,library,layout,cursor,spec.radio):return reject(radio.error)
	_spec=spec.duplicate(true);_radio=radio
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":cursor}
	return true

static func valid_spec(spec: Dictionary) -> bool:
	if spec.get("kind")!="credits" or not spec.get("radio") is Array:return false
	for key in ["fade_out_ms","fade_in_ms","radio_delay_ms","final_fade_at_ms","complete_after_ms","logo_pause_ms"]:
		if not Numbers.integer(spec.get(key),1,2147483647):return false
	if spec.radio_delay_ms<spec.fade_out_ms+spec.fade_in_ms or spec.final_fade_at_ms<=spec.radio_delay_ms or spec.complete_after_ms<=spec.final_fade_at_ms:return false
	for key in ["logo_image_id","credits_text_id","music_event_id"]:
		if not Numbers.integer(spec.get(key),0,65535):return false
	for key in ["scroll_pixels_per_second","logo_gap_pixels","camera_yaw_rate"]:
		var value: Variant=spec.get(key)
		if not (value is int or value is float) or not is_finite(value) or value<0 or value>10000:return false
	return spec.scroll_pixels_per_second>0

func advance(milliseconds: int) -> bool:
	error=""
	if _identity.is_empty() or milliseconds<0 or milliseconds>2147483647-_elapsed_ms:return reject("Invalid presentation clock")
	if _complete:return reject("The presentation has already completed")
	var elapsed:=_elapsed_ms+milliseconds
	var radio: RefCounted=_radio.fork_for_frame()
	var changes:=[]
	if elapsed>=int(_spec.radio_delay_ms):
		var observation:=_identity.duplicate();observation.condition_clock=elapsed-int(_spec.radio_delay_ms)
		if not radio.bind_context(observation):return reject(radio.error)
		changes=radio.step_context(int(observation.condition_clock))
		if not radio.error.is_empty():return reject(radio.error)
	_elapsed_ms=elapsed;_radio=radio;_events=changes
	if _credits_started_ms<0 and radio.snapshot().finished.all(func(value):return value):_credits_started_ms=elapsed
	if elapsed>int(_spec.complete_after_ms):_complete=true;_completion="watched"
	return true

func skip() -> bool:
	error=""
	if _identity.is_empty() or _credits_started_ms<0 or _complete:return reject("Finish the radio sequence before leaving the presentation")
	_complete=true;_completion="skipped";_events=[]
	return true

func completes(bindings: RefCounted,cursor: int,spec: Dictionary) -> bool:
	return _complete and _identity=={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":cursor} and _spec==spec

func snapshot() -> Dictionary:
	if _identity.is_empty():return {}
	var fade:=0.0
	if _elapsed_ms<int(_spec.fade_out_ms):fade=float(_elapsed_ms)/float(_spec.fade_out_ms)
	elif _elapsed_ms<int(_spec.fade_out_ms)+int(_spec.fade_in_ms):fade=1.0-float(_elapsed_ms-int(_spec.fade_out_ms))/float(_spec.fade_in_ms)
	elif _elapsed_ms>int(_spec.final_fade_at_ms):fade=clampf(float(_elapsed_ms-int(_spec.final_fade_at_ms))/float(int(_spec.complete_after_ms)-int(_spec.final_fade_at_ms)),0,1)
	var result:=_identity.duplicate()
	result.merge({"elapsed_ms":_elapsed_ms,"background_swapped":_elapsed_ms>=int(_spec.fade_out_ms),
		"background_elapsed_ms":maxi(0,_elapsed_ms-int(_spec.fade_out_ms)),"fade_alpha":fade,
		"radio":_radio.snapshot(),"radio_events":_events.duplicate(true),
		"credits_visible":_credits_started_ms>=0,"credits_elapsed_ms":_elapsed_ms-_credits_started_ms if _credits_started_ms>=0 else 0,
		"can_skip":_credits_started_ms>=0 and not _complete,"complete":_complete,"completion":_completion})
	return result

## Layout can change with the viewport without changing dialogue or completion
## timing. Integrate the scroll analytically so the centre hold is frame-rate independent.
func credits_layout(height: float,logo_height: float) -> Dictionary:
	if _identity.is_empty() or not is_finite(height) or not is_finite(logo_height) or height<=0 or logo_height<=0:return {}
	var centre:=height/2.0
	var distance:=height+logo_height+float(_spec.logo_gap_pixels)
	var travel_ms:=distance*1000.0/float(_spec.scroll_pixels_per_second)
	var elapsed:=float(maxi(0,_elapsed_ms-_credits_started_ms)) if _credits_started_ms>=0 else 0.0
	var moving_ms:=minf(elapsed,travel_ms)+maxf(0.0,elapsed-travel_ms-float(_spec.logo_pause_ms))
	var logo_y:=centre+distance-moving_ms*float(_spec.scroll_pixels_per_second)/1000.0
	return {"logo_y":logo_y,"credits_y":centre+logo_height+logo_y,"holding":elapsed>=travel_ms and elapsed<travel_ms+float(_spec.logo_pause_ms)}

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._spec=_spec;copy._identity=_identity;copy._radio=null if _radio==null else _radio.fork_for_frame()
	copy._elapsed_ms=_elapsed_ms;copy._credits_started_ms=_credits_started_ms
	copy._complete=_complete;copy._completion=_completion;copy._events=_events.duplicate(true)
	return copy

func reject(message: String) -> bool:error=message;return false
