extends SceneTree
## Source count and stream vectors, detached from any earned campaign or world.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Population=preload("res://src/simulation/traffic_population.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var checks:=0
var failures:=0
var bindings: RefCounted

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size() not in [3,6]:
		check(false,"Expected reader196 triple and optional195 absence control")
	else:
		var library:=Library.new();bindings=Bindings.new()
		if not library.open(args[0]) or not bindings.open(args[1],library.manifest):check(false,library.error+bindings.error)
		else:verify_counts()
		if args.size()==6:verify_absence(args[3],args[4])
	print("Ordinary Void population: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func context(rank: int) -> Dictionary:
	return {"campaign_cursor":33,"selected_system_id":-1,"selected_station_id":-1,
		"retained_system_id":-1,"retained_station_id":-1,"selected_mission_kind":-1,
		"selected_mission_story":false,"location_match":true,"rank":rank}

func verify_counts() -> void:
	# Independent Java48 draw vectors include all four first/second pairs. The
	# second state must remain unconsumed where the source keeps its initial2.
	var seeds:=[4097,4096,1,0]
	var first:=[0,0,1,1]
	var second:=[0,1,0,1]
	var first_states:=[27529194370055,27554409273972,205723924636679,205749139540596]
	var second_states:=[40675982651654,246425122192239,28280696119558,234029835660143]
	var vectors:=[
		[0,[2,2,2,2],[false,false,false,false]],
		[3,[2,2,2,2],[false,false,false,false]],
		[4,[2,2,1,2],[false,false,true,true]],
		[5,[2,2,1,2],[false,false,true,true]],
		[6,[2,3,2,3],[true,true,true,true]],
		[8,[3,4,3,4],[true,true,true,true]]]
	for vector in vectors:
		for index in seeds.size():
			var random:=Random.new();check(random.seed_from(seeds[index]),random.error)
			var incoming: Dictionary=random.snapshot()
			var owner:=Population.new()
			check(owner.configure_void(bindings,context(vector[0])),owner.error)
			if failures:return
			var result:=owner.generate(incoming)
			check(not result.is_empty(),owner.error)
			if result.is_empty():return
			check(result.actor_count==vector[1][index] and result.groups=={"void":vector[1][index]},"Void rank/count branch changed: "+str([vector[0],seeds[index],result]))
			check(result.first_count_draw==first[index] and result.has("second_count_draw")==vector[2][index],"Void count consumed the wrong number of draws")
			if vector[2][index]:check(result.second_count_draw==second[index],"Void second draw changed")
			var expected_state: int=second_states[index] if vector[2][index] else first_states[index]
			check(result.before_actors_random_state=={"state":expected_state} and result.incoming_random_state==incoming and random.snapshot()==incoming,"Void count reseeded, reordered or consumed its caller's stream")
			check(result.campaign_cursor==33 and result.system_id==-1 and result.station_id==-1 and result.mission_kind==-1 and result.base_content_id==bindings.base_content_id and result.binding_id==bindings.binding_id,"Void count changed the source context or identity")
			check(not result.has("unix_seconds") and not result.has("actors") and not result.has("reward_credits"),"Count selection constructed actors, reseeded by time or granted gameplay progress")
			check(owner.generate(incoming).is_empty() and owner.snapshot()==result,"One configured population generated twice")
			var observed:=owner.snapshot();observed.groups.void=999
			check(owner.snapshot()==result,"Population observation aliases its native owner")
	verify_refusals()

func verify_refusals() -> void:
	var random:=Random.new();check(random.seed_from(1),random.error)
	var stream: Dictionary=random.snapshot()
	var owner:=Population.new()
	check(owner.configure_void(bindings,context(4)),owner.error)
	check(owner.generate({"state":-1}).is_empty() and owner.snapshot().is_empty(),"Invalid caller stream committed a population")
	check(not owner.generate(stream).is_empty(),"Invalid-stream refusal prevented the valid retry")
	for change in [{"rank":-1},{"rank":4.5},{"rank":bindings.opening_handoff.rank_thresholds.size()},
		{"campaign_cursor":32},{"campaign_cursor":33.0},{"selected_station_id":91},{"retained_system_id":18},
		{"selected_mission_kind":8},{"selected_mission_story":true},{"location_match":false}]:
		var invalid:=context(4);invalid.merge(change,true)
		check(not owner.configure_void(bindings,invalid) and owner.snapshot().is_empty() and owner.generate(stream).is_empty(),"Invalid Void selection retained a generatable population: "+str(change))
	var missing:=context(4);missing.erase("rank")
	check(not owner.configure_void(bindings,missing),"Void count invented a career rank")
	check(random.snapshot()==stream,"Refused population mutated caller randomness")

func verify_absence(content: String,pack: String) -> void:
	var library:=Library.new();var previous:=Bindings.new()
	if not library.open(content) or not previous.open(pack,library.manifest):check(false,library.error+previous.error);return
	check(not previous.mido_travel.has("void_crystals"),"Absence control unexpectedly has the new capability")
	var owner:=Population.new()
	check(not owner.configure_void(previous,context(4)) and owner.snapshot().is_empty(),"Earlier content admitted the unimplemented Void count branch")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1;push_error(message)
