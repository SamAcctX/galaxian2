shader_type canvas_item;
render_mode unshaded;

uniform sampler2D glare : filter_linear, repeat_disable;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 displayed = min(base.rgb + texture(glare, UV).rgb, vec3(1.0));
	COLOR = vec4(displayed, base.a) * item_tint;
}
