extends SceneTree
## ARAÇ UZAK LOD'U ÜRETİR → res://assets/cars/far_lod/<model>.res (CarFarLod; bkz. vehicles/car_far_lod.gd).
## Her aracın içe aktarılmış parça dizileri (oyundaki köşe sırasıyla) dökülür, tools/far_lod/simplify_far_lod.py
## meshoptimizer ile sadeleştirir, indeksler kaynağa yazılır. Dönen parçalar (teker / lastik / jant) varsayılan olarak
## yazılmaz: kenar kilitsiz kademe lastikte boşluk açıyordu (qa/teker_tarama.gd lod=0 merge); kenar kilitli ve sıkı sapmayla
## (FAR_LOD_WHEEL_ERROR=0.0015) araç başına yalnız −%5–7 üçgen, +0,55 MB ve iki sınırda boşluk (2026-10-25) — kapalı.
## Ne zaman: araç modeli değişince ya da kataloğa araç eklenince (tests/far_lod_test.gd eksik / eskimiş dosyayı FAIL verir).
## Kullanım: tools/far_lod/make_far_lod.sh [<araç_id> ...]   (boşsa bütün araçlar; FAR_LOD_ERROR=0.004)
## Betik iki kipte çalışır: "dump" (PENCERELİ — başsızda mesh verisi okunamaz) ve "pack" (başsız). Python'u kabuk
## betiği çalıştırır: snap'teki Godot'nun ev klasörü ayrı, ~/.cache'teki meshoptimizer kitaplığını göremiyor.

const WORK: String = "res://.godot/far_lod/"
const SPIN_ROLES: Array[String] = ["wheels", "tires", "rims"]


func _initialize() -> void:
	_run.call_deferred()


## Aracın dönen parçaları (teker / lastik / jant rolleri + teker grupları): "tripo_part_N" adları.
static func spin_parts(scene_path: String) -> Dictionary:
	var map: Dictionary = CarPartMap.MAPS.get(scene_path, {})
	var out: Dictionary = {}
	for role: String in SPIN_ROLES:
		for p: int in map.get(role, []):
			out[CarPartMap.part_name(p)] = true
	for group: Array in map.get("wheel_groups", {}).values():
		for p: int in group:
			out[CarPartMap.part_name(p)] = true
	return out


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var work: String = ProjectSettings.globalize_path(WORK)
	DirAccess.make_dir_recursive_absolute(work)
	if not args.is_empty() and args[0] == "pack":
		_pack_all(work)
		quit(0)
		return
	for file: String in DirAccess.get_files_at(work):
		DirAccess.remove_absolute(work.path_join(file))
	var error: float = 0.004
	var ids: PackedStringArray = PackedStringArray()
	for arg: String in args.slice(1):
		if arg.begins_with("--error="):
			error = float(arg.trim_prefix("--error="))
		else:
			ids.append(arg)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://vehicles/cars.json"))
	for car: Dictionary in data["cars"]:
		if not ids.is_empty() and not ids.has(car["id"]):
			continue
		var model: String = (car["optimized_path"] as String).get_file().get_basename()
		_dump(car["scene_path"], work.path_join(model + ".in"), error)
	quit(0)


func _pack_all(work: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CarFarLod.DIR))
	for file: String in DirAccess.get_files_at(work):
		if file.ends_with(".out"):
			_pack(work.path_join(file), CarFarLod.DIR + file.get_basename() + ".res")


## Parça dizilerini simplify_far_lod.py'nin girdisine döker. Kazanç tabanı: içe aktarıcının sapması `error`a sığan en
## kaba kademesi (oyunda uzak kademe o eşikte onun yerine geçer).
func _dump(scene_path: String, path: String, error: float) -> void:
	var car: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	root.add_child(car)
	var spin: Dictionary = spin_parts(scene_path)
	var out: Dictionary = {}
	var blob: PackedByteArray = PackedByteArray()
	var count: int = 0
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or CarFarLod.path_for(mi.mesh) == "":
			continue
		for surface: int in mi.mesh.get_surface_count():
			var key: String = "%s:%d" % [mi.mesh.resource_name, surface]
			if out.has(key):
				continue
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
				else PackedInt32Array()
			if vertices.is_empty() or indices.size() < 3:
				continue
			var vc: int = vertices.size()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null \
				else PackedVector3Array()
			normals.resize(vc)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null \
				else PackedVector2Array()
			uvs.resize(vc)
			var raw: Dictionary = RenderingServer.mesh_get_surface(mi.mesh.get_rid(), surface)
			var coarse: int = indices.size()
			for lod: Dictionary in raw.get("lods", []):
				if float(lod["edge_length"]) <= error:
					coarse = (lod["index_data"] as PackedByteArray).size() / (2 if vc <= 65536 else 4)
			var head: PackedByteArray = PackedByteArray()
			head.resize(18)
			var kb: PackedByteArray = key.to_utf8_buffer()
			head.encode_u16(0, kb.size())
			blob.append_array(head.slice(0, 2))
			blob.append_array(kb)
			head.encode_u32(2, vc)
			head.encode_u32(6, indices.size())
			head.encode_u32(10, coarse)
			head.encode_u32(14, 1 if spin.has(mi.name) else 0)   # bayraklar: 1 = dönen parça (teker / lastik / jant)
			blob.append_array(head.slice(2, 18))
			blob.append_array(vertices.to_byte_array())   # Vector3 = 3 × float32
			blob.append_array(normals.to_byte_array())
			blob.append_array(uvs.to_byte_array())
			blob.append_array(indices.to_byte_array())
			out[key] = true
			count += 1
	car.free()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("FLI2".to_ascii_buffer())
	file.store_32(count)
	file.store_buffer(blob)
	file.close()


## simplify_far_lod.py'nin çıktısını CarFarLod kaynağına çevirir (zstd sıkıştırmalı ikili kaynak).
func _pack(path: String, target: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.slice(0, 4).get_string_from_ascii() != "FLO1":
		push_error("make_far_lod: çıktı okunamadı: " + path)
		return
	var lod: CarFarLod = CarFarLod.new()
	lod.error = bytes.decode_float(8)
	var at: int = 12
	for i: int in bytes.decode_u32(4):
		var klen: int = bytes.decode_u16(at)
		var key: String = bytes.slice(at + 2, at + 2 + klen).get_string_from_utf8()
		at += 2 + klen
		var vc: int = bytes.decode_u32(at)
		var first: Vector3 = Vector3(bytes.decode_float(at + 4), bytes.decode_float(at + 8), bytes.decode_float(at + 12))
		var count: int = bytes.decode_u32(at + 16)
		at += 24   # köşe sayısı, ilk köşe, indeks sayısı, gerçek sapma
		var indices: PackedInt32Array = bytes.slice(at, at + count * 4).to_int32_array()
		at += count * 4
		lod.surfaces[key] = [vc, first, CarFarLod.encode(indices, vc)]
	var err: Error = ResourceSaver.save(lod, target, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("make_far_lod: %s yazılamadı (%d)" % [target, err])
	else:
		print("FARLOD %s: %d parça, %d bayt" % [target.get_file(), lod.surfaces.size(),
			FileAccess.get_file_as_bytes(target).size()])
