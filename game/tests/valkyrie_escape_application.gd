extends "res://tests/valkyrie_start_application.gd"
## Valkyrie opening chain from the earned call: Kanado talk, the Vossk loan
## ship to B'akrram and the K'Suukk handover, then the escape flights.

func verify_free_application() -> void:
	var staged:=OS.get_environment("GOF2_VALKYRIE_STAGE")
	if staged.is_empty():
		await super.verify_free_application()
		if failures:return
		if not await story_route(74) or not await take_station_talk(47,48):return
		var loaned: Dictionary=app.session.station_owner().snapshot()
		check(loaned.loadout.ship_id==9 and app.session.station_owner().equipment_owner().snapshot().has("stored_ship"),"The Kanado talk did not lend the Vossk ship")
		print("VALKYRIE loan ship=",loaned.loadout.ship_id," items=",loaned.loadout.equipment_ids)
		await capture_free_application("valkyrie-loan-ship")
		if failures or not await story_route(58) or not await take_station_talk(48,49):return
		var prototype: Dictionary=app.session.station_owner().snapshot()
		print("VALKYRIE prototype ship=",prototype.loadout.ship_id," items=",prototype.loadout.equipment_ids)
		check(prototype.loadout.ship_id==41 and prototype.loadout.equipment_ids.count(177)==3,"B'akrram did not hand over the K'Suukk with three scatterguns")
		check(app.save_station(false),"Saving the escape start failed: "+app._save_notice.text)
		if failures:return
		var checkpoint:=OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-49.gof2save")
		check(DirAccess.copy_absolute(app.station_save_path(),checkpoint)==OK,"The escape checkpoint could not be kept")
		check(app.load_station(),"Fresh Resume at B'akrram failed: "+app._save_notice.text)
		if failures:return
		check(app.session.station_owner().snapshot().loadout==prototype.loadout,"Fresh Resume lost the K'Suukk")
		await capture_free_application("valkyrie-prototype-resumed")
		return
	if staged=="escape":await fly_escape()
	if staged=="home":await fly_home()

## 49-52: the K'Suukk flees with a Vossk escort that turns on the player at
## Makke S'ik, through the gate to S'inokk and away, then home to Kanado.
func fly_escape() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==49,"The escape checkpoint is not at cursor 49")
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not check_story_cast([9,9,9,9,9],false):return
	if not await wait_story_cursor(50,"valkyrie-escort-launch"):return
	if not await travel_application(62) or not check_story_cast([9,9,9,9],false):return
	var frame: RefCounted=app.session.flight_owner()
	var started:=now_us
	while not frame._encounter.story_hostility_applied() and now_us-started<90000000:
		if not application_step():return
		frame=app.session.flight_owner()
		if int(now_us/1000000)%2==0:await process_frame
	var actors: Array=frame._encounter.combat_snapshot().actors
	check(frame._encounter.story_hostility_applied() and actors.all(func(actor):return actor.hostile),"The Makke S'ik escort never turned on the player")
	check(frame._encounter.combat_owner().current_reputation().axes[0]==100,"The betrayal did not cost the Vossk standing")
	await dismiss_medal();await capture_free_application("valkyrie-betrayal")
	if failures or not await wait_story_cursor(51,""):return
	if not await follow_gate_course(5,25) or not await release_application_flight() or not check_story_cast([13,9,9,9,9,9],true):return
	if not await wait_story_cursor(52,"valkyrie-sinokk"):return
	var other:=-1
	for id in catalogue.tables.stations.size():
		if int(catalogue.tables.stations[id].system_id)==5 and id!=25:other=id;break
	if not await travel_application(other) or not check_story_cast([13,13,9,9,9,9,9,9],true):return
	if not await wait_story_cursor(54,"valkyrie-escape-away"):return
	if not await dock_application():return
	check(app.save_station(false),"Saving after the escape failed: "+app._save_notice.text)
	if failures:return
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-54.gof2save"))==OK,"The escape result checkpoint could not be kept")
	check(app.load_station(),"Fresh Resume after the escape failed: "+app._save_notice.text)
	if failures:return
	var resumed: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE escaped cursor=",resumed.campaign_cursor," station=",resumed.loadout.station_id," standing=",resumed.contracts.reputation)
	check(resumed.campaign_cursor==54 and resumed.contracts.reputation.axes[0]==100,"Fresh Resume lost the escape or the Vossk standing")
	await capture_free_application("valkyrie-escaped-resumed")

