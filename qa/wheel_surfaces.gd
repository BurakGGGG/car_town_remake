extends SceneTree
## Her aracın teker mesh'leri kaç yüzeyli ve dokulu mu? (_needs_wheel_split regresyon kontrolü)
func _init() -> void:
	var split_on: int = 0
	var split_off: int = 0
	for entry: Dictionary in CarCatalog.all():
		var path: String = entry["scene_path"]
		var root: Node3D = (load(path) as PackedScene).instantiate()
		var map: Dictionary = CarPartMap.get_map(path)
		var by_name: Dictionary = {}
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			by_name[m.name] = m
		var rows: PackedStringArray = PackedStringArray()
		for index: int in map.get("wheels", []):
			var m: MeshInstance3D = by_name.get("tripo_part_%d" % index)
			if m == null:
				continue
			var mat: BaseMaterial3D = m.mesh.surface_get_material(0) as BaseMaterial3D
			var need: bool = CarRig._needs_wheel_split(m)
			rows.append("%d:y%d%s%s" % [index, m.mesh.get_surface_count(),
				"D" if mat and mat.albedo_texture else "-", "+" if need else "!"])
			if need: split_on += 1
			else: split_off += 1
		print("%-22s %s" % [entry["id"], " ".join(rows)])
		root.free()
	print("--- shader takilan teker: %d, takilmayan: %d ---" % [split_on, split_off])
	quit()
