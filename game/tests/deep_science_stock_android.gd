extends SceneTree
## The Deep Science stock Android declarations: spans anchored in their own
## functions over the Android base stock (no imported content).
const Definitions=preload("res://src/content/deep_science_stock_definitions.gd")
const BaseStock=preload("res://src/content/base_station_stock_definitions.gd")
var checks:=0
var failures:=0

class Bindings extends RefCounted:
	var source_architecture: String
	var early_contracts: Dictionary
	var deep_science_stock: Dictionary

func _initialize() -> void:
	verify()
	print("Deep Science stock Android declarations: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var source_bytes:=8000000
	var arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":5,"bytes":24,"anchor":1}}}
	var data: Dictionary=Definitions.VALUES.duplicate(true)
	data.provenance={}
	for key in Definitions.ANDROID_SPANS:data.provenance[key]={"offset":4000+int(Definitions.ANDROID_SPANS[key][0]),"bytes":int(Definitions.ANDROID_SPANS[key][1]),"anchor":4000}
	var base: Dictionary=BaseStock.ANDROID_VALUES
	check(Definitions.validate(data,source_bytes,"android-armv7",arrival,base).is_empty(),"Android Deep Science stock was rejected")
	check(not Definitions.validate(data,source_bytes,"x86_64",arrival,base).is_empty(),"Android proofs passed as Mac layouts")
	check(not Definitions.validate(data,source_bytes,"armv7",arrival,base).is_empty(),"Android proofs passed as iOS layouts")
	check(not Definitions.validate(data,source_bytes,"android-armv7",arrival,BaseStock.MAC_VALUES).is_empty(),"Android stock accepted the Mac base stock")
	check(not Definitions.validate(data,source_bytes,"android-armv7",{"provenance":arrival.provenance},base).is_empty(),"Android stock accepted a foreign arrival")
	check(not Definitions.validate(data,source_bytes,"android-armv7",{"scope":"rescue_choreography","provenance":{}},base).is_empty(),"Android stock accepted an unproven arrival")
	var shifted: Dictionary=data.duplicate(true);shifted.provenance.all_base_gold.offset+=1
	check(not Definitions.validate(shifted,source_bytes,"android-armv7",arrival,base).is_empty(),"Android stock accepted a shifted proof extent")
	var missing: Dictionary=data.duplicate(true);missing.provenance.erase("required_medal_levels")
	check(not Definitions.validate(missing,source_bytes,"android-armv7",arrival,base).is_empty(),"Android stock accepted an incomplete proof")
	var bindings:=Bindings.new()
	bindings.source_architecture="android-armv7";bindings.early_contracts={"base_station_stock":base};bindings.deep_science_stock=data
	check(Definitions.available(bindings),"Android Deep Science stock was unavailable")
	bindings.source_architecture="armv7"
	check(not Definitions.available(bindings),"iOS bindings offered the Deep Science stock")
	# The Mac path keeps its own base stock.
	var mac_arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":1000000,"bytes":315}}}
	var mac: Dictionary=Definitions.VALUES.duplicate(true);mac.provenance={}
	for key in Definitions.MAC_SPANS:mac.provenance[key]={"offset":1000000+int(Definitions.MAC_SPANS[key][0]),"bytes":int(Definitions.MAC_SPANS[key][1])}
	check(Definitions.validate(mac,source_bytes,"x86_64",mac_arrival,BaseStock.MAC_VALUES).is_empty(),"Mac Deep Science stock was rejected")
	check(not Definitions.validate(mac,source_bytes,"x86_64",mac_arrival,base).is_empty(),"Mac stock accepted the Android base stock")
	check(not Definitions.validate(mac,source_bytes,"android-armv7",mac_arrival,BaseStock.MAC_VALUES).is_empty(),"Mac proofs passed as Android")
	check(not Definitions.validate(mac,source_bytes,"armv7",mac_arrival,BaseStock.MAC_VALUES).is_empty(),"Mac proofs passed as iOS")

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
