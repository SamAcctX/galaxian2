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
	# The supported travel context: contract navigation through free flight.
	travel.arrival_briefing=Travel.MAC_ARRIVAL_BRIEFING.duplicate(true)
	travel.contract_navigation=Travel.CONTRACT_NAVIGATION.duplicate(true)
	for row in [["contract_completion",Travel.ContractStory.MAC_VALUES],["convoy_capture",Travel.ConvoyCapture.MAC_VALUES],
		["convoy_ship",Travel.ConvoyShip.VALUES],["convoy_lifecycle",Travel.ConvoyLifecycle.VALUES],["convoy_effects",Travel.ConvoyEffects.VALUES],
		["alioth_arrival",Travel.Alioth.MAC_VALUES],["convoy_transit",Travel.Transit.VALUES],["alioth_attack",Travel.Attack.MAC_VALUES],
		["alioth_lifecycle",Travel.AliothLife.VALUES],["alioth_flight",Travel.AliothFlight.VALUES],["alioth_return",Travel.AliothReturn.MAC_VALUES],
		["free_navigation",Travel.FreeNavigation.VALUES],["free_population",Travel.FreePopulation.VALUES],["free_traffic",Travel.FreeTraffic.VALUES],
		["free_lifecycle",Travel.FreeLifecycle.VALUES],["free_flight",Travel.FreeFlight.VALUES]]:
		travel[row[0]]=row[1].duplicate(true)
	check(Travel.parameters(travel) and Travel.navigation_available(travel,13),"The Android travel context was refused")
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
	# Android stock progress is the library's (cursor + 25); the Mac adds 10.
	if chain.has("station_generation"):
		var mac_stock: Dictionary=chain.duplicate(true);mac_stock.station_generation=Definitions.Stock.VALUES.duplicate(true)
		check(Definitions.parameters(mac_stock) and not Definitions.validate(mac_stock,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts accepted the Mac stock progress")
		var mac_chain: Dictionary=mac.duplicate(true)
		mac_chain.acceptance=Definitions.MAC_ACCEPTANCE.duplicate(true);anchor_mac(mac_chain,Definitions.MAC_ACCEPTANCE_SPANS)
		for row in mac_extensions():
			mac_chain[row[0]]=row[1].duplicate(true);anchor_mac(mac_chain,row[2])
			if row[0]=="station_generation":break
		check(Definitions.validate(mac_chain,source_bytes,"x86_64",mac_arrival,travel).is_empty(),"Mac contracts through station generation were rejected")
		mac_chain.station_generation=Definitions.Stock.ANDROID_VALUES.duplicate(true)
		check(not Definitions.validate(mac_chain,source_bytes,"x86_64",mac_arrival,travel).is_empty(),"Mac contracts accepted the Android stock progress")
	# Each capability keeps its travel context: travel cut before it is refused.
	var keys:=["contract_navigation","contract_completion","convoy_capture","convoy_ship","convoy_lifecycle","convoy_effects","alioth_arrival","convoy_transit","alioth_attack","alioth_lifecycle","alioth_flight","alioth_return","free_navigation","free_population","free_traffic","free_lifecycle","free_flight"]
	for row in [["encounter_construction","contract_navigation"],["base_navigation","alioth_arrival"],["ordinary_generation","free_flight"]]:
		if not chain.has(row[0]):continue
		var cut: Dictionary=travel.duplicate(true)
		for key in keys.slice(keys.find(row[1])):cut.erase(key)
		check(Travel.parameters(cut) and not Definitions.validate(chain,source_bytes,"android-armv7",arrival,cut).is_empty(),"Android contracts kept "+row[0]+" without "+row[1])
	var shifted: Dictionary=accepted.duplicate(true)
	shifted.provenance.early_selector.offset+=1
	check(not Definitions.validate(shifted,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts accepted a shifted proof extent")
	var incomplete: Dictionary=accepted.duplicate(true)
	incomplete.provenance.erase("accept_fee_debit")
	check(not Definitions.validate(incomplete,source_bytes,"android-armv7",arrival,travel).is_empty(),"Android contracts accepted an incomplete proof")

## [key, values, spans] of each ported extension in chain order.
func extensions() -> Array:
	return [["generation",Definitions.Contacts.VALUES,Definitions.Contacts.ANDROID_SPANS],
		["delivery_results",Definitions.Delivery.VALUES,Definitions.Delivery.ANDROID_SPANS],
		["encounter_construction",Definitions.Encounters.VALUES,Definitions.Encounters.ANDROID_SPANS],
		["ship_combat",Definitions.ShipCombat.VALUES,Definitions.ShipCombat.ANDROID_SPANS],
		["ship_lifecycle",Definitions.ShipLifecycle.VALUES,Definitions.ShipLifecycle.ANDROID_SPANS],
		["flight_results",Definitions.FlightResults.VALUES,Definitions.FlightResults.ANDROID_SPANS],
		["junk_lifecycle",Definitions.Junk.VALUES,Definitions.Junk.ANDROID_SPANS],
		["world_initialization",Definitions.World.VALUES,Definitions.World.ANDROID_SPANS],
		["station_lounges",Definitions.Lounges.VALUES,Definitions.Lounges.ANDROID_SPANS],
		["station_generation",Definitions.Stock.ANDROID_VALUES,Definitions.Stock.ANDROID_SPANS]]

## [key, values, spans] of the Mac 1.0.7 chain.
func mac_extensions() -> Array:
	return [["generation",Definitions.Contacts.VALUES,Definitions.Contacts.MAC_SPANS],
		["delivery_results",Definitions.Delivery.VALUES,Definitions.Delivery.MAC_SPANS],
		["encounter_construction",Definitions.Encounters.VALUES,Definitions.Encounters.MAC_SPANS],
		["ship_combat",Definitions.ShipCombat.VALUES,Definitions.ShipCombat.MAC_SPANS],
		["ship_lifecycle",Definitions.ShipLifecycle.VALUES,Definitions.ShipLifecycle.MAC_SPANS],
		["flight_results",Definitions.FlightResults.VALUES,Definitions.FlightResults.MAC_SPANS],
		["junk_lifecycle",Definitions.Junk.VALUES,Definitions.Junk.MAC_SPANS],
		["world_initialization",Definitions.World.VALUES,Definitions.World.MAC_SPANS],
		["station_lounges",Definitions.Lounges.VALUES,Definitions.Lounges.MAC_SPANS],
		["station_generation",Definitions.Stock.VALUES,Definitions.Stock.MAC_SPANS]]

func anchor_mac(data: Dictionary,spans: Dictionary) -> void:
	for key in spans:data.provenance[key]={"offset":1000000+int(spans[key][0]),"bytes":int(spans[key][1])}

func anchored(spans: Dictionary,origin: int) -> Dictionary:
	var result:={}
	for key in spans:result[key]={"offset":origin+int(spans[key][0]),"bytes":int(spans[key][1]),"anchor":origin}
	return result

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
