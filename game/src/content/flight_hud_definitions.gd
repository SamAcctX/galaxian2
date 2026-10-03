extends RefCounted
## Flight HUD hit feedback and orbit information (Mac App Store behaviour).
## Image and text ids are original interface-atlas aliases and string ids.

# A hit lights the arc on the centre-frame ellipse facing the shooter. It
# fades out over 300 ms; blue art while any shield remains, red without.
const HIT_ARC_MS:=300
const HIT_ARC_IMAGES:={"side_blue":1324,"side_red":1318,"top_blue":1323,"top_red":1317}
# The shield badge swaps to its hit art for 500 ms while the shield holds.
const SHIELD_HIT_MS:=500
const SHIELD_HIT_IMAGE:=1197

# Orbit information: top-left race logo, station name (white), "<System>
# System" (grey) and the security level (coloured), while the 7 s arrival
# sequence of a flight runs.
const ORBIT_MS:=7000
const ORBIT_MIN_CURSOR:=8
const ORBIT_SYSTEM_LINE_MIN_CURSOR:=16
const ORBIT_SYSTEM_WORD_TEXT:=136
const ORBIT_SYSTEM_GREY:=Color8(0x77,0x77,0x77)

# Source screen width the abeam band was measured in (pixels beyond the edge).
const ABEAM_SCREEN_WIDTHS:=51.0

static func hit_sides(camera_local: Vector3, tangents: Vector2) -> Array:
	## Arcs for a shooter at camera-space position (-Z ahead, as the source).
	## The shooter is projected like a marker: ahead gives the top arc, behind
	## the bottom arc, plus the left/right arc when the projection falls off
	## that screen edge. Behind the camera the projection mirrors sideways, as
	## in the original; a nearly abeam shooter behind lights only the side.
	if not camera_local.is_finite() or camera_local.is_zero_approx():return []
	var behind:=camera_local.z>=0.0
	var depth:=absf(camera_local.z)*maxf(tangents.x,0.000001)
	var offset:=camera_local.x/depth if depth>0.0 else signf(camera_local.x)*INF
	if behind:offset=-offset
	var sides:=[]
	if offset<=-1.0:sides.append("left")
	elif offset>=1.0:sides.append("right")
	if not behind:sides.append("top")
	elif absf(offset)<=ABEAM_SCREEN_WIDTHS or sides.is_empty():sides.append("bottom")
	return sides
