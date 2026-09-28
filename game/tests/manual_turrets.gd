extends "res://tests/ship_exchange.gd"
## Detached catalogue loadouts exercise mount behavior; earned purchases are
## covered by the application pilot, never by these diagnostic inventories.
const Loadout=preload("res://src/simulation/opening_loadout.gd")
const Primary=preload("res://src/simulation/primary_weapons.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Fitting=preload("res://src/simulation/equipment_fitting.gd")
const Hits=preload("res://src/simulation/ordinary_weapon_hit.gd")
const TurretGeometry=preload("res://src/presentation/manual_turret_geometry.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Flight=preload("res://src/simulation/first_flight_frame.gd")
const Mission=preload("res://src/simulation/mission_flight_frame.gd")
const Selected=preload("res://src/simulation/selected40_flight_frame.gd")

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library) or not visuals.open(args[2],library.manifest):check(false,library.error+bindings.error+cat.error+visuals.error);return
	var fitting:=Fitting.new();var assets:=fitting.prepare_assets(bindings,cat,library)
	if assets.is_empty():check(false,fitting.error);return
	var mounts:=Mounts.new();var resolver:=Weapons.new()
	if not mounts.open(library,cat) or not resolver.configure(bindings,cat,bindings.base_content_id):check(false,mounts.error+resolver.error);return
	var modifier: int=cat.tables.items.filter(func(item):return item.arrays[2][5]==int(bindings.weapon_parameters.modifier_type))[0].id
	var tested:=[]
	for ship in cat.tables.ships:
		if not Context.base_player_hull(bindings,ship.id):continue
		for id in [47,48,49]:
			var loadout:=Loadout.new()
			var items:=[{"item_id":id,"slot":0,"quantity":1}]
			if ship.stats.primary_slots>0:items.append({"item_id":2,"slot":0,"quantity":1})
			if ship.stats.primary_slots>1:items.append({"item_id":3,"slot":1,"quantity":1})
			var assembled:=loadout.assemble({"ship_id":ship.id,"station_id":10,"equipment":items,"item_category_value_index":3},cat,bindings.base_content_id,bindings.binding_id)
			if ship.stats.turret_slots==0:
				check(not assembled,"A hull without a turret slot accepted one");continue
			if not assembled:check(false,loadout.error);return
			var owned:=loadout.snapshot();owned.campaign_cursor=24
			var inspected:=fitting.inspect(bindings,cat,owned,assets)
			check(not inspected.is_empty() and inspected.support[id].is_empty(),"Turret fitting refused hull %d: %s"%[ship.id,fitting.error])
			var weapon:=resolver.resolve(id,[]);var enhanced:=resolver.resolve(id,[modifier])
			check(weapon.damage==enhanced.damage and weapon.interval_ms==enhanced.interval_ms and enhanced.interval_multiplier==1.0,"Primary upgrades altered a turret")
			check(Hits.validate(weapon,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id},bindings.weapon_parameters.ordinary_hit_policy,[8]).is_empty(),"Turret damage cannot reach ordinary targets")
			var guns:=Primary.new()
			if not guns.configure(bindings,cat,mounts,owned):check(false,guns.error);return
			var initial:=guns.snapshot()
			check(initial.guns.filter(func(gun):return gun.equipment.category==2)[0].audio.enabled,"A full primary rack muted the turret")
			guns.advance(400)
			var forward:=guns.fire(Transform3D.IDENTITY,true)
			check(not forward.is_empty() and forward.weapons.filter(func(row):return row.item_id==id)[0].result.fired==false,"Turret fired outside its view")
			var branch: RefCounted=guns.fork_state();var before:=guns.snapshot()
			branch.set_turret_active(true);branch.advance_turret(Vector2(0,-1),100)
			check(guns.snapshot()==before,"Turret steering wrote into a frozen frame")
			var camera: Transform3D=branch.turret_camera(Transform3D.IDENTITY)
			var aim: Transform3D=branch.aim_pose(Transform3D.IDENTITY)
			check((-camera.basis.z).dot(aim.basis.z)>0.999 and not camera.origin.is_equal_approx(Vector3.ZERO),"Mounted camera faces away from the barrel")
			var fired: Dictionary=branch.fire(Transform3D.IDENTITY,true)
			if fired.is_empty():check(false,branch.error);return
			check(fired.weapons.all(func(row):return row.result.fired==(row.item_id==id)),"Turret mode fired forward guns or omitted its own shot")
			var shot: Dictionary=fired.weapons.filter(func(row):return row.item_id==id)[0].result.projectile
			check(shot.velocity.normalized().dot(aim.basis.z)>0.999 and shot.has("up"),"Turret shot lost its barrel direction or up axis")
			var local: Vector3=aim.affine_inverse()*shot.position
			check(absf(local.z-300)<0.01 and absf(local.y)<0.01,"Turret projectile did not leave the muzzle")
			branch.advance(400)
			var second: Dictionary=branch.fire(Transform3D.IDENTITY,true).weapons.filter(func(row):return row.item_id==id)[0].result.projectile
			var next_local: Vector3=aim.affine_inverse()*second.position
			check((local.x*next_local.x<0 and absf(local.x)>79) if id==48 else absf(next_local.x)<0.01,"Single/twin barrel selection is wrong")
			check(branch.snapshot().loadout==initial.loadout,"Firing consumed turret ownership")
			branch.advance_turret(Vector2(-1,0),10000)
			var up: Dictionary=branch.turret_state();branch.advance_turret(Vector2(-1,0),100)
			check(branch.turret_state().pitch==up.pitch,"Turret pitched through its elevation stop")
			branch.advance_turret(Vector2(1,0),10000)
			var down: Dictionary=branch.turret_state();branch.advance_turret(Vector2(1,0),100)
			check(branch.turret_state().pitch==down.pitch and down.pitch>up.pitch,"Turret pitched through its depression stop")
			branch.advance_turret(Vector2(-1,0),10000,true)
			check(branch.turret_state().pitch<up.pitch and branch.turret_state().camera_pitch<up.camera_pitch,"Inverted steering lost its wider pitch travel")
			var steady: RefCounted=guns.fork_state();steady.set_turret_active(true)
			steady.advance_turret(Vector2(-0.1,0.5),1000)
			for pattern in [[100],[7,7,6,7,7,7],[9,37,11,24]]:
				var timed: RefCounted=guns.fork_state();timed.set_turret_active(true)
				var elapsed:=0;var frame:=0
				while elapsed<1000:
					var delta:=mini(int(pattern[frame%pattern.size()]),1000-elapsed)
					timed.advance_turret(Vector2(-0.1,0.5),delta);elapsed+=delta;frame+=1
				check(timed.aim_pose(Transform3D.IDENTITY).is_equal_approx(steady.aim_pose(Transform3D.IDENTITY)),"Turret steering changed with frame cadence")
			if ship.id==23:
				var geometry:=TurretGeometry.new();root.add_child(geometry)
				check(geometry.build(branch.turret_state(),library,visuals,bindings),geometry.error)
				geometry.free()
			tested.append([ship.id,id])
	check(tested.size()==27,"The base turret/mount matrix is incomplete")
	print("Manual turret hulls/items: ",tested)
