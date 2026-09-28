extends RefCounted
## Resolve fitting against the same native owners used by flight. Unsupported
## devices keep an explicit reason; stock availability never grants behavior.
const Rules=preload("res://src/content/ordinary_fitting_definitions.gd")
const Stats=preload("res://src/simulation/equipment_stats.gd")
const Vehicle=preload("res://src/simulation/vehicle_response.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Projectiles=preload("res://src/simulation/ordinary_projectiles.gd")
const Hits=preload("res://src/simulation/ordinary_weapon_hit.gd")
const Audio=preload("res://src/simulation/weapon_audio.gd")
const Recharge=preload("res://src/simulation/shield_recharge.gd")
const Secondaries=preload("res://src/simulation/secondary_weapons.gd")
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")
const Materials=preload("res://src/presentation/material_library.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const AEM=preload("res://src/content/aem.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
const Tractor=preload("res://src/simulation/tractor_recovery.gd")
const NPCSystems=preload("res://src/content/npc_systems_definitions.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Conventional=preload("res://src/content/conventional_secondary_definitions.gd")
const ImpactSprites=preload("res://src/content/full_hold_particle_definitions.gd")
const Cloak=preload("res://src/simulation/player_cloak.gd")
const Booster=preload("res://src/simulation/player_booster.gd")
var error:=""

func prepare_assets(bindings: RefCounted,cat: RefCounted,library: RefCounted) -> Dictionary:
	error=""
	if not Rules.available(bindings) or library==null or cat==null or library.manifest.get("content_id")!=bindings.base_content_id or cat.content_id!=bindings.base_content_id:return fail("Fitting requires its original content assets")
	var resources:={};var items:={}
	var mounts:=Mounts.new()
	if not mounts.open(library,cat):return fail(mounts.error)
	var sounds=preload("res://src/content/audio_resources.gd").new()
	if not sounds.configure(library,bindings):return fail(sounds.error)
	for id in Booster.Definitions.SOUND_IDS:
		var clip: Dictionary=sounds.prepare(Booster.Definitions.SOUND_IDS[id])
		items[id]="" if not clip.is_empty() and not clip.has("unsupported") else "This booster's original sound is unavailable"
	var cloak_clip: Dictionary=sounds.prepare(Cloak.Definitions.SOUND_ID)
	var cloak_ready: bool=not cloak_clip.is_empty() and not cloak_clip.has("unsupported") and library.manifest.files.has(Cloak.Definitions.CLOAK_MAP)
	for id in [94,95,96]:items[id]="" if cloak_ready else "This cloak's original mask or sound is unavailable"
	for item in cat.tables.items:
		if item.arrays[2][3]!=0:continue
		var id:=int(item.id);var mapping:=Rules.primary(bindings.mido_travel.ordinary_fitting,id,int(item.arrays[2][5]))
		if mapping.is_empty():continue
		items[id]=""
		if mapping.has("thermal") and not preload("res://src/presentation/projectile_trail_geometry.gd").supported_material(bindings):items[id]="This weapon's trail atlas is unavailable"
		var model_keys:=["projectile_model_id","impact_model_id"]
		if mapping.has("muzzle_model_id"):model_keys.append("muzzle_model_id")
		for key in model_keys:
			var model: int=mapping[key]
			if not resources.has(model):
				var path: String=bindings.resolve(model,"mesh");var reader:=AEM.new()
				var decoded:=reader.decode(library.read_resource(path,AEM.MAX_BYTES))
				if decoded.is_empty():return fail("An original weapon model could not be read: "+path)
				var sampler:=Sampler.new()
				var supported: bool=decoded.surfaces.all(func(surface):return Surface.supported_surface(surface)) and sampler.configure(decoded.surfaces,key=="projectile_model_id")
				supported=supported and bindings.material_for_mesh(path,"high").get("render_type")==2
				resources[model]="" if supported else "This weapon's animated model is not yet supported"
			if not resources[model].is_empty():items[id]=resources[model]
	if Secondaries.Definitions.available(bindings):
		# Resolve each bomb through its shared declaration and actual body/burst
		# providers. Stock alone cannot admit unsupported animation or effects.
		var families:={}
		for item in cat.tables.items:
			if item.arrays[2][3]!=1:continue
			var id:=int(item.id);var declaration:=Secondaries.Bomb.Definitions.declaration(id)
			var mine: bool=not Secondaries.Mines.Definitions.declaration(id).is_empty()
			if mine:declaration=Secondaries.Mines.Definitions.declaration(id)
			if declaration.is_empty():continue
			var family: int=Secondaries.Mines.Definitions.effect_family(id) if mine else declaration.kind
			if not families.has(family):
				var bursts:=BurstResources.new()
				if not bursts.configure(library,bindings,family):return fail(bursts.error)
				families[family]=bursts
			var bomb: RefCounted=Secondaries.Mines.new() if mine else Secondaries.Bomb.new()
			var supported: bool=bomb.configure(bindings,cat,id,[]) and bomb.prepare_visuals(library,bindings)
			items[id]="" if supported else "This bomb's original body or glow is unavailable"
			if mine:
				for sound_id in [declaration.launch_sound,declaration.burst_sound]:
					var clip: Dictionary=sounds.prepare(sound_id)
					if clip.is_empty() or clip.has("unsupported"):items[id]="This mine's original sound is unavailable"
		var resolver:=Weapons.new()
		if not resolver.configure(bindings,cat,bindings.base_content_id):return fail(resolver.error)
		for item in cat.tables.items:
			if item.arrays[2][3]!=1 or Conventional.declaration(int(item.id),int(item.arrays[2][5])).is_empty():continue
			var weapon:=resolver.resolve(int(item.id),[])
			var prepared:=Conventional.presentation(library,bindings,weapon)
			var supported: bool=not prepared.is_empty() and Materials.supports(bindings.material_for_mesh(prepared.get("resource",""),"high"))
			supported=supported and preload("res://src/presentation/projectile_trail_geometry.gd").supported_material(bindings) and ImpactSprites.parameters(bindings.full_hold_particles)
			items[int(item.id)]="" if supported else "This secondary weapon's original effects are unavailable"
	if Tractor.Definitions.available(bindings):
		var rules: Dictionary=bindings.mido_travel.tractor_recovery
		for item in cat.tables.items:
			if item.arrays[2][3]!=3 or item.arrays[2][5]!=int(rules.equipment.category):continue
			var tractor:=Tractor.new()
			var loadout:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
				"ship_id":int(bindings.station_entry.ship_id),"equipment_ids":[int(item.id)]}
			items[int(item.id)]="" if tractor.configure(bindings,cat,loadout,library) else "This tractor's beam is not yet supported"
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"items":items,"mounts":mounts}

func inspect(bindings: RefCounted,cat: RefCounted,loadout: Dictionary,assets: Dictionary) -> Dictionary:
	error=""
	if not Rules.available(bindings) or cat==null or cat.content_id!=bindings.base_content_id or loadout.get("base_content_id")!=bindings.base_content_id or loadout.get("binding_id")!=bindings.binding_id:return fail("Fitting belongs to another content identity")
	if assets.get("base_content_id")!=bindings.base_content_id or assets.get("binding_id")!=bindings.binding_id or not assets.get("items") is Dictionary:return fail("Fitting lost its verified weapon assets")
	var ship: Variant=loadout.get("ship_id")
	if not Numbers.integer(ship,0,cat.tables.ships.size()-1):return fail("The equipped ship is absent from the catalogue")
	var weapon:=Weapons.new()
	if not weapon.configure(bindings,cat,bindings.base_content_id):return fail(weapon.error)
	var ids: Array=loadout.equipment_ids
	var support:={}
	for item in cat.tables.items:
		var id:=int(item.id)
		support[id]=_item_reason(bindings,cat,weapon,id,ids,int(ship))
		if support[id].is_empty() and item.arrays[2][3] in [0,1]:support[id]=assets.items.get(id,"This weapon's model is unavailable")
		if support[id].is_empty() and item.arrays[2][3]==3 and item.arrays[2][5]==13:support[id]=assets.items.get(id,"This tractor's beam is unavailable")
		if support[id].is_empty() and item.arrays[2][3]==3 and item.arrays[2][5]==14:support[id]=assets.items.get(id,"This booster's sound is unavailable")
		if support[id].is_empty() and item.arrays[2][3]==3 and item.arrays[2][5]==21:support[id]=assets.items.get(id,"This cloak's mask or sound is unavailable")
	for id in ids:
		if not support.has(id) or not support[id].is_empty():return fail("Installed equipment is unavailable: "+str(support.get(id,"unknown item")))
	var slots: Variant=loadout.get("slots")
	var secondary_slots: bool=slots is Array and slots.any(func(slot):return slot is Dictionary and slot.get("category")==1)
	if secondary_slots or ids.any(func(id):return cat.tables.items[id].arrays[2][3]==1):
		var secondaries:=Secondaries.new()
		if not secondaries.configure(bindings,cat,loadout,assets.get("mounts")):return fail(secondaries.error)
	var pools:=Stats.resolve_capacities(cat.tables.items,ids,bindings.opening_actors.player_initialization)
	var repair: Dictionary=bindings.opening_actors.player_initialization.repair
	var upgrades: Array=preload("res://src/simulation/ship_instance.gd").upgrades(loadout)
	var hull:=Stats.resolve_ship_hull(cat.tables.ships[ship].fields[int(repair.base_hull_field)],upgrades,repair)
	var device:=Stats.resolve_repair_device(cat.tables.items,ids,repair)
	var capacity:=Stats.cargo_capacity(bindings,cat,loadout)
	var passengers:=Stats.capacity_sum(cat,ids,int(Rules.VALUES.passenger_subtype),int(Rules.VALUES.passenger_property))
	var vehicle:=Vehicle.new()
	if not vehicle.configure(bindings,cat,bindings.base_content_id):return fail(vehicle.error)
	var handling:=vehicle.resolve(ship,upgrades,ids)
	if pools.is_empty() or hull<0 or device.is_empty() or capacity<0 or passengers<0 or handling.is_empty():return fail("Equipment produces unsupported ship capacities or handling")
	return {"support":support,"stats":{"hull":hull,"armor":pools.armor,"shield":pools.shield,
		"cargo_capacity":capacity,"passenger_capacity":passengers,"repair_mode":device.mode,
		"response_factor":handling.response_factor,"handling_bonus_percent":handling.equipment_percent}}

func _item_reason(bindings: RefCounted,cat: RefCounted,resolver: RefCounted,id: int,ids: Array,ship: int) -> String:
	var item: Dictionary=cat.tables.items[id]
	var category: int=item.arrays[2][3];var subtype: int=item.arrays[2][5]
	var properties: Dictionary=item.properties
	if category==0:
		var weapon: Dictionary=resolver.resolve(id,ids)
		if weapon.is_empty():return "This weapon's firing behavior is not yet supported"
		if weapon.get("ordinary_hit_policy",{}).get("additional_damage_required",false) and not NPCSystems.available(bindings):return "This weapon requires ship systems damage support"
		var projectiles:=Projectiles.new()
		if not projectiles.configure(weapon):return "This weapon's firing behavior is not yet supported"
		var reason:=Hits.validate(weapon,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id},bindings.weapon_parameters.ordinary_hit_policy,[int(weapon.kind)])
		if not reason.is_empty():return "This weapon's damage effects are not yet supported"
		if Rules.model(bindings,weapon,false).is_empty() or Rules.model(bindings,weapon,true).is_empty():return "This primary weapon's visual behavior is not yet supported"
		if Audio.player_entries(bindings.weapon_parameters.audio,cat.tables.items,[weapon]).size()!=1:return "This weapon's audio is not yet supported"
		return ""
	if category==1:
		if not Secondaries.Definitions.available(bindings):return "This secondary weapon's flight behavior is not yet supported"
		if not Secondaries.Mines.Definitions.declaration(id).is_empty():
			var mine:=Secondaries.Mines.new()
			return "" if mine.configure(bindings,cat,id,ids) and NPCSystems.available(bindings) else "This mine's firing or systems behavior is not yet supported"
		if not Secondaries.Bomb.Definitions.declaration(id).is_empty():
			var bomb:=Secondaries.Bomb.new()
			return "" if bomb.configure(bindings,cat,id,ids) else "This bomb's firing behavior is not yet supported"
		var weapon: Dictionary=resolver.resolve(id,ids)
		if not Conventional.resolved(weapon):return "This secondary weapon's flight behavior is not yet supported"
		if weapon.ordinary_hit_policy.additional_damage_required and not NPCSystems.available(bindings):return "This weapon requires ship systems damage support"
		var projectiles:=Projectiles.new()
		if not projectiles.configure(weapon):return "This secondary weapon's firing behavior is not yet supported"
		var reason:=Hits.validate(weapon,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id},bindings.weapon_parameters.ordinary_hit_policy,[int(weapon.kind)])
		return "" if reason.is_empty() else "This secondary weapon's damage effects are not yet supported"
	if category!=3:return "Fitting this equipment is not yet supported"
	var rule: Dictionary=bindings.opening_actors.player_initialization
	match subtype:
		9:
			var pools:=Stats.resolve_capacities(cat.tables.items,[id],rule)
			if pools.is_empty():return "The shield has no supported capacity"
			var charge:=Recharge.new()
			var duration: Variant=properties.get(int(rule.recharge.equipment_property))
			if not Numbers.integer(duration,0,2147483647) or not charge.configure(rule.recharge,pools.shield,duration):return "The shield has no supported recharge duration"
		10:
			if Stats.resolve_capacities(cat.tables.items,[id],rule).is_empty():return "The armor has no supported capacity"
		12,20:
			var property:=int(Rules.VALUES.cargo_property if subtype==12 else Rules.VALUES.passenger_property)
			if not Numbers.integer(properties.get(property),0,2147483647):return "The equipment has no supported capacity"
		13:
			if not Tractor.Definitions.available(bindings):return "Tractor recovery is not yet supported by this content pack"
			var tractor: Dictionary=bindings.mido_travel.tractor_recovery
		14:
			var booster:=Booster.new()
			if not booster.configure(bindings,cat,[id]):return booster.error
			if not preload("res://src/simulation/player_engine_particles.gd").Definitions.available_for(bindings,ship):return "This ship's booster exhaust is unavailable"
		15:
			if Stats.resolve_repair_device(cat.tables.items,[id],rule.repair).is_empty():return "The repair device is unavailable"
		16:
			if not Numbers.integer(properties.get(int(bindings.vehicle_response.equipment_percent_property)),0,2147483647):return "The handling upgrade is unavailable"
		17:
			var scanner: Dictionary=bindings.opening_staging.npc_scanner
			if not Numbers.integer(properties.get(int(scanner.duration_property)),1,2147483647):return "The scanner acquisition duration is unavailable"
		19:
			for property in [bindings.mining_drill.stability_property,bindings.mining_drill.rate_property]:
				if not Numbers.integer(properties.get(int(property)),1,100000):return "The drill performance is unavailable"
		21:
			var cloak:=Cloak.new()
			if not cloak.configure(bindings,cat,[id],ship,0.5):return cloak.error
		28:
			for property in [bindings.weapon_parameters.interval_percent_property,bindings.weapon_parameters.damage_percent_property]:
				if not Weapons.signed_integer(properties.get(int(property))):return "The weapon modifier is unavailable"
		_:
			return "This device's flight behavior is not yet supported"
	return ""

func fail(message: String) -> Dictionary:error=message;return {}
