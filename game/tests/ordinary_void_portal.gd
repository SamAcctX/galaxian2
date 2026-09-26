extends SceneTree
## Detached cursor33 source/return portal vectors. The session owns both worlds.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Navigation=preload("res://src/simulation/contract_navigation.gd")
const Source=preload("res://src/simulation/ordinary_void_source.gd")
const Portal=preload("res://src/simulation/void_portal.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var checks:=0
var failures:=0
var library: RefCounted
var bindings: RefCounted
var source: RefCounted
var camera:=Transform3D(Basis.IDENTITY,Vector3(0,0,40000))

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3 and args.size()!=6:check(false,"Expected App Store196 triple and optional old195 control triple");finish();return
	library=Library.new();bindings=Bindings.new();var catalogues:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not catalogues.open(library):
		check(false,library.error+bindings.error+catalogues.error);finish();return
	source=Source.new()
	var availability: Array=Navigation.initial_availability(bindings,catalogues,false)
	check(source.configure_fresh(bindings,catalogues,availability),source.error)
	if not source.snapshot().is_empty():
		verify_source_entry()
		verify_return()
		verify_contact()
		verify_clock_and_fork()
	if args.size()==6:verify_missing_capability(args[3],args[4])
	finish()

func entry(in_void:=false) -> Dictionary:
	var retained: Dictionary=source.snapshot()
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":33,"system_id":-1 if in_void else retained.source_system_id,
		"station_id":-1 if in_void else retained.source_station_id,"current_station_id":-1 if in_void else retained.source_station_id,
		"void_station_id":-1,"return_station_id":retained.source_station_id,
		"mission_kind":-1,"mission_story":false,"mission_completed":true,"mission_failed":false,
		"environment_object":{"resource_id":16994,"position":Vector3(0,0,60000)}}

func fresh(in_void:=false) -> RefCounted:
	var portal:=Portal.new()
	check(portal.configure_ordinary(bindings,entry(in_void),source,library),portal.error)
	return portal

func contact(portal: RefCounted,offset: Vector3,enabled:=true,mining:=false) -> Dictionary:
	return {"player_pose":Transform3D(Basis.IDENTITY,portal.portal_snapshot().position+offset),
		"environment_contact_enabled":enabled,"mining_active":mining}

func random_stream() -> RefCounted:
	var stream:=Random.new();check(stream.seed_from(25),stream.error);return stream

func verify_source_entry() -> void:
	var portal:=fresh();var accepted: Dictionary=portal.portal_snapshot()
	check(accepted.ordinary_mode=="source_entry" and accepted.campaign_cursor==33 and accepted.system_id==18 and accepted.station_id==91 and accepted.mission_kind==-1 and accepted.source_system_id==18 and accepted.source_station_id==91 and accepted.return_system_id==18 and accepted.return_station_id==91 and accepted.slot==3 and accepted.model_id==16994,"Source portal lost the original slot or actual Dima source identity")
	check(portal.snapshot().ordinary_mode=="source_entry" and portal.snapshot().return_station_id==91 and not portal.snapshot().portal_entered,"Source portal advertised an early transition")
	check(not portal.configure(bindings,entry(),library) and portal.portal_snapshot()==accepted,"Story-only admission accepted the ordinary sentinel")
	for change in [{"campaign_cursor":32},{"campaign_cursor":33.0},{"campaign_cursor":34},{"mission_kind":8},{"mission_story":true},{"system_id":6},{"station_id":93},{"current_station_id":93},{"void_station_id":91},{"return_station_id":93},{"return_system_id":6},{"binding_id":"foreign"},{"base_content_id":"foreign"},{"environment_object":{"resource_id":16995,"position":Vector3.ZERO}},{"environment_object":{"resource_id":16994,"position":Vector3(INF,0,0)}}]:
		var bad:=entry();bad.merge(change,true)
		check(not portal.configure_ordinary(bindings,bad,source,library) and portal.portal_snapshot()==accepted,"Rejected source entry replaced retained portal: "+str(change))
	for change in [{"mission_completed":false},{"mission_failed":true}]:
		var same_route:=entry();same_route.merge(change,true)
		var status_portal:=Portal.new()
		check(status_portal.configure_ordinary(bindings,same_route,source,library) and status_portal.portal_snapshot()==accepted and status_portal.observe_contact(contact(status_portal,Vector3.ZERO)) and status_portal.transition_ready(1) and status_portal.portal_snapshot().campaign_cursor==33 and status_portal.portal_snapshot().mission_kind==-1,"An unrelated sentinel status changed ordinary contact or advanced the story")
	check(not portal.configure_ordinary(bindings,entry(),Source.new(),library) and portal.portal_snapshot()==accepted,"Unconfigured native source entered a portal")
	check(not portal.configure_ordinary(bindings,entry(),RefCounted.new(),library) and portal.portal_snapshot()==accepted,"Foreign source object entered a portal")
	var tampered: Dictionary=portal.portal_snapshot();tampered.return_station_id=99
	check(portal.portal_snapshot().return_station_id==91,"Portal snapshot exposed mutable route state")

