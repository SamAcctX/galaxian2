extends SceneTree
## One-time flight hint windows: conditions pick one hint, it opens once,
## and the seen list survives a save round trip (old saves load empty).
const Hints=preload("res://src/simulation/flight_hints.gd")
const Archive=preload("res://src/simulation/opening_station_archive.gd")
var library=preload("res://src/content/library.gd").new()
var bindings=preload("res://src/content/resource_bindings.gd").new()
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb"):check(false,library.error+bindings.error)
	else:
		verify_order_and_once()
		verify_conditions()
		verify_saved()
		verify_text()
	print("Flight hints: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func flight(extra: Dictionary={}) -> Dictionary:
	var state:={"world_elapsed_ms":6000,"campaign_cursor":20,"location":{"station_id":5},"booster":{},"khador":{},"cloak":{},
		"station_autopilot":{"active":true},"progress":{"reputation":{"override":-1,"axes":[0,0]}},"cargo":{"capacity":40,"used":3}}
	state.merge(extra,true)
	return state

func verify_order_and_once() -> void:
	var owner:=Hints.new()
	var state:=flight({"booster":{"available":true},"cloak":{"energy_cost":1}})
	check(owner.next_hint(Hints.flight_facts(flight({"world_elapsed_ms":4000,"booster":{"available":true}}))).is_empty(),"A hint opened before the flight was 5 s old")
	var first:=owner.next_hint(Hints.flight_facts(state))
	check(first.get("id")=="booster" and first.get("text_id")==585,"Booster should open first: %s"%first)
	var second:=owner.next_hint(Hints.flight_facts(state))
	check(second.get("id")=="cloak","Cloak should open next: %s"%second)
	check(owner.next_hint(Hints.flight_facts(state)).is_empty(),"A seen hint opened again")
	check(owner.pending()==["booster","cloak"],"Pending hints: %s"%[owner.pending()])
	owner.banked()
	var saved:=Hints.merge_seen([],["cloak","booster"])
	check(owner.next_hint(Hints.flight_facts(flight({"booster":{"available":true},"progress":{"hints_seen":saved}}))).is_empty(),"A hint saved in the career opened again")

func verify_conditions() -> void:
	var cases:=[
		["booster",{"booster":{"available":true},"campaign_cursor":1},false],
		["khador_drive",{"khador":{"available":true}},true],
		["planet_travel",{"station_autopilot":{"active":false}},true],
		["planet_travel",{"station_autopilot":{"active":false},"contracts":{"active_offer_id":3}},false],
		["planet_travel",{"station_autopilot":{"active":false},"campaign_cursor":9},false],
		["wingmen",{"wingman_actors":{"actors":[{"active":true}]}},true],
		["reputation",{"progress":{"reputation":{"override":-1,"axes":[10,-71]}}},true],
		["reputation",{"progress":{"reputation":{"override":-1,"axes":[70,-70]}}},false],
		["ore_mining",{"mining_session":{"phase":"drilling"}},true],
		["asteroid_classes",{"mining_session":{"phase":"drilling"},"campaign_cursor":3},false],
		["cargo_full",{"cargo":{"capacity":40,"used":40}},true],
		["cargo_full",{"cargo":{"capacity":40,"used":40},"campaign_cursor":6},false],
		["gamma",{"gamma_rate":2.5},true],
		["gamma",{"gamma_rate":2.5,"campaign_cursor":91,"location":{"station_id":110}},false],
		["gamma",{"campaign_cursor":91,"location":{"station_id":110},"radio":{"finished":[true,true,true,true,true]}},true],
		["volatile_goods",{"volatile":true},true],
		["docking",{"campaign_cursor":91,"location":{"station_id":110},"radio":{"finished":[true,true,true,true,false]}},false],
		["docking",{"campaign_cursor":91,"location":{"station_id":110},"radio":{"finished":[true,true,true,true,true]}},true],
	]
	for row in cases:
		var facts:=Hints.flight_facts(flight(row[1]))
		check(Hints.holds(row[0],facts)==row[2],"%s should be %s for %s"%[row[0],row[2],row[1]])
	check(Hints.holds("hacking",Hints.flight_facts(flight(),true)),"Hacking hint did not hold while hacking")

func verify_saved() -> void:
	check(not {}.has("hints_seen") and Hints.flight_facts(flight()).saved==[],"An old save without hints did not read as none seen")
	var progress:={"hints_seen":Hints.merge_seen(["wingmen"],["booster"])}
	var loaded: Variant=JSON.parse_string(JSON.stringify(progress))
	check(loaded is Dictionary and Archive.valid_lifetime("hints_seen",loaded.hints_seen) and loaded.hints_seen==["booster","wingmen"],"Hints did not survive a save round trip: %s"%[loaded])
	check(not Archive.valid_lifetime("hints_seen",["booster","booster"]) and not Archive.valid_lifetime("hints_seen",["unknown"]) and not Archive.valid_lifetime("hints_seen",3),"Invalid hint history was accepted")
	check("hints_seen" in Archive.OPTIONAL_PROGRESS_KEYS and "hints_seen" in Archive.LIFETIME_KEYS,"Hints are not carried with the career")

func verify_text() -> void:
	for row in Hints.HINTS:
		var touch:=Hints.text(library,bindings,int(row.text_id),true)
		var desktop:=Hints.text(library,bindings,int(row.text_id),false)
		check(not touch.is_empty() and not desktop.is_empty() and not "#KEY_" in desktop,"Hint %s has no readable text"%row.id)
	var cloak:=Hints.text(library,bindings,582,false)
	check(cloak.contains("(C)") and cloak.contains("(E)"),"Desktop cloak hint lacks its key labels: %s"%cloak.left(80))
	print("Desktop cloak hint: "+cloak.left(70).replace("\n"," "))

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr(message)
