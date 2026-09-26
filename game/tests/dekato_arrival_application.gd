extends "res://tests/post_probe_application.gd"
## Continue the exact earned Eanya checkpoint through real map input and travel.
## The explicitly attached declarations never replace its original202 identity.
const DekatoArrival=preload("res://src/content/dekato_convoy_definitions.gd")
const LaunchPlayer=preload("res://src/simulation/opening_player_state.gd")
const LaunchEntry=preload("res://src/content/player_entry_definitions.gd")
const LaunchCache=preload("res://src/simulation/flight_player_cache.gd")
const SOURCE_SHA="b86c1dac98a7e68ce768bca8ee33e4500bb2cf5d81985d8bd4caff6e295c7c70"
const SOURCE_BINDING="3c3d6c0153e6b2444ab0f3edeefcfa99b33385a1e3b2aa59668c28331c302639"

func open_application_content(args: PackedStringArray) -> bool:
	if not super.open_application_content(args):return false
	var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	if not supplement is Array or supplement.size()!=3:check(false,"Supply the independently validated same-source declaration arguments");return false
	if not definitions.attach_dekato_source(str(supplement[1]),source.manifest):check(false,definitions.error);return false
	return true

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var source_station: RefCounted=app.session.station_owner()
	var original: Dictionary=source_station.snapshot()
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and definitions.binding_id==SOURCE_BINDING and not definitions.mido_travel.has("dekato_convoy"),"Use the exact original202 Eanya source without rewriting its bindings")
	check(original.campaign_cursor==38 and original.loadout.station_id==20 and original.loadout.system_id==4 and original.mission=={"kind":4,"station_id":22,"reward":0,"bonus":0,"source_parameter":0},"Resume the actual Eanya20 career, not a relocated component")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty(),"Eanya lost its actual wallet, passengers or empty hold")
	check(original.player_cache.values.hull==10 and original.player_cache.values.armor==0 and original.player_cache.values.shield==0,"The retained Eanya ship was repaired")
	check(original.loadout.slots.any(func(row):return row is Dictionary and row.item_id==42 and row.quantity==12),"The retained Eanya ammunition changed")
	if failures:return
	_world_clock_base=1789104800
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated arrival output")
	if failures:return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	if not app.save_station():check(false,app._save_notice.text);return
	var safe_hash:=FileAccess.get_sha256(app.station_save_path())
	await capture_free_application("earned202-dekato-eanya20-source")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	verify_launch_reset(original,app.session.snapshot())
	check(source_station.snapshot()==original,"The normal departure changed its retained damaged station cache")
	if failures:return
	if not await release_application_flight():return
	var departing: RefCounted=app.session.flight_owner()
	var before: Dictionary=departing.snapshot()
	check(PostProbeNavigation.destination_supported(definitions,38,original.mission,22) and departing.local_travel_owner().supports_destination(22),"The explicitly admitted route is missing from native local travel")
	if failures or not app.open_map(now_us):check(false,app.status.text);return
	var held: Dictionary=app.session.snapshot()
	check(app.map_panel.is_visible_in_tree() and app.map_panel.snapshot().rows.any(func(row):return row.station_id==22 and row.supported),"The visible map cannot select the source-admitted convoy")
	app.map_panel.select_station(22);app.map_panel.request_confirmation()
	check(app.map_panel.snapshot().confirmation_visible and app.session.snapshot()==held,"Map selection moved the player before confirmation")
	app.map_panel.back()
	check(not app.map_panel.snapshot().confirmation_visible and app.session.snapshot()==held,"Cancelled travel changed the actual Eanya career")
	app.map_panel.request_confirmation()
	await capture_free_application("earned202-dekato-map-confirmation")
	if failures or not app.confirm_map_planet(22,now_us):check(false,app.status.text);return
	for tick in 2000:
		if app.session.status=="local_arrival_transition_required":break
		if not application_step():return
		if app.session.flight_owner().death_active():check(false,"The retained Eanya ship died during actual local travel");return
		if tick%100==0:await process_frame
	check(app.session.status=="local_arrival_transition_required","Actual guidance did not complete planet acquisition and launch")
	if failures:return
	var completed: RefCounted=app.session.flight_owner()
	var flown: Dictionary=completed.snapshot()
	var transit: Dictionary=completed.prepare_local_arrival()
	check(transit.get("station_id")==22 and transit.get("from_station_id")==20 and transit.get("campaign_cursor")==38,"The actual local transit lost its source, destination or story")
	check(flown.world_elapsed_ms>before.world_elapsed_ms and flown.player_pose!=before.player_pose and flown.player.vitals.hull>0,"Travel skipped native movement or surviving-player checks")
	if failures or not app.enter_local_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var arrival: Dictionary=app.session.snapshot()
	var entry: Dictionary=app.session.flight_owner()._entry
	check(arrival.get("dekato_source_receipt")==definitions.dekato_source_receipt() and not arrival.dekato_source_receipt.is_empty(),"The actual incoming world lost its explicit supplemental source provenance")
	check(arrival.campaign_cursor==38 and arrival.location.station_id==22 and arrival.location.system_id==4 and arrival.actors.size()==7 and entry.departure.has("dekato_context"),"The actual arrival omitted the selected convoy world")
	check(arrival.binding_id==SOURCE_BINDING and arrival.arrival_from_station_id==20 and entry.departure.arrival_environment.station_id==22,"The new world lost original identity or actual incoming provenance")
	check(arrival.cargo==flown.cargo and arrival.mission==original.mission and arrival.progress==flown.progress,"Arrival changed current cargo, progress or pending story")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","completed_side_missions","delivery_statistics","travel_statistics"]:
		check(arrival.contracts[key]==flown.contracts[key],"Arrival changed independent career: "+key)
	check(arrival.player.vitals.hull==flown.player.vitals.hull and arrival.player.vitals.armor==flown.player.vitals.armor and arrival.player.vitals.shield==int(flown.player.vitals.shield),"Arrival granted player repairs")
	check(completed.snapshot()==flown and departing.snapshot()==before,"Arrival changed retained previous flight owners")
	check(not app.session.can_control() and app.session.flight_owner().prepare_station().is_empty(),"Arrival skipped its entry or completed an unplayed story")
	verify_arrival_guards(source_station.equipment_owner(),app.session.flight_owner().equipment_owner(),app.session.flight_owner().contract_owner(),transit,original.mission)
	await capture_free_application("earned202-dekato-incoming")
	if failures:return
	if not await acknowledge_story_lines(DekatoArrival.declarations(definitions).mission.briefing_events):return
	check(app.session.can_control() and app.session.snapshot().campaign_cursor==38,"The original briefing did not release the unchanged pending story")
	await capture_free_application("earned202-dekato-controlled")
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and FileAccess.get_sha256(app.station_save_path())==safe_hash,"Arrival overwrote its viable Eanya checkpoint")
	if not failures:print("Actual original202 Eanya20 -> map/cancel/confirm -> acquisition/launch -> Dekato22 incoming/briefing; no rebinding, purchases, grants or battle completion")

