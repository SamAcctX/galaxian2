shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
#define SKY_STORED_CHANNELS
#include "res://src/presentation/sky_vertex.gdshaderinc"
uniform sampler2D opaque_background : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	// Stars belong to the opaque pass. At far depth this cannot overwrite
	// foreground geometry, and later alpha geometry still blends over the sky.
	vec3 stars = texture(opaque_background, SCREEN_UV).rgb;
	vec3 nebula = sky_channels(UV);
	ALBEDO = sky_to_scene(clamp(stars + nebula, vec3(0.0), vec3(1.0)));
	ALPHA = 1.0;
}
