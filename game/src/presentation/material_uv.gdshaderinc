#include "res://src/presentation/material_sampling.gdshaderinc"
#include "res://src/presentation/material_fog.gdshaderinc"

void vertex() {
	source_fog_weight = source_fog_amount(VERTEX,MODEL_MATRIX,CAMERA_POSITION_WORLD);
	imported_vertex_color = has_vertex_color ? CUSTOM0 : vec4(1.0);
}

vec4 source_fogged_diffuse(vec2 coordinates) {
	vec4 color = source_diffuse(coordinates);
	if (source_fog_enabled) {
		// The fogged texture pass retains modulation of alpha, but blends the
		// texture's own RGB into fog independently of the wrapper's RGB tint.
		vec3 pigment = has_diffuse ? texture(diffuse_texture,source_uv(coordinates)).rgb : vec3(1.0);
		color.rgb = source_fog_linear(pigment);
	}
	return color;
}