## 54: home to Kanado through hostile Vossk space, the talk, the reward and
## the owned ship handed back.
func fly_home() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var credits: int=app.session.station_owner().snapshot().contracts.credits
	if not await story_route(74) or not await take_station_talk(54,55):return
	var home: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE home ship=",home.loadout.ship_id," credits=",home.contracts.credits," before=",credits)
	check(home.contracts.credits==credits+200000,"Kanado did not pay the 200,000 escape reward")
	check(not app.session.station_owner().equipment_owner().snapshot().has("stored_ship"),"Kanado did not hand back the owned ship")
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Kanado failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==55,"Fresh Resume lost the escape result")
	await capture_free_application("valkyrie-escape-home")

## Acknowledge a medal notice the way a player would, so it doesn't cover the view.
func dismiss_medal() -> void:
	if not app.medal_notice.visible:return
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true
	app._unhandled_input(enter);await process_frame

func check_story_cast(hulls: Array,hostile: bool) -> bool:
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile]))
	check(actors.map(func(actor):return int(actor.hull_catalogue_id))==hulls and actors.all(func(actor):return actor.actor_kind==1 and actor.hostile==hostile),"The story cast differs from its Vossk recipe")
	return failures==0

## Hold in space until the story silently moves on, like the original's 10 s rule.
func wait_story_cursor(cursor: int,label: String) -> bool:
	var started:=now_us;var radio_seen:=false
	while app.session.flight_owner()._objective.snapshot().campaign_cursor!=cursor and now_us-started<30000000:
		if not application_step():return false
		if app.session.flight_owner().death_active():check(false,"The escape pilot died waiting for cursor "+str(cursor));return false
		if int(now_us/1000000)%2==0:await process_frame
		await dismiss_medal()
		var radio: RefCounted=app.session.flight_owner()._radio
		if not radio_seen and not label.is_empty() and radio!=null and radio.snapshot().get("visible",false) and radio.snapshot().has("scripted_events"):
			radio_seen=true;print("VALKYRIE radio ",radio.snapshot().get("text_id"));await capture_free_application(label+"-radio")
	var seconds:=float(now_us-started)/1000000.0
	print("VALKYRIE cursor ",cursor," after ",seconds," s")
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==cursor,"The story did not move on to "+str(cursor)+" in flight")
	if failures:return false
	if not label.is_empty():await capture_free_application(label)
	return true

## Fly the earned route to a station, docking at each gate like a player.
func story_route(destination: int) -> bool:
	var original: Dictionary=app.session.station_owner().snapshot()
	var navigation:=Navigation.new()
	if not navigation.configure(definitions,catalogue,original.contracts.lounges.system_availability):check(false,navigation.error);return false
	var system_id:=int(catalogue.tables.stations[destination].system_id)
	var route: Array=navigation.route(original.loadout.system_id,system_id)
	print("VALKYRIE route to ",destination,": ",route)
	if route.is_empty():check(false,"The career has no route to station "+str(destination));return false
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	var gate_field:=int(definitions.mido_travel.free_navigation.gate_station_field)
	if route.size()>1:
		var first_gate:=int(catalogue.tables.systems[route[0]].fields[gate_field])
		if original.loadout.station_id!=first_gate and not await travel_application(first_gate):return false
		for next_system in route.slice(1):
			var gate:=int(catalogue.tables.systems[next_system].fields[gate_field])
			if not await follow_gate_course(next_system,gate) or not await release_application_flight():return false
			if next_system==system_id and gate==destination:return await dock_application()
			if next_system!=route[-1]:
				if not await dock_application():return false
				if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
				if not await release_application_flight():return false
	if app.session.snapshot().location.station_id!=destination and not await travel_application(destination):return false
	return await dock_application()

func resumed_contract_valid(state: Dictionary) -> bool:
	match OS.get_environment("GOF2_VALKYRIE_STAGE"):
		"escape":return state.campaign_cursor==49
		"home":return state.campaign_cursor==54
	return super.resumed_contract_valid(state)
