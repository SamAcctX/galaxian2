extends SceneTree
## Synthetic observations prove predicates, never an earned combat result.
const Definitions=preload("res://src/content/dekato_convoy_definitions.gd")
const Objective=preload("res://src/simulation/dekato_convoy_objective.gd")
const Retirement=preload("res://src/simulation/actor_retirement_condition.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_pack(args)
	elif not args.is_empty():check(false,"Supply either no pack or its three paths")
	print("Dekato convoy: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	for source in [Definitions.VALUES,Definitions.MAC_VALUES]:
		var objective:=Objective.new()
		var before: Dictionary=source.duplicate(true)
		check(objective.configure(source),objective.error)
		for mask in range(128):
			var actors:=[]
			var convoy:=0
			var escorts:=0
			for id in range(7):
				var retired: bool=(mask&(1<<id))!=0
				actors.append({"actor_mode":4 if retired else 1,"actor_kind":2 if id<2 else 3,"vitals":{"hull":0}})
				if retired:
					if id<2:convoy+=1
					else:escorts+=1
			var status:=objective.observe(actors)
			check(status=={"kind":18,"failure_kind":7,"defeated":escorts,"required":5,
				"convoy_destroyed":convoy,"convoy_count":2,"satisfied":escorts==5,"failed":convoy==2},"Original all-range/prefix retirement changed")
			var retained:=actors.duplicate(true)
			for id in range(7):
				for mode in range(6):
					var changed:=actors.duplicate(true)
					changed[id].actor_mode=mode
					changed[id].actor_kind=8 if id<2 else 0
					var result:=objective.observe(changed)
					var delta:=int(mode==4)-int((mask&(1<<id))!=0)
					check(result.satisfied==(escorts+(delta if id>=2 else 0)==5) and result.failed==(convoy+(delta if id<2 else 0)==2),"Hull, faction or tumbling substituted for retired mode4")
			check(actors==retained,"Observation changed a native input")
		check(source==before,"Objective modified source singleton declarations")
		for invalid in [[],[{}],null,{},[{}, {}, {}, {}, {}, {}, {}]]:
			check(objective.observe(invalid).is_empty(),"Invalid/incomplete cast became a combat result")
		var bad: Dictionary=source.duplicate(true)
		bad.objectives.failure.end_actor=1
		check(not objective.configure(bad) and objective.observe([]).is_empty(),"A rejected source retained stale objective state")
		check(not bad.has("reward_credits") and not bad.has("completed"),"Declarations acquired result authority")
	check(Retirement.range_status([],0,0,4).is_empty(),"An empty cast was reported as a victory")
	check(Retirement.range_status([{"actor_mode":4}],-1,1,4).is_empty(),"Negative actor indexing was accepted")
	check(Retirement.range_status([{"actor_mode":true}],0,1,4).is_empty(),"A Boolean became an actor mode")
	check(Retirement.range_status([{"actor_mode":6}],0,1,4).is_empty(),"An unsupported mode was accepted")

func verify_pack(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest):check(false,library.error+bindings.error);return
	check(Travel.parameters(bindings.mido_travel),"The content adapter rejected the source-bound travel payload")
	var mission:={"kind":4,"station_id":22,"reward":0,"bonus":0,"source_parameter":0}
	check(not Navigation.destination_supported(bindings,38,mission,22),"Partial Dekato declarations admitted the unimplemented encounter")
	if bindings.mido_travel.has("dekato_convoy"):
		check(Definitions.available(bindings),"Verified Dekato declarations were unavailable")
		var objective:=Objective.new()
		check(objective.configure(bindings.mido_travel.dekato_convoy),objective.error)
		var data: Dictionary=bindings.mido_travel.duplicate(true)
		data.erase("bakka_return")
		check(not Travel.parameters(data),"Dekato survived removal of its prerequisite")
		data=bindings.mido_travel.duplicate(true)
		var previous: Dictionary=data.dekato_convoy.duplicate(true)
		data.dekato_convoy=Definitions.MAC_VALUES if Definitions.Equal.equal_value(previous,Definitions.VALUES) else Definitions.VALUES
		check(not Definitions.Equal.equal_value(previous,data.dekato_convoy),"Edition rejection test failed to change its source payload")
		check(not Travel.parameters(data),"Dekato accepted a cross-edition prerequisite")
	else:check(not Definitions.available(bindings),"Earlier bindings fabricated Dekato support")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
