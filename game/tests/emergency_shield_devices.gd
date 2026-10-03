extends SceneTree
## Supernova Emergency System (item 185) and Shield Injector (item 227):
## the ship survives a killing hit once with 10 s of invulnerability, the
## empty shield refills from 30 t of Blue Plasma, sounds resolve, and kills
## during the emergency feed Grave Riser (medal 43).
const Emergency=preload("res://src/simulation/emergency_system.gd")
const Injector=preload("res://src/simulation/shield_injector.gd")
const Devices=preload("res://src/simulation/flight_devices.gd")
const PlayerState=preload("res://src/simulation/opening_player_state.gd")
const Tracker=preload("res://src/simulation/elite_medal_tracker.gd")
var library=preload("res://src/content/library.gd").new()
var bindings=preload("res://src/content/resource_bindings.gd").new()
var catalogues=preload("res://src/content/catalogues.gd").new()
var checks:=0
var failures:=0

class FakeCargo extends RefCounted:
	var held:={202:40}
	var error:=""
	func quantity(id: int) -> int:return int(held.get(id,0))
	func fork_for_frame() -> RefCounted:
		var copy:=FakeCargo.new();copy.held=held.duplicate();return copy
	func consume(id: int,units: int) -> bool:
		if quantity(id)<units:error="short";return false
		held[id]=quantity(id)-units;return true
	func snapshot() -> Dictionary:return {"held":held.duplicate()}

class FakeNotices extends RefCounted:
	var lines:=[]
	func enqueue_plasma_injected(units: int) -> bool:lines.append(units);return true

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not catalogues.open(library):check(false,library.error+bindings.error+catalogues.error)
	else:
		verify_items()
		verify_emergency()
		verify_injector()
		verify_medal()
		verify_sounds()
	print("Emergency/shield devices: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func items() -> Array:return catalogues.tables.items

func player(hull: int,shield: float) -> RefCounted:
	var state:=PlayerState.new()
	state._state={"vitals":{"hull":hull,"armor":0,"shield":shield},"capacities":{"shield":100,"armor":0,"shield_item_id":30},"active":true,"damage_allowed":true,"equipment_ids":[185,227]}
	state._emergency=Emergency.create(items(),[185,227]);state._injector=Injector.create(items(),[185,227])
	return state

func verify_items() -> void:
	check(Emergency.find(items(),[95,185])==185 and Injector.find(items(),[227])==227,"Items 185/227 are not found by sorts 27/43")
	var emergency: RefCounted=Emergency.create(items(),[185])
	check(emergency!=null and emergency.duration_ms==10000,"Emergency System does not last 10 s")
	var injector: RefCounted=Injector.create(items(),[227])
	check(injector!=null and injector.amount==30,"Shield Injector does not take 30 t")
	check(Emergency.create(items(),[95])==null and Injector.create(items(),[95])==null,"A ship without the devices got them")

func verify_emergency() -> void:
	var ship:=player(40,0.0)
	ship.advance_devices(16,0)
	check(not ship.emergency_active(),"Emergency fired with hull left")
	# A killing hit: the next device step leaves 1 hull and starts the emergency.
	check(not ship.normal_hit(500).is_empty() and ship.snapshot().vitals.hull==0,"The test hit did not empty the hull")
	var events: Dictionary=ship.advance_devices(16,0)
	check(events.emergency_started and ship.snapshot().vitals.hull==1 and ship.emergency_active(),"Emergency did not leave 1 hull")
	check(ship.snapshot().devices.emergency.used,"Emergency was not used up")
	var hit: Dictionary=ship.normal_hit(500)
	check(not hit.accepted and ship.snapshot().vitals.hull==1,"The ship took damage while invulnerable")
	var ended:=false
	for i in 625:ended=ship.advance_devices(16,0).emergency_ended or ended
	check(ended and not ship.emergency_active(),"Emergency did not end after 10 s")
	check(not ship.normal_hit(500).is_empty() and ship.snapshot().vitals.hull==0,"Damage did not return after the emergency")
	check(not ship.advance_devices(16,0).emergency_started and ship.snapshot().vitals.hull==0,"Emergency fired twice")
	# Forked frames keep their own timer.
	var other:=player(0,0.0);other.advance_devices(16,0)
	var copy: RefCounted=other.fork_for_frame();copy.advance_devices(10000,0)
	check(other.emergency_active() and not copy.emergency_active(),"A frame fork shares the emergency timer")

func verify_injector() -> void:
	var ship:=player(50,0.0)
	var cargo:=FakeCargo.new();var notices:=FakeNotices.new()
	var step: Dictionary=Devices.advance(ship,cargo,null,notices,16)
	check(step.events.plasma_used==30 and step.cargo.quantity(202)==10 and cargo.quantity(202)==40,"Injection did not take 30 t from a forked hold")
	check(notices.lines==[30],"No '-30t' notice")
	check(ship.snapshot().vitals.shield==2.0 and ship.snapshot().devices.injector.filling,"Shield did not start filling at 0.15/ms")
	cargo=step.cargo
	var frames:=0
	while ship.snapshot().devices.injector.filling and frames<200:
		step=Devices.advance(ship,cargo,null,notices,16);cargo=step.cargo;frames+=1
	check(ship.snapshot().vitals.shield==100.0 and frames<=60,"Shield did not refill to full in under 1 s")
	check(cargo.quantity(202)==10,"Plasma was taken again while filling")
	# Empty again with only 10 t: nothing happens.
	ship._state.vitals.shield=0.0
	step=Devices.advance(ship,cargo,null,notices,16)
	check(step.events.plasma_used==0 and ship.snapshot().vitals.shield==0.0,"Injected without enough plasma")
	var bare:=player(50,0.0);bare._state.capacities={"shield":0,"armor":0,"shield_item_id":-1}
	check(Devices.advance(bare,FakeCargo.new(),null,null,16).events.plasma_used==0,"Injected without a shield")

func verify_medal() -> void:
	var tracker:=Tracker.new()
	var state:={"player":{"devices":{"emergency":{"active":true}}},"encounter":{"controller":{"accounting":{"counter_deltas":{"player_kills":0}}}}}
	tracker.observe(state)
	for kills in [1,2,3,4]:
		state.encounter.controller.accounting.counter_deltas.player_kills=kills;tracker.observe(state)
	check(not 43 in tracker.reached(),"Grave Riser latched early")
	state.player.devices.emergency.active=false;state.encounter.controller.accounting.counter_deltas.player_kills=5;tracker.observe(state)
	check(not 43 in tracker.reached(),"Kills after the emergency counted")
	state.player.devices.emergency.active=true
	for kills in [6,7,8,9,10]:
		state.encounter.controller.accounting.counter_deltas.player_kills=kills;tracker.observe(state)
	check(43 in tracker.reached(),"5 kills during one emergency did not reach Grave Riser")

func verify_sounds() -> void:
	var feedback: Node=load("res://src/presentation/flight_devices_feedback.gd").new()
	get_root().add_child(feedback)
	feedback.configure(library,bindings)
	var clips: Array=feedback.snapshot().clips
	for id in [Emergency.SOUND,Injector.START_SOUND,Injector.LOOP_SOUND,Injector.END_SOUND]:check(id in clips,"Sound %d does not resolve"%id)
	feedback.present({"emergency":{"active":true},"injector":{"filling":true}})
	check(feedback.snapshot().emergency and feedback.snapshot().filling,"Feedback missed the device start")
	feedback.present({"emergency":{"active":false},"injector":{"filling":false}})
	check(not feedback.snapshot().emergency and not feedback.snapshot().filling,"Feedback missed the device end")
	feedback.free()

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
