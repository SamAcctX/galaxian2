extends "res://tests/recovery_application.gd"
## Real contact inspection, paid shop input and acknowledged local hand-in.

func _initialize() -> void:
	if OS.get_environment("GOF2_PURCHASE_RESUME")=="1":call_deferred("run_resumed_job")
	else:super._initialize()

func requested_contract_kind() -> int:return 8

func verify_free_application() -> void:
	app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"))
	app.show();app.present_session();await process_frame;resume_application_focus()
	var original: Dictionary=app.session.station_owner().snapshot()
	var client:=int(OS.get_environment("GOF2_PURCHASE_STATION"))
	var contact_id:=int(OS.get_environment("GOF2_PURCHASE_CONTACT"))
	if original.contracts.mission.get("kind")!=8:
		if int(original.loadout.station_id)!=client and not await visit_delivery_station(client):return
		var key:=InputEventKey.new();key.physical_keycode=KEY_L;key.pressed=true;app._unhandled_input(key)
		check(app.lounge_panel.visible,"Keyboard input did not open the request contact's lounge")
		var before: Dictionary=app.session.station_owner().snapshot()
		app.lounge_panel.select_contact(contact_id)
		var inspected: Dictionary=app.session.station_owner().snapshot()
		var offered: Dictionary=inspected.contracts.offers.get(contact_id,{}).get("offer",{})
		if offered.is_empty():check(false,"The actual contact did not generate its requested job");return
		check(offered.mission.kind==8 and offered.mission.station_id==client and inspected.contracts.mission==before.contracts.mission,"Inspection changed the active job or quoted another station")
		check(app.lounge_panel._body.text.contains(source.strings[int(definitions.station_equipment.item_text_offset)+int(offered.mission.source_parameter)]) and not app.lounge_panel._body.text.contains("#"),"The request omitted its original item name or retained placeholders")
		print("Purchase requested: ",offered.mission)
		await capture_free_application("purchase-request")
		app.lounge_panel.confirm();app.lounge_panel.back()
		check(app.session.station_owner().snapshot()==inspected,"Cancelling the request changed the career")
		app.lounge_panel.confirm();app.lounge_panel.confirm()
		var accepted: Dictionary=app.session.station_owner().snapshot()
		check(accepted.contracts.mission==offered.mission and accepted.contracts.passengers==0 and accepted.cargo==before.cargo,"Acceptance supplied goods or retained replaced passengers")
		check(accepted.contracts.credits==before.contracts.credits and accepted.contracts.completed_side_missions==before.contracts.completed_side_missions,"Acceptance paid the requested job")
		if not app.contract_action("close",-1):check(false,app.session.error);return
		if not retain_recovery_save("accepted"):return
	var accepted: Dictionary=app.session.station_owner().snapshot()
	var mission: Dictionary=accepted.contracts.mission
	var item:=int(mission.source_parameter);var quantity:=int(mission.quantity)
	var incomplete:=OS.get_environment("GOF2_PURCHASE_INCOMPLETE")=="1"
	var target_quantity:=quantity-1 if incomplete else quantity
	var held:=cargo_quantity(accepted,item)
	check(held<quantity and accepted.loadout.station_id==mission.station_id,"The shop pilot requires an unfinished local request")
	if failures:return
	var open_key:=InputEventKey.new();open_key.physical_keycode=KEY_H;open_key.pressed=true;app._unhandled_input(open_key)
	var panel: Control=app.equipment_panel
	panel.select_tab("shop")
	var rows: Array=app.session.station_owner().snapshot().equipment.market_rows.filter(func(row):return row.item_id==item)
	if rows.size()!=1:check(false,"The generated client has no stock of its requested goods");return
	var price:=int(rows[0].unit_price);var remaining:=target_quantity-held
	check(rows[0].stock>=remaining and price*remaining<=accepted.contracts.credits,"The actual stock or earned wallet cannot supply this request")
	if failures:return
	await process_frame
	panel._scroll.ensure_control_visible(panel._rows[item].node)
	await process_frame;await process_frame;resume_application_focus()
	await click_purchase_control(panel._rows[item].node)
	check(panel._selected_id==item and panel._rows[item].actions.buy.visible,"The shop row click did not expose Buy")
	if failures:return
	await capture_free_application("purchase-shop")
	for index in remaining:
		await click_purchase_control(panel._rows[item].actions.buy)
		if not application_step():return
		var purchased: Dictionary=app.session.station_owner().snapshot()
		check(cargo_quantity(purchased,item)==held+index+1 and purchased.contracts.credits==accepted.contracts.credits-price*(index+1),"The shop input did not buy one unit at its retained price")
		if failures:return
		if index<remaining-1:check(purchased.contracts.pending_result.is_empty(),"Insufficient goods completed the request")
	var supplied: Dictionary=app.session.station_owner().snapshot()
	if incomplete:
		check(supplied.contracts.pending_result.is_empty() and supplied.contracts.mission==mission,"A short delivery opened success")
		if not app.equipment_action("close"):check(false,app.session.error);return
		await capture_free_application("purchase-insufficient")
		if not retain_recovery_save("incomplete"):return
		await replace_purchase(supplied,item)
		return
	var pending: Dictionary=supplied.contracts.pending_result
	check(pending.get("completed",false) and app.lounge_panel.visible and not app.equipment_panel.visible,"The last purchase did not open the modal delivery result")
	check(supplied.hangar_open and supplied.contracts.completed_side_missions==accepted.contracts.completed_side_missions and supplied.cargo.used==accepted.cargo.used+remaining,"Result opening paid, closed the shop or removed goods early")
	var blocked: RefCounted=app.session.station_owner()
	check(not blocked.equipment_action("buy",item,definitions,catalogue) and not blocked.close_equipment() and blocked.snapshot()==supplied,"The pending result allowed its inventory to change")
	await capture_free_application("purchase-result")
	if OS.get_environment("GOF2_PURCHASE_MOBILE")=="1":
		root.size=Vector2i(960,540);app.set_mobile_layout(true);TouchInput.set_preference(app,true)
		await process_frame;resume_application_focus();app.present_session()
		await capture_free_application("purchase-result-mobile")
	var serial:=int(pending.serial)
	await acknowledge_recovery_result()
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.mission.is_empty() and paid.contracts.credits==supplied.contracts.credits+int(mission.reward)+int(mission.bonus) and paid.contracts.completed_side_missions==accepted.contracts.completed_side_missions+1,"Acknowledgement lost its quoted payment or completion")
	check(cargo_quantity(paid,item)==0 and paid.contracts.delivery_statistics==accepted.contracts.delivery_statistics,"Hand-in retained goods or counted a courier delivery")
	check(paid.campaign_cursor==original.campaign_cursor and paid.mission==original.mission,"Purchase advanced the campaign")
	check(paid.hangar_open and app.equipment_panel.visible and paid.equipment.market_rows.filter(func(row):return row.item_id==item)[0].owned==0,"The shop did not resume with its delivered quantity removed")
	check(not app.contract_action("result_close",serial) and app.session.station_owner().snapshot()==paid,"The Purchase reward paid twice")
	if not app.equipment_action("close"):check(false,app.session.error);return
	await capture_free_application("purchase-paid")
	if not retain_recovery_save("paid"):return
	print("Purchase earned: ",{"item":item,"quantity":quantity,"price":price,"reward":mission.reward,"credits":paid.contracts.credits,"jobs":paid.contracts.completed_side_missions,"cursor":paid.campaign_cursor})

