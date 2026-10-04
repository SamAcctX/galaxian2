extends "res://tests/dekato_flight.gd"
## The actual Eanya save stays original202. The reused target flight below is
## explicitly a separate component, not a relocated save or an earned battle.
const Extension=preload("res://src/content/dekato_source_extension.gd")

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size() not in [3,4]:check(false,"Supply original content, bindings and visuals");finish();return
	captures=OS.get_environment("GOF2_CAPTURE_DIR") if args.size()==3 else str(args[3])
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);finish();return
	var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	if not supplement is Array or supplement.size()!=3:check(false,"Supply the independently prepared supplemental source arguments");finish();return
	verify_source(library,bindings,cat,str(args[1]),str(supplement[1]))
	if not failures and OS.get_environment("GOF2_DEKATO_SOURCE_COMPONENT")!="0":
		print("Separate original202 + explicit source component: not the earned Eanya inventory or a completed journey")
		await verify(library,bindings,cat,str(args[2]))
	if vitals!=null:vitals.free()
	if secondaries!=null:secondaries.free()
	if session!=null:session.free();await process_frame
	finish()

func verify_source(library: RefCounted,bindings: RefCounted,cat: RefCounted,base_directory: String,source_directory: String) -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	check(expected.length()==64 and FileAccess.get_sha256(saved)==expected,"The exact earned Eanya source changed before admission")
	var archive:=Archive.new();var file:=SaveFile.new()
	var record:=file.load_document(saved,bindings,cat,library)
	if record.is_empty():check(false,file.error);return
	var station:=archive.restore(bindings,cat,library,record)
	if station==null:check(false,archive.error);return
	# Today's capture adds newer save fields the retained file predates; compare
	# the station's own capture before and after attaching instead.
	var captured: Dictionary=archive.capture(station,bindings)
	var before: Dictionary=station.snapshot();var raw: Dictionary=bindings.mido_travel.duplicate(true)
	var original_id: String=bindings.binding_id
	check(before.campaign_cursor==38 and before.loadout.station_id==20 and before.loadout.system_id==4 and before.mission.station_id==22,"Use the actual retained Eanya20 checkpoint, not a substituted predecessor")
	check(before.contracts.credits==19370 and before.contracts.passengers==3 and before.cargo.entries.is_empty(),"The source lost its earned wallet, passengers or empty hold")
	check(before.player_cache.values.hull==10 and before.player_cache.values.armor==0 and before.player_cache.values.shield==0,"The source ship was repaired or replaced")
	check(before.loadout.slots.any(func(row):return row is Dictionary and row.get("item_id")==42 and row.get("quantity")==12),"The source lost its actual paid EMP42 inventory")
	check(not Rules.available(bindings) and bindings.dekato_source_receipt().is_empty(),"Original202 acquired an implicit source extension")
	check(not PlayerEntry.new().configure(bindings,38,22,true,0) and Frame.OrdinaryFlight.FreeFlight.player_entry(raw,22,0,38).is_empty(),"Original202 ordinary player/cache entry bypassed its pending story")
	check(PlayerEntry.new().configure(bindings,38,20,true,0),"The story boundary closed ordinary Eanya20 entry")
	check(not Bindings.new().attach_dekato_source(source_directory,library.manifest),"An unopened base accepted supplemental declarations")
	check(not bindings.attach_dekato_source(base_directory,library.manifest) and not Rules.available(bindings),"The preceding pack was treated as a new declaration source")
	check(not bindings.attach_dekato_source(source_directory.path_join("absent"),library.manifest) and bindings.mido_travel==raw,"Missing source admission changed the preceding pack")
	var candidate:=Bindings.new()
	if not candidate.open(source_directory,library.manifest):check(false,candidate.error);return
	check(candidate.binding_id!=original_id and Rules.available(candidate),"Use the separate source203, not a restamped original202 pack")
	check(archive.restore(candidate,cat,library,record)==null and file.load_document(saved,candidate,cat,library).is_empty(),"Same-source declarations silently migrated the actual saved career")
	verify_projection(base_directory,source_directory)
	if failures:return
	if not bindings.attach_dekato_source(source_directory,library.manifest):check(false,bindings.error);return
	var proof: Dictionary=bindings.dekato_source_receipt()
	check(proof.binding_id==original_id and proof.source_binding_id==candidate.binding_id and proof.base_content_id==bindings.base_content_id,"The explicit receipt lost either binding identity")
	check(Rules.available(bindings) and Rules.declarations(bindings)==candidate.mido_travel.dekato_convoy,"The supplemental declarations differ from the independently validated source")
	check(bindings.binding_id==original_id and bindings.mido_travel==raw and not raw.has("dekato_convoy"),"Source attachment rewrote the imported payload or save identity")
	check(proof.is_read_only() and Rules.declarations(bindings).is_read_only() and Rules.declarations(bindings).mission.result_events.is_read_only(),"Source declarations expose mutable nested containers")
	var detached:=Rules.declarations(bindings).duplicate(true);detached.mission.station_id=20
	check(Rules.declarations(bindings).mission.station_id==22,"Editing a detached observation changed the accepted source")
	check(not bindings.attach_dekato_source(source_directory,library.manifest) and bindings.dekato_source_receipt()==proof,"A repeated attachment replaced its accepted provenance")
	check(Navigation.destination_supported(bindings,38,before.mission,22),"Explicit same-source admission did not expose its native local arrival")
	check(not PlayerEntry.new().configure(bindings,38,22,true,0),"The supplemental source bypassed the selected player adapter")
	check(not Frame.OrdinaryFlight.FreeFlight.Campaign.supported(bindings.mido_travel,39),"An extension granted unsupported public39")
	check(station.contract_owner().campaign_flight_context(bindings,before.mission).is_empty(),"The Eanya20 career was silently relocated to Dekato22")
	check(archive.capture(station,bindings)==captured and station.snapshot()==before,"Attaching declarations changed the actual earned station owners")
	var restored:=archive.restore(bindings,cat,library,record)
	check(restored!=null and restored.snapshot()==before and file.load_document(saved,bindings,cat,library)==record,"Original202 archive restoration changed after source attachment")
	check(not station.prepare_departure(bindings,cat).is_empty() and station.snapshot()==before,"Actual Eanya departure lost the retained source career")
	check(archive.restore(candidate,cat,library,record)==null,"Explicit supplementation weakened strict cross-binding restore refusal")
	var reopened:=Bindings.new()
	if not reopened.open(base_directory,library.manifest) or not reopened.attach_dekato_source(source_directory,library.manifest) or not reopened.open(base_directory,library.manifest):check(false,reopened.error);return
	check(not Rules.available(reopened) and reopened.dekato_source_receipt().is_empty(),"Reopening the original pack leaked a previous source attachment")
	check(FileAccess.get_sha256(saved)==expected,"The declaration extension overwrote the earned Eanya save")
	print("Actual Eanya20 source unchanged: ",expected,"; explicit declaration receipt ",JSON.stringify(proof))