func verify_return() -> void:
	var portal:=fresh(true);var initial: Dictionary=portal.portal_snapshot()
	check(initial.ordinary_mode=="void_return" and initial.system_id==-1 and initial.station_id==-1 and initial.return_station_id==91 and initial.source_station_id==91 and initial.mission_kind==-1,"Void return lost its actual retained source")
	for change in [{"return_station_id":93},{"return_system_id":6},{"current_station_id":91},{"station_id":91},{"system_id":18},{"mission_story":true},{"mission_kind":8}]:
		var bad:=entry(true);bad.merge(change,true)
		check(not portal.configure_ordinary(bindings,bad,source,library) and portal.portal_snapshot()==initial,"Wrong Void return destination or selected mission replaced the portal: "+str(change))
	var absent:=entry(true);absent.erase("return_station_id")
	check(not portal.configure_ordinary(bindings,absent,source,library) and portal.portal_snapshot()==initial,"Void return invented an absent recorded station")
	var completed_false:=entry(true);completed_false.mission_completed=false
	var completed_portal:=Portal.new()
	check(completed_portal.configure_ordinary(bindings,completed_false,source,library) and completed_portal.portal_snapshot()==initial and completed_portal.observe_contact(contact(completed_portal,Vector3.ZERO)) and completed_portal.transition_ready(1) and completed_portal.portal_snapshot().campaign_cursor==33,"Uncompleted sentinel status blocked or advanced ordinary Void return")
	var changed_source: Dictionary=source.snapshot();changed_source.source_station_id=93
	check(source.restore(changed_source),source.error)
	check(portal.configure_ordinary(bindings,entry(false),source,library) and portal.portal_snapshot().source_station_id==93 and portal.portal_snapshot().ordinary_mode=="source_entry","Rerolled source did not control source-flight identity")
	var old_return:=entry(true);old_return.return_station_id=91
	check(not portal.configure_ordinary(bindings,old_return,source,library),"Return retained stale Dima91 after source changed")
	var actual_return:=entry(true)
	check(portal.configure_ordinary(bindings,actual_return,source,library),portal.error)
	check(portal.portal_snapshot().source_station_id==93 and portal.portal_snapshot().return_station_id==93 and portal.snapshot().return_station_id==93,"Return did not track an actual alternate source station")
	var old_source:=entry(false);old_source.station_id=91;old_source.current_station_id=91;old_source.return_station_id=91
	check(not portal.configure_ordinary(bindings,old_source,source,library),"A previous warning station remained a live source")
	changed_source.source_station_id=91
	check(source.restore(changed_source),source.error)
	var disabled: Dictionary=source.snapshot();disabled.source_system_id=-10;disabled.source_station_id=-10
	check(source.restore(disabled),source.error)
	check(not portal.configure_ordinary(bindings,entry(true),source,library),"Disabled warning source still admitted an ordinary portal")
	check(source.restore(changed_source),source.error)

