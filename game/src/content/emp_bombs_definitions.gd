extends RefCounted
## Original player EMP bomb flight, blast and systems recovery.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const VALUES = {"scope":"player_emp_bomb_physics","category":1,"kind":6,"item_ids":[41,42,43],"model_ids":[14684,14684,14684],"capacity":1,"system_damage_property":10,"blast_radius_property":14,"muzzle_offset":[0.0,0.0,400.0],"cooldown_initial_interval":true,"cooldown_strict":true,"ammunition_per_launch":1,"ammunition_per_detonation":0,"manual_detonation":true,"contact_detonation":true,"expiry_detonation":true,"blast_distance_truncated":true,"blast_radius_strict":true,"linear_system_damage":true,"normal_damage":false,"detonated_lifetime":-1,"systems":{"scope":"emp_system_damage_and_recovery","requires_active":true,"requires_damage_permission":true,"requires_positive_hull":true,"requires_positive_integrity":true,"partial_integrity_recovers":false,"recovery_while_disabled":true,"recovery_strict":true,"depletion_resets_recovery":true,"affects_combat_pools":false}}
const SPANS = {"emp_factory_case":[67190,4],"emp_factory":[65815,232],"emp_muzzle_offset":[1574918,4],"emp_models":[1576622,12],"emp_radius_assignment":[-35845,29],"emp_radius_setter":[-188312,12],"emp_initial_clock":[-189587,54],"emp_owner_trigger":[543530,362],"emp_launch_quantity":[-187771,81],"emp_launch_position":[-187669,706],"emp_launch_direction":[-186542,206],"emp_launch_motion":[-186124,147],"emp_launch_consume":[-185977,281],"emp_frame_clock":[-180349,57],"emp_frame_motion":[-180195,539],"emp_collision_kind":[-183037,134],"emp_collision_detonation":[-182388,18],"emp_collision_tail":[-180382,13],"emp_pulse":[-184530,1454],"emp_active_getter":[540924,14],"emp_immune_getter":[535540,28],"emp_system_configuration":[535708,56],"emp_system_damage_gates":[538094,81],"emp_system_subtract":[538465,23],"emp_system_disabled":[538870,40],"emp_system_recovery":[544763,112]}

# Native composition.
const MAC_SPANS = {"emp_factory_case":[67190,4],"emp_factory":[65815,232],"emp_muzzle_offset":[1549982,4],"emp_models":[1551686,12],"emp_radius_assignment":[-35845,29],"emp_radius_setter":[-188804,12],"emp_initial_clock":[-190079,54],"emp_owner_trigger":[544066,362],"emp_launch_quantity":[-188263,81],"emp_launch_position":[-188161,706],"emp_launch_direction":[-187034,206],"emp_launch_motion":[-186616,147],"emp_launch_consume":[-186469,281],"emp_frame_clock":[-180841,57],"emp_frame_motion":[-180687,539],"emp_collision_kind":[-183529,134],"emp_collision_detonation":[-182880,18],"emp_collision_tail":[-180874,13],"emp_pulse":[-185022,1454],"emp_active_getter":[541460,14],"emp_immune_getter":[536076,28],"emp_system_configuration":[536244,56],"emp_system_damage_gates":[538630,81],"emp_system_subtract":[539001,23],"emp_system_disabled":[539406,40],"emp_system_recovery":[545299,112]}

## Valkyrie guided antimatter missile (Liberator). The catalogue's guidance
## attribute decides steering; this row only names its original assets/sounds.
## Chase camera and turn factor come from the original launcher; the turn time
## unit is an assumption (radians per 60 Hz frame, see research note).
const GUIDED = {"item_id":179,"model_id":14293,"attachment_id":14294,"launch_sound":1117,"burst_sound":12,
	"guidance_sound":1116,"guided_property":15,"camera_offset":[0.0,450.0,-1400.0],"camera_target":[0.0,0.0,1700.0],
	"turn_factor":0.003,"turn_frame_ms":1000.0/60.0}

static func parameters(data: Variant) -> bool:return Equal.equal_value(data,VALUES)

## Supernova Shock Blast: no projectile body; the blast starts at the ship
## itself (glow model scaled 50000) and its launch sound is the blast.
const SHOCK = {"item_id":226,"kind":42,"glow_model_id":18996,"glow_scale":50000.0,"launch_sound":2269,"self_damage_factor":0.2}

## Supernova Fireworks: an unguided bomb with no glow attachment that bursts
## as the firework look-at model (explosion type 13) at a quarter of its size.
## It has its own burst family (43). Assumptions: sound 2280 is its launch
## sound; the burst is silent; the flying particle trail is not drawn.
const FIREWORKS = {"item_id":232,"model_id":27338,"family":43,"burst_model_id":16809,"burst_scale":0.25,"launch_sound":2280}

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and parameters(bindings.mido_travel.get("emp_bombs"))

## Both original area-bomb families share launch and detonation ownership.
## Damage, timing, speed and radius remain catalogue values.
static func declaration(item_id: int) -> Dictionary:
	var index: int=VALUES.item_ids.find(item_id)
	if index>=0:return {"kind":6,"model_id":14684,"attachment_id":14685,"effect_type":7,"launch_sound":6+index,"burst_sound":15+index}
	if item_id==int(GUIDED.item_id):
		return {"kind":7,"model_id":int(GUIDED.model_id),"attachment_id":int(GUIDED.attachment_id),"effect_type":0,
			"launch_sound":int(GUIDED.launch_sound),"burst_sound":int(GUIDED.burst_sound)}
	if item_id==int(SHOCK.item_id):
		return {"kind":int(SHOCK.kind),"model_id":-1,"attachment_id":-1,"effect_type":7,"launch_sound":int(SHOCK.launch_sound),"burst_sound":-1}
	if item_id==int(FIREWORKS.item_id):
		return {"kind":7,"family":int(FIREWORKS.family),"model_id":int(FIREWORKS.model_id),"attachment_id":-1,"effect_type":7,
			"launch_sound":int(FIREWORKS.launch_sound),"burst_sound":-1}
	if item_id not in [44,45,46]:return {}
	return {"kind":7,"model_id":14682 if item_id==46 else 14680,
		"attachment_id":14683 if item_id==46 else 14681,"effect_type":0,
		"launch_sound":item_id-35,"burst_sound":58-item_id}

## The burst family an item's detonation draws (its kind unless it has its own).
static func effect_family(item_id: int) -> int:
	var row:=declaration(item_id)
	return int(row.get("family",row.get("kind",-1)))
