extends "res://tests/valkyrie_start_application.gd"
const CombatPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const EmpSteering=preload("res://tests/fixtures/expedition_flight_pilot.gd")
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
	if staged=="blueprint":await fly_blueprint()
	if staged=="convoy":await fly_convoys()
	if staged=="call":await fly_call()
	if staged=="outpost":await fly_outpost()
	if staged=="distraction":await fly_distraction()
	if staged=="delivery":await fly_delivery()
	if staged=="trot":await fly_trot()
	if staged=="teres":await fly_teres(false)
	if staged=="teres-lost":await fly_teres(true)
	if staged=="escape78":await fly_valkyrie_escape()
	if staged=="supernova":await fly_supernova_start()
	if staged=="supernova89":await fly_supernova_blast()
	if staged=="supernova91":await fly_supernova_rescue()

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
	# The player switches the auto turret off and on from the action menu.
	for enabled in [false,true]:
		if not app.open_flight_menu(false):check(false,"The action menu did not open: "+app.status.text);return
		await process_frame
		app.choose_flight_menu("auto_turret");await process_frame
		var turret: Dictionary=app.session.flight_owner().turret_state()
		var notices: Array=app.session.flight_owner().snapshot().get("flight_notices",{}).get("pending",[])
		print("VALKYRIE auto turret enabled=",turret.get("auto_enabled")," notices=",notices.map(func(row):return row.get("text")))
		check(turret.get("auto_enabled",true)==enabled and notices.any(func(row):return row.get("kind")==("auto_turret_on" if enabled else "auto_turret_off")),"The auto turret toggle did not switch or show its notice")
		if failures:return
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

func seed_khador_drive() -> bool:return seed_cargo([[85,1],[122,12]])

## Test shortcut: put goods the career could buy elsewhere into the hold.
func seed_cargo(rows: Array,credits:=0) -> bool:
	var file:=StationSaveFile.new()
	var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	var entries: Array=document.inventory.cargo.entries
	for row in rows:
		entries.append({"item_id":int(row[0]),"quantity":int(row[1])})
		document.inventory.prices.cargo.append({"item_id":int(row[0]),"unit_price":0})
		document.inventory.cargo.used=int(document.inventory.cargo.used)+int(row[1])
	document.inventory.cargo.free_space=int(document.inventory.cargo.capacity)-int(document.inventory.cargo.used)
	document.station.cargo=document.inventory.cargo.duplicate(true)
	document.career.credits=int(document.career.credits)+credits
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station(),"The seeded save did not load: "+app._save_notice.text)
	return failures==0

## 58: the Valkyrie hands over the item-179 blueprint with part of its material
## already supplied; the talk opens only once ten are built and in the hold.
func fly_blueprint() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var state: Dictionary=app.session.station_owner().snapshot()
	check(state.campaign_cursor==58 and state.loadout.station_id==101,"The blueprint checkpoint is not docked at the Valkyrie at cursor 58")
	var project: Array=state.contracts.blueprints.entries.filter(func(row):return row.item_id==179)
	check(not project.is_empty() and project[0].available and int(project[0].station_id)==101,"Mission 58 did not hand over the item-179 blueprint at the Valkyrie")
	if failures:return
	var materials: Array=Array(catalogue.tables.items[179].arrays[0])
	print("VALKYRIE blueprint 179 materials=",materials," needs=",Array(catalogue.tables.items[179].arrays[1])," remaining=",project[0].remaining," capacity=",state.cargo.capacity," used=",state.cargo.used)
	check(int(project[0].remaining[materials.find(127)])==int(catalogue.tables.items[179].arrays[1][materials.find(127)])-5,"The Valkyrie did not pre-supply five of material 127")
	check(not app.session.campaign_story_ready() and not app.session.snapshot().dialogue.visible,"The base talk opened before the goods were built")
	if failures:return
	var seeds:=[]
	for index in materials.size():
		if int(project[0].remaining[index])>0:seeds.append([int(materials[index]),int(project[0].remaining[index])])
	if not seed_cargo(seeds):return
	if not app.equipment_action("open"):check(false,app.session.error);return
	for row in seeds:
		if not app.equipment_action("supply_blueprint",179,row[0],row[1]):check(false,"Supplying material "+str(row[0])+" failed: "+app.session.error);return
	app.equipment_panel.select_tab("cargo");await capture_free_application("valkyrie-blueprint-built")
	if not app.equipment_action("close"):check(false,app.session.error);return
	var built: Dictionary=app.session.station_owner().snapshot()
	var goods: Array=built.cargo.entries.filter(func(row):return row.item_id==179)
	print("VALKYRIE blueprint built=",goods)
	check(not goods.is_empty() and int(goods[0].quantity)>=10,"The blueprint did not build ten of item 179")
	if failures or not await take_station_talk(58,59):return
	var locked: Dictionary=app.session.station_owner().snapshot()
	check(not locked.contracts.blueprints.entries.filter(func(row):return row.item_id==179)[0].available,"Mission 59 did not take the item-179 blueprint back")
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the blueprint failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==59,"Fresh Resume lost the blueprint result")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-59.gof2save"))==OK,"The blueprint checkpoint could not be kept")

## 59-60: the Liberator field test hunts a convoy at stations 56, 45 and 22;
## the base then pays 50,000 plus 50,000 per ship a Liberator destroyed.
func fly_convoys() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==59,"The convoy checkpoint is not at cursor 59")
	var known: Array=app.session.station_owner().snapshot().contracts.lounges.system_availability
	if failures or not seed_cargo([[122,5]]):return
	# The ten Liberators built in 58 ride in the hold; the refit mounts them.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	# This career still flies its starter ship; a player would trade up first.
	var refitted:=false
	var yards:=[]
	for station in catalogue.tables.stations.size():
		var system:=int(catalogue.tables.stations[station].system_id)
		if system<known.size() and known[system] and system not in [4,9,11,14,22,23,24,25,26] and not yards.any(func(id):return int(catalogue.tables.stations[id].system_id)==system):yards.append(station)
	print("VALKYRIE yard candidates ",yards)
	for yard in yards.slice(0,6):
		if not await khador_jump(yard) or not await dock_application():return
		if not app.equipment_action("open"):check(false,app.session.error);return
		var ships: Array=app.session.station_owner().snapshot().equipment.market_ships
		if not app.equipment_action("close"):check(false,app.session.error);return
		print("VALKYRIE yard ",yard," ships ",ships.size())
		if not ships.is_empty():
			if not await outfit_for_combat():return
			refitted=true;break
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight():return
	check(refitted,"No shipyard found for the convoy refit")
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var radio_ids:=[]
	for station in [56,45,22]:
		if not await khador_jump(station):return
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		print("VALKYRIE convoy ",station," cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.population_group,actor.hostile]))
		check(actors.size()==6 and actors[0].population_group=="freighter" and actors.all(func(actor):return not actor.hostile),"The convoy at "+str(station)+" differs from its recipe")
		if failures or not await hunt_convoy(station,radio_ids):return
	var progress: Dictionary=app.session.flight_owner()._objective._contracts.snapshot().progress
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==60,"The third convoy did not finish the field test")
	for tick in 300:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2179 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE convoy radio ",radio_ids," progress ",progress)
	check([2174,2175,2176,2177,2178,2179].all(func(id):return id in radio_ids),"The convoy radio lines did not all play")
	if failures or not await khador_jump(101) or not await dock_application():return
	var docked: Dictionary=app.session.station_owner().snapshot()
	var kills:=int(docked.contracts.progress.get("story_counter",0))
	if not await take_station_talk(60,61):return
	var paid: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE field test kills=",kills," paid=",paid.contracts.credits-docked.contracts.credits)
	check(paid.contracts.credits-docked.contracts.credits==50000*(kills+1),"The field test did not pay 50,000 per Liberator kill plus 50,000")
	check(kills>0,"No escort died to a Liberator during the field test")
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the field test failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==61,"Fresh Resume lost the field test result")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-61.gof2save"))==OK,"The field test checkpoint could not be kept")

