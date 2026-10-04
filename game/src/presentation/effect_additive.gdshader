shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
#include "res://src/presentation/effect_texture.gdshaderinc"
#include "res://src/presentation/material_coordinates.gdshaderinc"

// Expansion effects carry per-vertex colours in CUSTOM0.
uniform bool vertex_colors = false;
varying vec3 vertex_color;

void vertex() {
	vertex_color = vertex_colors ? CUSTOM0.rgb : vec3(1.0);
}

void fragment() {
	ALBEDO = effect_color(source_uv(UV)).rgb * vertex_color;
	// Source type 2 uses ONE, ONE: texture/tint alpha is not a blend factor.
	ALPHA = 1.0;
}
