extends SceneTree
## The local journey's Android declarations: values, spans anchored in their
## own functions and the arrival staging by presence (no imported content).
const Definitions=preload("res://src/content/mido_travel_definitions.gd")
const Station=preload("res://src/content/station_entry_definitions.gd")
const Training=preload("res://src/content/combat_training_definitions.gd")
const FirstReturn=preload("res://src/content/station_return_definitions.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	print("Mido travel Android declarations: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var source_bytes:=8000000
	var origin:=4000
	var arrival:={"scope":"rescue_choreography","provenance":{"actor":{"offset":5,"bytes":24,"anchor":1}}}
	var station: Dictionary=Station.ANDROID_VALUES.duplicate(true);station.provenance={}
	var training: Dictionary=Training.MAC_VALUES.duplicate(true);training.provenance={}
	var android: Dictionary=Definitions.ANDROID_VALUES.duplicate(true)
	android.continuation=Definitions.MAC_CONTINUATION.duplicate(true)
	android.return_visit=Definitions.ANDROID_RETURN_VISIT.duplicate(true)
	android.provenance=anchored(Definitions.ANDROID_SPANS,origin)
	check(Definitions.validate(android,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android local travel was rejected")
	check(not Definitions.validate(android,source_bytes,"x86_64",arrival,station,training).is_empty(),"Android proofs passed as Mac layouts")
	check(not Definitions.validate(android,source_bytes,"android-armv7",{"provenance":arrival.provenance},station,training).is_empty(),"Android travel accepted a foreign arrival")
	check(not Definitions.validate(android,source_bytes,"android-armv7",{"scope":"rescue_choreography","provenance":{}},station,training).is_empty(),"Android travel accepted an unproven arrival")
	var full: Dictionary=android.duplicate(true)
	full.arrival_briefing=Definitions.MAC_ARRIVAL_BRIEFING.duplicate(true)
	full.contract_navigation=Definitions.CONTRACT_NAVIGATION.duplicate(true)
	full.provenance.merge(anchored(Definitions.ANDROID_ARRIVAL_BRIEFING_SPANS,origin))
	full.provenance.merge(anchored(Definitions.ANDROID_NAVIGATION_SPANS,origin))
	check(Definitions.validate(full,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android briefing and contract navigation were rejected")
	for key in ["arrival_briefing","contract_navigation"]:
		var partial: Dictionary=full.duplicate(true);partial.erase(key)
		check(not Definitions.validate(partial,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel kept proofs of a missing capability: "+key)
	# Ported extensions follow the chain, each only with its own proofs.
	var chain: Dictionary=full.duplicate(true)
	for row in extensions():
		chain[row[0]]=row[1].duplicate(true)
		chain.provenance.merge(anchored(row[2],origin))
		check(Definitions.validate(chain,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android extension was rejected: "+row[0])
		var unproven: Dictionary=chain.duplicate(true)
		for key in row[2]:unproven.provenance.erase(key)
		check(not Definitions.validate(unproven,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android extension passed without its proofs: "+row[0])
	# Android shopping keeps system 25's maximum price; the Mac marks it up.
	if chain.has("ordinary_shopping"):
		var mac_shop: Dictionary=chain.duplicate(true)
		mac_shop.travel=Definitions.MAC_VALUES.travel.duplicate(true);mac_shop.return_visit=Definitions.MAC_RETURN_VISIT.duplicate(true)
		mac_shop.ordinary_shopping=Definitions.Shopping.VALUES.duplicate(true)
		if mac_shop.has("kappa_return"):mac_shop.kappa_return=Definitions.KappaReturn.MAC_VALUES.duplicate(true)
		if mac_shop.has("tractor_recovery"):mac_shop.tractor_recovery=Definitions.TractorRecovery.VALUES.duplicate(true)
		if mac_shop.has("void_probe"):mac_shop.void_probe=Definitions.VoidProbe.VALUES.duplicate(true)
		check(Definitions.parameters(mac_shop),"Mac shopping values were refused")
		mac_shop.ordinary_shopping=Definitions.Shopping.ANDROID_VALUES.duplicate(true)
		check(not Definitions.parameters(mac_shop),"Mac travel accepted the Android shopping values")
		var android_shop: Dictionary=chain.duplicate(true)
		android_shop.ordinary_shopping=Definitions.Shopping.VALUES.duplicate(true)
		check(not Definitions.validate(android_shop,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted the Mac shopping markup")
	# Android ends the second Kappa conversation with the tractor-beam vendor lines.
	if chain.has("kappa_return"):
		var mac_return: Dictionary=chain.duplicate(true)
		mac_return.kappa_return=Definitions.KappaReturn.MAC_VALUES.duplicate(true)
		check(not Definitions.validate(mac_return,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted the Mac Kappa return")
	# Android's tractor acquisition window is Globals::w / 16 (the Mac: / 18).
	if chain.has("tractor_recovery"):
		var mac_tractor: Dictionary=chain.duplicate(true)
		mac_tractor.tractor_recovery=Definitions.TractorRecovery.VALUES.duplicate(true)
		check(not Definitions.validate(mac_tractor,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted the Mac tractor window")
	# Android's station-lock windows are Globals::w / 6 and / 16 (the Mac: / 8 and / 18).
	if chain.has("void_probe"):
		var mac_probe: Dictionary=chain.duplicate(true)
		mac_probe.void_probe=Definitions.VoidProbe.VALUES.duplicate(true)
		check(not Definitions.validate(mac_probe,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted the Mac station-lock windows")
	var shifted: Dictionary=full.duplicate(true)
	shifted.provenance.story_dispatch.offset+=1
	check(not Definitions.validate(shifted,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted a shifted proof extent")
	var incomplete: Dictionary=full.duplicate(true)
	incomplete.provenance.erase("yrdal_briefing_briefing_start")
	check(not Definitions.validate(incomplete,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted an incomplete proof")
	# The library's own values: the planet window and the contract gate.
	var mac_window: Dictionary=android.duplicate(true)
	mac_window.travel.target_window_divisor=18
	check(not Definitions.validate(mac_window,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Android travel accepted the Mac planet window")
	var mac_gate: Dictionary=android.duplicate(true)
	mac_gate.return_visit=Definitions.MAC_RETURN_VISIT.duplicate(true)
	check(not Definitions.parameters(mac_gate),"Android travel accepted the Mac contract gate")
	var mac: Dictionary=Definitions.MAC_VALUES.duplicate(true)
	mac.continuation=Definitions.MAC_CONTINUATION.duplicate(true);mac.return_visit=Definitions.MAC_RETURN_VISIT.duplicate(true)
	mac.provenance=android.provenance
	check(Definitions.parameters(mac) and not Definitions.validate(mac,source_bytes,"android-armv7",arrival,station,training).is_empty(),"Mac values passed as Android proofs")
	check(int(Definitions.station_return_overrides(12,true,true).contract_gate.additional_completions)==1 and int(Definitions.station_return_overrides(12,true).contract_gate.additional_completions)==4,"Station return lost the library's contract gate")
	var returned: Dictionary=FirstReturn.MAC_VALUES.duplicate(true);returned.provenance={}
	returned.merge(Definitions.station_return_overrides(12,true,true),true)
	check(Definitions.station_return_parameters(returned),"The Android Kernstal return was refused")
	returned.contract_gate.additional_completions=2
	check(not Definitions.station_return_parameters(returned),"A foreign contract gate passed the Kernstal return")

## [key, values, spans] of each ported extension in chain order.
func extensions() -> Array:
	return [["contract_completion",Definitions.ContractStory.MAC_VALUES,Definitions.ContractStory.ANDROID_SPANS],
		["convoy_capture",Definitions.ConvoyCapture.MAC_VALUES,Definitions.ConvoyCapture.ANDROID_SPANS],
		["convoy_ship",Definitions.ConvoyShip.VALUES,Definitions.ConvoyShip.ANDROID_SPANS],
		["convoy_lifecycle",Definitions.ConvoyLifecycle.VALUES,Definitions.ConvoyLifecycle.ANDROID_SPANS],
		["convoy_effects",Definitions.ConvoyEffects.VALUES,Definitions.ConvoyEffects.ANDROID_SPANS],
		["alioth_arrival",Definitions.Alioth.MAC_VALUES,Definitions.Alioth.ANDROID_SPANS],
		["convoy_transit",Definitions.Transit.VALUES,Definitions.Transit.ANDROID_SPANS],
		["alioth_attack",Definitions.Attack.MAC_VALUES,Definitions.Attack.ANDROID_SPANS],
		["alioth_lifecycle",Definitions.AliothLife.VALUES,Definitions.AliothLife.ANDROID_SPANS],
		["alioth_flight",Definitions.AliothFlight.VALUES,Definitions.AliothFlight.ANDROID_SPANS],
		["alioth_return",Definitions.AliothReturn.MAC_VALUES,Definitions.AliothReturn.ANDROID_SPANS],
		["free_navigation",Definitions.FreeNavigation.VALUES,Definitions.FreeNavigation.ANDROID_SPANS],
		["free_population",Definitions.FreePopulation.VALUES,Definitions.FreePopulation.ANDROID_SPANS],
		["free_traffic",Definitions.FreeTraffic.VALUES,Definitions.FreeTraffic.ANDROID_SPANS],
		["free_lifecycle",Definitions.FreeLifecycle.VALUES,Definitions.FreeLifecycle.ANDROID_SPANS],
		["free_flight",Definitions.FreeFlight.VALUES,Definitions.FreeFlight.ANDROID_SPANS],
		["free_arrival",Definitions.FreeArrival.VALUES,Definitions.FreeArrival.ANDROID_SPANS],
		["gate_environment",Definitions.GateEnvironment.VALUES,Definitions.GateEnvironment.ANDROID_SPANS],
		["local_arrival_environment",Definitions.LocalArrivalEnvironment.VALUES,Definitions.LocalArrivalEnvironment.ANDROID_SPANS],
		["gate_transit",Definitions.GateTransit.VALUES,Definitions.GateTransit.ANDROID_SPANS],
		["ordinary_worlds",Definitions.Worlds.VALUES,Definitions.Worlds.ANDROID_SPANS],
		["gate_arrival",Definitions.GateArrival.VALUES,Definitions.GateArrival.ANDROID_SPANS],
		["ordinary_shopping",Definitions.Shopping.ANDROID_VALUES,Definitions.Shopping.ANDROID_SPANS],
		["ordinary_fitting",Definitions.Fitting.MAC_VALUES,Definitions.Fitting.ANDROID_SPANS],
		["ordinary_contracts",Definitions.OrdinaryContracts.VALUES,Definitions.OrdinaryContracts.ANDROID_SPANS],
		["suttnar_visit",Definitions.SuttnarVisit.MAC_VALUES,Definitions.SuttnarVisit.ANDROID_SPANS],
		["kappa_preparation",Definitions.KappaPreparation.MAC_VALUES,Definitions.KappaPreparation.ANDROID_SPANS],
		["emp_bombs",Definitions.EMPBombs.VALUES,Definitions.EMPBombs.ANDROID_SPANS],
		["kappa_rescue",Definitions.KappaRescue.MAC_VALUES,Definitions.KappaRescue.ANDROID_SPANS],
		["kappa_fighters",Definitions.KappaFighters.VALUES,Definitions.KappaFighters.ANDROID_SPANS],
		["kappa_lifecycle",Definitions.KappaLife.VALUES,Definitions.KappaLife.ANDROID_SPANS],
		["secondary_ownership",Definitions.Secondary.VALUES,Definitions.Secondary.ANDROID_SPANS],
		["kappa_return",Definitions.KappaReturn.ANDROID_VALUES,Definitions.KappaReturn.ANDROID_SPANS],
		["kappa_outcome",Definitions.KappaOutcome.MAC_VALUES,Definitions.KappaOutcome.ANDROID_SPANS],
		["kappa_departure",Definitions.KappaDeparture.MAC_VALUES,Definitions.KappaDeparture.ANDROID_SPANS],
		["sahi_visit",Definitions.SahiVisit.MAC_VALUES,Definitions.SahiVisit.ANDROID_SPANS],
		["sahi_encounter",Definitions.SahiEncounter.MAC_VALUES,Definitions.SahiEncounter.ANDROID_SPANS],
		["sahi_stage",Definitions.SahiStage.VALUES,Definitions.SahiStage.ANDROID_SPANS],
		["tractor_recovery",Definitions.TractorRecovery.ANDROID_VALUES,Definitions.TractorRecovery.ANDROID_SPANS],
		["void_portal",Definitions.VoidPortal.VALUES,Definitions.VoidPortal.ANDROID_SPANS],
		["post_sahi",Definitions.PostSahi.VALUES,Definitions.PostSahi.ANDROID_SPANS],
		["thynome_expedition",Definitions.Thynome.VALUES,Definitions.Thynome.ANDROID_SPANS],
		["void_probe",Definitions.VoidProbe.ANDROID_VALUES,Definitions.VoidProbe.ANDROID_SPANS],
		["dima_return",Definitions.DimaReturn.VALUES,Definitions.DimaReturn.ANDROID_SPANS],
		["post_probe_visits",Definitions.PostProbe.VALUES,Definitions.PostProbe.ANDROID_SPANS],
		["void_access",Definitions.VoidAccess.VALUES,Definitions.VoidAccess.ANDROID_SPANS],
		["vossk_traffic",Definitions.Vossk.VALUES,Definitions.Vossk.ANDROID_SPANS]]

func anchored(spans: Dictionary,origin: int) -> Dictionary:
	var result:={}
	for key in spans:result[key]={"offset":origin+int(spans[key][0]),"bytes":int(spans[key][1]),"anchor":origin}
	return result

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