## 61-62: ten seconds out of the Valkyrie the call comes in over the radio,
## then the base sends the player to Kothar.
func fly_call() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==61,"The call checkpoint is not at cursor 61")
	if failures or not seed_cargo([[122,5]]):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	check(app.session.flight_owner()._encounter.combat_snapshot().actors.is_empty(),"The call built story ships")
	if failures or not await wait_story_cursor(62,"valkyrie-call"):return
	var radio_ids:=[]
	for tick in 3000:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2197 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE call radio ",radio_ids)
	check(range(2190,2198).all(func(id):return id in radio_ids),"The call's lines did not all play")
	# Kothar has no gate route; the player jumps there with the Khador drive.
	if failures or not await khador_jump(100) or not await dock_application() or not await take_station_talk(62,63):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the call failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==63,"Fresh Resume lost the Kothar talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-63.gof2save"))==OK,"The Kothar checkpoint could not be kept")

## Buy the toughest hull that leaves money for guns, refit the old gear and
## fill the gun slots with the best affordable primary weapon.
func outfit_for_combat() -> bool:
	# An old passenger job blocks changing ships; the player discards it.
	if int(app.session.station_owner().snapshot().contracts.passengers)>0:
		if not app.open_missions(now_us) or not app.discard_mission():check(false,"The passenger job could not be discarded: "+app.status.text);return false
		app.close_missions(now_us)
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var quote: Dictionary=app.session.station_owner().snapshot()
	var budget:=int(quote.contracts.credits)+int(quote.loadout.ship_instance.unit_price)-120000
	var secondaries:=2 if OS.get_environment("GOF2_VALKYRIE_STAGE").begins_with("teres") else 1
	var offers: Array=quote.equipment.market_ships.filter(func(row):return int(row.unit_price)<=budget and catalogue.tables.ships[row.ship_id].stats.equipment_slots>=3 and catalogue.tables.ships[row.ship_id].stats.primary_slots>=2 and catalogue.tables.ships[row.ship_id].stats.secondary_slots>=secondaries)
	offers.sort_custom(func(a,b):return catalogue.tables.ships[a.ship_id].stats.armor>catalogue.tables.ships[b.ship_id].stats.armor)
	print("VALKYRIE shipyard all ",quote.equipment.market_ships.map(func(row):return [row.ship_id,row.unit_price,catalogue.tables.ships[row.ship_id].stats.armor,catalogue.tables.ships[row.ship_id].stats.equipment_slots])," budget ",budget)
	print("VALKYRIE shipyard ",quote.loadout.station_id," offers ",offers.map(func(row):return [row.ship_id,row.unit_price,catalogue.tables.ships[row.ship_id].stats.armor]))
	var current:=int(quote.loadout.ship_id)
	# Keep the current hull when the yard has nothing tougher.
	if offers.is_empty() or (catalogue.tables.ships[offers[0].ship_id].stats.armor<=catalogue.tables.ships[current].stats.armor and catalogue.tables.ships[current].stats.secondary_slots>=secondaries):offers=[{"ship_id":current}]
	if offers.is_empty():check(false,"No affordable combat hull at station "+str(quote.loadout.station_id));return false
	if int(offers[0].ship_id)!=current:
		var index: int=quote.equipment.market_ships.find(offers[0])
		if not app.equipment_action("buy_ship",index):check(false,"The hull exchange was refused: "+app.session.error);return false
		check(app.session.station_owner().snapshot().loadout.ship_id==offers[0].ship_id,"The hull exchange failed")
	if failures:return false
	for id in [85,51,91,2,179,41]:
		if app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==id):app.equipment_action("mount",id)
	var guns: Array=app.session.station_owner().snapshot().equipment.market_rows.filter(func(row):return int(catalogue.tables.items[row.item_id].properties.get(1,-1))==0 and int(row.stock)>0)
	guns.sort_custom(func(a,b):return int(a.unit_price)>int(b.unit_price))
	print("VALKYRIE guns ",guns.map(func(row):return [row.item_id,row.unit_price,row.stock])," primary slots ",catalogue.tables.ships[offers[0].ship_id].stats.primary_slots)
	for gun in guns:
		if int(gun.unit_price)*int(catalogue.tables.ships[offers[0].ship_id].stats.primary_slots)>int(app.session.station_owner().snapshot().contracts.credits):continue
		for unit in int(catalogue.tables.ships[offers[0].ship_id].stats.primary_slots):
			if not app.equipment_action("buy",int(gun.item_id)):print("VALKYRIE buy refused ",app.session.error);break
			if not app.equipment_action("mount",int(gun.item_id)):print("VALKYRIE mount refused ",app.session.error);break
		break
	# Then the best affordable shield (type 9), armour (10) and repair device (15).
	for kind in [9,10,15]:
		var best: Array=app.session.station_owner().snapshot().equipment.market_rows.filter(func(row):return int(catalogue.tables.items[row.item_id].arrays[2][5])==kind and int(row.stock)>0 and int(row.unit_price)<=int(app.session.station_owner().snapshot().contracts.credits))
		best.sort_custom(func(a,b):return int(a.unit_price)>int(b.unit_price))
		if best.is_empty():continue
		var id:=int(best[0].item_id)
		if not app.equipment_action("buy",id) or not app.equipment_action("mount",id):print("VALKYRIE protection refused ",id," ",app.session.error)
	var fitted: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE refit ship ",fitted.loadout.ship_id," items ",fitted.loadout.equipment_ids," credits ",fitted.contracts.credits)
	check(fitted.loadout.equipment_ids.has(85),"The refit lost the Khador Drive")
	check(fitted.loadout.equipment_ids.has(179),"The refit did not mount the Liberators from the hold")
	return app.equipment_action("close") and failures==0

## 63: at the pirate outpost in Skavac three of the six sleeping pirates must
## go; the others then surrender their guns. Back at Kothar for mission 64.
func fly_outpost() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==63,"The outpost checkpoint is not at cursor 63")
	# Six pirates wake together near the outpost; a player brings a tougher
	# ship by now. Test shortcut: the money the career would have earned.
	if failures or not seed_cargo([[122,12]],3000000) or not outfit_for_combat():return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(103):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE outpost cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.active]))
	check(actors.size()==7 and actors[0].get("static_object",false) and actors.slice(1).all(func(actor):return actor.actor_kind==8 and actor.hostile and not actor.active),"The outpost cast differs from its recipe")
	if failures:return
	await capture_free_application("valkyrie-outpost-start")
	var radio_ids:=[]
	if not await fight_until("outpost",func():return app.session.flight_owner()._objective.snapshot().campaign_cursor==64,
		func(list):return range(1,list.size()).filter(func(id):return int(list[id].vitals.hull)>0),radio_ids,30000,true):return
	var after: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	var killed:=after.filter(func(actor):return int(actor.vitals.hull)<=0).size()
	print("VALKYRIE outpost killed ",killed," firing ",after.map(func(actor):return actor.get("firing_allowed")))
	check(killed>=3 and after.slice(1).all(func(actor):return actor.get("firing_allowed")==false),"The surviving pirates did not give up their guns")
	for tick in 600:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2216 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE outpost radio ",radio_ids)
	check([2212,2213,2215,2216].all(func(id):return id in radio_ids),"The outpost radio lines did not all play")
	await capture_free_application("valkyrie-outpost-won")
	# 64: the drive is refused during the rescue; Khador is in the same system.
	if failures or not await travel_application(104):return
	var rescue: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE rescue cast ",rescue.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.get("friendly")]))
	check(rescue.size()==9 and rescue[0].hull_catalogue_id==38 and rescue[0].get("friendly")==true and rescue.slice(1).all(func(actor):return actor.actor_kind==8 and actor.hostile),"The rescue cast differs from its recipe")
	if failures:return
	await capture_free_application("valkyrie-rescue-start")
	var rescue_radio:=[]
	if not await fight_until("rescue",func():return app.session.flight_owner()._objective.snapshot().campaign_cursor==65,
		func(list):return range(1,list.size()).filter(func(id):return int(list[id].vitals.hull)>0 and list[id].get("firing_allowed",true)),rescue_radio,30000,true,30000.0):return
	for tick in 900:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in rescue_radio:rescue_radio.append(int(radio.text_id))
		if 2228 in rescue_radio:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE rescue radio ",rescue_radio)
	check(range(2217,2229).all(func(id):return id in rescue_radio),"The rescue radio lines did not all play")
	check(int(app.session.flight_owner()._encounter.combat_snapshot().actors[0].vitals.hull)>0,"Khador's ship was lost")
	await capture_free_application("valkyrie-rescue-won")
	# Home to Kothar (Beidan) with the drive (assumption: no automatic jump).
	if failures or not await go_to(100) or not await dock_application() or not await take_station_talk(65,66):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the rescue failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==66,"Fresh Resume lost the rescue result")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-66.gof2save"))==OK,"The rescue checkpoint could not be kept")

