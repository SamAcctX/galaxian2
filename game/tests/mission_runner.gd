extends SceneTree
## Focused admission/fork checks with detached observations, not pilot flight.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Context=preload("res://src/simulation/mission_context.gd")
const Runner=preload("res://src/simulation/mission_runner.gd")
const Inventory=preload("res://tests/fixtures/bakka_equipment.gd")
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	print("Mission runner components: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Supply the original202 content arguments and explicit203 supplement");return
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	if not supplement is Array or supplement.size()!=3:check(false,"Supply the explicit same-source supplement");return
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library) or not bindings.attach_dekato_source(str(supplement[1]),library.manifest):check(false,library.error+bindings.error+cat.error);return
	var entry:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,"station_id":22,"system_id":4,"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":22,"system_id":4,"ship_id":0,"equipment_ids":[]}
	for primary in [0,22,2]:
		seed.equipment_ids=[primary,42,57,91,64]
		var loadout:=Inventory.equipped_seed(bindings,cat,seed)
		var context:=Context.new()
		if not context.admit(bindings,cat,entry,loadout):check(false,context.error);return
		var admitted:=context.recipe()
		check(context.matches_loadout(loadout) and context.ship_id()==0 and context.has_feature("station"),"The representative equipped entry lost its admitted flight capability")
		var planets: RefCounted=load("res://src/simulation/opening_planet_layout.gd").new()
		var layout: Dictionary=planets.for_lounge(bindings,cat,entry.station_id,entry.campaign_cursor,"high",context)
		check(not layout.is_empty(),"Admitted mission could not construct its ordinary scenery: "+planets.error)
		check(layout==planets.for_lounge(bindings,cat,entry.station_id,entry.campaign_cursor),"Mission admission changed the catalogue's planet layout")
		check(planets.for_lounge(bindings,cat,20,entry.campaign_cursor,"high",context).is_empty(),"Mission admission granted another location")
		check(planets.for_lounge(bindings,cat,entry.station_id,entry.campaign_cursor,"high",Context.new()).is_empty(),"Empty mission context granted scenery admission")
		var exposed:=context.recipe();exposed.next_cursor=-1;exposed.world.station=false
		check(context.recipe()==admitted,"A caller changed the admitted recipe through its snapshot")
		check(not context.admit(bindings,cat,entry,loadout) and context.recipe()==admitted,"A mission entry was admitted twice")
		for key in ["binding_id","station_id","slots"]:
			var changed:=loadout.duplicate(true)
			changed[key]="foreign" if key=="binding_id" else 20 if key=="station_id" else []
			var refused:=Context.new()
			check(not refused.admit(bindings,cat,entry,changed) and refused.recipe().is_empty() and not context.matches_loadout(changed),"A changed source, station or equipped inventory reused mission admission: "+key)
		if primary==2:
			verify_runner(context)
			verify_poll_cadence(context)
	verify_pilot_delta()

func observations(retired: Array) -> Array:
	var result:=[]
	for id in 7:result.append({"actor_mode":4 if id in retired else 0,"vitals":{"hull":0 if id in retired else 100}})
	return result

func verify_runner(context: RefCounted) -> void:
	var parent:=Runner.new()
	if not parent.configure(context):check(false,parent.error);return
	check(not parent.acknowledge(),"Unopened result acknowledged successfully")
	var untouched:=parent.snapshot()
	# Same-frame competing outcomes, strict success clock, and failure while
	# radio/time block success. The full flight test supplies real retirements.
	for sample in [[[],0,true,false,0],[range(2,7),5000,false,true,0],[range(2,7),5001,true,true,0],[range(2,7),5001,false,false,0],[range(2,7),5001,false,true,1],[[0,2,3,4,5,6],5001,false,true,1],[[0,1],0,true,false,2],[range(7),5001,false,true,1],[range(7),5001,true,true,2]]:
		var branch: RefCounted=parent.fork();var actors:=observations(sample[0]);var before:=actors.duplicate(true)
		check(branch.sample_clock(15000,sample[1]),branch.error)
		var selected: Dictionary=branch.poll(actors,sample[2],sample[3])
		check(selected.get("mode")==sample[4],"Result timing, radio gate or competing outcome changed: "+str(sample))
		if sample[4]!=0:
			check(branch.poll(observations([]),false,true)==selected,"An opened outcome changed when the next frame's observations changed")
		if sample[4]==1:
			check(branch.acknowledge(),branch.error)
			var acknowledged: Dictionary=branch.snapshot()
			check(acknowledged.retired and acknowledged.mode==0 and not branch.acknowledge() and branch.snapshot()==acknowledged,"Acknowledgement repeated or failed to retire the result")
			check(branch.poll(actors,false,true)==acknowledged,"A retired result reopened")
		check(actors==before and parent.snapshot()==untouched,"A result branch changed its parent or actor observations")
	var dead_hulls:=observations([])
	for actor in dead_hulls:actor.vitals.hull=0
	check(parent.sample_clock(15000,5001),parent.error)
	check(parent.poll(dead_hulls,false,true).mode==0,"Hull zero counted as retirement")
	var frozen:=parent.snapshot()
	check(not parent.sample_clock(14999,0) and parent.snapshot()==frozen,"A backward clock partially changed the runner")
	check(parent.poll(observations(range(7)),false,true,false)==frozen,"A dead player opened a new mission result")