func verify_contact() -> void:
	for in_void in [false,true]:
		var portal:=fresh(in_void)
		for offset in [Vector3(40000,0,0),Vector3(0,-40000,0),Vector3(30000,30000,0)]:
			check(portal.observe_contact(contact(portal,offset)) and portal.snapshot().contact.is_empty() and not portal.transition_ready(1),"Ordinary portal pulled outside its source cube/sphere")
		check(portal.observe_contact(contact(portal,Vector3(1000,0,0))) and portal.snapshot().contact.pull_distance==152 and not portal.transition_ready(1),"Ordinary pull radius entered at the wrong range")
		check(portal.observe_contact(contact(portal,Vector3.ZERO,false)) and portal.snapshot().contact.is_empty() and not portal.transition_ready(1),"Disabled contact entered the ordinary portal")
		check(portal.observe_contact(contact(portal,Vector3.ZERO,true,true)) and portal.snapshot().contact.is_empty() and not portal.transition_ready(1),"Active mining entered the ordinary portal")
		check(portal.observe_contact(contact(portal,Vector3(999,0,0))) and portal.snapshot().contact.entry_contact and portal.transition_ready(1),"Living ordinary contact failed at the inclusive entry range")
		check(not portal.transition_ready(0) and not portal.transition_ready(-1) and not portal.transition_ready(1.0),"Dead or malformed hull authorized an ordinary transition")
		var once: Dictionary=portal.snapshot()
		check(portal.observe_contact(contact(portal,Vector3(999,0,0))) and portal.snapshot()==once and portal.portal_snapshot().campaign_cursor==33 and portal.portal_snapshot().mission_kind==-1,"Repeated contact manufactured another story or portal state")
		check(not portal.observe_contact({}) and portal.snapshot()==once,"Malformed contact erased an earned ordinary entry")

func verify_clock_and_fork() -> void:
	var portal:=fresh();var stream:=random_stream();var original_random: Dictionary=stream.snapshot()
	var fork: RefCounted=portal.fork_for_frame()
	check(fork.observe_contact(contact(fork,Vector3.ZERO)) and fork.transition_ready(1) and not portal.transition_ready(1),"Discarded contact changed the retained portal")
	for _step in 400:
		if not portal.advance(150,camera,stream):check(false,portal.error);return
	check(portal.portal_snapshot().elapsed_ms==60000 and portal.portal_snapshot().extent==4096 and stream.snapshot()==original_random,"Ordinary clock or RNG changed at the original closing boundary")
	check(portal.advance(1,camera,stream) and portal.observe_contact(contact(portal,Vector3.ZERO)) and not portal.transition_ready(1),"Closing ordinary portal allowed entry")
	for _step in 20:
		if not portal.advance(150,camera,stream):check(false,portal.error);return
	check(portal.portal_snapshot().elapsed_ms==-3000 and portal.portal_snapshot().position==Vector3(-77981,34947,-75738) and portal.snapshot().source_station_id==91,"Relocation lost shared clock or ordinary route identity")
	check(not portal.transition_ready(1),"Relocation manufactured an ordinary entry")

func verify_missing_capability(content: String,pack: String) -> void:
	var older_library:=Library.new();var older_bindings:=Bindings.new()
	if not older_library.open(content) or not older_bindings.open(pack,older_library.manifest):check(false,older_library.error+older_bindings.error);return
	check(not older_bindings.mido_travel.has("void_access"),"Control binding unexpectedly has ordinary Void access")
	var portal:=Portal.new()
	check(not portal.configure_ordinary(older_bindings,entry(),source,older_library) and portal.snapshot().is_empty(),"Earlier binding admitted the cursor33 portal")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func finish() -> void:
	print("Ordinary Void portal: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