## 66: Alice's talk at the Valkyrie. 67: the outpost is friendly for now; the
## four pirates around it wake, four more arrive at "Cornelius, move in!" and
## Tenner flies along. Eight pirates down and the talk ends the mission.
func fly_distraction() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==66,"The distraction checkpoint is not at cursor 66")
	# Test shortcut: the launcher refilled to ten (the Valkyrie builds them).
	if failures or not seed_cargo([[122,12],[179,4]],3000000) or not outfit_for_combat():return
	var slots: Array=app.session.station_owner().snapshot().loadout.slots
	var launcher:=range(slots.size()).filter(func(i):return slots[i]!=null and int(slots[i].item_id)==179)
	if launcher.is_empty() or not app.equipment_action("open") or not app.equipment_action("unmount",179,launcher[0]) or not app.equipment_action("mount",179) or not app.equipment_action("close"):check(false,"Loading the Liberators failed: "+app.session.error);return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await go_to(101) or not await dock_application() or not await take_station_talk(66,67):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await go_to(104):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE distraction cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.get("friendly"),actor.active]))
	check(actors.size()==10 and actors[0].get("static_object",false) and not actors[0].hostile and actors[9].hull_catalogue_id==27 and actors[9].get("friendly")==true,"The distraction cast differs from its recipe")
	if failures:return
	await capture_free_application("valkyrie-distraction-start")
	var radio_ids:=[];var outpost:=Vector3(220000,-20000,-10000)
	if not await fight_until("distraction",func():return app.session.flight_owner()._objective.snapshot().campaign_cursor==68,
		func(list):return range(1,9).filter(func(id):return int(list[id].vitals.hull)>0 and list[id].pose.origin.distance_to(outpost)<200000),radio_ids,30000,true,30000.0):return
	for tick in 1500:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2295 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE distraction radio ",radio_ids)
	check(range(2276,2296).all(func(id):return id in radio_ids),"The distraction radio lines did not all play")
	check(int(app.session.flight_owner()._encounter.combat_snapshot().actors[0].vitals.hull)>0,"The outpost was destroyed")
	await capture_free_application("valkyrie-distraction-won")
	if failures or not await go_to(100) or not await dock_application():return
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the distraction failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==68,"Fresh Resume lost the distraction result")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-68.gof2save"))==OK,"The distraction checkpoint could not be kept")

## As the shared helper, but the map may open with the story target already
## selected; ask for the confirmation only once.
func acquire_application_planet(destination: int) -> bool:
	resume_application_focus()
	if not app.open_map():check(false,app.status.text);return false
	app.present_session()
	if int(app.map_panel.snapshot().get("selected_station_id",-1))!=destination:app.map_panel.select_station(destination)
	if not app.map_panel.snapshot().get("confirmation_visible",false):app.map_panel.request_confirmation()
	var shown: Dictionary=app.map_panel.snapshot()
	if not app.confirm_map_planet(destination,now_us):check(false,"The map refused station %d: selected %s confirmation %s error '%s' status %s pauses %s active %s"%[destination,shown.get("selected_station_id"),shown.get("confirmation_visible"),app.map_panel.error,app.session.status,str(app.session._pauses),str(app.session._active)]);return false
	app.session.rebase_time(now_us)
	for tick in 2000:
		if app.session.status=="local_arrival_transition_required":return true
		if not application_step():return false
		if tick%100==0:await process_frame
	check(false,"Local travel to %d never arrived"%destination);return false

## Test shortcut while the 67 playtest is open: move a copied checkpoint's story
## on to the given cursor (the station's story mission follows the table).
func seed_story_cursor(cursor: int) -> bool:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	var row: Array=load("res://src/content/valkyrie_campaign_definitions.gd").MISSIONS[cursor]
	print("VALKYRIE seed story from station mission ",document.station.get("mission")," career mission ",document.career.get("mission"))
	var from:=int(document.station.campaign_cursor)
	_move_cursor(document.station,from,cursor);_move_cursor(document.career,from,cursor)
	# Rank and score follow the story cursor.
	for part in [document.station,document.career]:
		var progress: Variant=part.get("progress")
		if not progress is Dictionary or not progress.has("player_kills"):continue
		var earned: Dictionary=load("res://src/simulation/opening_handoff.gd").calculate_progress(definitions.opening_handoff,cursor,progress.player_kills,progress.pirate_kills,progress.other_score)
		progress.merge(earned,true)
		if part.has("rank") and earned.has("rank"):part.rank=earned.rank
	var mission: Dictionary=document.station.mission.duplicate(true)
	mission.merge({"kind":row[0],"station_id":row[2],"reward":row[1]},true)
	document.station.mission=mission
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station(),"The story-seeded save did not load: "+app._save_notice.text)
	return failures==0

static func _move_cursor(node: Variant,from: int,to: int) -> void:
	if node is Dictionary:
		for key in node.keys():
			if str(key)=="campaign_cursor" and node[key] is int and node[key]==from:node[key]=to
			else:_move_cursor(node[key],from,to)
	elif node is Array:
		for item in node:_move_cursor(item,from,to)

## 68: Netor at Inari Onu (Vulpes) takes the Void Essence; entering 69 removes it.
func fly_delivery() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if failures or not seed_story_cursor(68) or not seed_cargo([[122,12],[175,1]]):return
	check(app.session.station_owner().snapshot().campaign_cursor==68,"The delivery checkpoint is not at cursor 68")
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await go_to(66) or not await dock_application() or not await take_station_talk(68,69):return
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(not docked.cargo.entries.any(func(row):return int(row.item_id)==175),"Netor did not take the Void Essence")
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the delivery failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==69,"Fresh Resume lost the delivery")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-69.gof2save"))==OK,"The delivery checkpoint could not be kept")

## 69: Trot Lykkt leaves Inari Onu; 70: he is stopped at Lopat; 71: Netor's
## talk; 72: Alice calls after 10 s in space.
func fly_trot() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==69,"The Trot checkpoint is not at cursor 69")
	if failures or not seed_cargo([[122,12]]):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE leaving cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.get("friendly")]))
	check(actors.size()==5 and actors[0].hull_catalogue_id==12 and actors.all(func(actor):return actor.get("friendly")==true),"The Inari Onu cast differs from its recipe")
	var radio_ids:=[]
	for tick in 1200:
		if app.session.flight_owner()._objective.snapshot().campaign_cursor==70:break
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if not application_step():return
		if tick%10==0:await process_frame
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==70 and [2307,2308].all(func(id):return id in radio_ids),"Trot's departure did not play: "+str(radio_ids))
	if failures:return
	await capture_free_application("valkyrie-trot-leaves")
	if not await go_to(65):return
	var chase: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	check(chase.size()==1 and chase[0].hull_catalogue_id==12,"The Lopat cast differs from its recipe")
	if failures:return
	var chase_radio:=[]
	if not await fight_until("trot",func():return app.session.flight_owner()._objective.snapshot().campaign_cursor==71,
		func(list):return [0] if int(list[0].vitals.hull)>0 and list[0].hostile else [],chase_radio,30000,true,30000.0):return
	for tick in 600:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in chase_radio:chase_radio.append(int(radio.text_id))
		if 2313 in chase_radio:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE trot radio ",chase_radio)
	check(range(2309,2314).all(func(id):return id in chase_radio),"The Lopat radio lines did not all play")
	await capture_free_application("valkyrie-trot-stopped")
	if failures or not await go_to(66) or not await dock_application() or not await take_station_talk(71,72):return
	var before_call:=int(app.session.station_owner().snapshot().contracts.credits)
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var call:=[]
	for tick in 3000:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in call:call.append(int(radio.text_id))
		if 2335 in call:break
		if not application_step():return
		if tick%10==0:await process_frame
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==73 and range(2321,2336).all(func(id):return id in call),"Alice's call did not play: "+str(call))
	if failures or not await dock_application():return
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the call failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==73,"Fresh Resume lost Alice's call")
	check(int(app.session.station_owner().snapshot().contracts.credits)==before_call+150000,"Alice's call did not pay 150000: "+str(before_call)+" -> "+str(app.session.station_owner().snapshot().contracts.credits))
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-73.gof2save"))==OK,"The call checkpoint could not be kept")

