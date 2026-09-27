extends RefCounted
## Bind fog only to participating material families. Sky and additive passes
## retain their separate shaders and never receive a global fog override.
const State=preload("res://src/simulation/distance_fog.gd")
const SHADERS=[preload("res://src/presentation/material_opaque.gdshader"),
	preload("res://src/presentation/material_alpha.gdshader"),
	preload("res://src/presentation/material_cutout.gdshader"),
	preload("res://src/presentation/material_lit.gdshader"),
	preload("res://src/presentation/surface_response.gdshader"),
	preload("res://src/presentation/sky_planet.gdshader"),
	preload("res://src/presentation/scenery_effect_alpha.gdshader")]

static func apply(material: ShaderMaterial, state: Dictionary) -> void:
	if material.shader not in SHADERS:return
	material.set_shader_parameter("source_fog_enabled",not state.is_empty())
	material.set_shader_parameter("source_fog_color",state.get("color",Vector3.ZERO))
	material.set_shader_parameter("source_fog_end",float(state.get("end",1.0)))

static func apply_models(models: Array, state: Dictionary) -> void:
	for model in models:
		for material in model.materials:apply(material,state)
