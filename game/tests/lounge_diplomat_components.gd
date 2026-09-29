extends "res://tests/lounge_coordinates_application.gd"
## Synthetic service boundaries are NOT an earned diplomat purchase.
## The unchanged earned application remains separate and flies after the fixture.
const Standing=preload("res://src/simulation/faction_reputation.gd")
const CacheOwner=preload("res://src/simulation/lounge_cache.gd")
const NativeRandom=preload("res://src/simulation/seeded_random.gd")
const ArchiveOwner=preload("res://src/simulation/station_archive.gd")
const SaveOwner=preload("res://src/simulation/station_save_file.gd")
var component_session: Node3D
var component_panel: Control
var component_file: String
var component_save_count:=0

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	if directory.is_empty():check(false,"Diplomat checks require isolated output");return
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var retained: RefCounted=app.session.station_owner()
	var original: Dictionary=retained.snapshot()
	check_original_rules()
	if failures:return
	# Opening only initializes the normal source-art resources. No contact is forged
	# in this application, and no earned input or saved profile is edited.
	if not app.contract_action("open",-1):check(false,app.session.error);return
	for step in 40:
		if not application_step():return
	await capture_free_application("earned-neutral-lounge")
	var art: RefCounted=app.lounge_panel._visuals
	if not app.contract_action("close",-1):check(false,app.session.error);return
	check(not app.contract_action("buy_diplomat",-1),"An invalid earned contact accepted diplomat payment")
	var live_before: Dictionary=app.session.station_owner().snapshot()
	var fixture: RefCounted=make_component_fixture(retained)
	if fixture==null:return
	var initial: Dictionary=fixture.snapshot()
	var contacts: Array=initial.contracts.population.contacts.filter(func(row):return row.role==7 and row.faction==0)
	var id:=int(contacts[0].contact_id)
	var quote: Dictionary=fixture.diplomat_preview(id,definitions)
	check(quote.total_price==12800 and quote.can_accept and quote.reputation_after.axes==[-35,3],"The component quote changed its faction, fee or repair")
	var poor: RefCounted=fixture.fork();poor._contracts._state.credits=12799
	var poor_before: Dictionary=poor.snapshot()
	check(not poor.diplomat_preview(id,definitions).can_accept and not poor.purchase_lounge_diplomat(id,definitions) and poor.snapshot()==poor_before,"An unfunded component changed standing or wallet")
	var archive:=ArchiveOwner.new()
	var document: Dictionary=archive.capture(fixture,definitions)
	check(not document.is_empty(),"Synthetic component capture: "+archive.error)
	if failures:return
	component_file=directory.path_join("component-only/synthetic-"+str(OS.get_process_id())+".gof2save")
	component_session=load("res://src/presentation/station_session.gd").new();root.add_child(component_session)
	component_panel=load("res://src/presentation/lounge_panel.gd").new();root.add_child(component_panel)
	component_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not component_panel.configure(source,definitions,art,catalogue) or not component_session.configure_saved(source,definitions,art,document,now_us):
		check(false,"Synthetic presentation: "+component_panel.error+component_session.error);cleanup_component();return
	app.hide();app.session.hide()
	if not component_session.activate():check(false,component_session.error);cleanup_component();return
	check(not component_session.contract_action("buy_diplomat",id,component_panel),"A closed component lounge accepted payment")
	check(component_session.contract_action("open",-1,component_panel),component_session.error)
	for step in 40:
		now_us+=100000;check(component_session.step(now_us),component_session.error)
	component_panel.select_contact(id)
	component_panel.action_requested.connect(component_action)
	var marker:=Label.new();marker.text="SYNTHETIC COMPONENT CHECK — NOT AN EARNED PURCHASE";marker.position=Vector2(12,12);component_panel.add_child(marker)
	var before: Dictionary=component_session.station_owner().snapshot()
	check(component_panel.snapshot().body==source.strings[870].replace("#C",component_panel.money(12800)),"The diplomat's original introduction was not resolved")
	await capture_free_application("component-only-diplomat-offer")
	check(component_session.set_pause("user",true,now_us),component_session.error)
	check(not component_session.contract_action("buy_diplomat",id,component_panel),"Paused component input accepted payment")
	check(component_session.set_pause("user",false,now_us),component_session.error)
	check(not component_session.contract_action("buy_diplomat",id,component_panel,func(_candidate):return false),"A rejected save accepted the component purchase")
	check(component_session.station_owner().snapshot()==before and component_panel.snapshot().accept_visible,"Failed checkpoint changed the component wallet, standing, or consumption")
	component_key(KEY_ENTER);component_key(KEY_BACKSPACE)
	check(component_session.station_owner().snapshot()==before and not component_panel.snapshot().confirming,"Keyboard cancellation changed the component")
	for button in [JOY_BUTTON_A,JOY_BUTTON_B]:
		var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true
		check(component_panel.handle_event(event),"Controller did not handle diplomat consent")
	check(component_session.station_owner().snapshot()==before and not component_panel.snapshot().confirming,"Controller cancellation changed the component")
	await click_coordinate_button(component_panel._yes)
	check(component_panel.snapshot().confirming and component_session.station_owner().snapshot()==before,"Mouse confirmation charged before consent")
	check(component_panel.snapshot().body==source.strings[874].replace("#C",component_panel.money(12800)),"The original diplomat confirmation was not shown")
	await capture_free_application("component-only-diplomat-confirmation")
	if failures:cleanup_component();return
	await click_coordinate_button(component_panel._yes)
	var bought: Dictionary=component_session.station_owner().snapshot()
	check(component_save_count==1 and bought.contracts.credits==7200 and bought.contracts.reputation.axes==[-35,3] and bought.progress.reputation==bought.contracts.reputation,"Payment and faction repair were not saved atomically")
	check(bought.cargo==before.cargo and bought.loadout==before.loadout and bought.contracts.mission==before.contracts.mission and bought.contracts.passengers==before.contracts.passengers and bought.contracts.blueprints==before.contracts.blueprints,"Diplomacy changed goods, ship, recipe, or carried job")
	check(fixture.snapshot()==initial and not component_panel.snapshot().accept_visible,"Purchase mutated its parent or retained the buy action")
	var saver:=SaveOwner.new();var loaded: Dictionary=saver.load_document(component_file,definitions,catalogue,source)
	var restored: RefCounted=archive.restore(definitions,catalogue,source,loaded)
	check(restored!=null and restored.snapshot()==bought,"Saved component did not restore exactly: "+saver.error+archive.error)
	await capture_free_application("component-only-diplomat-paid")
	if restored!=null:
		var repeat: RefCounted=restored.fork()
		repeat._contracts._state.reputation.axes[0]=-80;repeat._contracts._state.progress.reputation.axes[0]=-80;repeat._state.progress.reputation.axes[0]=-80
		var returned_hostility: Dictionary=repeat.snapshot()
		check(not repeat.purchase_lounge_diplomat(id,definitions) and repeat.snapshot()==returned_hostility,"Restored consumption allowed another payment when synthetic hostility returned")
		var malformed: Dictionary=loaded.duplicate(true)
		malformed.locations.locations[0].used_diplomats[id]=842
		check(archive.restore(definitions,catalogue,source,malformed)==null,"Invalid saved diplomat response was admitted")
		malformed=loaded.duplicate(true);malformed.locations.locations[0].used_diplomats[-1]=843
		check(archive.restore(definitions,catalogue,source,malformed)==null,"An absent saved diplomat was admitted")
	print("Synthetic diplomat component only: ",{"faction":0,"credits_before":20000,"price":12800,"credits_after":bought.contracts.credits,"reputation":bought.contracts.reputation,"file":component_file})
	cleanup_component()
	check(app.session.station_owner().snapshot()==live_before and retained.snapshot()==original,"The isolated component altered the real earned career")
	check(FileAccess.get_sha256(input_path)==input_hash,"The immutable earned input was modified")
	if failures:return
	# Real earned journey is regression coverage only: no diplomat was purchased.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	await capture_free_application("earned-neutral-departure")
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.contracts.credits==original.contracts.credits and landed.contracts.reputation==original.contracts.reputation and landed.cargo==original.cargo and landed.contracts.blueprints==original.contracts.blueprints and landed.contracts.mission==original.contracts.mission,"The neutral earned journey changed wallet, standing, cargo, recipe or job")
	if not retain_recovery_save("neutral-returned"):return
	await capture_free_application("earned-neutral-returned")
	check(FileAccess.get_sha256(input_path)==input_hash,"The earned input changed after the real journey")
	print("Earned neutral regression only: ",{"credits":landed.contracts.credits,"reputation":landed.contracts.reputation,"input_sha256":input_hash})

