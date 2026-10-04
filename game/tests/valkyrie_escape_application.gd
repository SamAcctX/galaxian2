extends "res://tests/valkyrie_start_application.gd"
const StoryFlights=preload("res://src/content/valkyrie_flight_definitions.gd")
const CombatPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const EmpSteering=preload("res://tests/fixtures/expedition_flight_pilot.gd")
const StationSaveFile=preload("res://src/simulation/station_save_file.gd")
## Valkyrie opening chain from the earned call: Kanado talk, the Vossk loan
## ship to B'akrram and the K'Suukk handover, then the escape flights.

func verify_free_application() -> void:
	var staged:=OS.get_environment("GOF2_VALKYRIE_STAGE")
	# A newer extraction attaches as an import update, as the game does on
	# launch, keeping the saved identity (payload-material meshes).
	var update:=OS.get_environment("GOF2_IMPORT_UPDATE")
	if not update.is_empty():
		for owner in [app.bindings,definitions]:
			if owner!=null and owner.import_update_receipt().is_empty() and not owner.attach_import_update(update,app.library.manifest,app.library):check(false,"Import update: "+owner.error);return
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
	if staged=="supernova93":await fly_supernova_luur()
	if staged=="supernova97":await fly_supernova_genoh()
	if staged=="supernova100":await fly_supernova_stealth()
	if staged=="supernova102":await fly_supernova_tadram()
	if staged=="supernova105":await fly_supernova_bomb()
	if staged=="supernova109":await fly_supernova_bars()
	if staged=="supernova117":await fly_supernova_meenkk()
	if staged=="supernova128":await fly_supernova_wanted()
	if staged=="supernova135":await fly_supernova_coromesk()
	if staged=="kaamo":await fly_kaamo_siege()
	if staged=="pirate-base":await fly_pirate_base()
	if staged=="loma":await fly_loma_toll()
	if staged=="weapons":await fly_dlc_weapons()
	if staged=="supernova141":await fly_supernova_finale()
	if staged=="supernova154":await fly_supernova_ambush()
	if staged=="supernova160":await fly_supernova_end()
	if staged=="bounty":await fly_supernova_bounty()

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
			if absf(current-float(input.throttle))<.01 or not app.session.can_control():break
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
		# Top up an existing stack (one hangar row per item), else add a new one.
		var stack: Array=entries.filter(func(entry):return int(entry.item_id)==int(row[0]) and not entry.get("mission",false))
		if not stack.is_empty():stack[0].quantity=int(stack[0].quantity)+int(row[1])
		else:
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
	# Test shortcut: the top shield and armour a long career would have; the
	# scripted pilot does not outlast the transport's two turrets otherwise.
	var top:=top_protection()
	if failures or not seed_cargo(top.map(func(id):return [id,1])) or not fit_same_type(top):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var radio_ids:=[]
	for station in [56,45,22]:
		if not await khador_jump(station):return
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		print("VALKYRIE convoy ",station," cast ",actors.map(func(actor):return [actor.hull_catalogue_id,actor.actor_kind,actor.population_group,actor.hostile]))
		check(actors.size()==8 and actors[0].population_group=="freighter" and actors.slice(6).all(func(actor):return actor.get("static_object",false)) and actors.all(func(actor):return not actor.hostile),"The convoy at "+str(station)+" differs from its recipe")
		if failures or not await hunt_convoy(station,radio_ids):return
		# The transport's two turrets go with it (when its radio line starts).
		var turrets_gone:=false
		for tick in 900:
			var left: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
			turrets_gone=left.size()<8 or left.slice(6).all(func(actor):return int(actor.vitals.hull)<=0 or not actor.get("model_draw_enabled",true))
			if turrets_gone:break
			if not application_step():return
			if tick%10==0:await process_frame
		check(turrets_gone,"The convoy turrets at "+str(station)+" outlived the transport")
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
	if failures or not await khador_jump(100) or not await hear_lines("kothar-62",[2198]) or not await dock_application() or not await take_station_talk(62,63):return
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
	# A Supernova career keeps its drive and fittings: no hull with fewer slots.
	if OS.get_environment("GOF2_VALKYRIE_STAGE").begins_with("supernova"):
		var slots: int=int(catalogue.tables.ships[int(quote.loadout.ship_id)].stats.equipment_slots)
		offers=offers.filter(func(row):return int(catalogue.tables.ships[row.ship_id].stats.equipment_slots)>=slots)
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
		# Supernova careers already carry guns: make room for the better ones.
		if OS.get_environment("GOF2_VALKYRIE_STAGE").begins_with("supernova"):
			var slots: Array=app.session.station_owner().snapshot().loadout.slots
			for index in range(slots.size()-1,-1,-1):
				if slots[index]!=null and int(catalogue.tables.items[int(slots[index].item_id)].properties.get(1,-1))==0 and int(slots[index].item_id)!=int(gun.item_id):
					if not app.equipment_action("unmount",int(slots[index].item_id),index):print("VALKYRIE unmount refused ",app.session.error)
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
	check(fitted.loadout.equipment_ids.has(85) or int(fitted.loadout.ship_id) in [37,38,40],"The refit lost the Khador Drive")
	check(fitted.loadout.equipment_ids.has(179) or OS.get_environment("GOF2_VALKYRIE_STAGE").begins_with("supernova"),"The refit did not mount the Liberators from the hold")
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
	if failures or not await khador_jump(100,false):return
	var khador: Dictionary=app.session.flight_owner()._encounter.combat_snapshot().actors[0] if app.session.flight_owner()._encounter!=null else {}
	check(int(khador.get("hull_catalogue_id",-1))==38 and khador.get("friendly",false) and khador.pose.origin.distance_to(app.session.snapshot().player_pose.origin)<6000,"Khador's Typhon is not beside the player at Kothar: "+str(khador.get("hull_catalogue_id")))
	if failures or not await release_application_flight() or not await hear_lines("kothar-65",[2240,2241,2242]):return
	check(not app.session.flight_owner().drive_permits_mission(),"The Khador Drive is not refused at Kothar during 65")
	if failures or not await dock_application() or not await take_station_talk(65,66):return
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
	# Test shortcut: the launcher refilled to ten (the Valkyrie builds them),
	# plus the top shield and armour a long career would have found; the
	# scripted pilot cannot outlast the reserve wave on the Kothar-era stock.
	var top:=top_protection()
	if failures or not seed_cargo([[122,12],[179,4]]+top.map(func(id):return [id,1]),3000000) or not outfit_for_combat() or not fit_same_type(top):return
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
		await watch_cutscene("leaving")
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
	# Test shortcut: the top shield and armour a long career would have; the
	# scripted pilot cannot outlast Kothar's fighters under turret fire.
	var top:=top_protection()
	if not seed_cargo(top.map(func(id):return [id,1])) or not fit_same_type(top):return
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
		func(list):return range(1,19).filter(func(id):return int(list[id].vitals.hull)>0),battle_radio,60000,true,30000.0,-1,0):return
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
		await watch_cutscene("story")
		tick+=1
		if tick%10==0:await process_frame
	print("VALKYRIE story jump status ",app.session.status," cursor ",app.session.snapshot().campaign_cursor," radio ",radio_ids)
	check(app.session.status in ["drive_arrival_transition_required","local_arrival_transition_required"],"The story's drive jump did not happen: "+app.session.status+" "+app.status.text)
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
		await watch_cutscene("tadram92")
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

## 93: fly to Midantha for Bargand's talk (a Gamma Shield I in the hold);
## fit it. 94: jump to Luur, ferry the 83 people from the platform to the
## freighter while the raiders come in three pairs; Bargand's lines; the story
## takes the ship to Thynome (95).
func fly_supernova_luur() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==93,"The Luur checkpoint is not at cursor 93")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	# Carla's nag call (stage 93) about 12 s into an ordinary flight, once.
	var nag:=[]
	for tick in 350:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in nag:nag.append(int(radio.text_id))
		if not application_step():return
		if tick%10==0:await process_frame
	print("SUPERNOVA nag radio ",nag," progress ",app.session.flight_owner()._objective._contracts.snapshot().progress.get("nag_heard"))
	check(3157 in nag and 3158 in nag,"Carla's nag call did not play: "+str(nag))
	if failures or not await khador_jump(114) or not await dock_application() or not await take_station_talk(93,94):return
	var hold: Dictionary=app.session.station_owner().snapshot().get("cargo",{})
	print("SUPERNOVA Midantha hold ",hold)
	check(int(app.session.station_owner().snapshot().contracts.progress.get("nag_heard",-1))==93,"Carla's call was not kept as heard")
	if not await fit_item(205):return
	# The 83 must move within the shielded gamma budget: carry as many as fit.
	if not seed_cargo([],2000000) or not await fit_cabins(83,true):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(111):return
	var radio_ids:=[];var raiders:=0;var moved_seen:=0;var rate_seen:=false
	var began:=now_us
	app.session.rebase_time(now_us)
	for tick in 60000:
		if app.session.status!="running" or app.session.flight_owner()._objective.snapshot().campaign_cursor!=94:break
		var frame: RefCounted=app.session.flight_owner()
		var radio: Dictionary=frame._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if frame.death_active():check(false,"The pilot died at Luur: gamma "+str(frame._player.snapshot().get("gamma"))+" vitals "+str(frame._player.snapshot().vitals)+" dock "+str(frame._story_dock));return
		var state: Dictionary=app.session.snapshot()
		var dock: Dictionary=frame._story_dock
		if not rate_seen:rate_seen=true;print("SUPERNOVA Luur gamma rate ",frame._gamma_rate," berths ",dock.get("berths")," status ",dock.get("status"));await capture_free_application("supernova-luur")
		var actors: Array=frame._encounter.combat_snapshot().actors
		var moved: int=83-int(dock.get("status",83))
		if moved>=moved_seen+20:moved_seen=moved;print("SUPERNOVA Luur moved ",moved," at ",(now_us-began)/1000000," s gamma ",state.player.get("gamma")," radio ",radio_ids)
		# Awake raiders near the ship: fight them off first.
		var awake: Callable=func():
			var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
			var pose: Vector3=app.session.snapshot().player_pose.origin
			return range(1,7).filter(func(id):return int(cast[id].vitals.hull)>0 and cast[id].get("active",false) and cast[id].pose.origin.distance_to(pose)<12000.0)
		if not awake.call().is_empty() and not frame.cinematic_input_blocked():
			raiders+=awake.call().size()
			if raiders<=2:await capture_free_application("supernova-luur-raiders")
			var over:=func():return app.session.status!="running" or app.session.flight_owner()._objective.snapshot().campaign_cursor!=94
			if not await fight_until("luur",func():return over.call() or awake.call().is_empty(),func(_actors):return awake.call(),radio_ids):return
			print("SUPERNOVA Luur raiders cleared at ",(now_us-began)/1000000," s")
			continue
		var cap:=mini(int(dock.berths),int(dock.status))
		var steer:=Vector2.ZERO;var want:=0.0
		if int(dock.status)>0:
			var goal:=0 if int(dock.aboard)==0 or (int(dock.docked)==0 and int(dock.aboard)<cap) else 7
			var target: Vector3=actors[goal].get("pose",Transform3D()).origin
			var distance: float=state.player_pose.origin.distance_to(target)
			steer=EmpSteering.steering_toward(state.player_pose,target);want=1.0 if distance>2000.0 else 0.0
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-want)<.01 or frame.cinematic_input_blocked():break
			if not app.session.action("throttle_up" if current<want else "throttle_down"):check(false,app.session.error);return
		now_us+=100000
		if not app.session.step(now_us,steer if not frame.cinematic_input_blocked() else Vector2.ZERO):check(false,app.session.error);return
		app.present_session()
		await watch_cutscene("luur94")
		await dismiss_medal()
		if tick%20==0:await process_frame
	print("SUPERNOVA Luur radio ",radio_ids," status ",app.session.status," cursor ",app.session.snapshot().campaign_cursor," raiders ",raiders," in ",(now_us-began)/1000000," s")
	check(range(2530,2536).all(func(id):return id in radio_ids) and 2543 in radio_ids and raiders>=6,"The Luur evacuation did not play through")
	var waited:=now_us
	while app.session.status=="running" and now_us-waited<30000000:
		await dismiss_medal()
		if not application_step():return
	# The cutaway holds the ship from the start: no controls to release.
	if not await enter_story_arrival("Luur",false):return
	# 95: the cutaway at Thynome plays with the ship held; then on to Alioth.
	check(int(app.session.snapshot().location.station_id)==10 and app.session.snapshot().campaign_cursor==95,"The ship did not arrive at Thynome for 95")
	await capture_free_application("supernova-thynome-95")
	if failures:return
	var heard:=[]
	if not await ride_story_jump(heard,300):return
	print("SUPERNOVA Thynome cutaway radio ",heard)
	check(2544 in heard and heard.size()>=17,"The Thynome cutaway did not play through")
	if failures or not await enter_story_arrival("Thynome"):return
	check(int(app.session.snapshot().location.station_id)==98 and app.session.snapshot().campaign_cursor==96,"The ship did not arrive at Alioth for 96: "+str([app.session.snapshot().location.station_id,app.session.snapshot().campaign_cursor]))
	await capture_free_application("supernova-alioth-96")
	if failures or not await dock_application() or not await take_station_talk(96,97):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Alioth failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==97,"Fresh Resume lost Brent's talk at Alioth")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-97.gof2save"))==OK,"The Alioth checkpoint could not be kept")

## Take the story's move out of a finished flight (drive or local arrival).
func enter_story_arrival(label: String,release:=true) -> bool:
	match app.session.status:
		"drive_arrival_transition_required":check(app.enter_drive_arrival(now_us,4096,flight_world_seconds()),app.status.text)
		"local_arrival_transition_required":check(app.enter_local_arrival(now_us,4096,flight_world_seconds()),app.status.text)
		_:check(false,"The story did not take the ship on after "+label+": "+app.session.status)
	if not release:return failures==0
	return failures==0 and await release_application_flight()

## 97: the pirate battle at Genoh (12 pirates beside Nivelian ships); 98:
## Harval's talk at Katashán; 99: the Thynome cutaway; 100: docked at Katashán.
func fly_supernova_genoh() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==97,"The Genoh checkpoint is not at cursor 97")
	# Test shortcut: the money the career would have earned, spent on protection,
	# plus the top shield and armour a long career would have found by now.
	var top:=top_protection()
	if failures or not seed_cargo([[85,1]]+top.map(func(id):return [id,1]),5000000) or not await outfit_for_combat() or not fit_same_type(top):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(85):return
	var radio_ids:=[]
	var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("SUPERNOVA Genoh cast ",cast.map(func(actor):return [actor.actor_kind,actor.hull_catalogue_id,int(actor.vitals.hull)]))
	await capture_free_application("supernova-genoh")
	var pirates:=func(): return range(0,12).filter(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)>0)
	if not await fight_until("genoh",func():return pirates.call().is_empty(),func(_actors):return pirates.call(),radio_ids):return
	if not await wait_story_cursor(98,"supernova-genoh-won"):return
	var heard:=[]
	for tick in 1200:
		if app.session.status!="running":break
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
		if not application_step():return
		if tick%10==0:await process_frame
	print("SUPERNOVA Genoh radio ",radio_ids," after ",heard)
	if not await khador_jump(120) or not await dock_application() or not await take_station_talk(98,99):return
	# 99: the story takes the ship to Thynome for the cutaway, then docks it at Katashán (100).
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var moved:=[]
	if not await ride_story_jump(moved,30) or not await enter_story_arrival("Katashán",false):return
	check(int(app.session.snapshot().location.station_id)==10 and app.session.snapshot().campaign_cursor==99,"The ship did not arrive at Thynome for 99")
	await capture_free_application("supernova-thynome-99")
	var scene:=[]
	if not await ride_story_jump(scene,300):return
	print("SUPERNOVA Thynome 99 radio ",scene)
	check(2589 in scene and scene.size()>=13,"The 99 cutaway did not play through")
	if failures or not await enter_story_arrival("Thynome"):return
	check(int(app.session.snapshot().location.station_id)==120 and app.session.snapshot().campaign_cursor==100,"The ship did not come to Katashán for 100: "+str([app.session.snapshot().location.station_id,app.session.snapshot().campaign_cursor]))
	if failures or not await dock_application():return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Katashán failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==100,"Fresh Resume lost the 99 cutaway")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-100.gof2save"))==OK,"The Katashán checkpoint could not be kept")

## 100-101: two stealth fighters ambush the player at Alioth; then Brent's
## talk puts the Nirai SPP-C1 in the hold for the Tadram evacuation.
func fly_supernova_stealth() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==100,"The Alioth checkpoint is not at cursor 100")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(98):return
	var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("SUPERNOVA Alioth cast ",cast.map(func(actor):return [actor.actor_kind,actor.hull_catalogue_id,int(actor.vitals.hull),int(actor.pose.origin.distance_to(app.session.snapshot().player_pose.origin))]))
	await capture_free_application("supernova-alioth-stealth")
	var radio_ids:=[];var cloaked:=[]
	var stealth:=func():
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		for id in 2:
			if actors[id].get("cloaked",false) and id not in cloaked:cloaked.append(id)
		return range(0,2).filter(func(id):return int(actors[id].vitals.hull)>0)
	if not await fight_until("alioth-stealth",func():return stealth.call().is_empty(),func(_actors):return stealth.call(),radio_ids):return
	print("SUPERNOVA Alioth radio ",radio_ids," cloaked ",cloaked)
	check(2602 in radio_ids and 2603 in radio_ids,"Keith's two ambush lines did not play")
	check(not cloaked.is_empty(),"The stealth fighters never cloaked")
	if not await wait_story_cursor(101,"supernova-alioth-won"):return
	if not await dock_application() or not await take_station_talk(101,102):return
	print("SUPERNOVA hold after 101 ",app.session.station_owner().snapshot().cargo.entries.map(func(row):return [row.item_id,row.quantity]))
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Alioth failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==102,"Fresh Resume lost Brent's talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-102.gof2save"))==OK,"The Alioth checkpoint could not be kept")

