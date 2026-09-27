extends SceneTree
## Detached original offer presentation. No accepted job or career is fabricated.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Offer=preload("res://src/simulation/contract_offer.gd")
const Lounge=preload("res://src/presentation/lounge_panel.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3 and not OS.get_environment("GOF2_CAPTURE_DIR").is_empty():args.append(OS.get_environment("GOF2_CAPTURE_DIR"))
	if args.size() in [3,4]:await verify(args)
	else:check(false,"Supply content, bindings, visuals and optional captures")
	print("Lounge reading: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library) or not visuals.open(args[2],library.manifest):
		check(false,library.error+bindings.error+cat.error+visuals.error);return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(568,320)
	var panel:=Lounge.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.configure(library,bindings,visuals,cat):check(false,panel.error);panel.free();return
	panel.set_mobile_layout(true)
	var state:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"lounge_open":true,
		"contracts":{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":79,
			"offers":{},"mission":{},"pending_result":{},"credits":5000,"accepted_contact":{},"completed_side_missions":0},"contract_previews":{}}
	for id in 5:
		var offer:=Offer.new()
		var context:={"campaign_cursor":13,"station_id":79,"rank":0,"reputation":{"axes":[30,0],"override":-1},"client_faction":3}
		var choices:={"kind_index":id,"difficulty_index":0,"destination_station_id":79 if id==4 else 76,"cargo_description_index":0}
		if not offer.configure(bindings,cat,context,choices):check(false,offer.error);panel.free();return
		state.contracts.offers[id]={"offer":offer.snapshot(),"consumed":false}
		state.contract_previews[id]={"can_accept":true,"replacement_required":false}
	# A generated original portrait supplies the real column width. Offer terms
	# remain detached fixtures, without acceptance or retained lounge history.
	var contacts: RefCounted=load("res://src/simulation/lounge_contacts.gd").new()
	var random: RefCounted=load("res://src/simulation/seeded_random.gd").new();random.seed_from(0)
	var history: Array=[];history.resize(15);history.fill(false)
	var contact_context:={"campaign_cursor":13,"station_id":79,"rank":0,"reputation":{"axes":[30,0],"override":-1}}
	if not contacts.prepare(bindings,cat,library,contact_context,random.snapshot(),history):check(false,contacts.error);panel.free();return
	var composer: RefCounted=load("res://src/presentation/portrait_compositor.gd").new()
	var client: Dictionary=contacts.snapshot().contacts[0]
	var portrait: Dictionary=composer.compose_definition(library,bindings,visuals,0,"large",client.portrait)
	if portrait.is_empty():check(false,composer.error);panel.free();return
	var texture:=ImageTexture.create_from_image(portrait.image)
	panel._portraits={0:texture,1:texture,2:texture,3:texture,4:texture};panel._contact_ids=[0,1,2,3,4]
	check(panel.present(state),panel.error)
	var left:=InputEventKey.new();left.physical_keycode=KEY_LEFT;left.pressed=true
	check(panel.handle_event(left) and panel.snapshot().selected==4,"First Left skipped the final lounge contact")
	var longest:=0;var length:=0
	for id in 5:
		panel.select_contact(id)
		if panel.snapshot().body.length()>length:longest=id;length=panel.snapshot().body.length()
	panel.select_contact(longest)
	await process_frame;await process_frame
	var bar: VScrollBar=panel._body.get_v_scroll_bar()
	print("Original offer layout: ",{"offer":longest,"characters":length,"panel":panel.size,"body":panel._body.size,"content_height":panel._body.get_content_height(),"scroll_max":bar.max_value,"scroll_page":bar.page})
	check(bar.max_value>bar.page,"The original landscape offer does not exercise scrolling")
	bar.value=bar.max_value-bar.page
	await process_frame
	var scroll:=bar.value
	check(scroll>0,"The contract briefing could not be scrolled")
	for frame in 4:
		check(panel.present(state),panel.error)
		await process_frame
	check(is_equal_approx(bar.value,scroll),"Repeated lounge frames reset the contract reading position")
	panel.set_active(false);panel.set_active(true)
	await process_frame
	check(is_equal_approx(bar.value,scroll),"Pausing the lounge reset the contract reading position")
	if args.size()==4 and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(args[3]);await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(args[3].path_join("lounge-reading-landscape.png"))==OK,"Could not capture the scrolled original offer")
	panel.confirm();check(panel.snapshot().confirming,"Confirm did not open the acceptance question")
	check(panel.present(state) and panel.snapshot().confirming,"An unchanged frame cancelled acceptance")
	state.contract_previews[longest]={"can_accept":false,"reason_text_id":int(bindings.early_contracts.courier.capacity_text_id),"cargo_tons":14}
	check(panel.present(state) and not panel.snapshot().accept_visible,"Changed cargo requirements left acceptance available")
	check(panel.snapshot().body.contains("14"),"The capacity warning lost the offered cargo quantity")
	check(not panel.snapshot().confirming,"Changed acceptance terms retained an obsolete confirmation")
	state.contract_previews[longest]={"can_accept":true,"replacement_required":false}
	check(panel.present(state) and not panel.snapshot().confirming,"Restoring acceptance silently confirmed the changed offer")
	var started:=Time.get_ticks_usec()
	for frame in 500:panel.present(state)
	print("Unchanged lounge presentation, 500 updates: %d us"%(Time.get_ticks_usec()-started))
	panel.free();await process_frame

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
