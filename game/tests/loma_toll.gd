extends SceneTree
## Loma pirate toll: amount and percent, answers and their career effects,
## pirates holding fire under the truce, a hit breaking it, clearing outside
## Loma, the saved progress key and the scripted radio lines.
const Toll=preload("res://src/content/loma_toll_definitions.gd")
const LomaToll=preload("res://src/simulation/loma_toll.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const Actor=preload("res://src/simulation/opening_combat_actor.gd")
const Group=preload("res://src/simulation/opening_combat_group.gd")
const FreeLife=preload("res://src/content/free_lifecycle_definitions.gd")
const Archive=preload("res://src/simulation/opening_station_archive.gd")
const LocalRadio=preload("res://src/simulation/local_traffic_radio.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const StationArchive=preload("res://src/simulation/station_archive.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Frame=preload("res://src/simulation/first_flight_frame.gd")
var library=preload("res://src/content/library.gd").new()
var bindings=preload("res://src/content/resource_bindings.gd").new()
var catalogues=preload("res://src/content/catalogues.gd").new()
var checks:=0
var failures:=0

class FakeActor extends RefCounted:
	var kind:=8
	var truce:=false
	var _read:={}
	func read_snapshot() -> Dictionary:return snapshot()
	func fork_for_frame() -> RefCounted:
		var copy:=FakeActor.new();copy.kind=kind;copy.truce=truce;return copy
	func snapshot() -> Dictionary:return {"actor_kind":kind,"active":true}
	func normal_hit(_amount,_nonplayer) -> Dictionary:return {"destroyed_now":false}
	func apply_free_hostility(_reputation,_forced,_rules,held:=false) -> bool:truce=held;return true

class FakeProvocation extends RefCounted:
	func fork_for_frame() -> RefCounted:return self
	func snapshot() -> Dictionary:return {"forced_hostile":[false,false],"initial_reputation":{"override":-1,"axes":[0,0]}}
	func read_state() -> Dictionary:return snapshot()
	func signature_axes(_race) -> Array:return []
	func evaluate(_a,_b,_c,_d,_e) -> Dictionary:return {"owner":self,"random_state":{},"events":[]}

class FakeReputation extends RefCounted:
	func fork_for_frame() -> RefCounted:return self
	func apply_to(prior: Dictionary,_count:=0) -> Dictionary:return prior.duplicate(true)

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not catalogues.open(library) or not library.select_language("gb"):check(false,library.error+bindings.error+catalogues.error)
	else:
		verify_amount()
		verify_answers()
		verify_career()
		verify_hostility()
		verify_group()
		verify_archive()
		verify_text()
		verify_radio()
		if not OS.get_environment("GOF2_SOURCE_SAVE").is_empty():verify_flight()
	print("Loma toll: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_amount() -> void:
	check(Toll.percent(0.0)==2 and Toll.percent(0.5)==5 and Toll.percent(1.0)==10 and Toll.percent(1.5)==20,"Toll percent by difficulty is wrong")
	var items: Array=catalogues.tables.items
	var value:=Toll.cargo_value([{"item_id":120,"quantity":10},{"item_id":121,"quantity":2}],[{"item_id":120,"unit_price":300}],items)
	check(value==10*300+2*int(items[121].properties.get(7,0)),"Cargo value does not use paid or catalogue prices: %d"%value)
	check(Toll.cargo_value([],[],items)==100,"An empty hold is not valued at 100")
	check(Toll.amount(3000,0.5)==150 and Toll.amount(100,0.5)==5,"Toll amount is not the percent of the hold value")

func verify_answers() -> void:
	var toll:=LomaToll.new()
	var line:=toll.start(0,0)
	check(line in Toll.WELCOME and toll.holds_fire(),"An unasked Loma flight does not welcome with pirates holding fire")
	check(not toll.observe_finished(440,3000,0.5) and not toll.question,"Another line opened the toll question")
	check(toll.observe_finished(line,3000,0.5) and toll.question and toll.amount==150 and toll.percent==5,"The welcome did not ask 5% of 3000")
	check(not toll.observe_finished(line,3000,0.5),"The question was asked twice")
	var paid: Dictionary=toll.fork().answer(true,1000)
	check(paid.status==Toll.PAID and paid.debit==150 and paid.radio in Toll.PAID_LINES,"Yes with credits did not pay")
	var poor: Dictionary=toll.fork().answer(true,100)
	check(poor.status==Toll.REFUSED and poor.debit==0 and poor.shortfall==50 and poor.radio in Toll.ATTACK,"Yes without credits was not a refusal with its shortfall")
	var refused: RefCounted=toll.fork();var no: Dictionary=refused.answer(false,1000)
	check(no.status==Toll.REFUSED and no.shortfall==0 and no.radio in Toll.ATTACK and not refused.holds_fire(),"No did not turn the pirates hostile")
	var back:=LomaToll.new()
	check(back.start(Toll.PAID,0)==-1 and back.holds_fire(),"A paid toll radioed or armed the pirates")
	check(back.start(Toll.REFUSED,0) in Toll.RETURN and not back.holds_fire(),"A refused toll did not radio its return line")
	var hit:=LomaToll.new();hit.start(Toll.PAID,0)
	check(hit.provoke() and hit.status==Toll.REFUSED and not hit.provoke(),"Hitting a pirate did not refuse the paid toll")

func verify_career() -> void:
	var career:=Contracts.new();career._state={"credits":1000,"progress":{}}
	check(career.set_loma_toll(Toll.PAID,150) and career._state.credits==850 and career._state.progress.loma_toll==Toll.PAID,"Paying did not debit and record the toll")
	check(not career.set_loma_toll(Toll.PAID,5000) and career._state.credits==850,"An unaffordable toll was debited")
	check(not career.set_loma_toll(Toll.REFUSED,10),"A refusal debited credits")
	check(career.set_loma_toll(Toll.REFUSED) and Toll.status(career._state.progress)==Toll.REFUSED,"Refusal was not recorded")
	check(career.set_loma_toll(0) and not career._state.progress.has("loma_toll") and career._state.credits==850,"Leaving Loma did not clear the toll")

func verify_hostility() -> void:
	var rules: Dictionary=FreeLife.VALUES.standing.duplicate(true)
	var reputation:={"override":-1,"axes":[0,0]}
	for truce in [false,true]:
		var actor:=Actor.new();actor._state={"free_traffic":true,"local_combat":true,"actor_kind":8,"hostile":true,"friendly":false}
		check(actor.apply_free_hostility(reputation,false,rules,truce),actor.error)
		check(actor._state.hostile==not truce,"Pirate hostility under truce=%s is wrong"%truce)
	var forced:=Actor.new();forced._state={"free_traffic":true,"local_combat":true,"actor_kind":8,"hostile":false,"friendly":false}
	check(forced.apply_free_hostility(reputation,true,rules,true) and forced._state.hostile,"A provoked pirate held fire")
	var trader:=Actor.new();trader._state={"free_traffic":true,"local_combat":true,"actor_kind":0,"hostile":false,"friendly":false}
	check(trader.apply_free_hostility(reputation,false,rules,false) and not trader._state.hostile,"Truce wiring changed other factions")

func verify_group() -> void:
	var group:=Group.new()
	var pirate:=FakeActor.new();var trader:=FakeActor.new();trader.kind=0
	group._actors=[pirate,trader];group._provocation=FakeProvocation.new();group._reputation=FakeReputation.new();group._training_weapons={"free_lifecycle":{}}
	group.set_truce([Toll.PIRATE_KIND])
	check(group.refresh_hostility(0) and group._actors[0].truce and group.refresh_hostility(1) and not group._actors[1].truce,"The truce did not reach only the pirates: "+group.error)
	# Hits run without faction provocation (pirates are not eligible for it).
	var provocation: RefCounted=group._provocation;group._provocation=null
	check(not group.normal_hit(1,10,false).is_empty() and not group.truce_broken(),"Hitting a trader broke the pirate truce")
	check(not group.normal_hit(0,10,true).is_empty() and not group.truce_broken(),"A non-player hit broke the truce")
	check(not group.normal_hit(0,10,false).is_empty() and group.truce_broken() and group.truce_kinds().is_empty(),"Hitting a pirate did not break the truce")
	group._provocation=provocation
	check(group.refresh_hostility(0) and not group._actors[0].truce,"Pirates kept holding fire after the hit")
	check(group.fork_for_frame().truce_broken(),"A forked frame lost the broken truce")

func verify_archive() -> void:
	check("loma_toll" in Archive.OPTIONAL_PROGRESS_KEYS and "loma_toll" in Archive.LIFETIME_KEYS,"The save does not carry the toll state")
	check(Archive.valid_lifetime("loma_toll",1) and Archive.valid_lifetime("loma_toll",2) and not Archive.valid_lifetime("loma_toll",3) and not Archive.valid_lifetime("loma_toll",0),"The saved toll state range is wrong")

func verify_text() -> void:
	var strings: Array=library.strings
	var question:=Toll.question_text(strings[Toll.QUESTION_TEXT],5,150)
	check(question.contains("5%") and question.contains("150$") and not question.contains("#"),"Question tokens were not filled: "+question)
	check(Toll.shortfall_text(strings[Toll.SHORTFALL_TEXT],50).contains("50$"),"Shortfall text lacks the missing credits")
	check(strings[Toll.YES_TEXT]=="Yes" and strings[Toll.NO_TEXT]=="No","Yes/No texts moved")
	for text_id in Toll.LINES:
		check(not str(strings[text_id]).is_empty(),"Toll line %d has no text"%text_id)
		var message:={"serial":0,"kind":"scripted","speaker_id":Toll.SPEAKER_ID,"text_id":text_id,"voice_event_id":Toll.LINES[text_id]}
		check(LocalRadio.valid_payload({},message),"Toll line %d is not a valid scripted radio message"%text_id)
	check(not LocalRadio.valid_payload({},{"serial":0,"kind":"scripted","speaker_id":Toll.SPEAKER_ID,"text_id":438,"voice_event_id":1440}),"A mismatched toll voice was accepted")
	check(LocalRadio.valid_portrait({},{"status":"speaker"}),"Scripted lines lack the speaker portrait")

func verify_radio() -> void:
	var metrics=load("res://src/content/image_font.gd").new();var layout=load("res://src/presentation/source_text_layout.gd").new()
	if not metrics.open_selected(library,bindings,0) or not layout.configure_from_bindings(metrics,350,5,bindings):check(false,metrics.error+layout.error);return
	var radio:=LocalRadio.new()
	if not radio.configure(bindings,library,layout,10):check(false,radio.error);return
	check(not radio.queue_scripted(100) and radio.queue_scripted(438),"Scripted radio accepted another line or refused the welcome")
	var audio=load("res://src/presentation/opening_audio.gd").new()
	audio._local_radio_rules=bindings.mido_travel.traffic_combat.radio.duplicate(true);audio._voice_displayed=[false,false]
	audio._radio_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":10,"language":"gb"}
	var reaction:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":10,"radio_serial":0,"pending_radio":{}}
	var random:={"state":42};var seen:=[];var voices:=[]
	for time in range(0,30000,50):
		var update:=radio.evaluate(time,reaction,random)
		if update.is_empty():check(false,radio.error);break
		radio=update.radio;random=update.random_state
		for event in update.events:
			seen.append(event.kind)
			check(event.get("message_kind")=="scripted" and event.get("text_id")==438,"Scripted event lost its line")
		var prepared:Dictionary=audio.prepare_local_radio({"radio":radio.snapshot(),"radio_changes":update.events})
		if prepared.is_empty():check(false,audio.error);break
		for op in prepared.operations:voices.append(op.source_id)
		audio._voice_displayed=prepared.displayed
		if "finished" in seen:break
	check(seen==["started","display","finished"],"The welcome did not play through: %s"%[seen])
	check(voices==[1436],"The welcome voice did not start once: %s"%[voices])
	audio.free()

## Optional earned station save in Loma (GOF2_SOURCE_SAVE): the welcome is
## chosen by the departure's seeds, whatever the engine's global RNG holds.
func verify_flight() -> void:
	var file:=SaveFile.new()
	var document:=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,catalogues,library)
	if document.is_empty():check(false,file.error);return
	var bodies:=preload("res://src/content/scenery_body_resources.gd").new();var effects:=preload("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var heard:=[]
	for global_seed in [1,2,3,4,5,6]:
		seed(global_seed)
		var archive:=StationArchive.new();var station: RefCounted=archive.restore(bindings,catalogues,library,document)
		if station==null:check(false,archive.error);return
		var construction:=Construction.new();var world:=Frame.new()
		if not construction.prepare_free(bindings,catalogues,station,4096,1789100000,true,bodies,effects) or not world.configure(bindings,catalogues,library,construction,"E",0.5):check(false,construction.error+world.error);return
		heard.append(world._radio._scripted.map(func(message):return message.text_id))
	check(heard[0].size()==1 and heard[0][0] in Toll.WELCOME,"The Loma departure queued no welcome: %s"%[heard[0]])
	check(heard.all(func(lines):return lines==heard[0]),"The Loma welcome changed with the engine's global RNG: %s"%[heard])

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr(message)