## 102-104: the Tadram carrier evacuation (dropships ferry 1700 people while
## stealth fighters attack), Khador's plan at Thynome and the Gamma Shield II
## built from its blueprint and handed over.
func fly_supernova_tadram() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==102,"The Tadram checkpoint is not at cursor 102")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(113):return
	var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("SUPERNOVA Tadram cast ",cast.map(func(actor):return [actor.actor_kind,actor.hull_catalogue_id,int(actor.vitals.hull)]))
	await capture_free_application("supernova-tadram-carrier")
	var radio_ids:=[];var first_status:=int(app.session.flight_owner()._story_dock.get("status",-1))
	var fighters:=func():
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		return range(6,10).filter(func(id):return int(actors[id].vitals.hull)>0 and actors[id].get("active",false) and actors[id].pose.origin.distance_to(app.session.snapshot().player_pose.origin)<60000)
	var over:=func():return app.session.status!="running" or app.session.snapshot().campaign_cursor!=102
	var captured:=false
	for tick in 60000:
		if over.call():break
		if app.session.flight_owner().death_active():check(false,"The player died at Tadram: "+str(app.session.snapshot().player.vitals));return
		if not fighters.call().is_empty():
			if not captured:captured=true;await capture_free_application("supernova-tadram-fighters")
			if not await fight_until("tadram",func():return over.call() or fighters.call().is_empty(),func(_actors):return fighters.call(),radio_ids):return
			continue
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if not application_step():return
		await watch_cutscene("tadram102")
		if tick%10==0:await process_frame
		if tick%600==0:print("SUPERNOVA Tadram ",tick/10," s status ",app.session.flight_owner()._story_dock.get("status")," radio ",radio_ids)
	print("SUPERNOVA Tadram radio ",radio_ids," status ",first_status," -> ",app.session.flight_owner()._story_dock.get("status"))
	check(first_status==1700,"Tadram did not start with 1700 people waiting")
	check(2621 in radio_ids,"Everyone's-on-board line did not play")
	if not await wait_story_cursor(103,"supernova-tadram-done"):return
	if not await khador_jump(10) or not await dock_application() or not await take_station_talk(103,104):return
	# The Gamma Shield II blueprint (10 Hypanium supplied); the test supplies the rest.
	var state: Dictionary=app.session.station_owner().snapshot()
	var project: Array=state.contracts.blueprints.entries.filter(func(row):return row.item_id==206)
	check(not project.is_empty() and project[0].available,"Khador's plan did not hand over the Gamma Shield II blueprint")
	if failures:return
	var materials: Array=Array(catalogue.tables.items[206].arrays[0]);var seeds:=[]
	for index in materials.size():
		if int(project[0].remaining[index])>0:seeds.append([int(materials[index]),int(project[0].remaining[index])])
	print("SUPERNOVA blueprint 206 remaining ",project[0].remaining," seeds ",seeds)
	if not seed_cargo(seeds) or not app.equipment_action("open"):check(false,app.session.error);return
	for row in seeds:
		if not app.equipment_action("supply_blueprint",206,row[0],row[1]):check(false,"Supplying material "+str(row[0])+" failed: "+app.session.error);return
	if not app.equipment_action("close"):check(false,app.session.error);return
	check(app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==206),"The Gamma Shield II was not built")
	if failures or not await take_station_talk(104,105):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Thynome failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==105,"Fresh Resume lost the Gamma Shield II hand-over")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-105.gof2save"))==OK,"The Thynome checkpoint could not be kept")

## 105-108: the Naneroh bomb run (Gamma Shield II fitted, fly toward the sun,
## stealth fighters on the way, "Bombs away!"), the Luur aftermath scene,
## then Thynome and Carla's talk.
func fly_supernova_bomb() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==105,"The Naneroh checkpoint is not at cursor 105")
	if failures or not fit_same_type([206]):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	# Leaving Thynome away from Naneroh: drive there (Carla's nag call may
	# already hold this ordinary flight's story slot).
	if int(app.session.snapshot().location.station_id)!=109:
		for t in 600:
			if app.session.can_control() or not application_step():break
			if t%10==0:await process_frame
		check(app.session.can_control(),"The Thynome launch did not release the controls")
		if failures or not await khador_jump(109,false):return
	await capture_free_application("supernova-naneroh-route")
	var radio_ids:=[];var captured:=false;var press_on_us:=0
	var fighters:=func():
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		return range(2,mini(5,actors.size())).filter(func(id):return int(actors[id].vitals.hull)>0 and actors[id].get("active",false) and actors[id].pose.origin.distance_to(app.session.snapshot().player_pose.origin)<30000)
	var over:=func():return app.session.status!="running" or app.session.snapshot().campaign_cursor!=105
	for tick in 40000:
		if over.call():break
		if app.session.flight_owner().death_active():check(false,"The player died at Naneroh: "+str(app.session.snapshot().player.vitals)+" gamma "+str(app.session.snapshot().get("gamma")));return
		# Gamma keeps draining: fight for at most 25 s, then press on 25 s.
		if now_us>=press_on_us and not fighters.call().is_empty():
			if not captured:captured=true;await capture_free_application("supernova-naneroh-fighters")
			var engaged:=now_us
			if not await fight_until("naneroh",func():return over.call() or fighters.call().is_empty() or now_us-engaged>25000000,func(_actors):return fighters.call(),radio_ids):return
			press_on_us=now_us+25000000
			continue
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		# Head for the route's end at full throttle.
		var state: Dictionary=app.session.snapshot()
		var point: Variant=app.session.flight_owner().story_route_point()
		var commands:=Vector2.ZERO
		if point is Vector3:commands=missile_steering({"basis":state.player_pose.basis,"position":state.player_pose.origin},point)
		for adjustment in 10:
			if app.session.snapshot().input_throttle>=.99 or not app.session.action("throttle_up"):break
		now_us+=100000
		if not app.session.step(now_us,commands,false,false,0.0):check(false,app.session.error);return
		app.present_session()
		await watch_cutscene("naneroh105")
		if tick%10==0:await process_frame
		if tick%300==0:print("SUPERNOVA Naneroh ",tick/10," s to go ",int(state.player_pose.origin.distance_to(point)) if point is Vector3 else -1," radio ",radio_ids," vitals ",state.player.vitals," gamma ",state.player.get("gamma"))
	print("SUPERNOVA Naneroh radio ",radio_ids)
	check(2654 in radio_ids,"Bombs away did not play")
	if failures or not await wait_story_cursor(106,"supernova-bombs-away"):return
	# The bomb set off the supernova: Ginoya's sun has swollen.
	check(app.session.scene.planets!=null and float(app.session.scene.planets._layout.get("sun_swell",1.0))>1.3,"The sun did not swell after the Naneroh bomb")
	await capture_free_application("supernova-naneroh-sun")
	var moved:=[]
	if not await ride_story_jump(moved,120) or not await enter_story_arrival("Naneroh",false):return
	check(int(app.session.snapshot().location.station_id)==111,"The story did not take the ship to Luur for 106")
	await capture_free_application("supernova-luur-106")
	var scene:=[]
	if not await ride_story_jump(scene,300):return
	print("SUPERNOVA Luur 106 radio ",scene)
	check(2660 in scene,"The 106 scene did not play through")
	if failures or not await enter_story_arrival("Luur"):return
	check(int(app.session.snapshot().location.station_id)==10 and app.session.snapshot().campaign_cursor==108,"The story did not bring the ship to Thynome for 108: "+str([app.session.snapshot().location.station_id,app.session.snapshot().campaign_cursor]))
	if failures or not await dock_application() or not await take_station_talk(108,109):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Thynome failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==109,"Fresh Resume lost Carla's talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-109.gof2save"))==OK,"The 109 checkpoint could not be kept")

## 109-116: the Midantha cutaway, the bar trail (Thynome, Nepis with the
## Magnetar Juice, Plural Z), the Marktesh asteroid ambush and the Maissa
## bar hunt that opens Me'enkk (117).
func fly_supernova_bars() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==109,"The Thynome checkpoint is not at cursor 109")
	# Test shortcut: the Magnetar Juice 112 asks for (bought on the way in play).
	if failures or not seed_cargo([[146,1],[122,12]]) or not fit_best_guns():return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var moved:=[]
	if not await ride_story_jump(moved,30) or not await enter_story_arrival("Thynome",false):return
	check(int(app.session.snapshot().location.station_id)==114 and app.session.snapshot().campaign_cursor==109,"The ship did not arrive at Midantha for 109")
	await capture_free_application("supernova-midantha-109")
	var scene:=[]
	if not await ride_story_jump(scene,300):return
	print("SUPERNOVA Midantha 109 radio ",scene)
	check(scene.size()>=4,"The 109 cutaway did not play through")
	if failures or not await enter_story_arrival("Midantha"):return
	check(int(app.session.snapshot().location.station_id)==10 and app.session.snapshot().campaign_cursor==110,"The story did not bring the ship to Thynome for 110")
	if failures or not await dock_application() or not await take_station_talk(110,111):return
	for leg in [[38,111,112],[38,112,113],[82,113,114]]:
		# A follow-on talk at the same station opens a moment after the last.
		var clock:=Time.get_ticks_usec()
		for tick in 30:
			if docked_station()!=leg[0] or app.session.snapshot().dialogue.visible:break
			clock+=100000;app.session.step(clock);app.present_session();await process_frame
		if docked_station()!=leg[0] or not app.session.snapshot().dialogue.visible:
			if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
			if not await release_application_flight():return
			if int(app.session.snapshot().location.station_id)!=leg[0] and not await khador_jump(leg[0]):return
			if not await dock_application():return
		if not await take_station_talk(leg[1],leg[2]):return
		if leg[1]==112:check(not app.session.station_owner().snapshot().cargo.entries.any(func(row):return int(row.item_id)==146),"The Magnetar Juice stayed in the hold after 113 began")
	# 114: six pirates asleep at Marktesh's asteroids; they wake as the player nears.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(83):return
	await capture_free_application("supernova-marktesh")
	var radio_ids:=[]
	var pirates:=func(): return range(0,6).filter(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)>0)
	if not await fight_until("marktesh",func():return pirates.call().is_empty(),func(_actors):return pirates.call(),radio_ids):return
	print("SUPERNOVA Marktesh radio ",radio_ids)
	if not await wait_story_cursor(115,"supernova-marktesh-won"):return
	if not await khador_jump(82) or not await dock_application() or not await take_station_talk(115,116):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await khador_jump(93) or not await dock_application() or not await take_station_talk(116,117):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Maissa failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==117,"Fresh Resume lost the Flabbergaster talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-117.gof2save"))==OK,"The 117 checkpoint could not be kept")

## 117-127: Me'enkk and the Mutagen (117-118), the Thynome cutaway (119),
## the Valadon stealth pair (120), Maissa and Thynome (121-122), Névan
## (123-124), the Kappa black box with three container hacks (125), the
## Katashán cutaway (126) and Alioth's talk that opens the Wanted boards.
func fly_supernova_meenkk() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==117,"The Maissa checkpoint is not at cursor 117")
	# Test shortcut (as at Genoh): a long career's money spent on the
	# toughest hull on sale, top shield and armour, and the best guns.
	var top:=top_protection()
	if failures or not seed_cargo([[122,12]]+top.map(func(id):return [id,1]),7000000) or not await outfit_for_combat() or not fit_same_type(top) or not fit_best_guns():return
	if not await travel_and_talk(126,117,118):return
	# 118: the Mutagen is on sale here (a story offer); buying it completes 118.
	var bought: bool=app.equipment_action("open") and app.equipment_action("buy",209)
	print("SUPERNOVA Mutagen bought ",bought," ",app.session.error)
	check(bought,"The Mutagen (209) was not on sale at Bak S'ondorr")
	# Closing the shop re-checks the station: 118's talk opens without undocking.
	app.equipment_action("close")
	if failures or not await take_station_talk(118,119):return
	# 119: the Thynome cutaway, then docked back at Bak S'ondorr (120).
	if not await story_cutaway(10,126,120,"supernova-thynome-119"):return
	# 120: two stealth fighters at Valadon; done when Keith's line ends. The
	# Mutagen aboard is volatile: the Khador Drive refuses, so go by gates.
	if not await story_route(40,false):return
	var radio_ids:=[]
	var stealth:=func():return range(0,2).filter(func(id):return int(app.session.flight_owner()._encounter.combat_snapshot().actors[id].vitals.hull)>0)
	await capture_free_application("supernova-valadon")
	# With the Mutagen aboard every jerk of the stick shakes it: hold course
	# and let the stealth pair's scene play out (it ends on Keith's line).
	print("SUPERNOVA Valadon stealth ",stealth.call())
	if not await wait_story_cursor(121,"supernova-valadon-done"):return
	if not await dock_application():return
	for leg in [[93,121,122],[10,122,123]]:
		# Gates only while the volatile Mutagen is aboard; the drive otherwise.
		var volatile: bool=app.session.station_owner().snapshot().cargo.entries.any(func(row):return int(row.item_id) in [204,209])
		if not (await story_route(leg[0]) if volatile else await travel_and_talk(leg[0],leg[1],leg[2])):return
		if volatile and not await take_station_talk(leg[1],leg[2]):return
		if leg[1]==122:check(not app.session.station_owner().snapshot().cargo.entries.any(func(row):return int(row.item_id)==209),"The Mutagen stayed in the hold after 122")
	# 123: Névan, four lines in flight; 124 the talk there.
	if not await depart_to(121) or not await wait_story_cursor(124,"supernova-nevan"):return
	if not await dock_application() or not await take_station_talk(124,125):return
	# Two of Keith's search sites first: each gives an opener and "no reading".
	for site in [[40,2],[45,3]]:
		if not await depart_to(site[0]):return
		var heard:=[]
		for tick in 250:
			var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
			if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
			if not application_step():return
			if tick%10==0:await process_frame
		# The opener can finish during arrival, before this loop listens.
		var finished: Array=app.session.flight_owner()._radio.snapshot().get("finished",[])
		print("SUPERNOVA search site ",site[0]," radio ",heard," finished ",finished)
		check((finished.size()==2 and finished[0]==true or heard.any(func(id):return id>=2793 and id<=2796)) and heard.any(func(id):return id>=2799 and id<=2802),"Station %d gave no search lines"%site[0])
		if failures or not await dock_application():return
		check(int(app.session.station_owner().snapshot().contracts.progress.get("story_stations_mask",0)) & (1<<site[1]),"Station %d was not marked searched"%site[0])
		if failures:return
	if not await depart_to(55) or not await kappa_black_box():return
	# 126: launched at Katashán for the cutaway, then Alioth's gate (127).
	var scene:=[]
	if not await ride_story_jump(scene,300):return
	print("SUPERNOVA Katashán 126 radio ",scene)
	if failures or not await enter_story_arrival("Kappa",false):return
	check(int(app.session.snapshot().location.station_id)==120,"The story did not launch the ship at Katashán for 126")
	await capture_free_application("supernova-katashan-126")
	scene=[]
	if not await ride_story_jump(scene,300) or not await enter_story_arrival("Katashán"):return
	check(int(app.session.snapshot().location.station_id)==98 and app.session.snapshot().campaign_cursor==127,"The story did not bring the ship to Alioth for 127")
	if failures or not await dock_application() or not await take_station_talk(127,128):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Alioth failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==128,"Fresh Resume lost Alioth's talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-128.gof2save"))==OK,"The 128 checkpoint could not be kept")

## 128-134: at a Terran station the Most Wanted board lists Pal Tyyrt; the
## pilot flies to where the board's criminal is, beats him below a third of
## his hull and he gives up (128 -> 130); the same for Kehnor (130 -> 131).
## Then Var Lupra (131-132), the Katashán cutaway (133) and Dekato (134).
const TERRAN_BOARD_STATION:=5
## A Terran board station in a system this career knows (the drive only
## reaches known systems); the docked station when it is one.
func terran_board_station() -> int:
	var document: Dictionary=StationSaveFile.new().read_document(app.station_save_path())
	var known: Array=find_value(document,"system_availability")
	var race_of:=func(id):return int(catalogue.tables.systems[int(catalogue.tables.stations[id].system_id)].fields[2])
	var race: int=race_of.call(TERRAN_BOARD_STATION)
	var ids: Array=[docked_station()]+range(catalogue.tables.stations.size())
	for id in ids:
		var system:=int(catalogue.tables.stations[id].system_id) if id>=0 else -1
		if system>=0 and system<known.size() and known[system] and race_of.call(id)==race and id!=load("res://src/simulation/wanted_board.gd").CLOSED_STATION:return id
	return TERRAN_BOARD_STATION

