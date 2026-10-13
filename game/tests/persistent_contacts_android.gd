extends SceneTree
## The persistent contact Android declarations: spans anchored in their own
## functions over the ordinary generation (no imported content).
const Definitions=preload("res://src/content/persistent_contact_definitions.gd")
const Ordinary=preload("res://src/content/ordinary_generation_definitions.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	print("Persistent contact Android declarations: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var source_bytes:=8000000
	var arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":5,"bytes":24,"anchor":1}}}
	var data: Dictionary=Definitions.VALUES.duplicate(true)
	data.provenance={}
	for key in Definitions.ANDROID_SPANS:data.provenance[key]={"offset":4000+int(Definitions.ANDROID_SPANS[key][0]),"bytes":int(Definitions.ANDROID_SPANS[key][1]),"anchor":4000}
	check(Definitions.validate(data,source_bytes,"android-armv7",arrival,Ordinary.VALUES).is_empty(),"Android persistent contacts were rejected")
	check(not Definitions.validate(data,source_bytes,"x86_64",arrival,Ordinary.VALUES).is_empty(),"Android proofs passed as Mac layouts")
	check(not Definitions.validate(data,source_bytes,"armv7",arrival,Ordinary.VALUES).is_empty(),"Android proofs passed as iOS layouts")
	check(not Definitions.validate(data,source_bytes,"android-armv7",arrival,{}).is_empty(),"Android contacts accepted a missing ordinary generation")
	check(not Definitions.validate(data,source_bytes,"android-armv7",{"provenance":arrival.provenance},Ordinary.VALUES).is_empty(),"Android contacts accepted a foreign arrival")
	check(not Definitions.validate(data,source_bytes,"android-armv7",{"scope":"rescue_choreography","provenance":{}},Ordinary.VALUES).is_empty(),"Android contacts accepted an unproven arrival")
	var shifted: Dictionary=data.duplicate(true);shifted.provenance.persistent_loader.offset+=1
	check(not Definitions.validate(shifted,source_bytes,"android-armv7",arrival,Ordinary.VALUES).is_empty(),"Android contacts accepted a shifted proof extent")
	var missing: Dictionary=data.duplicate(true);missing.provenance.erase("persistent_price_getter")
	check(not Definitions.validate(missing,source_bytes,"android-armv7",arrival,Ordinary.VALUES).is_empty(),"Android contacts accepted an incomplete proof")
	var mac_arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":1000000,"bytes":315}}}
	var mac: Dictionary=Definitions.VALUES.duplicate(true);mac.provenance={}
	for key in Definitions.MAC_SPANS:mac.provenance[key]={"offset":1000000+int(Definitions.MAC_SPANS[key][0]),"bytes":int(Definitions.MAC_SPANS[key][1])}
	check(Definitions.validate(mac,source_bytes,"x86_64",mac_arrival,Ordinary.VALUES).is_empty(),"Mac persistent contacts were rejected")
	check(not Definitions.validate(mac,source_bytes,"android-armv7",mac_arrival,Ordinary.VALUES).is_empty(),"Mac proofs passed as Android")
	check(not Definitions.validate(mac,source_bytes,"armv7",mac_arrival,Ordinary.VALUES).is_empty(),"Mac proofs passed as iOS")

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
