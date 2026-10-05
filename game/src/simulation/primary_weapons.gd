extends RefCounted
## Native ownership of forward guns and a manual turret for an owned loadout.
## Actor permission, world scheduling, target lists and consequences belong to
## the encounter owner. No unsupported primary is silently replaced or omitted.
const Turret=preload("res://src/simulation/manual_turret.gd")
const COLLECTOR_SORT:=35
const Projectiles = preload("res://src/simulation/ordinary_projectiles.gd")
const Weapons = preload("res://src/simulation/weapon_loadout.gd")
const Slots = preload("res://src/simulation/equipment_slots.gd")
const Vitals = preload("res://src/simulation/combat_vitals.gd")
const Library = preload("res://src/content/library.gd")
const Contacts = preload("res://src/simulation/ordinary_npc_contacts.gd")
const Combat = preload("res://src/simulation/opening_combat_group.gd")
const OpeningContacts = preload("res://src/simulation/ordinary_opening_contacts.gd")
const TargetInventory = preload("res://src/simulation/opening_target_inventory.gd")
const SceneryBodies = preload("res://src/simulation/scenery_bodies.gd")
const Audio = preload("res://src/simulation/weapon_audio.gd")
const Random = preload("res://src/simulation/seeded_random.gd")
var error := ""
var _turret: RefCounted
var _loadout := {}
var _guns: Array = []
var _next_mount_id := 1
var _selected40_context := {}
var _selected40_construction: RefCounted

func clear() -> void:
	error = ""
	_loadout = {};_turret=null
	_guns = []
	_selected40_context = {}
	_selected40_construction = null

func configure(bindings: RefCounted, catalogues: RefCounted, mounts: RefCounted, loadout: Dictionary,mission_context: RefCounted=null) -> bool:
	clear()
	var content_id: Variant = loadout.get("base_content_id")
	if not Library.valid_hash(content_id) or bindings == null or catalogues == null or mounts == null:
		return reject("Primary weapons require an explicit content loadout")
	if loadout.get("binding_id") != bindings.binding_id or mounts.snapshot().get("base_content_id") != content_id:
		return reject("Primary equipment, mounts and bindings have different identities")
	if mission_context!=null:
		if not is_instance_of(mission_context,load("res://src/simulation/mission_context.gd")) or not mission_context.matches_loadout(loadout):return reject("Primary equipment changed after mission entry")
		return _configure_loadout(bindings,catalogues,mounts,loadout)
	# This component constructs catalogue equipment; it cannot authorize a
	# journey. Gameplay passes the player prepared by the flight entry owner.
	if loadout.has("campaign_cursor") and not preload("res://src/content/opening_definitions.gd").integer(loadout.campaign_cursor,0,2147483647):return reject("Invalid primary observation cursor")
	return _configure_loadout(bindings,catalogues,mounts,loadout)

## Consume the player already prepared by the flight entry owner. This does
## not select a world or admit a new loadout.
func configure_player(bindings: RefCounted,catalogues: RefCounted,mounts: RefCounted,player: RefCounted,mission_context: RefCounted=null) -> bool:
	if not is_instance_of(player,load("res://src/simulation/opening_player_state.gd")) or player.snapshot().is_empty():return reject("Primary weapons require their initialized native player")
	var loadout: Dictionary=player.loadout()
	if mission_context!=null:return configure(bindings,catalogues,mounts,loadout,mission_context)
	clear()
	if bindings==null or catalogues==null or mounts==null or loadout.get("base_content_id")!=bindings.base_content_id or loadout.get("binding_id")!=bindings.binding_id or mounts.snapshot().get("base_content_id")!=bindings.base_content_id:return reject("Primary player and mounts belong to another content identity")
	return _configure_loadout(bindings,catalogues,mounts,loadout)

