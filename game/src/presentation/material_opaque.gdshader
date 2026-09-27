shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
#include "res://src/presentation/material_uv.gdshaderinc"
void fragment() {
	ALBEDO = source_fogged_diffuse(UV).rgb;
}
