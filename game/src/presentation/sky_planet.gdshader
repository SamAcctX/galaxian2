shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;
#include "res://src/presentation/material_sampling.gdshaderinc"
#include "res://src/presentation/material_fog.gdshaderinc"
void vertex() {
	source_fog_weight = source_fog_amount(VERTEX,MODEL_MATRIX,CAMERA_POSITION_WORLD);
	imported_vertex_color = has_vertex_color ? CUSTOM0 : vec4(1.0);
	// The owner adds camera position to the retained source planet position.
	// Keep its finite plane, scale and orientation while drawing behind the world.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = CLIP_SPACE_FAR * POSITION.w;
}
void fragment() {
	vec4 color = source_diffuse(UV);
	ALBEDO = source_fog_linear(color.rgb);
	ALPHA = color.a;
}