static func find_value(value: Variant,key: String) -> Variant:
	if value is Dictionary:
		if value.has(key):return value[key]
		for child in value.values():
			var found: Variant=find_value(child,key)
			if found!=null:return found
	elif value is Array:
		for child in value:
			var found: Variant=find_value(child,key)
			if found!=null:return found
	return null

## Kaamo Club siege (from the earned 135 save): the drive to Shima, four
## pirate outposts and six pirates, Mkkt Bkkt's call; pirates come back while
## an outpost stands; all ten down -> his thanks, kaamo_state 1, docking at
## the club, save and fresh Resume. The pilot is kept unharmed (shortcut).
const KAAMO:=108
func fly_kaamo_siege() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if not seed_cargo([[122,12]]) or not await depart_to(KAAMO):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("KAAMO cast ",actors.map(func(actor):return [actor.get("static_object",false),int(actor.vitals.hull),String(actor.get("display_name",""))]))
	check(actors.size()==10 and range(4).all(func(id):return actors[id].get("static_object",false)) and range(4,10).all(func(id):return not actors[id].get("static_object",false)),"The Kaamo siege cast is not four outposts and six pirates")
	if failures:return
	await capture_free_application("kaamo-siege")
	var radio_ids:=[]
	# Like a player: break the outposts (which keep calling pirates in), then the rest.
	var standing:=func(list):
		var alive:=range(list.size()).filter(func(id):return int(list[id].vitals.hull)>0)
		var outposts:=alive.filter(func(id):return id<4)
		return outposts if not outposts.is_empty() else alive
	if not await fight_until("kaamo",func():return 447 in radio_ids or app.session.status!="running",standing,radio_ids,60000):return
	print("KAAMO radio ",radio_ids)
	check(446 in radio_ids and 447 in radio_ids,"Mkkt Bkkt's call or thanks did not play")
	for tick in 300:
		if app.session.status!="running" or app.session.flight_owner()._radio.snapshot().get("visible",false)==false:break
		now_us+=100000
		if not app.session.step(now_us,Vector2.ZERO,false,false,0.0):check(false,app.session.error);return
		if tick%10==0:await process_frame
	await capture_free_application("kaamo-won")
	if failures or not await dock_application():return
	check(docked_station()==KAAMO,"The club did not open for docking after the siege")
	check(int(app.session.station_owner().snapshot().contracts.progress.get("kaamo_state",0))>=1,"The career did not keep the rescued club")
	# Mkkt Bkkt's first-visit talk, then the purchase offer once 30 M and 50 t Buskat are aboard.
	if failures or not await kaamo_talk(448,18,"kaamo-talk"):return
	check(int(app.session.station_owner().snapshot().contracts.progress.get("kaamo_state",0))==2,"The first talk did not open the club offer")
	check(app.load_station() and int(app.session.station_owner().snapshot().contracts.progress.get("kaamo_state",0))==2,"Fresh Resume lost the club offer")
	if not seed_cargo([[109,50]],30000001):return
	var before: Dictionary=app.session.station_owner().snapshot()
	if not await kaamo_talk(466,1,"kaamo-offer",false):return
	var after: Dictionary=app.session.station_owner().snapshot()
	check(int(after.contracts.progress.get("kaamo_state",0))==3,"Buying the club did not make it the player's")
	check(int(before.contracts.credits)-int(after.contracts.credits)==30000000,"The club did not cost 30,000,000 credits")
	check(not after.cargo.entries.any(func(row):return int(row.item_id)==109),"The 50 t Buskat stayed in the hold")
	if not await kaamo_talk(468,7,"kaamo-farewell"):return
	check(app.load_station() and int(app.session.station_owner().snapshot().contracts.progress.get("kaamo_state",0))==3,"Fresh Resume lost the bought club")
	for tick in 20:
		app.session.step(Time.get_ticks_usec());app.present_session();await process_frame
	check(not app.session.snapshot().dialogue.visible,"The owned club talked again")
	# The owned club's hangar stores goods for free and keeps them across Resume.
	var wallet:=int(app.session.station_owner().snapshot().contracts.credits)
	check(app.equipment_action("open") and app.equipment_action("sell",122),"Storing goods at the club failed: "+app.status.text)
	var opened: Dictionary=app.session.station_owner().snapshot()
	check(int(opened.contracts.credits)==wallet,"Storing goods at the club was not free")
	check(opened.get("stock",opened.get("equipment",{}).get("stock",[])) is Array,"The club storage has no stock")
	check(app.equipment_action("close") and app.load_station(),"Resuming after storing goods failed")
	var kept: Dictionary=app.session.station_owner().snapshot().contracts.progress.get("kaamo_storage",{})
	print("KAAMO storage ",kept)
	check(kept.get("items",[]).any(func(row):return int(row.item_id)==122),"The stored goods were lost on Resume")
	await capture_free_application("kaamo-storage")
	# The club's mechanics mod the flown hull; the ship dealer parks a ship in storage.
	if failures or not seed_cargo([],20000000):return
	var before_mods: Dictionary=app.session.station_owner().snapshot()
	check(app.contract_action("open",-1),"The Kaamo lounge did not open: "+app.session.error)
	var agents: Array=app.session.station_owner().snapshot().contracts.get("population",{}).get("contacts",[])
	print("KAAMO lounge ",agents.map(func(contact):return [contact.name,contact.get("kaamo",{})]))
	check(agents.size()==6 and agents.all(func(contact):return contact.has("kaamo")),"The Kaamo lounge does not hold its six agents")
	for kind in [0,1,"ship"]:
		var found: Array=agents.filter(func(contact):return contact.get("kaamo",{}).get("mod",-1)==kind if kind is int else contact.get("kaamo",{}).get("kind")==kind)
		if found.is_empty():check(false,"No Kaamo agent for "+str(kind));return
		var id: int=int(found[0].contact_id)
		check(app.contract_action("select",id) and app.contract_action("buy_kaamo",id),"Buying from the Kaamo agent %s failed: %s"%[str(kind),app.session.error])
	await capture_free_application("kaamo-lounge")
	check(app.contract_action("close",-1),"The Kaamo lounge did not close")
	var modded: Dictionary=app.session.station_owner().snapshot()
	var tags: Array=modded.loadout.ship_instance.upgrade_tags
	check(0 in tags and 1 in tags,"The mechanics' mods are not on the hull: "+str(tags))
	check(int(modded.cargo.capacity)==int(before_mods.cargo.capacity)+30,"The cargo mod did not add 30 t")
	check(int(modded.contracts.credits)<int(before_mods.contracts.credits),"The Kaamo agents charged nothing")
	check(modded.contracts.progress.kaamo_storage.ships.size()==1,"The dealer's ship was not parked in storage")
	check(app.save_station(false) and app.load_station(),"Saving the modded ship failed: "+app._save_notice.text)
	var resumed: Dictionary=app.session.station_owner().snapshot()
	check(resumed.loadout.ship_instance.upgrade_tags==tags and resumed.contracts.progress.kaamo_storage.ships.size()==1,"Fresh Resume lost the mods or the parked ship")
	# A parked ship can be sold from the club hangar for its listed price.
	var parked: Dictionary=resumed.contracts.progress.kaamo_storage.ships[0]
	var purse:=int(resumed.contracts.credits)
	check(app.equipment_action("open"),"The club hangar did not reopen: "+app.status.text)
	var quote: Array=app.session.station_owner().snapshot().get("equipment",{}).get("market_ships",[])
	var index:=quote.find(parked)
	check(index>=0,"The parked ship is not listed in the club hangar: %s"%str(quote))
	await capture_free_application("kaamo-parked")
	check(index>=0 and app.equipment_action("sell_ship",index),"Selling the parked ship failed: "+app.status.text)
	var sold: Dictionary=app.session.station_owner().snapshot()
	check(int(sold.contracts.credits)==purse+int(parked.unit_price) and sold.contracts.progress.kaamo_storage.ships.is_empty(),"Selling the parked ship paid %d (expected %d) or kept it"%[int(sold.contracts.credits)-purse,int(parked.unit_price)])
	check(app.equipment_action("close") and app.save_station(false) and app.load_station() and app.session.station_owner().snapshot().contracts.progress.kaamo_storage.ships.is_empty(),"Fresh Resume brought the sold ship back")

## Waits for a club talk opening with first_text, pages through it and captures it.
## Pirate base at station 1: the outpost and five sleeping guards, a guard's
## wake call, the outpost's end, the Nivelian thanks and 20,000 credits; the
## base stays gone after docking and a fresh Resume.
func fly_pirate_base() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var base:=pirate_base_station()
	if base<0:return
	var bit:=int(StoryFlights.PIRATE_BASES[base].bit)
	var wallet:=int(app.session.station_owner().snapshot().contracts.credits) if app.station_shell.visible else 0
	# A tractor beam (with its scanner) collects the outpost's loot.
	if not seed_cargo([[85,1],[122,12],[68,1],[81,1]]) or not fit_item(68) or not fit_scanner_beside(68) or not await depart_to(base):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("PIRATE BASE cast ",actors.map(func(actor):return [actor.get("static_object",false),int(actor.vitals.hull),actor.get("position",Vector3.ZERO)]))
	check(actors.size()==6 and actors[0].get("static_object",false) and range(1,6).all(func(id):return not actors[id].get("static_object",false)),"The pirate base cast is not an outpost and five guards")
	var fogs: Array=app.session.scene.sky.static_fogs
	check(fogs.size()==1 and fogs[0].visible and fogs[0].multimesh.instance_count==30 and fogs[0].multimesh.custom_aabb.get_center().distance_to(actors[0].body_pose.origin)<1.0,"The outpost lost its red fog")
	if failures:return
	await capture_free_application("pirate-base")
	var radio_ids:=[]
	var standing:=func(list):
		var alive:=range(list.size()).filter(func(id):return int(list[id].vitals.hull)>0)
		return [0] if 0 in alive else alive
	# Like a player: the outpost first, then the guards still awake before flying home.
	var cleared:=func():
		var list: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		return radio_ids.any(func(id):return id in [427,428,429]) and list.all(func(actor):return int(actor.vitals.hull)<=0)
	if not await fight_until("pirate_base",func():return cleared.call() or app.session.status!="running",standing,radio_ids,90000):return
	print("PIRATE BASE radio ",radio_ids)
	check(radio_ids.any(func(id):return id in [424,425,426]) and radio_ids.any(func(id):return id in [427,428,429]) and not 431 in radio_ids,"The guard call or the outpost's end did not play, or the thanks came by radio")
	for tick in 300:
		if app.session.status!="running" or app.session.flight_owner()._radio.snapshot().get("visible",false)==false:break
		now_us+=100000
		if not app.session.step(now_us,Vector2.ZERO,false,false,0.0):check(false,app.session.error);return
		if tick%10==0:await process_frame
	await capture_free_application("pirate-base-won")
	if failures or not await collect_base_loot(base) or not await dock_application():return
	# The original thanks the player at the next docking and pays there.
	if not await kaamo_talk(431,1,"pirate-base-thanks"):return
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(int(docked.contracts.progress.get("pirate_bases",0)) & bit and not int(docked.contracts.progress.pirate_bases) & 16,"The career did not record the destroyed base and the paid thanks")
	print("PIRATE BASE credits ",wallet," -> ",int(docked.contracts.credits))
	check(int(docked.contracts.credits)==wallet+20000,"The docking thanks did not pay 20000")
	check(app.load_station() and int(app.session.station_owner().snapshot().contracts.progress.get("pirate_bases",0)) & bit,"Fresh Resume lost the destroyed base")
	if failures or not await depart_to(base):return
	check(not app.session.flight_owner()._encounter.combat_snapshot().actors.any(func(actor):return actor.get("static_object",false)),"The destroyed base came back")
	# With the base gone the station is manned again; with it standing (the
	# kill undone in the save) Security turns the ship away at docking.
	if failures or not await dock_application():return
	check(not app.session.snapshot().dialogue.get("visible",false),"The freed station still refused docking")
	if failures or not await docking_fee():return
	if failures or not await wanted_notice():return
	if failures or not seed_pirate_bases(int(app.session.station_owner().snapshot().contracts.progress.get("pirate_bases",0)) & ~bit):return
	if not await kaamo_talk(423,1,"pirate-base-unmanned"):return
	for tick in 120:
		if app.session.has_method("flight_owner"):break
		app.present_session();await process_frame
	check(app.session.has_method("flight_owner") and app.session.flight_owner()._encounter!=null and app.session.flight_owner()._encounter.combat_snapshot().actors.any(func(actor):return actor.get("static_object",false)),"The unmanned station did not send the ship back to its outpost")

## Expansion weapons in one flight: fitted in the hangar from the hold, then
## the cluster salvo, the Shock Blast and the new guns fire, with captures.
func fly_dlc_weapons() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if not seed_cargo([[214,6],[226,3],[211,3],[228,1],[176,1],[232,3],[224,1]]):return
	# Make room: take off the guns and secondaries already fitted.
	if not app.equipment_action("open"):check(false,app.session.error);return
	var slots: Array=app.session.station_owner().snapshot().loadout.slots
	for index in range(slots.size()-1,-1,-1):
		if slots[index]!=null and int(catalogue.tables.items[int(slots[index].item_id)].properties.get(1,-1)) in [0,1]:
			if not app.equipment_action("unmount",int(slots[index].item_id),index):check(false,app.session.error);return
	if not app.equipment_action("close"):check(false,app.session.error);return
	# Two secondary slots: the cluster salvo and sentry passed this run before;
	# now the Shock Blast and the Fireworks. The Matador needs a turret slot.
	var ship:=int(app.session.station_owner().snapshot().loadout.ship_id)
	var turret_slots:=int(catalogue.tables.ships[ship].stats.turret_slots)
	var wanted:=[226,232,228,176]+([224] if turret_slots>0 else [])
	print("WEAPONS ship ",ship," turret slots ",turret_slots)
	for id in wanted:
		if not await fit_item(id):return
	var fitted: Array=app.session.station_owner().snapshot().loadout.equipment_ids
	check(wanted.all(func(id):return id in fitted),"Not every expansion weapon was fitted: "+str(fitted))
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	for item in [226,232]:
		check(app.session.select_secondary(item),"Selecting %d failed: %s"%[item,app.session.error])
		var before:=weapon_rounds(item)
		check(app.session.action("missiles"),"Launching %d failed: %s"%[item,app.session.error])
		var most:=0
		for tick in 12:
			if not application_step():return
			most=maxi(most,live_shots(item))
			if tick==6:await capture_free_application("weapons-%d"%item)
			await process_frame
		print("WEAPONS ",item," rounds ",before," -> ",weapon_rounds(item)," live shots ",most)
		check(weapon_rounds(item)<before,"Launching %d used no round"%item)
		if item==214:check(most>=3,"The cluster launch fired no salvo")
		# Fireworks burst when their 8 s fuse runs out.
		var burst:=false
		for tick in (240 if item==232 else 80):
			if not application_step():return
			if item==232 and not burst and burst_active(item):burst=true;await capture_free_application("weapons-fireworks-burst")
		if item==232:check(burst,"The Fireworks never burst")
	# Matador TS: turret view, hold fire.
	if 224 in wanted:
		check(app.session.action("turret"),"Turret view failed: "+app.session.error)
		for tick in 30:
			now_us+=50000
			if not app.session.step(now_us,Vector2.ZERO,true):check(false,app.session.error);return
			app.present_session()
			if tick==15:await capture_free_application("weapons-matador")
			await process_frame
		check(app.session.error.is_empty(),"Firing the Matador failed: "+app.session.error)
		check(app.session.action("turret"),"Leaving turret view failed: "+app.session.error)
	# Primary guns: hold fire for a moment.
	for tick in 20:
		now_us+=50000
		if not app.session.step(now_us,Vector2.ZERO,true):check(false,app.session.error);return
		app.present_session()
		if tick==10:await capture_free_application("weapons-primaries")
		await process_frame
	check(app.session.error.is_empty(),"Firing the expansion guns failed: "+app.session.error)

func burst_active(item: int) -> bool:
	var owner: RefCounted=app.session.flight_owner()._encounter._secondaries
	for gun in owner.snapshot().guns:
		if int(gun.equipment.item_id)!=item:continue
		var burst: RefCounted=owner.detonation_owner(int(gun.slot_index))
		return burst!=null and burst.snapshot().get("effect",{}).get("active",false)
	return false

func weapon_rounds(item: int) -> int:
	for gun in app.session.flight_owner()._encounter.snapshot().get("secondaries",{}).get("guns",[]):
		if int(gun.get("equipment",{}).get("item_id",-1))==item:return int(gun.get("ammunition",gun.get("equipment",{}).get("quantity",-1)))
	return -1

func live_shots(item: int) -> int:
	for gun in app.session.flight_owner()._encounter.snapshot().get("secondaries",{}).get("guns",[]):
		if int(gun.get("equipment",{}).get("item_id",-1))==item:
			return gun.get("projectiles",{}).get("slots",[]).filter(func(slot):return slot is Dictionary and int(slot.get("remaining_ms",0))>0).size()
	return 0

## Shared release, with the blocking state printed when control never comes.
func release_application_flight() -> bool:
	var released: bool=await super.release_application_flight()
	if not released:
		var world: RefCounted=app.session.flight_owner()
		print("RELEASE blocked pauses ",app.session._pauses," toll ",world.toll_state()," released ",world.entry_released()," dialogue ",world.dialogue_visible()," departing ",world.local_departing()," cinematic ",world.cinematic_input_blocked()," audio ",app.session.flight_audio!=null," station ",app.session.snapshot().location.station_id)
	return released

