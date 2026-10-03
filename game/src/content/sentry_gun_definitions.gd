extends RefCounted
## Supernova sentry guns (secondary sort 39). One press places a friendly gun
## turret where the ship is; it turns toward the nearest hostile ship and shoots
## it with the item's own damage, interval, shot lifetime and speed.
## base/head: the turret mesh and its additive glow, drawn at half size.
## gun_item/kind/shot_model: the ordinary shot the turret fires (verified
## Level::assignGuns). muzzle: distance ahead of the turret where shots start.
const CAPACITY:=3
const HULL:=100
## Safe from damage for its first three seconds after placement.
const ARMING_MS:=3000
## Its explosion plays for 4.5 s before the slot can be reused.
const DEATH_MS:=4500
const DEATH_SOUND:=22
const SCALE:=0.5
## Same aiming rules as the original's other turret objects (static_turret.gd);
## a sentry turns its whole body, so it has no pitch stops.
const AIM:={"barrel_offset":Vector3.ZERO,"range":50000,"retarget_ms":3000,"lead":1500.0,
	"turn_ms":4096,"aim_tolerance":0.05,"pitch_up_ms":2048,"pitch_down_ms":2048}

static func declaration(item_id: int) -> Dictionary:
	match item_id:
		211:return {"base":18880,"head":18886,"gun_item":2,"kind":0,"shot_model":6756,"muzzle":250.0}
		212:return {"base":18881,"head":18887,"gun_item":20,"kind":1,"shot_model":6797,"muzzle":250.0}
		213:return {"base":18882,"head":18888,"gun_item":14,"kind":1,"shot_model":6790,"muzzle":300.0}
	return {}
