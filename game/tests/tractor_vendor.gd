extends SceneTree
## The Android end of Generator::createAgents: the lounge reward jackpot and the
## Thynome tractor-beam vendor (creation, speech, greeting, departure,
## retention). Detached from any journey; Mac content has neither.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Contacts=preload("res://src/simulation/lounge_contacts.gd")
const Cache=preload("res://src/simulation/lounge_cache.gd")
const Session=preload("res://src/simulation/contract_session.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Offer=preload("res://src/simulation/contract_offer.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Navigation=preload("res://src/simulation/contract_navigation.gd")
const Persistent=preload("res://src/content/persistent_contact_definitions.gd")
const Ordinary=preload("res://src/content/ordinary_generation_definitions.gd")
const LoungePanel=preload("res://src/presentation/lounge_panel.gd")
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const VENDOR={"creation_cursor":23,"station_id":10,"faction":0,"male":true,"role":2,"item_id":68,"quantity":1,"total_price":100000,"dialogue_cursor":24,"text_ids":[3390,3391],"separator":"\n","departure_cursor":24}
const JACKPOT={"forced_cursor":23,"forced_station_id":10,"draw_bound":100,"winning_roll":1,"role":0,"maximum_reward":49999,"multiplier":10,"cap":50000}
const TRADE={"item_id":68,"quantity":1,"total_price":100000}
const SETTINGS={"difficulty":1.0,"valkyrie_owned":true,"supernova_owned":true,"energy_availability_percent":0,"missile_availability_percent":0,"ship_price_percent":0}
var checks:=0
var failures:=0
var capped:=false
var exact:=false
var guarded:=0

class Draws extends RefCounted:
	var choices:=[]
	var wrong:=false
	func _init(values: Array):choices=values.duplicate(true)
	func next_int(bound: int) -> int:
		if choices.is_empty():wrong=true;return 0
		var pair: Array=choices.pop_front()
		if pair[0]!=bound:wrong=true
		return int(pair[1])

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Tractor vendor and lounge jackpot: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func verify(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not lib.select_language("gb") or not cat.open(lib) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+visuals.error);return
	var history:=[];history.resize(15);history.fill(false)
	var context:={"campaign_cursor":23,"station_id":10,"rank":0,"reputation":{"axes":[0,0],"override":-1},"difficulty":1.0,"system_availability":Navigation.initial_availability(bindings,cat,false)}
	if bindings.source_architecture!="android-armv7":
		verify_mac(bindings,cat,lib,visuals,context,history);return
	check(Equal.equal_value(Persistent.vendor(bindings),VENDOR) and Equal.equal_value(bindings.early_contracts.generation.get("jackpot"),JACKPOT),"Android lounge rules differ from the library's")
	if failures:return
	verify_vendor_generation(bindings,cat,lib,context,history)
	verify_other_lounges(bindings,cat,lib,context,history)
	verify_jackpot(bindings,cat,lib,context,history)
	verify_retention(bindings,cat,lib)
	verify_speech(bindings,cat,lib,visuals,context,history)

## The Mac lounges keep their generation; no vendor, jackpot or retirement.
func verify_mac(bindings: RefCounted,cat: RefCounted,lib: RefCounted,visuals: RefCounted,context: Dictionary,history: Array) -> void:
	check(Persistent.vendor(bindings).is_empty() and not bindings.early_contracts.generation.has("jackpot"),"Mac bindings carry the Android lounge rules")
	for cursor in [23,24]:
		context.campaign_cursor=cursor
		for seed_value in range(6):
			var random:=Random.new();random.seed_from(seed_value*4097)
			var current:=Contacts.new()
			if not current.prepare(bindings,cat,lib,context,random.snapshot(),history):check(false,current.error);return
			check(not current.snapshot().contacts.any(func(row):return row.get("trade")==TRADE or row.offer.get("choices",{}).has("jackpot")),"A Mac lounge gained the tractor-beam vendor or the jackpot")
			if seed_value==0:
				var raised: Array=current.snapshot().contacts.filter(func(row):return not row.offer.is_empty())
				if not raised.is_empty():
					var offer: Dictionary=raised[0].offer;var choices: Dictionary=offer.choices.duplicate(true);choices.jackpot=true
					check(not Offer.new().configure(bindings,cat,offer.context,choices),"A Mac offer accepted the Android jackpot")
	context.campaign_cursor=23
	var cache:=Cache.new();check(cache.configure(bindings),cache.error)
	var random:=Random.new();random.seed_from(5)
	check(cache.select_location(bindings,cat,lib,career(23),SETTINGS,random.snapshot(),1789100000),cache.error)
	var session:=Session.new();session._lounges=cache.fork();session._state={"campaign_cursor":24,"station_id":10}
	session.retire_departure_vendors(bindings)
	check(session._lounges.snapshot()==cache.snapshot(),"A Mac departure retired lounge contacts")
	check(Cache.greeting(Persistent.vendor(bindings),{"campaign_cursor":24,"station_id":10,"lounges":cache.snapshot()})==-1,"A Mac lounge greeted")
	# A Mac seller of item 68 at cursor 24 in Thynome keeps the generic offer.
	var seller: Dictionary=cache.location(10).population.contacts[1].duplicate(true);seller.trade=TRADE.duplicate()
	var panel:=LoungePanel.new();root.add_child(panel);root.size=Vector2i(1280,720)
	check(panel.configure(lib,bindings,visuals,cat) and panel.present(lounge_state(bindings,seller,24,100000,false,10,68)),panel.error)
	panel.select_contact(1,false)
	check(panel.snapshot().body==panel.label_text(855).replace("#Q","1").replace("#P",panel.text(int(bindings.station_equipment.item_text_offset)+68)).replace("#C","100000$"),"A Mac seller spoke the Android vendor's lines")
	panel.free()

func career(cursor: int,station_id: int=10) -> Dictionary:
	return {"campaign_cursor":cursor,"station_id":station_id,"rank":0,"reputation":{"axes":[0,0],"override":-1}}

## The population under the Mac rules: no jackpot, no vendor.
func plain(bindings: RefCounted,cat: RefCounted,lib: RefCounted,context: Dictionary,random_state: Dictionary,history: Array) -> Dictionary:
	var kept:=[bindings.early_contracts,bindings.persistent_contacts]
	var terms: Dictionary=kept[0].duplicate(true);terms.generation.erase("jackpot")
	var agents: Dictionary=kept[1].duplicate(true);agents.erase("tractor_vendor")
	bindings.early_contracts=terms;bindings.persistent_contacts=agents
	var owner:=Contacts.new();var prepared:=owner.prepare(bindings,cat,lib,context,random_state,history)
	bindings.early_contracts=kept[0];bindings.persistent_contacts=kept[1]
	check(prepared,"The Mac-rule population failed: "+owner.error)
	return owner.snapshot()

func vendor_contact(names: Array,bindings: RefCounted,random: RefCounted) -> Dictionary:
	# The vendor's name and then portrait follow the count draws.
	var probe:=Contacts.new();probe._rules=bindings.early_contracts.generation;probe._names=names
	probe._rng=Random.new();probe._rng.restore(random.snapshot())
	probe._population_count(1,bindings.persistent_contacts)
	var name:=probe._name(0,true)
	return {"contact_id":1,"faction":0,"male":true,"role":2,"name":name,"portrait":probe._portrait(0,true),"trade":TRADE,"offer":{},"source_contact_id":-1,"generated":true}

func verify_vendor_generation(bindings: RefCounted,cat: RefCounted,lib: RefCounted,context: Dictionary,history: Array) -> void:
	var names:=[]
	for path in bindings.early_contracts.generation.names.resources:names.append(Contacts.decode_names(lib.read_resource(path,1024*1024)))
	var replaced:=0;var forced_raises:=0
	for seed_value in range(32):
		context.reputation.axes=[100,100] if seed_value%2 else [0,0]
		var random:=Random.new();random.seed_from(seed_value*4097)
		var current:=Contacts.new();var old:=plain(bindings,cat,lib,context,random.snapshot(),history)
		if not current.prepare(bindings,cat,lib,context,random.snapshot(),history) or old.is_empty():check(false,current.error);return
		var state:=current.snapshot()
		check(state.contacts.size()==old.contacts.size() and state.contacts.size() in [4,5],"The vendor did not take one of the generated slots")
		check(state.contacts[0].get("source_contact_id")==5 and not state.contacts[0].generated,"The vendor displaced the authored contact")
		check(not old.contacts.any(func(row):return row.get("trade")==TRADE),"An older lounge revision created the vendor")
		var seller: Dictionary=state.contacts[1]
		if seller.role==7:replaced+=1
		else:check(seller==vendor_contact(names,bindings,random),"The vendor differs from Generator::createAgents")
		check(state.contacts.filter(func(row):return row.get("trade")==TRADE).size()<=1+int(seller.role==7),"The vendor was created twice")
		# The vendor's lounge always pays one jackpot (cursor 23 in Thynome).
		var raised: Array=state.contacts.filter(func(row):return not row.offer.is_empty() and row.offer.choices.get("jackpot",false))
		var eligible: Array=state.contacts.slice(2).filter(func(row):return row.role==0 and not row.offer.is_empty() and (row.offer.choices.get("jackpot",false) or int(row.offer.mission.reward)<=49999))
		check(raised.size()==int(not eligible.is_empty()) and (eligible.is_empty() or eligible[0]==raised[0]),"The forced Thynome jackpot missed its first eligible contract")
		forced_raises+=raised.size()
		var restored:=Contacts.new()
		check(restored.restore(bindings,cat,lib,state) and restored.snapshot()==state,"The vendor's lounge failed exact restoration: "+restored.error)
		if seller.role!=7:
			var forged:=state.duplicate(true);forged.contacts[1].trade.total_price=150000
			check(not Contacts.new().restore(bindings,cat,lib,forged),"A changed vendor price was accepted")
	check(replaced>0 and forced_raises>0,"No population replaced the vendor with a hostile diplomat or paid the forced jackpot")
	context.reputation.axes=[0,0]

## Elsewhere the population is the older revision's except one jackpot draw.
func verify_other_lounges(bindings: RefCounted,cat: RefCounted,lib: RefCounted,context: Dictionary,history: Array) -> void:
	var places:=[[24,10],[22,10]]
	for id in cat.tables.stations.size():
		if id!=10 and Ordinary.location_supported(bindings,cat,23,id):places.append([23,id]);break
	check(places.size()==3,"No other cursor-23 lounge to compare")
	var raised:=0
	for place in places:
		var lounge:=context.duplicate(true);lounge.campaign_cursor=place[0];lounge.station_id=place[1]
		var won:=0
		# Every lounge draws nextInt(100) after its population; 1 wins.
		for seed_value in range(1500):
			var random:=Random.new();random.seed_from(seed_value*977+place[1])
			var old:=plain(bindings,cat,lib,lounge,random.snapshot(),history)
			if old.is_empty():return
			var after:=Random.new();after.restore(old.random)
			var roll: int=after.next_int(100)
			if seed_value>=6 and roll!=1:continue
			var current:=Contacts.new()
			if not current.prepare(bindings,cat,lib,lounge,random.snapshot(),history):check(false,current.error);return
			var state:=current.snapshot()
			var eligible: bool=old.contacts.slice(1).any(func(row):return row.role==0 and not row.offer.is_empty() and int(row.offer.mission.reward)<=49999)
			check(same_population(state.contacts,old.contacts)==int(roll==1 and eligible),"A lounge outside cursor-23 Thynome differs from its jackpot draw %d: %s"%[roll,place])
			check(state.draw_calls==old.draw_calls+1 and state.random==after.snapshot(),"A lounge outside cursor-23 Thynome skipped or repeated its jackpot draw")
			var restored:=Contacts.new()
			check(restored.restore(bindings,cat,lib,state) and restored.snapshot()==state,"A jackpot lounge failed exact restoration: "+restored.error)
			if roll==1 and eligible:
				raised+=1;won+=1
				break
		check(won==1,"No seeded lounge won the jackpot at %s"%[place])
	# The early Mido lounges draw it too.
	var mido:={"campaign_cursor":13,"station_id":79,"rank":0,"reputation":{"axes":[30,0],"override":-1}}
	var random:=Random.new();random.seed_from(0)
	var current:=Contacts.new();var early:=plain(bindings,cat,lib,mido,random.snapshot(),history)
	if not current.prepare(bindings,cat,lib,mido,random.snapshot(),history) or early.is_empty():check(false,current.error);return
	check(current.snapshot().draw_calls==early.draw_calls+1 and current.snapshot().keys()==early.keys(),"The early lounge lost its jackpot draw or changed its schema")

## Number of jackpot-raised offers by which a equals b, or -1.
func same_population(a: Array,b: Array) -> int:
	if a.size()!=b.size():return -1
	var raised:=0
	for index in a.size():
		if a[index]==b[index]:continue
		var row: Dictionary=a[index].duplicate(true)
		if row.offer.is_empty() or not row.offer.choices.get("jackpot",false):return -1
		if not raised_correctly(row.offer,b[index].offer):return -1
		row.offer=b[index].offer
		if row!=b[index]:return -1
		raised+=1
	return raised

func raised_correctly(raised: Dictionary,original: Dictionary) -> bool:
	var reward:=int(original.mission.reward)
	if reward*10>50000:capped=true
	else:exact=true
	var mission: Dictionary=raised.mission.duplicate(true);mission.reward=reward
	var choices: Dictionary=raised.choices.duplicate(true);choices.erase("jackpot")
	return raised.mission.reward==mini(reward*10,50000) and mission==original.mission and choices==original.choices and raised.context==original.context

func owner_for(bindings: RefCounted,cat: RefCounted,lounge: Dictionary,draws: Array) -> RefCounted:
	var owner:=Contacts.new();owner._rules=bindings.early_contracts.generation.duplicate(true);owner._catalogues=cat
	owner._context=lounge;owner._rng=Draws.new(draws)
	return owner

func draws_done(owner: RefCounted,label: String) -> void:
	check(owner.error.is_empty() and not owner._rng.wrong and owner._rng.choices.is_empty(),"Jackpot draws differ: "+label)

## _jackpot itself on revision-1 rosters: which contract, how much, how many draws.
func verify_jackpot(bindings: RefCounted,cat: RefCounted,lib: RefCounted,context: Dictionary,history: Array) -> void:
	var lounge:=context.duplicate(true);lounge.campaign_cursor=24
	var tested:=0
	for seed_value in range(60):
		var random:=Random.new();random.seed_from(seed_value*31)
		var roster: Array=plain(bindings,cat,lib,lounge,random.snapshot(),history).get("contacts",[])
		if roster.is_empty():return
		var eligible:=[]
		for index in range(1,roster.size()):
			if roster[index].role==0 and not roster[index].offer.is_empty() and int(roster[index].offer.mission.reward)<=49999:eligible.append(index)
		if eligible.size()<2:continue
		tested+=1
		var first: int=eligible[0];var second: int=eligible[1]
		# A winning draw raises the first eligible contract only.
		var owner:=owner_for(bindings,cat,lounge,[[100,1]]);var contacts:=roster.duplicate(true)
		owner._jackpot(bindings,contacts,1);draws_done(owner,"winning draw")
		check(raised_correctly(contacts[first].offer,roster[first].offer) and Offer.new().restore(bindings,cat,contacts[first].offer),"The jackpot raise differs from Mission::setReward")
		check(changed_only(contacts,roster,[first]),"The jackpot changed another contact")
		for roll in [0,2,99]:
			owner=owner_for(bindings,cat,lounge,[[100,roll]]);contacts=roster.duplicate(true)
			owner._jackpot(bindings,contacts,1);draws_done(owner,"losing draw %d"%roll)
			check(contacts==roster,"A losing draw raised a reward")
		# Cursor 23 in Thynome raises without a draw.
		var forced:=lounge.duplicate(true);forced.campaign_cursor=23
		owner=owner_for(bindings,cat,forced,[]);contacts=roster.duplicate(true)
		owner._jackpot(bindings,contacts,1);draws_done(owner,"forced")
		check(owner._draws==0 and changed_only(contacts,roster,[first]),"Cursor-23 Thynome drew for or missed its jackpot")
		for place in [[23,11],[24,10],[22,10]]:
			var elsewhere:=lounge.duplicate(true);elsewhere.campaign_cursor=place[0];elsewhere.station_id=place[1]
			owner=owner_for(bindings,cat,elsewhere,[[100,0]]);contacts=roster.duplicate(true)
			owner._jackpot(bindings,contacts,1);draws_done(owner,"unforced %s"%[place])
			check(contacts==roster,"The jackpot was forced outside cursor-23 Thynome")
		# A reward above 49999, another role or a slot before the scan is skipped.
		var large:=roster.duplicate(true);large[first].offer.mission.reward=50000
		owner=owner_for(bindings,cat,lounge,[[100,1]]);owner._jackpot(bindings,large,1)
		check(large[first].offer.mission.reward==50000 and changed_only(large,roster,[first,second]) and raised_correctly(large[second].offer,roster[second].offer),"A large reward was raised or blocked the next contract")
		var other:=roster.duplicate(true);other[first].role=1
		owner=owner_for(bindings,cat,lounge,[[100,1]]);owner._jackpot(bindings,other,1)
		check(other[first].offer==roster[first].offer and raised_correctly(other[second].offer,roster[second].offer),"A contact of another role was raised")
		owner=owner_for(bindings,cat,lounge,[[100,1]]);contacts=roster.duplicate(true)
		owner._jackpot(bindings,contacts,first+1)
		check(changed_only(contacts,roster,[second]),"The scan ignored its first generated slot")
		var reward:=int(roster[first].offer.mission.reward)
		for limit in [reward-1,reward]:
			owner=owner_for(bindings,cat,lounge,[[100,1]]);owner._rules.jackpot.maximum_reward=limit;contacts=roster.duplicate(true)
			owner._jackpot(bindings,contacts,1)
			check((contacts[first].offer!=roster[first].offer)==(limit==reward),"The jackpot limit is not inclusive")
		verify_offer_guard(bindings,cat,roster[first].offer)
		if tested>=6:break
	check(tested>0,"No seeded roster had two eligible contracts")
	# Small early rewards are multiplied exactly; larger ones meet the cap.
	var mido:={"campaign_cursor":13,"station_id":79,"rank":0,"reputation":{"axes":[30,0],"override":-1}}
	for seed_value in range(20):
		var random:=Random.new();random.seed_from(seed_value)
		var roster: Array=plain(bindings,cat,lib,mido,random.snapshot(),history).get("contacts",[])
		if roster.is_empty():return
		var owner:=owner_for(bindings,cat,mido,[[100,1]]);var contacts:=roster.duplicate(true)
		owner._jackpot(bindings,contacts,0)
		check(same_population(contacts,roster)==int(roster.any(func(row):return row.role==0 and not row.offer.is_empty())),"The early jackpot differs")
	check(capped and exact and guarded>0,"The fixtures missed the capped or the exact raise or a large reward")

func changed_only(contacts: Array,roster: Array,ids: Array) -> bool:
	for index in contacts.size():
		if (contacts[index]!=roster[index])!=(index in ids):return false
	return true

## The raised offer restores only with its jackpot choice and a small reward.
func verify_offer_guard(bindings: RefCounted,cat: RefCounted,original: Dictionary) -> void:
	var choices: Dictionary=original.choices.duplicate(true);choices.jackpot=true
	var offer:=Offer.new()
	check(offer.configure(bindings,cat,original.context,choices) and offer.snapshot().mission.reward==mini(int(original.mission.reward)*10,50000),"The jackpot choice did not raise the reward")
	for value in [false,1,"true"]:
		choices.jackpot=value
		check(not Offer.new().configure(bindings,cat,original.context,choices),"An invalid jackpot choice was accepted")
	var forged:=original.duplicate(true);forged.mission.reward=mini(int(original.mission.reward)*10,50000)
	check(not Offer.new().restore(bindings,cat,forged),"A raised reward restored without its jackpot choice")
	choices.jackpot=true
	var rich:Dictionary=original.context.duplicate(true);rich.rank=bindings.opening_handoff.rank_thresholds.size()-1
	var base:=Offer.new()
	if base.configure(bindings,cat,rich,original.choices) and int(base.snapshot().mission.reward)>49999:
		check(not Offer.new().configure(bindings,cat,rich,choices),"The jackpot raised a reward above 49999")
		guarded+=1

## Arrival, greeting, departure and saves in the retained lounge cache.
func verify_retention(bindings: RefCounted,cat: RefCounted,lib: RefCounted) -> void:
	var rules:=Persistent.vendor(bindings)
	var cache:=Cache.new();check(cache.configure(bindings),cache.error)
	var random:=Random.new();random.seed_from(5)
	if not cache.select_location(bindings,cat,lib,career(23),SETTINGS,random.snapshot(),1789100000):check(false,cache.error);return
	check(cache.location(10).population.contacts[1].get("trade")==TRADE,"Arriving at Thynome at cursor 23 created no vendor")
	check(cache.merchant_quote(10,1)=={"item_id":68,"quantity":1,"total_price":100000,"consumed":false},"The vendor's quote differs")
	var view:={"campaign_cursor":24,"station_id":10,"lounges":cache.snapshot()}
	check(Cache.greeting(rules,view)==1,"The vendor did not greet at cursor 24")
	for wrong in [{"campaign_cursor":23},{"campaign_cursor":25},{"station_id":11}]:
		var other:=view.duplicate(true);other.merge(wrong,true)
		check(Cache.greeting(rules,other)==-1,"The vendor greeted outside cursor-24 Thynome")
	check(Cache.greeting({},view)==-1,"A lounge without the vendor rules greeted")
	var moved:=view.duplicate(true);moved.station_id=11
	for entry in moved.lounges.locations:if entry.station_id==10:entry.station_id=11
	check(Cache.greeting(rules,moved)==-1,"A seller of item 68 greeted outside Thynome")
	var other_item:=view.duplicate(true)
	for entry in other_item.lounges.locations:if entry.station_id==10:entry.population.contacts[1].trade.item_id=69
	check(Cache.greeting(rules,other_item)!=1,"A seller of another item greeted")
	var met: RefCounted=cache.fork();met.meet(10,1)
	check(Cache.greeting(rules,{"campaign_cursor":24,"station_id":10,"lounges":met.snapshot()})==-1,"A met vendor greeted again")
	# Departure at cursor 24 from Thynome retires him, bought or not; the
	# retired lounge passes the save check.
	var retired:=Session.new();retired._lounges=cache.fork();retired._state={"campaign_cursor":24,"station_id":10}
	retired.retire_departure_vendors(bindings)
	var after: Dictionary=retired._lounges.location(10)
	check(after.get("purchased_goods",[])==[1] and after.get("known",[])==[1],"Departure did not retire the vendor")
	check(retired._lounges.merchant_quote(10,1).consumed and not retired._lounges.consume_goods(10,1),"A retired vendor still sells")
	retired.retire_departure_vendors(bindings)
	check(retired._lounges.location(10).purchased_goods==[1],"Retiring twice repeated the purchase record")
	var saved: RefCounted=Archive.new()._locations(bindings,cat,lib,retired._lounges.snapshot())
	check(saved!=null and saved.snapshot()==retired._lounges.snapshot(),"The retired vendor's lounge failed the save check")
	check(cache.location(10).get("purchased_goods",[]).is_empty(),"Retirement changed the station's own cache")
	var bought: RefCounted=cache.fork()
	check(bought.consume_goods(10,1),bought.error)
	bought.retire_vendors(rules,10)
	check(bought.location(10).purchased_goods==[1] and bought.location(10).known==[1],"Retiring a sold-out vendor repeated the purchase")
	# Only sellers of item 68, only at cursor 24, only from Thynome (forged rosters).
	var merchant: Dictionary=cache.location(10).population.contacts[2].duplicate(true)
	merchant.contact_id=cache.location(10).population.contacts.size();merchant.role=2;merchant.trade={"item_id":1,"quantity":5,"total_price":500}
	for row in [[24,10,true],[23,10,false],[25,10,false],[24,11,false]]:
		var session:=Session.new();session._lounges=cache.fork();session._state={"campaign_cursor":row[0],"station_id":row[1]}
		for entry in session._lounges._state.locations:
			if entry.station_id==10:entry.station_id=row[1];entry.population.contacts.append(merchant)
		session.retire_departure_vendors(bindings)
		var place: Dictionary=session._lounges.location(row[1])
		check((place.get("purchased_goods",[])==[1] and place.get("known",[])==[1])==row[2],"Departure retirement differs at %s"%[row])
		check(not merchant.contact_id in place.get("purchased_goods",[]) and not merchant.contact_id in place.get("known",[]),"Departure retired a seller of another item")
	# Thynome already in the three-station stack keeps its earlier lounge.
	var stacked:=Cache.new();check(stacked.configure(bindings),stacked.error)
	var earlier:=22 if Ordinary.location_supported(bindings,cat,22,10) else 21
	if not stacked.select_location(bindings,cat,lib,career(earlier),SETTINGS,random.snapshot(),1789100000) or not stacked.select_location(bindings,cat,lib,career(23),SETTINGS,random.snapshot(),1789100000):check(false,stacked.error);return
	var kept: Dictionary=stacked.location(10)
	check(kept.population.context.campaign_cursor==earlier and not kept.population.contacts.any(func(row):return row.get("trade")==TRADE),"A stacked Thynome gained the vendor")

## The lounge panel: his speech at cursor 24 in Thynome and "nothing left".
func verify_speech(bindings: RefCounted,cat: RefCounted,lib: RefCounted,visuals: RefCounted,context: Dictionary,history: Array) -> void:
	var random:=Random.new();random.seed_from(0)
	var current:=Contacts.new()
	if not current.prepare(bindings,cat,lib,context,random.snapshot(),history):check(false,current.error);return
	var seller: Dictionary=current.snapshot().contacts[1]
	check(seller.get("trade")==TRADE,"The fixture lounge has no vendor")
	if failures:return
	var panel:=LoungePanel.new();root.add_child(panel);root.size=Vector2i(1280,720);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check(panel.configure(lib,bindings,visuals,cat),panel.error)
	var emitted:=[];panel.action_requested.connect(func(action,id):emitted.append([action,id]))
	var speech: String=(panel.text(3390)+"\n"+panel.text(3391)).replace("#C","100000$")
	check(speech.begins_with("There you are!") and speech.contains("Okay, for 100000$"),"Texts 3390/3391 are not the vendor's")
	var item: String=panel.text(int(bindings.station_equipment.item_text_offset)+68)
	var generic: String=panel.label_text(855).replace("#Q","1").replace("#P",item).replace("#C","100000$")
	for row in [[24,100000,false,speech],[24,99999,false,speech+"\n\n"+panel.text(192).replace("#C","1$")],
		[23,100000,false,generic],[24,0,true,panel.label_text(845)],[24,100000,false,generic,11],
		[24,100000,false,panel.label_text(855).replace("#Q","1").replace("#P",panel.text(int(bindings.station_equipment.item_text_offset)+69)).replace("#C","100000$"),10,69]]:
		check(panel.present(lounge_state(bindings,seller,row[0],row[1],row[2],row[4] if row.size()>4 else 10,row[5] if row.size()>5 else 68)),panel.error)
		panel.select_contact(1,false)
		check(panel.snapshot().body==row[3] and panel.snapshot().selected==1,"The vendor's speech differs at %s: %s"%[row.slice(0,3),panel.snapshot().body])
		check(panel.snapshot().accept_visible==(not row[2] and row[1]>=100000),"The vendor's buy button differs")
	check(emitted.is_empty(),"A greeting selection asked the session to inspect again")
	panel.select_contact(1)
	check(emitted==[["select",1]],"A player selection was not reported")
	panel.free()

func lounge_state(bindings: RefCounted,seller: Dictionary,cursor: int,credits: int,consumed: bool,station_id: int,item_id: int) -> Dictionary:
	var ids:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	var contracts:={"station_id":station_id,"campaign_cursor":cursor,"offers":{},"mission":{},"pending_result":{},"credits":credits,"accepted_contact":{},"completed_side_missions":0,"population":{"contacts":[seller]}}
	contracts.merge(ids)
	var state:={"lounge_open":true,"contracts":contracts,"cargo":{},
		"contract_previews":{1:{"kind":"merchant","item_id":item_id,"quantity":1,"total_price":100000,"consumed":consumed,"can_accept":not consumed and credits>=100000,"missing_credits":maxi(0,100000-credits)}}}
	state.merge(ids)
	return state
