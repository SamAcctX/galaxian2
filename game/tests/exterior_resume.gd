extends "res://tests/freelance_resume_application.gd"
## Inspect shared exterior rendering after a real saved career departs.
func capture_free_application(label: String) -> void:
	if label=="freelance-resumed-station":
		var station: Node3D=app.session
		for child in station.geometry.models:
			for material in child.materials:check(material.shader!=preload("res://src/presentation/imported_material.gdshader"),"Saved station retained generic PBR shading")
		check(station.lighting.lights.size()==2 and station.reflection.texture!=null,"Saved station omitted interior lighting or reflections")
		for frame in 20:await process_frame
	if label=="freelance-paid-resumed-flight":
		var scene: Node3D=app.session.scene
		var shaded:=0
		for child in scene.find_children("*","",true,false):
			if child.get_script()!=preload("res://src/presentation/imported_model.gd"):continue
			for material in child.materials:
				check(material.shader!=preload("res://src/presentation/imported_material.gdshader"),"Ordinary flight retained an unprepared opaque exterior")
				if material.shader==preload("res://src/presentation/surface_response.gdshader"):shaded+=1
		check(shaded>0 and scene.lighting.lights.size()==2 and scene.reflection.texture!=null,"Ordinary flight omitted location lighting or reflections")
		# Scene construction can enqueue shader pipelines after the input sequence.
		# Sample the settled rendered view while the application clock is held.
		for frame in 20:await process_frame
	await super.capture_free_application(label)