func check_original_rules() -> void:
	for faction in 4:
		var axis:=0 if faction<2 else 1;var sign: int=-1 if faction in [0,2] else 1
		var standing:={"axes":[11,3],"override":-1};standing.axes[axis]=70*sign
		check(not Standing.diplomat_quote(standing,faction).eligible,"Exactly seventy standing was treated as hostile")
		standing.axes[axis]=71*sign
		var original: Dictionary=standing.duplicate(true);var quote: Dictionary=Standing.diplomat_quote(standing,faction)
		check(quote.eligible and quote.total_price==11360 and quote.reputation_after.axes[axis]==35*sign and quote.reputation_after.axes[1-axis]==standing.axes[1-axis] and standing==original,"Minimum hostile service changed its price, axis, or retained input")
		standing.axes[axis]=100*sign
		check(Standing.diplomat_quote(standing,faction).total_price==16000,"Maximum hostility changed the original fee")
	check(Standing.diplomat_quote({"axes":[-101,0],"override":-1},0).is_empty(),"Invalid standing received a quote")
	check(Standing.diplomat_quote({"axes":[-100,0],"override":0},0).is_empty(),"Unsupported override received a quote")
	check(Standing.diplomat_quote({"axes":[-100,0],"override":-1},4).is_empty(),"An unsupported faction received a quote")

