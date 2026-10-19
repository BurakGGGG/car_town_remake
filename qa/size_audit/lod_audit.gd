extends SceneTree
## Araç mesh'lerinde taban yerine LOD1 kullanılsa ne kazanılır? Parça başına LOD1 hatası (dünya mm)
## ve eşik başına tahmini ham boyut. Teker rolleri (wheels/tires/rims + wheel_groups) hariç.

const WHEEL_ROLES: Array[String] = ["wheels", "tires", "rims"]
const THRESH_MM: Array[float] = [0.5, 1.0, 2.0, 3.0, 5.0, 1e9]

func _walk(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		_walk(c, out)

func _unique(idx: PackedByteArray, wide: bool) -> int:
	var seen := {}
	if wide:
		var a := idx.to_int32_array()
		for v in a:
			seen[v] = true
	else:
		for k in range(0, idx.size(), 2):
			seen[idx.decode_u16(k)] = true
	return seen.size()

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://vehicles/cars.json"))
	var only: String = OS.get_environment("ONLY")
	var base_total := 0
	var new_total := {}
	for t in THRESH_MM:
		new_total[t] = 0
	var err_hist := {}
	for car in data["cars"]:
		var cid: String = car["id"]
		if only != "" and not cid.begins_with(only):
			continue
		var scale: float = float(car.get("model_scale", 4.4))
		var map: Dictionary = CarPartMap.MAPS.get(car["scene_path"], {})
		var wheel_parts := {}
		for r in WHEEL_ROLES:
			for p in map.get(r, []):
				wheel_parts[int(p)] = true
		for g in map.get("wheel_groups", {}).values():
			for p in g:
				wheel_parts[int(p)] = true
		var ps: PackedScene = load(car["optimized_path"])
		var root: Node = ps.instantiate()
		var mis: Array = []
		_walk(root, mis)
		var car_base := 0
		var car_new := {}
		for t in THRESH_MM:
			car_new[t] = 0
		for mi in mis:
			var nm: String = (mi as Node).name
			var part := -1
			if nm.begins_with("tripo_part_"):
				part = int(nm.trim_prefix("tripo_part_"))
			var is_wheel: bool = wheel_parts.has(part)
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var d: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
				var vc: int = d["vertex_count"]
				var per_v: int = ((d["vertex_data"] as PackedByteArray).size() + (d["attribute_data"] as PackedByteArray).size()) / max(vc, 1)
				var wide: bool = vc > 65535
				var ib: int = (d["index_data"] as PackedByteArray).size()
				var lods: Array = d.get("lods", [])
				var lod_sz := 0
				for l in lods:
					lod_sz += (l["index_data"] as PackedByteArray).size()
				var base_sz: int = vc * per_v + ib + lod_sz
				car_base += base_sz
				var alt_sz: int = base_sz
				var err_mm := 1e12
				if lods.size() > 0 and not is_wheel:
					var l1: Dictionary = lods[0]
					err_mm = float(l1["edge_length"]) * scale * 1000.0
					var l1b: PackedByteArray = l1["index_data"]
					var uv: int = _unique(l1b, wide)
					alt_sz = uv * per_v + l1b.size() + (lod_sz - l1b.size())
					var bucket: int = int(clamp(floor(err_mm), 0, 10))
					err_hist[bucket] = err_hist.get(bucket, 0) + ib / (4 if wide else 2) / 3
				for t in THRESH_MM:
					car_new[t] += alt_sz if err_mm <= t else base_sz
		base_total += car_base
		var line := "%-26s base=%5.2f MB" % [cid, car_base / 1e6]
		for t in THRESH_MM:
			new_total[t] += car_new[t]
			line += "  ≤%s:%5.2f" % [str(t) if t < 1e8 else "hepsi", car_new[t] / 1e6]
		print(line)
		root.free()
	print("TOPLAM ham base=%.1f MB" % (base_total / 1e6))
	for t in THRESH_MM:
		print("  LOD1 hata ≤ %s mm → %.1f MB (%.0f%%)" % [str(t) if t < 1e8 else "sınırsız", new_total[t] / 1e6, 100.0 * new_total[t] / base_total])
	var ks := err_hist.keys()
	ks.sort()
	for k in ks:
		print("  LOD1 hatası %d–%d mm: %d taban üçgeni" % [k, k + 1, err_hist[k]])
	quit()