## Loma toll: refuse on the first visit (pirates turn on the player), the
## refusal survives docking and Resume and greets the next flight; with the
## answer cleared, paying takes the toll and is kept after Resume.
const LOMA:=105
func fly_loma_toll() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	# The drive's arrival in Loma is the first Loma flight: the toll is asked there.
	# No control release on arrival: the toll question pauses the flight first.
	if not seed_khador_drive() or not await depart_to(int(app.session.station_owner().snapshot().loadout.station_id)) or not await khador_jump(LOMA,false):return
	if not await loma_flight([438,439],"loma-question",false):return
	app._answer_toll(0)
	var radio:=await loma_radio([442,443])
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	var pirates:=actors.filter(func(actor):return int(actor.get("actor_kind",-1))==8)
	print("LOMA refused radio ",radio," pirates ",pirates.map(func(actor):return actor.get("hostile")))
	check(radio.any(func(id):return id in [442,443]),"Refusing the toll played no pirate line")
	check(pirates.all(func(actor):return actor.get("hostile",false)),"Pirates held fire after the refusal")
	await capture_free_application("loma-refused")
	if failures or not await dock_application():return
	check(docked_station()==LOMA,"The ship did not dock in Loma")
	check(int(app.session.station_owner().snapshot().contracts.progress.get("loma_toll",0))==2,"The career did not keep the refusal")
	check(app.load_station() and int(app.session.station_owner().snapshot().contracts.progress.get("loma_toll",0))==2,"Fresh Resume lost the refusal")
	if failures:return
	app.set_player_mode(true);app.show();app.present_session();await process_frame;resume_application_focus()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var back:=await loma_radio([444,445])
	check(back.any(func(id):return id in [444,445]) and not app.session.is_paused(),"A refused pilot was asked again or not greeted")
	if failures or not await dock_application():return
	# Test shortcut: forget the answer, as leaving Loma would, then pay.
	if not seed_loma_toll_cleared():return
	var wallet:=int(app.session.station_owner().snapshot().contracts.credits)
	if not await loma_flight([438,439],"loma-question-2"):return
	var toll: Dictionary=app.session.flight_owner().toll_state()
	app._answer_toll(1)
	var paid:=await loma_radio([440,441])
	check(paid.any(func(id):return id in [440,441]),"Paying the toll played no pirate line")
	if failures or not await dock_application():return
	var docked: Dictionary=app.session.station_owner().snapshot()
	print("LOMA toll ",toll," credits ",wallet," -> ",int(docked.contracts.credits))
	check(int(docked.contracts.progress.get("loma_toll",0))==1,"The career did not keep the paid toll")
	check(wallet-int(docked.contracts.credits)==int(toll.get("amount",-1)) and int(toll.get("amount",0))>0,"The toll was not taken from the credits")
	check(app.load_station() and int(app.session.station_owner().snapshot().contracts.progress.get("loma_toll",0))==1,"Fresh Resume lost the paid toll")

## Depart, hear the welcome and reach the paused question.
func loma_flight(welcome: Array,capture: String,depart:=true) -> bool:
	if depart:
		app.set_player_mode(true);app.show();app.present_session();await process_frame;resume_application_focus()
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
		if not await release_application_flight():return false
	var heard:=[]
	for tick in 3000:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
		if app.session.is_paused() and app.session.flight_owner().toll_state().get("question",false):break
		if not application_step():return false
		if tick%10==0:await process_frame
	print("LOMA welcome ",heard," toll ",app.session.flight_owner().toll_state())
	check(heard.any(func(id):return id in welcome),"The Loma welcome did not play")
	check(app.session.is_paused() and app.session.flight_owner().toll_state().get("question",false),"The toll question did not pause the flight")
	await capture_free_application(capture)
	return failures==0

func loma_radio(wanted: Array) -> Array:
	var heard:=[]
	for tick in 1500:
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
		if heard.any(func(id):return id in wanted):break
		if not application_step():break
		if tick%10==0:await process_frame
	return heard

func seed_loma_toll_cleared() -> bool:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	document.career.progress.erase("loma_toll");document.station.progress.erase("loma_toll")
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station(),"The seeded save did not load: "+app._save_notice.text)
	return failures==0

## The first pirate base in a system the career knows (test shortcut: else
## open the first base's system, as a bought map would).
## Fit scanner 81 unless one is fitted, keeping `keep` and the drive.
func fit_scanner_beside(keep: int) -> bool:
	var items: Array=catalogue.tables.items
	if app.session.station_owner().snapshot().loadout.equipment_ids.any(func(id):return int(items[int(id)].properties.get(2,-1))==17):return true
	if not app.equipment_action("open"):check(false,app.session.error);return false
	if not app.equipment_action("mount",81):
		var slots: Array=app.session.station_owner().snapshot().loadout.slots
		for index in range(slots.size()-1,-1,-1):
			if slots[index]!=null and int(slots[index].item_id) not in [keep,85] and int(items[int(slots[index].item_id)].properties.get(1,-1))==int(items[81].properties.get(1,-1)):
				app.equipment_action("unmount",int(slots[index].item_id),index);break
		if not app.equipment_action("mount",81):check(false,"Scanner could not be fitted: "+app.session.error);return false
	return app.equipment_action("close")

## Steer at the destroyed outpost's container until the tractor takes it and check its
## fixed loot lands in the hold.
func collect_base_loot(base: int) -> bool:
	var loot: Array=StoryFlights.PIRATE_BASES[base].loot
	var held:=func():
		var rows: Array=app.session.snapshot().cargo.entries.filter(func(row):return int(row.item_id)==int(loot[0]))
		return 0 if rows.is_empty() else int(rows[0].quantity)
	var before: int=held.call()
	var crate: Dictionary=app.session.flight_owner()._encounter._control.destruction_view(0).snapshot().get("cargo",{})
	check(crate.get("model_exists",false) and crate.get("eligible",false) and crate.entries==[{"item_id":int(loot[0]),"quantity":int(loot[1])}],"The destroyed outpost dropped no loot container")
	if failures:return false
	var inside:=false
	for tick in 3000:
		var life: Dictionary=app.session.flight_owner()._encounter._control.destruction_view(0).snapshot().cargo
		if not life.eligible:break
		var state: Dictionary=app.session.snapshot()
		if not inside and state.player_pose.origin.distance_to(life.pose.origin)<15000.0:
			inside=true;await capture_free_application("pirate-base-loot")
		now_us+=100000
		if not app.session.step(now_us,CombatPilot.Steering.steering_toward(state.player_pose,life.pose.origin),false,false,0.0):check(false,app.session.error);return false
		if tick%10==0:await process_frame
	print("PIRATE BASE loot ",loot," held ",before," -> ",held.call())
	check(held.call()==before+int(loot[1]),"The outpost's loot did not reach the hold")
	return failures==0

## Docking as an enemy of the system's race: the station asks 194 with a fee.
## Yes pays it and opens the station; with too few credits 192 sends the ship out.
func docking_fee() -> bool:
	var station:=int(app.session.station_owner().snapshot().loadout.station_id)
	var cat: RefCounted=load("res://src/content/catalogues.gd").new()
	if not cat.open(app.library):check(false,cat.error);return false
	var race:=int(cat.tables.systems[int(cat.tables.stations[station].system_id)].fields[2])
	var axes:=[0,0];axes[0 if race<2 else 1]=-100 if race in [0,2] else 100
	var credits:=int(app.session.station_owner().snapshot().contracts.credits)
	if not seed_career(axes,-1):return false
	await process_frame
	check(not app.session.snapshot().dialogue.get("visible",false),"Resume at a hostile station asked the docking fee")
	if failures or not await depart_to(station) or not await dock_application():return false
	if not await kaamo_talk(194,1,"docking-fee"):return false
	var paid: Dictionary=app.session.station_owner().snapshot()
	print("DOCKING FEE race ",race," credits ",credits," -> ",int(paid.contracts.credits))
	check(int(paid.contracts.credits)<credits and int(paid.contracts.credits)>=credits-2900 and not app.session.has_method("flight_owner") and not app.session.snapshot().dialogue.get("visible",false),"Paying the docking fee did not take 2700..2899 credits and open the station")
	if failures or not seed_career(axes,100) or not await depart_to(station) or not await dock_application():return false
	if not await kaamo_talk(194,1,"docking-fee-short",false):return false
	if not await kaamo_talk(192,1,"docking-fee-missing"):return false
	for tick in 120:
		if app.session.has_method("flight_owner"):break
		app.present_session();await process_frame
	check(app.session.has_method("flight_owner"),"Too few credits for the fee did not send the ship out")
	if failures:return false
	return seed_career([0,0],credits)

## Docking after a wanted pilot is terminated: 3221 names him and his ship
## (Quineros sells it from then on), once per game run. The medal notices
## (638/639/640) need earned medal evidence and are checked in valkyrie_worlds.
func wanted_notice() -> bool:
	if not app.session.station_owner().snapshot().contracts.progress.has("wanted"):print("WANTED board not started in this career");return true
	if not seed_wanted_dead(6):return false
	# The notice waits behind any "New medal!" window; close those first.
	for tick in 20:app.session.step(Time.get_ticks_usec());app.present_session();await process_frame
	check(not app.session.snapshot().dialogue.get("visible",false) or not app.medal_notice.visible,"The wanted notice opened over a medal window")
	for attempt in 60:
		if not app.medal_notice.visible:break
		app.acknowledge_medal_notice();app.present_session();await process_frame
	if not await kaamo_talk(3221,1,"wanted-ship-notice"):return false
	check(app.load_station(),"Reload after the wanted notice failed")
	app.set_player_mode(true);app.show();app.present_session()
	for tick in 30:app.session.step(Time.get_ticks_usec());app.present_session();await process_frame
	check(not app.session.snapshot().dialogue.get("visible",false),"The wanted notice repeated in the same game run")
	return failures==0

## Test shortcut: mark one Most Wanted entry terminated.
func seed_wanted_dead(index: int) -> bool:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	for part in [document.station,document.career]:
		if part.get("progress") is Dictionary and part.progress.get("wanted") is Dictionary:part.progress.wanted.entries[index].dead=true
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station() and not app._save_file.recovered_backup,"The wanted-seeded career did not load: "+app._save_notice.text)
	app.set_player_mode(true);app.show();app.present_session()
	return failures==0

## Test shortcut: set the career's standing axes and (when >= 0) credits.
func seed_career(axes: Array,credits: int) -> bool:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	var standing:={"axes":axes,"override":-1}
	for part in [document.station,document.career]:
		if part.has("reputation"):part.reputation=standing.duplicate(true)
		if part.get("progress") is Dictionary and part.progress.has("reputation"):part.progress.reputation=standing.duplicate(true)
	if credits>=0:document.career.credits=credits
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station() and not app._save_file.recovered_backup,"The seeded career did not load: "+app._save_notice.text)
	app.set_player_mode(true);app.show();app.present_session()
	return failures==0

## Test shortcut: set the career's destroyed-base bits.
func seed_pirate_bases(mask: int) -> bool:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	for part in [document.station,document.career]:
		if part.get("progress") is Dictionary:part.progress.pirate_bases=mask
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station(),"The base-seeded save did not load: "+app._save_notice.text)
	app.set_player_mode(true);app.show();app.present_session()
	return failures==0

func pirate_base_station() -> int:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return -1
	var open: Array=document.locations.system_availability
	for station in StoryFlights.PIRATE_BASES:
		if open[int(catalogue.tables.stations[station].system_id)]:return int(station)
	open[int(catalogue.tables.stations[1].system_id)]=true
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return -1
	check(app.load_station(),"The seeded save did not load: "+app._save_notice.text)
	return 1 if failures==0 else -1

## `closes`: false when the line leads straight into the next talk (Yes on the offer).
func kaamo_talk(first_text: int,pages: int,capture: String,closes:=true) -> bool:
	for tick in 60:
		if app.session.snapshot().dialogue.visible:break
		app.session.step(Time.get_ticks_usec());app.present_session();await process_frame
	var line: Dictionary=app.session.snapshot().dialogue
	check(line.get("visible",false) and int(line.get("text_id",-1))==first_text and int(line.get("count",0))==pages,"The club talk %d did not open: %s"%[first_text,str(line)])
	if failures:return false
	await capture_free_application(capture)
	for page in pages:app.station_navigation("next");await process_frame
	check(app.session.snapshot().dialogue.visible!=closes,"The club talk %d did not %s"%[first_text,"close" if closes else "lead on"])
	return failures==0

func fly_supernova_wanted() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==128,"The Alioth checkpoint is not at cursor 128")
	if failures or not seed_cargo([[122,12]]):return
	for entry in [0,1]:
		var cursor: int=[128,130][entry];var name: String=["Pal Tyyrt","Kehnor"][entry]
		var board_station:=terran_board_station()
		if not await depart_to(board_station) or not await dock_application():return
		app.open_missions();await process_frame
		app.missions_panel.toggle_wanted();await process_frame
		var log: Dictionary=app.missions_panel.snapshot()
		print("SUPERNOVA board ",log.get("wanted_available")," ",String(log.get("wanted","")).get_slice("\n\n",0).replace("\n"," | "))
		check(log.get("wanted_available",false) and String(log.wanted).begins_with("Pal Tyyrt"),"The Terran Most Wanted board is not open at cursor %d"%cursor)
		await capture_free_application("supernova-wanted-board-%d"%cursor)
		app.close_missions();await process_frame
		var board: Dictionary=app.session.station_owner().snapshot().contracts.progress.get("wanted",{})
		var at: int=int(board.get("entries",[{},{}])[entry].get("at",-1))
		check(board.entries[entry].active and at>=0,name+" is not on the board")
		if failures or not await depart_to(at):return
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		print("SUPERNOVA ",name," at ",at," cast ",actors.map(func(actor):return [actor.hull_catalogue_id,int(actor.vitals.hull),actor.get("display_name","")]))
		check(actors.size()>=1 and String(actors[0].get("display_name",""))==name,name+" was not met at his station")
		if failures:return
		await capture_free_application("supernova-wanted-%d"%cursor)
		var radio_ids:=[]
		var criminal:=func(_now):
			var him: Dictionary=app.session.flight_owner()._encounter.combat_snapshot().actors[0]
			return [0] if int(him.vitals.hull)*3>=int(him.max_hull) else []
		if not await fight_until("wanted-%d"%cursor,func():return app.session.flight_owner()._objective.snapshot().campaign_cursor!=cursor,criminal,radio_ids):return
		var him: Dictionary=app.session.flight_owner()._encounter.combat_snapshot().actors[0]
		print("SUPERNOVA ",name," gave up: hull ",him.vitals.hull,"/",him.max_hull," hostile ",him.get("hostile")," radio ",radio_ids)
		check(int(him.vitals.hull)>0 and not him.get("hostile",true),name+" did not give up alive")
		check(int(app.session.flight_owner()._objective.snapshot().campaign_cursor)==[130,131][entry],"The story did not move on after "+name)
		await capture_free_application("supernova-wanted-%d-surrender"%cursor)
		if failures:return
		if entry==0 and (not await dock_application()):return
	# 131: Var Lupra, held until Keith's line ends; 132 the talk there.
	if not await khador_jump(112,false) or not await wait_story_cursor(132,"supernova-varlupra"):return
	if not await dock_application() or not await take_station_talk(132,133):return
	if not await story_cutaway(120,112,134,"supernova-katashan-133"):return
	if not await travel_and_talk(22,134,135):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming for 135 failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==135,"Fresh Resume lost the 134 talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-135.gof2save"))==OK,"The 135 checkpoint could not be kept")

