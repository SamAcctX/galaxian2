extends SceneTree
## Focused harness-clock contract, not a mission or content-fidelity proof.
const Cadence=preload("res://tests/fixtures/mission_host_cadence.gd")
const Clock=preload("res://src/simulation/frame_clock.gd")
var checks:=0
var failures:=0

class TimingContext extends RefCounted:
	var base_content_id:="a".repeat(64)
	var binding_id:="b".repeat(64)
	var frame_clock:={"time_unit":"milliseconds","max_frame_milliseconds":100}

func _initialize() -> void:call_deferred("verify")

func verify() -> void:
	var context:=TimingContext.new()
	for offset in [0,123,999]:
		var clock:=Clock.new();var now_us: int=9000000+offset
		check(clock.configure(context,context.base_content_id) and clock.rebase(now_us),clock.error)
		var origin:=now_us;var total_ms:=0;var samples:={};var steps:={}
		var defeats_truncation:=false;var defeats_fixed7:=false
		for index in 288:
			var delta:=Cadence.rate_delta_us(index,144)
			var actual:=roundi(clock.sample(now_us+delta,false)*1000.0)
			check(clock.error.is_empty() and actual==Cadence.native_delta_ms(now_us,delta),"High-rate expectation disagreed with the actual clock")
			defeats_truncation=defeats_truncation or actual!=delta/1000
			defeats_fixed7=defeats_fixed7 or actual!=7
			now_us+=delta;total_ms+=actual;samples[delta]=true;steps[actual]=true
			check(now_us-origin==(index+1)*1000000/144 and total_ms==Cadence.native_delta_ms(origin,now_us-origin),"Cumulative high-rate input or simulation drifted")
		check(now_us-origin==2000000 and total_ms==2000 and samples.size()==2 and samples.has(6944) and samples.has(6945)
			and steps.size()==2 and steps.has(6) and steps.has(7),"Two high-rate seconds omitted a fractional boundary")
		check(defeats_truncation and defeats_fixed7,"Clock fixture would accept per-frame truncation or fixed7ms")
		# A capture/focus gap rebases without advancing the simulated world.
		now_us+=7654321
		check(clock.rebase(now_us),clock.error)
		var delta:=Cadence.rate_delta_us(288,144)
		var resumed:=roundi(clock.sample(now_us+delta,false)*1000.0)
		check(resumed==Cadence.native_delta_ms(now_us,delta) and resumed in [6,7],"Focus resume caught up paused time or lost its absolute endpoint")
		now_us+=delta
		check(clock.sample(now_us+3456789,true)==0.0,"Blocked clock advanced simulation")
		now_us+=3456789;delta=Cadence.rate_delta_us(289,144)
		check(roundi(clock.sample(now_us+delta,false)*1000.0)==Cadence.native_delta_ms(now_us,delta),"Blocked sampling leaked paused time into the next frame")
		# The established variable schedule still satisfies its old step guard,
		# even when the clock origin is not on a millisecond boundary.
		now_us+=delta
		for variable_delta in [4000,17000,31000,9000,67000]:
			check(roundi(clock.sample(now_us+variable_delta,false)*1000.0)==variable_delta/1000,"Variable-cadence legacy step expectation changed")
			now_us+=variable_delta
	print("Host cadence clock: ",checks," checks; ",failures," failures; unaligned144Hz, pause/rebase and legacy variable intervals; not earned gameplay")
	quit(0 if failures==0 else 1)

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr(message)
