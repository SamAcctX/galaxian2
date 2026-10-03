extends RefCounted
## One radial pulse. Physics supplies admitted targets; combat and scenery own
## damage permission, consequences and attribution when the pulse is committed.
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Mines=preload("res://src/content/mine_definitions.gd")
var error:=""

func evaluate(weapon: Dictionary,shot: Dictionary,targets: Array) -> Dictionary:
	error=""
	var hits:=[]
	for target in targets:
		if not target.active or (weapon.kind==6 and target.emp_immune):continue
		var difference: Vector3=target.position-shot.position
		var distance:=Vitals.single(sqrt(Vectors.dot(difference,difference)))
		if not is_finite(distance) or distance>Vitals.MAX_SHIELD:return fail("Area target distance exceeds supported coordinates")
		var whole:=int(distance)
		if whole>=weapon.radius:continue
		var reach: float=Mines.FALLOFF_DISTANCE if weapon.kind==11 else float(weapon.radius)
		var fraction:=clampf(Vitals.single(Vitals.single(reach-float(whole))/Vitals.single(reach)),0.0,1.0)
		var amount:=fraction
		if weapon.kind in [7,11,42] and target.emp_immune:amount=Vitals.single(amount*Vitals.single(0.6))
		var hit:={"actor_id":target.actor_id,"system_damage":int(Vitals.single(float(weapon.system_damage)*amount)),"distance":whole}
		if target.has("target"):hit.target=target.target.duplicate()
		if weapon.kind in [7,11,42]:
			hit.normal_damage=int(Vitals.single(float(weapon.damage)*amount))
			hit.impact_vector=Vectors.normalized(difference);hit.motion_scalar=fraction
		hits.append(hit)
	return {"base_content_id":weapon.base_content_id,"binding_id":weapon.binding_id,
		"projectile_id":shot.id,"item_id":weapon.item_id,"position":shot.position,"hits":hits}

func fail(message: String) -> Dictionary:error=message;return {}