## 73: the Teres convoy. Four pirates at the first point; EMP one of the
## Terran transports and four more pirates close in around the player. All
## eight down: the result plays and the story moves to Kothar (74). The
## failure case loses all four transports: a failure result, cursor stays 73.
func fly_teres(lose: bool) -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==73,"The Teres checkpoint is not at cursor 73")
	# Test shortcut: the money the career would have earned, a full launcher and EMP bombs.
	if failures or not seed_cargo([[122,12],[179,4],[41,10]],3000000) or not outfit_for_combat():return
	var fitted: Array=app.session.station_owner().snapshot().loadout.equipment_ids
	check(fitted.has(41),"The refit did not mount the EMP bombs: "+str(fitted))
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await go_to(81):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE teres cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.get("friendly"),actor.active]))
	check(actors.size()==12 and actors.slice(0,8).all(func(actor):return actor.actor_kind==8 and actor.hostile and not actor.active) and actors.slice(8).all(func(actor):return actor.get("friendly")==true),"The Teres cast differs from its recipe")
	if failures:return
	await capture_free_application("valkyrie-teres-start")
	var radio_ids:=[]
	if not await fight_until("teres",func():return range(0,4).all(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)<=0),
		func(list):return range(0,4).filter(func(id):return int(list[id].vitals.hull)>0),radio_ids,30000,true,30000.0):return
	if lose:
		# Shoot the transports down instead of guarding them.
		if not await fight_until("teres-lost",func():return range(8,12).all(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)<=0),
			func(list):return range(8,12).filter(func(id):return int(list[id].vitals.hull)>0),radio_ids,30000,false):return
		for tick in 600:
			if app.session.status!="running" or app.session.snapshot().contracts.get("pending_result",{}).get("failed",false):break
			if not application_step():return
			if tick%10==0:await process_frame
		var state: Dictionary=app.session.snapshot()
		print("VALKYRIE teres failure ",state.contracts.get("pending_result",{})," status ",app.session.status)
		await capture_free_application("valkyrie-teres-lost")
		check(state.campaign_cursor==73,"Losing the convoy moved the story on")
		return
	if not await emp_transport(8,radio_ids):return
	var reserve: Array=app.session.flight_owner()._encounter.combat_snapshot().actors.slice(4,8)
	var player: Vector3=app.session.snapshot().player_pose.origin
	print("VALKYRIE teres reserve ",reserve.map(func(actor):return [int(actor.pose.origin.distance_to(player)),actor.active]))
	check(reserve.all(func(actor):return actor.active and actor.pose.origin.distance_to(player)<60000),"The reserve did not close in around the player")
	if failures:return
	if not await fight_until("teres-reserve",func():return app.session.flight_owner()._objective.snapshot().campaign_cursor==74,
		func(list):return range(4,8).filter(func(id):return int(list[id].vitals.hull)>0),radio_ids,30000,true,30000.0):return
	for tick in 1500:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2352 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE teres radio ",radio_ids)
	check(range(2336,2353).all(func(id):return id in radio_ids),"The Teres radio lines did not all play")
	await capture_free_application("valkyrie-teres-won")
	# 74-76: three Kothar talks back to back; afterwards the yard offers only
	# Khador's Cronus, for nothing.
	if failures or not await go_to(100) or not await dock_application() or not await take_station_talk(74,75) or not await take_station_talk(75,76):return
	if failures or not await take_station_talk(76,77):return
	var yard: Array=await shipyard()
	print("VALKYRIE Kothar yard at 77 ",yard)
	check(yard.size()==1 and int(yard[0].ship_id)==37 and int(yard[0].unit_price)==0,"The Cronus is not free at Kothar")
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the Kothar talks failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==77,"Fresh Resume lost the Kothar talks")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-77.gof2save"))==OK,"The Kothar checkpoint could not be kept")

