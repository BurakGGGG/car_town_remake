extends SceneTree
## DEKOR SAYIMI: garajdaki her eşya türü için adet, örnek başına mesh / yüzey / üçgen / farklı materyal.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/decor_census.gd --headless

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 150:
		await process_frame
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	var bodies: Dictionary = view.get("_bodies")
	var stats: Dictionary = {}
	for iid: String in bodies:
		var body: Node3D = bodies[iid]
		var item: String = String(body.get_child(0).name) if body.get_child_count() > 0 else "?"
		var meshes: int = 0
		var surfaces: int = 0
		var tris: int = 0
		var materials: Dictionary = {}
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			if mi.mesh == null:
				continue
			meshes += 1
			for s: int in mi.mesh.get_surface_count():
				surfaces += 1
				var arrays: Array = mi.mesh.surface_get_arrays(s)
				var index: Variant = arrays[Mesh.ARRAY_INDEX]
				tris += (index as PackedInt32Array).size() / 3 if index is PackedInt32Array and (index as PackedInt32Array).size() > 0 \
					else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				var mat: Material = mi.get_active_material(s)
				materials[mat.get_instance_id() if mat else 0] = true
		if not stats.has(item):
			stats[item] = {"n": 0, "meshes": meshes, "surfaces": surfaces, "tris": tris, "mats": materials.size()}
		stats[item]["n"] += 1
	var keys: Array = stats.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return stats[a]["n"] * stats[a]["surfaces"] > stats[b]["n"] * stats[b]["surfaces"])
	print("| eşya | adet | mesh/örnek | yüzey/örnek | farklı materyal | üçgen/örnek | TOPLAM yüzey | TOPLAM üçgen |")
	for k: String in keys:
		var e: Dictionary = stats[k]
		print("| %s | %d | %d | %d | %d | %d | %d | %dk |" % [k, e["n"], e["meshes"], e["surfaces"], e["mats"], e["tris"],
			e["n"] * e["surfaces"], e["n"] * e["tris"] / 1000])
	quit(0)
