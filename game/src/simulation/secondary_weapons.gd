extends RefCounted
## Equipped secondary ownership. Prospective operations commit ammunition,
## retained projectiles and target damage together.
const Definitions=preload("res://src/content/secondary_ownership_definitions.gd")
const Loadout=preload("res://src/simulation/equipment_slots.gd")
const Bomb=preload("res://src/simulation/emp_bombs.gd")
const Detonation=preload("res://src/simulation/emp_detonation.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Audio=preload("res://src/simulation/weapon_audio.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Projectiles=preload("res://src/simulation/ordinary_projectiles.gd")
const Conventional=preload("res://src/content/conventional_secondary_definitions.gd")
const Contacts=preload("res://src/simulation/ordinary_opening_contacts.gd")
const NpcContacts=preload("res://src/simulation/ordinary_npc_contacts.gd")
const Playback=preload("res://src/simulation/model_playback.gd")
var error:=""
var _initial_loadout:={}
var _loadout:={}
var _guns:=[]
var _launches:=0
var _detonation_events: Array[Dictionary]=[]
var _camera_commands: Array[Dictionary]=[]
var _presentation_identity: RefCounted

func configure(bindings: RefCounted,cat: RefCounted,loadout: Dictionary,mounts: RefCounted=null) -> bool:
	error=""
	if not Definitions.available(bindings):return reject("This content has no supported secondary ownership")
	var checked:=Loadout.checked_slots(bindings,cat,loadout)
	if checked.is_empty():return reject("Secondary ownership requires matching catalogue slots and equipment order")
	var weapons: Array=checked.categories[int(Definitions.VALUES.category)].duplicate(true)
	weapons.reverse()
	var guns:=[];var seen:={}
	var resolver:=Weapons.new()
	if not resolver.configure(bindings,cat,bindings.base_content_id):return reject(resolver.error)
	for entry in weapons:
		if entry.quantity<1 or seen.has(entry.item_id):return reject("This installed secondary has an invalid ammunition stack")
		var index: int=int(checked.counts[0])+entry.slot
		var gun:={"slot_index":index,"equipment":entry.duplicate(true),"ammunition":entry.quantity}
		if entry.item_id in Definitions.VALUES.item_ids:
			var bomb:=Bomb.new()
			var muzzle:=Vector3(0,0,400)
			if mounts!=null:
				if not is_instance_of(mounts,load("res://src/content/weapon_mounts.gd")):return reject("Bomb launchers require the ship's authored mounts")
				gun.mount=mounts.resolve(int(checked.ship_id),1,int(entry.slot))
				if gun.mount.is_empty():return reject(mounts.error)
				muzzle=gun.mount.position+Vector3(0,0,100)
			if not bomb.configure(bindings,cat,entry.item_id,checked.equipment_ids,muzzle):return reject(bomb.error)
			gun.bomb=bomb
			gun.audio={"enabled":true,"source_id":int(Definitions.VALUES.launch_audio.event_ids[Definitions.VALUES.item_ids.find(entry.item_id)]),"pitch_raw":float(Definitions.VALUES.launch_audio.pitch_raw)}
		else:
			var weapon:=resolver.resolve(entry.item_id,checked.equipment_ids)
			if not Conventional.resolved(weapon):return reject("This installed secondary has no supported launch declaration")
			if loadout.has("campaign_cursor"):weapon.campaign_cursor=loadout.campaign_cursor
			if not is_instance_of(mounts,load("res://src/content/weapon_mounts.gd")):return reject("Conventional launchers require the ship's authored mounts")
			gun.mount=mounts.resolve(int(checked.ship_id),1,int(entry.slot))
			gun.projectiles=Projectiles.new()
			if gun.mount.is_empty() or not gun.projectiles.configure(weapon):return reject(mounts.error+gun.projectiles.error)
			gun.audio={"enabled":true,"source_id":int(bindings.weapon_parameters.audio.player_event_ids[entry.item_id]),"pitch_raw":0.0}
		guns.append(gun)
		seen[entry.item_id]=true
	_initial_loadout=loadout.duplicate(true);_loadout=loadout.duplicate(true);_guns=guns;_launches=0;_detonation_events=[];_camera_commands=[]
	_presentation_identity=RefCounted.new()
	return true

## Install original burst resources before the first launch. Detached physics
## callers may omit presentation; actual effect callers must prepare it explicitly.
func configure_detonations(resources: RefCounted) -> bool:
	error=""
	if _loadout.is_empty() or not has_bombs() or _launches!=0 or has_detonations() or not resources is Detonation.Resources:return reject("Prepare EMP bursts once, before launching")
	var data: Dictionary=resources.snapshot()
	for key in ["base_content_id","binding_id"]:
		if data.get(key)!=_loadout[key]:return reject("EMP burst resources belong to another weapon owner")
	var prepared:={}
	for gun in _guns:
		if not gun.has("bomb"):continue
		var burst:=Detonation.new()
		if not burst.configure(resources,int(gun.equipment.item_id)):return reject(burst.error)
		prepared[gun.slot_index]=burst
	for gun in _guns:
		if prepared.has(gun.slot_index):gun.detonation=prepared[gun.slot_index]
	return true

func has_bombs() -> bool:return _guns.any(func(gun):return gun.has("bomb"))

func configure_projectile_visuals(library: RefCounted,bindings: RefCounted) -> bool:
	error=""
	if _loadout.is_empty() or _launches!=0:return reject("Prepare projectile models before the first secondary launch")
	for key in ["base_content_id","binding_id"]:
		if _loadout.get(key)!=bindings.get(key):return reject("Secondary models belong to another content identity")
	var prepared:={}
	for gun in _guns:
		if not gun.has("projectiles"):continue
		if gun.has("visuals"):return reject("Secondary model clocks were already prepared")
		var visual:=Conventional.presentation(library,bindings,gun.projectiles.snapshot().weapon)
		if visual.is_empty():return reject("Conventional launcher has unsupported original body or attachment animation")
		prepared[gun.slot_index]=visual
	for gun in _guns:
		if prepared.has(gun.slot_index):gun.visuals=prepared[gun.slot_index]
	return true

func has_detonations() -> bool:
	return has_bombs() and _guns.all(func(gun):return not gun.has("bomb") or gun.has("detonation"))

func detonation_owner(slot_index: int) -> RefCounted:
	for gun in _guns:
		if gun.slot_index==slot_index:return gun.get("detonation")
	return null

func evaluate_trigger(pose: Variant,selected_item_id: Variant,combat: RefCounted,ordered_actor_ids: Variant,permitted: Variant=true) -> Dictionary:
	error=""
	var targets:=_targets(combat,ordered_actor_ids)
	if not error.is_empty():return {}
	if not Flight.rigid_pose(pose) or not permitted is bool or not selected_item_id is int or (selected_item_id!=-1 and not _guns.any(func(gun):return gun.equipment.item_id==selected_item_id)):return fail("Invalid selected secondary or firing context")
	var next:=fork();var group: RefCounted=combat.fork_for_frame();var events:=[];var exhausted:=false
	if permitted:
		for gun in next._guns:
			var before: Dictionary=gun.bomb.snapshot() if gun.has("bomb") else gun.projectiles.snapshot()
			var flying: bool=before.get("shot",{}).get("phase")=="flying"
			if not flying and gun.equipment.item_id!=selected_item_id:continue
			var event: Dictionary
			if gun.has("bomb"):
				event=gun.bomb.trigger(pose,gun.ammunition,targets,true)
				if event.is_empty():return fail(gun.bomb.error)
			else:
				var shot: Dictionary=gun.projectiles.fire_forward_from_mount(gun.mount,pose,gun.ammunition>0)
				if shot.is_empty():return fail(gun.projectiles.error)
				event={"action":"launched","ammunition_consumed":1,"shot":shot.projectile} if shot.fired else {"action":"none"}
			if event.action=="none":
				if gun.ammunition==0 and before.elapsed_ms>before.weapon.interval_ms:exhausted=true
				continue
			var committed: Dictionary=next._apply_event(gun,event,group,pose.origin)
			if committed.is_empty():return fail(next.error)
			events.append(committed)
			if event.action=="launched":break
	return {"owner":next,"combat":group,"events":events,"selection_exhausted":exhausted,"loadout":next._loadout.duplicate(true)}

## Live player input stages the pulse and every inventory view as one result.
## A rejected retained view discards the prospective launch and its combat hits.
func evaluate_player_trigger(pose: Variant,selected_item_id: Variant,combat: RefCounted,ordered_actor_ids: Variant,player: RefCounted,equipment: RefCounted,primaries: RefCounted,targets: RefCounted,input_enabled: Variant=true) -> Dictionary:
	error=""
	if not is_instance_of(player,load("res://src/simulation/opening_player_state.gd")) or not input_enabled is bool:return fail("Secondary firing requires an initialized player and input permission")
	var state: Dictionary=player.snapshot()
	if player.loadout()!=_loadout or not state.get("active") is bool or not state.get("vitals") is Dictionary or not Vitals.integer(state.vitals.get("hull")):return fail("Secondary firing lost its current player equipment or vitality")
	var operation:=evaluate_trigger(pose,selected_item_id,combat,ordered_actor_ids,input_enabled and state.active and state.vitals.hull>0)
	if operation.is_empty():return {}
	var retained: Dictionary=operation.owner.evaluate_retention(player,equipment,primaries,targets)
	if retained.is_empty():return fail(operation.owner.error)
	operation.merge(retained)
	return operation

func evaluate_advance(delta_ms: Variant,combat: RefCounted,ordered_actor_ids: Variant,observer_position: Variant=null,bodies: RefCounted=null,inventory: RefCounted=null,guidance_actor_id: int=-1) -> Dictionary:
	error=""
	var targets:=_targets(combat,ordered_actor_ids)
	if not error.is_empty():return {}
	if not Vitals.integer(delta_ms):return fail("Invalid secondary frame duration")
	var next:=fork();var group: RefCounted=combat.fork_for_frame();var events:=[]
	var field: RefCounted=bodies
	next._detonation_events.clear();next._camera_commands.clear()
	# Projectile wrappers update in creation order, independently of firing order.
	for index in range(next._guns.size()-1,-1,-1):
		var gun: Dictionary=next._guns[index]
		if gun.has("projectiles"):
			if gun.has("visuals"):Playback.advance([gun.visuals.attachment],int(delta_ms),true)
			var shots: Dictionary=gun.projectiles.snapshot()
			if gun.projectiles.has_retained_projectiles():
				var contacts: RefCounted=Contacts.new() if field!=null else NpcContacts.new()
				var result: Dictionary=contacts.evaluate(gun.projectiles,group,field,inventory) if field!=null else contacts.evaluate(gun.projectiles,group,ordered_actor_ids)
				if result.is_empty():return fail(contacts.error)
				gun.projectiles=result.projectiles;group=result.combat
				if field!=null:field=result.bodies
				for hit in result.contacts:
					if hit.get("projectile_continues",false):continue
					var projectile: Dictionary=shots.slots[hit.slot]
					var contact: Dictionary=hit.duplicate(true)
					contact.merge({"action":"impact","slot_index":gun.slot_index,"item_id":gun.equipment.item_id,"position":projectile.position,"audio":{},"ammunition_consumed":0})
					events.append(contact)
			var target: Variant=group.guidance_position(guidance_actor_id) if gun.projectiles.has_guidance() else null
			if gun.projectiles.advance(delta_ms,target).is_empty():return fail(gun.projectiles.error)
			continue
		var before: Dictionary=gun.bomb.snapshot()
		var event: Dictionary=gun.bomb.advance(delta_ms,targets)
		if event.is_empty():return fail(gun.bomb.error)
		if gun.has("detonation"):
			var burst: Dictionary=gun.detonation.advance(before,gun.bomb.snapshot(),delta_ms,observer_position)
			if burst.is_empty():return fail(gun.detonation.error)
			next._detonation_events.append_array(burst.audio)
			if not burst.camera.is_empty():
				var command: Dictionary=burst.camera.duplicate(true)
				command.slot_index=gun.slot_index;command.item_id=gun.equipment.item_id
				next._camera_commands.append(command)
		if event.action=="none":continue
		var committed: Dictionary=next._apply_event(gun,event,group,Vector3.ZERO)
		if committed.is_empty():return fail(next.error)
		events.append(committed)
	return {"owner":next,"combat":group,"bodies":field,"events":events,"loadout":next._loadout.duplicate(true)}

func evaluate_contact(slot_index: Variant,projectile_id: Variant,combat: RefCounted,ordered_actor_ids: Variant) -> Dictionary:
	error=""
	var targets:=_targets(combat,ordered_actor_ids)
	if not error.is_empty():return {}
	if not slot_index is int or not projectile_id is int:return fail("Invalid secondary contact handle")
	var next:=fork();var group: RefCounted=combat.fork_for_frame()
	for gun in next._guns:
		if gun.slot_index!=slot_index:continue
		if not gun.has("bomb"):return fail("Conventional contacts require their physical target pass")
		var event: Dictionary=gun.bomb.detonate(projectile_id,targets)
		if event.is_empty():return fail(gun.bomb.error)
		var committed: Dictionary=next._apply_event(gun,event,group,Vector3.ZERO)
		if committed.is_empty():return fail(next.error)
		return {"owner":next,"combat":group,"events":[committed],"loadout":next._loadout.duplicate(true)}
	return fail("Secondary contact names an unavailable launcher")

func _targets(combat: RefCounted,ordered_actor_ids: Variant) -> Array:
	if _loadout.is_empty() or not combat is Combat or not ordered_actor_ids is Array:reject("Secondary update requires its equipped owner and combat targets");return []
	var state: Dictionary=combat.snapshot()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if not _loadout.has(key) or state.get(key)!=_loadout[key]:reject("Secondary targets belong to another encounter");return []
	var targets:=[];var seen:={}
	for id in ordered_actor_ids:
		if not id is int or id<0 or id>=state.actors.size() or seen.has(id):reject("Secondary target order names an unavailable or repeated actor");return []
		var actor: Dictionary=state.actors[id]
		if not actor.get("scenery") is bool or not actor.get("active") is bool or not actor.get("position") is Vector3 or not actor.position.is_finite():reject("Secondary target lacks current classification and position");return []
		targets.append({"actor_id":id,"position":actor.position,"active":actor.active,"emp_immune":actor.scenery})
		seen[id]=true
	return targets

func _apply_event(gun: Dictionary,event: Dictionary,combat: RefCounted,origin: Vector3) -> Dictionary:
	var result:=event.duplicate(true)
	result.slot_index=gun.slot_index;result.item_id=gun.equipment.item_id;result.audio={};result.systems_hits=[]
	if event.action=="launched":
		if gun.ammunition<event.ammunition_consumed or _launches>=Vitals.MAX_INTEGER:return fail("Secondary launch exceeds retained ammunition or handle range")
		gun.ammunition-=event.ammunition_consumed;_launches+=1
		if gun.ammunition==0:_loadout.slots[gun.slot_index]=null
		else:_loadout.slots[gun.slot_index].quantity=gun.ammunition
		_loadout.equipment_ids=[]
		for slot in _loadout.slots:
			if slot!=null:_loadout.equipment_ids.append(slot.item_id)
		if gun.has("detonation") and not gun.detonation.begin_projectile(event.shot):return fail(gun.detonation.error)
		result.audio=Audio.cue(gun.audio,origin)
	elif event.action=="detonated":
		for hit in event.blast.hits:
			var applied: Dictionary=combat.systems_hit(hit.actor_id,hit.system_damage,false)
			if applied.is_empty():return fail(combat.error)
			result.systems_hits.append({"actor_id":hit.actor_id,"damage":hit.system_damage,"result":applied})
	return result

## Only the actual launcher history may reduce an existing equipped stack. The
## caller retains all other inventory fields and publishes this with the frame.
func reconcile_loadout(prior: Dictionary) -> Dictionary:
	error=""
	if _initial_loadout.is_empty():return fail("Secondary ownership is unconfigured")
	if prior.has("campaign_cursor") and prior.campaign_cursor!=_initial_loadout.get("campaign_cursor"):return fail("Secondary consumption belongs to another encounter")
	var expected:=_initial_loadout.duplicate(true);var actual:=prior.duplicate(true)
	if not actual.get("slots") is Array:return fail("Secondary consumption lost its ordered slots")
	var ids:=[]
	for entry in actual.slots:
		if entry==null:continue
		if not entry is Dictionary or not entry.get("item_id") is int:return fail("Secondary consumption lost an installed item")
		ids.append(entry.item_id)
	if actual.get("equipment_ids")!=ids:return fail("Secondary consumption lost installed equipment order")
	# Career equipment omits the encounter cursor carried by flight owners.
	expected.erase("campaign_cursor");actual.erase("campaign_cursor")
	for gun in _guns:
		var old: Variant=actual.get("slots",[])[gun.slot_index] if actual.get("slots") is Array and gun.slot_index<actual.slots.size() else false
		if old==null:
			if gun.ammunition!=0:return fail("Equipped ammo disappeared before its actual launch")
		elif not old is Dictionary or not Vitals.integer(old.get("quantity")) or old.quantity<1 or old.quantity<gun.ammunition or old.quantity>gun.equipment.quantity:return fail("Equipped ammo differs from retained secondary consumption")
		else:
			var normalized: Dictionary=old.duplicate();normalized.quantity=gun.equipment.quantity
			if normalized!=gun.equipment:return fail("Secondary consumption changed an equipment identity")
		actual.slots[gun.slot_index]=gun.equipment.duplicate(true)
	actual.equipment_ids=expected.equipment_ids.duplicate()
	if actual!=expected:return fail("Secondary consumption changed unrelated equipment or location")
	var result:=_loadout.duplicate(true)
	if not prior.has("campaign_cursor"):result.erase("campaign_cursor")
	return result

## Primary contacts retain a canonical loadout without station metadata. Check
## that exact projection against the same launcher history, never a new loadout.
func reconcile_weapon_loadout(prior: Dictionary) -> Dictionary:
	error=""
	var keys:=["base_content_id","binding_id","ship_id","slots","equipment_ids"]
	if prior.size()!=keys.size()+int(prior.has("campaign_cursor")):return fail("Weapon ownership lost its canonical loadout")
	for key in keys:
		if not prior.has(key):return fail("Weapon ownership lost its canonical loadout")
	if _initial_loadout.is_empty():return fail("Secondary ownership is unconfigured")
	var complete:=_initial_loadout.duplicate(true)
	for key in prior:complete[key]=prior[key]
	var result:=reconcile_loadout(complete)
	if result.is_empty():return {}
	for key in result.keys():
		if not prior.has(key):result.erase(key)
	return result

## Prepare every retained flight view before publishing any ammunition change.
## The caller commits these forks with the accepted combat and presentation frame.
func evaluate_retention(player: RefCounted,equipment: RefCounted,primaries: RefCounted,targets: RefCounted) -> Dictionary:
	error=""
	if not is_instance_of(player,load("res://src/simulation/opening_player_state.gd")) or not is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")) or not is_instance_of(primaries,load("res://src/simulation/primary_weapons.gd")) or not is_instance_of(targets,load("res://src/simulation/opening_target_inventory.gd")):return fail("Secondary retention requires the native player, equipment, weapons and targets")
	var prior: Dictionary=player.loadout()
	var held: Dictionary=prior.duplicate(true);held.erase("campaign_cursor")
	if held!=equipment.snapshot().get("loadout"):return fail("Player and retained inventory disagree before ammunition consumption")
	var primary: Dictionary=primaries.snapshot().get("loadout",{})
	if primary.is_empty() or not targets.validate_loadout(primary):return fail("Primary contacts lost their retained target loadout")
	for key in primary:
		if not prior.has(key) or primary[key]!=prior[key]:return fail("Primary contacts and player disagree before ammunition consumption")
	var retained_player: RefCounted=player.fork_for_frame()
	var retained_equipment: RefCounted=equipment.fork()
	var retained_primaries: RefCounted=primaries.fork_state()
	var retained_targets: RefCounted=targets.fork_for_frame()
	if not retained_player.retain_secondary_ammunition(self):return fail(retained_player.error)
	if not retained_equipment.retain_secondary_ammunition(self):return fail(retained_equipment.error)
	if not retained_primaries.retain_secondary_ammunition(self):return fail(retained_primaries.error)
	if not retained_targets.retain_secondary_ammunition(self):return fail(retained_targets.error)
	return {"player":retained_player,"equipment":retained_equipment,"primaries":retained_primaries,"targets":retained_targets}

## Native control feedback, not automatic selection. Preserve firing order:
## a successful launch ends the pass, so an earlier selected launcher can fire
## before a later live bomb. The display must not promise to detonate that bomb.
func selection_feedback(selected_item_id: int) -> Dictionary:
	error=""
	if _loadout.is_empty() or (selected_item_id!=-1 and not _guns.any(func(gun):return gun.equipment.item_id==selected_item_id)):return fail("Secondary feedback requires the current launcher selection")
	var weapons:=[];var actions:=[];var ended:=false
	for gun in _guns:
		var state: Dictionary=gun.bomb.snapshot() if gun.has("bomb") else gun.projectiles.snapshot()
		var flying: bool=state.get("shot",{}).get("phase")=="flying"
		var wait_ms: int=maxi(0,int(state.weapon.interval_ms)-int(state.elapsed_ms)+1)
		var action: String=gun.bomb.trigger_action(gun.ammunition) if gun.has("bomb") else ("launched" if gun.ammunition>0 and wait_ms==0 and state.available_slots>0 else "none")
		var count: int=int(flying) if gun.has("bomb") else state.slots.filter(func(slot):return slot!=null).size()
		weapons.append({"item_id":int(gun.equipment.item_id),"quantity":int(gun.ammunition),"slot_index":int(gun.slot_index),"live":flying,"in_flight":count,"wait_ms":wait_ms})
		if ended or (not flying and gun.equipment.item_id!=selected_item_id) or action=="none":continue
		actions.append({"item_id":int(gun.equipment.item_id),"action":action})
		ended=action=="launched"
	return {"base_content_id":_loadout.base_content_id,"binding_id":_loadout.binding_id,"selected_item_id":selected_item_id,"weapons":weapons,"actions":actions}

## A new flight revision may omit the weapon update while dialogue is modal.
## Clear only one-frame cues; effects, clocks and ammunition remain retained.
func clear_frame_cues() -> void:
	_detonation_events.clear();_camera_commands.clear()

## Wrapper updates write one shared camera field in creation order. The last
## write wins, including a retirement reset; amplitudes are not added or ranked.
## Only a positive camera update should request these three shared random draws.
## The supported ordinary view uses the original unscaled look-at perturbation.
func evaluate_camera(random_state: Dictionary) -> Dictionary:
	error=""
	if _loadout.is_empty():return fail("EMP camera sampling requires an initialized weapon owner")
	var random:=Random.new()
	if not random.restore(random_state):return fail(random.error)
	var offset:=Vector3.ZERO
	var prior_slot:=-1
	for command in _camera_commands:
		if not command.get("slot_index") is int or command.slot_index<=prior_slot:return fail("EMP camera commands lost wrapper creation order")
		var burst: RefCounted=detonation_owner(command.slot_index)
		if burst==null:return fail("EMP camera command lost its retained launcher")
		var retained: Dictionary=burst.snapshot()
		if command.get("item_id")!=retained.item_id or command.get("projectile_id")!=retained.projectile_id or command.get("strength")!=retained.camera.strength or command.get("spread")!=retained.camera.spread:return fail("EMP camera command differs from its retained burst")
		prior_slot=command.slot_index
	if not _camera_commands.is_empty():
		var command: Dictionary=_camera_commands.back()
		var strength: Variant=command.get("strength")
		var spread: Variant=command.get("spread")
		if not (strength is float or strength is int) or not is_finite(strength) or strength<0.0 or strength>1.0 or spread not in [0,Detonation.Resources.CAMERA_SPREAD] or (strength>0.0 and spread==0):return fail("EMP camera command has unsupported strength or spread")
		if strength>0.0:
			for axis in 3:offset[axis]=Vitals.single(float(random.next_int(2*int(spread))-int(spread))*float(strength))
	return {"offset":offset,"random_state":random.snapshot()}

func discard_flying() -> void:
	for gun in _guns:
		if gun.has("bomb"):gun.bomb.discard_flying()
		else:gun.projectiles.discard_flying()

func presentation_identity() -> RefCounted:return _presentation_identity

func snapshot() -> Dictionary:
	if _loadout.is_empty():return {}
	var guns:=[]
	for gun in _guns:
		var row:={"slot_index":gun.slot_index,"equipment":gun.equipment.duplicate(true),"ammunition":gun.ammunition,"audio":gun.audio.duplicate()}
		if gun.has("bomb"):row.bomb=gun.bomb.snapshot()
		else:row.projectiles=gun.projectiles.snapshot();row.mount=gun.mount.duplicate(true)
		if gun.has("detonation"):row.detonation=gun.detonation.snapshot()
		if gun.has("visuals"):row.visuals=gun.visuals.duplicate(true)
		guns.append(row)
	var state:={"initial_loadout":_initial_loadout.duplicate(true),"loadout":_loadout.duplicate(true),"launches":_launches,"guns":guns}
	if has_detonations():
		state.detonation_audio=_detonation_events.duplicate(true)
		state.detonation_camera=_camera_commands.duplicate(true)
	return state

func fork() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._initial_loadout=_initial_loadout.duplicate(true);next._loadout=_loadout.duplicate(true);next._launches=_launches
	next._presentation_identity=_presentation_identity;next._detonation_events=_detonation_events.duplicate(true);next._camera_commands=_camera_commands.duplicate(true)
	for gun in _guns:
		var copy: Dictionary=gun.duplicate();copy.equipment=gun.equipment.duplicate(true);copy.audio=gun.audio.duplicate()
		if gun.has("bomb"):copy.bomb=gun.bomb.fork()
		else:copy.projectiles=gun.projectiles.fork_state();copy.mount=gun.mount.duplicate(true)
		if gun.has("detonation"):copy.detonation=gun.detonation.fork()
		if gun.has("visuals"):copy.visuals=gun.visuals.duplicate(true)
		next._guns.append(copy)
	return next

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
