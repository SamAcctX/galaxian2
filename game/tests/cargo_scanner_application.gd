extends "res://tests/recovery_resume_application.gd"
## Earned shopping, input acquisition, read-only cargo inspection and saved fitting.

func resumed_contract_valid(state: Dictionary) -> bool:return state.contracts.mission.is_empty()

func visit_delivery_station(destination: int) -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return await release_application_flight() and await travel_application(destination) and await dock_application()

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_CARGO_SCAN_RESUMED")=="1"
	var item:=-1;var price:=0
	if not resumed:
		if original.loadout.station_id!=39 and not await visit_delivery_station(39):return
		if not app.equipment_action("open"):check(false,app.session.error);return
		var before: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=before.equipment.market_rows.filter(func(row):return row.stock>0 and row.unit_price<=before.contracts.credits and catalogue.tables.items[row.item_id].properties.get(2)==17 and catalogue.tables.items[row.item_id].properties.get(31)==1)
		offers.sort_custom(func(a,b):return a.unit_price<b.unit_price)
		if offers.is_empty():check(false,"The earned shop has no affordable cargo scanner");return
		item=int(offers[0].item_id);price=int(offers[0].unit_price)
		if not app.equipment_action("buy",item):check(false,app.session.error);return
		var installed: Array=before.loadout.equipment_ids.filter(func(id):return catalogue.tables.items[id].properties.get(2)==17)
		var removed:=int(installed[0]) if not installed.is_empty() else 86
		if not app.equipment_action("unmount",removed) or not app.equipment_action("mount",item):check(false,app.session.error);return
		check(app.session.station_owner().snapshot().contracts.credits==before.contracts.credits-price,"The cargo scanner purchase changed its quoted price")
		await capture_free_application("cargo-scanner-purchased-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	else:
		var installed: Array=original.loadout.equipment_ids.filter(func(id):return catalogue.tables.items[id].properties.get(2)==17 and catalogue.tables.items[id].properties.get(31)==1)
		if installed.size()!=1:check(false,"Fresh Resume lost the purchased cargo scanner");return
		item=int(installed[0])
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(item),"The cargo scanner is absent from the actual ship")
	check(fitted.contracts.completed_side_missions==original.contracts.completed_side_missions and fitted.mission==original.mission,"Buying the scanner advanced a mission")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var flight: Dictionary=app.session.snapshot();var candidates:=[];var empty_ships:=[]
	for actor in flight.encounter.combat.actors:
		if not actor.active or actor.actor_mode in [3,4]:continue
		var owner: RefCounted=app.session._world._encounter.npc_destruction_owner(int(actor.actor_id))
		var cargo: Array=[] if owner==null else owner.snapshot().get("cargo",{}).get("entries",[])
		print("Cargo scan candidate: ",{"actor":actor.actor_id,"kind":actor.actor_kind,"cargo":cargo,"hostile":actor.hostile})
		var candidate:={"actor_id":actor.actor_id,"cargo":cargo,"distance":actor.pose.origin.distance_squared_to(flight.player_pose.origin)}
		if cargo.is_empty():empty_ships.append(candidate)
		else:candidates.append(candidate)
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	if candidates.is_empty():check(false,"The generated flight has no loaded ship to inspect");return
	if not await acquire_cargo(candidates[0]):return
	if resumed:
		if empty_ships.is_empty():check(false,"The resumed generated flight has no empty ship to inspect");return
		if not await acquire_cargo(empty_ships[0]):return
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout.equipment_ids.has(item) and landed.contracts.credits==fitted.contracts.credits and landed.cargo==fitted.cargo,"Inspection took goods or lost the purchased fitting on docking")
	check(landed.contracts.completed_side_missions==original.contracts.completed_side_missions and landed.campaign_cursor==original.campaign_cursor,"Scanning changed job completion or the story")
	if not retain_recovery_save("fitted"):return
	await capture_free_application("cargo-scanner-saved-station")
	print("Cargo scanner saved: ",{"item":item,"price":price,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor})

func acquire_cargo(candidate: Dictionary) -> bool:
	var target_id:=int(candidate.actor_id);var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var expected: String=source.strings[531]
	var label:="cargo-empty" if candidate.cargo.is_empty() else "cargo-scanned"
	if not candidate.cargo.is_empty():
		var row: Dictionary=candidate.cargo[0]
		expected="%dt %s"%[row.quantity,source.strings[int(definitions.station_equipment.item_text_offset)+int(row.item_id)]]
	while now_us-started<180000000:
		var state: Dictionary=app.session.snapshot();var target: Dictionary=state.encounter.combat.actors[target_id]
		var distance: float=state.player_pose.origin.distance_to(target.position)
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,target.position),"throttle":1.0 if distance>24000.0 else 0.0,"fire":false,"strafe":0.0}
		var markers: Array=state.npc_scanner.markers.filter(func(marker):return marker.actor_id==target_id and marker.in_view)
		if not markers.is_empty():
			var offset: Vector2=Vector2(markers[0].pixels-state.npc_scanner.aim_pixels)
			input.commands=Vector2(clampf(offset.y/300.0,-1.0,1.0),clampf(-offset.x/300.0,-1.0,1.0))
		if not pirate_step(input):return false
		var acquired: Dictionary=app.session.snapshot();var notice: Dictionary=acquired.flight_notices
		if now_us>=next_log:
			print("Cargo acquisition: ",{"elapsed":(now_us-started)/1000000.0,"distance":distance,"target":target_id,"selected":acquired.npc_scanner.selected_actor_id,"notice":notice.current})
			next_log=now_us+10000000
		if notice.current.get("text")==expected and notice.alpha>=200:
			var cargo: Array=app.session._world._encounter.npc_destruction_owner(target_id).snapshot().cargo.entries
			check(cargo==candidate.cargo and notice.current.rgb==[255,255,255],"Scanning consumed the target's goods or displayed pickup coloring")
			check(acquired.npc_scanner.selected_actor_id==target_id and app.session.flight_audio!=null,"Inspection lost the selected ship or acquisition audio")
			check(app.session.scene.notice_panel.snapshot().current.text==expected,"The cargo readout never reached the visible notice panel")
			await capture_free_application(label+"-desktop")
			app.session.scene.notice_panel.set_mobile_layout(true)
			await capture_free_application(label+"-touch")
			app.session.scene.notice_panel.set_mobile_layout(false)
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	await capture_free_application("cargo-scan-stopped")
	check(false,"Input acquisition did not show the generated ship's cargo");return false
