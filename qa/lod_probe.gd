extends SceneTree
## LOD YAPISI: araç modellerinin (özgün parçalar ve birleşik mesh) LOD kademelerinde kaç üçgen kaldığı.
## LOD katsayısı düşürüldüğü hâlde üçgen azalmıyorsa en kaba kademe yüksek demektir.
## Kullanım: tools/qa_isolated.sh res://qa/lod_probe.gd --display-driver x11 --resolution 640x360 -- <araç_id> ...

func _initialize() -> void:
	_run.call_deferred()


func _surface_lods(mesh: Mesh, s: int) -> Array:
	var raw: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
	var wide: bool = int(raw.get("vertex_count", 0)) > 65536
	var base: int = int(raw.get("index_count", 0)) / 3
	var out: Array = [base]
	for lod: Dictionary in raw.get("lods", []):
		var bytes: PackedByteArray = lod["index_data"]
		out.append([snappedf(float(lod["edge_length"]), 0.0001), bytes.size() / (4 if wide else 2) / 3])
	return out


func _run() -> void:
	await process_frame
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["bmw_e46", "hyundai_getz", "lambo_huracan"])
	for id: String in ids:
		var path: String = CarCatalog.scene_path(StringName(id))
		var car: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(car)
		# Özgün parçalar: kademe başına toplam üçgen (her parçanın k. LOD'u, yoksa en kabası)
		var per_level: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
		var parts: int = 0
		var no_lod: int = 0
		var no_lod_tris: int = 0
		for node: Node in car.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			if mi.mesh == null:
				continue
			for s: int in mi.mesh.get_surface_count():
				parts += 1
				var lods: Array = _surface_lods(mi.mesh, s)
				if lods.size() == 1:
					no_lod += 1
					no_lod_tris += int(lods[0])
				for k: int in per_level.size():
					var tris: int = int(lods[0]) if k == 0 else int((lods[mini(k, lods.size() - 1)] as Array)[1]) if lods.size() > 1 else int(lods[0])
					per_level[k] += tris
		print("LOD %s: %d parça yüzeyi, LOD'suz %d (%d üçgen) | kademe üçgenleri %s" % [id, parts, no_lod, no_lod_tris, str(per_level)])
		# Birleşik mesh (önbellekten ya da şimdi kur)
		var rig: CarRig = CarRig.new(car)
		rig.apply(CarAppearance.get_for(path))
		var got: Array = []
		rig.optimize(true)
		for i: int in 600:
			await process_frame
			var merged: MeshInstance3D = car.find_child("MergedParts", true, false) as MeshInstance3D
			if merged and merged.mesh:
				got.append(merged.mesh)
				break
		if got.is_empty():
			print("LOD %s: birleşik mesh oluşmadı" % id)
		else:
			var mesh: Mesh = got[0]
			for s: int in mesh.get_surface_count():
				print("LOD %s birleşik yüzey %d: %s" % [id, s, str(_surface_lods(mesh, s))])
		car.queue_free()
		await process_frame
	quit(0)
