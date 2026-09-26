extends RefCounted
## Transactional source41 cast, bodies and player from the native late portal.
## The enclosing source41 environment/flight must provide the post-field RNG;
## constructing these components alone does not activate or save a new world.
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Body=preload("res://src/simulation/opening_combat_actor.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Entry=preload("res://src/simulation/selected41_portal_entry.gd")
const Rules=preload("res://src/content/selected41_population_definitions.gd")
var error:=""
var _entry: RefCounted
var _factory: RefCounted
var _player: RefCounted
var _bodies: Array=[]

func prepare(bindings: RefCounted,catalogues: RefCounted,entry: RefCounted,post_field_random: Variant) -> bool:
	error=""
	if _entry!=null:return reject("Prepare source41 construction exactly once")
	if not entry is Entry or entry.snapshot().is_empty():return reject("Source41 construction requires its actual native portal transaction")
	var factory:=Factory.new()
	if not factory.configure_selected41(bindings,catalogues,entry) or factory.generate(post_field_random).is_empty():return reject(factory.error)
	return _prepare_factory(bindings,catalogues,entry,factory)

## Consume the exact factory already generated after the native field. Never
## draw another cast or use a snapshot dictionary as construction authority.
func prepare_initialized(bindings: RefCounted,catalogues: RefCounted,entry: RefCounted,world: RefCounted) -> bool:
	error=""
	if _entry!=null:return reject("Prepare source41 construction exactly once")
	if not entry is Entry or not is_instance_of(world,load("res://src/simulation/opening_world_initialization.gd")):return reject("Source41 components require their native initialized world")
	if entry.snapshot().is_empty() or world.snapshot().get("selected41_entry")!=entry.snapshot():return reject("Source41 initialized world belongs to another portal transaction")
	var factory: RefCounted=world.npc_construction_owner()
	if factory==null:return reject("Generate source41 world before preparing its bodies")
	return _prepare_factory(bindings,catalogues,entry,factory)

func _prepare_factory(bindings: RefCounted,catalogues: RefCounted,entry: RefCounted,factory: RefCounted) -> bool:
	var bodies:=[]
	for id in int(Rules.VALUES.actor_count):
		var body:=Body.new()
		if not body.configure_selected41(bindings,catalogues,factory,id):return reject(body.error)
		bodies.append(body)
	var player:=Player.new()
	if not player.configure_selected41(bindings,catalogues,entry,factory):return reject(player.error)
	_entry=entry.fork();_factory=factory;_player=player;_bodies=bodies
	return true

func snapshot() -> Dictionary:
	if _entry==null:return {}
	return {"scope":"source41_native_components","campaign_cursor":41,"entry":_entry.snapshot(),
		"construction":_factory.snapshot(),"actors":_bodies.map(func(body):return body.snapshot()),"player":_player.snapshot(),
		"player_pose":Transform3D(Basis.IDENTITY,Vector3(Rules.VALUES.player_position[0],Rules.VALUES.player_position[1],Rules.VALUES.player_position[2])),
		"application_committed":false}

func matches_departure(departure: RefCounted) -> bool:return _entry!=null and _entry.matches_departure(departure)
func entry_owner() -> RefCounted:return null if _entry==null else _entry.fork()
func npc_construction_owner() -> RefCounted:return _factory
func player_owner() -> RefCounted:return null if _player==null else _player.fork_for_frame()
func body_owner(id: int) -> RefCounted:return null if id<0 or id>=_bodies.size() else _bodies[id].fork_for_frame()
func reject(message: String) -> bool:error=message;return false
