extends "res://tests/valkyrie_start_application.gd"
const CombatPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const StationSaveFile=preload("res://src/simulation/station_save_file.gd")
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
	if staged=="turret":await fly_turret()

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
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-55.gof2save"))==OK,"The Kanado result checkpoint could not be kept")
	await capture_free_application("valkyrie-escape-home")

## Valkyrie base talk lends the S'Kanarr; its turret test against sleeping
## pirates at station 102 moves the story on; the base pays 150,000.
func fly_turret() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	# Valkyrie base lies in Herjaza, which has no jumpgate. This earned career
	# never built a Khador Drive, so the test save is given one and its fuel.
	if not seed_khador_drive():return
	if not app.equipment_action("open"):check(false,app.session.error);return
	var owned: Dictionary=app.session.station_owner().snapshot()
	for item in owned.loadout.equipment_ids:
		if catalogue.tables.items[item].properties.get(2)==10:
			if not app.equipment_action("unmount",int(item)):check(false,app.session.error);return
			break
	if not app.equipment_action("mount",85) or not app.equipment_action("close"):check(false,app.session.error);return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(101) or not await dock_application():return
	if not await take_station_talk(55,56):return
	var loaned: Dictionary=app.session.station_owner().snapshot()
	check(loaned.loadout.ship_id==39 and app.session.station_owner().equipment_owner().snapshot().has("stored_ship"),"The Valkyrie talk did not lend the S'Kanarr")
	var credits: int=loaned.contracts.credits
	print("VALKYRIE systems 101=",catalogue.tables.stations[101].system_id," 102=",catalogue.tables.stations[102].system_id)
	check(int(catalogue.tables.stations[101].system_id)==int(catalogue.tables.stations[102].system_id),"The turret test station is in another system")
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await travel_application(102):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE turret cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.get("friendly")]))
	check(actors.size()==9 and actors.slice(0,3).all(func(actor):return actor.hull_catalogue_id==24 and not actor.hostile) and actors.slice(3).all(func(actor):return actor.actor_kind==8 and actor.hostile),"The turret test cast differs from its recipe")
	if failures:return
	await capture_free_application("valkyrie-turret-start")
	var pilot:=CombatPilot.new();var radio_ids:=[];var captured:=false
	for tick in 24000:
		if app.session.flight_owner()._objective.snapshot().campaign_cursor==57:break
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The S'Kanarr was destroyed in the turret test: "+str(state.player.vitals));return
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		var input:=pilot.controls(state,tick,range(3,9),true)
		if not captured and input.distance>0 and input.distance<5000:captured=true;await capture_free_application("valkyrie-turret-fight")
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return
		now_us+=100000
		if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return
		app.present_session()
		if tick%20==0:await process_frame
		if tick%600==0:print("VALKYRIE turret ",tick," target ",input.target," distance ",int(input.distance)," vitals ",state.player.vitals," radio ",radio_ids)
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==57,"The turret test did not move the story on to 57")
	if failures:return
	for tick in 300:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2149 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE turret radio ",radio_ids)
	check(2143 in radio_ids and 2149 in radio_ids,"The turret test radio or its result lines did not play")
	await capture_free_application("valkyrie-turret-result")
	if failures or not await travel_application(101) or not await dock_application():return
	# Pirate bounties are paid on the kill; the base's own payment is measured at the dock.
	credits=app.session.station_owner().snapshot().contracts.credits
	if not await take_station_talk(57,58):return
	var paid: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE turret paid ship=",paid.loadout.ship_id," credits=",paid.contracts.credits," before=",credits)
	check(paid.contracts.credits==credits+150000,"The Valkyrie base did not pay 150,000 for the turret test")
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the turret test failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==58,"Fresh Resume lost the turret test result")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-58.gof2save"))==OK,"The turret result checkpoint could not be kept")

func seed_khador_drive() -> bool:
	var file:=StationSaveFile.new()
	var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	var entries: Array=document.inventory.cargo.entries
	entries.append({"item_id":85,"quantity":1});entries.append({"item_id":122,"quantity":12})
	document.inventory.prices.cargo.append({"item_id":85,"unit_price":0});document.inventory.prices.cargo.append({"item_id":122,"unit_price":0})
	document.inventory.cargo.used=int(document.inventory.cargo.used)+13
	document.inventory.cargo.free_space=int(document.inventory.cargo.capacity)-int(document.inventory.cargo.used)
	document.station.cargo=document.inventory.cargo.duplicate(true)
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station(),"The Khador-seeded save did not load: "+app._save_notice.text)
	return failures==0

## Jump with the Khador Drive the way a player does: K opens the drive map.
func khador_jump(destination: int) -> bool:
	resume_application_focus()
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.physical_keycode=KEY_K;key.keycode=KEY_K;key.pressed=pressed;app._unhandled_input(key)
	check(app.map_panel.visible and app.map_panel.snapshot().drive_mode,"The Khador key did not open the drive map")
	if failures:return false
	if app.map_panel.snapshot().get("void_prompt",false):
		for pressed in [true,false]:
			var key:=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.keycode=KEY_ESCAPE;key.pressed=pressed;app._unhandled_input(key)
	var system_id:=int(catalogue.tables.stations[destination].system_id)
	app.map_panel.show_system(system_id)
	check(app.map_panel.snapshot().system_id==system_id and app.map_panel.snapshot().drive_mode,"The drive map did not open Herjaza: "+app.map_panel.error)
	if failures:return false
	app.map_panel.select_station(destination);app.map_panel.request_confirmation()
	if not app.confirm_map_planet(destination,now_us):check(false,"The drive map refused station "+str(destination)+": "+app.map_panel.error+" "+app.status.text);return false
	var began:=now_us
	app.session.rebase_time(now_us)
	while app.session.status=="running" and now_us-began<15000000:
		if not application_step():return false
	check(app.session.status=="drive_arrival_transition_required","The Khador jump did not complete: "+app.session.status)
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	check(app.session.snapshot().location.station_id==destination,"The Khador jump arrived elsewhere")
	return failures==0 and await release_application_flight()

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
		"turret":return state.campaign_cursor==55
	return super.resumed_contract_valid(state)

## A player crossing hostile Vossk space fights off the ships closing in
## before committing to the gate; the scripted pilot does the same.
func follow_gate_course(system_id: int,station_id: int) -> bool:
	if OS.get_environment("GOF2_VALKYRIE_STAGE")=="home" and not await fight_nearby_hostiles(25000.0):return false
	return await super.follow_gate_course(system_id,station_id)

func fight_nearby_hostiles(radius: float) -> bool:
	var pilot:=CombatPilot.new();var kills:=0
	for tick in 9000:
		var state: Dictionary=app.session.snapshot()
		var threats: Array=state.encounter.combat.actors.filter(func(actor):return actor.get("hostile",false) and actor.vitals.hull>0 and actor.position.distance_to(state.player_pose.origin)<radius).map(func(actor):return actor.actor_id)
		if threats.is_empty():print("VALKYRIE home cleared after ",tick," ticks, ",kills," down, vitals ",state.player.vitals);return true
		if app.session.flight_owner().death_active():check(false,"The escaping K'Suukk was shot down fighting at the gate: "+str(state.player.vitals));return false
		var input:=pilot.controls(state,tick,threats,true)
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
		now_us+=100000
		if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
		app.present_session()
		if tick%20==0:await process_frame
		if tick%300==0:print("VALKYRIE home fight ",tick," threats ",threats.size()," vitals ",state.player.vitals)
	check(false,"The escaping K'Suukk could not shake the Vossk at the gate");return false