## 135-140: a Most Wanted bounty first (Gendol Ethor, on the Terran board
## since 131); Coromesk is refused without a drill, then the pilot delivers
## 140 Titanium at the Mining Plant while pirates keep coming back (the test
## tops the hold up where the player would mine); Var Lupra; B'akrram's
## clearance and talk; a Vol Noor for Bra'Murr, two won hacks and the
## transfer; Var Lupra's talk for 141.
const COROMESK:=103
const DRILL:=86
const TITANIUM:=155
const VOL_NOOR:=42
func fly_supernova_coromesk() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==135,"The Dekato checkpoint is not at cursor 135")
	if failures or not seed_cargo([[122,12]]):return
	# The bounty: fly to where the board's third entry is and destroy him.
	var board: Dictionary=app.session.station_owner().snapshot().contracts.progress.get("wanted",{})
	var gendol: Dictionary=board.get("entries",[{},{},{}])[2]
	# He joins the Terran board at the first Terran docking after 131.
	if not gendol.get("active",false):
		if not await depart_to(terran_board_station()) or not await dock_application():return
		gendol=app.session.station_owner().snapshot().contracts.progress.get("wanted",{}).get("entries",[{},{},{}])[2]
	# A rich career trades up where the yard has a tougher hull.
	var hull_before: int=int(app.session.station_owner().snapshot().loadout.ship_id)
	if not await outfit_for_combat():return
	if int(app.session.station_owner().snapshot().loadout.ship_id)!=hull_before:
		var top:=top_protection()
		if not seed_cargo(top.map(func(id):return [id,1])) or not fit_same_type(top):return
	if not fit_best_guns():return
	print("SUPERNOVA Gendol Ethor ",gendol)
	check(gendol.get("active",false),"Gendol Ethor was not activated by a Terran docking after 131")
	if failures:return
	var credits:=int(app.session.station_owner().snapshot().contracts.credits)
	if not await depart_to(int(gendol.at)):return
	var bounty_radio:=[]
	var him:=func(_actors):return [0] if int(app.session.flight_owner()._encounter.combat_snapshot().actors[0].vitals.hull)>0 else []
	# His wingman first (lighter), then him: one gun on the player sooner.
	var pack:=func(_actors):
		var now: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		var alive: Array=range(now.size()).filter(func(id):return int(now[id].vitals.hull)>0 and now[id].get("active",false) and now[id].get("hostile",false))
		var wing: Array=alive.filter(func(id):return id!=0)
		return wing if not wing.is_empty() else alive
	await capture_free_application("supernova-bounty")
	if not await fight_until("bounty",func():return him.call([]).is_empty(),pack,bounty_radio):return
	if not await wait_story_cursor(135,"") or not await dock_application():return
	var after: Dictionary=app.session.station_owner().snapshot()
	print("SUPERNOVA bounty paid ",int(after.contracts.credits)-credits," board ",after.contracts.progress.wanted.bounties," radio ",bounty_radio)
	check(after.contracts.progress.wanted.entries[2].dead and int(after.contracts.progress.wanted.bounties[0])==1 and int(after.contracts.credits)>credits,"The bounty on Gendol Ethor was not paid")
	if failures:return
	# Refused without a drill (3202).
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var refused: RefCounted=app.session.flight_owner().start_drive(COROMESK)
	print("SUPERNOVA Coromesk without a drill: ",refused._notices.snapshot() if refused!=null else app.session.flight_owner().error)
	check(refused!=null and refused._drive.snapshot().get("phase","ready")=="ready","The drive jumped to Coromesk without a drill")
	if failures or not await dock_application():return
	var free:=int(app.session.station_owner().snapshot().cargo.free_space)
	if not seed_cargo([[DRILL,1],[TITANIUM,maxi(1,free-1)]]) or not fit_item(DRILL):return
	if not await depart_to(COROMESK):return
	await capture_free_application("supernova-coromesk")
	var radio_ids:=[];var topped:=[0]
	var pirates:=func(frame):
		var actors: Array=frame._encounter.combat_snapshot().actors;var at: Vector3=app.session.snapshot().player_pose.origin
		return range(1,3).filter(func(id):return int(actors[id].vitals.hull)>0 and actors[id].get("active",false) and actors[id].pose.origin.distance_to(at)<30000)
	var plant:=func(frame):
		# Out of Titanium at the plant: the test adds what mining would have.
		var status:=int(frame._story_dock.get("status",0))
		if int(frame._story_dock.get("docked",-1))==0 and frame._cargo.quantity(TITANIUM)==0 and status<140:
			var load:=mini(140-status,int(frame._cargo.snapshot().free_space))
			# The live world's hold (flight_owner() hands out a copy).
			if load>0 and app.session._world._cargo.add_entries([{"item_id":TITANIUM,"quantity":load}]):topped[0]+=load
		return frame._encounter.combat_snapshot().actors[0].pose.origin
	if not await story_flight(135,"coromesk",plant,pirates,radio_ids,900,1500.0):return
	print("SUPERNOVA Coromesk radio ",radio_ids," topped up ",topped[0])
	check(2875 in radio_ids or 2874 in radio_ids,"The pirates' lines at the plant did not play")
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==136,"Coromesk did not move the story to 136")
	if failures or not await khador_jump(112) or not await dock_application() or not await take_station_talk(136,137):return
	# 137: B'akrram's control in flight; 138 the talk there.
	if not await depart_to(58) or not await wait_story_cursor(138,"supernova-bakrram"):return
	if not await dock_application() or not await take_station_talk(138,139):return
	# 139: a Vossk ship is required. The test keeps a Khador Drive for the new hull.
	if not seed_cargo([[85,1]]):return
	var offers: Array=await shipyard()
	print("SUPERNOVA B'akrram yard ",offers.map(func(row):return [row.get("ship_id"),row.get("unit_price")]))
	# A Vol Noor, or another Vossk hull with item 190 fitted (the gate's two ways).
	var vossk:=[VOL_NOOR,9,39,41,44,49,50,53,54,61,63]
	var usable: Array=offers.filter(func(row):return int(row.get("ship_id",-1)) in vossk)
	usable.sort_custom(func(a,b):return int(a.ship_id)==VOL_NOOR)
	var index: int=offers.find(usable.front()) if not usable.is_empty() else -1
	if index<0 or not app.equipment_action("open") or not app.equipment_action("buy_ship",index):check(false,"No Vossk ship at B'akrram: "+app.session.error);return
	app.equipment_action("close")
	if not fit_item(85):return
	if int(app.session.station_owner().snapshot().loadout.ship_id)!=VOL_NOOR and (not seed_cargo([[190,1]]) or not fit_item(190)):return
	if not await depart_to(131):return
	await capture_free_application("supernova-bramurr")
	radio_ids=[]
	var battleship:=func(frame):
		var dock: Dictionary=frame._story_dock;var actors: Array=frame._encounter.combat_snapshot().actors;var at: Vector3=app.session.snapshot().player_pose.origin
		var open: Array=[0,1].filter(func(id):return dock.get("actors",{}).get(id,{}).get("dockable",false))
		if open.is_empty():return null
		open.sort_custom(func(a,b):return actors[a].pose.origin.distance_to(at)<actors[b].pose.origin.distance_to(at))
		return actors[open[0]].pose.origin
	if not await story_flight(139,"bramurr",battleship,func(_frame):return [],radio_ids,900,2000.0):return
	print("SUPERNOVA Bra'Murr radio ",radio_ids)
	check(2918 in radio_ids and app.session.flight_owner()._objective.snapshot().campaign_cursor==140,"Bra'Murr's transfer did not finish")
	await capture_free_application("supernova-bramurr-transfer")
	if failures or not await khador_jump(112) or not await dock_application() or not await take_station_talk(140,141):return
	check(app.save_station(false) and app.load_station(),"Saving and resuming at Var Lupra failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==141,"Fresh Resume lost the 140 talk")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-141.gof2save"))==OK,"The 141 checkpoint could not be kept")

## Most Wanted bounties (board entries 2+): the test puts a board criminal
## at the docked station (seeded board state on the 105 checkpoint, as no
## later earned save exists yet). Leaving without the kill keeps him on the
## board; flying out again meets him, the kill pays his bounty with Keith's
## line, the story stays put and it all survives docking, saving and a
## fresh Resume.
const BOUNTY_ENTRY:=2
func fly_supernova_bounty() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var protection: Array=top_protection()
	if failures or not seed_cargo(protection.map(func(id):return [id,1])) or not fit_same_type(protection):return
	var station:=int(app.session.station_owner().snapshot().contracts.station_id)
	var stats:=seed_board_criminal(BOUNTY_ENTRY,station)
	if stats.is_empty():return
	var cursor:=int(app.session.station_owner().snapshot().campaign_cursor)
	var credits:=int(app.session.station_owner().snapshot().contracts.credits)
	print("SUPERNOVA bounty ",stats.name," at ",station," cursor ",cursor," reward ",stats.reward," credits ",credits)
	# Failure: out and straight back in without the kill.
	if not await depart_to(station):return
	var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	print("SUPERNOVA bounty cast ",actors.map(func(actor):return [actor.hull_catalogue_id,int(actor.vitals.hull),actor.get("display_name","")]))
	check(actors.size()>=1 and String(actors[0].get("display_name",""))==String(stats.name),String(stats.name)+" was not met at his station")
	if failures or not await dock_application():return
	var kept: Dictionary=app.session.station_owner().snapshot()
	check(kept.contracts.progress.wanted.entries[BOUNTY_ENTRY].active and not kept.contracts.progress.wanted.entries[BOUNTY_ENTRY].dead and int(kept.contracts.credits)==credits,"Leaving without the kill changed the board or paid: "+str(kept.contracts.progress.wanted.entries[BOUNTY_ENTRY]))
	if failures:return
	# The kill.
	if not await depart_to(station):return
	await capture_free_application("supernova-bounty-met")
	var radio_ids:=[]
	var him:=func(_actors):return [0] if int(app.session.flight_owner()._encounter.combat_snapshot().actors[0].vitals.hull)>0 else []
	if not await fight_until("bounty",func():return him.call([]).is_empty(),him,radio_ids):return
	var killed_at: Vector3=app.session.snapshot().player_pose.origin
	await capture_free_application("supernova-bounty-kill")
	# Keith's kill line; the ship stays under the pilot's control meanwhile.
	var kill_lines:=range(3140,3145)
	var started:=now_us
	while now_us-started<20000000 and not radio_ids.any(func(id):return id in kill_lines):
		if not application_step():return
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		if int((now_us-started)/1000000)%2==0:await process_frame
	await capture_free_application("supernova-bounty-keith")
	var drift: float=app.session.snapshot().player_pose.origin.distance_to(killed_at)
	var flight: Dictionary=app.session.flight_owner()._objective.snapshot()
	print("SUPERNOVA bounty radio ",radio_ids," cursor ",flight.campaign_cursor," drift ",int(drift)," status ",app.session.status)
	check(radio_ids.any(func(id):return id in kill_lines),"Keith's bounty line did not play: "+str(radio_ids))
	check(int(flight.campaign_cursor)==cursor,"The bounty moved the story")
	check(app.session.status!="station_transition_required" and drift<20000.0,"The pilot was moved after the bounty: "+str(int(drift))+" "+app.session.status)
	if failures:return
	# The chase can end hundreds of km out: the autopilot takes its time home.
	resume_application_focus()
	if not app.session.action("autopilot"):check(false,app.session.error);return
	started=now_us
	while now_us-started<900000000 and app.session.status!="station_transition_required":
		if not application_step():return
		if int((now_us-started)/1000000)%4==0:await process_frame
	check(app.session.status=="station_transition_required","The autopilot never brought the pilot home after the bounty")
	if failures or not app.enter_station(now_us,42):check(false,app.status.text);return
	app.session.rebase_time(now_us)
	var after: Dictionary=app.session.station_owner().snapshot()
	var board: Dictionary=after.contracts.progress.wanted
	print("SUPERNOVA bounty paid ",int(after.contracts.credits)-credits," board ",board.bounties," entry ",board.entries[BOUNTY_ENTRY])
	check(board.entries[BOUNTY_ENTRY].dead and not board.entries[BOUNTY_ENTRY].active and int(board.bounties[int(stats.board)])==1,"The board did not mark "+String(stats.name)+" killed")
	check(int(after.contracts.credits)-credits==int(stats.reward),"The bounty paid %d, not %d"%[int(after.contracts.credits)-credits,int(stats.reward)])
	check(int(after.campaign_cursor)==cursor,"The docked career left cursor %d"%cursor)
	if failures:return
	check(app.save_station(false) and app.load_station(),"Saving and resuming after the bounty failed: "+app._save_notice.text)
	if failures:return
	var resumed: Dictionary=app.session.station_owner().snapshot()
	check(resumed.contracts.progress.wanted==board and int(resumed.contracts.credits)==int(after.contracts.credits) and int(resumed.campaign_cursor)==cursor,"Fresh Resume lost the bounty")
	await capture_free_application("supernova-bounty-resumed")
	# Out again: he is gone.
	if failures or not await depart_to(station):return
	actors=app.session.flight_owner()._encounter.combat_snapshot().actors
	check(not actors.any(func(actor):return String(actor.get("display_name",""))==String(stats.name)),String(stats.name)+" came back after his death")

## Test shortcut: board entry `index` active at `station` in the saved career.
func seed_board_criminal(index: int,station: int) -> Dictionary:
	var file:=StationSaveFile.new();var path: String=app.station_save_path()
	var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return {}
	var Wanted=load("res://src/simulation/wanted_board.gd")
	var table: Array=catalogue.tables.get("wanted",[])
	check(table.size()>index,"No Most Wanted table imported")
	if failures:return {}
	var row: Dictionary=table[index]
	var state: Dictionary=Wanted.fresh(table)
	var stats:={"name":row.name,"ship":int(row.ship),"race":int(row.race),"weapon":int(row.weapon),"hull":int(row.hull),
		"loot":[int(row.loot_item),int(row.loot_amount)],"reward":int(row.reward),"wingmen":int(row.wingmen),"board":int(row.board),"tier":int(row.required_bounties)}
	state.entries[index].merge({"active":true,"at":station,"to":station,"from":station,"stats":stats},true)
	var seeded:=0
	for part in [document.station,document.career]:
		if part.get("progress") is Dictionary:
			part.progress.wanted=state.duplicate(true);seeded+=1
	check(seeded>0,"The save has no career progress to seed")
	if failures:return {}
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return {}
	check(app.load_station(),"The board-seeded save did not load: "+app._save_notice.text)
	return stats if failures==0 else {}