## 77: take the free Cronus (drive built in) to the Valkyrie; Alice takes
## the Khador Drive. 78: the station leaves, twenty pirates wake, and the
## drive jumps straight to the alien world.
func fly_valkyrie_escape() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==77,"The escape checkpoint is not at cursor 77")
	if failures or not seed_cargo([[122,20],[175,2]]):return
	if not app.equipment_action("open"):check(false,"The hangar did not open: "+app.session.error);return
	var yard: Array=app.session.station_owner().snapshot().equipment.market_ships
	var index:=-1
	for i in yard.size():
		if int(yard[i].ship_id)==37:index=i
	if index<0 or not app.equipment_action("buy_ship",index):check(false,"The Cronus could not be taken: "+app.session.error);return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE Cronus ship ",fitted.loadout.ship_id," items ",fitted.loadout.equipment_ids," credits ",fitted.contracts.credits," hold ",fitted.cargo.entries)
	check(int(fitted.loadout.ship_id)==37,"The Cronus purchase did not change ships")
	for id in [179,41,51,57,75,91]:
		if fitted.cargo.entries.any(func(row):return row.item_id==id):app.equipment_action("mount",id)
	if failures or not app.equipment_action("close"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await go_to(101) or not await dock_application() or not await take_station_talk(77,78):return
	var taken: Dictionary=app.session.station_owner().snapshot()
	check(not taken.loadout.equipment_ids.has(85) and not taken.cargo.entries.any(func(row):return int(row.item_id)==85),"Alice did not take the Khador Drive")
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	check(actors.size()==20 and actors.all(func(actor):return actor.actor_kind==8 and actor.hostile and not actor.active),"The ambush cast differs from its recipe")
	if failures:return
	await capture_free_application("valkyrie-escape-start")
	var radio_ids:=[];var hidden_seen:=false
	for tick in 600:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if not hidden_seen and app.session.snapshot().get("station_hidden",false):hidden_seen=true;await capture_free_application("valkyrie-escape-station-gone")
		if 2401 in radio_ids and app.session.flight_owner()._encounter.combat_snapshot().actors.all(func(actor):return actor.active):break
		if not application_step():return
		if tick%10==0:await process_frame
	print("VALKYRIE escape radio ",radio_ids," hidden ",hidden_seen)
	check(range(2398,2402).all(func(id):return id in radio_ids) and hidden_seen,"The escape did not play: "+str(radio_ids))
	check(app.session.flight_owner()._encounter.combat_snapshot().actors.all(func(actor):return actor.active),"The pirates did not wake")
	if failures:return
	await capture_free_application("valkyrie-escape-ambush")
	resume_application_focus()
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.physical_keycode=KEY_K;key.keycode=KEY_K;key.pressed=pressed;app._unhandled_input(key)
	check(not app.map_panel.visible,"The escape drive opened the star map: "+app.status.text)
	var began:=now_us
	app.session.rebase_time(now_us)
	while app.session.status=="running" and now_us-began<15000000:
		if not application_step():return
	print("VALKYRIE escape drive status ",app.session.status," cursor ",app.session.snapshot().campaign_cursor)
	check(app.session.status=="drive_arrival_transition_required","The escape jump did not complete: "+app.session.status+" "+app.status.text)
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var arrived: Dictionary=app.session.snapshot()
	print("VALKYRIE alien world cursor ",arrived.campaign_cursor," location ",arrived.location)
	await capture_free_application("valkyrie-alien-world")
	check(int(arrived.location.station_id)<0 and int(arrived.campaign_cursor)>=79,"The escape did not reach the alien world at 79")
	if failures:return
	# 79: "Let's try this again!", then the drive's way out leads to Kothar (80).
	var void_radio:=[]
	for tick in 200:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot() if app.session.flight_owner()._radio!=null else {}
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in void_radio:void_radio.append(int(radio.text_id))
		if 2402 in void_radio:break
		if not application_step():return
		if tick%10==0:await process_frame
	check(2402 in void_radio,"The alien-world line did not play: "+str(void_radio))
	if failures:return
	resume_application_focus()
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.physical_keycode=KEY_K;key.keycode=KEY_K;key.pressed=pressed;app._unhandled_input(key)
	began=now_us
	app.session.rebase_time(now_us)
	while app.session.status=="running" and now_us-began<15000000:
		if not application_step():return
	check(app.session.status=="drive_arrival_transition_required","The way out of the alien world did not complete: "+app.session.status+" "+app.status.text)
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var kothar: Dictionary=app.session.snapshot()
	print("VALKYRIE back from the alien world cursor ",kothar.campaign_cursor," station ",kothar.location.station_id)
	await capture_free_application("valkyrie-kothar-battle-start")
	check(int(kothar.location.station_id)==100 and int(kothar.campaign_cursor)==80,"Leaving the alien world did not reach Kothar at 80")
	if failures:return
	# 80: break the battlestation's weak points (#1-#12) and the pirates
	# (#13-#18); "Retreat!", the station jumps away, Carla's lines, then the
	# drive takes the ship to the alien world by itself (81).
	var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("VALKYRIE kothar cast ",cast.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.hostile,actor.get("friendly"),int(actor.vitals.hull)]))
	check(cast.size()==22,"The Kothar battle cast differs from its recipe")
	if failures:return
	var battle_radio:=[]
	if not await fight_until("kothar",func():return range(1,19).all(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)<=0),
		func(list):return range(1,19).filter(func(id):return int(list[id].vitals.hull)>0),battle_radio,60000,true,30000.0):return
	await capture_free_application("valkyrie-kothar-won")
	if not await ride_story_jump(battle_radio,180):return
	print("VALKYRIE kothar radio ",battle_radio)
	check(range(2403,2421).all(func(id):return id in battle_radio),"The Kothar battle lines did not all play")
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var stranded: Dictionary=app.session.snapshot()
	print("VALKYRIE alice stranded cursor ",stranded.campaign_cursor," location ",stranded.location)
	await capture_free_application("valkyrie-alice-stranded")
	check(int(stranded.location.station_id)<0 and int(stranded.campaign_cursor)==81,"The battle did not move the ship to the alien world at 81")
	if failures:return
	# 81: four lines, then the drive takes the ship back to Kothar (82).
	var stranded_radio:=[]
	if not await ride_story_jump(stranded_radio,120):return
	check(range(2421,2425).all(func(id):return id in stranded_radio),"Alice's lines did not all play: "+str(stranded_radio))
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var home: Dictionary=app.session.snapshot()
	print("VALKYRIE home cursor ",home.campaign_cursor," station ",home.location.station_id)
	check(int(home.location.station_id)==100 and int(home.campaign_cursor)==82,"The story did not bring the ship back to Kothar at 82")
	if failures or not await dock_application():return
	await capture_free_application("valkyrie-kothar-82")
	# 82 -> 83 -> 84: the last talks and the win. Khador's three ships in the
	# yard, a bottle of Rum and a Khador Drive in the hold.
	if not await take_station_talk(82,83) or not await take_station_talk(83,84):return
	var won: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE won hold ",won.cargo.entries)
	check([137,85].all(func(id):return won.cargo.entries.any(func(row):return int(row.item_id)==id)),"The win did not put the Rum and a Khador Drive in the hold")
	var final_yard: Array=await shipyard()
	print("VALKYRIE Kothar yard at 84 ",final_yard.map(func(offer):return [offer.ship_id,offer.unit_price]))
	check([37,38,40].all(func(id):return final_yard.any(func(offer):return int(offer.ship_id)==id)),"Kothar's yard does not offer Khador's three ships after the win")
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the win failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==84,"Fresh Resume lost the win")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-84.gof2save"))==OK,"The win checkpoint could not be kept")

## Fly on (radio lines collected) until the story's own drive jump arrives.
func ride_story_jump(radio_ids: Array,seconds: int) -> bool:
	var began:=now_us
	app.session.rebase_time(now_us)
	var tick:=0
	while app.session.status=="running" and now_us-began<seconds*1000000:
		var radio: RefCounted=app.session.flight_owner()._radio
		if radio!=null and radio.snapshot().get("visible",false) and int(radio.snapshot().get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.snapshot().text_id))
		if app.session.flight_owner().death_active():check(false,"The pilot died waiting for the story jump");return false
		await dismiss_medal()
		if not application_step():return false
		tick+=1
		if tick%10==0:await process_frame
	print("VALKYRIE story jump status ",app.session.status," cursor ",app.session.snapshot().campaign_cursor," radio ",radio_ids)
	check(app.session.status=="drive_arrival_transition_required","The story's drive jump did not happen: "+app.session.status+" "+app.status.text)
	return failures==0

## Supernova 84-88 from the won Valkyrie career: Carla's call in flight (84 ->
## 86), Kothar talk, the flight to Thynome with her six lines, Thynome talk.
func fly_supernova_start() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==84,"The Supernova checkpoint is not at cursor 84")
	if failures or not seed_cargo([[122,20]]):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await wait_story_cursor(86,"supernova-call"):return
	var radio_ids:=[]
	for tick in 1500:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2464 in radio_ids:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("SUPERNOVA call radio ",radio_ids)
	check([2463,2464].all(func(id):return id in radio_ids),"The Supernova call's lines did not play")
	if failures or not await dock_application() or not await take_station_talk(86,87):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(10):return
	var home_radio:=[]
	for tick in 3000:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in home_radio:home_radio.append(int(radio.text_id))
		if app.session.flight_owner()._objective.snapshot().campaign_cursor==88:break
		if not application_step():return
		if tick%10==0:await process_frame
	print("SUPERNOVA Thynome radio ",home_radio," cursor ",app.session.flight_owner()._objective.snapshot().campaign_cursor)
	await capture_free_application("supernova-thynome")
	# The first line starts 1.5 s in, while the arrival settles: read the radio's own record.
	var heard: Array=app.session.flight_owner()._radio.snapshot().get("finished",[])
	check(heard.size()==6 and heard.all(func(done):return done==true) and range(2470,2475).all(func(id):return id in home_radio) and app.session.flight_owner()._objective.snapshot().campaign_cursor==88,"Carla's lines at Thynome did not play or finish 87")
	if failures or not await dock_application() or not await take_station_talk(88,89):return
	var opened: Dictionary=app.session.station_owner().snapshot()
	print("SUPERNOVA after 88 systems ",opened.get("progress",{}).get("unlocked_system_ids",opened.get("progress",{}).keys()))
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the Thynome talk failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==89,"Fresh Resume lost the Thynome talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-89.gof2save"))==OK,"The Thynome checkpoint could not be kept")

