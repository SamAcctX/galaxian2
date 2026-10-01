extends SceneTree
## Alien Hunter: a hostile Void ship drops 1..3 Alien Remains, picking the
## crate up adds to the career stat, and the medal reads that stat.
const Fixtures=preload("res://tests/full_hold_control.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const Death=preload("res://src/simulation/npc_destruction.gd")
const Recovery=preload("res://src/simulation/tractor_recovery.gd")
const RecoveryRules=preload("res://src/content/tractor_recovery_definitions.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const Medals=preload("res://src/simulation/base_medal_progress.gd")
class ComponentBindings extends RefCounted:
	var base_content_id:=""
	var binding_id:=""
	var mido_travel:={}
	var frame_clock:={}
	var fast_forward:={}
class FlightStub extends RefCounted:
	var recovery:={}
	func career_snapshot() -> Dictionary:
		return {"accounting":{"events":[],"counter_deltas":{"player_kills":0,"pirate_kills":0}},
			"combat":{"reputation":{"events":[]},"recovery":recovery.duplicate(true),"current_reputation":{"override":-1,"axes":[0,0]}}}
	func mission_context_owner() -> RefCounted:return null
var checks:=0
var failures:=0
var tractor_rules: RefCounted
var cat: RefCounted

func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Expected explicit Mac content, bindings and visuals")
	if args.size()==3:verify(args)
	print("Alien Hunter medal: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func verify(args: PackedStringArray):
	var lib:=Library.new();var bindings:=Bindings.new();cat=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib):check(false,lib.error+bindings.error+cat.error);return
	tractor_rules=ComponentBindings.new();tractor_rules.base_content_id=bindings.base_content_id
	tractor_rules.binding_id=("alien hunter component "+bindings.binding_id).sha256_text()
	tractor_rules.mido_travel={"tractor_recovery":RecoveryRules.VALUES.duplicate(true)}
	tractor_rules.frame_clock=bindings.frame_clock.duplicate(true);tractor_rules.fast_forward=bindings.fast_forward.duplicate(true)
	var fixture:=Fixtures.new();var flight:=Construction.new();var resources:=Resources.new()
	if not flight.prepare(bindings,cat,fixture.packet_fixture(bindings,cat,3),4096,1789100000) or not resources.configure_full_hold(lib,bindings):
		check(false,flight.error+resources.error);fixture.free();return
	var row: Dictionary=flight.snapshot().scenery.world_initialization.npc_construction.actors[0]
	fixture.free()
	# Death: hostile Void loot is replaced; other ships keep theirs.
	var seen:={}
	var void_crate:={}
	for seed in range(1,40):
		var entries:=dying_cargo(bindings,resources,row,{"actor_kind":9,"friendly":false},seed)
		check(entries.size()==1 and entries[0].item_id==131 and entries[0].quantity>=1 and entries[0].quantity<=3,"Hostile Void death did not drop 1..3 Alien Remains")
		if entries.size()==1:seen[entries[0].quantity]=true;void_crate=entries[0]
	check(seen.size()==3,"Alien Remains quantity does not cover 1..3")
	check(dying_cargo(bindings,resources,row,{"actor_kind":1,"friendly":false},7)==row.cargo,"A non-Void death lost its own cargo")
	check(dying_cargo(bindings,resources,row,{"actor_kind":9,"friendly":true},7)==row.cargo,"A friendly Void ship used the hostile loot path")
	# Pickup: only a Void crate feeds the separate counter.
	var void_events:=pickup_events(9,[void_crate])
	var other_events:=pickup_events(8,[{"item_id":131,"quantity":2}])
	var combat:=Combat.new()
	check(combat.record_cargo_recovery({},void_events) and combat.record_cargo_recovery({},other_events),combat.error)
	var totals:=combat.recovery_totals()
	check(totals.kind9_quantity==void_crate.quantity and totals.accepted_quantity==void_crate.quantity+2,"Only the Void crate should count for Alien Hunter")
	# Career: the flight total becomes the station stat once, then the medal.
	var session:=Contracts.new()
	session._progress_rules=bindings.opening_handoff.duplicate(true)
	session._state={"campaign_cursor":20,"rank":0,"progress":{"player_kills":0,"pirate_kills":0,"other_score":0},"stats":{"alien_remains":5-void_crate.quantity}}
	session._flight={"accounting":{"events":[],"counter_deltas":{"player_kills":0,"pirate_kills":0}},"reputation_events":[]}
	var stub:=FlightStub.new();stub.recovery=totals
	check(session._retain_combat_progress(stub),session.error)
	check(session._retain_combat_progress(stub),session.error)
	check(session._state.stats.alien_remains==5,"Picked-up Alien Remains were not counted exactly once")
	var career:={"campaign_cursor":20,"stats":session._state.stats}
	check(Medals.observe(career).levels[21]==0,"Alien Hunter awarded at exactly 5 (source requires more)")
	stub.recovery.kind9_quantity+=1
	check(session._retain_combat_progress(stub) and session._state.stats.alien_remains==6,"A later pickup was not added")
	career.stats=session._state.stats
	check(Medals.observe(career).levels[21]==3,"Alien Hunter bronze missing after 6 remains")
	career.stats={"alien_remains":11};check(Medals.observe(career).levels[21]==2,"Alien Hunter silver missing")
	career.stats={"alien_remains":26};check(Medals.observe(career).levels[21]==1,"Alien Hunter gold missing")

func dying_cargo(bindings: RefCounted,resources: RefCounted,row: Dictionary,lethal: Dictionary,seed: int) -> Array:
	var death:=Death.new();var initial:=row.duplicate(true);initial.body_pose=Transform3D.IDENTITY
	if not death.configure_full_hold(bindings,resources,initial):check(false,death.error);return []
	var event: Dictionary=death.advance(0,{"state":seed*2654435761},lethal)
	if event.is_empty():check(false,death.error);return []
	check(event.state.cargo.eligible,"Death crate is not recoverable")
	return event.state.cargo.entries

func pickup_events(kind: int,entries: Array) -> Array:
	var ident:={"base_content_id":tractor_rules.base_content_id,"binding_id":tractor_rules.binding_id}
	var tractor:=Recovery.new()
	var loadout:=ident.duplicate();loadout.merge({"ship_id":0,"equipment_ids":[68,81]})
	if not tractor.configure(tractor_rules,cat,loadout):check(false,tractor.error);return []
	var ship:=ident.duplicate()
	ship.merge({"actor_id":0,"actor_mode":4,"actor_kind":kind,"hull":0,"active":true,"cargo_eligible":true,
		"cargo_model_exists":true,"retire_on_transfer":false,"statistics_exempt":false,"body_motion_blocked":false,
		"body_motion_detached":false,"friendly":false,"special_cargo":false,"body_pose":Transform3D.IDENTITY,
		"cargo_pose":Transform3D.IDENTITY,"cargo_entries":entries.duplicate(true),"collision_centers":[Vector3i.ZERO]})
	var player:=ident.duplicate();player.merge({"pose":Transform3D.IDENTITY,"autopilot":false})
	var hold:=ident.duplicate();hold.merge({"capacity":50,"used":0,"entries":[]})
	if not tractor.queue_acquired_wreck(ship) or not tractor.advance(0,player,ship,hold) or not tractor.advance(0,player,ship,hold):check(false,tractor.error);return []
	return tractor.snapshot().frame.transfer.events