## 141-162: Gunant's talk and the plasma kit; Kernstal refused until the kit
## is fitted, then the lesson: the waypoint, an Ion Lambda into the cloud and
## the sparks gathered into the hold; the Chromo Plasma built and handed over
## at Var Lupra (the test supplies the plasma a player would gather); Harval's
## fly-past and the destroyed array; the Void calls (147/152) and the
## penthouse bar; Brent; the Valkyrie ambush lines in the Void (154); the
## call and Damarque; the final battle at Var Lupra and Harval's end at Luur;
## the hero's talk, the two cutaways and docked at Maissa at 162, the
## Supernova campaign won. Then a Ginoya flight without radiation.
const VAR_HASTRA:=78
const KERNSTAL:=79
const VAR_LUPRA:=112
const KERNSTAL_WAYPOINT:=Vector3(90000,0,42000)
const KERNSTAL_CLOUD:=Vector3(92000,0,36000)
func fly_supernova_finale() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==141,"The Var Lupra checkpoint is not at cursor 141")
	if failures or not seed_cargo([[122,12]]):return
	# 142's plasma collector needs a turret slot: a player buys such a hull
	# where one is sold (here, or B'akrram's yard).
	if int(catalogue.tables.ships[int(app.session.station_owner().snapshot().loadout.ship_id)].stats.turret_slots)<1 and not await buy_turret_hull():
		if failures or not await depart_to(58) or not await dock_application() or not await buy_turret_hull():check(false,"No turret hull at Var Lupra or B'akrram");return
	if not await travel_and_talk(VAR_HASTRA,141,142):return
	var docked: Dictionary=app.session.station_owner().snapshot()
	var project: Array=docked.contracts.blueprints.entries.filter(func(row):return row.item_id==210)
	print("SUPERNOVA 141 blueprint ",project," hold ",docked.cargo.entries.map(func(row):return [row.item_id,row.quantity]))
	check(not project.is_empty() and project[0].available and [196,197,198].all(func(id):return docked.cargo.entries.any(func(row):return int(row.item_id)==id)),"141 did not hand over the Chromo Plasma blueprint and the plasma kit")
	if failures:return
	# The kit fills the hold: sell the leftovers (not the kit or the recipe's goods).
	if not app.equipment_action("open"):check(false,app.session.error);return
	sell_hold([196,197,198,175,137]+Array(catalogue.tables.items[210].arrays[0]))
	# Earlier stages each topped up item 122: keep one stack of 12.
	var spare:=0
	for row in app.session.station_owner().snapshot().cargo.entries:
		if int(row.item_id)==122:spare+=int(row.quantity)
	for unit in maxi(0,spare-12):
		if not app.equipment_action("sell",122):break
	print("SUPERNOVA 141 hold cleared ",app.session.station_owner().snapshot().cargo.entries.map(func(row):return [row.item_id,row.quantity])," free ",app.session.station_owner().snapshot().cargo.free_space)
	app.equipment_action("close")
	# 142 refused while the kit is not fitted (3205).
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	var refused: RefCounted=app.session.flight_owner().select_map_destination(KERNSTAL)
	print("SUPERNOVA Kernstal without the kit: ",refused._notices.snapshot() if refused!=null else app.session.flight_owner().error)
	check(refused!=null and int(refused._pending_destination)!=KERNSTAL,"A course to Kernstal was set without the plasma kit")
	if failures or not await dock_application():return
	# The collector needs a turret slot: change to a hull with one if needed.
	if int(catalogue.tables.ships[int(docked.loadout.ship_id)].stats.turret_slots)<1:
		var offers: Array=await shipyard()
		var credits:=int(app.session.station_owner().snapshot().contracts.credits)
		var fit: Array=offers.filter(func(row):var stats: Dictionary=catalogue.tables.ships[int(row.ship_id)].stats;return stats.turret_slots>=1 and stats.secondary_slots>=1 and stats.equipment_slots>=4 and int(row.unit_price)<credits)
		print("SUPERNOVA Var Hastra yard ",offers.map(func(row):return [row.ship_id,row.unit_price])," turret hulls ",fit.map(func(row):return row.ship_id))
		if fit.is_empty() or not app.equipment_action("open") or not app.equipment_action("buy_ship",offers.find(fit[0])):check(false,"No turret hull for the plasma collector: "+app.session.error);return
		app.equipment_action("close")
		if not fit_item(85):return
	for id in [196,198,197]:
		if not fit_item(id):return
	var slots: Array=app.session.station_owner().snapshot().loadout.slots
	print("SUPERNOVA plasma kit fitted ",slots.filter(func(slot):return slot!=null).map(func(slot):return [slot.item_id,slot.get("quantity",1)]))
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	if not await travel_application(KERNSTAL):return
	check(app.session.flight_owner()._gas.get("clouds",[]).any(func(cloud):return Vector3(cloud.position)==KERNSTAL_CLOUD),"Kernstal has no lesson gas cloud with the spectral filter fitted")
	if failures or not app.open_secondary_menu(now_us) or not app.session.confirm_secondary(197,now_us):check(false,"The Ion Lambda could not be selected: "+app.status.text+app.session.error);return
	await capture_free_application("supernova-kernstal-cloud")
	var radio_ids:=[];var shots:=[0];var near:=[false,false]
	var lesson:=func(frame):
		var heard: Array=frame._radio.snapshot().get("finished",[])
		if heard.size()<4 or heard[3]!=true:return KERNSTAL_WAYPOINT
		var sparks: Array=frame._gas.get("sparks",[]);var at: Vector3=app.session.snapshot().player_pose.origin
		# Approach like a player: stop 4 km short of the cloud, then turn in and fire.
		var standoff: Vector3=KERNSTAL_CLOUD+(KERNSTAL_WAYPOINT-KERNSTAL_CLOUD).normalized()*4000.0
		if not frame._gas_ionized and not near[0]:
			if at.distance_to(standoff)>1200:return standoff
			near[0]=true
		if not frame._gas_ionized or sparks.is_empty():return KERNSTAL_CLOUD
		# The collector works in turret view only. Sparks burst out of the
		# cloud away from the shot: look at the cloud from turret view and
		# let the collector pull them in.
		if app.session.turret_state().get("active",false):
			var view: Transform3D=frame._camera.snapshot().pose
			var reach: Array=sparks.filter(func(spark):return Vector3(spark.position).distance_to(at)<38000.0)
			if int(frame._gas.get("pulling",0))>0 and not near[1]:near[1]=true;print("SUPERNOVA Kernstal collector pulling, crosshair ",app.session.snapshot().get("player_aim",{}).get("image_id"))
			if reach.is_empty():return null
			reach.sort_custom(func(a,b):return (-view.basis.z).angle_to(Vector3(a.position)-view.origin)<(-view.basis.z).angle_to(Vector3(b.position)-view.origin))
			return {"turret_aim":Vector3(reach[0].position)}
		# Stop first: the ship keeps its speed in turret view.
		if app.session.snapshot().input_throttle>0.01:return at
		if app.session.action("turret"):print("SUPERNOVA Kernstal turret view with ",sparks.size()," sparks")
		else:print("SUPERNOVA Kernstal turret refused: ",app.session.error)
		return null
	var fire:=func(frame):
		var heard: Array=frame._radio.snapshot().get("finished",[])
		var pose: Transform3D=app.session.snapshot().player_pose;var to: Vector3=KERNSTAL_CLOUD-pose.origin
		if frame._gas_ionized or heard.size()<4 or heard[3]!=true or to.length()>9000 or (to.length()>1500 and (-pose.basis.z).angle_to(to)>0.3) or shots[0]>=10:return false
		shots[0]+=1;print("SUPERNOVA Kernstal ion shot at ",int(to.length())," m");return true
	if not await story_flight(142,"kernstal",lesson,func(_frame):return [],radio_ids,900,600.0,fire):return
	var plasma: Array=app.session.snapshot().cargo.entries.filter(func(row):return int(row.item_id) in [201,202,203,204])
	print("SUPERNOVA Kernstal radio ",radio_ids," shots ",shots[0]," plasma ",plasma.map(func(row):return [row.item_id,row.quantity]))
	check(2945 in radio_ids and not plasma.is_empty(),"The Kernstal lesson ended without plasma in the hold")
	await capture_free_application("supernova-kernstal-sparks")
	if failures or not await khador_jump(VAR_LUPRA) or not await dock_application():return
	# 143: build the Chromo Plasma at Var Lupra; the test supplies what is missing.
	project=app.session.station_owner().snapshot().contracts.blueprints.entries.filter(func(row):return row.item_id==210)
	# The hold can't take every material at once: top up and hand in one load at a time.
	var materials: Array=Array(catalogue.tables.items[210].arrays[0])
	print("SUPERNOVA blueprint 210 remaining ",project[0].remaining)
	for index in materials.size():
		var item:=int(materials[index]);var need:=int(project[0].remaining[index])
		while need>0:
			var cargo: Dictionary=app.session.station_owner().snapshot().cargo;var have:=0
			for row in cargo.entries:if int(row.item_id)==item:have+=int(row.quantity)
			var load:=mini(need,have+int(cargo.free_space))
			if load<=0:check(false,"No hold space for plasma "+str(item));return
			if load>have and not seed_cargo([[item,load-have]]):return
			if not app.equipment_action("open") or not app.equipment_action("supply_blueprint",210,item,load):check(false,"Supplying plasma "+str(item)+" failed: "+app.session.error);return
			app.equipment_action("close");need-=load
	check(app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==210),"The Chromo Plasma was not built")
	if failures or not await take_station_talk(143,144):return
	# 144: launched at Var Lupra for Harval's fly-past; 145: the array destroyed.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await locked_launch():check(false,app.status.text);return
	await capture_free_application("supernova-harval-144")
	var scene:=[]
	# The 145 launch point is Var Lupra, where the pilot already is: a fresh
	# flight starts there.
	if not await ride_story_jump(scene,120) or not await enter_story_arrival("supernova-145"):return
	print("SUPERNOVA 144 radio ",scene)
	check(app.session.snapshot().campaign_cursor==145 and [2957,2958,2959,2960].all(func(id):return id in scene),"Harval's fly-past did not play through to 145")
	if failures or not await wait_story_cursor(146,"supernova-array"):return
	if not await dock_application() or not await take_station_talk(146,147):return
	# 147: Alice's call in the Void; the story moves on as the pilot leaves.
	if not await void_visit(147,148,[2977,2986]):return
	# 148: the penthouse bar at Kalun Amir plays 151's talk (-> 152).
	if not await travel_and_talk(96,148,152):return
	if not await void_visit(152,153,[3009,3016]):return
	# The plasma kit's hull is done with: the toughest hull on sale here (Kalun
	# Amir) and its best kit for the ambush (the same test shortcut as at Maissa).
	var armour:=top_protection()
	if failures or not seed_cargo([[122,12]]+armour.map(func(id):return [id,1]),7000000) or not await outfit_for_combat() or not fit_same_type(armour) or not fit_best_guns():return
	if not await travel_and_talk(98,153,154):return
	check(app.save_station(false) and DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-154.gof2save"))==OK,"The 154 checkpoint could not be kept")
	if failures:return
	await fly_supernova_ambush()

## 154 to the end, from the outfitted 154 checkpoint at station 98.
func fly_supernova_ambush() -> void:
	if OS.get_environment("GOF2_VALKYRIE_STAGE")=="supernova154":
		app.set_player_mode(true);app.show();app.present_session()
		await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==154,"The ambush checkpoint is not at cursor 154")
	if failures:return
	# Neither Kalun Amir nor this yard sells a hull for the ambush (stock is
	# random per visit): a long career's tougher hull, same slots (test shortcut).
	if not seed_shipyard() or not await outfit_for_combat() or not fit_same_type(top_protection()) or not fit_best_guns():return
	# The Gamma Shield II built at 104 goes back on for Var Lupra's radiation.
	if not app.session.station_owner().snapshot().loadout.equipment_ids.has(206):
		if not seed_cargo([[206,1]]) or not fit_item(206):return
	print("SUPERNOVA ambush ship ",app.session.station_owner().snapshot().loadout.ship_id," ",catalogue.tables.ships[int(app.session.station_owner().snapshot().loadout.ship_id)].stats.armor)
	var radio_ids:=[];var scene:=[]
	# 154: the Valkyrie ambush in the Void: the freighter, Valkyrie and twenty
	# Void fighters; after Keith's "90 seconds" dock at Valkyrie (actor 1) and
	# win the hack before the countdown ends; the drive then takes the pilot out.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	var before_void: int=int(app.session.snapshot().location.station_id)
	if not await void_drive(true):return
	var cast: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
	check(cast.size()==22 and cast[1].get("static_object",false) and range(2,22).all(func(id):return int(cast[id].actor_kind)==9),"The Void at 154 has no Valkyrie ambush cast")
	await capture_free_application("supernova-void-154")
	# Make for Valkyrie at once (as a player would) and wait beside it to dock.
	var valkyrie:=func(frame):return frame._encounter.combat_snapshot().actors[1].pose.origin
	# The fighters are left to chase: dock and win the hack before the countdown ends.
	if failures or not await story_flight(154,"valkyrie",valkyrie,func(_frame):return [],radio_ids,600,1500.0):return
	print("SUPERNOVA 154 radio ",radio_ids)
	check(3039 in radio_ids and app.session.flight_owner()._objective.snapshot().campaign_cursor==155,"Boarding Valkyrie did not move the story to 155")
	scene=[]
	if failures or not await ride_story_jump(scene,120) or not await enter_story_arrival("supernova-155"):return
	print("SUPERNOVA 154 out at ",app.session.snapshot().location.station_id)
	check(app.session.snapshot().campaign_cursor==155 and int(app.session.snapshot().location.station_id)==before_void,"The drive did not bring the pilot back from the Valkyrie ambush at 155")
	if failures or not await wait_story_cursor(156,"supernova-brent-call"):return
	if not await travel_and_talk(99,156,157,true):return
	# 157: the final battle at Var Lupra; the reversal; through to Luur (158).
	if not await depart_to(VAR_LUPRA):return
	await capture_free_application("supernova-armada")
	radio_ids=[]
	var enemies:=func(frame):
		var actors: Array=frame._encounter.combat_snapshot().actors;var at: Vector3=app.session.snapshot().player_pose.origin
		var live:=func(id):return int(actors[id].vitals.hull)>0 and actors[id].get("active",false) and int(actors[id].get("actor_mode",0))!=5 and not actors[id].get("targeting_blocked",false)
		# Line 3072 waits for the flagship (21) at half hull: go for it first.
		if 3070 in radio_ids and live.call(21) and not 3072 in radio_ids:return [21]
		return range(11,22).filter(func(id):return live.call(id) and actors[id].pose.origin.distance_to(at)<40000)
	if not await story_flight(157,"armada",func(_frame):return null,enemies,radio_ids,1200):return
	print("SUPERNOVA 157 radio ",radio_ids)
	# Alice fired the array: the flares go and the sun shrinks before the jump.
	if app.session.status=="running":
		check(app.session.snapshot().get("supernova_reversed",false) and app.session.scene.sky._flares.is_empty(),"The supernova did not reverse in the sky at 157")
		await capture_free_application("supernova-reversal")
	scene=[]
	if app.session.status=="running" and not await ride_story_jump(scene,60):return
	if not await enter_story_arrival("supernova-158"):return
	check(int(app.session.snapshot().location.station_id)==111 and app.session.snapshot().campaign_cursor==158,"The reversal did not take the ship to Luur for 158")
	await capture_free_application("supernova-luur-158")
	radio_ids=[]
	var harval:=func(frame):
		var actors: Array=frame._encounter.combat_snapshot().actors
		return [0] if int(actors[0].vitals.hull)>0 and actors[0].get("active",false) and int(actors[0].get("actor_mode",0))!=5 else []
	if failures or not await story_flight(158,"harval",func(_frame):return null,harval,radio_ids,1200):return
	print("SUPERNOVA 158 radio ",radio_ids)
	check(3093 in radio_ids and app.session.flight_owner()._objective.snapshot().campaign_cursor==159,"Harval's end did not move the story to 159")
	await capture_free_application("supernova-harval-dead")
	if failures or not await khador_jump(10) or not await dock_application() or not await take_station_talk(159,160):return
	check(app.save_station(false) and DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-160.gof2save"))==OK,"The 160 checkpoint could not be kept")
	if failures:return
	await fly_supernova_end()

## 160 to the end, from the 160 checkpoint docked at station 10.
func fly_supernova_end() -> void:
	var scene:=[]
	if OS.get_environment("GOF2_VALKYRIE_STAGE")=="supernova160":
		app.set_player_mode(true);app.show();app.present_session()
		await process_frame;resume_application_focus()
	check(app.session.station_owner().snapshot().campaign_cursor==160,"The end checkpoint is not at cursor 160")
	if failures:return
	# 160-161: the two cutaways; then docked at Maissa at 162.
	# The cutaway keeps the player locked: no controls to wait for.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	for leg in [[93,161,"supernova-maissa-161"],[93,162,"supernova-maissa-162"]]:
		scene=[]
		# Both arrivals are cutaways or docked: no flight controls to wait for.
		if not await ride_story_jump(scene,300) or not await enter_story_arrival(leg[2],false):return
		print("SUPERNOVA ",leg[2]," radio ",scene)
		check(int(app.session.snapshot().location.station_id)==leg[0] and app.session.snapshot().campaign_cursor==leg[1],"The story did not reach %d at Maissa"%leg[1])
		if failures:return
	if not await dock_application():return
	await capture_free_application("supernova-won")
	check(app.save_station(false) and app.load_station(),"Saving and resuming the won Supernova career failed: "+app._save_notice.text)
	if failures:return
	check(app.session.station_owner().snapshot().campaign_cursor==162,"Fresh Resume lost the end of Supernova")
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_CAPTURE_DIR").path_join("supernova-162.gof2save"))==OK,"The 162 checkpoint could not be kept")
	# After the end: Ginoya without radiation.
	if failures or not await depart_to(VAR_LUPRA):return
	await capture_free_application("supernova-ginoya-after")
	check(float(app.session.flight_owner()._gamma_rate)==0.0,"Var Lupra still drains gamma after the reversal")

## Flies on until the radio has shown every line in `ids` (talk arrivals).
func hear_lines(label: String,ids: Array,seconds:=90) -> bool:
	var heard:=[];var began:=now_us
	app.session.rebase_time(now_us)
	while now_us-began<seconds*1000000 and not ids.all(func(id):return id in heard):
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot() if app.session.flight_owner()._radio!=null else {}
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
		if not application_step():return false
		if (now_us-began)%1000000<100000:await process_frame
	print("VALKYRIE ",label," radio ",heard)
	var f: RefCounted=app.session.flight_owner()
	check(ids.all(func(id):return id in heard),label+": the arrival lines did not all play: "+str(heard))
	return failures==0

## A call in the alien world: into the Void, the lines from `lines[0]` to
## `lines[1]`, then back out with the drive; the story moves to `next`.
func void_visit(cursor: int,next: int,lines: Array) -> bool:
	# The drive in and back out needs energy cells (a player buys them here).
	var cells:=0
	for row in app.session.station_owner().snapshot().cargo.entries:if int(row.item_id)==122:cells+=int(row.quantity)
	print("SUPERNOVA Void ",cursor," energy cells ",cells)
	if cells<12 and not seed_cargo([[122,12-cells]]):return false
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return false
	if not await void_drive(true):return false
	# Void ships close in during the call: fight them while it plays.
	var heard:=[]
	var over:=func():
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
		return int(lines[1]) in heard and not radio.get("visible",false)
	if not await fight_until("void-%d"%cursor,over,func(actors):return actors.filter(func(actor):return actor.hostile and actor.vitals.hull>0).map(func(actor):return int(actor.actor_id)),heard,1500):return false
	print("SUPERNOVA Void ",cursor," radio ",heard)
	check(int(lines[0]) in heard and int(lines[1]) in heard,"The Void call for %d did not play"%cursor)
	await capture_free_application("supernova-void-%d"%cursor)
	if failures or not await void_drive(false):return false
	check(app.session.snapshot().campaign_cursor==next,"Leaving the Void did not move the story to %d"%next)
	return failures==0 and await dock_application()

## The Khador Drive into the Void (its question answered yes) or back out.
func void_drive(into: bool) -> bool:
	resume_application_focus()
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.physical_keycode=KEY_K;key.keycode=KEY_K;key.pressed=pressed;app._unhandled_input(key)
	if into:
		check(app.map_panel.visible and app.map_panel.snapshot().get("void_prompt",false),"The drive did not offer the Void")
		if failures:return false
		for pressed in [true,false]:
			var key:=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.keycode=KEY_ENTER;key.pressed=pressed;app._unhandled_input(key)
	var began:=now_us
	app.session.rebase_time(now_us)
	while app.session.status=="running" and now_us-began<15000000:
		if not application_step():return false
	check(app.session.status=="drive_arrival_transition_required","The drive did not leave %s: %s"%["for the Void" if into else "the Void",app.session.status])
	if failures or not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return failures==0 and await release_application_flight()

## One story flight until the story leaves `cursor`: hacking puzzles are
## solved with the arrow keys, `hostiles` (frame -> ids) are fought, and
## otherwise the ship flies to `goal` (frame -> point or null to hold),
## slowing to a stop within `slow` of it (a docking point).
## A cutaway launch keeps the player locked: wait only for the flight to start.
func locked_launch() -> bool:
	for tick in 71:
		if app.session.flight_audio!=null:return true
		if not application_step():return false
	check(false,"The locked launch never started the flight");return false

func story_flight(cursor: int,label: String,goal: Callable,hostiles: Callable,radio_ids: Array,seconds:=1200,slow:=2500.0,fire: Callable=Callable()) -> bool:
	var began:=now_us;var hacking:=false
	app.session.rebase_time(now_us)
	for tick in seconds*10:
		var frame: RefCounted=app.session.flight_owner()
		if app.session.status!="running" or frame._objective.snapshot().campaign_cursor!=cursor:return true
		if frame.death_active():
			var dead: Dictionary=app.session.snapshot();var where: Vector3=dead.player_pose.origin
			check(false,label+": the player died "+str(dead.player.vitals)+" at "+str(where)+" after "+str((now_us-began)/1000000)+" s, nearest "+str(frame._encounter.combat_snapshot().actors.map(func(actor):return [int(actor.actor_id),int(Vector3(actor.pose.origin).distance_to(where))]).filter(func(row):return row[1]<5000)));return false
		var radio: Dictionary=frame._radio.snapshot() if frame._radio!=null else {}
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		var puzzle: Dictionary=frame.story_hack_state()
		if not puzzle.is_empty():
			if not hacking:hacking=true;print("SUPERNOVA ",label," hacking at ",(now_us-began)/1000000," s");await capture_free_application("supernova-%s-hack"%label)
			if not bool(puzzle.get("won",false)) and String(puzzle.turning).is_empty() and int(puzzle.solved_ms)<0:
				var moves:=hack_solution(puzzle.board,puzzle.target)
				if not moves.is_empty():
					for pressed in [true,false]:
						var key:=InputEventKey.new();key.physical_keycode=KEY_LEFT if moves[0]=="left" else KEY_RIGHT;key.keycode=key.physical_keycode;key.pressed=pressed;app._unhandled_input(key)
			if not application_step():return false
			if tick%5==0:await process_frame
			continue
		hacking=false
		if not hostiles.call(frame).is_empty():
			var over:=func():return hostiles.call(app.session.flight_owner()).is_empty() or app.session.flight_owner()._objective.snapshot().campaign_cursor!=cursor
			if not await fight_until(label,over,func(_actors):return hostiles.call(app.session.flight_owner()),radio_ids):return false
			continue
		var state: Dictionary=app.session.snapshot()
		var target: Variant=goal.call(frame)
		var steer:=Vector2.ZERO;var want:=0.0
		if target is Vector3:
			# A target dead astern gives no turn direction: turn toward the side first.
			var pose: Transform3D=state.player_pose
			var aim: Vector3=target if (-pose.basis.z).angle_to(target-pose.origin)<2.8 else pose.origin+pose.basis.x*1000.0
			steer=missile_steering({"basis":pose.basis,"position":pose.origin},aim)
			want=1.0 if pose.origin.distance_to(target)>slow else 0.0
		elif target is Dictionary and target.has("turret_aim"):
			# Turret view: the stick swings the turret camera; the ship holds still.
			var view: Transform3D=frame._camera.snapshot().pose
			var local: Vector3=view.basis.inverse()*(Vector3(target.turret_aim)-view.origin)
			var length:=maxf(local.length(),1.0)
			steer=Vector2(clampf(-4.0*local.y/length,-1.0,1.0),clampf(-4.0*local.x/length,-1.0,1.0))
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-want)<.01 or frame.cinematic_input_blocked():break
			if not app.session.action("throttle_up" if current<want else "throttle_down"):check(false,app.session.error);return false
		if fire.is_valid() and fire.call(frame) and not app.session.action("missiles"):check(false,app.session.error);return false
		now_us+=100000
		if not app.session.step(now_us,steer if not frame.cinematic_input_blocked() else Vector2.ZERO,false,false,0.0):check(false,app.session.error);return false
		app.present_session()
		await watch_cutscene(label)
		await dismiss_medal()
		if tick%10==0:await process_frame
		if not keep_unharmed(label):return false
		if tick%600==0:print("SUPERNOVA ",label," ",(now_us-began)/1000000," s at ",Vector3i(app.session.snapshot().player_pose.origin)," dock ",frame._story_dock.get("docked")," status ",frame._story_dock.get("status")," radio ",radio_ids)
	check(false,label+": the story stayed at "+str(cursor)+" radio "+str(radio_ids))
	return false