## 89: launching from Thynome, the drive takes the ship to Naneroh; the
## supernova destroys the station and its ships while the player is held;
## then the drive brings the ship back to Thynome (90) for Gunant's talk.
func fly_supernova_blast() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==89,"The supernova checkpoint is not at cursor 89")
	if failures or not seed_cargo([[122,20]]):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var radio:=[]
	if not await ride_story_jump(radio,30):return
	if not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	# The scene holds the player from the start: step it instead of taking control.
	app.session.rebase_time(now_us)
	for tick in 30:
		if not application_step():return
	check(app.session.flight_owner().cinematic_input_blocked(),"The supernova scene did not hold the player")
	var naneroh: Dictionary=app.session.snapshot()
	var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("SUPERNOVA Naneroh station ",naneroh.location.station_id," cast ",cast.map(func(actor):return [actor.hull_catalogue_id,actor.get("static_model",-1),int(actor.vitals.hull),actor.get("model_draw_enabled")]))
	await capture_free_application("supernova-naneroh")
	check(int(naneroh.location.station_id)==109 and cast.size()==12,"The drive did not bring the ship to Naneroh's scene")
	if failures:return
	var blast:=false
	var began:=now_us
	while app.session.status=="running" and now_us-began<90000000:
		if not blast and app.session.flight_owner()._encounter.combat_snapshot().actors.slice(3).all(func(actor):return int(actor.vitals.hull)<=0):
			blast=true;print("SUPERNOVA blast after ",(now_us-began)/1000000," s");await capture_free_application("supernova-blast")
		if not application_step():return
		if int((now_us-began)/100000)%20==0:await process_frame
	check(blast,"The supernova did not destroy Naneroh's ships")
	check(app.session.status=="drive_arrival_transition_required" and app.session.snapshot().campaign_cursor==90,"The story did not take the ship home after the blast: "+app.session.status)
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	check(int(app.session.snapshot().location.station_id)==10,"The ship did not come back to Thynome")
	if failures or not await dock_application() or not await take_station_talk(90,91):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming after Gunant's talk failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==91,"Fresh Resume lost Gunant's talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-91.gof2save"))==OK,"The Gunant checkpoint could not be kept")

## 91: without ten passenger berths the drive refuses Valpatro; with cabins
## fitted the player jumps there, docks at the damaged freighter under gamma
## rays, the ten miners board, the player pulls away, the freighter explodes
## and the drive takes the ship on to Tadram (92).
func fly_supernova_rescue() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==91,"The rescue checkpoint is not at cursor 91")
	var hold: Dictionary=app.session.station_owner().snapshot().get("cargo",{})
	if failures or not seed_cargo([],400000):return
	var berths: int=load("res://src/simulation/first_flight_frame.gd")._passenger_berths(catalogue,app.session.station_owner().snapshot().loadout)
	print("SUPERNOVA berths before ",berths)
	if berths<10:
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight():return
		resume_application_focus()
		for pressed in [true,false]:
			var key:=InputEventKey.new();key.physical_keycode=KEY_K;key.keycode=KEY_K;key.pressed=pressed;app._unhandled_input(key)
		if app.map_panel.snapshot().get("void_prompt",false):
			for pressed in [true,false]:
				var key:=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.keycode=KEY_ESCAPE;key.pressed=pressed;app._unhandled_input(key)
		app.map_panel.show_system(int(catalogue.tables.stations[110].system_id))
		app.map_panel.select_station(110);app.map_panel.request_confirmation()
		print("SUPERNOVA refusal map ",app.map_panel.snapshot().get("selected_station_id")," confirm ",app.map_panel.snapshot().get("confirmation_visible")," drive ",app.map_panel.snapshot().get("drive_mode"))
		var confirmed: bool=app.confirm_map_planet(110,now_us)
		print("SUPERNOVA refusal confirm ",confirmed," ",app.status.text," map ",app.map_panel.error," session ",app.session.error," cursor ",app.session.flight_owner()._entry.campaign_cursor," drive ",app.session.flight_owner()._drive.snapshot().phase," notices ",app.session.flight_owner()._notices.snapshot().get("pending",[]).size())
		for tick in 20:
			if not application_step():return
		var pending: Array=app.session.flight_owner()._notices.snapshot().get("pending",[])
		print("SUPERNOVA refusal notices ",pending.map(func(row):return [row.get("source_id"),row.get("text")]))
		check(app.session.flight_owner()._drive.snapshot().phase not in ["charging","departing"] and pending.any(func(row):return int(row.get("source_id",-1))==43203),"The drive did not refuse Valpatro without ten berths")
		await capture_free_application("supernova-berths-refused")
		if failures or not await dock_application():return
		if not await fit_cabins(10):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(110):return
	var radio_ids:=[];var docked_at:=-1;var boarded:=false;var gone:=false;var gamma_seen:=false
	var began:=now_us
	app.session.rebase_time(now_us)
	for tick in 20000:
		if app.session.status!="running":break
		var frame: RefCounted=app.session.flight_owner()
		var radio: Dictionary=frame._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if frame.death_active():check(false,"The pilot died at Valpatro: gamma "+str(frame._player.snapshot().get("gamma")));return
		var state: Dictionary=app.session.snapshot()
		var dock: Dictionary=frame._story_dock
		if not gamma_seen and float(state.player.get("gamma",100.0))<99.0:
			gamma_seen=true;print("SUPERNOVA gamma falling ",state.player.gamma," rate ",frame._gamma_rate);await capture_free_application("supernova-valpatro-gamma")
		if int(dock.docked)==0 and docked_at<0:docked_at=tick;print("SUPERNOVA docked at tick ",tick," radio ",radio_ids);await capture_free_application("supernova-valpatro-docked")
		if int(dock.aboard)>=10 and not boarded:boarded=true;print("SUPERNOVA ten aboard ",(now_us-began)/1000000," s")
		var freighter: Dictionary=frame._encounter.combat_snapshot().actors[0]
		if int(freighter.vitals.hull)<=0 and not gone:gone=true;print("SUPERNOVA freighter destroyed ",(now_us-began)/1000000," s");await capture_free_application("supernova-valpatro-explosion")
		var target: Vector3=freighter.get("pose",Transform3D()).origin
		var steer:=Vector2.ZERO;var want:=0.0
		var heard: Array=radio.get("finished",[])
		if not boarded or heard.size()<7 or heard[6]!=true:
			# Before the lines allow docking, wait near; then fly in and hold.
			var distance: float=state.player_pose.origin.distance_to(target)
			steer=EmpSteering.steering_toward(state.player_pose,target);want=1.0 if distance>2000.0 and heard.size()>3 and heard[3]==true or distance>8000.0 else 0.0
		elif not gone:
			steer=EmpSteering.steering_toward(state.player_pose,state.player_pose.origin-(target-state.player_pose.origin));want=1.0
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-want)<.01 or frame.cinematic_input_blocked():break
			if not app.session.action("throttle_up" if current<want else "throttle_down"):check(false,app.session.error);return
		now_us+=100000
		if not app.session.step(now_us,steer if not frame.cinematic_input_blocked() else Vector2.ZERO):check(false,app.session.error);return
		app.present_session()
		await dismiss_medal()
		if tick%20==0:await process_frame
	print("SUPERNOVA Valpatro radio ",radio_ids," status ",app.session.status," cursor ",app.session.snapshot().campaign_cursor)
	check(docked_at>=0 and boarded and gone and gamma_seen and range(2493,2500).all(func(id):return id in radio_ids),"The Valpatro rescue did not play through")
	check(app.session.status=="local_arrival_transition_required" and app.session.snapshot().campaign_cursor==92,"The story did not take the ship on to Tadram: "+app.session.status)
	if failures or not app.enter_local_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	check(int(app.session.snapshot().location.station_id)==113,"The ship did not arrive at Tadram")
	print("SUPERNOVA Tadram gamma ",app.session.snapshot().player.get("gamma")," vitals ",app.session.snapshot().player.vitals)
	if failures:return
	await fly_supernova_handover()

