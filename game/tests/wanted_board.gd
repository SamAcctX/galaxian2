extends SceneTree
## Most Wanted boards on the imported list: the Terran board opens at 128 at
## Terran stations only, docking activates Pal Tyyrt alone, he travels one
## system per departure along his route, and giving up or dying ends him.
const Library=preload("res://src/content/library.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Wanted=preload("res://src/simulation/wanted_board.gd")
var checks:=0
var failures:=0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>=1:verify(args[0])
	else:check(false,"Expected the content pack")
	print("Wanted boards: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(content: String) -> void:
	var lib:=Library.new();var cat:=Catalogues.new()
	if not lib.open(content) or not cat.open(lib):check(false,lib.error+cat.error);return
	var table: Array=cat.tables.get("wanted",[])
	check(table.size()==25 and table[0].name=="Pal Tyyrt" and table[1].name=="Kehnor","The Most Wanted list was not read")
	if table.size()!=25:return
	var terran:=_station_of_race(cat,0);var midorian:=_station_of_race(cat,3)
	check(terran>=0 and midorian>=0,"No Terran or Midorian station")
	check(Wanted.accessible(table,cat,128,terran) and not Wanted.accessible(table,cat,127,terran) and not Wanted.accessible(table,cat,128,midorian),"The Terran board opens at the wrong cursor or race")
	var known:=[];known.resize(cat.tables.systems.size());known.fill(true)
	var state:=Wanted.fresh(table)
	var none: Dictionary=Wanted.activate(state,table,cat,128,midorian,known,7)
	check(none.activated.is_empty(),"A Midorian docking activated a Terran criminal")
	var docked: Dictionary=Wanted.activate(state,table,cat,128,terran,known,7)
	check(docked.activated==[0],"Docking at 128 should activate Pal Tyyrt alone: %s"%str(docked.activated))
	state=docked.state
	var entry: Dictionary=state.entries[0]
	var from:=Wanted.system_of(cat,int(entry.from));var to:=Wanted.system_of(cat,int(entry.to))
	var path:=Wanted._path(cat,known,from,to)
	check(from!=to and path.size()>=2 and path.size()<=4 and not Wanted.EXCLUDED_SYSTEMS.has(from) and not Wanted.EXCLUDED_SYSTEMS.has(to),"Pal Tyyrt's route is outside its bounds: %s"%str(path))
	check(path.has(Wanted.system_of(cat,int(entry.at))),"He does not start on his route")
	check(Wanted.criminal_at(state,int(entry.at))==0,"He is not met at his station")
	check(Wanted.activate(state,table,cat,129,terran,known,8).activated.is_empty(),"A story criminal activated after his cursor")
	# Departures: one system per step until he arrives, then a new route.
	var arrived:=false
	for step in 12:
		var before:=int(state.entries[0].at);var target:=int(state.entries[0].to)
		state=Wanted.travel(state,cat,-1,known,100+step)
		var after:=int(state.entries[0].at)
		var a:=Wanted.system_of(cat,before);var b:=Wanted.system_of(cat,after)
		check(a==b or cat.tables.systems[a].linked_system_ids.has(b),"He jumped more than one system")
		if before==target:
			arrived=true
			check(after==before and int(state.entries[0].from)==before and int(state.entries[0].to)!=before,"At his destination he did not pick a new one")
			break
	check(arrived,"He never reached his destination")
	var held:=Wanted.travel(state,cat,int(state.entries[0].at),known,99)
	check(int(held.entries[0].at)==int(state.entries[0].at),"He left the player's station")
	var gave_up:=Wanted.surrendered(state,0)
	check(not gave_up.entries[0].active and not gave_up.entries[0].dead and Wanted.criminal_at(gave_up,int(state.entries[0].at))<0,"A surrendered criminal stayed on the board")
	var dead:=Wanted.killed(state,0)
	check(dead.entries[0].dead and int(dead.bounties[0])==1,"A kill was not counted on the Terran board")
	check(Wanted.spawn_hull(state.entries[0].stats,0,128,false,0.5)==5512,"Normal difficulty hull at 128 should be 5000 + 4 x 128")

static func _station_of_race(cat: RefCounted,race: int) -> int:
	for system in cat.tables.systems:
		if int(system.fields[2])==race and not Wanted.EXCLUDED_SYSTEMS.has(int(system.id)) and not system.linked_system_ids.is_empty():return int(system.station_ids[0])
	return -1
