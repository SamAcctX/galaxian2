extends SceneTree
## Replay a copied station; funded branches below are explicit transaction fixtures.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Session=preload("res://src/presentation/station_session.gd")
const Lounge=preload("res://src/presentation/lounge_panel.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size() in [3,4]:await verify(args)
	else:check(false,"Supply content, bindings, visuals and GOF2_MERCHANT_SAVE")
	print("Lounge merchants: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library) or not visuals.open(args[2],library.manifest):check(false,library.error+bindings.error+cat.error+visuals.error);return
	var archive:=Archive.new();var file:=Save.new();var document:=file.read_document(OS.get_environment("GOF2_MERCHANT_SAVE"))
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,file.error+archive.error);return
	var original: Dictionary=station.snapshot();var merchants:=[]
	for contact in original.contracts.population.contacts:
		if contact.has("trade"):merchants.append(contact.contact_id)
	check(not merchants.is_empty(),"Fixture has no retained goods merchant")
	if merchants.is_empty():return
	var panel:=Lounge.new();root.add_child(panel);root.size=Vector2i(1280,720);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check(panel.configure(library,bindings,visuals,cat),panel.error)
	var session:=Session.new();root.add_child(session)
	if not session.configure_saved(library,bindings,visuals,document,0) or not session.activate():check(false,session.error);session.free();panel.free();return
	panel.action_requested.connect(func(action,id):check(session.contract_action(action,id,panel),session.error))
	check(session.contract_action("open",-1,panel),session.error)
	var preview:=original.duplicate(true);preview.lounge_open=true;preview.contract_previews={}
	for id in merchants:
		preview.contract_previews[id]=station.merchant_preview(id,bindings)
		check(not preview.contract_previews[id].is_empty(),station.error)
	if failures:session.free();panel.free();return
	check(panel.present(preview),panel.error);panel.select_contact(merchants[0])
	check(not panel.snapshot().body.contains("not yet available"),"Merchant still shows a placeholder")
	check(panel.snapshot().body.contains(str(preview.contract_previews[merchants[0]].quantity)),"Merchant omitted the retained bundle")
	for step in 20:check(session.step((step+1)*100000),session.error)
	await process_frame;await process_frame
	var captures:=args[3] if args.size()==4 else OS.get_environment("GOF2_CAPTURE_DIR")
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(captures.path_join("merchant-existing-save.png"))
	var booze_purchases:=0
	for id in merchants:
		var quote: Dictionary=station.merchant_preview(id,bindings)
		check(not quote.is_empty() and quote.kind=="merchant",station.error)
		var branch: RefCounted=station.fork()
		# Deliberately funded/empty-wallet unit fixtures; never write the input save.
		branch._contracts._state.credits=0
		var unfunded: Dictionary=branch.snapshot()
		check(not branch.merchant_preview(id,bindings).can_accept,"An empty wallet can buy goods")
		check(not branch.purchase_lounge_goods(id,bindings) and branch.snapshot()==unfunded,"Rejected purchase altered inventory or contact")
		branch._contracts._state.credits=int(quote.total_price)
		var before: Dictionary=branch.snapshot()
		session._world=branch
		check(session.contract_action("open",-1,panel),session.error)
		panel.select_contact(id);panel.confirm()
		check(panel.snapshot().confirming,"Merchant skipped purchase confirmation")
		panel.confirm();branch=session.station_owner()
		check(not panel.snapshot().accept_visible,"Purchased contact retained its Buy button")
		var bought: Dictionary=branch.snapshot()
		check(bought.contracts.credits==0 and bought.cargo.used==before.cargo.used+quote.quantity,"Bundle changed the quoted total or cargo quantity")
		var expected_progress: Dictionary=before.progress.duplicate(true);var expected_contract_progress: Dictionary=before.contracts.progress.duplicate(true)
		if int(quote.item_id)>=132 and int(quote.item_id)<=153:
			booze_purchases+=1;var bit:=1 << (int(quote.item_id)-132);expected_progress.booze_types_mask=int(expected_progress.get("booze_types_mask",0)) | bit;expected_contract_progress.booze_types_mask=int(expected_contract_progress.get("booze_types_mask",0)) | bit
		check(bought.loadout==before.loadout and bought.progress==expected_progress and bought.contracts.progress==expected_contract_progress and bought.mission==before.mission,"Purchase changed unrelated fitting/campaign state or lost Barkeeper history: contact %d item %d"%[id,int(quote.item_id)])
		check(not branch.purchase_lounge_goods(id,bindings) and branch.snapshot()==bought,"Merchant bundle could be purchased twice")
		check(station.snapshot()==original,"Forked purchase corrupted the original frame")
		var record:=archive.capture(branch,bindings)
		var restored: RefCounted=archive.restore(bindings,cat,library,record)
		check(restored!=null,archive.error)
		if restored!=null:
			check(restored.snapshot()==bought,"Save/Resume lost goods, wallet or contact consumption")
			check(restored.merchant_preview(id,bindings).consumed and not restored.purchase_lounge_goods(id,bindings),"Resume resurrected the purchased goods")
		if not captures.is_empty():
			var save_path:=captures.path_join("purchased-"+str(id)+".gof2save")
			check(file.save(save_path,branch,bindings,cat,library),file.error)
			var persisted:=file.load_document(save_path,bindings,cat,library)
			check(not persisted.is_empty(),file.error)
			check(archive.restore(bindings,cat,library,persisted).snapshot()==bought,"Written purchase changed during reload")
		var damaged:=record.duplicate(true)
		for entry in damaged.locations.locations:
			if entry.station_id==before.loadout.station_id:entry.purchased_goods.append(id)
		check(archive.restore(bindings,cat,library,damaged)==null,"Save accepted duplicate merchant purchase records")
	check(booze_purchases>0,"Fixture has no source booze merchant to cover the Barkeeper purchase writer")
	session.free();panel.free()