func verify_poll_cadence(context: RefCounted) -> void:
	var parent:=Runner.new()
	if not parent.configure(context):check(false,parent.error);return
	var untouched:=parent.snapshot()
	# A cinematic can prevent success, but cannot bank an overdue check.
	# Radio and unavailable success leave the independent cadence running.
	for allowed in [false,true]:
		for radio_active in [false,true]:
			for elapsed in [5000,5001]:
				var branch: RefCounted=parent.fork()
				check(branch.sample_clock(20000,elapsed),branch.error)
				var result: Dictionary=branch.poll(observations([]),radio_active,allowed)
				check(result.mode==0 and result.clock_ms==(0 if elapsed>5000 else elapsed),"A gated or unsuccessful result check lost its independent cadence")
	var blocked: RefCounted=parent.fork()
	check(blocked.sample_clock(30000,5100),blocked.error)
	var waiting: Dictionary=blocked.poll(observations(range(2,7)),false,false)
	check(waiting.mode==0 and waiting.clock_ms==0,"Cinematic time accumulated an overdue success check")
	check(blocked.sample_clock(30100,int(waiting.clock_ms)+100),blocked.error)
	check(blocked.poll(observations(range(2,7)),false,true).mode==0,"Release opened an overdue result before the next interval")
	check(blocked.sample_clock(35000,5000),blocked.error)
	check(blocked.poll(observations(range(2,7)),false,true).mode==0,"Success lost the strict five-second boundary")
	check(blocked.sample_clock(35001,5001),blocked.error)
	check(blocked.poll(observations(range(2,7)),false,true).mode==1,"Released success did not open on the next eligible check")
	check(parent.snapshot()==untouched,"A gated check changed its parent runner")

func verify_pilot_delta() -> void:
	# Identical physical target velocity sampled at different intervals must
	# produce the same aim. This catches a hidden 100ms assumption at 144Hz.
	var state:={"player_pose":Transform3D.IDENTITY,"encounter":{"combat":{"actors":[{"actor_id":0,"position":Vector3(500,0,10000),"vitals":{"hull":100}}]},"primaries":{"guns":[{"projectiles":{"weapon":{"speed_units_per_millisecond":5.0}}}]}}}
	var expected:=Vector2.ZERO
	for delta in [100.0,1000.0/144.0,41.667]:
		var pilot:=Pilot.new();var earlier:=state.duplicate(true)
		earlier.encounter.combat.actors[0].position-=Vector3(delta,0,0)
		pilot.controls(earlier,0,[0],false,delta)
		var current:=pilot.controls(state,1,[0],false,delta)
		if delta==100.0:expected=current.commands
		else:check(current.commands.is_equal_approx(expected),"The same moving target changed aim solely with the sample interval")
	var default_pilot:=Pilot.new();var explicit_pilot:=Pilot.new()
	default_pilot.controls(state,0,[0]);explicit_pilot.controls(state,0,[0],false,100.0)
	var later:=state.duplicate(true);later.encounter.combat.actors[0].position+=Vector3(100,0,0)
	check(default_pilot.controls(later,1,[0])==explicit_pilot.controls(later,1,[0],false,100.0),"Existing callers lost the default 100ms moving-target lead")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
