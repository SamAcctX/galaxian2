extends RefCounted
const FreeLife=preload("res://src/content/free_lifecycle_definitions.gd")
const Alioth=preload("res://src/content/alioth_population_definitions.gd")
const Kappa=preload("res://src/content/kappa_population_definitions.gd")
const Story=preload("res://src/content/story_encounter_definitions.gd")
## Ordinary NPC ownership; Opening alone uses the radio activation cue. AI and weapon
## target-list selection remain distinct from this canonical actor-ID inventory.
const EscapeCamera=preload("res://src/content/opening_escape_camera_definitions.gd")
const HitDefinitions = preload("res://src/content/ordinary_hit_definitions.gd")
const WeaponHit = preload("res://src/simulation/ordinary_weapon_hit.gd")
const Actor = preload("res://src/simulation/opening_combat_actor.gd")
const Activation = preload("res://src/content/npc_activation_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const TrainingWeapons = preload("res://src/content/combat_training_weapon_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const AmbientCombat=preload("res://src/content/ambient_combat_definitions.gd")
const ContractLife=preload("res://src/content/contract_ship_lifecycle_definitions.gd")
const BakkaCombat=preload("res://src/content/bakka_combat_definitions.gd")
const Convoy=preload("res://src/content/convoy_world_definitions.gd")
const ContractResults=preload("res://src/content/contract_flight_result_definitions.gd")
const NPCConstruction=preload("res://src/simulation/opening_npc_construction.gd")
const Reputation=preload("res://src/simulation/faction_reputation.gd")
const Provocation=preload("res://src/simulation/npc_provocation.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var error := ""
var _actors := []
## Actor ids this group has detached since its last fork; others may be shared.
var _owned := {}
var _activation := {}
var _hit_policy := {}
var _training_weapons := {}
var _identity := {}
var _activated := false
var _phase := -1
var _event_count := 0
var _escape_enabled:=false
var _reputation: RefCounted
## Ships destroyed by a named item this flight: [{actor_id, item_id, population_group}].
## Replaced, never mutated, so frames can share it.
var _lethal_items:=[]
var _provocation: RefCounted
var _reputation_rules:={}
var _contact_random:={}
var _display_available:=false
var _contract_encounter:={}
var _bakka_encounter:={}
var _contract_settlement:={}
## Standing fixed by a story hostility turn: {axis, value}.
var _story_standing:={}
const EMPTY_RECOVERY={"accepted_quantity":0,"kind9_quantity":0,"friendly_cargo_taken":false,"item_flags":[]}
var _recovery_totals:={}
var _selected40_world: RefCounted
var _selected41_world: RefCounted
var _wingman_primaries:=[]
var _wingman_systems:=[]

func clear() -> void:
	error = ""
	_owned={};_actors = []
	_activation = {}
	_hit_policy = {}
	_training_weapons = {}
	_identity = {}
	_activated = false
	_phase = -1
	_event_count = 0
	_escape_enabled=false
	_reputation=null
	_provocation=null;_reputation_rules={};_contact_random={};_display_available=false
	_contract_encounter={}
	_story_standing={}
	_bakka_encounter={}
	_contract_settlement={}
	_recovery_totals={};_lethal_items=[]
	_selected40_world=null;_selected41_world=null
	_wingman_primaries=[]
	_wingman_systems=[]

## Retain the actual field -> cast -> weapon initialization. This group enables
## native targeting and firing, but cannot silently apply incomplete encounter
## consequences, reserve activation or mission results.
func configure_selected41(bindings: RefCounted,catalogues: RefCounted,world: RefCounted) -> bool:
	error=""
	if not _identity.is_empty():return reject("Source41 actors require a fresh group")
	var data: Dictionary=load("res://src/content/selected41_population_definitions.gd").consequence_profile(bindings,catalogues,world)
	if data.is_empty():return reject("Source41 actors require the complete native initialized world")
	var entry: RefCounted=world.entry_owner();var equipment: RefCounted=entry.equipment_owner()
	var reaction:=Provocation.new();var history:=Reputation.new()
	if not reaction._configure_story(bindings,catalogues,data,equipment,entry.career_owner().snapshot().reputation) or not history.configure_selected41(bindings,catalogues,world):return reject(reaction.error+history.error)
	var policy: Dictionary=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Source41 lacks the ordinary hit policy")
	# Adopt the already accepted native bodies. In particular body0 retains
	# its Vossk assembly, actual carried hull and separate maximum capacity.
	var builder: RefCounted=world.construction_owner();var actors:=[]
	for id in int(data.actor_count):
		var actor: RefCounted=builder.body_owner(id)
		if actor==null or actor.snapshot().get("selected41_component")!=true:return reject("Source41 lost an initialized native body")
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":41}
	_owned={};_actors=actors;_training_weapons=data;_selected41_world=world
	_hit_policy=policy.duplicate(true);_provocation=reaction;_reputation=history;_reputation_rules=data.standing
	_contact_random=world.snapshot().random_state.duplicate(true)
	return true

func selected41_world_owner() -> RefCounted:return _selected41_world

func configure_selected40(bindings: RefCounted,catalogues: RefCounted,world: RefCounted) -> bool:
	error=""
	if not _identity.is_empty() or not is_instance_of(world,load("res://src/simulation/opening_world_initialization.gd")):return reject("Selected40 actors require a fresh group and native initialized world")
	var construction: RefCounted=world.npc_construction_owner()
	if construction==null:return reject("Selected40 actors require their generated cast")
	var data: Dictionary=load("res://src/content/selected40_population_definitions.gd").weapon_profile(bindings,construction.snapshot())
	if data.is_empty():return reject("Selected40 targeting lacks its verified source population")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_selected40(bindings,catalogues,construction,id):return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40}
	_owned={};_actors=actors;_training_weapons=data;_selected40_world=world
	return true

func selected40_world_owner() -> RefCounted:return _selected40_world

func apply_selected40_sequence(owner: RefCounted) -> bool:
	error=""
	if _selected40_world==null or not is_instance_of(owner,load("res://src/simulation/selected40_sequence.gd")) or owner.world_owner()==null or owner.world_owner().npc_construction_owner()!=_selected40_world.npc_construction_owner():return reject("Selected40 sequence changed its generated cast")
	var reaction: RefCounted=null if _provocation==null else _provocation.fork_for_frame()
	if reaction!=null and not reaction.apply_selected40_sequence(owner):return reject(reaction.error)
	var history: RefCounted=null if _reputation==null else _reputation.fork_for_frame()
	if history!=null and not history.apply_selected40_sequence(owner):return reject(history.error)
	for id in owner.snapshot().frame.actor_commands:
		if id not in [0,9,10,11,12]:return reject("Selected40 sequence changed an unrelated actor")
		if not _writable(id).apply_selected40_sequence(owner):return reject(_actors[id].error)
	_provocation=reaction;_reputation=history
	return true

## Called transactionally by the native controller before any actor update.
## Projectile/mixed-contact admission is deliberately a separate capability.
func _configure_selected40_consequences(bindings: RefCounted,catalogues: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	error=""
	if _selected40_world==null or _provocation!=null or _activated:return reject("Prepare selected40 reactions once before the first actor update")
	var data: Dictionary=load("res://src/content/selected40_population_definitions.gd").consequence_profile(bindings,catalogues,scenery,equipment)
	if data.is_empty() or not load("res://src/content/selected40_population_definitions.gd").matches_world(scenery,_selected40_world):return reject("Selected40 reactions belong to another generated world")
	var reaction:=Provocation.new();var history:=Reputation.new()
	if not reaction.configure_selected40(bindings,catalogues,scenery,equipment,reputation) or not history.configure_selected40(bindings,catalogues,scenery,equipment):return reject(reaction.error+history.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Selected40 consequences lack the ordinary hit policy")
	_hit_policy=policy.duplicate(true);_provocation=reaction;_reputation=history;_training_weapons=data;_reputation_rules=data.standing
	_contact_random=_selected40_world.snapshot().random_state.duplicate()
	return true

func apply_selected40_guidance(decision: Dictionary) -> bool:
	error=""
	var id: Variant=decision.get("actor_id")
	if _selected40_world==null or not id is int or id<1 or id>=_actors.size():return reject("Selected40 guidance requires its retained fighter")
	if not decision.get("activation") is String or not decision.activation.is_empty():return reject("Selected40 reserve activation requires its unfinished choreography owner")
	if not _writable(id).apply_story_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func configure(bindings: RefCounted, catalogues: RefCounted, difficulty: Variant) -> bool:
	clear()
	if bindings == null or catalogues == null: return reject("Opening combat group requires source content")
	var initial: Variant = bindings.opening_actors.get("npc_initialization",{})
	if not initial is Dictionary: return reject("Invalid NPC initialization scope")
	var activation: Variant = initial.get("activation",{})
	if not activation is Dictionary or not Activation.parameters(activation): return reject("Source opening activation is unavailable")
	var rows: Variant = bindings.opening_actors.get("actors")
	if not rows is Array or rows.is_empty(): return reject("Source opening actor population is unavailable")
	var actors := []
	for id in rows.size():
		var actor := Actor.new()
		if not actor.configure(bindings,catalogues,id,difficulty): return reject(actor.error)
		actors.append(actor)
	for id in activation.actor_ids:
		if int(id)>=actors.size(): return reject("Activation names an absent opening actor")
	var events: Variant = bindings.opening_dialogue.get("events")
	if not events is Array or activation.after_event_finished>=events.size(): return reject("Activation event is outside the source radio sequence")
	if bindings.opening_camera.get("pan",{}).get("engagement_after_event_finished") != activation.after_event_finished:
		return reject("Actor activation and camera engagement gates disagree")
	var hit_policy: Variant = bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(hit_policy): return reject("Invalid NPC weapon hit policy")
	_hit_policy = hit_policy.duplicate(true)
	_owned={};_actors = actors
	_activation = activation.duplicate(true)
	_activation.actor_ids = []
	for id in activation.actor_ids: _activation.actor_ids.append(int(id))
	_identity = {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_event_count = events.size()
	return _configure_reputation(bindings,0,difficulty)

func configure_full_hold(bindings: RefCounted, catalogues: RefCounted, construction: RefCounted, difficulty: Variant) -> bool:
	clear()
	var actor:=Actor.new()
	if not actor.configure_full_hold(bindings,catalogues,construction,difficulty):return reject(actor.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Second pirate lacks the ordinary NPC weapon hit policy")
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(bindings.full_hold_pirate.campaign_cursor)}
	_owned={};_actors=[actor];_hit_policy=policy.duplicate(true)
	return _configure_reputation(bindings,4,difficulty)


func configure_combat_training(bindings: RefCounted, catalogues: RefCounted, world: RefCounted, rank: Variant, difficulty: Variant) -> bool:
	clear()
	var actors:=[]
	for id in 4:
		var actor:=Actor.new()
		if not actor.configure_combat_training(bindings,catalogues,world,id,rank,difficulty):return reject(actor.error)
		actors.append(actor)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Combat training lacks the ordinary NPC weapon hit policy")
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":7}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true)
	if TrainingWeapons.parameters(bindings.combat_training_weapons):_training_weapons=bindings.combat_training_weapons.duplicate(true)
	return _configure_reputation(bindings,7,difficulty)

func apply_combat_training_guidance(data: Dictionary, decision: Dictionary) -> bool:
	error=""
	var id: Variant=decision.get("actor_id")
	if _identity.get("campaign_cursor")!=7 or _actors.size()!=4 or not id is int or id<0 or id>=_actors.size():return reject("Combat-training activity names an unavailable actor")
	if not _writable(id).apply_combat_training_guidance(data,decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func configure_local_patrol(bindings: RefCounted, catalogues: RefCounted, world: RefCounted, rank: Variant, difficulty: Variant) -> bool:
	clear()
	if world==null:return reject("Local patrol requires its generated world")
	var data:=Travel.population(bindings,world.snapshot(),rank,difficulty)
	if data.is_empty():return reject("Local patrol requires its verified population")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_local_patrol(bindings,catalogues,world,id,rank,difficulty):return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors
	return _configure_reputation(bindings,int(data.campaign_cursor),difficulty)

func _configure_reputation(bindings: RefCounted, cursor: int, difficulty: Variant, ordinary_void_system_id: Variant=null, ordinary_void_rank: Variant=null, native_cast: Dictionary={}) -> bool:
	if not Reputation.available(bindings):return true
	var history:=Reputation.new()
	var kinds:=_actors.map(func(actor):return int(actor.snapshot().actor_kind))
	if native_cast.is_empty() and _training_weapons.has("mission_recipe"):native_cast=_training_weapons
	if not history.configure(bindings,cursor,kinds,difficulty,_training_weapons.has("kappa_lifecycle"),ordinary_void_system_id,ordinary_void_rank,not _bakka_encounter.is_empty(),native_cast):return reject(history.error)
	_reputation=history
	return true

func configure_local_traffic(bindings: RefCounted, catalogues: RefCounted, world: RefCounted, rank: Variant, difficulty: Variant, equipment: RefCounted, reputation: Dictionary) -> bool:
	if not configure_local_patrol(bindings,catalogues,world,rank,difficulty):return false
	var reaction:=Provocation.new()
	if not reaction.configure(bindings,catalogues,world.snapshot(),rank,difficulty,equipment,reputation):clear();return reject(reaction.error)
	var weapons:=Travel.weapons(bindings,world.snapshot(),rank,difficulty)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if weapons.is_empty() or not HitDefinitions.parameters(policy):clear();return reject("Local combat lacks verified weapons and normal-hit rules")
	for id in _actors.size():
		if not _writable(id).enable_local_combat():clear();return reject(_actors[id].error)
	_provocation=reaction;_training_weapons=weapons;_hit_policy=policy.duplicate(true)
	_reputation_rules=bindings.mido_travel.reputation.duplicate(true)
	return true

func has_local_reactions() -> bool:return _provocation!=null

func configure_convoy(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	clear()
	if not construction is NPCConstruction:return reject("Convoy combat requires its generated encounter")
	var data:=Convoy.lifecycle(bindings,construction.snapshot())
	if data.is_empty():return reject("Unsupported convoy combat lifecycle")
	var reaction:=Provocation.new()
	if not reaction.configure_convoy(bindings,catalogues,construction,equipment,reputation):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Convoy combat lacks the ordinary hit policy")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_convoy(bindings,catalogues,construction,id) or not actor.enable_convoy_combat():return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_provocation=reaction;_training_weapons=data
	_reputation_rules=bindings.mido_travel.convoy_lifecycle.terran_hostility.duplicate(true)
	if not _configure_reputation(bindings,int(data.campaign_cursor),data.difficulty):
		var reason:=error;clear();return reject(reason)
	return true

func _configure_story(bindings: RefCounted,catalogues: RefCounted,data: Dictionary,equipment: RefCounted,reputation: Dictionary) -> bool:
	clear()
	var reaction:=Provocation.new()
	if not reaction._configure_story(bindings,catalogues,data,equipment,reputation):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Story combat lacks the ordinary hit policy")
	var actors:=[]
	for row in data.actor_rows:
		var actor:=Actor.new()
		if not actor._configure_story(bindings,data,row):return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_provocation=reaction;_training_weapons=data
	_reputation_rules=data.standing
	return _configure_reputation(bindings,int(data.campaign_cursor),data.difficulty,data.get("source_system_id") if data.get("ordinary_void",false) else null,data.get("rank") if data.get("ordinary_void",false) else null)

func apply_story_guidance(decision: Dictionary) -> bool:
	var id: Variant=decision.get("actor_id")
	if not _training_weapons.get("authored_story",false) or not id is int or id<0 or id>=_actors.size():return reject("Story guidance names an unavailable actor")
	if not _writable(id).apply_story_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func configure_alioth_attack(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	clear()
	if not construction is NPCConstruction:return reject("Alioth combat requires its generated encounter")
	var data:=Alioth.lifecycle(bindings,construction.snapshot())
	if data.is_empty():return reject("Unsupported Alioth combat lifecycle")
	var reaction:=Provocation.new()
	if not reaction.configure_alioth_attack(bindings,catalogues,construction,equipment,reputation):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Alioth combat lacks the ordinary hit policy")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_alioth_attack(bindings,catalogues,construction,id) or not actor.enable_alioth_combat():return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_provocation=reaction;_training_weapons=data
	if not _configure_reputation(bindings,int(data.campaign_cursor),data.difficulty):
		var reason:=error;clear();return reject(reason)
	return true

func apply_alioth_guidance(decision: Dictionary) -> bool:
	var id: Variant=decision.get("actor_id")
	if not _training_weapons.has("alioth_lifecycle") or not id is int or id<0 or id>=_actors.size():return reject("Alioth guidance names an unavailable actor")
	if not _writable(id).apply_alioth_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func configure_kappa_rescue(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,reputation: Dictionary) -> bool:
	clear()
	if not construction is NPCConstruction:return reject("Kappa combat requires its generated encounter")
	var data:=Kappa.lifecycle(bindings,construction.snapshot())
	if data.is_empty():return reject("Unsupported Kappa combat lifecycle")
	var reaction:=Provocation.new()
	if not reaction.configure_kappa_rescue(bindings,catalogues,construction,reputation):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Kappa combat lacks the ordinary hit policy")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_kappa_rescue(bindings,catalogues,construction,id) or not actor.enable_kappa_combat():return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_provocation=reaction;_training_weapons=data
	_reputation_rules=data.kappa_lifecycle.terran_hostility.duplicate(true)
	if not _configure_reputation(bindings,int(data.campaign_cursor),data.difficulty):
		var reason:=error;clear();return reject(reason)
	return true

func apply_kappa_guidance(decision: Dictionary) -> bool:
	var id: Variant=decision.get("actor_id")
	if not _training_weapons.has("kappa_lifecycle") or not id is int or id<0 or id>=_actors.size():return reject("Kappa guidance names an unavailable actor")
	if not _writable(id).apply_kappa_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func advance_systems(actor_id: int,delta_ms: Variant) -> bool:
	if actor_id<0 or actor_id>=_actors.size():return reject("Systems update names an unavailable actor")
	if not _writable(actor_id).advance_systems(delta_ms):return reject(_actors[actor_id].error)
	return true

func systems_for_frame(actor_id: int) -> RefCounted:
	if actor_id<0 or actor_id>=_actors.size():reject("Systems update names an unavailable actor");return null
	return _actors[actor_id].systems_for_frame()

func apply_kappa_sequence(owner: RefCounted) -> bool:
	if not _training_weapons.has("kappa_lifecycle"):return reject("This group has no Kappa sequence")
	var next: RefCounted=_provocation.fork_for_frame()
	if not next.apply_kappa_sequence(owner):return reject(next.error)
	var actors:=_reaction_actors(next,_actors)
	if actors.is_empty():return false
	_owned={};_actors=actors;_provocation=next
	return true

func systems_hit(actor_id: Variant,amount: Variant,nonplayer_source: Variant=false) -> Dictionary:
	if _selected40_world!=null and _provocation==null:reject("Selected40 group consequences are not prepared");return {}
	error=""
	if _provocation==null or _reputation==null or not actor_id is int or actor_id<0 or actor_id>=_actors.size():reject("Systems hit names an unavailable actor");return {}
	var actor: RefCounted=_actors[actor_id].fork_for_frame()
	var reaction: Dictionary=_provocation.evaluate_systems(actor.snapshot(),amount,nonplayer_source,_contact_random,_display_available)
	if reaction.is_empty():reject(_provocation.error);return {}
	var result: Dictionary=actor.systems_hit(amount)
	if result.is_empty():reject(actor.error);return {}
	var history: RefCounted=_reputation.fork_for_frame()
	if reaction.depleted_by_player and not history.record_systems_depletion(actor.snapshot(),result):reject(history.error);return {}
	var staged:=_actors.duplicate();staged[actor_id]=actor
	var actors:=_reaction_actors(reaction.owner,staged)
	if actors.is_empty():return {}
	_owned={};_actors=actors;_provocation=reaction.owner;_reputation=history;_contact_random=reaction.random_state
	result.reactions=reaction.events.duplicate(true)
	result.first_disable_by_player=reaction.first_disable_by_player
	return result

func _reaction_actors(reaction: RefCounted,actors: Array) -> Array:
	var state: Dictionary=reaction.snapshot();var result:=[]
	for id in actors.size():
		var actor: RefCounted=actors[id].fork_for_frame()
		if actor.snapshot().get("contract_debris",false) or actor.snapshot().get("static_object",false):result.append(actor);continue
		if _training_weapons.has("kappa_lifecycle"):
			if not actor.retain_kappa_force(state.forced_hostile[id],state.permanent_hostile[id]):reject(actor.error);return []
		elif state.has("systems_requested_damage") and state.has("permanent_hostile"):
			if not actor.retain_ordinary_force(state.forced_hostile[id],state.permanent_hostile[id]):reject(actor.error);return []
		else:
			if not actor.retain_local_force(state.forced_hostile[id]):reject(actor.error);return []
		result.append(actor)
	return result

func alioth_actor_context() -> Dictionary:
	if not _training_weapons.has("alioth_lifecycle"):return {}
	var result:=_identity.duplicate()
	result.actors=[]
	for owner in _actors:
		var actor: Dictionary=owner.snapshot()
		actor.current_hull=int(actor.vitals.hull)
		result.actors.append(actor)
	return result

func kappa_actor_context() -> Dictionary:
	if not _training_weapons.has("kappa_lifecycle"):return {}
	var result:=_identity.duplicate()
	result.actors=_actors.map(func(owner):return owner.kappa_observation())
	return result

func apply_alioth_sequence(owner: RefCounted) -> bool:
	error=""
	if not _training_weapons.has("alioth_lifecycle"):return reject("This group has no Alioth sequence")
	var actors:=[]
	for actor in _actors:
		var next: RefCounted=actor.fork_for_frame()
		if not next.apply_alioth_retirement(owner):return reject(next.error)
		actors.append(next)
	_owned={};_actors=actors
	return true

func apply_convoy_guidance(decision: Dictionary) -> bool:
	var id: Variant=decision.get("actor_id")
	if not _training_weapons.has("capital_death") or not id is int or id<0 or id>=_actors.size():return reject("Convoy guidance names an unavailable actor")
	if not _writable(id).apply_convoy_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func apply_convoy_capture(owner: RefCounted) -> bool:
	error=""
	if not _training_weapons.has("capital_death"):return reject("This group has no convoy capture owner")
	var actors:=[]
	for actor in _actors:
		var next: RefCounted=actor.fork_for_frame()
		if not next.apply_convoy_capture(owner):return reject(next.error)
		actors.append(next)
	_owned={};_actors=actors
	return true

func configure_contract(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,equipment: RefCounted) -> bool:
	clear()
	if not construction is NPCConstruction:return reject("Contract combat requires its accepted generated population")
	var data:=ContractLife.population(bindings,construction.snapshot(),construction.mission_context_owner())
	if data.is_empty():return reject("Unsupported contract combat lifecycle")
	var reaction: RefCounted
	var debris: bool=data.actors.all(func(row):return row.population_group=="debris")
	if debris:
		if equipment==null or equipment.snapshot().get("loadout",{}).get("station_id")!=int(data.station_id):return reject("Debris combat belongs to another equipped location")
	else:
		reaction=Provocation.new()
		if not reaction.configure_contract(bindings,catalogues,construction,equipment):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Contract combat lacks the ordinary hit policy")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_contract(bindings,catalogues,construction,id) or not actor.enable_contract_combat(bindings):return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_provocation=reaction;_training_weapons=data
	_contract_encounter=construction.snapshot().contract_encounter.duplicate(true)
	var native_cast:={"campaign_cursor":data.campaign_cursor,"actor_rows":data.actors,"context":{"system_id":construction.mission_context_owner().recipe().system_id}}
	if not debris and not _configure_reputation(bindings,int(data.campaign_cursor),data.difficulty,null,null,native_cast):
		var reason:=error;clear();return reject(reason)
	return true

func configure_bakka(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	clear()
	if not construction is NPCConstruction:return reject("B'akka combat requires its generated story population")
	var data:=BakkaCombat.population(bindings,construction.snapshot())
	if data.is_empty():return reject("Unsupported B'akka combat population")
	var reaction:=Provocation.new()
	if not reaction.configure_bakka(bindings,catalogues,construction,equipment,reputation):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("B'akka combat lacks the ordinary hit policy")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_bakka(bindings,catalogues,construction,id) or not actor.enable_bakka_combat(bindings):return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":36}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_training_weapons=data;_provocation=reaction
	_bakka_encounter=construction.snapshot().bakka_encounter.duplicate(true)
	if not _configure_reputation(bindings,36,data.difficulty):
		var reason:=error;clear();return reject(reason)
	return true

func apply_contract_guidance(decision: Dictionary) -> bool:
	var id: Variant=decision.get("actor_id")
	if _contract_encounter.is_empty() or not id is int or id<0 or id>=_actors.size():return reject("Contract guidance names an unavailable actor")
	if not _writable(id).apply_contract_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func apply_bakka_guidance(decision: Dictionary) -> bool:
	var id: Variant=decision.get("actor_id")
	if _bakka_encounter.is_empty() or not id is int or id<0 or id>=_actors.size():return reject("B'akka guidance names an unavailable actor")
	if not _writable(id).apply_bakka_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func relaunch_ambient(actor_id: int,bindings: RefCounted,death_owner: RefCounted=null,origin: Vector3=Vector3.ZERO) -> bool:
	error=""
	if _provocation==null or actor_id<0 or actor_id>=_actors.size():return reject("Traffic launch requires its configured combat group")
	var actor: RefCounted=_actors[actor_id].fork_for_frame()
	var reaction: RefCounted=_provocation.fork_for_frame()
	if not actor.relaunch_ambient(bindings,death_owner,origin):return reject(actor.error)
	if not reaction.reset_actor_damage(actor_id):return reject(reaction.error)
	var reactions: Dictionary=reaction.snapshot()
	if reactions.has("systems_requested_damage") and not actor.retain_ordinary_force(reactions.forced_hostile[actor_id],reactions.permanent_hostile[actor_id]):return reject(actor.error)
	var history: RefCounted=_reputation.fork_for_frame()
	if actor.snapshot().has("spawn_generation") and not history.register_relaunch(actor.snapshot()):return reject(history.error)
	_actors[actor_id]=actor;_provocation=reaction
	_reputation=history
	return true

func apply_ambient_guidance(decision: Dictionary) -> bool:
	error=""
	var id: Variant=decision.get("actor_id")
	if not id is int or id<0 or id>=_actors.size():return reject("Ambient decision names an unavailable actor")
	if not _writable(id).apply_ambient_guidance(decision):return reject(_actors[id].error)
	return true

func apply_ambient_departure_pose(actor_id: int,root: Variant) -> bool:
	error=""
	if actor_id<0 or actor_id>=_actors.size():return reject("Departure names an unavailable actor")
	if not _writable(actor_id).apply_ambient_departure_pose(root):return reject(_actors[actor_id].error)
	return true

func configure_ambient(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,rank: Variant,difficulty: Variant,equipment: RefCounted,reputation: Dictionary) -> bool:
	clear()
	if not construction is NPCConstruction:return reject("Ambient combat requires its generated construction")
	var data:=AmbientCombat.population(bindings,construction.snapshot(),rank,difficulty)
	if data.is_empty() or not TrainingWeapons.parameters(bindings.combat_training_weapons):return reject("Ambient combat lacks supported population and primary-hit declarations")
	if data.has("free_traffic"):
		data=FreeLife.population(bindings,construction.snapshot())
		if data.is_empty():return reject("Ordinary free-flight combat requires its verified lifecycle")
	var reaction:=Provocation.new()
	if not reaction.configure_ambient(bindings,catalogues,construction,rank,difficulty,equipment,reputation):return reject(reaction.error)
	var policy: Variant=bindings.weapon_parameters.get("ordinary_hit_policy",{})
	if not HitDefinitions.parameters(policy):return reject("Ambient combat lacks the ordinary hit policy")
	var actors:=[]
	for id in int(data.actor_count):
		var actor:=Actor.new()
		if not actor.configure_ambient(bindings,catalogues,construction,id,rank,difficulty) or not actor.enable_local_combat():return reject(actor.error)
		var retained: Dictionary=reaction.snapshot()
		if retained.has("permanent_hostile") and not actor.retain_ordinary_force(retained.forced_hostile[id],retained.permanent_hostile[id]):return reject(actor.error)
		actors.append(actor)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(data.campaign_cursor)}
	_owned={};_actors=actors;_hit_policy=policy.duplicate(true);_provocation=reaction
	_training_weapons=data.duplicate(true) if data.has("free_lifecycle") else {"scope":"mido_ambient_ordinary_weapons","campaign_cursor":int(data.campaign_cursor)}
	_reputation_rules=data.free_lifecycle.standing.duplicate(true) if data.has("free_lifecycle") else bindings.mido_travel.reputation.duplicate(true)
	if not _configure_reputation(bindings,int(data.campaign_cursor),difficulty):
		var reason:=error;clear();return reject(reason)
	return true

func begin_contact_pass(random_state: Dictionary, display_available: bool) -> bool:
	if _selected40_world!=null and _provocation==null:return reject("Selected40 consequences require complete native owners")
	error=""
	if _provocation==null and _contract_encounter.is_empty():return reject("This encounter does not use local provocation")
	var random:=Random.new()
	if not random.restore(random_state):return reject(random.error)
	_contact_random=random.snapshot();_display_available=display_available
	if _provocation!=null and _provocation.snapshot().get("arrival_response_pending",false):
		var arrival: Dictionary=_provocation.evaluate_arrival(_contact_random,display_available)
		if arrival.is_empty():return reject(_provocation.error)
		_provocation=arrival.owner;_contact_random=arrival.random_state
	return true

func contact_random_state() -> Dictionary:return _contact_random.duplicate(true)

## The standing hostility reads: the career's, or a fitted signature's.
func hostility_reputation() -> Dictionary:
	var standing:=current_reputation()
	var axes: Array=_provocation.signature_axes(int(_provocation.snapshot().get("signature_race",-1))) if _provocation!=null else []
	if not axes.is_empty() and not standing.is_empty():standing.axes=axes.duplicate()
	return standing

func current_reputation() -> Dictionary:
	var standing:=_current_reputation()
	if not _story_standing.is_empty() and not standing.is_empty() and int(_story_standing.axis)>=0:standing.axes[int(_story_standing.axis)]=int(_story_standing.value)
	return standing

## The story turns every contract ship hostile and fixes one faction standing.
func apply_story_hostility(axis: int,value: int) -> bool:
	error=""
	# Axis -1 turns the cast hostile without changing any faction standing.
	if _contract_encounter.is_empty() or axis not in [-1,0,1] or value<-100 or value>100:return reject("Story hostility requires a contract cast and a valid standing")
	for id in _actors.size():
		if _actors[id].snapshot().get("contract_ship",false) and not _writable(id).apply_story_hostility():return reject(_actors[id].error)
	_story_standing={"axis":axis,"value":value}
	return true

func story_hostility_applied() -> bool:return not _story_standing.is_empty()

## Story ships that give up keep flying but never fire again.
func disarm_story_actors(first: int,end: int) -> bool:
	error=""
	if _contract_encounter.is_empty() or first<0 or end>_actors.size() or end<=first:return reject("Story disarm requires contract ships")
	for id in range(first,end):
		var actor: Dictionary=_actors[id].snapshot()
		if actor.get("contract_ship",false) and not _writable(id).set_permissions(actor.active,actor.damage_allowed,false):return reject(_actors[id].error)
	return true

## Story ships that surrender stop being hostile and stop firing.
func stand_down_story_actors(first: int,end: int) -> bool:
	error=""
	if _contract_encounter.is_empty() or first<0 or end>_actors.size() or end<=first:return reject("Story surrender requires contract ships")
	for id in range(first,end):
		var actor: Dictionary=_actors[id].snapshot()
		if actor.get("contract_ship",false) and int(actor.vitals.hull)>0 and not _writable(id).stand_down_story():return reject(_actors[id].error)
	return true

## A story ship or object leaves the scene: inactive, unharmable, silent.
func retire_story_actor(id: int) -> bool:
	error=""
	if _contract_encounter.is_empty() or id<0 or id>=_actors.size():return reject("Story retirement requires contract ships")
	# A ship goes back to sleep where it is parked, so a later story
	# placement can wake it again (92: the cloaked ships return).
	if not _actors[id].snapshot().get("static_object",false):
		if not _writable(id).sleep_story():return reject(_actors[id].error)
		return true
	if not _writable(id).set_permissions(false,false,false):return reject(_actors[id].error)
	if not _writable(id).hide_static():return reject(_actors[id].error)
	return true

## Story actions on a range of actors: "destroy" (hull to 0) or "show" (a
## hidden static object appears).
func story_actor_action(first: int,end: int,action: String) -> bool:
	error=""
	if _contract_encounter.is_empty() or first<0 or end>_actors.size() or end<=first:return reject("Story actions require contract ships")
	for id in range(first,end):
		var done: bool=_writable(id).destroy_story() if action=="destroy" else _writable(id).show_static() if action=="show" else false
		if not done:return reject(_actors[id].error if not _actors[id].error.is_empty() else "Unknown story action "+action)
	return true

func revive_story_actor(id: int) -> bool:
	error=""
	if _contract_encounter.is_empty() or id<0 or id>=_actors.size():return reject("Story respawn requires contract ships")
	if not _writable(id).revive_story():return reject(_actors[id].error)
	return true

func set_story_cloak(id: int,cloaked: bool) -> bool:
	error=""
	if _contract_encounter.is_empty() or id<0 or id>=_actors.size():return reject("Story cloaking requires contract ships")
	if bool(_actors[id].snapshot().get("cloaked",false))==cloaked:return true
	if not _writable(id).set_story_cloak(cloaked):return reject(_actors[id].error)
	return true

func wake_story_actors(first: int,end: int) -> bool:
	error=""
	if _contract_encounter.is_empty() or first<0 or end>_actors.size() or end<=first:return reject("Story wake requires contract ships")
	for id in range(first,end):
		if not _writable(id).wake_story():return reject(_actors[id].error)
	return true

func _current_reputation() -> Dictionary:
	if _provocation==null and not _contract_encounter.is_empty():
		return _contract_settlement.reputation.duplicate(true) if not _contract_settlement.is_empty() else _contract_encounter.context.reputation.duplicate(true)
	if _provocation==null:return {}
	if not _contract_settlement.is_empty():return _reputation.apply_to(_contract_settlement.reputation,int(_contract_settlement.event_count))
	return reputation_after(_provocation.snapshot().initial_reputation)

func open_contract_result(bindings: RefCounted,mode: int) -> bool:
	error=""
	if _contract_encounter.is_empty() or not _contract_settlement.is_empty() or not ContractResults.available(bindings):return reject("This combat group has no unsettled contract result")
	if bindings.base_content_id!=_identity.base_content_id or bindings.binding_id!=_identity.binding_id:return reject("Contract result belongs to another content identity")
	var rules: Dictionary=bindings.early_contracts.flight_results
	if mode not in [int(rules.success_result_mode),int(rules.failure_result_mode)]:return reject("Unsupported contract result mode")
	var context: Dictionary=_contract_encounter.context
	var standing:=current_reputation()
	if mode==int(rules.success_result_mode):
		standing=ContractResults.standing_after(bindings.early_contracts,standing,int(context.mission.kind),int(context.client_faction),float(context.difficulty))
	if standing.is_empty():return reject("The contract lost its faction standing")
	# Retain lethal history, but apply future hits after the result bonus. This
	# matters at the reputation caps: replaying the old hits would change it twice.
	_contract_settlement={"mode":mode,"retired":false,"reputation":standing,"event_count":0 if _reputation==null else _reputation.snapshot().events.size()}
	return true

func retire_contract_result() -> bool:
	error=""
	if _contract_settlement.is_empty() or _contract_settlement.retired:return reject("No contract result awaits retirement")
	if _provocation!=null and not _provocation.retire_contract():return reject(_provocation.error)
	_contract_settlement.retired=true
	return true

func reputation_after(prior: Dictionary) -> Dictionary:
	error=""
	if _reputation==null:reject("This encounter has no retained reputation hit history");return {}
	var result: Dictionary=_reputation.apply_to(prior)
	if result.is_empty():reject(_reputation.error)
	return result

## Called on the staged combat branch after the native hold accepts its one
## transfer. World and career observe the same accepted quantity, not inventory
## stack deltas. A failed enclosing frame discards this branch, including faction
## changes that precede capacity acceptance in the original transaction.
func record_cargo_recovery(actor: Dictionary,events: Array) -> bool:
	var totals:=recovery_totals()
	for event in events:
		match event.kind:
			"faction_cargo_taken":
				if _reputation==null:return reject("Cargo recovery has no retained faction history")
				if not _reputation.record_cargo_recovery(actor):return reject(_reputation.error)
			"world_cargo_quantity":
				if totals.accepted_quantity>2147483647-event.quantity:return reject("Recovered cargo exceeds the source counter range")
				totals.accepted_quantity+=event.quantity
			"friendly_cargo_taken":totals.friendly_cargo_taken=true
			"kind9_cargo_quantity":
				if totals.kind9_quantity>2147483647-event.quantity:return reject("Recovered Void cargo exceeds the source counter range")
				totals.kind9_quantity+=event.quantity
			"item_recovery_flag":
				if not totals.item_flags.has(event.index):totals.item_flags.append(event.index)
	_recovery_totals=totals
	return true

func recovery_totals() -> Dictionary:
	return (EMPTY_RECOVERY if _recovery_totals.is_empty() else _recovery_totals).duplicate(true)

func apply_local_patrol_guidance(decision: Dictionary) -> bool:
	error=""
	var id: Variant=decision.get("actor_id")
	if _identity.get("campaign_cursor")!=10 or not id is int or id<0 or id>=_actors.size():return reject("Local patrol activity names an unavailable actor")
	if not _writable(id).apply_local_patrol_guidance(decision):return reject(_actors[id].error)
	_activated=_activated or bool(_actors[id].snapshot().active)
	return true

func apply_full_hold_guidance(data: Dictionary, decision: Dictionary) -> bool:
	error=""
	if _identity.get("campaign_cursor")!=4 or _actors.size()!=1:return reject("This group has no second-trip activity context")
	if not _writable(0).apply_full_hold_guidance(data,decision):return reject(_actors[0].error)
	_activated=_activated or bool(_actors[0].snapshot().active)
	return true

func apply_full_hold_appearance(data: Dictionary, root: Variant, statistics: Variant) -> bool:
	error=""
	if _identity.get("campaign_cursor")!=4 or _actors.size()!=1:return reject("This group has no second-trip appearance context")
	if not _writable(0).apply_full_hold_appearance(data,root,statistics):return reject(_actors[0].error)
	_activated=true
	return true

func configure_escape(bindings: RefCounted) -> bool:
	error=""
	if _activation.is_empty() or _escape_enabled or _phase>0 or bindings==null or bindings.binding_id!=_identity.get("binding_id") or not EscapeCamera.parameters(bindings.opening_staging.get("escape_camera",{})):
		return reject("Escape actor lifecycle requires matching fresh declarations")
	_escape_enabled=true
	return true

func update(scene: Variant, phase: Variant, preceding_radio: Variant) -> bool:
	error = ""
	if _actors.is_empty() or _activation.is_empty(): return reject("This combat group has no Opening radio activation owner")
	if not Numbers.integer(phase,0,16 if _escape_enabled else 4) or phase<_phase: return reject("Opening combat phase is invalid or regressed")
	if not preceding_radio is Dictionary: return reject("Opening activation requires preceding radio state")
	for key in _identity:
		if preceding_radio.get(key)!=_identity[key]: return reject("Activation radio belongs to another content identity")
	var finished: Variant = preceding_radio.get("finished")
	if not finished is Array or finished.size()!=_event_count: return reject("Activation radio completion flags are unavailable")
	for done in finished:
		if not done is bool: return reject("Invalid activation radio completion flag")
	if phase>4:
		if not _activated or not finished[10]:return reject("Escape precedes its earned encounter radio")
		for actor in _actors:
			if actor.snapshot().vitals.hull>0:return reject("Escape cannot bypass a surviving opening actor")
	var activate_now: bool = not _activated and phase>=int(_activation.phase)
	if activate_now and not finished[int(_activation.after_event_finished)]: return reject("Opening activation precedes its source radio gate")
	var staged := []
	for actor in _actors:
		var next: RefCounted = actor.fork_for_frame()
		if not next.apply_scene(scene): return reject(next.error)
		if activate_now and next.snapshot().actor_id in _activation.actor_ids:
			if not next.apply_activation(_activation): return reject(next.error)
		staged.append(next)
	_owned={};_actors = staged
	_phase = int(phase)
	_activated = _activated or activate_now
	return true

func snapshot() -> Dictionary:
	if _identity.is_empty(): return {}
	var result := career_snapshot()
	result.activated = _activated
	result.phase = _phase
	result.actors = actor_snapshots()
	if _training_weapons.get("ordinary_void",false):result.ordinary_void=true
	if _training_weapons.has("free_lifecycle"):result.free_context=_training_weapons.free_context.duplicate(true)
	return result

## Detached accounting and encounter identity, without copying actor poses.
func career_snapshot() -> Dictionary:
	if _identity.is_empty():return {}
	var result:=_identity.duplicate()
	if _training_weapons.get("context_key","")=="dekato_context":result.dekato_context=_training_weapons.context.duplicate(true)
	if _reputation!=null:result.reputation=_reputation.snapshot()
	elif not _contract_encounter.is_empty():result.reputation={"events":[]};result.current_reputation=current_reputation()
	if _provocation!=null:
		result.provocation=_provocation.snapshot();result.current_reputation=current_reputation()
	if not _contract_encounter.is_empty():result.contract_encounter=_contract_encounter.duplicate(true)
	if not _bakka_encounter.is_empty():result.bakka_encounter=_bakka_encounter.duplicate(true)
	if not _contract_settlement.is_empty():result.contract_settlement=_contract_settlement.duplicate(true)
	if not _recovery_totals.is_empty():result.recovery=_recovery_totals.duplicate(true)
	if not _lethal_items.is_empty():result.lethal_items=_lethal_items.duplicate(true)
	return result

func actor_snapshot(actor_id: int) -> Dictionary:
	if actor_id<0 or actor_id>=_actors.size():reject("Observation names an unavailable actor");return {}
	return _actors[actor_id].snapshot()

func actor_snapshots() -> Array:
	var result:=[]
	for actor in _actors:result.append(actor.snapshot())
	return result

func normal_hit(actor_id: Variant, amount: Variant, nonplayer_source: Variant=false, item_id:=-1) -> Dictionary:
	error = ""
	if _selected40_world!=null and _provocation==null:reject("Selected40 group consequences are not prepared");return {}
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size():
		reject("Normal hit names an unavailable opening actor")
		return {}
	var actor: RefCounted=_actors[actor_id].fork_for_frame()
	var reaction:={}
	if _provocation!=null and not actor.snapshot().get("contract_debris",false) and not actor.snapshot().get("static_object",false):
		reaction=_provocation.evaluate(actor.snapshot(),amount,nonplayer_source,_contact_random,_display_available)
		if reaction.is_empty():reject(_provocation.error);return {}
	var result: Dictionary = actor.normal_hit(amount,nonplayer_source)
	if result.is_empty():reject(actor.error);return {}
	var history: RefCounted=_reputation
	if result.destroyed_now and _reputation!=null and not actor.snapshot().get("contract_debris",false) and not actor.snapshot().get("static_object",false):
		history=_reputation.fork_for_frame()
		if not history.record_lethal(actor.snapshot()):reject(history.error);return {}
	var staged:=_actors.duplicate();staged[actor_id]=actor
	if not reaction.is_empty():
		staged=_reaction_actors(reaction.owner,staged)
		if staged.is_empty():return {}
		_provocation=reaction.owner;_contact_random=reaction.random_state
		result.reactions=reaction.events.duplicate(true)
	if result.destroyed_now and item_id>=0 and not nonplayer_source:
		_lethal_items=_lethal_items+[{"actor_id":actor_id,"item_id":item_id,"population_group":actor.snapshot().get("population_group","")}]
	_owned={};_actors=staged;_reputation=history
	return result

## Repair beam healing (see repair_beams.gd).
func heal_hull(actor_id: int,amount: int) -> bool:
	if actor_id<0 or actor_id>=_actors.size() or amount<=0:return false
	return _writable(actor_id).heal_hull(amount)

func set_pose(actor_id: Variant, pose: Variant, physical_pose: Variant=null) -> bool:
	error=""
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size(): return reject("Pose names an unavailable opening actor")
	if not _writable(actor_id).set_pose(pose,physical_pose): return reject(_actors[actor_id].error)
	return true

func refresh_hostility(actor_id: Variant) -> bool:
	error=""
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size(): return reject("Hostility names an unavailable opening actor")
	if _provocation!=null:
		if not _bakka_encounter.is_empty():
			# The rival's authored friendship wins over the retained faction force
			# flags, as in the shared challenge ship update. Pirates stay hostile.
			if not _writable(actor_id).refresh_hostility():return reject(_actors[actor_id].error)
			return true
		if _training_weapons.has("kappa_lifecycle"):
			var state: Dictionary=_provocation.snapshot()
			if not _writable(actor_id).refresh_kappa_hostility(hostility_reputation(),state.forced_hostile[actor_id],state.permanent_hostile[actor_id],_reputation_rules):return reject(_actors[actor_id].error)
			return true
		if _training_weapons.has("free_lifecycle") or _training_weapons.get("authored_story",false):
			if not _writable(actor_id).apply_free_hostility(hostility_reputation(),_provocation.snapshot().forced_hostile[actor_id],_reputation_rules):return reject(_actors[actor_id].error)
			return true
		if _training_weapons.has("alioth_lifecycle"):
			if not _writable(actor_id).refresh_alioth_hostility(_provocation.snapshot().forced_hostile[actor_id]):return reject(_actors[actor_id].error)
			return true
		if _training_weapons.has("capital_death"):
			if not _writable(actor_id).refresh_convoy_hostility(hostility_reputation(),_provocation.snapshot().forced_hostile[actor_id],_reputation_rules):return reject(_actors[actor_id].error)
			return true
		if not _contract_encounter.is_empty():
			if not _writable(actor_id).refresh_contract_hostility(_provocation.snapshot().forced_hostile[actor_id],hostility_reputation(),_training_weapons.get("ordinary_standing",{})):return reject(_actors[actor_id].error)
			return true
		if not _writable(actor_id).apply_local_hostility(hostility_reputation(),_provocation.snapshot().forced_hostile[actor_id],_reputation_rules):return reject(_actors[actor_id].error)
		return true
	if not _writable(actor_id).refresh_hostility(): return reject(_actors[actor_id].error)
	return true

func apply_destruction(actor_id: Variant, death: Dictionary) -> bool:
	error=""
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size(): return reject("Destruction names an unavailable opening actor")
	if not _writable(actor_id).apply_destruction(death): return reject(_actors[actor_id].error)
	return true

func apply_freighter_destruction(actor_id: Variant,owner: RefCounted) -> bool:
	error=""
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size():return reject("Freighter destruction names an unavailable actor")
	if not _writable(actor_id).apply_freighter_destruction(owner):return reject(_actors[actor_id].error)
	return true

func apply_debris_destruction(actor_id: int,owner: RefCounted) -> bool:
	error=""
	if actor_id<0 or actor_id>=_actors.size():return reject("Debris destruction names an unavailable actor")
	if not _writable(actor_id).apply_debris_destruction(owner):return reject(_actors[actor_id].error)
	return true

func set_static_geometry(actor_id: int,boxes: Array) -> bool:
	error=""
	if actor_id<0 or actor_id>=_actors.size():return reject("Static geometry names an unavailable actor")
	if not _writable(actor_id).set_static_geometry(boxes):return reject(_actors[actor_id].error)
	return true

func set_turret_aim(actor_id: int,aim: Dictionary) -> bool:
	error=""
	if actor_id<0 or actor_id>=_actors.size():return reject("Turret aim names an unavailable actor")
	if not _writable(actor_id).set_turret_aim(aim):return reject(_actors[actor_id].error)
	return true

func wake_static(actor_id: int) -> bool:
	error=""
	if actor_id<0 or actor_id>=_actors.size():return reject("Static wake names an unavailable actor")
	if not _writable(actor_id).wake_static():return reject(_actors[actor_id].error)
	return true

func apply_static_destruction(actor_id: int,owner: RefCounted) -> bool:
	error=""
	if actor_id<0 or actor_id>=_actors.size():return reject("Static destruction names an unavailable actor")
	if not _writable(actor_id).apply_static_destruction(owner):return reject(_actors[actor_id].error)
	return true

func shooter_states() -> Array:
	error=""
	if _actors.is_empty():
		reject("Configure opening actors before reading shooter state")
		return []
	var result := []
	for actor in _actors:
		var state: Dictionary=actor.snapshot()
		if not state.get("hostile") is bool:
			reject("Current NPC hostility is unavailable")
			return []
		# Source guns retain their statistics owner even while it is inactive.
		result.append({"present":true,"hostile":state.hostile})
	return result

## Register only declarations resolved by the retained native companion pool.
## This extends the source weapon population, not the permitted damage policy.
func bind_wingman_primaries(owner: RefCounted) -> bool:
	if not is_instance_of(owner,load("res://src/simulation/opening_npc_weapons.gd")):return reject("Companion damage requires its native weapon owner")
	var declarations: Array=owner.wingman_primary_declarations()
	if declarations.is_empty() or declarations.size()>3:return reject("Companion primary declaration is absent")
	for weapon in declarations:
		for key in _identity:
			if weapon.get(key)!=_identity[key]:return reject("Companion weapons belong to another combat world")
		if weapon.get("nonplayer_source")!=true or weapon.get("ordinary_hit_policy",{}).get("additional_damage_required")!=false:return reject("Companion primary changed its ordinary damage policy")
	if not _wingman_primaries.is_empty() and _wingman_primaries!=declarations:return reject("Companion weapon declarations changed during combat")
	_wingman_primaries=declarations.duplicate(true)
	return true

func bind_wingman_systems(owner: RefCounted) -> bool:
	if not is_instance_of(owner,load("res://src/simulation/opening_npc_weapons.gd")):return reject("Companion systems damage requires its native weapon owner")
	var declarations: Array=owner.wingman_systems_declarations()
	if not owner.is_wingman_systems() or declarations.size()>3:return reject("Invalid companion systems population")
	for weapon in declarations:
		for key in _identity:
			if weapon.get(key)!=_identity[key]:return reject("Companion systems gun belongs to another combat world")
		if weapon.get("wingman_systems")!=true or weapon.get("nonplayer_source")!=true or weapon.get("item_id")!=18 or weapon.get("kind")!=1 or weapon.get("damage")!=0 or not weapon.get("ordinary_hit_policy",{}).get("additional_damage_required",false):return reject("Companion systems gun changed its damage policy")
	if not _wingman_systems.is_empty() and _wingman_systems!=declarations:return reject("Companion systems declarations changed during combat")
	_wingman_systems=declarations.duplicate(true)
	return true

func supports_weapon_hit(weapon: Variant) -> bool:
	if _selected40_world!=null and not has_local_reactions():return reject("Selected40 weapon contacts require complete consequence owners")
	var fitted: bool=weapon is Dictionary and preload("res://src/content/ordinary_fitting_definitions.gd").ordinary(weapon)
	var secondary: bool=weapon is Dictionary and preload("res://src/content/conventional_secondary_definitions.gd").resolved(weapon)
	var kinds: Array=[int(weapon.kind)] if fitted or secondary else [0]
	if weapon is Dictionary and (_wingman_primaries.has(weapon) or _wingman_systems.has(weapon)):
		kinds=[0,1]
	elif not _training_weapons.is_empty() and weapon is Dictionary:
		if weapon.get("nonplayer_source",false)==true:
			var valid: bool=Story.npc_hit(_training_weapons,weapon) if _training_weapons.get("authored_story",false) else Kappa.npc_hit(_training_weapons,weapon) if _training_weapons.has("kappa_lifecycle") else FreeLife.npc_hit(_training_weapons,weapon) if _training_weapons.has("free_lifecycle") else Alioth.npc_hit(_training_weapons,weapon) if _training_weapons.has("alioth_lifecycle") else Convoy.npc_hit(_training_weapons,weapon) if _training_weapons.has("capital_death") else (BakkaCombat.npc_hit(_training_weapons,weapon) if not _bakka_encounter.is_empty() else (ContractLife.npc_hit(_training_weapons,weapon) if not _contract_encounter.is_empty() else (Travel.npc_hit(_training_weapons,weapon) if _provocation!=null else TrainingWeapons.npc_hit(_training_weapons,weapon))))
			if not valid:return reject("NPC damage differs from this encounter's weapon declaration")
			kinds=[0,1]
		elif weapon.get("kind")==2 and not fitted:
			if not TrainingWeapons.dispersed_primary(weapon):return reject("Player damage lacks its verified primary declaration")
			kinds=[0,2]
	elif weapon is Dictionary and weapon.get("nonplayer_source",false)==true:return reject("This group has no verified NPC weapon contact path")
	error = WeaponHit.validate(weapon,_identity,_hit_policy,kinds)
	return error.is_empty()

func weapon_hit(actor_id: Variant, weapon: Variant) -> Dictionary:
	if not supports_weapon_hit(weapon): return {}
	if not weapon.ordinary_hit_policy.additional_damage_required:return normal_hit(actor_id,weapon.ordinary_hit_policy.nonplayer_damage,weapon.get("nonplayer_source",false))
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size():return _failed_weapon_hit("Systems projectile names an unavailable actor")
	# A projectile applies both pools as one transaction. Later normal-contact
	# failure must not leave a disabled ship or a reputation change behind.
	var next: RefCounted=fork_for_frame();var systems:={}
	if not _actors[actor_id].snapshot().get("contract_debris",false) and not _actors[actor_id].snapshot().get("static_object",false):
		systems=next.systems_hit(actor_id,weapon.ordinary_hit_policy.additional_damage,weapon.get("nonplayer_source",false))
		if systems.is_empty():return _failed_weapon_hit(next.error)
	var result: Dictionary=next.normal_hit(actor_id,weapon.ordinary_hit_policy.nonplayer_damage,weapon.get("nonplayer_source",false))
	if result.is_empty():return _failed_weapon_hit(next.error)
	if not systems.is_empty():
		result.systems=systems
		result.reactions=systems.get("reactions",[])+result.get("reactions",[])
	_owned={};_actors=next._actors;_provocation=next._provocation;_reputation=next._reputation;_contact_random=next._contact_random
	return result

func _failed_weapon_hit(message: String) -> Dictionary:
	error=message;return {}

func record_contact(actor_id: Variant, incoming_velocity: Variant,point_box_index: Variant=null) -> bool:
	error = ""
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size():
		return reject("Contact names an unavailable opening actor")
	if not _writable(actor_id).record_contact(incoming_velocity,point_box_index): return reject(_actors[actor_id].error)
	return true

func collision_context(actor_id: Variant) -> Dictionary:
	error = ""
	if not actor_id is int or actor_id<0 or actor_id>=_actors.size():
		reject("Collision target names an unavailable opening actor")
		return {}
	return _actors[actor_id].collision_context()

## Resolve after this gun's contacts; an acquired ship may have just retired.
func guidance_position(actor_id: int) -> Variant:
	if actor_id<0 or actor_id>=_actors.size():return null
	var actor: Dictionary=_actors[actor_id].snapshot()
	if not actor.active or actor.actor_mode in [3,4] or actor.get("hidden",false) or actor.get("cloaked",false):return null
	return actor.pose.origin

func fork_for_frame() -> RefCounted:
	var copy: RefCounted = get_script().new()
	# Configuration is immutable after setup; only live state needs a private copy.
	copy._identity = _identity.duplicate()
	copy._selected40_world=_selected40_world;copy._selected41_world=_selected41_world
	copy._activation = _activation
	copy._hit_policy = _hit_policy
	copy._training_weapons = _training_weapons
	copy._wingman_primaries=_wingman_primaries
	copy._wingman_systems=_wingman_systems
	copy._activated = _activated
	copy._phase = _phase
	copy._event_count = _event_count
	copy._escape_enabled=_escape_enabled
	if _reputation!=null:copy._reputation=_reputation.fork_for_frame()
	if _provocation!=null:copy._provocation=_provocation.fork_for_frame()
	copy._reputation_rules=_reputation_rules;copy._contact_random=_contact_random.duplicate(true);copy._display_available=_display_available
	copy._contract_encounter=_contract_encounter
	copy._bakka_encounter=_bakka_encounter
	copy._contract_settlement=_contract_settlement.duplicate(true)
	copy._lethal_items=_lethal_items
	copy._story_standing=_story_standing
	# Recovery replaces its small observation only on pickup.
	copy._recovery_totals=_recovery_totals
	# Actors are copy-on-write: both groups share them until _writable() detaches one.
	copy._actors=_actors.duplicate();_owned={}
	return copy

## Detach one shared actor before an in-place change.
func _writable(id: int) -> RefCounted:
	if not _owned.get(id,false):
		_actors[id]=_actors[id].fork_for_frame();_owned[id]=true
	return _actors[id]

func reject(message: String) -> bool:
	error = message
	return false
