shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, skip_vertex_transform;

uniform sampler2D diffuse_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_specular_texture : filter_linear_mipmap_anisotropic;
uniform vec3 light_direction;
uniform vec3 ambient_color;
uniform vec3 diffuse_color;
uniform vec3 specular_color;
uniform float specular_power;
uniform float diffuse_bias;
uniform float normal_bias;
varying vec3 key_in_view;
varying vec3 half_in_view;
varying float opacity;

void vertex() {
	float half_size = length(MODEL_MATRIX[0].xyz);
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz;
	VERTEX = center + VERTEX*half_size;
	key_in_view = mat3(VIEW_MATRIX)*light_direction;
	half_in_view = normalize(normalize(-VERTEX)+key_in_view);
	// Same fade as the field's opacity(): in from 2000 units, out near 10000.
	float distance_squared = dot(center,center);
	opacity = COLOR.a*min(clamp(distance_squared/4000000.0,0.0,1.0),clamp((100000000.0-distance_squared)/75000000.0,0.0,1.0));
}

vec3 display_to_linear(vec3 value) {
	return mix(value/12.92,pow(max((value+vec3(0.055))/1.055,vec3(0.0)),vec3(2.4)),greaterThan(value,vec3(0.04045)));
}

void fragment() {
	vec4 pigment = texture(diffuse_texture,UV,diffuse_bias);
	vec4 detail = texture(normal_specular_texture,UV,normal_bias);
	vec3 facing = detail.rgb*2.0-1.0;
	vec3 light = ambient_color+diffuse_color*clamp(dot(facing,key_in_view),0.0,1.0);
	vec3 highlight = detail.a*specular_color*pow(clamp(dot(facing,half_in_view),0.0,1.0),specular_power);
	vec3 response = pigment.rgb*light+highlight;
	ALBEDO = OUTPUT_IS_SRGB ? response : display_to_linear(response);
	ALPHA = pigment.a*opacity;
}
