extends SceneTree
## Supernova gas clouds: the system's plasma colour and share, cloud count and
## placement, ion blasts turning a cloud into sparks, and spark pickup only in
## turret view after the delay, with a full hold losing them.
const Library=preload("res://src/content/library.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Clouds=preload("res://src/simulation/gas_clouds.gd")
const View=preload("res://src/presentation/gas_cloud_view.gd")
const FAR:=Vector3(1e7,0,0)
var checks:=0
var failures:=0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>=1:verify(args)
	else:check(false,"Expected the content pack")
	print("Gas clouds: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: Array) -> void:
	var lib:=Library.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not cat.open(lib):check(false,lib.error+cat.error);return
	var expected:={"Mido":[201,89],"Buntta":[203,100],"Eanya":[201,88],"Wolf-Reiser":[202,88],"Y'mirr":[204,84],"K'ontrr":[204,100],"Suteo":[203,83],"Herjaza":[],"Skavac":[],"Alda":[]}
	var ids:={}
	for system in cat.tables.systems:ids[String(system.name).strip_edges()]=int(system.id)
	for name in expected:
		check(ids.has(name),"No system named "+name)
		var got:=Clouds.plasma_type(cat,int(ids.get(name,-1)))
		var want: Array=expected[name]
		check(got.is_empty() if want.is_empty() else (got.get("item_id")==want[0] and got.get("percent")==want[1]),"%s plasma should be %s, got %s"%[name,str(want),str(got)])
	var mido:=int(ids.Mido)
	for seed_value in 40:
		var state:=Clouds.spawn(cat,mido,seed_value)
		var n: int=state.clouds.size()
		check(n>=3 and n<=6,"Mido cloud count %d outside 3..6"%n)
		check(state.clouds.all(func(c):return c.position.length()>25000.0 and absf(c.position.x)<=80000 and absf(c.position.y)<=80000 and absf(c.position.z)<=80000 and c.item_id==201),"A cloud is too near the centre, outside the cube or the wrong colour")
		var mission:=Clouds.spawn(cat,mido,seed_value,3,Vector3(92000,0,36000))
		check(mission.clouds.size()>=6 and mission.clouds.size()<=9 and mission.clouds[0].position==Vector3(92000,0,36000),"Mission 142 clouds are wrong")
	check(Clouds.spawn(cat,int(ids.Herjaza),1).clouds.is_empty(),"Herjaza has clouds")
	check(Clouds.spawn(cat,mido,5)==Clouds.spawn(cat,mido,5),"The same seed gave different clouds")
	# Ionize one cloud at its centre.
	var state:=Clouds.spawn(cat,mido,7,3,Vector3(92000,0,36000))
	var ionized:=Clouds.ionize(state,Vector3(92000,0,36000),10000.0,11)
	check(not state.ionized and ionized.ionized and ionized.clouds[0].ionized and ionized.sparks.size()==70,"A centre blast should give 70 sparks: %d"%ionized.sparks.size())
	check(Clouds.ionize(ionized,Vector3(92000,0,36000),10000.0,12).sparks.size()==70,"A cloud ionized twice")
	check(Clouds.ionize(state,Vector3(92000,0,36000)+Vector3(5000,0,0),10000.0,11).sparks.size()==48,"A half-radius blast should give 48 sparks")
	# Sparks burst out of the cloud centre, away from the side the shot hit.
	var side: Array=Clouds.ionize(state,Vector3(92000,0,36000)+Vector3(5000,0,0),10000.0,11).sparks
	check(side.all(func(s):return s.position==Vector3(92000,0,36000)) and side.filter(func(s):return s.velocity.x<0.0).size()>side.size()/2,"Sparks should leave the cloud centre away from the blast")
	check(ionized.sparks.all(func(s):return s.velocity.length()>=20.99 and s.velocity.length()<=42.01 and s.life_ms>=8000 and s.life_ms<22000),"Spark speed or lifetime out of range")
	# Sparks age out.
	var aged: Dictionary=ionized
	for unused in 48:aged=Clouds.step(aged,500,FAR,false,Vector3.FORWARD,{},100).state
	check(aged.sparks.is_empty(),"Sparks outlived 22 s + fade")
	# Pickup only after 2 s and in turret view; a full hold loses them.
	var early:=Clouds.step(ionized,1,ionized.sparks[0].position,true,Vector3.FORWARD,{},100)
	check(early.picked.is_empty(),"A spark was taken before 2 s")
	var waited: Dictionary=Clouds.step(ionized,2000,FAR,false,Vector3.FORWARD,{},100).state
	var at: Vector3=waited.sparks[0].position
	var taken:=Clouds.step(waited,1,at,true,Vector3.FORWARD,{},100)
	var count:=int(taken.picked.get(201,0))
	check(count>=1 and taken.picked.size()==1 and taken.state.sparks.size()==waited.sparks.size()-count and taken.lost==0,"Turret view within 800 did not take plasma: %s"%str(taken.picked))
	check(Clouds.step(waited,1,at,false,Vector3.FORWARD,{},100).picked.is_empty(),"Plasma taken outside turret view")
	var full:=Clouds.step(waited,1,at,true,Vector3.FORWARD,{},0)
	check(full.picked.is_empty() and full.lost>=1,"A full hold kept the spark")
	check(int(taken.state.caught)==count and int(full.state.caught)==full.lost and Clouds.snapshot_for_view(taken.state).caught==count,"Caught sparks are not counted for the extractor sound")
	# Collector: a spark straight ahead is pulled at property 49 speed; one behind is not.
	var ahead:={"clouds":[],"ionized":true,"elapsed_ms":5000,"sparks":[{"position":Vector3(0,0,-20000),"velocity":Vector3(3,0,0),"base_speed":3.0,"age_ms":0,"life_ms":20000,"item_id":202,"ready_ms":2000}]}
	var collector:={"speed":26,"box":80,"range":40000}
	var pulled:=Clouds.step(ahead,10,Vector3.ZERO,true,Vector3.FORWARD,collector,10)
	check(is_equal_approx(pulled.state.sparks[0].position.z,-19740.0),"A collector did not pull the spark in view")
	check(int(pulled.state.pulling)==1 and int(Clouds.step(ahead,10,Vector3.ZERO,true,Vector3.BACK,collector,10).state.pulling)==0,"The in-range crosshair does not follow sparks being pulled")
	check(is_equal_approx(Clouds.step(ahead,10,Vector3.ZERO,true,Vector3.BACK,collector,10).state.sparks[0].position.z,-20000.0),"A collector pulled a spark behind the view")
	# Outside turret view a fitted collector neither pulls nor takes sparks.
	var outside:=Clouds.step(ahead,10,Vector3.ZERO,false,Vector3.ZERO,collector,10)
	check(outside.picked.is_empty() and is_equal_approx(outside.state.sparks[0].position.z,-20000.0),"A collector worked outside turret view")
	var beside:=Clouds.step(waited,1,at,false,Vector3.ZERO,collector,100)
	check(beside.picked.is_empty(),"A collector took plasma outside turret view")
	var snap:=Clouds.snapshot_for_view(taken.state)
	check(snap.clouds.size()==taken.state.clouds.size() and snap.sparks.size()==taken.state.sparks.size(),"View snapshot is incomplete")
	if args.size()>=3:
		var bindings:=Bindings.new();var visuals:=Visuals.new()
		if not bindings.open(args[1],lib.manifest) or not visuals.open(args[2],lib.manifest):check(false,bindings.error+visuals.error);return
		var view:=View.new()
		check(view.build(lib,visuals,bindings),"Gas cloud view failed: "+view.error)
		if view.error.is_empty():
			view.present(snap)
			check(view.error.is_empty() and view.get_child_count()>=9,"Gas cloud view did not draw: "+view.error)
		view.free()