## Construct the retained player's actual guns without granting a selected
## world, target list or departure. The native player and generated cast must
## agree on the origin equipment; a loose cursor40 dictionary is insufficient.
func configure_selected40(bindings: RefCounted,catalogues: RefCounted,mounts: RefCounted,player: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not _loadout.is_empty():return reject("Selected40 primaries already retain live weapon state")
	if not is_instance_of(player,load("res://src/simulation/opening_player_state.gd")) or not is_instance_of(construction,load("res://src/simulation/opening_npc_construction.gd")):
		return reject("Selected40 primaries require their native retained player and cast")
	if not is_instance_of(mounts,load("res://src/content/weapon_mounts.gd")) or not is_instance_of(bindings,load("res://src/content/resource_bindings.gd")) or not is_instance_of(catalogues,load("res://src/content/catalogues.gd")):
		return reject("Selected40 primaries require native catalogue mounts and content")
	var equipment: Dictionary=player.loadout()
	if player.selected40_construction_owner()!=construction:return reject("Selected40 primary player belongs to another native constructor generation")
	var context: Dictionary=load("res://src/content/selected40_population_definitions.gd").retained_player_context(bindings,construction.snapshot(),equipment)
	var state: Dictionary=player.snapshot()
	if context.is_empty() or state.get("scope")!="selected40_retained_player_component" or state.get("selected40_context")!=context or not equipment.get("campaign_cursor") is int or equipment.campaign_cursor!=40:
		return reject("Selected40 primaries differ from their retained origin player")
	if mounts.snapshot().get("base_content_id")!=bindings.base_content_id:return reject("Selected40 mounts belong to another content identity")
	if not _configure_loadout(bindings,catalogues,mounts,equipment):return false
	_selected40_context=context.duplicate(true)
	_selected40_construction=construction
	return true

## Shared catalogue, mount, projectile and audio construction. Admission stays
## with the explicit entry methods above; this function never changes a career.
func _configure_loadout(bindings: RefCounted,catalogues: RefCounted,mounts: RefCounted,loadout: Dictionary) -> bool:
	var content_id: Variant=loadout.get("base_content_id")
	var resolver := Weapons.new()
	if not resolver.configure(bindings,catalogues,content_id): return reject(resolver.error)
	var checked:=Slots.checked_slots(bindings,catalogues,loadout)
	if checked.is_empty():return reject("Primary ownership requires matching catalogue slots and equipment order")
	var ship_id: int=checked.ship_id
	var slots: Array=checked.slots;var ordered_ids: Array=checked.equipment_ids
	var primary: Array=checked.categories[0]
	var items: Array=catalogues.tables.items
	# Source builds each category backwards while visiting installed slots forwards.
	# Empty slots stay absent; they do not shift the authored category-slot number.
	primary.reverse()
	var forward_count:=primary.size()
	# A plasma collector (sort 35) sits in the turret slot and gives turret
	# view but fires nothing; the flight's gas clouds own what it collects.
	for entry in checked.categories[2]:
		if int(items[entry.item_id].properties.get(2,-1))!=COLLECTOR_SORT:primary.append(entry);continue
		if _turret!=null:return reject("Only one manual turret mount is supported")
		var collector_mount: Dictionary=mounts.resolve(ship_id,2,entry.slot)
		if collector_mount.is_empty():return reject(mounts.error)
		_turret=Turret.new()
		if not _turret.configure(items[entry.item_id],collector_mount):return reject(_turret.error)
	var staged := []
	var resolved := []
	if _next_mount_id > 9223372036854775807 - primary.size(): return reject("Weapon handle limit exceeded")
	for equipment in primary:
		var weapon: Dictionary = resolver.resolve(equipment.item_id,ordered_ids)
		if weapon.is_empty(): return reject(resolver.error)
		if loadout.has("campaign_cursor"):weapon.campaign_cursor=loadout.campaign_cursor
		resolved.append(weapon)
		var mount: Dictionary = mounts.resolve(ship_id,int(equipment.category),equipment.slot)
		if mount.is_empty(): return reject(mounts.error)
		if equipment.category==2:
			if _turret!=null:return reject("Only one manual turret mount is supported")
			_turret=Turret.new()
			if not _turret.configure(items[equipment.item_id],mount):return reject(_turret.error)
		var projectiles := Projectiles.new()
		if not projectiles.configure(weapon): return reject(projectiles.error)
		# No contact result exists before the first pass. This native sentinel
		# does not assert an initialized source pointer before its verified reset.
		staged.append({"mount_id":_next_mount_id+staged.size(),"equipment":equipment,
			"mount":mount,"projectiles":projectiles,"contact_pass_evaluated":false,"last_contact_target":null,"audio":{}})
	var audio: Dictionary=bindings.weapon_parameters.get("audio",{})
	if not audio.is_empty():
		var entries := Audio.player_entries(audio,items,resolved.slice(0,forward_count))
		# The mounted weapon has its own sound, independent of the forward-gun
		# sound budget. Entering turret view must not mute a full primary rack.
		entries.append_array(Audio.player_entries(audio,items,resolved.slice(forward_count)))
		if entries.size()!=staged.size():return reject("Primary weapons lack supported sound selection")
		for i in staged.size():staged[i].audio=entries[i]
	_guns = staged
	_next_mount_id += staged.size()
	_loadout = {"base_content_id":content_id,"binding_id":bindings.binding_id,
		"ship_id":ship_id,"slots":slots.duplicate(true),"equipment_ids":ordered_ids}
	if loadout.has("campaign_cursor"):_loadout.campaign_cursor=loadout.campaign_cursor
	return true

func snapshot() -> Dictionary:
	if _loadout.is_empty(): return {}
	var guns := []
	for gun in _guns:
		guns.append({"mount_id":gun.mount_id,"equipment":gun.equipment.duplicate(true),
			"mount":gun.mount.duplicate(true),"projectiles":gun.projectiles.snapshot(),
			"audio":gun.audio.duplicate(),
			"contact_pass_evaluated":gun.contact_pass_evaluated,
			"last_contact_target":null if gun.last_contact_target==null else gun.last_contact_target.duplicate()})
	var result:={"loadout":_loadout.duplicate(true),"guns":guns}
	if _turret!=null:result.turret=_turret.snapshot()
	if not _selected40_context.is_empty():
		result.scope="selected40_retained_primary_component"
		result.selected40_context=_selected40_context.duplicate(true)
	return result

func fork_state() -> RefCounted:
	var staged: RefCounted = get_script().new()
	staged._loadout = _loadout.duplicate(true)
	staged._turret=null if _turret==null else _turret.fork()
	staged._next_mount_id = _next_mount_id
	staged._selected40_context = _selected40_context.duplicate(true)
	staged._selected40_construction = _selected40_construction
	for gun in _guns:
		staged._guns.append({"mount_id":gun.mount_id,"equipment":gun.equipment.duplicate(true),
			"mount":gun.mount.duplicate(true),"projectiles":gun.projectiles.fork_state(),
			"audio":gun.audio.duplicate(),
			"contact_pass_evaluated":gun.contact_pass_evaluated,
			"last_contact_target":null if gun.last_contact_target==null else gun.last_contact_target.duplicate()})
	return staged

## Primary guns and their in-flight projectiles survive secondary consumption.
## Only the canonical contact-validation loadout changes; firing state is kept.
func retain_secondary_ammunition(owner: RefCounted) -> bool:
	error=""
	if _loadout.is_empty() or not is_instance_of(owner,load("res://src/simulation/secondary_weapons.gd")):return reject("Primary ownership requires the actual secondary launch history")
	var next: Dictionary=owner.reconcile_weapon_loadout(_loadout)
	if next.is_empty():return reject(owner.error)
	_loadout=next
	return true

func reset_fire_intervals() -> bool:
	error=""
	if _loadout.is_empty():return reject("Configure primary ownership before resetting firing intervals")
	var next:=fork_state()
	for gun in next._guns:
		if not gun.projectiles.reset_fire_interval():return reject(gun.projectiles.error)
	_guns=next._guns
	return true

func discard_flying() -> void:
	for gun in _guns:gun.projectiles.discard_flying()

func evaluate_npc_update(combat: RefCounted, ordered_actor_ids: Variant, delta_ms: Variant, bounds_selection: Variant = null) -> Dictionary:
	error = ""
	if not _selected40_context.is_empty():return fail("Selected40 primary contacts require the unfinished native targeting owner")
	if _loadout.is_empty(): return fail("Configure primary ownership before NPC updates")
	if not Vitals.integer(delta_ms): return fail("Primary time must be nonnegative integer milliseconds")
	if combat==null or combat.get_script()!=Combat: return fail("Primary NPC updates require the opening NPC owner")
	var state: Dictionary = combat.snapshot()
	if state.get("base_content_id")!=_loadout.base_content_id or state.get("binding_id")!=_loadout.binding_id:
		return fail("Primary weapons and NPCs have different content identities")
	if not ordered_actor_ids is Array or ordered_actor_ids.size()>65536:
		return fail("Primary NPC updates require an explicit bounded ordered target list")
	var staged_combat: RefCounted = combat.fork_for_frame()
	for id in ordered_actor_ids:
		if staged_combat.collision_context(id).is_empty(): return fail(staged_combat.error)
	var staged: RefCounted = fork_state()
	var operation := Contacts.new()
	var events := []
	# Source wrappers append in equipment creation order and the world updates
	# that list forwards. The primary firing array itself was filled backwards.
	for index in range(staged._guns.size()-1,-1,-1):
		var gun: Dictionary = staged._guns[index]
		var contacts: Dictionary = operation.evaluate_staged(gun.projectiles,staged_combat,ordered_actor_ids,bounds_selection)
		if contacts.is_empty(): return fail(operation.error)
		var motion: Dictionary = contacts.projectiles.advance(delta_ms)
		if motion.is_empty(): return fail(contacts.projectiles.error)
		gun.projectiles=contacts.projectiles
		gun.contact_pass_evaluated=true
		gun.last_contact_target=null if contacts.last_contact_actor_id==null else {"group":"npc","index":contacts.last_contact_actor_id}
		staged_combat=contacts.combat
		events.append({"mount_id":gun.mount_id,"slot":gun.equipment.slot,"item_id":gun.equipment.item_id,
			"contacts":contacts.contacts,"motion":motion})
	return {"primaries":staged,"combat":staged_combat,"weapons":events}

## combat_staged: the caller passes a detached combat that it discards on any
## failure; contacts then change it in place instead of forking it again.
func evaluate_opening_update(combat: RefCounted, bodies: RefCounted, inventory: RefCounted, delta_ms: Variant, bounds_selection: Variant = null, guidance_actor_id: int=-1, combat_staged:=false) -> Dictionary:
	error=""
	if not _selected40_context.is_empty():return fail("Selected40 mixed contacts require the unfinished native scenery and targeting owners")
	return _evaluate_opening_update(combat,bodies,inventory,delta_ms,bounds_selection,guidance_actor_id,combat_staged)

## Explicit admission to the shared ordered pass, never generic cursor40 travel.
func evaluate_selected40_update(combat: RefCounted,bodies: RefCounted,inventory: RefCounted,delta_ms: Variant,guidance_actor_id: int=-1) -> Dictionary:
	error=""
	if _selected40_construction==null or not inventory is TargetInventory or not inventory.matches_selected40(combat,_selected40_construction,_selected40_context):return fail("Selected40 primaries require their same-generation native target inventory")
	return _evaluate_opening_update(combat,bodies,inventory,delta_ms,null,guidance_actor_id)

func _evaluate_opening_update(combat: RefCounted,bodies: RefCounted,inventory: RefCounted,delta_ms: Variant,bounds_selection: Variant,guidance_actor_id: int,combat_staged:=false) -> Dictionary:
	if _loadout.is_empty(): return fail("Configure primary ownership before opening updates")
	if not Vitals.integer(delta_ms): return fail("Primary time must be nonnegative integer milliseconds")
	if combat==null or combat.get_script()!=Combat or bodies==null or bodies.get_script()!=SceneryBodies:
		return fail("Opening primary updates require both native target owners")
	if inventory==null or inventory.get_script()!=TargetInventory:
		return fail("Opening primary updates require the verified fresh target inventory")
	# Even an unarmed owner must belong to the complete verified opening world.
	# Owners never change target membership after construction; debug builds and
	# tests recheck it, since the check rebuilds every actor observation.
	if not inventory.validate_loadout(_loadout) or (OS.is_debug_build() and not inventory.validate_owners(combat.snapshot(),bodies.read_snapshot())):
		return fail(inventory.error)
	var staged: RefCounted = fork_state()
	var staged_combat: RefCounted = combat if combat_staged else combat.fork_for_frame()
	var staged_bodies: RefCounted = bodies.fork_for_frame()
	var operation := OpeningContacts.new()
	var events := []
	for index in range(staged._guns.size()-1,-1,-1):
		var gun: Dictionary = staged._guns[index]
		var result:={"projectiles":gun.projectiles,"combat":staged_combat,"bodies":staged_bodies,
			"contacts":[],"last_contact_target":null}
		# Configuration and world entry already validated the ordinary policy.
		# Empty guns need their clocks and events, but no target geometry queries.
		if gun.projectiles.has_retained_projectiles() or bounds_selection!=null:
			result=operation.evaluate(gun.projectiles,staged_combat,staged_bodies,inventory,bounds_selection)
			if result.is_empty(): return fail(operation.error)
		# Cleanup belongs after this gun's COMPLETE target list, never between
		# NPCs and scenery or after every gun has completed a global contact pass.
		var target: Variant=result.combat.guidance_position(guidance_actor_id) if result.projectiles.has_guidance() else null
		var motion: Dictionary = result.projectiles.advance(delta_ms,target)
		if motion.is_empty(): return fail(result.projectiles.error)
		gun.projectiles=result.projectiles
		gun.contact_pass_evaluated=true
		gun.last_contact_target=null if result.last_contact_target==null else result.last_contact_target.duplicate()
		staged_combat=result.combat;staged_bodies=result.bodies
		events.append({"mount_id":gun.mount_id,"slot":gun.equipment.slot,"item_id":gun.equipment.item_id,
			"contacts":result.contacts,"last_contact_target":result.last_contact_target,"motion":motion})
	return {"primaries":staged,"combat":staged_combat,"bodies":staged_bodies,"weapons":events}

func turret_state() -> Dictionary:return {} if _turret==null else _turret.snapshot()
func turret_active() -> bool:return _turret!=null and _turret.active()
func set_turret_active(value: bool) -> void:
	if _turret!=null:_turret.set_active(value)
func advance_turret(command: Vector2,milliseconds: int,inverted:=false) -> void:
	if _turret!=null:_turret.advance(command,milliseconds,inverted)
func turret_camera(ship: Transform3D) -> Transform3D:return _turret.camera_pose(ship)
func aim_pose(ship: Transform3D) -> Transform3D:return _turret.aim_pose(ship) if turret_active() else ship

func has_beams() -> bool:
	if turret_active():return false
	for gun in _guns:
		if gun.projectiles.has_beam():return true
	return false

func observe_beam_pose(pose: Transform3D) -> bool:
	if not pose.is_finite():return reject("Beam source pose must be finite")
	for gun in _guns:
		if gun.projectiles.has_beam() and not gun.projectiles.observe_beam_pose(pose):return reject(gun.projectiles.error)
	return true

func turret_automatic() -> bool:return _turret!=null and _turret.automatic()
func set_auto_turret_enabled(value: bool) -> void:
	if _turret!=null:_turret.set_auto_enabled(value)
func advance_auto_turret(ship: Transform3D,actors: Array,milliseconds: int) -> bool:
	return _turret!=null and _turret.advance_auto(ship,actors,milliseconds)

## The trigger fires the forward guns (or the turret in turret view); an
## automatic turret on target fires on its own.
func fire(firing_transform: Variant, firing_allowed: Variant, random_state: Variant=null, beam_targets: Array=[], trigger:=true, auto_turret:=false) -> Dictionary:
	error = ""
	if _loadout.is_empty(): return fail("Configure primary ownership before firing")
	if not firing_transform is Transform3D or not firing_transform.is_finite() or not firing_allowed is bool:
		return fail("Primary firing requires a finite transform and explicit actor permission")
	var next_random: Variant=null
	if random_state!=null:
		var random:=Random.new()
		if not random.restore(random_state):return fail(random.error)
		next_random=random.snapshot()
	var staged := []
	var events := []
	for gun in _guns:
		var projectiles: RefCounted = gun.projectiles.fork_state()
		var result := {"fired":false,"reason":"inactive_group"}
		var firing_pose: Transform3D=_turret.barrel_pose(firing_transform) if gun.equipment.category==2 else firing_transform
		var selected: bool=(trigger and (gun.equipment.category==2)==turret_active()) or (auto_turret and gun.equipment.category==2 and not turret_active())
		if gun.equipment.quantity > 0 and selected:
			if projectiles.has_beam():result=projectiles.fire_beam_from_mount(gun.mount,firing_transform,firing_allowed,beam_targets)
			else:result = projectiles.fire_forward_from_mount(gun.mount,firing_pose,firing_allowed,next_random)
		if result.is_empty(): return fail(projectiles.error)
		if result.has("random_state"):next_random=result.random_state
		staged.append(projectiles)
		events.append({"mount_id":gun.mount_id,"slot":gun.equipment.slot,
			"item_id":gun.equipment.item_id,"result":result})
		if not gun.audio.is_empty():
			var cues := []
			if result.fired:
				var cue := Audio.cue(gun.audio,firing_pose.origin)
				if not cue.is_empty():cues.append(cue)
			events[-1].audio_events=cues
	for i in _guns.size(): _guns[i].projectiles = staged[i]
	# Ordinary primary shots do not consume the installed item's quantity.
	var outcome:={"weapons":events}
	if next_random!=null:outcome.random_state=next_random
	return outcome

func advance(delta_ms: Variant) -> Dictionary:
	error = ""
	if _loadout.is_empty(): return fail("Configure primary ownership before advancing")
	if not Vitals.integer(delta_ms): return fail("Primary time must be nonnegative integer milliseconds")
	var staged := []
	var events := []
	for gun in _guns:
		var projectiles: RefCounted = gun.projectiles.fork_state()
		var result: Dictionary = projectiles.advance(delta_ms)
		if result.is_empty(): return fail(projectiles.error)
		staged.append(projectiles)
		events.append({"mount_id":gun.mount_id,"slot":gun.equipment.slot,
			"item_id":gun.equipment.item_id,"result":result})
	for i in _guns.size(): _guns[i].projectiles = staged[i]
	return {"weapons":events}

func retire(mount_id: Variant, projectile_id: Variant) -> bool:
	error = ""
	if not mount_id is int or mount_id < 1: return reject("Invalid weapon handle")
	for gun in _guns:
		if gun.mount_id == mount_id:
			if gun.projectiles.retire(projectile_id): return true
			return reject(gun.projectiles.error)
	return reject("Weapon handle is stale or belongs to another primary owner")

func mark_impact(mount_id: Variant, projectile_id: Variant) -> bool:
	error = ""
	if not mount_id is int or mount_id < 1: return reject("Invalid impact weapon handle")
	for gun in _guns:
		if gun.mount_id == mount_id:
			if gun.projectiles.mark_impact(projectile_id): return true
			return reject(gun.projectiles.error)
	return reject("Impact weapon handle is stale or belongs to another primary owner")

func reject(message: String) -> bool:
	error = message
	return false

func fail(message: String) -> Dictionary:
	error = message
	return {}
