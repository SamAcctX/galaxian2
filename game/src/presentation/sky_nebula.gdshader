shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
#include "res://src/presentation/sky_vertex.gdshaderinc"
uniform vec3 nebula_black_level = vec3(0.0);
void fragment() {
	ALBEDO = max(source_diffuse(UV).rgb - nebula_black_level, vec3(0.0)) / (vec3(1.0) - nebula_black_level);
	ALPHA = 1.0;
}
