extends RefCounted
## Shared validation for already-resolved ordinary non-player weapon damage.
## The target owner implements its own contact prelude and consequences.
const Turrets=preload("res://src/content/manual_turret_definitions.gd")
const Beams=preload("res://src/content/beam_primary_definitions.gd")
const Secondary=preload("res://src/content/conventional_secondary_definitions.gd")
const Definitions = preload("res://src/content/ordinary_hit_definitions.gd")
const Vitals = preload("res://src/simulation/combat_vitals.gd")

static func validate(weapon: Variant, identity: Dictionary, policy: Dictionary, kinds: Array=[0]) -> String:
	if identity.is_empty() or policy.is_empty() or not Definitions.parameters(policy) or not weapon is Dictionary:
		return "Weapon hit requires a configured target owner and resolved weapon"
	for key in identity:
		if weapon.get(key)!=identity[key]: return "Weapon hit belongs to another content or binding identity"
	for key in ["item_id","category","kind","damage"]:
		if not Vitals.integer(weapon.get(key)): return "Invalid resolved hit weapon field: "+key
	if (weapon.category!=0 and not Secondary.resolved(weapon) and not Turrets.resolved(weapon)) or weapon.kind not in kinds or (weapon.get("launch_mode")!="ordinary" and not Beams.resolved(weapon)) or not Definitions.resolved(weapon.get("ordinary_hit_policy"),weapon.damage):
		return "Weapon lacks supported ordinary non-player hit declarations"
	if weapon.has("nonplayer_source") and not weapon.nonplayer_source is bool:return "Invalid ordinary damage attribution"
	var extra: int=weapon.ordinary_hit_policy.additional_damage
	if weapon.ordinary_hit_policy.additional_damage_required!=(extra!=int(policy.missing_additional_damage)) or (extra!=int(policy.missing_additional_damage) and not Vitals.integer(extra)):
		return "Weapon has inconsistent systems damage"
	return ""