func make_component_fixture(parent: RefCounted) -> RefCounted:
	var before: Dictionary=parent.snapshot();var standing:={"axes":[-80,3],"override":-1}
	var settings: Dictionary={}
	for location in before.contracts.lounges.locations:
		if location.station_id==before.loadout.station_id:settings=location.stock.context.duplicate(true)
	for key in ["station_id","campaign_cursor","all_base_medals_gold"]:settings.erase(key)
	var context:={"station_id":before.loadout.station_id,"campaign_cursor":before.campaign_cursor,"rank":before.contracts.rank,"reputation":standing}
	for seed in 32:
		var random:=NativeRandom.new();random.seed_from(seed)
		var cache:=CacheOwner.new()
		if not cache.configure(definitions):check(false,cache.error);return null
		cache._state.system_availability=before.contracts.lounges.system_availability.duplicate()
		if not cache.select_location(definitions,catalogue,source,context,settings,random.snapshot(),1700000000+seed,parent.mission_station_context_owner()):check(false,cache.error);return null
		var entry: Dictionary=cache.location(before.loadout.station_id)
		if not entry.population.contacts.any(func(row):return row.role==7 and row.faction==0):continue
		var fixture: RefCounted=parent.fork()
		fixture._contracts._lounges=cache;fixture._contracts._state.population=entry.population.duplicate(true);fixture._contracts._state.offers=entry.offers.duplicate(true)
		fixture._contracts._state.credits=20000;fixture._contracts._state.reputation=standing.duplicate(true)
		fixture._contracts._state.progress.reputation=standing.duplicate(true);fixture._state.progress.reputation=standing.duplicate(true)
		print("Synthetic component generation seed: ",seed,"; never accepted as earned career progress")
		return fixture
	check(false,"The bounded synthetic generation produced no diplomat");return null

func component_key(code: int) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	check(component_panel.handle_event(event),"The component did not handle its keyboard event")

func component_action(action: String,id: int) -> void:
	check(component_session.contract_action(action,id,component_panel,save_component),component_session.error)

func save_component(candidate: RefCounted) -> bool:
	var file:=SaveOwner.new()
	var saved:=file.save(component_file,candidate,definitions,catalogue,source)
	if saved:component_save_count+=1
	else:print("Component save rejection: ",file.error)
	return saved

func cleanup_component() -> void:
	if is_instance_valid(component_panel):component_panel.free()
	if is_instance_valid(component_session):component_session.free()
	app.show();app.session.show();app.session.camera.make_current();app.session.rebase_time(now_us)
