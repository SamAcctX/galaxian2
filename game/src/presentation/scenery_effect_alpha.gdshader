shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled;

#include "res://src/presentation/effect_texture.gdshaderinc"
#include "res://src/presentation/material_fog.gdshaderinc"

void vertex() {
	source_fog_weight = source_fog_amount(VERTEX,MODEL_MATRIX,CAMERA_POSITION_WORLD);
}

void fragment() {
	vec4 pigment = texture(diffuse_texture,UV);
	vec3 response = (source_fog_enabled ? source_fog_display(pigment.rgb) : pigment.rgb*effect_tint.rgb)*darken_value;
	ALBEDO = OUTPUT_IS_SRGB ? response : effect_display_to_linear(response);
	ALPHA = pigment.a*effect_tint.a;
}
