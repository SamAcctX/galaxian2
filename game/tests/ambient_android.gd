extends SceneTree
## The early Mido traffic's Android declarations: the Mac values, spans anchored
## in their own functions over the Android local travel (no imported content).
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Population=preload("res://src/content/ambient_population_definitions.gd")
const Combat=preload("res://src/content/ambient_combat_definitions.gd")
const Destruction=preload("res://src/content/freighter_destruction_definitions.gd")
const Lifecycle=preload("res://src/content/ambient_lifecycle_definitions.gd")
var checks:=0
var failures:=0
var source_bytes:=8000000
var arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":5,"bytes":24,"anchor":1}}}

func _initialize() -> void:
	verify()
	print("Ambient traffic Android declarations: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var travel: Dictionary=Travel.ANDROID_VALUES.duplicate(true)
	travel.continuation=Travel.MAC_CONTINUATION.duplicate(true)
	travel.return_visit=Travel.ANDROID_RETURN_VISIT.duplicate(true)
	travel.provenance={}
	var mac_travel: Dictionary=Travel.MAC_VALUES.duplicate(true);mac_travel.provenance={}
	var population:=android(Population.VALUES,Population.ANDROID_SPANS)
	common("population",func(data,arch,staging,parent):return Population.validate(data,source_bytes,arch,staging,parent),population,travel,mac_travel,"ambient_population_counts")
	mac("population",func(data,arch,staging,parent):return Population.validate(data,source_bytes,arch,staging,parent),Population.VALUES,Population.MAC_SPANS,mac_travel)
	# The population is the same on both editions.
	var combat:=android(Combat.VALUES,Combat.ANDROID_SPANS)
	common("combat",func(data,arch,staging,parent):return Combat.validate(data,source_bytes,arch,staging,parent),combat,population,{},"ambient_combat_factory")
	mac("combat",func(data,arch,staging,parent):return Combat.validate(data,source_bytes,arch,staging,parent),Combat.VALUES,Combat.MAC_SPANS,population)
	var destruction:=android(Destruction.VALUES,Destruction.ANDROID_SPANS)
	common("freighter destruction",func(data,arch,staging,parent):return Destruction.validate(data,source_bytes,arch,staging,parent),destruction,combat,{},"freighter_destruction_death_model")
	mac("freighter destruction",func(data,arch,staging,parent):return Destruction.validate(data,source_bytes,arch,staging,parent),Destruction.VALUES,Destruction.MAC_SPANS,combat)
	var lifecycle:=android(Lifecycle.VALUES,Lifecycle.ANDROID_SPANS);lifecycle.recycling=Lifecycle.RECYCLING.duplicate(true)
	check(Lifecycle.recycling_parameters(lifecycle),"Android lifecycle lost its recycling")
	common("lifecycle",func(data,arch,staging,parent):return Lifecycle.validate(data,source_bytes,arch,staging,parent),lifecycle,combat,{},"ambient_lifecycle_freighter_reset_dispatch")
	var mac_spans: Dictionary=Lifecycle.MAC_SPANS.duplicate();mac_spans.merge(Lifecycle.MAC_RECYCLING_SPANS)
	mac("lifecycle",func(data,arch,staging,parent):return Lifecycle.validate(data,source_bytes,arch,staging,parent),lifecycle,mac_spans,combat)

## Acceptance, other editions, the staging and the proofs of one validator.
func common(name: String,validate: Callable,data: Dictionary,parent: Dictionary,foreign_parent: Dictionary,span: String) -> void:
	check(validate.call(data,"android-armv7",arrival,parent).is_empty(),"Android %s was rejected"%name)
	check(not validate.call(data,"x86_64",arrival,parent).is_empty(),"Android %s proofs passed as Mac layouts"%name)
	check(not validate.call(data,"armv7",arrival,parent).is_empty(),"Android %s proofs passed as iOS layouts"%name)
	check(not validate.call(data,"android-armv7",arrival,foreign_parent).is_empty(),"Android %s accepted a foreign parent"%name)
	check(not validate.call(data,"android-armv7",{"provenance":arrival.provenance},parent).is_empty(),"Android %s accepted a foreign arrival"%name)
	check(not validate.call(data,"android-armv7",{"scope":"rescue_choreography","provenance":{}},parent).is_empty(),"Android %s accepted an unproven arrival"%name)
	var shifted: Dictionary=data.duplicate(true);shifted.provenance[span].offset+=1
	check(not validate.call(shifted,"android-armv7",arrival,parent).is_empty(),"Android %s accepted a shifted proof extent"%name)
	var missing: Dictionary=data.duplicate(true);missing.provenance.erase(span)
	check(not validate.call(missing,"android-armv7",arrival,parent).is_empty(),"Android %s accepted an incomplete proof"%name)

## The Mac path keeps its own layouts.
func mac(name: String,validate: Callable,values: Dictionary,spans: Dictionary,parent: Dictionary) -> void:
	var staging:={"scope":"rescue_choreography","provenance":{"actor":{"offset":1000000,"bytes":315}}}
	var data: Dictionary=values.duplicate(true);data.provenance={}
	for key in spans:data.provenance[key]={"offset":1000000+int(spans[key][0]),"bytes":int(spans[key][1])}
	check(validate.call(data,"x86_64",staging,parent).is_empty(),"Mac %s was rejected"%name)
	check(not validate.call(data,"android-armv7",staging,parent).is_empty(),"Mac %s proofs passed as Android"%name)
	check(not validate.call(data,"armv7",staging,parent).is_empty(),"Mac %s proofs passed as iOS"%name)

func android(values: Dictionary,spans: Dictionary) -> Dictionary:
	var data: Dictionary=values.duplicate(true)
	data.provenance={}
	for key in spans:data.provenance[key]={"offset":4000+int(spans[key][0]),"bytes":int(spans[key][1]),"anchor":4000}
	return data

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
