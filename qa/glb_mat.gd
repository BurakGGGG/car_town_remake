extends SceneTree
func _initialize() -> void:
	var scene: PackedScene = load("res://assets/decor/tyre_pile.glb")
	var n: Node3D = scene.instantiate()
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var m: MeshInstance3D = node
			print("mesh %s: yüzey %d, override=%s" % [m.name, m.mesh.get_surface_count(), m.material_override])
			for i: int in m.mesh.get_surface_count():
				var mat: Material = m.mesh.surface_get_material(i)
				if mat is StandardMaterial3D:
					var sm: StandardMaterial3D = mat
					print("   yüzey %d: %s albedo=%s roughness=%.2f metallic=%.2f" % [i, sm.resource_name,
						sm.albedo_color, sm.roughness, sm.metallic])
				else:
					print("   yüzey %d: %s" % [i, mat])
		for c: Node in node.get_children(): stack.append(c)
	quit(0)
