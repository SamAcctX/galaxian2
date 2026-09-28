shader_type spatial;
render_mode cull_disabled;
#include "res://src/presentation/material_sampling.gdshaderinc"
uniform sampler2D normal_specular_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool has_normal_specular = false;
uniform sampler2D cloak_mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D background : source_color, filter_linear;
uniform float dissolve = 0.0;
uniform float animation_seconds = 0.0;

void vertex() {
	imported_vertex_color = has_vertex_color ? CUSTOM0 : vec4(1.0);
	// A smooth native interference field, driven by accepted simulation time.
	vec3 phase = VERTEX * 8.0 + vec3(animation_seconds, 0.0, 0.0);
	vec3 ripple = sin(phase.yzx + sin(phase.zxy * 0.71));
	VERTEX += ripple * (4.0 * clamp(dissolve * 2.0, 0.0, 1.0));
}

void fragment() {
	vec2 coordinates = source_uv(UV);
	vec4 packed_normal = has_normal_specular ? texture(normal_specular_texture, coordinates) : vec4(0.5, 0.5, 1.0, 0.0);
	float mask = texture(cloak_mask, coordinates).r;
	float threshold = dissolve * 1.1 - 0.05;
	float covered = smoothstep(mask - 0.025, mask + 0.025, threshold);
	float edge = 1.0 - smoothstep(0.0, 0.05, abs(mask - threshold));
	vec2 ripple = (packed_normal.xy * 2.0 - 1.0) * vec2(100.0 * sin(animation_seconds), 75.0 * cos(animation_seconds));
	vec2 screen = clamp(SCREEN_UV + ripple / VIEWPORT_SIZE, vec2(0.0), vec2(1.0));
	vec3 pigment = has_diffuse ? source_diffuse(UV).rgb : vec3(0.46, 0.55, 0.64) * imported_vertex_color.rgb;
	ALBEDO = pigment * (1.0 - covered);
	EMISSION = texture(background, screen).rgb * covered + vec3(0.6, 0.8, 1.0) * edge;
	ROUGHNESS = 0.55;
	SPECULAR = packed_normal.a * (1.0 - covered);
	if (has_normal_specular) { NORMAL_MAP = packed_normal.rgb; }
	// Screen refraction belongs after the opaque world, including at full cloak.
	ALPHA = 1.0;
}
