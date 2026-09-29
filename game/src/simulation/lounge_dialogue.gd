extends RefCounted
## Social topics and imported-text references, retained by the lounge owner.
const Random=preload("res://src/simulation/seeded_random.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const TOPIC_BASE=809
const TOPIC_COUNT=21
const ORE_BASE=1417
const ORE_COUNT=10
const STATION_COUNT=100

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and bindings.early_contracts.get("briefing_text_base")==775

static func eligible_topic(topic: int,contact: Dictionary) -> int:
	if (topic==16 and contact.faction!=0) or (topic==13 and not contact.male):return 4
	return topic

static func prepare(contact: Dictionary,random_state: Dictionary,used: Array) -> Dictionary:
	var remaining:=[]
	for topic in TOPIC_COUNT:
		if topic not in used:remaining.append(topic)
	if remaining.is_empty():return {}
	var random:=Random.new()
	if not random.restore(random_state):return {}
	var chosen:=int(remaining[random.next_int(remaining.size())])
	var record:={"topic":eligible_topic(chosen,contact),"station_id":random.next_int(STATION_COUNT),
		"ore_index":random.next_int(ORE_COUNT),"revisited":false}
	return {"dialogue":record,"raw_topic":chosen,"random":random.snapshot()}

static func revisit(record: Dictionary,contact: Dictionary,station_id: int,library: RefCounted) -> Dictionary:
	var next:=record.duplicate(true)
	var random:=Random.new()
	random.seed_from(station_id+int(contact.faction)*String(contact.name).length())
	if String(library.strings[TOPIC_BASE+int(record.topic)]).contains("#S"):
		next.station_id=random.next_int(STATION_COUNT)
	next.ore_index=random.next_int(ORE_COUNT);next.revisited=true
	return next

static func valid(record: Variant,contact: Dictionary,cat: RefCounted,library: RefCounted) -> bool:
	if not record is Dictionary or record.size()!=4 or contact.get("role")!=1 or library==null or cat==null:return false
	if not Numbers.integer(record.get("topic"),0,TOPIC_COUNT-1) or not Numbers.integer(record.get("station_id"),0,STATION_COUNT-1) or not Numbers.integer(record.get("ore_index"),0,ORE_COUNT-1) or not record.get("revisited") is bool:return false
	if eligible_topic(int(record.topic),contact)!=record.topic or cat.tables.stations.size()<STATION_COUNT or library.strings.size()<ORE_BASE+ORE_COUNT:return false
	return not String(library.strings[TOPIC_BASE+int(record.topic)]).is_empty()

static func text(library: RefCounted,cat: RefCounted,record: Dictionary,name: String) -> String:
	return String(library.strings[TOPIC_BASE+int(record.topic)]).replace("#S",String(cat.tables.stations[int(record.station_id)].name)).replace("#N",name).replace("#ORE",String(library.strings[ORE_BASE+int(record.ore_index)]))
