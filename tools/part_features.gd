extends SceneTree
## Kaynak araç GLB'sinin her parçası için rol sınıflandırma özelliklerini CSV olarak yazar
## (tools/classify_roles.py okur). Ayrıntı: docs/VEHICLE_ASSETS.md §2.
## Kullanım: godot-4 --headless --path . -s res://tools/part_features.gd -- <glb> [<tscn_map_yolu>]
## Satır: car,idx,tris,cx,cy,cz,sx,sy,sz,cyl,r,g,b,sat,val,rol
##   c* = parçanın normalize medyan konumu (0..1, araç kutusuna göre), s* = p05-p95 boyutu,
##   rol = CarPartMap'teki bilinen rol (harita verilirse; yoksa "?") — doğrulama için.

const SAMPLES: int = 400   # parça başına doku örneği


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("glb yolu gerekli")
		quit(1)
		return
	var path: String = args[0]
	var map_path: String = args[1] if args.size() > 1 else ""
	var known: Dictionary = {}
	if map_path != "":
		var map: Dictionary = CarPartMap.get_map(map_path)
		for role: StringName in CarPartMap.ROLES:
			for idx: int in map.get(role, []):
				known[idx] = String(role)
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		printerr("okunamadi: " + path)
		quit(1)
		return
	var root: Node = doc.generate_scene(state)
	var image: Image = null
	if not state.materials.is_empty():
		var mat: BaseMaterial3D = state.materials[0] as BaseMaterial3D
		if mat and mat.albedo_texture:
			image = mat.albedo_texture.get_image()
			if image.is_compressed():
				image.decompress()
			if image.get_width() > 1024:
				image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var parts: Array[MeshInstance3D] = []
	var xforms: Array[Transform3D] = []
	_collect(root, Transform3D.IDENTITY, parts, xforms)
	# Aracın tamamının kutusu: normalleştirme için
	var whole: AABB = AABB()
	var first: bool = true
	for i: int in parts.size():
		var box: AABB = xforms[i] * parts[i].mesh.get_aabb()
		whole = box if first else whole.merge(box)
		first = false
	var car: String = path.get_file().get_basename()
	var scale: float = maxf(maxf(whole.size.x, whole.size.y), whole.size.z)
	print("#car=%s parts=%d aabb=%s size=%s" % [car, parts.size(), whole.position, whole.size])
	for order: int in parts.size():
		var part: MeshInstance3D = parts[order]
		# İNDEKS DÜĞÜM ADINDAN gelir ("tripo_part_N"): GLTF gezinme sırası numara sırası DEĞİL
		# (3. mesh "tripo_part_10" olabiliyor). CarPartMap da adı kullanıyor.
		var index: int = order
		var pname: String = String(part.name)
		if pname.begins_with("tripo_part_"):
			index = int(pname.get_slice("_", 2))
		var mesh: Mesh = part.mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tris: int = idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		# Kutu yerine YÜZDELİK: Tripo taramalarında birkaç çöp üçgen AABB'yi aracın yarısı kadar
		# şişiriyor (teker parçası 0,67 uzunluk görünüyordu). p05-p95 gerçek gövdeyi verir.
		var px_list: PackedFloat32Array = PackedFloat32Array()
		var py_list: PackedFloat32Array = PackedFloat32Array()
		var pz_list: PackedFloat32Array = PackedFloat32Array()
		var vstep: int = maxi(1, verts.size() / 2000)
		for vi: int in range(0, verts.size(), vstep):
			var wv: Vector3 = xforms[order] * verts[vi]
			px_list.append(wv.x)
			py_list.append(wv.y)
			pz_list.append(wv.z)
		px_list.sort()
		py_list.sort()
		pz_list.sort()
		var lo: Vector3 = Vector3(_pct(px_list, 0.05), _pct(py_list, 0.05), _pct(pz_list, 0.05))
		var hi: Vector3 = Vector3(_pct(px_list, 0.95), _pct(py_list, 0.95), _pct(pz_list, 0.95))
		var mid: Vector3 = Vector3(_pct(px_list, 0.5), _pct(py_list, 0.5), _pct(pz_list, 0.5))
		var center: Vector3 = (mid - whole.position) / scale
		var size: Vector3 = (hi - lo) / scale
		# Silindir skoru: iki eksen birbirine yakın ve büyük, üçüncüsü ince (teker)
		var dims: Array[float] = [size.x, size.y, size.z]
		dims.sort()
		var cyl: float = 0.0
		if dims[2] > 0.0001:
			cyl = (dims[1] / dims[2]) * (1.0 - dims[0] / dims[2])
		# Doku rengi: parçanın UV'lerinden örnek al
		var r: float = 0.0
		var g: float = 0.0
		var b: float = 0.0
		var count: int = 0
		if image and uvs.size() > 0:
			var step: int = maxi(1, uvs.size() / SAMPLES)
			for i: int in range(0, uvs.size(), step):
				var uv: Vector2 = uvs[i]
				var px: int = clampi(int(uv.x * float(image.get_width())), 0, image.get_width() - 1)
				var py: int = clampi(int(uv.y * float(image.get_height())), 0, image.get_height() - 1)
				var c: Color = image.get_pixel(px, py)
				r += c.r
				g += c.g
				b += c.b
				count += 1
		if count > 0:
			r /= float(count)
			g /= float(count)
			b /= float(count)
		var col: Color = Color(r, g, b)
		print("%s,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s" % [
			car, index, tris, center.x, center.y, center.z, size.x, size.y, size.z, cyl,
			col.r, col.g, col.b, col.s, col.v, known.get(index, "?")])
	quit()


static func _pct(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(int(float(values.size() - 1) * q), 0, values.size() - 1)]


## Sahne ağacına EKLENMEDİĞİ için global_transform çalışmaz: dönüşüm elle biriktirilir.
func _collect(node: Node, parent: Transform3D, out: Array[MeshInstance3D],
		xforms: Array[Transform3D]) -> void:
	var here: Transform3D = parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append(node)
		xforms.append(here)
	for child: Node in node.get_children():
		_collect(child, here, out, xforms)