func verify_projection(base_directory: String,source_directory: String) -> void:
	var old_header: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base_directory.path_join("bindings.json")))
	var old_body: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base_directory.path_join("registrations.json")))
	var header: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_directory.path_join("bindings.json")))
	var body: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_directory.path_join("registrations.json")))
	var previous:=Extension.describe(old_header,old_body);var current:=Extension.describe(header,body)
	check(not Extension.receipt(previous,current).is_empty(),"The exact full-payload Dekato-only projection failed")
	for key in ["base_content_id","source_executable_sha256","architecture","source_executable_bytes","preceding_payload_sha256","reader"]:
		var changed:=current.duplicate(true);changed[key]=0 if key=="source_executable_bytes" else "different"
		check(Extension.receipt(previous,changed).is_empty(),"Source extension ignored changed "+key)
	for key in body:
		if key in ["reader","mido_travel"]:continue
		var changed:=body.duplicate(true)
		changed[key]={"unrelated_delta":true}
		check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"Source projection ignored earlier root "+str(key))
	var changed:=body.duplicate(true);changed.mido_travel.bakka_return.scope="changed"
	check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"The preceding mission was silently changed")
	changed=body.duplicate(true);changed.mido_travel.unreviewed_capability={"enabled":true}
	check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"An unrelated new capability entered through the Dekato delta")
	for key in Rules.SPANS:
		changed=body.duplicate(true);changed.mido_travel.provenance.erase(key)
		check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"An incomplete Dekato source proof was accepted: "+str(key))
	changed=body.duplicate(true);changed.mido_travel.dekato_convoy.mission.station_id=20
	check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"The source extension accepted altered mission declarations")
