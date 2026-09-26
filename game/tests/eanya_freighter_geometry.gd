extends "res://tests/freighter_geometry.gd"
## Exercise the actual ordinary dispatcher, not a separate Mido renderer.
func configure_detail(selector: RefCounted,bindings: RefCounted,assembly: Dictionary) -> bool:
	return selector.configure_assembly(bindings,assembly)

func build_ship(ship: Node3D,assembly: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted,_shared: RefCounted) -> bool:
	return ship.build_population_assembly(assembly,library,visuals,bindings)
