extends RefCounted
## Coordinates mission transitions while combat, flight, dialogue and career
## retain their native owners. Frame forks make each boundary transactional.
const Context=preload("res://src/simulation/mission_context.gd")
const StationContext=preload("res://src/simulation/mission_station_context.gd")
const Condition=preload("res://src/simulation/mission_result_condition.gd")
const Conversation=preload("res://src/simulation/mission_conversation.gd")
const ResultPoll=preload("res://src/simulation/mission_result_poll.gd")
var error:=""
var _context: RefCounted
var _result:={}
var _readout:={}
var _state:={}
var _conversations:={}
var _conversation: RefCounted
var _dialogue_kind:=""

func configure(context: RefCounted) -> bool:
	error=""
	if _context!=null:return reject("A mission runner is configured only once")
	if not (context is Context or context is StationContext) or context.recipe().is_empty():return reject("Mission runner requires an admitted entry")
	var recipe: Dictionary=context.recipe()
	_context=context;_result=recipe.result;_readout=recipe.get("readout",{})
	_state={"clock_ms":0,"elapsed_ms":0,"mode":0,"retired":false}
	return true

func prepare_conversations(bindings: RefCounted,library: RefCounted) -> bool:
	if _context==null or not _conversations.is_empty():return reject("Prepare mission conversations once at entry")
	var prepared:={}
	for kind in ["briefing","success","failure"]:
		if kind=="briefing" and _context.recipe().briefing.is_empty():continue
		var pages:=Conversation.new()
		if not pages.prepare(bindings,library,_context,kind):return reject(pages.error)
		prepared[kind]=pages
	_conversations=prepared
	return true

## Called only on the acknowledged candidate. Replacing this small coordinator
## clears obsolete result predicates and polling time without touching the cast.
func continue_in_world(bindings: RefCounted,library: RefCounted,loadout: Dictionary) -> RefCounted:
	error=""
	if _context==null or not _state.retired or _conversation!=null:
		reject("A retained continuation requires the acknowledged final result");return null
	var context: RefCounted=_context.retained_successor(bindings,loadout)
	if context==null:reject(_context.error);return null
	var next: RefCounted=get_script().new()
	if not next.configure(context) or not next.prepare_conversations(bindings,library):reject(next.error);return null
	next._state.briefed=true
	return next

func open_briefing() -> bool:
	if _conversation!=null or not _conversations.has("briefing") or _state.get("briefed",false):return reject("The mission briefing is not available")
	_conversation=_conversations.briefing.fork();_dialogue_kind="briefing"
	return true

func open_result() -> bool:
	if _conversation!=null or _state.retired or _state.mode==0:return reject("No new mission result is available")
	var kind:="success" if _state.mode==int(_result.policy.success_result_mode) else "failure"
	if not _conversations.has(kind):return reject("Mission result text was not prepared at entry")
	_conversation=_conversations[kind].fork();_dialogue_kind=kind
	return true

## The caller stages its career/world boundary before accepting this fork.
## Repeated final-page input cannot create another transition.
func navigate(action: String) -> Dictionary:
	if _conversation==null:return fail("No mission conversation is open")
	if not _conversation.navigate(action):return fail(_conversation.error)
	if not _conversation.snapshot().acknowledged:return {"kind":_dialogue_kind,"acknowledged":false}
	var kind:=_dialogue_kind
	var transition: Dictionary={} if kind=="briefing" else _conversation.transition()
	if kind=="success" and not acknowledge():return {}
	if kind=="briefing":_state.briefed=true
	_conversation=null;_dialogue_kind=""
	return {"kind":kind,"acknowledged":true,"transition":transition}

func dialogue() -> Dictionary:
	return {"visible":false} if _conversation==null else _conversation.snapshot().dialogue

func sample_clock(world_ms: int,poll_ms: int) -> bool:
	if _context==null or world_ms<0 or poll_ms<0 or world_ms>2147483647 or poll_ms>2147483647 or world_ms<int(_state.elapsed_ms):return reject("Mission clock must advance monotonically within its supported range")
	if _state.mode!=0 and _result.get("freeze_clock_on_result",false):return reject("Acknowledge the result before advancing its clock")
	_state.elapsed_ms=world_ms;_state.clock_ms=poll_ms
	return true

func observe(actors: Array,sequences: Dictionary={},world_facts: Dictionary={}) -> Dictionary:
	if _context==null or actors.size()!=int(_result.actor_count):return {}
	var observation:={"actors":actors,"sequences":sequences,"world":world_facts,"elapsed_ms":int(_state.elapsed_ms)}
	var success:=Condition.evaluate(_result.success,observation)
	var failure:=Condition.evaluate(_result.failure,observation)
	var periodic:=Condition.evaluate(_result.get("periodic_failure",{"kind":"never"}),observation)
	if success.is_empty() or failure.is_empty() or periodic.is_empty():return {}
	return {"satisfied":success.satisfied,"failed":failure.satisfied,"periodic_failure":periodic.satisfied,
		"defeated":success.get("retired",0),"required":success.get("required",0),
		"convoy_destroyed":failure.get("retired",0),"convoy_count":failure.get("required",0)}

func poll(actors: Array,radio_active: bool,periodic_poll_allowed: bool,player_alive:=true,sequences: Dictionary={},world_facts: Dictionary={}) -> Dictionary:
	error=""
	if _context==null:return fail("Mission runner is not configured")
	if _state.retired or _state.mode!=0 or not player_alive:return snapshot()
	var status:=observe(actors,sequences,world_facts)
	if status.is_empty():return fail("Mission result lost its actor or sequence observation")
	_state=ResultPoll.evaluate(_result.policy,_state,status,radio_active,periodic_poll_allowed,_result.get("reset_while_blocked",true))
	return snapshot()

func acknowledge() -> bool:
	error=""
	if _context==null or _state.retired or _state.mode==0:return reject("No mission result awaits acknowledgement")
	if _state.mode!=int(_result.policy.success_result_mode) and not (_result.get("retire_failure",false) and _state.mode==int(_result.policy.failure_result_mode)):return reject("This failed mission cannot resume after acknowledgement")
	_state.mode=0;_state.retired=true
	return true

func context_owner() -> RefCounted:return _context
## Passive HUD values use the same accepted clock and encounter counters as
## results. Presentation neither advances time nor decides the mission outcome.
func flight_readout(counters: Dictionary={}) -> Dictionary:
	if _context==null or _state.retired or _readout.is_empty():return {}
	match _readout.kind:
		"countdown":
			var remaining: int=int(_readout.duration_ms)-int(_state.elapsed_ms)
			return {"kind":"countdown","remaining_ms":remaining} if remaining>0 else {}
		"contest":
			var player: Variant=counters.get(_readout.player_counter)
			var other: Variant=counters.get(_readout.other_counter)
			if player is int and other is int and player>=0 and other>=0:return {"kind":"contest","player":player,"other":other}
	return {}

func snapshot() -> Dictionary:return _state.duplicate(true)
func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._context=_context;copy._result=_result;copy._readout=_readout;copy._state=_state.duplicate(true)
	copy._conversations=_conversations
	copy._conversation=null if _conversation==null else _conversation.fork();copy._dialogue_kind=_dialogue_kind
	return copy
func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
