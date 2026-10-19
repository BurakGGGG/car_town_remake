extends SceneTree

func _walk(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append((n as MeshInstance3D).mesh)
	for c in n.get_children():
		_walk(c, out)

func _init() -> void:
	var dir := "res://assets/cars/optimized/"
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()
	var only: String = OS.get_environment("ONLY")
	var tot := {"v": 0, "a": 0, "i": 0, "l": 0, "verts": 0, "tris": 0, "lodtris": 0, "surf": 0, "comp": 0, "idx32": 0, "lodn": 0}
	var fmt_seen := {}
	for f in files:
		if only != "" and not f.begins_with(only):
			continue
		var ps: PackedScene = load(dir + f)
		var root: Node = ps.instantiate()
		var meshes: Array = []
		_walk(root, meshes)
		var c := {"v": 0, "a": 0, "i": 0, "l": 0, "verts": 0, "tris": 0, "lodtris": 0, "surf": 0, "lodn": 0}
		for m in meshes:
			var mesh: Mesh = m
			for s in mesh.get_surface_count():
				var d: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
				var fmt: int = d["format"]
				fmt_seen[fmt] = fmt_seen.get(fmt, 0) + 1
				c["v"] += (d["vertex_data"] as PackedByteArray).size()
				c["a"] += (d.get("attribute_data", PackedByteArray()) as PackedByteArray).size()
				c["i"] += (d.get("index_data", PackedByteArray()) as PackedByteArray).size()
				c["verts"] += int(d["vertex_count"])
				c["tris"] += int(d.get("index_count", 0)) / 3
				c["surf"] += 1
				if fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES:
					tot["comp"] += 1
				if int(d["vertex_count"]) > 65535:
					tot["idx32"] += 1
				for lod in d.get("lods", []):
					var lb: PackedByteArray = lod["index_data"]
					c["l"] += lb.size()
					c["lodn"] += 1
		for k in c:
			tot[k] += c[k]
		print("%-28s surf=%3d verts=%7d tris=%7d  V=%5.2f A=%5.2f I=%5.2f LOD=%5.2f (n=%d) MB" % [f, c["surf"], c["verts"], c["tris"], c["v"] / 1e6, c["a"] / 1e6, c["i"] / 1e6, c["l"] / 1e6, c["lodn"]])
		root.free()
	print("TOTAL surf=%d compressed=%d idx32=%d verts=%d tris=%d  V=%.1f A=%.1f I=%.1f LOD=%.1f MB" % [tot["surf"], tot["comp"], tot["idx32"], tot["verts"], tot["tris"], tot["v"] / 1e6, tot["a"] / 1e6, tot["i"] / 1e6, tot["l"] / 1e6])
	for fm in fmt_seen:
		print("format 0x%x x%d" % [fm, fmt_seen[fm]])
	quit()
