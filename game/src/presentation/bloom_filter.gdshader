shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform vec2 sample_offsets[5];
uniform float sample_weights[5];

void fragment() {
	vec3 filtered = vec3(0.0);
	for (int sample_index = 0; sample_index < 5; sample_index++) {
		filtered += texture(TEXTURE, UV + sample_offsets[sample_index]).rgb
			* sample_weights[sample_index];
	}
	COLOR = vec4(filtered, 1.0);
}
