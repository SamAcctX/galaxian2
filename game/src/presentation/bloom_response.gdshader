shader_type canvas_item;
render_mode unshaded, blend_disabled;

void fragment() {
	vec3 channel = texture(TEXTURE, UV).rgb;
	// Per-channel display-range highlight response; this is not scene exposure.
	vec3 excess = max(channel * (channel * (6250000.0 / 321489.0)
		+ vec3(5.0 / 81.0)) - vec3(5.0), vec3(0.0));
	COLOR = vec4(excess / (vec3(10.0) + excess), 1.0);
}