## 92: dock at the Tadram freighter, the ten leave; three unknown ships appear,
## cloak and come back; destroy them; the freighter leaves; Gunant's call.
func fly_supernova_handover() -> void:
	var radio_ids:=[];var unloaded:=false;var cloaked:=false
	var began:=now_us
	app.session.rebase_time(now_us)
	for tick in 30000:
		if app.session.status!="running":break
		var frame: RefCounted=app.session.flight_owner()
		var radio: Dictionary=frame._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if frame.death_active():check(false,"The pilot died at Tadram: gamma "+str(frame._player.snapshot().get("gamma"))+" vitals "+str(frame._player.snapshot().vitals));return
		if frame._objective.snapshot().campaign_cursor==93:break
		var state: Dictionary=app.session.snapshot()
		var dock: Dictionary=frame._story_dock
		var actors: Array=frame._encounter.combat_snapshot().actors
		if int(dock.get("status",10))==0 and not unloaded:unloaded=true;print("SUPERNOVA ten off at ",(now_us-began)/1000000," s radio ",radio_ids);await capture_free_application("supernova-tadram-docked")
		var heard: Array=radio.get("finished",[])
		if heard.size()>5 and heard[5]==true and not cloaked:cloaked=true;print("SUPERNOVA cloak at ",(now_us-began)/1000000," s");await capture_free_application("supernova-tadram-ambush")
		var steer:=Vector2.ZERO;var want:=0.0
		var hunting: bool=heard.size()>6 and heard[6]==true and range(1,4).any(func(id):return int(actors[id].vitals.hull)>0 and actors[id].get("active",false))
		if hunting:
			var alive:=func(): return [1,2,3].filter(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)>0)
			if not await fight_until("tadram",func():return alive.call().is_empty(),func(_actors):return alive.call(),radio_ids):return
			print("SUPERNOVA ambush destroyed at ",(now_us-began)/1000000," s")
			continue
		if true:
			if not unloaded:
				var target: Vector3=actors[0].get("pose",Transform3D()).origin
				var distance: float=state.player_pose.origin.distance_to(target)
				steer=EmpSteering.steering_toward(state.player_pose,target);want=1.0 if distance>2000.0 else 0.0
			for adjustment in 10:
				var current: float=app.session.snapshot().input_throttle
				if absf(current-want)<.01 or frame.cinematic_input_blocked():break
				if not app.session.action("throttle_up" if current<want else "throttle_down"):check(false,app.session.error);return
			now_us+=100000
			if not app.session.step(now_us,steer if not frame.cinematic_input_blocked() else Vector2.ZERO):check(false,app.session.error);return
		app.present_session()
		await dismiss_medal()
		if tick%20==0:await process_frame
	print("SUPERNOVA Tadram radio ",radio_ids," cursor ",app.session.snapshot().campaign_cursor," status ",app.session.status)
	check(unloaded and cloaked and range(2502,2512).all(func(id):return id in radio_ids) and 2518 in radio_ids and app.session.snapshot().campaign_cursor==93,"The Tadram hand-over did not play through")
	if failures or not await dock_application():return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Tadram failed: "+app._save_notice.text)
	if failures:return
	var resumed: Dictionary=app.session.station_owner().snapshot()
	check(resumed.campaign_cursor==93 and int(resumed.loadout.station_id)==113,"Fresh Resume lost the Tadram hand-over: "+str([resumed.campaign_cursor,resumed.loadout.station_id]))
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-93.gof2save"))==OK,"The Tadram checkpoint could not be kept")

## Buy and fit passenger cabins at the current station until the ship has
## `needed` berths, making room by unfitting non-essential equipment.
func fit_cabins(needed: int) -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	for attempt in 12:
		var shop: Dictionary=app.session.station_owner().snapshot()
		if load("res://src/simulation/first_flight_frame.gd")._passenger_berths(catalogue,shop.loadout)>=needed:break
		var cabin:={}
		for row in shop.equipment.market_rows:
			var properties: Dictionary=catalogue.tables.items[row.item_id].properties
			if int(properties.get(2,-1))==20 and row.stock>0 and row.unit_price<=shop.contracts.credits:
				if cabin.is_empty() or int(properties.get(34,0))>cabin.places:cabin={"item_id":row.item_id,"price":row.unit_price,"places":int(properties.get(34,0))}
		if cabin.is_empty():check(false,"No passenger cabin on sale at station "+str(shop.loadout.station_id));return false
		if not shop.equipment.fitting_support.get(cabin.item_id,{}).is_empty():
			var category: int=int(catalogue.tables.items[cabin.item_id].properties.get(1,-1))
			var freed:=false
			for index in shop.loadout.slots.size():
				var slot: Variant=shop.loadout.slots[index]
				if slot==null or int(slot.item_id)==85:continue
				var own: Dictionary=catalogue.tables.items[int(slot.item_id)].properties
				if int(own.get(1,-1))==category and int(own.get(2,-1))!=20:
					if not app.equipment_action("unmount",int(slot.item_id),index):check(false,app.session.error);return false
					freed=true;break
			if not freed:check(false,"No slot to free for a cabin: "+str(shop.equipment.fitting_support.get(cabin.item_id)));return false
		if not app.equipment_action("buy",int(cabin.item_id)) or not app.equipment_action("mount",int(cabin.item_id)):check(false,app.session.error);return false
		print("SUPERNOVA fitted cabin ",cabin)
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(load("res://src/simulation/first_flight_frame.gd")._passenger_berths(catalogue,fitted.loadout)>=needed,"The ship still lacks passenger berths")
	await capture_free_application("supernova-cabins")
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return failures==0

## The hangar's ship offers, as the player sees them.
func shipyard() -> Array:
	if not app.equipment_action("open"):check(false,"The hangar did not open: "+app.session.error);return [-1]
	var offers: Array=app.session.station_owner().snapshot().equipment.market_ships.duplicate(true)
	await capture_free_application("valkyrie-kothar-yard-%d"%int(app.session.station_owner().snapshot().campaign_cursor))
	if not app.equipment_action("close"):check(false,"The hangar did not close: "+app.session.error)
	return offers

## Fly at a transport and set off an EMP bomb beside it, as a player would.
func emp_transport(id: int,radio_ids: Array) -> bool:
	if not app.open_secondary_menu(now_us) or not app.session.confirm_secondary(41,now_us):check(false,"The secondary menu did not select the EMP bomb: "+app.status.text+app.session.error);return false
	app.present_session();resume_application_focus()
	var launched:=false
	for tick in 6000:
		var state: Dictionary=app.session.snapshot()
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if 2343 in radio_ids and app.session.flight_owner()._encounter.combat_snapshot().actors[4].active:return true
		var target: Dictionary=state.encounter.combat.actors[id]
		var gun: Dictionary={}
		for row in state.encounter.secondaries.guns:
			if int(row.equipment.item_id)==41:gun=row
		var distance: float=target.position.distance_to(state.player_pose.origin)
		var fire:=false
		if not launched and distance<1500.0 and int(gun.ammunition)>0 and int(gun.bomb.elapsed_ms)>int(gun.bomb.weapon.interval_ms):fire=true;launched=true
		elif launched and gun.bomb.get("shot",{}).get("phase")=="flying":fire=true
		elif launched and gun.bomb.get("shot",{}).get("phase")!="flying" and not target.get("systems_disabled",false):launched=false
		if fire and not app.session.action("missiles"):check(false,app.session.error);return false
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			var want:=1.0 if distance>1500.0 else 0.0
			if absf(current-want)<.01:break
			if not app.session.action("throttle_up" if current<want else "throttle_down"):check(false,app.session.error);return false
		now_us+=100000
		if not app.session.step(now_us,EmpSteering.steering_toward(state.player_pose,target.position)):check(false,app.session.error);return false
		app.present_session()
		if app.session.flight_owner().death_active():check(false,"The player died at the convoy");return false
		if tick%20==0:await process_frame
		if tick%300==0:print("VALKYRIE emp ",tick," distance ",int(distance)," hit ",target.get("systems_hit_serial")," disabled ",target.get("systems_disabled")," radio ",radio_ids)
	check(false,"The EMP never reached a transport: "+str(radio_ids))
	return false

## Local travel inside the current system, the Khador Drive otherwise.
func go_to(station: int) -> bool:
	if int(catalogue.tables.stations[station].system_id)==int(app.session.snapshot().location.system_id):return await travel_application(station)
	return await khador_jump(station)

