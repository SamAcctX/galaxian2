extends "res://tests/recovery_application.gd"
## Generated search, paid shop input, physical return and retained settlement.

func _initialize() -> void:
	if OS.get_environment("GOF2_STOLEN_RESUME")=="1":call_deferred("run_resumed_job")
	else:super._initialize()

func requested_contract_kind() -> int:return 14
func contract_search_stations() -> Array:return [-1,38]
func accepts_requested_contract(mission: Dictionary) -> bool:return mission.kind==14
func uses_pilot_cadence() -> bool:return app.session is FlightSession

func application_step() -> bool:
	if not app.session is StationSession:return super.application_step()
	resume_application_focus();now_us+=pirate_delta_us()
	if not app.session.step(now_us):check(false,app.session.error);return false
	app.present_session();return true

func verify_delivery_route(original: Dictionary,_before: Dictionary,offer: Dictionary,accepted: Dictionary,kind: int) -> void:
	check(kind==14,"The search pilot selected another job")
	var mission: Dictionary=offer.mission;var client:=int(accepted.contracts.accepted_contact.station_id)
	var incomplete:=OS.get_environment("GOF2_STOLEN_INCOMPLETE")=="1"
	print("Stolen Goods accepted: ",{"client":client,"mission":mission,"credits":accepted.contracts.credits})
	if not retain_recovery_save("accepted") or not await check_search_map(client,"stolen-search-map"):return
	var price:=0
	if file_quantity(accepted)==0:
		if not await visit_delivery_station(int(mission.station_id)) or not application_step():return
		var arrived: Dictionary=app.session.station_owner().snapshot()
		check(arrived.contracts.pending_result.is_empty() and arrived.contracts.mission==mission,"The destination paid before the file was returned")
		var key:=InputEventKey.new();key.physical_keycode=KEY_H;key.pressed=true;app._unhandled_input(key)
		var rows: Array=app.session.station_owner().snapshot().equipment.market_rows.filter(func(row):return row.item_id==115)
		if rows.size()!=1 or rows[0].stock!=1:check(false,"The actual destination shop lacks its single file");return
		price=int(rows[0].unit_price)
		var panel: Control=app.equipment_panel;panel.select_tab("shop")
		await process_frame;panel._scroll.ensure_control_visible(panel._rows[115].node)
		await process_frame;await process_frame;resume_application_focus()
		await click_shop_control(panel._rows[115].node)
		check(panel._selected_id==115 and panel._rows[115].actions.buy.visible,"The file row did not expose Buy")
		await capture_free_application("stolen-file-shop")
		if not incomplete:
			await click_shop_control(panel._rows[115].actions.buy)
			if not application_step():return
			var bought: Dictionary=app.session.station_owner().snapshot()
			check(file_quantity(bought)==1 and bought.contracts.credits==accepted.contracts.credits-price and bought.contracts.pending_result.is_empty(),"The file purchase changed its price, quantity or completed too early")
			check(bought.equipment.market_rows.filter(func(row):return row.item_id==115)[0].stock==0,"The purchased file remained for sale")
		if not app.equipment_action("close"):check(false,app.session.error);return
		if not retain_recovery_save("empty-return" if incomplete else "bought"):return
	var supplied: Dictionary=app.session.station_owner().snapshot()
	if not await check_search_map(client,"stolen-return-map"):return
	if int(supplied.loadout.station_id)!=client and not await visit_delivery_station(client):return
	if not application_step():return
	var delivered: Dictionary=app.session.station_owner().snapshot()
	if incomplete:
		check(delivered.contracts.pending_result.is_empty() and delivered.contracts.mission==mission and delivered.contracts.credits==accepted.contracts.credits,"Returning empty paid or discarded the search")
		await capture_free_application("stolen-empty-return")
		retain_recovery_save("incomplete");return
	var pending: Dictionary=delivered.contracts.pending_result
	check(pending.get("completed",false) and app.lounge_panel.visible and delivered.contracts.credits==supplied.contracts.credits and file_quantity(delivered)==file_quantity(supplied),"Returning the file lost the result or settled before Close")
	if failures:return
	await capture_free_application("stolen-result")
	var serial:=int(pending.serial)
	await acknowledge_recovery_result()
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.mission.is_empty() and paid.contracts.credits==supplied.contracts.credits+mission.reward+mission.bonus and paid.contracts.completed_side_missions==accepted.contracts.completed_side_missions+1,"The file return paid the wrong amount or completed twice")
	check(file_quantity(paid)==0 and paid.contracts.delivery_statistics==accepted.contracts.delivery_statistics,"The return kept its file or counted a courier delivery")
	check(paid.campaign_cursor==original.campaign_cursor and paid.mission==original.mission and paid.cargo.entries==supplied.cargo.entries.filter(func(row):return row.item_id!=115),"Returning the file changed the campaign or unrelated cargo")
	check(not app.contract_action("result_close",serial) and app.session.station_owner().snapshot()==paid,"Repeated Close paid the file twice")
	await capture_free_application("stolen-paid-station")
	if not retain_recovery_save("paid"):return
	print("Stolen Goods saved: ",{"price":price,"reward":mission.reward,"credits":paid.contracts.credits,"jobs":paid.contracts.completed_side_missions,"cursor":paid.campaign_cursor,"deltas":_pilot_deltas})

func file_quantity(state: Dictionary) -> int:
	var total:=0
	for row in state.cargo.entries:
		if row.item_id==115:total+=int(row.quantity)
	return total

func check_search_map(client: int,label: String) -> bool:
	if not app.open_map(now_us):check(false,app.status.text);return false
	if app.map_panel.snapshot().route_mode=="galaxy":app.map_panel.show_system(int(app.session.snapshot().location.system_id))
	var targets: Array=app.map_panel.snapshot().rows.filter(func(row):return row.mission_target).map(func(row):return row.station_id)
	check(targets==[client],"The map disclosed the shop instead of the return client")
	await capture_free_application(label)
	if not app.close_map(now_us):check(false,app.status.text);return false
	return failures==0

func click_shop_control(control: Control) -> void:
	resume_application_focus()
	var point: Vector2=root.get_final_transform()*control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion);Input.flush_buffered_events()
	for down in [true,false]:
		var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
		Input.parse_input_event(click);Input.flush_buffered_events()
	await process_frame;resume_application_focus()

func acquire_application_planet(destination: int) -> bool:
	if not app.open_map():check(false,app.status.text);return false
	if app.map_panel.snapshot().route_mode=="galaxy":app.map_panel.show_system(int(app.session.snapshot().location.system_id))
	app.map_panel.select_station(destination);app.map_panel.request_confirmation()
	if not app.confirm_map_planet(destination,now_us):check(false,app.map_panel.error);return false
	app.session.rebase_time(now_us)
	var started:=now_us;var next_yield:=now_us+2000000
	while now_us-started<200000000 and app.session.status!="local_arrival_transition_required":
		if not application_step():return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
	check(app.session.status=="local_arrival_transition_required","The input course did not reach its actual planet")
	return failures==0
