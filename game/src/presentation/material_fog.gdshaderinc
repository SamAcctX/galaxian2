// Fog belongs to the material pass, not Godot's global exponential fog.
uniform bool source_fog_enabled = false;
uniform vec3 source_fog_color;
uniform float source_fog_end = 1.0;
varying float source_fog_weight;

float source_fog_amount(vec3 point, mat4 model, vec3 eye) {
	if (!source_fog_enabled) { return 0.0; }
	vec3 local_eye = (inverse(model)*vec4(eye,1.0)).xyz;
	return clamp(length(local_eye-point)/source_fog_end,0.0,1.0);
}

vec3 fog_to_linear(vec3 value) {
	return mix(value/12.92,pow(max((value+vec3(0.055))/1.055,vec3(0.0)),vec3(2.4)),greaterThan(value,vec3(0.04045)));
}

vec3 fog_to_display(vec3 value) {
	return mix(value*12.92,1.055*pow(max(value,vec3(0.0)),vec3(1.0/2.4))-0.055,greaterThan(value,vec3(0.0031308)));
}

vec3 source_fog_display(vec3 value) {
	return mix(value,source_fog_color,source_fog_weight);
}

vec3 source_fog_linear(vec3 value) {
	if (!source_fog_enabled) { return value; }
	return OUTPUT_IS_SRGB ? source_fog_display(value) : fog_to_linear(source_fog_display(fog_to_display(value)));
}