## Leave the station and Khador-jump to `station` (no jump when already there).
func depart_to(station: int) -> bool:
	# Already in flight (back out of the Void): no departure.
	if app.station_shell.visible:
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
		if not await release_application_flight():return false
	if int(app.session.snapshot().location.station_id)==station:return true
	return await khador_jump(station)

## Fly to `station`, dock and take the talk from `cursor` to `next`.
func travel_and_talk(station: int,cursor: int,next: int,redock:=false) -> bool:
	if redock or docked_station()!=station:
		if not await depart_to(station) or not await dock_application():return false
	return await take_station_talk(cursor,next)

## A kind-170 cutaway at `at`, then the story's move to `after` for `next`.
func story_cutaway(at: int,after: int,next: int,label: String) -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	var moved:=[]
	if not await ride_story_jump(moved,30) or not await enter_story_arrival(label,false):return false
	check(int(app.session.snapshot().location.station_id)==at,"The story did not take the ship to %d for its cutaway"%at)
	await capture_free_application(label)
	var scene:=[]
	if not await ride_story_jump(scene,300):return false
	print("SUPERNOVA cutaway ",label," radio ",scene)
	if failures or not await enter_story_arrival(label):return false
	check(int(app.session.snapshot().location.station_id)==after and app.session.snapshot().campaign_cursor==next,"The cutaway did not end at %d for %d"%[after,next])
	return failures==0 and await dock_application()

## 125: fly the course, beat the pirates, dock at each Secure Container and
## solve its puzzle with the arrow keys.
func kappa_black_box() -> bool:
	var radio_ids:=[];var hacked:=[];var hacking:=false
	var began:=now_us
	app.session.rebase_time(now_us)
	for tick in 60000:
		var frame: RefCounted=app.session.flight_owner()
		if app.session.status!="running" or frame._objective.snapshot().campaign_cursor!=125:break
		if frame.death_active():check(false,"The player died at Kappa: "+str(app.session.snapshot().player.vitals));return false
		var radio: Dictionary=frame._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		var actors: Array=frame._encounter.combat_snapshot().actors
		var state: Dictionary=app.session.snapshot()
		var puzzle: Dictionary=frame.story_hack_state()
		if not puzzle.is_empty():
			if not hacking:hacking=true;print("SUPERNOVA hacking container ",frame._story_dock.docked," at ",(now_us-began)/1000000," s");await capture_free_application("supernova-kappa-hack-%d"%hacked.size())
			if not bool(puzzle.get("won",false)) and String(puzzle.turning).is_empty() and int(puzzle.solved_ms)<0:
				var moves:=hack_solution(puzzle.board,puzzle.target)
				if not moves.is_empty():
					for pressed in [true,false]:
						var key:=InputEventKey.new();key.physical_keycode=KEY_LEFT if moves[0]=="left" else KEY_RIGHT;key.keycode=key.physical_keycode;key.pressed=pressed;app._unhandled_input(key)
			if not application_step():return false
			if tick%5==0:await process_frame
			continue
		if hacking:
			hacking=false
			if int(frame._story_dock.get("last_hacked",-1))>=0 and int(frame._story_dock.last_hacked) not in hacked:hacked.append(int(frame._story_dock.last_hacked))
		var hostile: Array=range(0,8).filter(func(id):return int(actors[id].vitals.hull)>0 and actors[id].get("active",false) and actors[id].get("model_draw_enabled",true) and actors[id].pose.origin.distance_to(state.player_pose.origin)<20000)
		if not hostile.is_empty():
			var living:=func():
				var now: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
				return range(0,8).filter(func(id):return int(now[id].vitals.hull)>0 and now[id].get("active",false) and now[id].get("model_draw_enabled",true))
			if not await fight_until("kappa",func():return living.call().is_empty() or app.session.flight_owner()._objective.snapshot().campaign_cursor!=125,func(_actors):return living.call(),radio_ids):return false
			continue
		var target: Variant=frame.story_route_point()
		var open: bool=2806 in radio_ids
		var left: Array=range(8,11).filter(func(id):return id not in hacked and actors[id].get("model_draw_enabled",true))
		if open and not left.is_empty():
			left.sort_custom(func(a,b):return actors[a].pose.origin.distance_to(state.player_pose.origin)<actors[b].pose.origin.distance_to(state.player_pose.origin))
			target=actors[left[0]].pose.origin
		var steer:=Vector2.ZERO;var want:=0.0
		if target is Vector3:
			var distance: float=state.player_pose.origin.distance_to(target)
			steer=missile_steering({"basis":state.player_pose.basis,"position":state.player_pose.origin},target);want=1.0 if distance>(2500.0 if open else 3000.0) else 0.15
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-want)<.01 or frame.cinematic_input_blocked() or not app.session.can_control():break
			if not app.session.action("throttle_up" if current<want else "throttle_down"):check(false,app.session.error);return false
		now_us+=100000
		if not app.session.step(now_us,steer if not frame.cinematic_input_blocked() else Vector2.ZERO,false,false,0.0):check(false,app.session.error);return false
		app.present_session()
		await watch_cutscene("kappa125")
		await dismiss_medal()
		if tick%10==0:await process_frame
		if tick%600==0:print("SUPERNOVA Kappa ",(now_us-began)/1000000," s hacked ",hacked," radio ",radio_ids)
	print("SUPERNOVA Kappa radio ",radio_ids," hacked ",hacked," status ",app.session.status)
	check(hacked.size()==3 and 2810 in radio_ids,"The three containers were not all hacked")
	return failures==0

## The shortest button sequence that turns `board` into `target`.
func hack_solution(board: Array,target: Array) -> Array:
	var Hacking=load("res://src/simulation/hacking_game.gd")
	var frontier:=[[board,[]]];var seen:={str(board):true}
	while not frontier.is_empty():
		var next:=[]
		for row in frontier:
			if row[0]==target:return row[1]
			for button in ["left","right"]:
				var turned: Array=Hacking._turned(row[0],button)
				if not seen.has(str(turned)):seen[str(turned)]=true;next.append([turned,row[1]+[button]])
		frontier=next
	return []

## Swap passenger cabins for the best shield, armour and repair device on sale.
func refit_protection() -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var shop: Dictionary=app.session.station_owner().snapshot()
	for index in range(shop.loadout.slots.size()-1,-1,-1):
		var slot: Variant=shop.loadout.slots[index]
		if slot!=null and int(catalogue.tables.items[int(slot.item_id)].properties.get(2,-1))==20:
			if not app.equipment_action("unmount",int(slot.item_id),index):check(false,app.session.error);return false
	for kind in [9,10,15]:
		var rows: Array=app.session.station_owner().snapshot().equipment.market_rows.filter(func(row):return int(catalogue.tables.items[row.item_id].properties.get(2,-1))==kind and int(row.stock)>0 and int(row.unit_price)<=int(app.session.station_owner().snapshot().contracts.credits))
		rows.sort_custom(func(a,b):return int(a.unit_price)>int(b.unit_price))
		if rows.is_empty():continue
		if not app.equipment_action("buy",int(rows[0].item_id)) or not app.equipment_action("mount",int(rows[0].item_id)):print("SUPERNOVA protection refused ",rows[0].item_id," ",app.session.error)
	print("SUPERNOVA refit items ",app.session.station_owner().snapshot().loadout.equipment_ids)
	return app.equipment_action("close")

## The highest-tier shield (type 9) and armour (type 10) item ids.
func top_protection() -> Array:
	var best:=[]
	for kind in [9,10]:
		var ids: Array=catalogue.tables.items.keys().filter(func(id):return int(catalogue.tables.items[id].properties.get(2,-1))==kind) if catalogue.tables.items is Dictionary else range(catalogue.tables.items.size()).filter(func(id):return catalogue.tables.items[id]!=null and int(catalogue.tables.items[id].properties.get(2,-1))==kind)
		if not ids.is_empty():best.append(int(ids.max()))
	print("SUPERNOVA top protection ",best)
	return best

## Fit hold items in place of any fitted item of the same type.
func fit_same_type(ids: Array) -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	for id in ids:
		var slots: Array=app.session.station_owner().snapshot().loadout.slots
		for index in range(slots.size()-1,-1,-1):
			if slots[index]!=null and int(catalogue.tables.items[int(slots[index].item_id)].properties.get(2,-1))==int(catalogue.tables.items[id].properties.get(2,-1)):
				if not app.equipment_action("unmount",int(slots[index].item_id),index):check(false,app.session.error);return false
		if not app.equipment_action("mount",id):check(false,"Item "+str(id)+" could not be fitted: "+app.session.error);return false
	print("SUPERNOVA protection fitted ",app.session.station_owner().snapshot().loadout.equipment_ids)
	return app.equipment_action("close")

## Fit an item from the hold, making room in its category if needed.
func fit_item(item_id: int) -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var shop: Dictionary=app.session.station_owner().snapshot()
	if not shop.equipment.fitting_support.get(item_id,{}).is_empty():
		var category: int=int(catalogue.tables.items[item_id].properties.get(1,-1))
		for index in shop.loadout.slots.size():
			var slot: Variant=shop.loadout.slots[index]
			if slot==null or int(slot.item_id)==85:continue
			var own: Dictionary=catalogue.tables.items[int(slot.item_id)].properties
			if int(own.get(1,-1))==category and int(own.get(2,-1))!=20:
				if not app.equipment_action("unmount",int(slot.item_id),index):check(false,app.session.error);return false
				break
	# All slots taken: unfit one item of its category (not the drive or the
	# top shield/armour) and try again.
	if not app.equipment_action("mount",item_id):
		var slots: Array=app.session.station_owner().snapshot().loadout.slots
		var category: int=int(catalogue.tables.items[item_id].properties.get(1,-1))
		for index in range(slots.size()-1,-1,-1):
			if slots[index]!=null and int(slots[index].item_id) not in [85,225,59] and int(catalogue.tables.items[int(slots[index].item_id)].properties.get(1,-1))==category:
				app.equipment_action("unmount",int(slots[index].item_id),index);break
	if not app.session.station_owner().snapshot().loadout.equipment_ids.has(item_id) and not app.equipment_action("mount",item_id):check(false,"Item "+str(item_id)+" could not be fitted: "+app.session.error+" "+str(app.session.station_owner().snapshot().equipment.fitting_support.get(item_id)));return false
	print("SUPERNOVA fitted ",item_id," properties ",catalogue.tables.items[item_id].properties)
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return true

## Buy and fit passenger cabins at the current station until the ship has
## `needed` berths, making room by unfitting non-essential equipment.
func fit_cabins(needed: int,best_effort:=false) -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	for attempt in 12:
		var shop: Dictionary=app.session.station_owner().snapshot()
		if load("res://src/simulation/first_flight_frame.gd")._passenger_berths(catalogue,shop.loadout)>=needed:break
		var cabin:={}
		for row in shop.equipment.market_rows:
			var properties: Dictionary=catalogue.tables.items[row.item_id].properties
			if int(properties.get(2,-1))==20 and row.stock>0 and row.unit_price<=shop.contracts.credits:
				if cabin.is_empty() or int(properties.get(34,0))>cabin.places:cabin={"item_id":row.item_id,"price":row.unit_price,"places":int(properties.get(34,0))}
		if cabin.is_empty() and best_effort:break
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
			if not freed and best_effort:break
			if not freed:check(false,"No slot to free for a cabin: "+str(shop.equipment.fitting_support.get(cabin.item_id)));return false
		if not app.equipment_action("buy",int(cabin.item_id)) or not app.equipment_action("mount",int(cabin.item_id)):check(false,app.session.error);return false
		print("SUPERNOVA fitted cabin ",cabin)
	var fitted: Dictionary=app.session.station_owner().snapshot()
	var berths: int=load("res://src/simulation/first_flight_frame.gd")._passenger_berths(catalogue,fitted.loadout)
	print("SUPERNOVA berths now ",berths)
	check(best_effort or berths>=needed,"The ship still lacks passenger berths")
	await capture_free_application("supernova-cabins")
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return failures==0

## The hangar's ship offers, as the player sees them.
## Buy the toughest affordable hull with a turret slot here (keeping the
## Khador Drive fitted); false when the yard has none.
func buy_turret_hull() -> bool:
	var offers: Array=await shipyard()
	var credits:=int(app.session.station_owner().snapshot().contracts.credits)
	var fit: Array=offers.filter(func(row):var stats: Dictionary=catalogue.tables.ships[int(row.ship_id)].stats;return stats.turret_slots>=1 and stats.secondary_slots>=1 and stats.equipment_slots>=4 and int(row.unit_price)<credits)
	print("SUPERNOVA turret yard ",docked_station()," ",offers.map(func(row):return row.ship_id)," turret hulls ",fit.map(func(row):return row.ship_id))
	if fit.is_empty():return false
	fit.sort_custom(func(a,b):return int(catalogue.tables.ships[int(a.ship_id)].stats.armor)>int(catalogue.tables.ships[int(b.ship_id)].stats.armor))
	if not app.equipment_action("open") or not app.equipment_action("buy_ship",offers.find(fit[0])):check(false,"The turret hull could not be bought: "+app.session.error);return false
	app.equipment_action("close")
	return fit_item(85)