func replace_purchase(supplied: Dictionary,item: int) -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_L;key.pressed=true;app._unhandled_input(key)
	var state: Dictionary=app.session.station_owner().snapshot();var replacement:=-1
	for id in state.contracts.offers:
		if state.contracts.offers[id].consumed:continue
		var terms: Dictionary=app.session.station_owner().contract_preview(id,definitions)
		if terms.get("can_accept",false):replacement=int(id);break
	if replacement<0:check(false,"The actual lounge has no supported replacement offer");return
	app.lounge_panel.select_contact(replacement);app.lounge_panel.confirm();app.lounge_panel.confirm()
	var replaced: Dictionary=app.session.station_owner().snapshot()
	check(replaced.contracts.mission==state.contracts.offers[replacement].offer.mission and replaced.contracts.completed_side_missions==supplied.contracts.completed_side_missions and replaced.contracts.credits==supplied.contracts.credits,"Replacing the incomplete request granted a reward")
	check(cargo_quantity(replaced,item)==cargo_quantity(supplied,item),"Replacing the request deleted purchased goods")
	if not app.contract_action("close",-1):check(false,app.session.error);return
	await capture_free_application("purchase-replaced");retain_recovery_save("replaced")

func cargo_quantity(state: Dictionary,item: int) -> int:
	var total:=0
	for row in state.cargo.entries:
		if row.item_id==item:total+=int(row.quantity)
	return total

func click_purchase_control(control: Control) -> void:
	resume_application_focus()
	var point: Vector2=root.get_final_transform()*control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion);Input.flush_buffered_events()
	for down in [true,false]:
		var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
		Input.parse_input_event(click);Input.flush_buffered_events()
	await process_frame;resume_application_focus()
