extends SceneTree
## Repair and transfusion beams (Supernova sorts 37 and 41): fitting, targeting,
## heal rate, drain into the shield and the 2.5 s retarget.
const Beams=preload("res://src/simulation/repair_beams.gd")
var library=preload("res://src/content/library.gd").new()
var bindings=preload("res://src/content/resource_bindings.gd").new()
var catalogues=preload("res://src/content/catalogues.gd").new()
var checks:=0
var failures:=0

class FakePlayer extends RefCounted:
	var owner: RefCounted
	var state:={"vitals":{"hull":100,"shield":10.0},"capacities":{"shield":100,"shield_item_id":30}}
	func beams_owner() -> RefCounted:return owner
	func snapshot() -> Dictionary:return state.duplicate(true)
	func add_shield(amount: float) -> void:state.vitals.shield=minf(state.vitals.shield+amount,100.0)

class FakeEncounter extends RefCounted:
	var bodies:=[]
	func beam_bodies() -> Array:return bodies.duplicate(true)
	func apply_beam_effects(heal: Dictionary,drain: Dictionary) -> void:
		for body in bodies:
			body.vitals.hull=mini(body.vitals.hull+int(heal.get(body.actor_id,0)),body.max_hull)-int(drain.get(body.actor_id,0))

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not catalogues.open(library):check(false,library.error+bindings.error+catalogues.error)
	else:
		verify_fitting()
		verify_repair()
		verify_replacement()
		verify_transfusion()
		verify_flight()
	print("Repair beams: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func items() -> Array:return catalogues.tables.items

func row(key: String,position: Vector3,hull: int,max_hull: int,friendly: bool,hostile:=false,cloaked:=false) -> Dictionary:
	return {"key":key,"position":position,"hull":hull,"max_hull":max_hull,"friendly":friendly,"hostile":hostile,"cloaked":cloaked,"alive":hull>0}

func player(shield:=100.0,alive:=true) -> Dictionary:return {"alive":alive,"shield":shield,"capacity":100,"shield_fitted":true}

## Steps of 10 ms; returns the summed effects.
func run_for(owner: RefCounted,ms: int,origin: Vector3,facts: Dictionary,rows: Array) -> Dictionary:
	var total:={"heal":{},"drain":{},"shield":0.0}
	for i in ms/10:
		var effects: Dictionary=owner.advance(10,origin,facts,rows)
		for kind in ["heal","drain"]:
			for key in effects[kind]:total[kind][key]=int(total[kind].get(key,0))+int(effects[kind][key])
		total.shield+=effects.shield
		facts.shield=minf(float(facts.shield)+effects.shield,float(facts.capacity))
	return total

func verify_fitting() -> void:
	check(Beams.create(items(),[95])==null,"A ship without beams got a beam owner")
	var both: RefCounted=Beams.create(items(),[208,222])
	check(both!=null and both.beams.size()==2,"Repair and transfusion beams were not both fitted")
	if both==null:return
	var repair: Dictionary=both.beams[0];var transfusion: Dictionary=both.beams[1]
	check(repair.sort==37 and repair.slots.size()==3 and repair.range==60000 and repair.rate==100 and repair.sound_id==2272 and repair.model_id==19092,"Item 208 read wrong: %s"%str(repair))
	check(transfusion.sort==41 and transfusion.slots.size()==1 and transfusion.range==20000 and transfusion.rate==50 and transfusion.sound_id==2267 and transfusion.model_id==19093,"Item 222 read wrong: %s"%str(transfusion))
	var fitting:=preload("res://src/simulation/equipment_fitting.gd").new()
	var reason: String=fitting._item_reason(bindings,catalogues,null,207,[207],0)
	check(reason.is_empty(),"The repair beam cannot be fitted: "+reason)
	reason=fitting._item_reason(bindings,catalogues,null,223,[223],0)
	check(reason.is_empty(),"The transfusion beam cannot be fitted: "+reason)

func verify_repair() -> void:
	var owner: RefCounted=Beams.create(items(),[207])
	var rows:=[row("npc:0",Vector3(0,0,20000),50,100,true),row("npc:1",Vector3(0,0,1000),100,100,true),row("npc:2",Vector3(0,0,1000),10,100,false,true),row("npc:3",Vector3(0,0,5000),40,100,true)]
	var before: Dictionary=run_for(owner,2500,Vector3.ZERO,player(),rows)
	check(before.heal.is_empty() and owner.beams[0].slots==[null],"A repair beam fired before its first 2.5 s scan")
	owner.advance(10,Vector3.ZERO,player(),rows)
	check(owner.beams[0].slots==["npc:3"] and owner.active(),"The repair beam did not pick the damaged friendly in range: %s"%str(owner.beams[0].slots))
	# Item 207: 60 * 0.03% per ms = 18 hull per second.
	var healed: Dictionary=run_for(owner,1000,Vector3.ZERO,player(),rows)
	check(healed.heal.keys()==["npc:3"] and int(healed.heal["npc:3"]) in [17,18],"Repair rate is not 18 hull/s: %s"%str(healed.heal))
	# The ship is repaired; the next scan (2.5 s after the first) drops it.
	rows[3].hull=100
	run_for(owner,1480,Vector3.ZERO,player(),rows)
	check(owner.beams[0].slots==["npc:3"],"The beam retargeted before 2.5 s")
	run_for(owner,20,Vector3.ZERO,player(),rows)
	check(owner.beams[0].slots==[null] and not owner.active(),"The 2.5 s retarget kept a repaired ship")
	rows[3].hull=40;run_for(owner,2500,Vector3.ZERO,player(),rows)
	check(owner.beams[0].slots==["npc:3"],"The beam did not pick the ship up again on the next scan")
	owner.advance(10,Vector3.ZERO,player(100.0,false),rows)
	check(not owner.active(),"The beam stayed on with the player dead")

func verify_replacement() -> void:
	var owner: RefCounted=Beams.create(items(),[208])
	var rows:=[row("npc:0",Vector3.ZERO,100,500,true),row("npc:1",Vector3.ZERO,200,500,true),row("npc:2",Vector3.ZERO,300,500,true),row("npc:3",Vector3.ZERO,150,500,true),row("npc:4",Vector3.ZERO,400,500,true)]
	run_for(owner,2510,Vector3.ZERO,player(),rows)
	var picked: Array=owner.beams[0].slots.duplicate();picked.sort()
	# The 150 ship replaces the slot with the next-higher hull (200), not the highest.
	check(picked==["npc:0","npc:2","npc:3"],"A full beam did not swap in a more damaged ship as the original does: %s"%str(picked))

func verify_transfusion() -> void:
	var owner: RefCounted=Beams.create(items(),[222])
	var rows:=[row("npc:0",Vector3(0,0,5000),500,500,false,true,true),row("npc:1",Vector3(0,0,8000),500,500,false,true),row("npc:2",Vector3(0,0,1000),500,500,true)]
	run_for(owner,2510,Vector3.ZERO,player(100.0),rows)
	check(owner.beams[0].slots==[null],"Transfusion locked on with a full shield")
	var facts:=player(10.0)
	run_for(owner,2500,Vector3.ZERO,facts,rows)
	check(owner.beams[0].slots==["npc:1"],"Transfusion did not pick the visible hostile: %s"%str(owner.beams[0].slots))
	# Item 222: 50 * 0.01% per ms = 5 points per second, into shield and out of hull.
	var drained: Dictionary=run_for(owner,1000,Vector3.ZERO,facts,rows)
	check(absf(drained.shield-5.0)<0.05 and int(drained.drain.get("npc:1",0)) in [4,5],"Transfusion did not move 5 points/s: %s"%str(drained))
	var full: Dictionary=run_for(owner,500,Vector3.ZERO,player(100.0),rows)
	check(full.drain.is_empty() and full.shield==0.0 and owner.active(),"Transfusion drained with a full shield or dropped its beam early")

func verify_flight() -> void:
	var pilot:=FakePlayer.new();pilot.owner=Beams.create(items(),[207,222])
	var encounter:=FakeEncounter.new()
	encounter.bodies=[{"actor_id":4,"pose":Transform3D(Basis.IDENTITY,Vector3(0,0,3000)),"active":true,"actor_mode":0,"max_hull":200,"vitals":{"hull":100},"friendly":true,"hostile":false},
		{"actor_id":7,"pose":Transform3D(Basis.IDENTITY,Vector3(0,0,-3000)),"active":true,"actor_mode":0,"max_hull":300,"vitals":{"hull":300},"friendly":false,"hostile":true}]
	for i in 351:Beams.advance_flight(pilot,Transform3D.IDENTITY,encounter,null,10)
	check(encounter.bodies[0].vitals.hull>=117 and encounter.bodies[0].vitals.hull<=119,"Flight repair did not heal the friendly: %d"%encounter.bodies[0].vitals.hull)
	check(encounter.bodies[1].vitals.hull<=296 and absf(pilot.state.vitals.shield-15.0)<0.1,"Flight transfusion did not drain into the shield: %d, %.2f"%[encounter.bodies[1].vitals.hull,pilot.state.vitals.shield])
	var lines: Array=pilot.owner.snapshot().beams[0].lines
	check(lines.size()==1 and lines[0].to==Vector3(0,0,3000),"The beam line does not end at its target")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