## Test shortcut: the docked station's yard (stock is random per visit) also
## offers the toughest hull that keeps the current kit's slots.
func seed_shipyard() -> bool:
	var state: Dictionary=app.session.station_owner().snapshot();var station:=int(state.loadout.station_id)
	var ships: Array=catalogue.tables.ships;var current: Dictionary=ships[int(state.loadout.ship_id)].stats
	# Only hulls the yards of the main races sell (affiliation 0-4).
	var affiliations: Array=app.bindings.early_contracts.base_station_stock.ships.affiliations
	var best:=-1;var listed:=[]
	for id in ships.size():
		var stats: Dictionary=ships[id].stats
		if stats.equipment_slots<current.equipment_slots or stats.primary_slots<2 or stats.secondary_slots<1:continue
		listed.append([id,stats.armor,int(affiliations[id])])
		if int(affiliations[id])<0 or int(affiliations[id])>4:continue
		if best<0 or stats.armor>ships[best].stats.armor:best=id
	listed.sort_custom(func(a,b):return a[1]>b[1])
	print("SUPERNOVA yard candidates ",listed.slice(0,8))
	var file:=StationSaveFile.new();var path: String=app.station_save_path();var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	var rows: Array=document.locations.locations.filter(func(row):return int(row.station_id)==station)
	if rows.is_empty() or best<0:check(false,"No yard to seed at station %d"%station);return false
	rows[0].market_ships=[{"ship_id":best,"faction_id":0,"unit_price":1000000}]
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station(),"The seeded yard did not load: "+app._save_notice.text)
	print("SUPERNOVA seeded yard hull ",best," armor ",ships[best].stats.armor)
	return failures==0

## Test shortcut for a long career's ship: the saved hull becomes the
## toughest one with exactly the same slot layout (every fitting stays valid).
func seed_hull() -> bool:
	var state: Dictionary=app.session.station_owner().snapshot();var station:=int(state.loadout.station_id)
	var ships: Array=catalogue.tables.ships;var own:=int(state.loadout.ship_id);var current: Dictionary=ships[own].stats
	var best:=own
	for id in ships.size():
		var stats: Dictionary=ships[id].stats
		if ["primary_slots","secondary_slots","turret_slots","equipment_slots"].any(func(key):return stats[key]!=current[key]):continue
		if stats.armor>ships[best].stats.armor:best=id
	print("SUPERNOVA seeded hull ",own," -> ",best," armor ",ships[best].stats.armor)
	if best==own:return true
	var file:=StationSaveFile.new();var path: String=app.station_save_path();var document: Dictionary=file.read_document(path)
	if document.is_empty():check(false,file.error);return false
	for row in _station_dicts(document,station):
		if row.get("ship_id")==own:row.ship_id=best
		if row.get("ship_instance") is Dictionary and row.ship_instance.get("ship_id")==own:row.ship_instance.ship_id=best
	var bytes:=file.encode(document)
	if bytes.is_empty() or not file._write(path,bytes):check(false,file.error);return false
	check(app.load_station() and int(app.session.station_owner().snapshot().loadout.ship_id)==best,"The seeded hull did not load: "+app._save_notice.text)
	return failures==0

func _station_dicts(node: Variant,station: int) -> Array:
	var found:=[]
	if node is Dictionary:
		if node.get("station_id")==station:found.append(node)
		for value in node.values():found.append_array(_station_dicts(value,station))
	elif node is Array:
		for value in node:found.append_array(_station_dicts(value,station))
	return found

func _station_rows(node: Variant,station: int) -> Array:
	var found:=[]
	if node is Dictionary:
		if node.get("station_id")==station and node.has("market_ships"):found.append(node)
		for value in node.values():found.append_array(_station_rows(value,station))
	elif node is Array:
		for value in node:found.append_array(_station_rows(value,station))
	return found

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

## TEST SHORTCUT (gaps file): Void fighters drain ~290/s at 154 and 157;
## the pilot is kept unharmed there until that is researched
## (GOF2_SUPERNOVA_HARM=valkyrie,armada turns it off per fight).
func keep_unharmed(label: String) -> bool:
	if label not in ["valkyrie","armada","kaamo","pirate_base","loma"] or label in OS.get_environment("GOF2_SUPERNOVA_HARM").split(","):return true
	var live: RefCounted=app.session._world._player
	if bool(live.snapshot().get("damage_allowed",true)) and not live.set_permissions(bool(live.snapshot().active),false):check(false,live.error);return false
	return true

## Local travel inside the current system, the Khador Drive otherwise.
func go_to(station: int) -> bool:
	if int(catalogue.tables.stations[station].system_id)==int(app.session.snapshot().location.system_id):return await travel_application(station)
	return await khador_jump(station)

## Fight the story cast like a player until done() holds; targets(actors)
## lists the actor ids to attack in order.
## Story cutscenes (64-70): ~1 s in, the player is held, the HUD is hidden
## and the camera looks at the named ship; one capture per cutscene.
var cutscene_marks:={}
func watch_cutscene(label: String) -> void:
	if app.session.flight_owner()==null:return
	var scene: Dictionary=app.session.flight_owner()._cutscene
	if not scene.has("eye"):return
	var key:="%s-cutscene%d"%[label,int(scene.key)];var clock:=int(app.session.snapshot().world_elapsed_ms)
	if not cutscene_marks.has(key):cutscene_marks[key]=clock
	if int(cutscene_marks[key])<0 or clock-int(cutscene_marks[key])<1000:return
	cutscene_marks[key]=-1
	var view: Transform3D=app.session.flight_owner()._camera.snapshot().pose
	var target: Vector3=app.session.flight_owner()._cutscene_target()
	var facing:=(-view.basis.z).normalized().dot((target-view.origin).normalized())
	print("VALKYRIE ",key," camera to ship ",int(view.origin.distance_to(target))," facing ",facing)
	check(app.session.flight_owner().cinematic_input_blocked() and not app.session.flight_hud_visible() and facing>.99,"The "+key+" does not hold the player, hide the HUD and look at the ship")
	await capture_free_application("valkyrie-"+key)

func fight_until(label: String,done: Callable,targets: Callable,radio_ids: Array,ticks:=30000,liberate:=false,standoff:=9000.0,refuge:=-1,withdraw_from:=-1) -> bool:
	var pilot:=CombatPilot.new();var captured:=false;var closest:=INF
	var best_shield:=0.0;var retreating:=false
	if liberate and not select_liberator():return false
	for tick in ticks:
		if done.call():return true
		var actors: Array=app.session.flight_owner()._encounter.combat_snapshot().actors
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The player died in "+label+" at tick "+str(tick)+": "+str(state.player.vitals)+" nearest "+str(actors.map(func(actor):return [int(actor.position.distance_to(state.player_pose.origin)),int(actor.pose.origin.distance_to(state.player_pose.origin)),actor.get("firing_allowed"),actor.get("mode")])));return false
		var radio: Dictionary=app.session.flight_owner()._radio.snapshot()
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.text_id))
		await watch_cutscene(label)
		if not keep_unharmed(label):return false
		var input:=pilot.controls(state,tick,targets.call(actors),true)
		# With a friendly refuge, fall back to it while the shield recharges,
		# as a player would against a large pack.
		if refuge>=0 or withdraw_from>=0:
			var shield:=float(state.player.vitals.shield);best_shield=maxf(best_shield,shield)
			if shield<best_shield*.1:retreating=true
			elif shield>=best_shield*.9:retreating=false
			if retreating and withdraw_from>=0:
				# Against gun turrets, pull out of their reach to recharge.
				var away: Vector3=state.player_pose.origin-Vector3(actors[withdraw_from].position)
				input.commands=CombatPilot.Steering.steering_toward(state.player_pose,state.player_pose.origin+away.normalized()*100000.0)
				input.throttle=1.0;input.fire=false;input.strafe=0.0
			elif retreating:
				input=pilot.controls(state,tick,[refuge],true);input.fire=false
				if input.distance>0 and input.distance<2500:input.throttle=0.0
		# Against many snipers, hold back and let the Liberators do the work.
		# (Out of Liberators, close in to gun range.)
		if not retreating and standoff>9000.0 and (not liberate or int(liberator_gun(state).get("ammunition",0))>0) and input.distance>0 and input.distance<standoff:input.throttle=0.0
		var pool:=float(state.player.vitals.hull)+float(state.player.vitals.armor)+float(state.player.vitals.shield)
		if not captured and input.distance>0 and input.distance<6000:captured=true;await capture_free_application("valkyrie-"+label+"-fight")
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01 or not app.session.can_control():break
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
			elif not retreating and input.target>0 and input.distance<standoff and liberator_ready(state):press=true;closest=INF
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
	var liberators:=0;var closest:=INF;var guided_seen:=false
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
			if absf(current-float(input.throttle))<.01 or not app.session.can_control():break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
		# Finish a damaged escort as a player would: R launches the Liberator,
		# the stick flies it at the nearest escort, a second R sets it off close by.
		var missile: Dictionary=liberator_shot(state)
		var press:=false
		if not missile.is_empty() and not guided_seen:
			# Guiding: only the bars and crosshair (no target frame or weapon list).
			guided_seen=true;app.present_session();await capture_free_application("valkyrie-liberator-hud")
			check(state.get("guided_missile",false) and not app.session.scene.target_frame.visible and not app.secondary_panel.visible and not app.flight_vitals._cargo_frame.visible,"The HUD stayed full while guiding a Liberator")
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

## release=false: the arrival opens a story scene that holds the controls.
func khador_jump(destination: int,release:=true) -> bool:
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
	while app.session.status=="running" and now_us-began<40000000:
		if not application_step():return false
	if app.session.status=="running":print("VALKYRIE drive stuck ",app.session.flight_owner()._drive.snapshot().get("phase")," local ",app.session.flight_owner().local_departing()," system ",app.session.snapshot().location.system_id," to ",catalogue.tables.stations[destination].system_id," permits ",app.session.flight_owner().drive_permits_mission()," refusal ",app.session.flight_owner().story_entry_refusal(destination)," rule ",app.session.flight_owner().story_drive_rule()," job ",app.session.flight_owner()._objective.snapshot().get("contracts",{}).get("mission",{}).get("kind")," ctx ",app.session.flight_owner()._mission_context!=null)
	var local: bool=app.session.status=="local_arrival_transition_required"
	check(local or app.session.status=="drive_arrival_transition_required","The Khador jump did not complete: "+app.session.status)
	if failures or not (app.enter_local_arrival(now_us,4096,flight_world_seconds()) if local else app.enter_drive_arrival(now_us,4096,flight_world_seconds())):check(false,app.status.text);return false
	check(app.session.snapshot().location.station_id==destination,"The Khador jump arrived elsewhere")
	return failures==0 and (not release or await release_application_flight())

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
func wait_story_cursor(cursor: int,label: String,radio_ids: Array=[]) -> bool:
	var started:=now_us;var radio_seen:=false
	while app.session.flight_owner()._objective.snapshot().campaign_cursor!=cursor and now_us-started<90000000:
		if not application_step():return false
		await watch_cutscene("story%d"%cursor)
		if app.session.flight_owner().death_active():check(false,"The escape pilot died waiting for cursor "+str(cursor));return false
		if int(now_us/1000000)%2==0:await process_frame
		await dismiss_medal()
		var radio: RefCounted=app.session.flight_owner()._radio
		if radio!=null and radio.snapshot().get("visible",false) and int(radio.snapshot().get("text_id",-1)) not in radio_ids:radio_ids.append(int(radio.snapshot().text_id))
		if not radio_seen and not label.is_empty() and radio!=null and radio.snapshot().get("visible",false) and radio.snapshot().has("scripted_events"):
			radio_seen=true;print("VALKYRIE radio ",radio.snapshot().get("text_id"));await capture_free_application(label+"-radio")
	var seconds:=float(now_us-started)/1000000.0
	print("VALKYRIE cursor ",cursor," after ",seconds," s")
	check(app.session.flight_owner()._objective.snapshot().campaign_cursor==cursor,"The story did not move on to "+str(cursor)+" in flight")
	if failures:return false
	if not label.is_empty():await capture_free_application(label)
	return true

## Fly the earned route to a station, docking at each gate like a player.
## dock=false stops in the destination's orbit (a story flight there).
func story_route(destination: int,dock:=true) -> bool:
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
			if next_system==system_id and gate==destination:return not dock or await dock_application()
			if next_system!=route[-1]:
				if not await dock_application():return false
				if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
				if not await release_application_flight():return false
	if app.session.snapshot().location.station_id!=destination and not await travel_application(destination):return false
	return not dock or await dock_application()

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
		"supernova93":return state.campaign_cursor==93
		"supernova97":return state.campaign_cursor==97
		"supernova100":return state.campaign_cursor==100
		"supernova102":return state.campaign_cursor==102
		"supernova105":return state.campaign_cursor==105
		"supernova109":return state.campaign_cursor==109
		"supernova117":return state.campaign_cursor==117
		"supernova128":return state.campaign_cursor==128
		"supernova135","kaamo","pirate-base","loma","weapons":return state.campaign_cursor==135
		"supernova141":return state.campaign_cursor==141
		"supernova154":return state.campaign_cursor==154
		"supernova160":return state.campaign_cursor==160
		"bounty":return state.campaign_cursor==105
	return super.resumed_contract_valid(state)

## A player crossing hostile Vossk space fights off the ships closing in
## before committing to the gate; the scripted pilot does the same.
func follow_gate_course(system_id: int,station_id: int) -> bool:
	var volatile: bool=app.session.snapshot().get("volatile",false)
	if (OS.get_environment("GOF2_VALKYRIE_STAGE")=="home" or volatile) and not await fight_nearby_hostiles(25000.0):return false
	return await super.follow_gate_course(system_id,station_id)

func fight_nearby_hostiles(radius: float) -> bool:
	var pilot:=CombatPilot.new();var kills:=0;var steer:=Vector2.ZERO
	for tick in 9000:
		var state: Dictionary=app.session.snapshot()
		var threats: Array=state.encounter.combat.actors.filter(func(actor):return actor.get("hostile",false) and actor.vitals.hull>0 and actor.position.distance_to(state.player_pose.origin)<radius).map(func(actor):return actor.actor_id)
		if threats.is_empty():print("VALKYRIE home cleared after ",tick," ticks, ",kills," down, vitals ",state.player.vitals);return true
		if app.session.flight_owner().death_active():check(false,"The escaping K'Suukk was shot down fighting at the gate: "+str(state.player.vitals));return false
		var input:=pilot.controls(state,tick,threats,true)
		# With volatile cargo aboard, ease the stick like a careful player.
		if state.get("volatile",false):
			input.commands=steer+(input.commands-steer).limit_length(.05);steer=input.commands
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01 or not app.session.can_control():break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
		now_us+=100000
		if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
		app.present_session()
		if tick%20==0:await process_frame
		if tick%300==0:print("VALKYRIE home fight ",tick," threats ",threats.size()," vitals ",state.player.vitals," instability ",app.session.flight_owner().instability())
	check(false,"The escaping K'Suukk could not shake the Vossk at the gate");return false

func docked_station() -> int:
	var state: Dictionary=app.session.station_owner().snapshot()
	return int(state.get("contracts",{}).get("station_id",state.get("location",{}).get("station_id",-1)))

## Test shortcut: refit every gun of the fitted gun type with that type's
## strongest gun (damage per second), as a long career would have by now.
func fit_best_guns() -> bool:
	var items: Array=catalogue.tables.items
	var weapons: Dictionary=definitions.weapon_parameters
	var slots: Array=app.session.station_owner().snapshot().loadout.slots
	# Primary guns: weapon category 0 with a firing interval.
	var gun:=func(id):return items[id]!=null and items[id].get("arrays") is Array and items[id].arrays.size()==3 and items[id].arrays[2].size()>int(weapons.item_category_value_index) and int(items[id].arrays[2][int(weapons.item_category_value_index)])==0 and int(items[id].properties.get(int(weapons.interval_property),0))>0
	var fitted: Array=slots.filter(func(slot):return slot!=null and gun.call(int(slot.item_id))).map(func(slot):return int(slot.item_id))
	if fitted.is_empty():return true
	var sort:=int(items[fitted[0]].properties.get(2,-1))
	var rate:=func(id):return float(items[id].properties.get(int(weapons.damage_property),0))/float(items[id].properties.get(int(weapons.interval_property),1))
	# The strongest primary gun whose firing the remake supports.
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var support: Dictionary=app.session.station_owner().equipment_owner().snapshot().get("fitting_support",{})
	app.equipment_action("close")
	var candidates: Array=range(items.size()).filter(func(id):return gun.call(id) and String(support.get(id,"x")).is_empty())
	candidates.sort_custom(func(a,b):return rate.call(a)>rate.call(b))
	check(not candidates.is_empty(),"No supported primary gun")
	if failures:return false
	var best: int=candidates[0]
	if not seed_cargo([[best,fitted.size()]]) or not app.equipment_action("open"):check(false,"Seeding guns failed: "+app.session.error);return false
	for index in range(slots.size()-1,-1,-1):
		if slots[index]!=null and gun.call(int(slots[index].item_id)):
			if not app.equipment_action("unmount",int(slots[index].item_id),index):check(false,app.session.error);return false
	for count in fitted.size():
		if not app.equipment_action("mount",best):check(false,"Gun "+str(best)+" could not be fitted: "+app.session.error);return false
	print("SUPERNOVA guns fitted ",best," x",fitted.size()," ",app.session.station_owner().snapshot().loadout.equipment_ids)
	# Sell the replaced equipment so the hold has room again.
	sell_hold([])
	return app.equipment_action("close")

## With the shop open: sell what the hold carries except story goods,
## fuel and `keep` (a player clearing room).
func sell_hold(keep: Array) -> void:
	for row in app.session.station_owner().snapshot().cargo.entries:
		if int(row.item_id) in [122,146,204,209]+keep or catalogue.tables.items[int(row.item_id)].arrays[2][3]==4:continue
		for unit in int(row.quantity):
			if not app.equipment_action("sell",int(row.item_id)):break

