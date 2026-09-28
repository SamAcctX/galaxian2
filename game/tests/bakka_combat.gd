extends SceneTree
## Focused story-combat coverage. Construction comes from the recovered B'akka
## fixture; movement, breakup timing and death accounting run through native owners.
## Result polling is covered through the native controller; acknowledgement and
## the enclosing mission/session transition remain separate.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const World=preload("res://src/simulation/opening_world_initialization.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Rules=preload("res://src/content/bakka_combat_definitions.gd")
const Group=preload("res://src/simulation/opening_combat_group.gd")
const Guidance=preload("res://src/simulation/opening_npc_guidance.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const Motion=preload("res://src/simulation/npc_flight.gd")
const ActorControl=preload("res://src/simulation/combat_training_control.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const Defeat=preload("res://src/simulation/pirate_defeat_condition.gd")
const ComponentEquipment=preload("res://tests/fixtures/bakka_equipment.gd")
const COMPONENT_STANDING={"axes":[13,-17],"override":-1}
var component_equipment: RefCounted
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content, bindings and visuals")
	else:verify(args)
	print("Bakka combat: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	if not preload("res://src/content/bakka_contest_definitions.gd").available(bindings):
		check(Rules.population(bindings,{}).is_empty(),"Earlier pack enabled B'akka combat")
		return
	var vectors_file:=FileAccess.open(OS.get_environment("GOF2_BAKKA_VECTORS"),FileAccess.READ)
	if vectors_file==null:check(false,"Supply independent B'akka vectors");return
	var vectors: Variant=JSON.parse_string(vectors_file.get_as_text())
	if not vectors is Array or vectors.is_empty():check(false,"Missing B'akka vectors");return
	var vector: Dictionary=vectors[0]
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":36,"station_id":27,"system_id":5,"mission_kind":12,"mission_story":true,"mission_completed":false,"rank":7,"difficulty":0.5}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":27,"system_id":5,"ship_id":0,"equipment_ids":[90,81]}
	var fixture:=ComponentEquipment.new()
	component_equipment=fixture.create(bindings,cat,seed)
	if component_equipment==null:check(false,fixture.error);return
	var player_position:=Vector3(vector.player[0],vector.player[1],vector.player[2])
	var entry_conditions:={"companions_empty":true,"location_match":false,"special_placement":false}
	var random:=Random.new();random.seed_from(int(vector.seed))
	var world:=World.new()
	if not world.configure_bakka(bindings,cat,seed,context,player_position,entry_conditions):check(false,world.error);return
	var world_packet: Dictionary=world.generate(random.snapshot())
	if world_packet.is_empty():check(false,world.error);return
	check(world_packet.campaign_cursor==36 and world_packet.station_id==27 and world_packet.system_id==5 and world_packet.bakka_context==context,"B'akka world lost selected story identity")
	check(world_packet.npc_construction.get("bakka_encounter") is Dictionary and world_packet.npc_construction.actors.size()==8,"B'akka world did not own the fixed contest population")
	check(world_packet.weapon_effects.size()==8 and world_packet.weapon_effects.all(func(effect):return effect.has("primary")),"B'akka world did not allocate shared weapon effects")
	check(not Rules.population(bindings,world_packet.npc_construction).is_empty(),"B'akka world population did not enter shared combat definitions")
	var construction:=Factory.new()
	if not construction.configure_bakka(bindings,cat,seed,context,player_position):check(false,construction.error);return
	if construction.generate(random.snapshot()).is_empty():check(false,construction.error);return
	var packet: Dictionary=construction.snapshot()
	check(world_packet.npc_construction==packet,"World-owned B'akka construction diverged from the recovered fixture")
	var data:=Rules.population(bindings,packet)
	check(not data.is_empty() and data.actor_count==8 and data.campaign_cursor==36,"Story population did not enter B'akka combat")
	if data.is_empty():return
	check(not packet.has("contract_encounter") and packet.has("bakka_encounter"),"B'akka combat impersonated a lounge contract")
	check(data.target_memberships[0]==[-1,1,2,3,4,5,6,7] and data.target_memberships[1]==[0,-1] and data.target_memberships[2]==[-1,0],"Contest target order changed")
	var combat:=Group.new()
	if not combat.configure_bakka(bindings,cat,construction,component_equipment,COMPONENT_STANDING):check(false,combat.error);return
	check(not Group.new().configure_bakka(bindings,cat,construction,null,COMPONENT_STANDING),"B'akka reactions accepted missing equipment")
	check(not Group.new().configure_bakka(bindings,cat,construction,component_equipment,{}),"B'akka reactions invented missing career standing")
	var weapons:=Weapons.new()
	if not weapons.configure_bakka(bindings,cat,construction):check(false,weapons.error);return
	var state:=combat.snapshot()
	check(state.bakka_encounter==packet.bakka_encounter and not state.has("contract_encounter"),"Combat lost story identity")
	check(state.actors[0].name_text_id==int(bindings.mido_travel.bakka_contest.population.rival_name_text_id) and state.actors[0].friendly,"Rival identity or friendship changed")
	check(state.actors.slice(1).all(func(actor):return actor.actor_kind==8 and actor.actor_mode==5 and not actor.active),"Pirates activated before proximity")
	if load("res://src/content/npc_systems_definitions.gd").available(bindings):
		for actor in state.actors:
			var expected: Dictionary=load("res://src/content/npc_systems_definitions.gd").systems(bindings,int(context.rank),int(actor.subtype))
			var systems: RefCounted=combat.systems_for_frame(int(actor.actor_id))
			check(systems!=null,"Retained secondary equipment lacks an authored target systems owner")
			if systems==null:return
			var pools: Dictionary=systems.snapshot()
			check(pools.capacity==expected.capacity and pools.integrity==expected.capacity and pools.recovery_ms==expected.recovery_ms and not pools.disabled,"Story target did not use its shared rank/subtype systems initialization")
	var random_state: Dictionary=packet.random_state.duplicate(true)
	var contact_before:=combat.snapshot()
	check(combat.begin_contact_pass(random_state,true) and combat.contact_random_state()==random_state and combat.snapshot()==contact_before,"Selected-story secondary frame cannot retain its contact RNG without inventing damage")
	check(not combat.begin_contact_pass({},true) and combat.contact_random_state()==random_state and combat.snapshot()==contact_before,"Malformed contact RNG mutated the selected combat group")
	check(not Group.new().begin_contact_pass(random_state,true),"An unconfigured combat group gained contact support")
	for id in 8:
		var guide:=Guidance.new();var motion:=Motion.new()
		if not guide.configure_bakka(bindings,cat,construction,id) or not motion.configure(bindings,combat.actor_snapshot(id).body_pose):check(false,guide.error+motion.error);return
		var initial:=combat.actor_snapshot(id)
		var player:=player_fixture(bindings,initial.pose.origin+Vector3(0,0,20000))
		for _frame in 2:
			if not combat.refresh_hostility(id):check(false,combat.error);return
			var actor:=combat.actor_snapshot(id)
			var decision: Dictionary=guide.update(16,actor,motion.snapshot().root_pose,player,random_state,combat.actor_snapshots())
			if decision.is_empty() or not combat.apply_bakka_guidance(decision):check(false,guide.error+combat.error);return
			if decision.travel_enabled or decision.steering_enabled:
				var moved:=motion.advance(16,decision.direction,decision.speed,decision.steering_enabled,decision.travel_enabled)
				if moved.is_empty() or not combat.set_pose(id,moved.pose,moved.root_pose):check(false,motion.error+combat.error);return
			random_state=decision.random_state.duplicate(true)
	check(combat.actor_snapshots().all(func(actor):return actor.active and actor.actor_mode==1),"Real proximity frames did not release all contest ships")
	check(combat.actor_snapshot(0).friendly and not combat.actor_snapshot(0).hostile,"Rival lost authored friendly state")
	check(combat.actor_snapshots().slice(1).all(func(actor):return actor.hostile),"Pirates did not enter shared hostile combat")
	var pulse_probe: RefCounted=combat.fork_for_frame()
	var pulse: Dictionary=pulse_probe.systems_hit(1,1,false)
	check(not pulse.is_empty(),"An actual B'akka systems contact was rejected: "+pulse_probe.error)
	verify_system_reactions(bindings,combat)
	if failures:return
	var player_kills:=0;var other_kills:=0
	for id in range(1,8):
		var nonplayer:=id>=5
		var hit:=combat.normal_hit(id,9999999,nonplayer)
		if hit.is_empty() or not hit.destroyed_now:check(false,combat.error);return
		var actor:=combat.actor_snapshot(id)
		check(actor.nonplayer_kill==nonplayer,"Lethal attribution changed")
		if nonplayer:other_kills+=1
		else:player_kills+=1
		for phase in [{"phase":"tumble","mode":3},{"phase":"explosion","mode":4},{"phase":"retired","mode":4}]:
			actor=combat.actor_snapshot(id)
			var death={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":36,"actor_id":id,"phase":phase.phase,"mode":phase.mode,"pose":actor.body_pose,"statistics_pose":actor.pose}
			if not combat.apply_destruction(id,death):check(false,combat.error);return
	var actors:=combat.actor_snapshots()
	check(actors.slice(1).all(func(actor):return actor.actor_mode==4 and not actor.active),"All seven pirates did not retire")
	var totals={"world_player_kills":player_kills,"world_other_kills":other_kills}
	var outcome:=Defeat.evaluate(actors,totals,bindings.mido_travel.bakka_contest.objectives,true)
	check(outcome.defeated==7 and outcome.required==7 and outcome.satisfied and not outcome.failed,"Strict player-majority contest success changed")
	var failure:=Defeat.evaluate(actors,{"world_player_kills":3,"world_other_kills":4},bindings.mido_travel.bakka_contest.objectives,true)
	check(failure.failed and not failure.satisfied and failure.kind==20 and failure.failure_kind==21,"Contest loss branch changed")
	verify_control(library,bindings,cat,construction)
	verify_failure_control(library,bindings,cat,construction)
	check(construction.snapshot()==packet,"Combat mutated retained B'akka construction")

func verify_control(library: RefCounted,bindings: RefCounted,cat: RefCounted,construction: RefCounted) -> void:
	var resources:=Resources.new();var control:=ActorControl.new()
	if not resources.configure_bakka(library,bindings,construction) or not control.configure_bakka(bindings,cat,construction,component_equipment,COMPONENT_STANDING) or not control.set_destruction(bindings,resources):check(false,resources.error+control.error);return
	var fresh: Dictionary=control.snapshot()
	check(fresh.support_state=="bakka_combat" and fresh.accounting.events.is_empty(),"B'akka controller did not own fresh destruction/accounting")
	check(fresh.combat.reputation.bakka_contest and fresh.combat.reputation.system_id==5 and not fresh.combat.reputation.has("spawn_generations"),"Authored B'akka cast inherited recyclable traffic reputation")
	var standing: RefCounted=load("res://src/simulation/faction_reputation.gd").new()
	check(standing.restore(bindings,fresh.combat.reputation) and standing.snapshot()==fresh.combat.reputation,"Fresh B'akka reputation did not round-trip")
	check(fresh.bakka_result=={"clock_ms":0,"elapsed_ms":0,"mode":0,"retired":false} and not fresh.has("contract_result"),"B'akka result state impersonated a lounge contract")
	for id in 8:
		for _frame in 2:
			var actor: Dictionary=control.snapshot().combat.actors[id]
			var target:=player_fixture(bindings,actor.body_pose.origin+Vector3(0,0,20000))
			if control.advance(0,target).is_empty():check(false,control.error);return
	check(control.snapshot().combat.actors.all(func(actor):return actor.active and actor.actor_mode==1),"Controller proximity frames did not release the contest cast")
	var target:=player_fixture(bindings,control.snapshot().combat.actors[0].body_pose.origin+Vector3(0,0,20000))
	for id in range(1,8):
		var combat: RefCounted=control.combat_owner();var nonplayer:=id>=5
		if not combat.begin_contact_pass(control.snapshot().random_state,true):check(false,combat.error);return
		var hit: Dictionary=combat.normal_hit(id,9999999,nonplayer)
		if hit.is_empty() or not hit.destroyed_now:check(false,combat.error);return
		var incoming: Dictionary=control.snapshot()
		if control.advance(0,target,combat,incoming.random_state).is_empty():check(false,control.error);return
		var elapsed:=0
		while control.snapshot().combat.actors[id].actor_mode!=4 and elapsed<5000:
			if control.advance(100,target).is_empty():check(false,control.error);return
			elapsed+=100
		var state: Dictionary=control.snapshot()
		check(state.combat.actors[id].actor_mode==4 and state.destruction[id].phase=="explosion","Native breakup did not destroy B'akka pirate %d"%id)
		check(state.accounting.events.size()==id,"B'akka death was not accounted exactly once")
		var retained: Dictionary=state.accounting.duplicate(true)
		if control.advance(100,target).is_empty():check(false,control.error);return
		check(control.snapshot().accounting==retained,"Retired B'akka pirate counted its death twice")
	var final: Dictionary=control.snapshot();var totals: Dictionary=final.accounting.counter_deltas
	check(totals.world_player_kills==4 and totals.world_other_kills==3,"B'akka controller lost player/nonplayer lethal attribution")
	check(standing.restore(bindings,final.combat.reputation) and standing.snapshot()==final.combat.reputation,"Actual B'akka lethal history did not round-trip")
	var mislabeled: Dictionary=final.combat.reputation.duplicate(true);mislabeled.erase("bakka_contest")
	check(not standing.restore(bindings,mislabeled) and standing.snapshot()==final.combat.reputation,"B'akka history accepted a free-traffic relabel or changed on rejected restore")
	check(final.defeat_status.defeated==7 and final.defeat_status.required==7 and final.defeat_status.satisfied and not final.defeat_status.failed,"B'akka controller did not expose strict-majority success")
	var deferred: Dictionary=control.poll_bakka_result(true,true)
	check(deferred.mode==0 and deferred.clock_ms==0,"Active radio did not defer and reset the due B'akka success poll")
	for _frame in 50:
		if control.advance(100,target).is_empty():check(false,control.error);return
	var early: Dictionary=control.poll_bakka_result(false,true)
	check(early.mode==0 and early.clock_ms==5000,"B'akka success opened before its strict 5.001 second poll")
	if control.advance(1,target).is_empty():check(false,control.error);return
	var success: Dictionary=control.poll_bakka_result(false,true)
	check(success.mode==int(bindings.early_contracts.flight_results.success_result_mode) and success.clock_ms==5001,"Due idle B'akka success did not enter the shared source result mode")
	check(control.snapshot().bakka_result==success and not control.snapshot().has("contract_result"),"B'akka result was not retained under story identity")
	check(control.advance(100,target).is_empty(),"Pending B'akka result did not stop positive-time actor flight")
	check(not control.advance(0,target).is_empty() and control.snapshot().bakka_result==success,"B'akka modal did not preserve its result across a zero-time world pass")
	check(not control.acknowledge_contract_result(),"B'akka result entered the lounge-contract acknowledgement path")
	check(control.acknowledge_bakka_result() and control.snapshot().bakka_result.retired,"B'akka success did not retire its native result")
	check(not control.acknowledge_bakka_result(),"B'akka success retired twice")

func verify_failure_control(library: RefCounted,bindings: RefCounted,cat: RefCounted,construction: RefCounted) -> void:
	var resources:=Resources.new();var control:=ActorControl.new()
	if not resources.configure_bakka(library,bindings,construction) or not control.configure_bakka(bindings,cat,construction,component_equipment,COMPONENT_STANDING) or not control.set_destruction(bindings,resources):check(false,resources.error+control.error);return
	for id in 8:
		for _frame in 2:
			var actor: Dictionary=control.snapshot().combat.actors[id]
			var target:=player_fixture(bindings,actor.body_pose.origin+Vector3(0,0,20000))
			if control.advance(0,target).is_empty():check(false,control.error);return
	var target:=player_fixture(bindings,control.snapshot().combat.actors[0].body_pose.origin+Vector3(0,0,20000))
	for id in range(1,8):
		var combat: RefCounted=control.combat_owner();var nonplayer:=id>=4
		if not combat.begin_contact_pass(control.snapshot().random_state,true):check(false,combat.error);return
		var hit: Dictionary=combat.normal_hit(id,9999999,nonplayer)
		if hit.is_empty() or not hit.destroyed_now:check(false,combat.error);return
		var incoming: Dictionary=control.snapshot()
		if control.advance(0,target,combat,incoming.random_state).is_empty():check(false,control.error);return
		var elapsed:=0
		while control.snapshot().combat.actors[id].actor_mode!=4 and elapsed<5000:
			if control.advance(100,target).is_empty():check(false,control.error);return
			elapsed+=100
	var final: Dictionary=control.snapshot()
	check(final.defeat_status.defeated==7 and final.defeat_status.failed and not final.defeat_status.satisfied,"B'akka controller did not expose the 3-4 loss")
	var failure: Dictionary=control.poll_bakka_result(true,false)
	check(failure.mode==int(bindings.early_contracts.flight_results.failure_result_mode),"B'akka loss waited for the periodic success gate or idle radio")
	check(control.snapshot().bakka_result==failure and not control.snapshot().has("contract_result"),"B'akka failure was not retained under story identity")
	check(not control.acknowledge_bakka_result(),"B'akka loss was acknowledged as a victory")

func player_fixture(bindings: RefCounted,position: Vector3) -> Dictionary:
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"pose":Transform3D(Basis.IDENTITY,position),
		"ship_id":0,"active":true,"hull":95,"special_flight":false,"targeting_blocked":false,"alternate_position":null}

func verify_system_reactions(bindings: RefCounted,original: RefCounted) -> void:
	var parent: Dictionary=original.snapshot()
	var random: Dictionary=original.contact_random_state()
	check(original.current_reputation()==COMPONENT_STANDING,"B'akka lost explicitly retained nonzero standing")
	var subject: RefCounted=original.fork_for_frame()
	var capacity: int=int(parent.actors[0].systems.capacity)
	@warning_ignore("integer_division")
	var threshold: int=capacity/3
	var hit: Dictionary=subject.systems_hit(0,threshold,false)
	if hit.is_empty():check(false,subject.error);return
	var reaction: Dictionary=subject.snapshot().provocation
	check(not reaction.forced_hostile[0] and not reaction.warning_issued and reaction.systems_requested_damage[0]==threshold,"Systems warning did not preserve its strict source threshold")
	hit=subject.systems_hit(0,1,false)
	if hit.is_empty():check(false,subject.error);return
	reaction=subject.snapshot().provocation
	check(reaction.forced_hostile==[true,false,false,false,false,false,false,false] and reaction.warning_issued and not reaction.permanent_hostile[0],"A Vossk EMP warning forced another faction or prematurely persisted hostility")
	check(reaction.requested_damage==[0,0,0,0,0,0,0,0] and not reaction.response_issued and not reaction.station_response_flag and reaction.radio_serial==0 and subject.contact_random_state()==random,"Systems warning changed normal damage, consumed radio randomness or alerted the station during story12")
	hit=subject.systems_hit(0,capacity,false)
	if hit.is_empty():check(false,subject.error);return
	var disabled: Dictionary=subject.snapshot()
	check(hit.first_disable_by_player and disabled.actors[0].systems.integrity==0 and disabled.provocation.permanent_hostile==[true,false,false,false,false,false,false,false],"Player depletion missed its first-disable event or matching-faction persistence")
	check(subject.refresh_hostility(0) and subject.actor_snapshot(0).friendly and not subject.actor_snapshot(0).hostile and subject.actor_snapshot(0).script_hostile,"Vossk reaction flags overrode authored rival friendship")
	var expected: Dictionary=COMPONENT_STANDING.duplicate(true);expected.axes[0]+=2
	check(subject.current_reputation()==expected and disabled.reputation.events.size()==1 and disabled.reputation.events[0].event_kind=="systems_disabled" and disabled.reputation.events[0].actor_kind==1 and disabled.reputation.events[0].change==2,"Vossk systems depletion changed the wrong standing axis or amount")
	hit=subject.systems_hit(0,capacity,false)
	check(not hit.is_empty() and not hit.first_disable_by_player and subject.snapshot().reputation==disabled.reputation,"An already empty systems pool counted another depletion")
	for tick in int(ceil(float(disabled.actors[0].systems.recovery_ms)/100.0))+2:
		if not subject.advance_systems(0,100):check(false,subject.error);return
	check(subject.actor_snapshot(0).systems.integrity==capacity,"The ordinary systems clock did not recover the B'akka rival")
	hit=subject.systems_hit(0,capacity,false)
	if hit.is_empty():check(false,subject.error);return
	expected.axes[0]+=2
	check(subject.current_reputation()==expected and subject.snapshot().reputation.events.size()==2,"A recovered pool lost its distinct second depletion reputation event")
	var history: RefCounted=load("res://src/simulation/faction_reputation.gd").new()
	check(history.restore(bindings,subject.snapshot().reputation) and history.snapshot()==subject.snapshot().reputation,"B'akka systems history failed its native round-trip")
	var npc: RefCounted=original.fork_for_frame()
	hit=npc.systems_hit(0,capacity,true)
	check(not hit.is_empty() and not hit.first_disable_by_player and npc.actor_snapshot(0).systems.integrity==0 and npc.current_reputation()==COMPONENT_STANDING and npc.snapshot().provocation==parent.provocation,"A nonplayer EMP provoked the player's faction or credited standing")
	var pirate: RefCounted=original.fork_for_frame()
	hit=pirate.systems_hit(1,int(parent.actors[1].systems.capacity),false)
	check(not hit.is_empty() and hit.first_disable_by_player and pirate.actor_snapshot(1).systems.integrity==0 and pirate.current_reputation()==COMPONENT_STANDING and pirate.snapshot().provocation==parent.provocation,"A pirate EMP depletion invoked the Vossk faction reaction")
	var ordinary: RefCounted=original.fork_for_frame()
	hit=ordinary.normal_hit(0,int(parent.actors[0].max_hull),false)
	if hit.is_empty():check(false,ordinary.error);return
	reaction=ordinary.snapshot().provocation
	check(reaction.warning_issued and reaction.response_issued and reaction.station_response_flag and reaction.radio_serial==0 and ordinary.contact_random_state()==random,"The same B'akka actor lost normal-hit faction response or emitted story-forbidden radio")
	check(reaction.systems_requested_damage==[0,0,0,0,0,0,0,0] and ordinary.refresh_hostility(0) and ordinary.actor_snapshot(0).friendly and not ordinary.actor_snapshot(0).hostile,"Normal hit polluted EMP counters or replaced rival friendship")
	for request in [[-1,1,false],[8,1,false],[0,1.5,false],[0,1,"player"]]:
		var rejected: RefCounted=original.fork_for_frame()
		check(rejected.systems_hit(request[0],request[1],request[2]).is_empty() and rejected.snapshot()==parent and rejected.contact_random_state()==random,"Rejected B'akka systems input partially changed accepted owners")
	check(original.snapshot()==parent and original.contact_random_state()==random,"Detached reaction tests changed the accepted battle parent")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
