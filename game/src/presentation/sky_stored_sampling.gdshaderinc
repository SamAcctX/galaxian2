#include "res://src/presentation/material_coordinates.gdshaderinc"
// These textures carry the sky's channel values, rather than linear radiance.
uniform sampler2D diffuse_texture : filter_linear_mipmap_anisotropic;
uniform bool has_diffuse = false;
uniform bool has_vertex_color = false;
uniform vec4 surface_tint = vec4(1.0);
varying vec4 imported_vertex_color;

vec3 sky_channels(vec2 uv) {
	vec3 sample_color = has_diffuse ? texture(diffuse_texture, source_uv(uv)).rgb : vec3(1.0);
	return sample_color * imported_vertex_color.rgb * surface_tint.rgb;
}

vec3 sky_to_scene(vec3 channels) {
	if (OUTPUT_IS_SRGB) { return channels; }
	vec3 value = max(channels, vec3(0.0));
	return mix(value / 12.92, pow((value + 0.055) / 1.055, vec3(2.4)), greaterThan(value, vec3(0.04045)));
}
