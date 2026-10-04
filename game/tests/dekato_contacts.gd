extends "res://tests/dekato_combat.gd"
## Explicit component equipment/cache and firing poses, never an earned save.
## Every hit below comes from a real gun slot and the shared encounter pass.
## Reuse the fleet diagnostic renderer; this is not the unfinished gameplay HUD.
const Player=preload("res://src/simulation/opening_player_state.gd")
const PlayerEntry=preload("res://src/content/player_entry_definitions.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const Bodies=preload("res://src/content/scenery_body_resources.gd")
const Effects=preload("res://src/content/scenery_effect_resources.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Primaries=preload("res://src/simulation/primary_weapons.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const MissionContext=preload("res://src/simulation/mission_context.gd")

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size() not in [3,4]:check(false,"Expected content, bindings, visuals and optional captures");finish();return
	art=args[2]
	if args.size()==4:captures=args[3]
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);finish();return
	if not Rules.available(bindings):
		var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,"station_id":22,"system_id":4,
			"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false,"rank":10,"difficulty":0.5}
		check(not PlayerEntry.new().configure_dekato(bindings,context,0),"Earlier pack accepted an explicit selected Dekato entry")
		check(not Player.new().configure_dekato(bindings,cat,null,null,{}),"Earlier pack accepted a Dekato player")
		check(not Scenery.new().configure_dekato(bindings,cat,null,{},ENTRY,123),"Earlier pack accepted Dekato scenery")
		check(not Encounter.new().configure_dekato(bindings,cat,library,null,null,null,{}),"Earlier pack accepted Dekato contacts")
		finish();return
	for difficulty in [0.5,1.0]:await verify_contacts(library,bindings,cat,difficulty)
	finish()

func verify_contacts(library: RefCounted,bindings: RefCounted,cat: RefCounted,difficulty: float) -> void:
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,"station_id":22,"system_id":4,
		"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false,"rank":10,"difficulty":difficulty}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":22,"system_id":4,"ship_id":0,"equipment_ids":[2 if difficulty==0.5 else 22,41,86,81,55]}
	var fixture:=InventoryFixture.new();var equipment: RefCounted=fixture.create(bindings,cat,seed)
	if equipment==null:check(false,fixture.error);return
	var owned: Dictionary=equipment.snapshot();var loadout: Dictionary=owned.loadout.duplicate(true)
	loadout.campaign_cursor=38
	var mount_resources:=Mounts.new()
	if not mount_resources.open(library,cat):check(false,mount_resources.error);return
	# Dekato entry is admitted once by the shared mission context; guns trust it
	# and only reject equipment changed after that entry.
	var mission:=MissionContext.new()
	check(mission.admit(bindings,cat,context,loadout),"Mission entry rejected the selected Dekato loadout: "+mission.error)
	check(Primaries.new().configure(bindings,cat,mount_resources,loadout,mission),"Primaries rejected the admitted Dekato loadout")
	for mutation in [["campaign_cursor",36],["station_id",27],["system_id",5],["equipment_ids",[]]]:
		var wrong_loadout:=loadout.duplicate(true);wrong_loadout[mutation[0]]=mutation[1]
		check(not Primaries.new().configure(bindings,cat,mount_resources,wrong_loadout,mission),"Primaries accepted equipment changed after Dekato entry: "+mutation[0])
	for mutation in [["binding_id","foreign"],["station_id",27],["system_id",5],["mission_completed",true]]:
		var wrong_context:=context.duplicate(true);wrong_context[mutation[0]]=mutation[1]
		check(not MissionContext.new().admit(bindings,cat,wrong_context,loadout),"Mission entry admitted another selected context: "+mutation[0])
	var entry:=PlayerEntry.new()
	check(not entry.configure(bindings,38,22,true,int(loadout.ship_id)),"Native contact work opened generic Dekato player entry")
	if not entry.configure_dekato(bindings,context,int(loadout.ship_id)):check(false,entry.error);return
	var parameters: Dictionary=bindings.opening_actors.player_initialization
	var capacities:=Player.resolve_capacities(cat.tables.items,loadout.equipment_ids,parameters)
	var repair: Dictionary=parameters.repair
	var hull:=Player.resolve_ship_hull(cat.tables.ships[int(loadout.ship_id)].fields[int(repair.base_hull_field)],repair.initial_upgrades,repair)
	var cache:=entry.player_cache(parameters.flight_cache,loadout,hull,capacities)
	if cache.is_empty():check(false,"Cannot construct the explicit component cache");return
	cache.values.hull=67;cache.values.armor=mini(7,capacities.armor);cache.values.shield=mini(5,capacities.shield)
	var bodies:=Bodies.new();var effects:=Effects.new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var scenery:=Scenery.new()
	if not scenery.configure_dekato(bindings,cat,equipment,context,ENTRY,123,true,bodies,effects):check(false,scenery.error);return
	var population: RefCounted=scenery.world_initialization_owner().npc_construction_owner()
	var packet: Dictionary=population.snapshot()
	check(scenery.snapshot().world_initialization.dekato_context==context and packet.dekato_context==context,"Scenery lost the selected convoy context")
	var player:=Player.new()
	if not player.configure_dekato(bindings,cat,equipment,population,cache):check(false,player.error);return
	check(player.snapshot().dekato_context==context and player.loadout()==loadout,"Player lost retained ship or installed slots")
	for key in ["hull","armor","shield"]:check(player.snapshot().vitals[key]==cache.values[key],"Arrival restored fresh rather than surviving "+key)
	check(player.set_permissions(true,true),player.error)
	var encounter:=Encounter.new()
	if not encounter.configure_dekato(bindings,cat,library,player,scenery,equipment,Reputation.initial(bindings)):check(false,encounter.error);return
	check(encounter.snapshot().combat.actors.size()==7,"Encounter dropped convoy members")
	for key in encounter.snapshot().primaries.loadout:check(encounter.snapshot().primaries.loadout[key]==loadout[key],"Encounter changed primary loadout "+key)
	check(encounter.freighter_assembly(0)==packet.actors[0].assembly and encounter.freighter_resources()!=null,"Encounter dropped retained freighter geometry")
	var initial: Dictionary=encounter.snapshot();var before_player: Dictionary=player.snapshot();var before_field: Dictionary=scenery.snapshot()
	check(not encounter.configure_dekato(bindings,cat,library,player,scenery,equipment,Reputation.initial(bindings)) and encounter.snapshot()==initial,"Reconfiguration discarded the live encounter")
	for mutation in [["binding_id","foreign"],["station_id",27],["ship_id",1],["equipment_ids",[]],["campaign_cursor",36]]:
		var wrong:=cache.duplicate(true);wrong[mutation[0]]=mutation[1]
		check(not Player.new().configure_dekato(bindings,cat,equipment,population,wrong),"Player accepted a mismatched retained cache: "+mutation[0])
	var dead_cache:=cache.duplicate(true);dead_cache.values.hull=0
	check(not Player.new().configure_dekato(bindings,cat,equipment,population,dead_cache),"Arrival resurrected a destroyed player")
	var wrong_player: RefCounted=player.fork_for_frame();wrong_player._state.dekato_context.difficulty=0.5 if difficulty==1.0 else 1.0
	check(not Encounter.new().configure_dekato(bindings,cat,library,wrong_player,scenery,equipment,Reputation.initial(bindings)),"Encounter accepted another selected difficulty")
	var random: Dictionary=scenery.random_state();var distant:=Transform3D(Basis.IDENTITY,Vector3(300000,0,0))
	check(encounter.evaluate_weapons(player,Transform3D(Basis.IDENTITY,Vector3(NAN,0,0)),1,scenery,random).is_empty(),"Nonfinite player pose entered contacts")
	check(encounter.evaluate_weapons(player,distant,1,Scenery.new(),random).is_empty(),"Contacts accepted an unrelated scenery owner")
	check(encounter.snapshot()==initial and player.snapshot()==before_player and scenery.snapshot()==before_field and equipment.snapshot()==owned,"Rejected contacts or entry mutated a retained owner")
	# Run real early weapons and late NPC phases before requesting the controlled
	# contact. The native factories/activation/firing permissions remain in charge.
	var warm:=encounter.evaluate_weapons(player,distant,1,scenery,random)
	if warm.is_empty():check(false,encounter.error);return
	var active: Dictionary=warm.encounter.evaluate_world(warm.player,distant,1,warm.random_state)
	if active.is_empty():check(false,warm.encounter.error);return
	encounter=active.encounter;player=warm.player;scenery=warm.scenery;random=active.random_state
	check(encounter.snapshot().controller.combat.actors.size()==7,"Late NPC pass lost the mixed population")
	var escort: Dictionary=encounter.combat_owner().actor_snapshot(2)
	check(escort.active and escort.hostile and escort.firing_allowed,"Original escort did not enter live combat")
	var target: Dictionary=encounter.combat_owner().collision_context(0)
	var hit_point: Vector3=target.center+target.boxes[0].offset
	var fired: RefCounted=encounter.fork_for_frame();fired._weapons=encounter._weapons.fork_for_frame()
	var shot: Dictionary=fired._weapons.fire_combat_training(fired.combat_owner(),[{"actor_id":2,"target_actor_id":0,"pose":Transform3D(Basis.IDENTITY,hit_point)}])
	if shot.is_empty() or not shot.actors[0].outcome.fired:check(false,"Actual escort gun did not fire: "+fired._weapons.error);return
	var previous: Dictionary=fired.snapshot();var previous_player: Dictionary=player.snapshot();var previous_scenery: Dictionary=scenery.snapshot()
	var npc_pass: Dictionary=fired.evaluate_weapons(player,Transform3D(Basis.IDENTITY,hit_point),0,scenery,random)
	if npc_pass.is_empty():check(false,fired.error);return
	var events: Array=npc_pass.encounter.snapshot().weapon_events.filter(func(row):return row.actor_id==2)
	check(events.size()==1 and events[0].contacts.size()==1 and events[0].npc_contacts.map(func(row):return row.actor_id)==[0],"A real Mido shot did not visit player then freighter")
	if events.size()!=1:return
	check(events[0].last_contact_actor=={"group":"npc","index":0} and events[0].motion.cleared==[shot.actors[0].outcome.projectile.id],"Projectile cleanup broke the ordered mixed pass")
	check(npc_pass.player.snapshot().vitals!=previous_player.vitals,"Hostile projectile failed to damage the surviving equipped player")
	check(npc_pass.encounter.combat_owner().actor_snapshot(0).vitals.hull<previous.combat.actors[0].vitals.hull,"Real freighter point boxes did not receive NPC damage")
	check(npc_pass.encounter.combat_owner().actor_snapshot(0).friendly,"A real contact erased permanent freighter friendliness")
	check(fired.snapshot()==previous and player.snapshot()==previous_player and scenery.snapshot()==previous_scenery,"Mixed contact preparation mutated its parent owners")
	# Fire the installed primary at an actual escort without moving the actor or
	# supplying a hit, damage amount, retirement state or mission outcome.
	var mounts: Dictionary=encounter.snapshot().primaries.guns[0].mount
	var aim:=Transform3D(Basis.IDENTITY,escort.position-mounts.position-Vector3(0,0,100))
	var volley:=encounter.evaluate_primary_fire(player,aim,true,true,random)
	if volley.is_empty():check(false,encounter.error);return
	check(volley.encounter.snapshot().primary_fire.weapons[0].result.fired,"Installed primary did not allocate a real projectile")
	var primary_pass: Dictionary=volley.encounter.evaluate_weapons(player,distant,0,scenery,volley.random_state)
	if primary_pass.is_empty():check(false,volley.encounter.error);return
	var primary_events: Array=primary_pass.encounter.primary_contacts()[0].contacts
	check(primary_events.any(func(row):return row.get("target")=={"group":"npc","index":2}),"Equipped player projectile missed the actual escort contact pass")
	check(primary_pass.encounter.combat_owner().actor_snapshot(2).vitals.hull<escort.vitals.hull,"Actual primary failed to damage the escort")
	check(primary_pass.encounter.combat_owner().actor_snapshot(2).hostile,"Real player contact erased permanent escort hostility")
	var later: Dictionary=primary_pass.encounter.evaluate_world(primary_pass.player,distant,100,primary_pass.random_state)
	if later.is_empty():check(false,primary_pass.encounter.error);return
	check(equipment.snapshot()==owned and player.loadout()==loadout,"Contact/NPC phases consumed or reconstructed installed equipment")
	var objective:=Objective.new()
	check(objective.configure(bindings.mido_travel.dekato_convoy),objective.error)
	var status:=objective.observe(later.encounter.combat_owner().actor_snapshots())
	check(not status.is_empty() and not status.satisfied and not status.failed,"Nonlethal projectiles manufactured a mission result")
	print("Dekato actual contacts difficulty=%s player=%s freighter=%s escort=%s"%[difficulty,npc_pass.player.snapshot().vitals,npc_pass.encounter.combat_owner().actor_snapshot(0).vitals,primary_pass.encounter.combat_owner().actor_snapshot(2).vitals])
	if DisplayServer.get_name()!="headless" and difficulty==0.5:
		await render_native(library,bindings,packet,npc_pass.encounter._control.fork_for_frame(false,npc_pass.encounter.combat_owner()),npc_pass.encounter.freighter_resources(),"actual-mixed-contact",0)
		await render_native(library,bindings,packet,later.encounter._control,later.encounter.freighter_resources(),"actual-equipped-primary",2)

func finish() -> void:
	print("Dekato contacts: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
