shader_type spatial;
// Participate in the opaque screen copy. The shared vertex owner writes only
// the far/clear depth, so this does not cover any foreground geometry.
render_mode unshaded, depth_draw_opaque, cull_back, fog_disabled;
#define SKY_STORED_CHANNELS
#include "res://src/presentation/sky_vertex.gdshaderinc"
void fragment() {
	// Carry channel values until the nebula completes the sky. Decoding and
	// re-encoding at this intermediate target needlessly loses dark precision.
	ALBEDO = clamp(sky_channels(UV), vec3(0.0), vec3(1.0));
}