## Fight the story cast like a player until done() holds; targets(actors)
## lists the actor ids to attack in order.
func fight_until(label: String,done: Callable,targets: Callable,radio_ids: Array,ticks:=30000,liberate:=false,standoff:=9000.0) -> bool:
	var pilot:=CombatPilot.new();var captured:=false;var closest:=INF
	if liberate and not select_liberator():return false
	for tick in ticks:
		if done.call():return true
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The player died in "+label+" at tick "+str(tick)+": "+str(state.player.vitals)+" nearest "+str(actors.map(func(actor):return [int(actor.position.distance_to(state.player_pose.origin)),int(actor.pose.origin.distance_to(state.player_pose.origin)),actor.get("firing_allowed"),actor.get("mode")])));return false
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		var input:=pilot.controls(state,tick,targets.call(actors),true)
		# Against many snipers, hold back and let the Liberators do the work.
		if standoff>9000.0 and input.distance>0 and input.distance<standoff:input.throttle=0.0
		var pool:=float(state.player.vitals.hull)+float(state.player.vitals.armor)+float(state.player.vitals.shield)
		if not captured and input.distance>0 and input.distance<6000:captured=true;await capture_free_application("valkyrie-"+label+"-fight")
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
		# With Liberators aboard, launch one at a target inside 9 km, fly it
		# to the nearest target and set it off close by, as a player would.
		var press:=false
		if liberate:
			var missile: Dictionary=liberator_shot(state)
			var aim: Array=targets.call(actors)
			if not missile.is_empty():
				aim.sort_custom(func(a,b):return actors[a].position.distance_squared_to(missile.position)<actors[b].position.distance_squared_to(missile.position))
				if aim.is_empty():press=true
				else:
					var gap: float=actors[aim[0]].position.distance_to(missile.position)
					input.commands=missile_steering(missile,actors[aim[0]].position);input.fire=false
					press=gap<1500.0 or gap>closest+500.0
					closest=minf(closest,gap)
			elif input.target>0 and input.distance<standoff and liberator_ready(state):press=true;closest=INF
		var key: InputEventKey
		if press:
			resume_application_focus();key=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=true;app._unhandled_input(key)
		now_us+=100000
		if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
		if key!=null:key.pressed=false;app._unhandled_input(key)
		app.present_session()
		if tick%20==0:await process_frame
		if tick%600==0:print("VALKYRIE ",label," ",tick," active ",actors.map(func(actor):return int(actor.get("active",false)))," hulls ",actors.map(func(actor):return int(actor.vitals.hull))," liberators ",int(liberator_gun(state).get("ammunition",-1))," target ",input.target," distance ",int(input.distance)," vitals ",state.player.vitals," radio ",radio_ids)
	check(false,label+" did not finish in time")
	return false

func hunt_convoy(station: int,radio_ids: Array) -> bool:
	var pilot:=CombatPilot.new();var captured:=false
	var liberators:=0;var closest:=INF
	if not select_liberator():return false
	for tick in 30000:
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		if int(actors[0].vitals.hull)<=0:break
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The player died at the convoy of "+str(station)+": "+str(state.player.vitals));return false
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		# Once the convoy turns, fight off the escorts, then take the transport.
		var escorts: Array=range(1,6).filter(func(id):return int(actors[id].vitals.hull)>0)
		var input:=pilot.controls(state,tick,escorts if actors[0].hostile and not escorts.is_empty() else [0],true)
		if not captured and input.distance>0 and input.distance<6000:captured=true;await capture_free_application("valkyrie-convoy-%d"%station)
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
		# Finish a damaged escort as a player would: R launches the Liberator,
		# the stick flies it at the nearest escort, a second R sets it off close by.
		var missile: Dictionary=liberator_shot(state)
		var press:=false
		if not missile.is_empty():
			var aim: Array=escorts.duplicate()
			aim.sort_custom(func(a,b):return actors[a].position.distance_squared_to(missile.position)<actors[b].position.distance_squared_to(missile.position))
			if aim.is_empty():press=true
			else:
				var gap: float=actors[aim[0]].position.distance_to(missile.position)
				input.commands=missile_steering(missile,actors[aim[0]].position);input.fire=false
				press=gap<1500.0 or gap>closest+500.0
				closest=minf(closest,gap)
		elif liberators<2 and actors[0].hostile and input.target>0 and input.distance<9000 and int(actors[input.target].vitals.hull)<=600 and liberator_ready(state):
			press=true;liberators+=1;closest=INF
		var key: InputEventKey
		if press:
			resume_application_focus();key=InputEventKey.new();key.physical_keycode=KEY_R;key.keycode=KEY_R;key.pressed=true;app._unhandled_input(key)
		now_us+=100000
		if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
		if key!=null:key.pressed=false;app._unhandled_input(key)
		app.present_session()
		if tick%20==0:await process_frame
		if tick%600==0:print("VALKYRIE convoy ",station," ",tick," target ",input.target," distance ",int(input.distance)," vitals ",state.player.vitals," radio ",radio_ids)
	check(int(app.session.flight_owner()._encounter.combat_snapshot().actors[0].vitals.hull)<=0,"The convoy transport at "+str(station)+" survived")
	for tick in 200:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if not application_step():return false
		if tick%10==0:await process_frame
	return failures==0

func select_liberator() -> bool:
	if app.session.snapshot().encounter.get("selected_secondary")==179:return true
	if not app.open_secondary_menu(now_us) or not app.session.confirm_secondary(179,now_us):check(false,"The secondary menu did not select the Liberator: "+app.status.text+app.session.error);return false
	app.present_session();resume_application_focus()
	return true

func liberator_gun(state: Dictionary) -> Dictionary:
	for gun in state.get("encounter",{}).get("secondaries",{}).get("guns",[]):
		if int(gun.equipment.item_id)==179:return gun
	return {}

func liberator_shot(state: Dictionary) -> Dictionary:
	var shot: Dictionary=liberator_gun(state).get("bomb",{}).get("shot",{})
	return shot if shot.get("phase")=="flying" else {}

func liberator_ready(state: Dictionary) -> bool:
	var gun:=liberator_gun(state)
	return not gun.is_empty() and int(gun.ammunition)>0 and int(gun.bomb.elapsed_ms)>int(gun.bomb.weapon.interval_ms)

## Stick toward a point in the missile's own frame, as for the ship:
## x pitches (down positive), y yaws (right positive).
static func missile_steering(missile: Dictionary,point: Vector3) -> Vector2:
	var local: Vector3=Basis(missile.basis).inverse()*(point-missile.position)
	var length:=maxf(local.length(),1.0)
	return Vector2(clampf(-4.0*local.y/length,-1.0,1.0),clampf(4.0*local.x/length,-1.0,1.0))

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
	if not app.confirm_map_planet(destination,now_us):check(false,"The drive map refused station "+str(destination)+": "+app.map_panel.error+" "+app.status.text+" destinations "+str(app.session.flight_owner()._navigation_destinations)+" drive "+str(app.session.flight_owner()._drive.snapshot().get("destinations",{}).keys())+" selected "+str(app.map_panel.snapshot().get("selected_station_id"))+" confirm "+str(app.map_panel.snapshot().get("confirmation_visible"))+" quote "+str(app.session.flight_owner().drive_quote(destination))+" diagnostic "+str(app.map_panel.snapshot().get("diagnostic")));return false
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
		"blueprint":return state.campaign_cursor==58
		"convoy":return state.campaign_cursor==59
		"call":return state.campaign_cursor==61
		"outpost":return state.campaign_cursor==63
		"distraction":return state.campaign_cursor==66
		"delivery":return state.campaign_cursor==66
		"trot":return state.campaign_cursor==69
		"teres","teres-lost":return state.campaign_cursor==73
		"escape78":return state.campaign_cursor==77
		"supernova":return state.campaign_cursor==84
		"supernova89":return state.campaign_cursor==89
		"supernova91":return state.campaign_cursor==91
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
