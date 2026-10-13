extends SceneTree
## The early contract Android declarations: values, spans anchored in their
## own functions and the arrival staging by presence (no imported content).
const Definitions=preload("res://src/content/early_contract_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	print("Early contract Android declarations: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var source_bytes:=8000000
	var origin:=4000
	var arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":5,"bytes":24,"anchor":1}}}
	var travel: Dictionary=Travel.ANDROID_VALUES.duplicate(true)
	travel.continuation=Travel.MAC_CONTINUATION.duplicate(true)
	travel.return_visit=Travel.ANDROID_RETURN_VISIT.duplicate(true)
	travel.provenance={}
	var android: Dictionary=Definitions.MAC_VALUES.duplicate(true)
	android.provenance=anchored(Definitions.ANDROID_SPANS,origin)
	check(Definitions.validate(android,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android early contracts were rejected")
	check(not Definitions.validate(android,source_bytes,"x86_64",arrival,travel).is_empty(),"Android proofs passed as Mac layouts")
	check(not Definitions.validate(android,source_bytes,"armv7",arrival,travel).is_empty(),"Android proofs passed as iOS layouts")
	check(not Definitions.validate(android,source_bytes,"android-armv7",{"provenance":arrival.provenance},travel).is_empty(),"Android contracts accepted a foreign arrival")
	check(not Definitions.validate(android,source_bytes,"android-armv7",{"scope":"rescue_choreography","provenance":{}},travel).is_empty(),"Android contracts accepted an unproven arrival")
	var mac_arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":1000000,"bytes":315}}}
	var mac: Dictionary=Definitions.MAC_VALUES.duplicate(true);mac.provenance={}
	for key in Definitions.MAC_SPANS:mac.provenance[key]={"offset":1000000+int(Definitions.MAC_SPANS[key][0]),"bytes":int(Definitions.MAC_SPANS[key][1])}
	check(Definitions.validate(mac,source_bytes,"x86_64",mac_arrival,travel).is_empty(),"Mac early contracts were rejected")
	check(not Definitions.validate(mac,source_bytes,"armv7",mac_arrival,travel).is_empty(),"Mac proofs passed as iOS layouts")
	check(not Definitions.validate(mac,source_bytes,"android-armv7",mac_arrival,travel).is_empty(),"Mac proofs passed as Android")
	var older: Dictionary=Definitions.VALUES.duplicate(true);older.provenance=android.provenance
	check(Definitions.parameters(older) and not Definitions.validate(older,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts accepted the 61-ship terms")
	var accepted: Dictionary=android.duplicate(true)
	accepted.acceptance=Definitions.MAC_ACCEPTANCE.duplicate(true)
	accepted.provenance.merge(anchored(Definitions.ANDROID_ACCEPTANCE_SPANS,origin))
	check(Definitions.validate(accepted,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contract acceptance was rejected")
	var unaccepted: Dictionary=accepted.duplicate(true);unaccepted.erase("acceptance")
	check(not Definitions.validate(unaccepted,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts kept proofs of a missing acceptance")
	var unproven: Dictionary=accepted.duplicate(true)
	for key in Definitions.ANDROID_ACCEPTANCE_SPANS:unproven.provenance.erase(key)
	check(not Definitions.validate(unproven,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android acceptance passed without its proofs")
	# Ported extensions follow the chain, each only with its own proofs.
	var chain: Dictionary=accepted.duplicate(true)
	for row in extensions():
		chain[row[0]]=row[1].duplicate(true)
		chain.provenance.merge(anchored(row[2],origin))
		check(Definitions.validate(chain,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android extension was rejected: "+row[0])
		var missing: Dictionary=chain.duplicate(true)
		for key in row[2]:missing.provenance.erase(key)
		check(not Definitions.validate(missing,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android extension passed without its proofs: "+row[0])
	var shifted: Dictionary=accepted.duplicate(true)
	shifted.provenance.early_selector.offset+=1
	check(not Definitions.validate(shifted,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts accepted a shifted proof extent")
	var incomplete: Dictionary=accepted.duplicate(true)
	incomplete.provenance.erase("accept_fee_debit")
	check(not Definitions.validate(incomplete,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts accepted an incomplete proof")

## [key, values, spans] of each ported extension in chain order.
func extensions() -> Array:
	return []

func anchored(spans: Dictionary,origin: int) -> Dictionary:
	var result:={}
	for key in spans:result[key]={"offset":origin+int(spans[key][0]),"bytes":int(spans[key][1]),"anchor":origin}
	return result

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
