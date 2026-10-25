extends SceneTree
## ARAÇ UZAK LOD'U (vehicles/car_far_lod.gd, tools/far_lod/): her aracın dosyası var ve içe aktarılmış mesh'lerle eşleşiyor
## (model değişip dosya eskimişse FAIL: tools/far_lod/make_far_lod.sh <araç>); CarMeshMerger birleşik mesh'e en kaba
## kademe olarak ekliyor; indeks kodlaması gidiş-dönüş aynı. PENCERELİ (başsızda mesh verisi okunamaz).
##   tools/run_tests.sh far_lod_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	print("== 1) KODLAMA ==")
	var sample: PackedInt32Array = PackedInt32Array([0, 65535, 1, 32768, 32767, 0, 40000, 7, 65535, 65534, 3, 2])
	var decoded: PackedInt32Array = PackedInt32Array([-1])
	CarFarLod.append_decoded(decoded, CarFarLod.encode(sample, 65536), 65536, 100)
	var expected: PackedInt32Array = PackedInt32Array([-1])
	for i: int in sample:
		expected.append(i + 100)
	check(decoded == expected, "16 bit fark kodlaması uçlarda (0 / 65535 sarması) gidiş-dönüş aynı, kaydırma eklenir")
	var wide: PackedInt32Array = PackedInt32Array([70000, 0, 123456])
	var wide_out: PackedInt32Array = PackedInt32Array()
	CarFarLod.append_decoded(wide_out, CarFarLod.encode(wide, 200000), 200000, 0)
	check(wide_out == wide, "65536'dan çok köşede düz 32 bit")

	print("== 2) DOSYALAR GÜNCEL ==")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://vehicles/cars.json"))
	var missing: PackedStringArray = PackedStringArray()
	var stale: PackedStringArray = PackedStringArray()
	var thin: PackedStringArray = PackedStringArray()
	var surfaces: int = 0
	for car: Dictionary in data["cars"]:
		var car_root: Node3D = (load(car["scene_path"]) as PackedScene).instantiate() as Node3D
		var path: String = ""
		var matched: int = 0
		var bad: int = 0
		for node: Node in car_root.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node as MeshInstance3D
			if mi.mesh == null or CarFarLod.path_for(mi.mesh) == "":
				continue
			path = CarFarLod.path_for(mi.mesh)
			for surface: int in mi.mesh.get_surface_count():
				var far: Array = CarFarLod.lookup(mi.mesh, surface)
				if far.is_empty():
					continue
				var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				if CarFarLod.matches(far, vertices):
					matched += 1
				else:
					bad += 1
		car_root.free()
		surfaces += matched
		if path == "" or not ResourceLoader.exists(path):
			missing.append(car["id"])
		elif bad > 0:
			stale.append("%s (%d parça)" % [car["id"], bad])
		elif matched == 0:
			thin.append(String(car["id"]))
	check(missing.is_empty(), "her aracın uzak kademe dosyası var %s" % ["" if missing.is_empty() else str(missing)])
	check(stale.is_empty(), "dosyalar içe aktarılmış mesh'lerle eşleşiyor (köşe sayısı + ilk köşe) %s"
		% ["" if stale.is_empty() else str(stale)])
	# Toros'un gövdesi tek mesh (Blender'da kuruldu): bir parça yeter
	check(thin.is_empty(), "her araçta en az bir parçanın uzak kademesi var %s" % ["" if thin.is_empty() else str(thin)])
	print("  ·    %d parça uzak kademeli" % surfaces)

	print("== 3) BİRLEŞİK MESH ==")
	# Godot'nun bu eşikte seçeceği kademe (mesh_surface_get_lod: eşiği aşmayan son kademe): uzak kademe eşiğinin biraz üstü
	var allowed: float = 0.004 * CarFarLod.SWITCH_MARGIN * 1.05
	for id: StringName in [&"bmw_e46", &"lambo_huracan"]:
		var scene_path: String = CarCatalog.scene_path(id)
		var at_threshold: Array[int] = []
		var coarsest: Array[int] = []
		for enabled: bool in [false, true]:
			CarFarLod.enabled = enabled
			CarMeshMerger.clear_cache()
			var car: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
			root.add_child(car)
			var parts: Array = []
			for node: Node in car.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = node as MeshInstance3D
				for s: int in mi.mesh.get_surface_count():
					parts.append([mi.mesh, s, CarMeshMerger.relative(mi, car), 0, INF])
			var merged: ArrayMesh = CarMeshMerger.build(parts, 1, true)
			var picked: int = 0
			var last: int = 0
			var ordered: bool = true
			for s: int in merged.get_surface_count():
				var raw: Dictionary = RenderingServer.mesh_get_surface(merged.get_rid(), s)
				var width: int = 2 if int(raw["vertex_count"]) <= 65536 else 4
				var lods: Array = raw.get("lods", [])
				var chosen: int = int(raw["index_count"])
				var previous_edge: float = 0.0
				var previous_count: int = int(raw["index_count"])
				for lod: Dictionary in lods:
					var count: int = (lod["index_data"] as PackedByteArray).size() / width
					ordered = ordered and float(lod["edge_length"]) > previous_edge and count <= previous_count
					previous_edge = float(lod["edge_length"])
					previous_count = count
					if float(lod["edge_length"]) <= allowed:
						chosen = count
				picked += chosen / 3
				last += previous_count / 3
			at_threshold.append(picked)
			coarsest.append(last)
			if enabled:
				check(ordered, "%s: kademe eşikleri artan, üçgen sayıları azalan sırada" % id)
			car.free()
		CarFarLod.enabled = true
		check(at_threshold[1] < at_threshold[0] * 0.6, "%s: şehrin olağan uzaklığında (sapma %.4f) uzak kademe seçilir (%d → %d üçgen)"
			% [id, allowed, at_threshold[0], at_threshold[1]])
		check(coarsest[1] <= coarsest[0], "%s: zorla en kaba kademe (garajın uzak araçları) eskisinden çok üçgen çizmez (%d → %d üçgen)"
			% [id, coarsest[0], coarsest[1]])
	CarMeshMerger.clear_cache()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
