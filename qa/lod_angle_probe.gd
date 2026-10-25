extends SceneTree
## LOD ÜRETİM SONDASI — araç GLB'si içe aktarıcının kullandığı ImporterMesh.generate_lods ile farklı normal birleştirme
## açılarında sadeleştirilir; her açıda kademe başına toplam üçgen yazılır (en kaba kademe = uzak / küçük araç).
## Godot içe aktarıcısı köşeleri yalnız konum + UV + normal (açı içinde) aynıysa birleştirir, kalan dikişler "kenar"
## sayılıp kilitlenir (SIMPLIFY_LOCK_BORDER): normal açısı dar olunca en kaba kademe yüksek kalıyor mu?
##   godot-4 --headless --path . --script qa/lod_angle_probe.gd -- <araç_id> ...

const ANGLES: Array[float] = [25.0, 60.0, 90.0, 180.0]


func _initialize() -> void:
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["bmw_e46", "lambo_huracan"])
	for id: String in ids:
		var path: String = "res://assets/cars/optimized/%s.glb" % id
		for angle: float in ANGLES:
			var doc: GLTFDocument = GLTFDocument.new()
			var state: GLTFState = GLTFState.new()
			if doc.append_from_file(path, state) != OK:
				print("yüklenemedi: ", path)
				break
			var base: int = 0
			var levels: PackedInt32Array = []   # kademe → toplam üçgen (kademe yoksa en kabası sayılır)
			var started: int = Time.get_ticks_msec()
			for gltf_mesh: GLTFMesh in state.get_meshes():
				var mesh: ImporterMesh = gltf_mesh.mesh
				mesh.generate_lods(angle, 0.0, [])
				for s: int in mesh.get_surface_count():
					var tris: int = mesh.get_surface_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
					base += tris
					var count: int = mesh.get_surface_lod_count(s)
					for level: int in 8:
						if levels.size() <= level:
							levels.append(0)
						var lod_tris: int = tris if count == 0 else mesh.get_surface_lod_indices(s, mini(level, count - 1)).size() / 3
						levels[level] += lod_tris
			print("%s açı %3.0f: taban %d | kademeler %s (%d ms)" % [id, angle, base, levels, Time.get_ticks_msec() - started])
	quit(0)
