extends SceneTree
const Presentation=preload("res://src/simulation/mission_presentation.gd")
const Epilogue=preload("res://src/content/campaign_epilogue_definitions.gd")
var failures:=0
var checks:=0
var bindings: RefCounted
var library: RefCounted
var layout: RefCounted

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if not prepare_content(args):finish();return
	check(not Epilogue.recipe(bindings,43).is_empty(),"The earned campaign pack cannot prepare its station continuation")
	verify_boundaries()
	for cadence in [[100],[],[7,17,41,8,100,11]]:verify_cadence(cadence)
	verify_rejections()
	finish()

func prepare_content(args: PackedStringArray) -> bool:
	if args.size()!=3:check(false,"Expected selected content, bindings and visuals");return false
	library=load("res://src/content/library.gd").new();bindings=load("res://src/content/resource_bindings.gd").new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb"):
		check(false,library.error+bindings.error);return false
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing declared campaign source");return false
		var accepted: bool=bindings.attach_dekato_source(supplement[1],library.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],library.manifest)
		if not accepted:check(false,bindings.error);return false
	var resources=load("res://src/presentation/opening_radio_resources.gd").new()
	layout=resources.prepare_layout(library,bindings)
	if layout==null:check(false,resources.error);return false
	return true

func prepared() -> RefCounted:
	var result:=Presentation.new()
	check(result.configure(bindings,library,layout,43,Epilogue.presentation()),result.error)
	return result

func verify_boundaries() -> void:
	var sequence:=prepared()
	var before: Dictionary=sequence.snapshot()
	check(before.credits_elapsed_ms==0 and not before.credits_visible,"Credits began before the transmissions")
	check(not sequence.skip() and sequence.snapshot()==before,"Early input skipped the original ending transmission")
	check(sequence.advance(3000) and is_equal_approx(sequence.snapshot().fade_alpha,0.5) and not sequence.snapshot().background_swapped,"The hangar did not fade before the background replacement")
	check(sequence.advance(3000) and sequence.snapshot().background_swapped and sequence.snapshot().fade_alpha==1.0,"Background replacement was visible before full black")
	check(sequence.advance(3000) and is_equal_approx(sequence.snapshot().fade_alpha,0.5),"The exterior did not fade in")
	check(sequence.advance(3000) and sequence.snapshot().fade_alpha==0.0 and not sequence.snapshot().radio.started[0],"Radio began during the opening fade")
	check(sequence.advance(4000) and sequence.snapshot().radio.started[0] and not sequence.snapshot().radio.visible,"The first radio transmission missed its eligibility boundary")
	check(sequence.advance(2000) and not sequence.snapshot().radio.visible,"Radio ignored its strict reveal delay")
	check(sequence.advance(1) and sequence.snapshot().radio.visible,"The eligible transmission never became visible")
	before=sequence.snapshot()
	var branch: RefCounted=sequence.fork()
	check(branch.advance(100) and sequence.snapshot()==before,"A candidate presentation mutated the retained frame")
	before.radio.started[0]=false
	check(sequence.snapshot().radio.started[0],"Editing an inspected snapshot changed live radio")

func verify_cadence(cadence: Array) -> void:
	var sequence:=prepared();var tick:=0;var shown:=[];var completed:=[];var skip_checked:=false
	while sequence.snapshot().elapsed_ms<148000:
		var before: Dictionary=sequence.snapshot()
		var delta: int=int((tick+1)*1000/144)-int(tick*1000/144) if cadence.is_empty() else int(cadence[tick%cadence.size()])
		delta=mini(delta,148000-int(before.elapsed_ms));tick+=1
		if not sequence.advance(delta):check(false,sequence.error);return
		var state: Dictionary=sequence.snapshot()
		for event in state.radio_events:
			if event.kind=="display":shown.append(event.event)
			if event.kind=="finished":completed.append(event.event)
		if state.can_skip and not skip_checked:
			skip_checked=true
			check(completed==[0,1,2,3] and not state.radio.visible,"Skip unlocked before all four transmissions finished")
			var skip: RefCounted=sequence.fork()
			check(skip.skip() and skip.snapshot().complete and skip.snapshot().completion=="skipped" and sequence.snapshot()==state,"Skipping did not complete only the candidate presentation")
			var skipped: Dictionary=skip.snapshot()
			check(not skip.skip() and skip.snapshot()==skipped,"Repeated input completed the same presentation twice")
			verify_scroll(sequence)
	var watched: Dictionary=sequence.snapshot()
	check(skip_checked and shown==[0,1,2,3] and completed==[0,1,2,3],"Cadence changed radio order, lost a line or duplicated speech")
	check(not watched.complete and watched.fade_alpha==1.0,"The ending returned before its strict final fade boundary")
	check(sequence.advance(1) and sequence.snapshot().complete and sequence.snapshot().completion=="watched","The watched ending failed to finish")
	var ended: Dictionary=sequence.snapshot()
	check(not sequence.advance(100) and sequence.snapshot()==ended,"A completed presentation restarted after another frame")

func verify_scroll(source: RefCounted) -> void:
	var sequence: RefCounted=source.fork()
	# A synthetic viewport gives an integral 28-second trip to the centre.
	check(sequence.advance(28000) and is_equal_approx(sequence.credits_layout(674,156).logo_y,337.0),"The logo missed the screen centre")
	check(sequence.advance(3999) and sequence.credits_layout(674,156).holding and is_equal_approx(sequence.credits_layout(674,156).logo_y,337.0),"The logo did not hold at centre")
	check(sequence.advance(1001) and not sequence.credits_layout(674,156).holding and is_equal_approx(sequence.credits_layout(674,156).logo_y,307.0),"Credits did not resume after the centre hold")
	var now: Dictionary=sequence.snapshot()
	sequence.credits_layout(900,156)
	check(sequence.snapshot()==now,"Resizing credits changed speech or completion timing")

func verify_rejections() -> void:
	var sequence:=prepared();var before: Dictionary=sequence.snapshot()
	check(not sequence.advance(-1) and sequence.snapshot()==before,"Invalid time partially advanced the ending")
	var bad:=Epilogue.presentation();bad.radio[0].text_id=-1
	var rejected:=Presentation.new()
	check(not rejected.configure(bindings,library,layout,43,bad) and rejected.snapshot().is_empty(),"Missing source speech left a partially prepared presentation")
	bad=Epilogue.presentation();bad.final_fade_at_ms=bad.complete_after_ms
	check(not Presentation.new().configure(bindings,library,layout,43,bad),"A zero-length final fade was admitted")
	check(sequence.credits_layout(0,156).is_empty(),"An invalid viewport produced credit positions")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func finish() -> void:
	print("Mission presentation: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
