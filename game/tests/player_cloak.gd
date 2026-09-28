extends SceneTree
const Cloak=preload("res://src/simulation/player_cloak.gd")
var library=preload("res://src/content/library.gd").new()
var bindings=preload("res://src/content/resource_bindings.gd").new()
var catalogues=preload("res://src/content/catalogues.gd").new()
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not catalogues.open(library):check(false,library.error+bindings.error+catalogues.error)
	else:
		verify_requests()
		verify_timing()
		verify_appearance()
		verify_cargo()
	print("Player cloaking: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func configured(ids: Array=[95],ship:=0,difficulty:=0.5) -> RefCounted:
	var owner:=Cloak.new();check(owner.configure(bindings,catalogues,ids,ship,difficulty),owner.error)
	return owner

func advance(owner: RefCounted,total: int,cadence: Array=[100]) -> bool:
	var remaining:=total;var index:=0
	while remaining>0:
		var delta: int=mini(remaining,int(cadence[index%cadence.size()]))
		if not owner.advance(delta):check(false,owner.error);return false
		remaining-=delta;index+=1
	return true

func verify_requests() -> void:
	var owner:=configured([]);var initial: Dictionary=owner.snapshot()
	check(not owner.request_start(20).started and owner.snapshot()==initial,"An unequipped ship charged a cloak")
	owner=configured();initial=owner.snapshot()
	check(not owner.request_start(20,false).started and owner.snapshot()==initial,"A blocked press started charging")
	var empty: Dictionary=owner.request_start(0)
	check(empty.insufficient_energy and empty.consumed==0 and owner.snapshot()==initial,"Insufficient cells consumed energy or changed readiness")
	var start: Dictionary=owner.request_start(1)
	check(start.started and start.consumed==1 and owner.snapshot().phase=="charging" and not owner.active(),"One bought cell did not start U'tool charging")
	check(owner.snapshot().audio.is_empty(),"Charging played the active cloak sound early")
	var accepted: Dictionary=owner.snapshot()
	check(not owner.request_start(20).started and owner.snapshot()==accepted,"Repeated charging input spent another cell")
	check(owner.advance(0) and owner.snapshot()==accepted,"Paused cloak advanced charging")
	var fork: RefCounted=owner.fork_for_frame()
	check(advance(fork,2002) and fork.active() and owner.snapshot()==accepted,"Prepared cloak activation altered its parent frame")
	accepted=fork.snapshot()
	for value in [-1,1001,0.25,NAN,"100",true]:check(not fork.advance(value) and fork.snapshot()==accepted,"Bad frame time partly changed cloaking")
	for value in [-1,0.5,NAN,"1",true]:check(fork.request_start(value).is_empty() and fork.snapshot()==accepted,"Invalid cargo count changed cloak state")
	check(fork.request_start(2,null).is_empty() and fork.snapshot()==accepted,"Invalid activation permission changed cloak state")
	check(not fork.configure(bindings,catalogues,[9999],0,0.5) and fork.snapshot()==accepted,"Unknown loadout replaced a retained cloak")
	check(not fork.configure(bindings,catalogues,[95],0,0.2) and fork.snapshot()==accepted,"Unknown difficulty changed cloak readiness")
	for hull in [44,49]:
		var builtin:=configured([94],hull)
		check(builtin.snapshot().builtin and builtin.request_start(1).started,"Built-in cloaking lost precedence over fitted equipment")

func verify_timing() -> void:
	for item in [94,95,96]:
		for cadence in [[100],[7,7,6],[5,11,16,33,100,6]]:
			var owner:=configured([item]);var device: Dictionary=owner.snapshot()
			var cost: int=device.energy_cost;owner.request_start(cost)
			check(advance(owner,int(device.charge_ms)+1,cadence) and not owner.active(),"Cloak skipped its full initial charging delay")
			check(owner.advance(1) and owner.active() and owner.snapshot().elapsed_ms==0,"Completed charge did not start cloak at its own zero clock")
			check(owner.snapshot().audio.size()==1 and owner.snapshot().audio[0].source_id==30,"Active cloak omitted its original sound")
			var state: Dictionary=owner.snapshot()
			check(not owner.request_start(cost).started and owner.snapshot()==state,"Active cloak input restarted its duration")
			check(advance(owner,int(device.duration_ms),cadence) and owner.active(),"Cloak expired before its inclusive active duration")
			check(owner.advance(1) and not owner.active() and owner.snapshot().remaining_ms==7000 and owner.snapshot().audio_serial==2,"Cloak expiry missed visibility, cooldown or exit sound")
			state=owner.snapshot()
			check(not owner.request_start(cost).started and owner.snapshot()==state,"Cooling device spent cells or restarted")
			check(advance(owner,6999,cadence) and not owner.ready(),"Cloak cooldown ended early")
			check(owner.advance(1) and owner.ready() and owner.snapshot().ready_serial==1,"Cloak did not become ready at the end of cooldown")
			owner.request_start(cost)
			check(advance(owner,int(device.charge_ms),cadence) and not owner.active() and owner.advance(1) and owner.active(),"Recharged cloak retained its initial sentinel delay")
	for setting in [[1.0,9000],[1.5,12000]]:
		var owner:=configured([95],0,setting[0]);owner.request_start(1)
		advance(owner,2002);advance(owner,10001)
		check(owner.snapshot().remaining_ms==setting[1],"Difficulty did not retain its source cloak cooldown")

func verify_appearance() -> void:
	var owner:=configured();owner.request_start(1);advance(owner,2002)
	check(owner.snapshot().dissolve==0 and owner.snapshot().attachment_alpha==1,"Newly active cloak skipped its visible entry")
	advance(owner,1000)
	check(is_equal_approx(owner.snapshot().dissolve,0.5) and owner.snapshot().animation_seconds==1,"Entry dissolve did not follow accepted cloak time")
	var accepted: Dictionary=owner.snapshot()
	check(owner.advance(0) and owner.snapshot()==accepted,"Paused cloak animated its mask or background distortion")
	advance(owner,1000)
	check(owner.snapshot().dissolve==1 and is_equal_approx(owner.snapshot().attachment_alpha,50.0/255) and is_equal_approx(owner.snapshot().exhaust_alpha,20.0/255),"Full cloak retained opaque attachments or bright exhaust")
	advance(owner,6000)
	check(owner.snapshot().dissolve==1,"Cloak ended its steady visibility period early")
	advance(owner,1000)
	check(is_equal_approx(owner.snapshot().dissolve,0.5),"Cloak did not reverse its dissolve before expiry")
	advance(owner,1000)
	check(owner.active() and owner.snapshot().dissolve==0 and owner.snapshot().attachment_alpha==1,"Last active sample did not restore original visibility")
	owner.advance(1)
	check(not owner.active() and owner.snapshot().dissolve==0,"Expired cloak kept a refracting surface")

func verify_cargo() -> void:
	# This detached hold tests consumption only; no station purchase is claimed.
	var cargo=load("res://src/simulation/flight_cargo.gd").new()
	cargo._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":0,"capacity":20,"used":6,
		"entries":[{"item_id":122,"quantity":3},{"item_id":116,"quantity":1,"mission":true},{"item_id":125,"quantity":2}]}
	cargo._item_count=catalogues.tables.items.size();cargo._mission_cargo_id=116
	var before: Dictionary=cargo.snapshot();var cloak:=configured([94]);var inactive: Dictionary=cloak.snapshot()
	var result: Dictionary=cloak.evaluate_request(cargo)
	check(not result.is_empty() and result.started and result.consumed==2,"Owned energy cells did not start the fitted cloak")
	check(cargo.snapshot()==before and cloak.snapshot()==inactive,"Speculative cloak activation spent its parent cargo")
	if result.is_empty():return
	var spent: Dictionary=result.cargo.snapshot()
	check(spent.used==4 and spent.free_space==16 and result.cargo.quantity(122)==1 and spent.entries.slice(1)==before.entries.slice(1),"Cloaking altered unrelated goods or failed to release cargo space")
	var again: Dictionary=result.cloak.evaluate_request(result.cargo)
	check(not again.started and again.cargo.snapshot()==spent,"Repeated charging input consumed another cargo unit")
	var empty: Dictionary=cloak.evaluate_request(result.cargo)
	check(not empty.started and empty.insufficient_energy and empty.cargo.snapshot()==spent,"Insufficient energy changed a retained hold")
	for args in [[116,1],[122,2],[122,0],[122,-1],[122,0.5],[-1,1]]:
		check(not result.cargo.consume(args[0],args[1]) and result.cargo.snapshot()==spent,"Rejected consumption changed cargo or spent protected mission goods")
	check(result.cargo.consume(122,1) and result.cargo.quantity(122)==0 and result.cargo.snapshot().entries.size()==2 and result.cargo.snapshot().used==3,"Consuming the last cell left an empty row or stale used space")
	var foreign: RefCounted=cargo.fork_for_frame();foreign._state.binding_id="0".repeat(64)
	check(cloak.evaluate_request(foreign).is_empty() and cloak.snapshot()==inactive,"Foreign cargo activated a fitted cloak")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
