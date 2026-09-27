extends "res://tests/void_ambush_cadence_application.gd"
## Earned entry, then actual 144Hz Host input through result41 into living42.
## The preceding mission40 pilot is unchanged; this is not a render-FPS test.
const HostCadence=preload("res://tests/fixtures/mission_host_cadence.gd")
var native_steps:={}
var clock_origin_us:=-1
var clock_origin_ms:=0

func cadence_delta_us(index: int) -> int:
	return HostCadence.rate_delta_us(index,144)

func check_cadence_step(before_ms: int,after_ms: int,start_us: int,delta_us: int) -> void:
	if clock_origin_us<0:clock_origin_us=start_us;clock_origin_ms=before_ms
	var native_delta:=after_ms-before_ms
	check(native_delta==HostCadence.native_delta_ms(start_us,delta_us),
		"Earned144Hz Host lost absolute millisecond endpoints at sample "+str(cadence_frames))
	check(start_us-clock_origin_us==cadence_elapsed_us and cadence_elapsed_us+delta_us==(cadence_frames+1)*1000000/144,
		"Earned144Hz Host timestamps drifted from the cumulative input schedule")
	check(after_ms-clock_origin_ms==HostCadence.native_delta_ms(clock_origin_us,cadence_elapsed_us+delta_us),
		"Earned144Hz flight lost accumulated native time across a capture or dialogue boundary")
	native_steps[native_delta]=true

func check_cadence_coverage() -> void:
	check(cadence_kinds.size()==2 and cadence_kinds.has(6944) and cadence_kinds.has(6945)
		and native_steps.size()==2 and native_steps.has(6) and native_steps.has(7),
		"Earned144Hz battle omitted fractional input intervals or native6/7ms steps")

func cadence_capture_label(label: String) -> String:
	return label.replace("void41-cadence-","void41-high-rate-")

func verify_free_application() -> void:
	await super.verify_free_application()
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),
		"Earned144Hz journey changed its original Néhma checkpoint")
	if not failures:print("Earned144Hz Host accepted: ",cadence_frames," samples, ",cadence_elapsed_us,"us; absolute origin ",clock_origin_us,
		"; native steps ",native_steps.keys(),"; primary emissions ",emitted_primary_shots,"; same living42, no escape or save")
