extends RefCounted
## Shared native projectile pools for the verified ordinary NPC populations.
## The encounter owner decides who requests fire and when updates run. Target
## selection, shooter state, AI and mission consequences remain outside this owner.
## Explicit player updates apply contacts before each gun's movement and cleanup.
const Actor = preload("res://src/simulation/opening_combat_actor.gd")
const Definitions = preload("res://src/content/opening_npc_weapon_definitions.gd")
const Projectiles = preload("res://src/simulation/ordinary_projectiles.gd")
const Combat = preload("res://src/simulation/opening_combat_group.gd")
const Vitals = preload("res://src/simulation/combat_vitals.gd")
const Library = preload("res://src/content/library.gd")
const PlayerContacts = preload("res://src/simulation/ordinary_player_contacts.gd")
const Player = preload("res://src/simulation/opening_player_state.gd")
const Audio = preload("res://src/simulation/weapon_audio.gd")
const NPCContacts = preload("res://src/simulation/ordinary_npc_contacts.gd")
const Training = preload("res://src/content/combat_training_weapon_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const AmbientLife=preload("res://src/content/ambient_lifecycle_definitions.gd")
const Construction=preload("res://src/simulation/opening_npc_construction.gd")
const ContractCombat=preload("res://src/content/contract_ship_combat_definitions.gd")
const BakkaCombat=preload("res://src/content/bakka_combat_definitions.gd")
const Convoy=preload("res://src/content/convoy_world_definitions.gd")
const Kappa=preload("res://src/content/kappa_population_definitions.gd")
const Alioth=preload("res://src/content/alioth_population_definitions.gd")
const AliothSequence=preload("res://src/simulation/alioth_attack.gd")
var error := ""
var _identity := {}
var _definition := {}
var _guns: Array = []
var _audio := {}
var _definitions := []
var _actor_audio := []
var _training := {}
var _alioth_revision:=-1
var _selected40_world: RefCounted
var _selected40:={}
var _selected41_world: RefCounted
var _selected41:={}

func clear() -> void:
	error = ""
	_identity = {}
	_definition = {}
	_guns = []
	_audio = {}
	_definitions=[];_actor_audio=[];_training={}
	_alioth_revision=-1
	_selected40_world=null;_selected40={};_selected41_world=null;_selected41={}

func configure(bindings: RefCounted, catalogues: RefCounted) -> bool:
	clear()
	if not _matching_content(bindings,catalogues):return reject("NPC weapons require matching source content and bindings")
	var data: Variant = bindings.opening_actors.get("npc_initialization",{}).get("primary_weapon",{})
	if not Definitions.parameters(data): return reject("Source opening NPC weapons are unavailable")
	var rows: Variant = bindings.opening_actors.get("actors")
	if not rows is Array or rows.size()!=3: return reject("Source opening NPC population is unavailable")
	for i in rows.size():
		if rows[i].get("actor_id")!=i or rows[i].get("actor_kind")!=data.actor_kind or rows[i].get("hull_catalogue_id")!=[2,23,2][i]: return reject("NPC weapon declaration does not match the opening population")

	return _configure(bindings,catalogues,data,rows.size())

func configure_full_hold(bindings: RefCounted, catalogues: RefCounted, construction: RefCounted) -> bool:
	clear()
	if Actor.full_hold_initial(bindings,catalogues,construction).is_empty():return reject("Second pirate weapons require its matching detached world")
	if not _configure(bindings,catalogues,bindings.full_hold_pirate.primary_weapon,1):return false
	_identity.campaign_cursor=int(bindings.full_hold_pirate.campaign_cursor)
	return true

static func _matching_content(bindings: RefCounted, catalogues: RefCounted) -> bool:
	return bindings!=null and catalogues!=null and Library.valid_hash(bindings.base_content_id) and Library.valid_hash(bindings.binding_id) and bindings.base_content_id==catalogues.content_id

func _configure(bindings: RefCounted, catalogues: RefCounted, data: Dictionary, count: int) -> bool:
	var rows:=[]
	for _id in count:rows.append(data)
	if not _configure_rows(bindings,catalogues,rows):return false
	_definition=data.duplicate(true);_audio=_actor_audio[0].duplicate()
	return true

func configure_combat_training(bindings: RefCounted, catalogues: RefCounted, world: RefCounted, rank: Variant, difficulty: Variant) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not Training.parameters(bindings.combat_training_weapons):return reject("This pack has no combat-training weapons")
	# The canonical combat constructor validates the retained four actors,
	# identities, entry rank and difficulty without consuming effect draws.
	var combat:=Combat.new()
	if not combat.configure_combat_training(bindings,catalogues,world,rank,difficulty):return reject(combat.error)
	if not _configure_rows(bindings,catalogues,bindings.combat_training_weapons.npc_weapons,7):return false
	_identity.campaign_cursor=int(bindings.combat_training_weapons.campaign_cursor)
	_training=bindings.combat_training_weapons.duplicate(true)
	for id in _training.target_memberships.size():_training.target_memberships[id]=_training.target_memberships[id].map(func(value):return int(value))
	return true

func configure_local_traffic(bindings: RefCounted, catalogues: RefCounted, world: RefCounted, rank: Variant, difficulty: Variant) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or world==null:return reject("Local weapons require their generated world")
	var data:=Travel.weapons(bindings,world.snapshot(),rank,difficulty)
	if data.is_empty():return reject("Local weapons require their source population")
	if not _configure_rows(bindings,catalogues,data.npc_weapons,int(data.campaign_cursor)):return false
	_identity.campaign_cursor=int(data.campaign_cursor);_training=data
	return true

func configure_ambient(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,rank: Variant,difficulty: Variant) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not construction is Construction or not AmbientLife.recycling_parameters(bindings.ambient_lifecycle):return reject("Ambient weapons require their supported generated population")
	var data:=AmbientLife.guidance(bindings,construction.snapshot(),rank,difficulty)
	if data.is_empty():return reject("Unsupported ambient weapon population")
	var cursor:=int(data.campaign_cursor)
	var rows:=[]
	for actor in construction.snapshot().actors:
		var row: Dictionary={} if actor.population_group=="freighter" else Travel.ordinary_weapon(bindings.mido_travel,cursor)
		if data.has("free_traffic") and actor.population_group!="freighter":row=ContractCombat.shared_weapon(bindings.early_contracts.ship_combat.weapons,cursor,rank,float(difficulty),actor.actor_kind)
		for key in ["actor_id","actor_kind","hull_catalogue_id"]:row[key]=actor[key]
		if actor.population_group=="freighter":row.unarmed=true;data.target_memberships[actor.actor_id]=[]
		rows.append(row)
	if not _configure_rows(bindings,catalogues,rows,cursor):return false
	_identity.campaign_cursor=cursor;_training=data
	return true

func configure_contract(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not construction is Construction:return reject("Contract weapons require their generated accepted population")
	var data:=ContractCombat.population(bindings,construction.snapshot(),construction.mission_context_owner())
	if data.is_empty():return reject("This population has no supported contract ship weapons")
	if not _configure_rows(bindings,catalogues,data.npc_weapons,int(data.campaign_cursor)):return false
	_identity.campaign_cursor=int(data.campaign_cursor);_training=data
	_training.contract_encounter=construction.snapshot().contract_encounter.duplicate(true)
	return true

func configure_bakka(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not construction is Construction:return reject("B'akka weapons require their generated story population")
	var data:=BakkaCombat.population(bindings,construction.snapshot())
	if data.is_empty():return reject("This population has no supported B'akka ship weapons")
	if not _configure_rows(bindings,catalogues,data.npc_weapons,36):return false
	_identity.campaign_cursor=36;_training=data
	_training.bakka_encounter=construction.snapshot().bakka_encounter.duplicate(true)
	return true

func configure_convoy(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not construction is Construction:return reject("Convoy weapons require their generated population")
	return _configure_encounter_weapons(bindings,catalogues,Convoy.population(bindings,construction.snapshot()))

func configure_alioth_attack(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not construction is Construction:return reject("Alioth weapons require their generated original population")
	if not _configure_encounter_weapons(bindings,catalogues,Alioth.combat(bindings,construction.snapshot())):return false
	_alioth_revision=0
	return true

func configure_kappa_rescue(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	clear()
	if not _matching_content(bindings,catalogues) or not construction is Construction:return reject("Kappa weapons require their generated rescue population")
	return _configure_encounter_weapons(bindings,catalogues,Kappa.combat(bindings,construction.snapshot()))

func _configure_encounter_weapons(bindings: RefCounted,catalogues: RefCounted,data: Dictionary) -> bool:
	if data.is_empty():return reject("This population has no supported encounter weapons")
	if not _configure_rows(bindings,catalogues,data.npc_weapons,int(data.campaign_cursor)):return false
	_identity.campaign_cursor=int(data.campaign_cursor);_training=data
	return true

func configure_selected41(bindings: RefCounted,catalogues: RefCounted,world: RefCounted,combat: RefCounted) -> bool:
	error=""
	if not _identity.is_empty() or not _matching_content(bindings,catalogues):return reject("Source41 weapons require fresh matching owners")
	if not is_instance_of(world,load("res://src/simulation/selected41_world_initialization.gd")) or not combat is Combat or combat.selected41_world_owner()!=world or not combat.has_local_reactions():return reject("Source41 weapons require their complete native generation")
	var initial: Dictionary=world.scenery_owner().world_initialization_owner().snapshot()
	var data: Dictionary=load("res://src/content/selected41_population_definitions.gd").weapon_profile(bindings,initial.get("npc_construction",{}))
	if data.is_empty() or not initial.get("weapon_effects") is Array or initial.weapon_effects.size()!=8:return reject("Source41 weapons lost the accepted effect allocations")
	if not _configure_rows(bindings,catalogues,data.npc_weapons,41,false,true):return false
	_identity.campaign_cursor=41;_training=data;_selected41_world=world
	_selected41={"context":initial.selected41_context.duplicate(true),"weapon_effects":initial.weapon_effects.duplicate(true),
		"input_random_state":initial.input_random_state.duplicate(),"random_state":initial.random_state.duplicate()}
	return true

func configure_selected40(bindings: RefCounted,catalogues: RefCounted,world: RefCounted,combat: RefCounted) -> bool:
	error=""
	if not _identity.is_empty() or not _matching_content(bindings,catalogues):return reject("Selected40 weapons require fresh owners and matching source content")
	if not is_instance_of(world,load("res://src/simulation/opening_world_initialization.gd")) or not combat is Combat or combat.selected40_world_owner()!=world:return reject("Selected40 weapons must retain the same native world as their actors")
	var initial: Dictionary=world.snapshot()
	var data: Dictionary=load("res://src/content/selected40_population_definitions.gd").weapon_profile(bindings,initial.get("npc_construction",{}))
	if data.is_empty() or not initial.get("weapon_effects") is Array or initial.weapon_effects.size()!=int(data.actor_count):return reject("Selected40 weapons require completed cast and weapon allocation")
	if not _configure_rows(bindings,catalogues,data.npc_weapons,40,true):return false
	_identity.campaign_cursor=40;_training=data;_selected40_world=world
	_selected40={"context":initial.selected40_context.duplicate(true),"weapon_effects":initial.weapon_effects.duplicate(true),
		"input_random_state":initial.input_random_state.duplicate(),"random_state":initial.random_state.duplicate()}
	return true

func _clear_story_targets() -> void:
	_training=_training.duplicate()
	_training.target_memberships=_training.target_memberships.map(func(_targets):return [])

func apply_alioth_sequence(owner: RefCounted) -> bool:
	error=""
	if _alioth_revision<0 or not owner is AliothSequence:return reject("Alioth target changes require their retained weapon owner")
	var sequence: Dictionary=owner.snapshot()
	for key in _identity:
		if sequence.get(key)!=_identity[key]:return reject("Alioth weapons belong to another sequence")
	if sequence.get("revision")!=_alioth_revision+1:return reject("Alioth weapons received a repeated or skipped sequence frame")
	var memberships: Array=_training.target_memberships.duplicate(true)
	for row in sequence.frame.actor_overrides:
		if sequence.phase!=AliothSequence.Stage.ESCAPE_VIEW or row.actor_id not in [3,4,5,6] or not row.clear_targets or memberships[row.actor_id].is_empty():return reject("Unsupported Alioth weapon target removal")
		memberships[row.actor_id]=[]
	# Original assignment updates every gun's target pointer too. Live projectile
	# slots and their clocks remain; their following collision pass has no targets.
	_training.target_memberships=memberships;_alioth_revision=sequence.revision
	return true

## Companions keep their own body population, but use the ordinary primary
## factory after their saved faction has replaced the temporary factory kind.
func configure_wingmen(bindings: RefCounted,catalogues: RefCounted,departure: RefCounted,bodies: Array) -> bool:
	clear()
	if not is_instance_of(departure,load("res://src/simulation/first_flight_construction.gd")) or bodies.is_empty() or bodies.size()>3:return reject("Companion guns require the retained paid departure")
	var career: RefCounted=departure.contract_owner()
	if career==null:return reject("Companion guns lost the paid career")
	var state: Dictionary=career.snapshot();var entry: Dictionary=departure.snapshot()
	var roster: Dictionary=state.get("wingmen",{}).get("active",{})
	if roster.get("names",[]).size()!=bodies.size():return reject("Companion gun population differs from the paid roster")
	var rows:=[]
	for id in bodies.size():
		if not bodies[id] is Actor:return reject("Companion guns require native body owners")
		var actor: Dictionary=bodies[id].snapshot()
		if actor.get("wingman")!=true or actor.get("wingman_index")!=id or actor.get("name")!=roster.names[id] or actor.get("actor_kind")!=roster.faction:return reject("Companion gun lost its saved pilot identity")
		for key in ["base_content_id","binding_id"]:
			if actor.get(key)!=bindings.get(key):return reject("Companion body and weapon content differ")
		var faction:=int(actor.actor_kind) if int(actor.actor_kind)<=3 else 8
		var enhanced: bool=int(state.get("mission",{}).get("kind",-1))==6
		var row:=ContractCombat.shared_weapon(bindings.early_contracts.ship_combat.weapons,int(entry.campaign_cursor),int(state.rank),float(state.difficulty),faction,enhanced)
		if row.is_empty():return reject("Companion primary lacks its native faction declaration")
		row.actor_id=id;row.actor_kind=int(actor.actor_kind);row.hull_catalogue_id=int(actor.hull_catalogue_id);row.name=actor.name
		rows.append(row)
	if not _configure_rows(bindings,catalogues,rows,int(entry.campaign_cursor)):return false
	_identity.campaign_cursor=int(entry.campaign_cursor)
	_training={"wingmen":roster.names.duplicate()}
	return true

func wingman_primary_declarations() -> Array:
	if not _training.has("wingmen"):return []
	return _guns.map(func(gun):return gun.snapshot().weapon)

func fire_wingmen(bodies: Array,requested_actor_ids: Array,poses: Dictionary) -> Dictionary:
	if not _training.has("wingmen") or bodies.size()!=_guns.size():return fail("Companion firing needs its own retained body population")
	var scene:={"actors":[]}
	for id in bodies.size():
		if not bodies[id] is Actor:return fail("Companion firing lost a native body owner")
		var body: Dictionary=bodies[id].snapshot()
		for key in _identity:
			if body.get(key)!=_identity[key]:return fail("Companion firing body belongs to another flight")
		if body.get("wingman")!=true or body.get("wingman_index")!=id or body.get("name")!=_definitions[id].name or body.get("actor_kind")!=_definitions[id].actor_kind:return fail("Companion firing changed its paid pilot")
		scene.actors.append(body)
	return _fire_bodies(scene,requested_actor_ids,poses)

## The companion's native target list includes other NPCs, even its own faction.
## Do not collapse it to the selected hostile; source geometry decides the hit.
## Reciprocal enemy/companion-body contacts remain a separate membership owner.
func evaluate_wingman_contacts(combat: RefCounted,delta_ms: int) -> Dictionary:
	if not _training.has("wingmen") or delta_ms<0:return fail("Invalid companion primary contact pass")
	if combat!=null and not combat is Combat:return fail("Companion contacts need the native combat owner")
	var next:=fork_for_frame();var targets:=[];var events:=[]
	var updated: RefCounted=null if combat==null else combat.fork_for_frame()
	if updated!=null:
		if not updated.bind_wingman_primaries(self):return fail(updated.error)
		for actor in updated.actor_snapshots():
			if not actor.get("contract_debris",false):targets.append(int(actor.actor_id))
	for id in next._guns.size():
		var gun: RefCounted=next._guns[id];var hits:=[];var last: Variant=null
		if updated!=null:
			var contacts:=NPCContacts.new()
			var result:=contacts.evaluate_staged(gun,updated,targets)
			if result.is_empty():return fail(contacts.error)
			gun=result.projectiles;updated=result.combat;hits=result.contacts;last=result.last_contact_actor_id
		var motion: Dictionary=gun.advance(delta_ms)
		if motion.is_empty():return fail(gun.error)
		next._guns[id]=gun
		events.append({"actor_id":id,"contacts":[],"npc_contacts":hits,"last_contact_actor":last,"motion":motion})
	return {"weapons":next,"combat":updated,"actors":events}

func _configure_rows(bindings: RefCounted, catalogues: RefCounted, rows: Array, cursor: int=-1, selected40:=false, selected41:=false) -> bool:
	var guns:=[];var sounds:=[]
	for data in rows:
		if data.get("unarmed",false):guns.append(null);sounds.append({});continue
		var weapon:=_resolve_weapon(bindings,catalogues,data,cursor,selected40,selected41)
		if weapon.is_empty():return false
		var gun:=Projectiles.new()
		if not gun.configure(weapon):return reject(gun.error)
		guns.append(gun)
		var selected_audio:={}
		var audio: Dictionary=bindings.weapon_parameters.get("audio",{})
		if not audio.is_empty():
			selected_audio=Audio.npc_entry(audio,int(data.actor_kind))
			if selected_audio.is_empty():return reject("NPC lacks supported weapon sound selection")
		sounds.append(selected_audio)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_guns=guns;_actor_audio=sounds;_definitions=rows.duplicate(true)
	return true

func _resolve_weapon(bindings: RefCounted, catalogues: RefCounted, data: Dictionary, cursor: int, selected40:=false, selected41:=false) -> Dictionary:
	var items: Variant = catalogues.tables.get("items")
	if not items is Array or data.item_id>=items.size(): return fail("NPC weapon names an absent catalogue item")
	var arrays: Variant = items[int(data.item_id)].get("arrays")
	if not arrays is Array or arrays.size()!=3 or arrays[2].size()<6 or arrays[2][3]!=data.category or arrays[2][5]!=data.get("catalogue_kind",data.kind):
		return fail("NPC weapon catalogue category or kind disagrees with its declaration")
	if bindings.resolve(int(data.model_resource_id),"mesh").is_empty(): return fail("NPC weapon visual resource is unavailable")
	var weapon := {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"launch_mode":"ordinary"}
	for key in ["item_id", "category", "kind", "damage", "interval_ms", "lifetime_ms", "projectile_capacity"]: weapon[key]=int(data[key])
	weapon.speed_units_per_millisecond=float(data.speed_units_per_millisecond)
	if data.has("nonplayer_source"):
		var policy: Dictionary=bindings.weapon_parameters.get("ordinary_hit_policy",{})
		var properties: Dictionary=items[int(data.item_id)].get("properties",{})
		var extra: Variant=properties.get(int(policy.get("additional_damage_property",-1)),int(policy.get("missing_additional_damage",0)))
		if extra!=int(policy.get("missing_additional_damage",0)) or policy.is_empty():return fail("NPC weapon requires unsupported additional damage")
		if cursor<0:return fail("NPC weapons require their constructed encounter identity")
		weapon.campaign_cursor=cursor
		weapon.nonplayer_source=bool(data.nonplayer_source)
		weapon.ordinary_hit_policy={"additional_damage":int(extra),"additional_damage_required":false,"nonplayer_damage":weapon.damage}
		weapon.collision_bounds={"mode":bindings.weapon_parameters.collision_bounds.mode}
	return weapon

func snapshot() -> Dictionary:
	if _identity.is_empty(): return {}
	var result := _identity.duplicate()
	result.definition=_definition.duplicate(true)
	result.audio=_audio.duplicate()
	result.actors=[]
	if not _selected41.is_empty():
		result.selected41=_selected41.duplicate(true);result.target_memberships=_training.target_memberships.duplicate(true)
	if not _selected40.is_empty():
		result.selected40=_selected40.duplicate(true);result.target_memberships=_training.target_memberships.duplicate(true)
	if _alioth_revision>=0:
		result.alioth_revision=_alioth_revision;result.target_memberships=_training.target_memberships.duplicate(true)
	for id in _guns.size():
		result.actors.append({"actor_id":id,"projectiles":{} if _guns[id]==null else _guns[id].snapshot()})
		if not _training.is_empty():
			result.actors[-1].definition=_definitions[id].duplicate(true)
			result.actors[-1].audio=_actor_audio[id].duplicate()
	return result

func fire(combat: RefCounted, requested_actor_ids: Array) -> Dictionary:
	if _selected41_world!=null:return fail("Source41 firing requires its retained native target owner")
	if _selected40_world!=null:return fail("Selected40 firing requires its live target owner")
	return _fire(combat,requested_actor_ids,{})

func fire_combat_training(combat: RefCounted, requests: Array) -> Dictionary:
	if _selected41_world!=null:return fail("Source41 firing requires its retained native target owner")
	if _selected40_world!=null:return fail("Selected40 firing requires its live target owner")
	return _fire_requests(combat,requests)

func _restart_selected41_attack(sequence: RefCounted) -> bool:
	error=""
	if not is_instance_of(sequence,load("res://src/simulation/selected41_sequence.gd")) or sequence.world_owner()!=_selected41_world:return reject("Source41 weapon reset requires its native sequence")
	var rows: Array=sequence.snapshot().frame.reset_fighters
	if rows.is_empty():return true
	if _selected41.get("attack_reset",false) or rows.map(func(row):return row.actor_id)!=[1,2,3]:return reject("Source41 weapon reset cannot repeat or replace actors")
	_training=_training.duplicate(true)
	for row in rows:
		var id: int=row.actor_id
		_guns[id]=_guns[id].fork_state();_guns[id].discard_flying()
		if not _guns[id].reset_fire_interval():return reject(_guns[id].error)
		_training.target_memberships[id]=[0]
	_selected41=_selected41.duplicate(true);_selected41.attack_reset=true
	return true

func fire_selected41(combat: RefCounted,player: RefCounted,requests: Array) -> Dictionary:
	error=""
	if _selected41_world==null or not combat is Combat or combat.selected41_world_owner()!=_selected41_world or not player is Player:return fail("Source41 firing requires its matching native actors and player")
	var state: Dictionary=player.snapshot()
	if player.selected41_construction_owner()!=_selected41_world.construction_owner().npc_construction_owner() or state.get("selected41_context")!=_selected41.context or player.loadout().get("ship_id")!=_training.player_ship_id:return fail("Source41 firing changed its retained player generation")
	var actors: Array=combat.actor_snapshots()
	for request in requests:
		if not request is Dictionary or not request.get("actor_id") is int or not request.get("target_actor_id") is int:return fail("Invalid source41 target request")
		var id: int=request.actor_id;var target: int=request.target_actor_id
		if id<1 or id>=actors.size() or target not in _training.target_memberships[id]:return fail("Source41 target is outside its authored membership")
		if request.get("pose")!=actors[id].pose:return fail("Source41 muzzle must retain its pre-motion native pose")
		if target==-1:
			if not actors[id].hostile or not state.active or state.vitals.hull<=0:return fail("Source41 gun cannot target a friendly or inactive player")
		elif not actors[target].active or actors[target].vitals.hull<=0 or actors[target].statistics_targeting_blocked:return fail("Source41 gun cannot target inactive, destroyed or blocked statistics")
	return _fire_requests(combat,requests)

func fire_selected40(combat: RefCounted,player: RefCounted,requests: Array) -> Dictionary:
	error=""
	if _selected40_world==null or not combat is Combat or combat.selected40_world_owner()!=_selected40_world or not player is Player:return fail("Selected40 firing requires its matching native actors and player")
	var state: Dictionary=player.snapshot()
	if player.selected40_construction_owner()!=_selected40_world.npc_construction_owner() or state.get("selected40_context")!=_selected40.context or player.loadout().get("ship_id")!=_training.player_ship_id:return fail("Selected40 target belongs to another retained player context")
	var actors: Array=combat.actor_snapshots()
	for request in requests:
		if not request is Dictionary or not request.get("actor_id") is int or not request.get("target_actor_id") is int:return fail("Invalid selected40 target request")
		var id: int=request.actor_id;var target: int=request.target_actor_id
		if id<1 or id>=actors.size() or target not in _training.target_memberships[id]:return fail("Selected40 target is outside its authored membership")
		if request.get("pose")!=actors[id].pose:return fail("Selected40 muzzle must use its native actor pose")
		if target==-1:
			if not actors[id].hostile or not state.active or state.vitals.hull<=0:return fail("Selected40 gun cannot target a friendly or inactive player")
		elif not actors[target].active or actors[target].vitals.hull<=0 or actors[target].statistics_targeting_blocked:return fail("Selected40 gun cannot target inactive, destroyed or blocked statistics")
	return _fire_requests(combat,requests)

func _fire_requests(combat: RefCounted, requests: Array) -> Dictionary:
	error=""
	if _training.is_empty():return fail("This weapon owner has no combat-training firing requests")
	var ids:=[];var poses:={}
	for request in requests:
		if not request is Dictionary or request.size()!=3 or not request.get("actor_id") is int or not request.get("target_actor_id") is int:return fail("Invalid combat-training firing request")
		var id: int=request.actor_id
		if id<0 or id>=_guns.size() or poses.has(id) or not request.get("pose") is Transform3D or not request.pose.is_finite():return fail("Invalid combat-training firing pose")
		if not request.target_actor_id in _training.target_memberships[id]:return fail("Combat-training request names a target outside its membership")
		ids.append(id);poses[id]=request.pose
	return _fire(combat,ids,poses)

func _fire(combat: RefCounted, requested_actor_ids: Array, poses: Dictionary) -> Dictionary:
	error=""
	if _identity.is_empty() or not combat is Combat: return fail("NPC firing requires configured weapons and matching combat actors")
	if _selected41_world!=null and combat.selected41_world_owner()!=_selected41_world:return fail("Source41 firing uses a different native generation")
	if _selected40_world!=null and combat.selected40_world_owner()!=_selected40_world:return fail("Selected40 firing uses a different generated world")
	var scene: Dictionary = combat.snapshot()
	for key in _identity:
		if scene.get(key)!=_identity[key]: return fail("NPC firing actors belong to another source profile")
	if not scene.get("actors") is Array or scene.actors.size()!=_guns.size():return fail("NPC firing population differs from its weapon pools")
	for id in _guns.size():
		var kind_matches: bool=scene.actors[id].get("actor_kind")==_definitions[id].actor_kind
		if _selected40_world!=null:kind_matches=load("res://src/content/selected40_population_definitions.gd").constructed_kind_matches(scene.actors[id],int(_definitions[id].actor_kind))
		if scene.actors[id].get("actor_id")!=id or not kind_matches:return fail("NPC firing membership differs from its weapon declaration")
	if _training.has("contract_encounter") and scene.get("contract_encounter")!=_training.contract_encounter:return fail("NPC firing belongs to another accepted contract")
	if _training.has("bakka_encounter") and scene.get("bakka_encounter")!=_training.bakka_encounter:return fail("NPC firing belongs to another B'akka contest")
	return _fire_bodies(scene,requested_actor_ids,poses)

func _fire_bodies(scene: Dictionary,requested_actor_ids: Array,poses: Dictionary) -> Dictionary:
	var seen := {}
	for id in requested_actor_ids:
		if not id is int or id<0 or id>=_guns.size() or seen.has(id): return fail("Invalid or duplicate NPC firing request")
		if _guns[id]==null:return fail("This traffic actor has no ordinary gun")
		seen[id]=true
	var staged := []
	var results := []
	# Source NPC array order determines events, independently of request order.
	for id in _guns.size():
		if _guns[id]==null:staged.append(null);continue
		var gun: RefCounted = _guns[id].fork_state()
		staged.append(gun)
		if not seen.has(id): continue
		var actor: Dictionary = scene.actors[id]
		var allowed: bool = actor.active and actor.firing_allowed and actor.vitals.hull>0
		if _selected40_world!=null or _selected41_world!=null:allowed=allowed and actor.actor_mode==1
		var outcome := {"fired":false,"reason":"permission"}
		if allowed:
			var pose: Variant = poses.get(id,actor.get("pose"))
			if not pose is Transform3D or not pose.is_finite(): return fail("Active NPC firing requires its explicit finite source pose")
			# This constructor supplies zero local muzzle and spread. NPCs do not
			# use the player's catalogue mounts or its additional Z displacement.
			outcome=gun.fire(pose.origin,pose.basis.z,true)
			if outcome.is_empty(): return fail(gun.error)
		results.append({"actor_id":id,"outcome":outcome})
		if not _actor_audio[id].is_empty():
			var cues := []
			if outcome.fired:
				var cue := Audio.cue(_actor_audio[id],poses.get(id,actor.pose).origin)
				if not cue.is_empty():cues.append(cue)
			results[-1].audio_events=cues
	_guns=staged
	return {"actors":results}

func advance(delta_ms: Variant) -> Dictionary:
	error=""
	if _identity.is_empty() or not Vitals.integer(delta_ms): return fail("NPC projectiles require nonnegative integer milliseconds")
	var staged := []
	var results := []
	for id in _guns.size():
		if _guns[id]==null:staged.append(null);continue
		var gun: RefCounted = _guns[id].fork_state()
		var result: Dictionary = gun.advance(delta_ms)
		if result.is_empty(): return fail(gun.error)
		staged.append(gun)
		results.append({"actor_id":id,"update":result})
	_guns=staged
	return {"actors":results}

func fork_for_frame() -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy._identity=_identity.duplicate()
	copy._definition=_definition.duplicate(true)
	copy._audio=_audio.duplicate()
	copy._definitions=_definitions.duplicate(true);copy._actor_audio=_actor_audio.duplicate(true);copy._training=_training.duplicate(true)
	copy._alioth_revision=_alioth_revision
	copy._selected40_world=_selected40_world;copy._selected40=_selected40.duplicate(true)
	copy._selected41_world=_selected41_world;copy._selected41=_selected41.duplicate(true)
	for gun in _guns: copy._guns.append(null if gun==null else gun.fork_state())
	return copy

func evaluate_player_update(player: RefCounted, pose: Variant, shooter_states: Variant, special_flight: Variant, delta_ms: Variant) -> Dictionary:
	error=""
	if not _training.is_empty():return fail("Combat-training weapons require their complete mixed target pass")
	if _guns.is_empty() or not player is Player or not Vitals.integer(delta_ms) or not special_flight is bool:
		return fail("NPC player updates require configured owners, time and flight state")
	if not shooter_states is Array or shooter_states.size()!=_guns.size(): return fail("NPC player update requires every shooter's current state in actor order")
	for state in shooter_states:
		if not state is Dictionary or state.size()!=2 or not state.get("present") is bool or not state.get("hostile") is bool: return fail("Invalid NPC shooter state")
	var next: RefCounted=fork_for_frame()
	var staged_player: RefCounted=player.fork_for_frame()
	var operation := PlayerContacts.new()
	var events := []
	for id in _guns.size():
		var state: Dictionary=shooter_states[id]
		var contact := operation.evaluate(next._guns[id],staged_player,pose,state.present,state.hostile,special_flight)
		if contact.is_empty(): return fail(operation.error)
		var motion: Dictionary=contact.projectiles.advance(delta_ms)
		if motion.is_empty(): return fail(contact.projectiles.error)
		next._guns[id]=contact.projectiles;staged_player=contact.player
		events.append({"actor_id":id,"contacts":contact.contacts,"last_contact_actor":contact.last_contact_actor,"motion":motion})
	return {"weapons":next,"player":staged_player,"actors":events}

func evaluate_combat_training_update(player: RefCounted, pose: Variant, combat: RefCounted, special_flight: Variant, delta_ms: Variant) -> Dictionary:
	error=""
	if _selected41_world!=null:return fail("Source41 mixed contacts require their explicit native owners")
	if _selected40_world!=null:return fail("Selected40 mixed contacts require complete consequence and lifecycle owners")
	return _evaluate_mixed_update(player,pose,combat,special_flight,delta_ms)

func evaluate_selected41_update(player: RefCounted,pose: Variant,combat: RefCounted,delta_ms: Variant) -> Dictionary:
	error=""
	if _selected41_world==null or not player is Player or not combat is Combat or combat.selected41_world_owner()!=_selected41_world or not combat.has_local_reactions():return fail("Source41 contacts require complete native consequence owners")
	if player.selected41_construction_owner()!=_selected41_world.construction_owner().npc_construction_owner() or player.snapshot().get("selected41_context")!=_selected41.context:return fail("Source41 contacts changed their retained native player")
	return _evaluate_mixed_update(player,pose,combat,false,delta_ms)

func evaluate_selected40_update(player: RefCounted,pose: Variant,combat: RefCounted,delta_ms: Variant) -> Dictionary:
	error=""
	if _selected40_world==null or not player is Player or not combat is Combat or combat.selected40_world_owner()!=_selected40_world or not combat.has_local_reactions():return fail("Selected40 contacts require their prepared native world and consequence owners")
	if player.selected40_construction_owner()!=_selected40_world.npc_construction_owner() or player.snapshot().get("selected40_context")!=_selected40.context:return fail("Selected40 contacts differ from their retained native player")
	return _evaluate_mixed_update(player,pose,combat,false,delta_ms)

func _evaluate_mixed_update(player: RefCounted,pose: Variant,combat: RefCounted,special_flight: Variant,delta_ms: Variant) -> Dictionary:
	if _training.is_empty() or not player is Player or not combat is Combat or not Vitals.integer(delta_ms) or not special_flight is bool:return fail("Mixed contacts require the verified training weapon, player and combat owners")
	var player_state: Dictionary=player.snapshot();var scene: Dictionary=combat.snapshot()
	for key in _identity:
		if player_state.get(key)!=_identity[key] or scene.get(key)!=_identity[key]:return fail("Mixed contact owners belong to another encounter")
	if not scene.get("actors") is Array or scene.actors.size()!=_guns.size():return fail("Mixed contacts require the complete NPC population")
	for id in _guns.size():
		for key in ["actor_id","actor_kind","hull_catalogue_id"]:
			if key=="actor_kind" and _selected40_world!=null and load("res://src/content/selected40_population_definitions.gd").constructed_kind_matches(scene.actors[id],int(_definitions[id][key])):continue
			if scene.actors[id].get(key)!=_definitions[id][key]:return fail("Mixed contact population changed")
	if _training.has("contract_encounter") and (scene.get("contract_encounter")!=_training.contract_encounter or player_state.get("contract_encounter")!=_training.contract_encounter):return fail("Mixed contacts belong to another accepted contract")
	var shooters: Array=combat.shooter_states()
	var next:=fork_for_frame();var staged_player: RefCounted=player.fork_for_frame();var staged_combat: RefCounted=combat.fork_for_frame()
	var player_contacts:=PlayerContacts.new();var npc_contacts:=NPCContacts.new();var events:=[]
	for id in _guns.size():
		if _guns[id]==null:continue
		var gun: RefCounted=next._guns[id]
		var player_hits:=[];var npc_hits:=[];var last: Variant=null
		for target in _training.target_memberships[id]:
			if int(target)==-1:
				var contact:=player_contacts.evaluate(gun,staged_player,pose,shooters[id].present,shooters[id].hostile,special_flight)
				if contact.is_empty():return fail(player_contacts.error)
				gun=contact.projectiles;staged_player=contact.player;player_hits.append_array(contact.contacts)
				if not contact.contacts.is_empty():last=contact.last_contact_actor
			else:
				# Both owners were detached above. Keep the outer transaction's
				# actors across target passes; a later failure discards them all.
				var npc:=npc_contacts.evaluate_staged(gun,staged_combat,[int(target)])
				if npc.is_empty():return fail(npc_contacts.error)
				gun=npc.projectiles;staged_combat=npc.combat;npc_hits.append_array(npc.contacts)
				if npc.last_contact_actor_id!=null:last={"group":"npc","index":npc.last_contact_actor_id}
		# A marked projectile retains its geometry until every target has been
		# visited in authored order, including the Challenge's player-last lists.
		var motion: Dictionary=gun.advance(delta_ms)
		if motion.is_empty():return fail(gun.error)
		next._guns[id]=gun
		events.append({"actor_id":id,"contacts":player_hits,"npc_contacts":npc_hits,"last_contact_actor":last,"motion":motion})
	return {"weapons":next,"player":staged_player,"combat":staged_combat,"actors":events}

func reject(message: String) -> bool:
	error=message
	return false

func fail(message: String) -> Dictionary:
	reject(message)
	return {}
