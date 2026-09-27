shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, skip_vertex_transform;

uniform sampler2D diffuse_texture : source_color, filter_linear_mipmap_anisotropic;
varying vec3 cloud_tint;

void vertex() {
	// Only the center follows the world transform; each square faces the viewer.
	VERTEX = (MODELVIEW_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz + VERTEX;
	cloud_tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = texture(diffuse_texture,UV).rgb * cloud_tint;
	// The cloud pass adds RGB directly, independently of the texture's alpha.
	ALPHA = 1.0;
}