func verify_launch_reset(original: Dictionary,launched: Dictionary) -> void:
	var rules: Dictionary=definitions.opening_actors.player_initialization
	var capacities:=LaunchPlayer.resolve_capacities(catalogue.tables.items,original.loadout.equipment_ids,rules)
	var hull:=LaunchPlayer.resolve_ship_hull(catalogue.tables.ships[original.loadout.ship_id].fields[int(rules.repair.base_hull_field)],rules.repair.initial_upgrades,rules.repair)
	var entry:=LaunchEntry.new()
	if not entry.configure(definitions,38,20,false,int(original.loadout.ship_id)):check(false,entry.error);return
	var reset:=entry.player_cache(rules.flight_cache,original.loadout,hull,capacities,true)
	check(entry.is_departure and not entry.restores_local and reset.values.values().all(func(value):return value==int(definitions.mido_travel.player_entry.cache_reset)),"Station launch lost the declared cleared-cache policy")
	var expected:=LaunchCache.restore_values(rules.flight_cache,hull,capacities,reset.values)
	for key in ["hull","armor","shield"]:check(launched.player.vitals[key]==expected[key],"Normal launch differs from its source pool reset: "+key)
	check(launched.contracts.credits==original.contracts.credits and launched.equipment.loadout==original.loadout,"Normal pool reset replaced the wallet or equipped ship")
	print("Source-bound station launch: retained cache ",original.player_cache.values," -> declared reset ",reset.values," -> player pools ",launched.player.vitals)

func verify_arrival_guards(origin: RefCounted,destination: RefCounted,career: RefCounted,transit: Dictionary,mission: Dictionary) -> void:
	var original: Dictionary=career.snapshot()
	var prepared: RefCounted=career.fork()
	if not prepared.rebase_station(origin,definitions):check(false,prepared.error);return
	var before: Dictionary=prepared.snapshot()
	var plain:=Bindings.new()
	if not plain.open(str(OS.get_cmdline_user_args()[1]),source.manifest):check(false,plain.error);return
	var refused: RefCounted=prepared.fork()
	check(not refused.rebase_dekato_arrival(plain,destination,transit,mission) and refused.snapshot()==before,"An unextended career bypassed the authored arrival boundary")
	refused=prepared.fork()
	check(not refused.rebase_station(destination,definitions) and refused.snapshot()==before,"Generic station inventory admitted pending38/22")
	for key in transit:
		var changed:=transit.duplicate(true)
		changed[key]=float(transit[key]) if transit[key] is int else "wrong-source"
		refused=prepared.fork()
		check(not refused.rebase_dekato_arrival(definitions,destination,changed,mission) and refused.snapshot()==before,"Invalid transit type or identity committed the career: "+key)
	var changed:=transit.duplicate(true);changed.extra=true
	refused=prepared.fork()
	check(not refused.rebase_dekato_arrival(definitions,destination,changed,mission) and refused.snapshot()==before,"Extra transit fields were accepted")
	refused=prepared.fork()
	check(refused.rebase_dekato_arrival(definitions,destination,transit,mission) and refused.snapshot()==original,"The exact native transit did not restore the same retained arrival career")
	check(not refused.rebase_dekato_arrival(definitions,destination,transit,mission) and refused.snapshot()==original,"Replaying the same arrival changed the career")
	check(career.snapshot()==original and prepared.snapshot()==before,"Arrival validation mutated retained owners")
