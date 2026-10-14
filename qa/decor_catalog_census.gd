extends SceneTree
## DEKOR KATALOĞU SAYIMI: katalogdaki HER eşya için gövde kurulur ve sayılır — mesh örneği, yüzey (≈ çizim
## çağrısı), farklı materyal, üçgen (LOD0) ve LOD kademesi. Garajda hangi eşyanın pahalı olduğunu kayıttan
## bağımsız gösterir. Pencereli çalışmalı (başsız sürücüde mesh dizileri okunamaz).
## Kullanım: tools/qa_isolated.sh res://qa/decor_catalog_census.gd --display-driver x11 --resolution 640x360

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rows: Array = []
	for item: Dictionary in GarageDecor.all():
		var id: StringName = StringName(item.get("id", ""))
		if GarageDecor.is_vehicle(id) or not GarageDecor.is_placeable(id):
			continue
		var body: Node3D = DecorBuilder.build_placeable(id)
		if body == null:
			continue
		root.add_child(body)
		var instances: int = 0
		var surfaces: int = 0
		var tris: int = 0
		var materials: Dictionary = {}
		for node: Node in body.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = null
			var count: int = 1
			if node is MeshInstance3D:
				mesh = (node as MeshInstance3D).mesh
			elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
				mesh = (node as MultiMeshInstance3D).multimesh.mesh
				count = (node as MultiMeshInstance3D).multimesh.instance_count
			if mesh == null:
				continue
			instances += 1
			for s: int in mesh.get_surface_count():
				surfaces += 1
				var mat: Material = (node as GeometryInstance3D).material_override
				if mat == null and node is MeshInstance3D:
					mat = (node as MeshInstance3D).get_surface_override_material(s)
				if mat == null:
					mat = mesh.surface_get_material(s)
				materials[mat.get_instance_id() if mat else 0] = true
				var arrays: Array = mesh.surface_get_arrays(s)
				var index: Variant = arrays[Mesh.ARRAY_INDEX]
				var n: int = (index as PackedInt32Array).size() / 3 if index is PackedInt32Array and (index as PackedInt32Array).size() > 0 \
						else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				tris += n * count
		rows.append([String(id), instances, surfaces, materials.size(), tris])
		body.free()
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	print("| eşya | örnek | yüzey | materyal | üçgen |")
	var total_s: int = 0
	var total_t: int = 0
	for r: Array in rows:
		print("| %s | %d | %d | %d | %d |" % [r[0], r[1], r[2], r[3], r[4]])
		total_s += r[2]
		total_t += r[4]
	print("TOPLAM %d eşya, ortalama %.1f yüzey, %.0f üçgen" % [rows.size(), float(total_s) / maxf(rows.size(), 1), float(total_t) / maxf(rows.size(), 1)])
	quit(0)
