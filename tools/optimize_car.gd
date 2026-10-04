extends SceneTree
## Araç GLB optimizasyon pipeline'ı (headless Godot, harici bağımlılık yok).
## Her parçayı (MeshInstance3D) ayrı ayrı sadeleştirir; node adları ve parça yapısı korunur,
## böylece CarPartMap indeksleri aynen çalışır. Orijinal dosyaya dokunmaz.
##
## Kullanım:
##   godot --headless --path . -s res://tools/optimize_car.gd -- --in res://assets/cars/source/bmw_e46.glb \
##         --out res://assets/cars/optimized/bmw_e46.glb --ratio 0.08 --min-tris 400
##
## --ratio     hedef üçgen oranı (0.08 = %8). Parça başına, meshoptimizer LOD zincirinden
##             hedefe en yakın (>=) seviye seçilir.
## --min-tris  küçük parçalar (plaka, ayna, far) bu sayının altına inmez.
## --keep      virgülle ayrılmış parça adları: bu parçalar için oran 2x (ör. farlar, jantlar).
## --tex-size  doku (albedo) kenar uzunluğu; kaynak daha büyükse küçültülür (varsayılan 2048, 0 = dokunma).
## --quality   GLB içine gömülen JPEG kalitesi (0–1, varsayılan 0.85). Dokusuz kaynakta etkisiz.
## --rename    mesh node adları "tripo_part_N" değilse sırayla yeniden adlandır (tek parçalı GLB'ler için).
## --map       CarPartMap'teki sahne yolu (ör. res://assets/cars/bmw_e_46.tscn): DETAIL_ROLES
##             rollerindeki parçalar otomatik --keep listesine eklenir (elle numara yazmaya gerek yok).
##             Haritada split_z varsa o parça CarRig kuralıyla önceden iki yüzeye bölünür.
##             Haritada extract varsa (kaynakta başka bir parçaya kaynamış teker gibi), belirtilen
##             silindir bölgesindeki üçgenler yeni bir tripo_part_N parçasına ayrılır; CarRig için
##             sıradan bir parça olur (kendi pivotu, dönüşü, shader'ı).
##
## Dokulu (UV + basecolor) kaynaklar: UV/normal/tanjant dizileri korunur, tek albedo dokusu
## --tex-size'a küçültülüp JPEG olarak gömülür, tüm parçalar TEK StandardMaterial3D paylaşır
## (kaynağın metallic/roughness değerleriyle). Ek PBR dokuları (normal, metallic-roughness) mobil için
## atılır. BMW E46 için kullanılan ve onaylanan ayar (43.2 MB → 3.9 MB, 1.87M → 133K üçgen):
##   --ratio 0.06 --min-tris 600 --map res://assets/cars/bmw_e_46.tscn

const DEFAULT_RATIO: float = 0.08
const DEFAULT_MIN_TRIS: int = 400
const DEFAULT_TEX_SIZE: int = 2048
const DEFAULT_QUALITY: float = 0.85
const NORMAL_MERGE_ANGLE: float = 25.0
## --map ile korunan (2x oran) detay rolleri: küçük ama göze çarpan parçalar.
const DETAIL_ROLES: Array[StringName] = [
	&"headlights", &"taillights", &"mirrors", &"grille", &"plate", &"rims",
	&"fog_lights", &"exhaust", &"antenna",
]

func _init() -> void:
	var args: Dictionary = _parse_args()
	var in_path: String = args.get("in", "")
	var out_path: String = args.get("out", "")
	if in_path == "" or out_path == "":
		push_error("--in ve --out gerekli")
		quit(1)
		return
	var ratio: float = float(args.get("ratio", DEFAULT_RATIO))
	var min_tris: int = int(args.get("min-tris", DEFAULT_MIN_TRIS))
	var keep: PackedStringArray = String(args.get("keep", "")).split(",", false)
	var map_path: String = args.get("map", "")
	var tex_size: int = int(args.get("tex-size", DEFAULT_TEX_SIZE))
	var quality: float = float(args.get("quality", DEFAULT_QUALITY))
	var rename: bool = args.has("rename")
	var splits: Dictionary = {}  # parça adı → split_z tanımı (CarPartMap)
	var extracts: Array[Dictionary] = []  # CarPartMap "extract" tanımları
	var fills: Array[Dictionary] = []     # CarPartMap "fill_arc" tanımları (eksik lastik yayı)
	if map_path != "":
		var map: Dictionary = CarPartMap.get_map(map_path)
		if map.is_empty():
			push_error("CarPartMap'te kayit yok: %s" % map_path)
			quit(1)
			return
		for role: StringName in DETAIL_ROLES:
			for index: int in map.get(role, []):
				var part: String = CarPartMap.part_name(index)
				if not keep.has(part):
					keep.append(part)
		for spec: Dictionary in map.get("split_z", []):
			splits[CarPartMap.part_name(spec["part"])] = spec
		extracts.assign(map.get("extract", []))
		fills.assign(map.get("fill_arc", []))

	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = doc.append_from_file(in_path, state)
	if err != OK:
		push_error("GLB okunamadi: %s (%d)" % [in_path, err])
		quit(1)
		return
	var source: Node = doc.generate_scene(state)
	if rename:
		_rename_parts(source)
	var albedo_img: Image = null   # renk koşullu extract için (kaliper)
	for spec: Dictionary in extracts:
		if spec.has("hue") and albedo_img == null:
			albedo_img = _source_albedo(state)
		_extract_part(source, spec, albedo_img)
	for spec: Dictionary in fills:
		_fill_arc(source, spec)
	# Dokulu kaynak: tek albedo dokusu küçültülür, çıkışın tüm yüzeyleri tek materyali paylaşır
	var out_material: StandardMaterial3D = _output_material(state, tex_size)

	var out_root: Node3D = Node3D.new()
	out_root.name = "ROOT"
	var total_before: Dictionary = {"verts": 0, "tris": 0, "meshes": 0}
	var total_after: Dictionary = {"verts": 0, "tris": 0, "meshes": 0}
	var materials: Dictionary = {}
	var shared_material: Material = null
	var plain_materials: Dictionary = {}   # dokusuz kaynak materyaller (bkz. _surface_material)
	var rows: PackedStringArray = PackedStringArray()

	for node: Node in _find_mesh_nodes(source):
		var importer: ImporterMesh = _to_importer_mesh(node)
		if importer == null or importer.get_surface_count() == 0:
			continue
		var name: String = node.name
		var material: Material = importer.get_surface_material(0)
		if material:
			materials[material.get_instance_id()] = material
			if shared_material == null:
				shared_material = out_material if out_material else material

		# Kaynak yüzeyler. CarPartMap'te split_z olan parça (ör. Fluence ön cam + tavan) burada,
		# sadeleştirmeden ÖNCE ve CarRig'in kendi kuralıyla iki yüzeye bölünür (0: ön, 1: arka);
		# böylece sınır yoğun mesh'te doğru çizilir, Godot import her yüzey için LOD üretir ve
		# CarRig çalışma zamanında bölme yapmak zorunda kalmaz.
		var surfaces: Array = []
		var surface_materials: Array[Material] = []
		for si: int in importer.get_surface_count():
			surfaces.append(importer.get_surface_arrays(si))
			surface_materials.append(importer.get_surface_material(si))
		var split_spec: Dictionary = splits.get(name, {})
		if not split_spec.is_empty() and surfaces.size() == 1:
			var whole: ArrayMesh = ArrayMesh.new()
			whole.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaces[0])
			var halves: ArrayMesh = CarRig._split_mesh_z(whole, map_path, split_spec["part"], split_spec["z"])
			surfaces = [halves.surface_get_arrays(0), halves.surface_get_arrays(1)]
			surface_materials = [surface_materials[0], surface_materials[0]]

		var part_ratio: float = ratio * (2.0 if keep.has(name) else 1.0)
		var mesh: ArrayMesh = ArrayMesh.new()
		for si: int in surfaces.size():
			var r: Dictionary = _simplify_surface(surfaces[si], part_ratio, min_tris)
			# Tanjant BURADA atılamaz: kaynakta yok, glTF yükleyicisi UV gördüğü için üretiyor ve
			# diziden silinse bile add_surface_from_arrays geri ekliyor (ölçüldü). Çıktı GLB'sinden
			# tools/strip_tangents.py atar — tools/rebuild_cars.sh bu betikten hemen sonra çağırır.
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, r["arrays"])
			var surf_mat: Material = _surface_material(surface_materials[si], out_material, plain_materials)
			if surf_mat == null:
				surf_mat = shared_material
			if surf_mat:
				mesh.surface_set_material(si, surf_mat)
			total_before["verts"] += r["verts_before"]
			total_before["tris"] += r["tris_before"]
			total_after["verts"] += r["verts_after"]
			total_after["tris"] += r["tris_after"]
			var label: String = name if surfaces.size() == 1 else "%s/y%d" % [name, si]
			rows.append("%-16s tris %7d -> %6d (%.1f%%)  verts %7d -> %6d  lod_seviyesi=%d" % [label, r["tris_before"], r["tris_after"], 100.0 * r["tris_after"] / maxf(r["tris_before"], 1), r["verts_before"], r["verts_after"], r["lod_count"]])
		total_before["meshes"] += 1
		total_after["meshes"] += 1

		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = name
		mi.mesh = mesh
		mi.transform = _global_of(node)  # kök (ParentNode) dönüşümü pişirilir: zemin y=0, ön +Z, uzunluk 1
		out_root.add_child(mi)
		mi.owner = out_root

	var out_state: GLTFState = GLTFState.new()
	var out_doc: GLTFDocument = GLTFDocument.new()
	out_doc.image_format = "JPEG"
	out_doc.lossy_quality = quality
	err = out_doc.append_from_scene(out_root, out_state)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
		err = out_doc.write_to_filesystem(out_state, out_path)
	if err != OK:
		push_error("GLB yazilamadi: %s (%d)" % [out_path, err])
		quit(1)
		return

	for r: String in rows:
		print(r)
	print("--- OZET ---")
	print("giris : %s  %.1f MB  mesh=%d  vertex=%d  tris=%d  materyal=%d" % [in_path, _size_mb(in_path), total_before["meshes"], total_before["verts"], total_before["tris"], materials.size()])
	var tex_info: String = "yok"
	if out_material and out_material.albedo_texture:
		var sz: Vector2i = out_material.albedo_texture.get_size()
		tex_info = "%dx%d JPEG q=%.2f" % [sz.x, sz.y, quality]
	print("cikis : %s  %.1f MB  mesh=%d  vertex=%d  tris=%d  materyal=%d  doku=%s" % [out_path, _size_mb(out_path), total_after["meshes"], total_after["verts"], total_after["tris"], 1 if shared_material else 0, tex_info])
	source.free()
	out_root.free()
	quit(0)


## Ağaç dışındaki node için üst zincir çarpımıyla dünya dönüşümü (global_transform ağaç ister).
static func _global_of(node: Node) -> Transform3D:
	var xf: Transform3D = (node as Node3D).transform
	var p: Node = node.get_parent()
	while p != null and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Yüzeyin çıkış materyali. Kural: DOKULU her materyal gövdenin küçültülmüş tek materyalini
## kullanır (bütün araçlar tek atlasla gelir, tek materyal = tek draw state). DOKUSUZ bir
## materyal ise kaynakta bilerek ayrı verilmiştir — düz renk olarak KORUNUR.
##
## Neden: Toros'un tekerleri Blender'da yeniden üretildi (kaynak mesh'teki bozuk lastik silinip
## yerine temiz geometri konuldu). Bu tekerlerin atlasta karşılığı yok; gövde materyaline
## bağlanınca renkleri UV'den geliyordu ve doğru texel'e nişanlamanın hiçbir yolu tutmadı —
## tek texel'i mipmap yutuyor, kaynağın kendi teker UV'leri ise atlasın her yanına dağılmış
## (model 6.887 kopuk parçadan oluşuyor). Dokusuz materyali korumak bunu kökten çözer.
## Tek atlaslı 15 aracın hepsinde her materyal DOKULU olduğu için çıktıları bit bit aynı kalır.
static func _surface_material(src: Material, out_material: StandardMaterial3D, cache: Dictionary) -> Material:
	if out_material == null:
		return src
	var base: BaseMaterial3D = src as BaseMaterial3D
	if base == null or base.albedo_texture != null:
		return out_material
	var key: int = base.get_instance_id()
	if not cache.has(key):
		var flat: StandardMaterial3D = StandardMaterial3D.new()
		flat.resource_name = base.resource_name
		flat.albedo_color = base.albedo_color
		flat.metallic = base.metallic
		flat.roughness = base.roughness
		cache[key] = flat
	return cache[key]


## Kaynağın ilk materyalinden çıkış materyali: albedo dokusu tex_size'a küçültülür (Lanczos), metallic /
## roughness sabitleri korunur; normal / metallic-roughness dokuları atılır. Dokusuz kaynakta null.
func _output_material(state: GLTFState, tex_size: int) -> StandardMaterial3D:
	if state.materials.is_empty():
		return null
	var src: BaseMaterial3D = state.materials[0] as BaseMaterial3D
	if src == null or src.albedo_texture == null:
		return null
	var img: Image = src.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	if tex_size > 0 and w > tex_size:
		img.resize(tex_size, tex_size * img.get_height() / w, Image.INTERPOLATE_LANCZOS)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = "car_albedo"
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = src.albedo_color
	# Metallic/roughness dokusu atılınca kaynağın çarpanları (çoğu Tripo PBR export'unda 1.0/1.0) tek başına
	# "tam metal, siyah" görünüm verir: doku varsa güvenli boya sabitlerine dön, yoksa çarpanları koru.
	mat.metallic = 0.0 if src.metallic_texture else src.metallic
	mat.roughness = 0.5 if src.roughness_texture else src.roughness
	print("doku : %dx%d -> %dx%d (kaynak dokular: albedo%s%s%s)" % [w, w, img.get_width(), img.get_height(), " +normal" if src.normal_texture else "", " +metal/rough" if src.metallic_texture or src.roughness_texture else "", " +emission" if src.emission_texture else ""])
	return mat


## Tek parçalı / adsız GLB: mesh node'larını sırayla tripo_part_N yapar (CarPartMap indeksleri için).
func _rename_parts(source: Node) -> void:
	var i: int = 0
	for node: Node in _find_mesh_nodes(source):
		if not String(node.name).begins_with("tripo_part_"):
			node.name = String(CarPartMap.part_name(i))
			print("rename: -> %s" % node.name)
		i += 1


## CarPartMap "extract": {"part", "new_part", "center": [x,y,z], "radius", "half_width"} — X eksenli
## silindir (teker) bölgesinde, üç köşesi de içeride kalan üçgenler kaynak parçadan alınır ve
## tripo_part_<new_part> adlı yeni bir MeshInstance3D olarak kök altına eklenir.
## İsteğe bağlı RENK koşulu (janta kaynamış fren kaliperi): "hue" (0-1), "hue_tol", "min_sat" verilirse
## üçgen ayrıca en az iki köşesinin doku rengi bu tona / doygunluğa uyuyorsa alınır.
func _extract_part(source: Node, spec: Dictionary, albedo: Image = null) -> void:
	var src_node: MeshInstance3D = source.find_child(String(CarPartMap.part_name(spec["part"])), true, false) as MeshInstance3D
	if src_node == null or src_node.mesh == null:
		push_error("extract: kaynak parca %s bulunamadi" % spec["part"])
		return
	var arrays: Array = src_node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var c: Array = spec["center"]
	# Tanım araç (dünya) uzayında: zemin y=0, ön +Z. Parçanın yerel uzayına çevrilir (kök ölçeği dahil).
	var inv: Transform3D = _global_of(src_node).affine_inverse()
	var center: Vector3 = inv * Vector3(c[0], c[1], c[2])
	var unit: float = inv.basis.get_scale().x
	var radius: float = float(spec["radius"]) * unit
	var half_width: float = float(spec["half_width"]) * unit
	var inside: PackedInt32Array = PackedInt32Array()
	var outside: PackedInt32Array = PackedInt32Array()
	var by_color: bool = spec.has("hue") and albedo != null
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if by_color else PackedVector2Array()
	for t: int in indices.size() / 3:
		var all_in: bool = true
		for k: int in 3:
			var d: Vector3 = verts[indices[t * 3 + k]] - center
			if absf(d.x) > half_width or Vector2(d.y, d.z).length() > radius:
				all_in = false
				break
		if all_in and by_color:
			var hits: int = 0
			for k: int in 3:
				if _color_match(albedo, uvs[indices[t * 3 + k]], spec):
					hits += 1
			all_in = hits >= 2
		var target: PackedInt32Array = inside if all_in else outside
		for k: int in 3:
			target.append(indices[t * 3 + k])
	var material: Material = src_node.mesh.surface_get_material(0)
	var remain: ArrayMesh = ArrayMesh.new()
	remain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, outside))
	remain.surface_set_material(0, material)
	src_node.mesh = remain
	var taken: ArrayMesh = ArrayMesh.new()
	taken.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, inside))
	taken.surface_set_material(0, material)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = String(CarPartMap.part_name(spec["new_part"]))
	mi.mesh = taken
	mi.transform = src_node.transform
	src_node.get_parent().add_child(mi)
	print("extract: %s -> %s  ucgen %d / kalan %d" % [src_node.name, mi.name, inside.size() / 3, outside.size() / 3])


## CarPartMap "fill_arc": {"part", "center": [x,y,z], "from", "to"} — lastiğin MODELLENMEMİŞ yayını doldurur.
## Tripo bazen çamurluğun içinde kalan lastik üstünü hiç üretmiyor (GT3 sağ-ön: üstte ~80°); teker dönünce
## o boşluk alta gelip görünüyordu. Lastik dönel simetrik olduğundan karşı yaydaki (açı + 180°) üçgenler
## aks etrafında 180° döndürülüp eklenir. Açı dünya uzayında, X ekseni etrafında: 0° = yukarı (+Y),
## 90° = ön (+Z); from > to ise yay 0°'dan geçer.
func _fill_arc(source: Node, spec: Dictionary) -> void:
	var node: MeshInstance3D = source.find_child(String(CarPartMap.part_name(spec["part"])), true, false) as MeshInstance3D
	if node == null or node.mesh == null:
		push_error("fill_arc: parca %s bulunamadi" % spec["part"])
		return
	var g: Transform3D = _global_of(node)
	var inv: Transform3D = g.affine_inverse()
	var c: Array = spec["center"]
	var center: Vector3 = Vector3(c[0], c[1], c[2])
	var from: float = fposmod(float(spec["from"]) + 180.0, 360.0)
	var to: float = fposmod(float(spec["to"]) + 180.0, 360.0)
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var spin: Basis = Basis(Vector3.RIGHT, PI)
	var new_verts: PackedVector3Array = verts.duplicate()
	var new_normals: PackedVector3Array = normals.duplicate()
	var new_uvs: PackedVector2Array = (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
	var out_idx: PackedInt32Array = indices.duplicate()
	var copied: Dictionary = {}   # eski vertex → yeni vertex
	var added: int = 0
	for t: int in indices.size() / 3:
		var w: Vector3 = Vector3.ZERO
		for k: int in 3:
			w += g * verts[indices[t * 3 + k]]
		w /= 3.0
		var deg: float = fposmod(rad_to_deg(atan2(w.z - center.z, w.y - center.y)), 360.0)
		var inside: bool = (deg >= from and deg <= to) if from <= to else (deg >= from or deg <= to)
		if not inside:
			continue
		for k: int in 3:
			var old: int = indices[t * 3 + k]
			if not copied.has(old):
				var world: Vector3 = center + spin * (g * verts[old] - center)
				new_verts.append(inv * world)
				new_normals.append((inv.basis * (spin * (g.basis * normals[old]))).normalized())
				new_uvs.append((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[old])
				copied[old] = new_verts.size() - 1
			out_idx.append(copied[old])
		added += 1
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = new_verts
	out[Mesh.ARRAY_NORMAL] = new_normals
	out[Mesh.ARRAY_TEX_UV] = new_uvs
	out[Mesh.ARRAY_INDEX] = out_idx
	var material: Material = node.mesh.surface_get_material(0)
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	mesh.surface_set_material(0, material)
	node.mesh = mesh
	print("fill_arc: %s  %d ucgen eklendi (%.0f-%.0f derece yayindan)" % [node.name, added, from, to])


static func _color_match(img: Image, uv: Vector2, spec: Dictionary) -> bool:
	var c: Color = img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1),
		clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
	if c.s < float(spec.get("min_sat", 0.4)) or c.v < 0.2:
		return false
	var dh: float = absf(c.h - float(spec["hue"]))
	return minf(dh, 1.0 - dh) <= float(spec.get("hue_tol", 0.06))


## Kaynağın albedo görüntüsü (sıkıştırılmamış), renk koşullu extract için.
static func _source_albedo(state: GLTFState) -> Image:
	if state.materials.is_empty():
		return null
	var mat: BaseMaterial3D = state.materials[0] as BaseMaterial3D
	if mat == null or mat.albedo_texture == null:
		return null
	var img: Image = mat.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	return img


## Tek yüzeyi hedef orana sadeleştirir: meshoptimizer LOD zincirinden hedefe en yakın (>=) seviye
## seçilir, kullanılmayan vertex'ler atılır.
func _simplify_surface(src_arrays: Array, part_ratio: float, min_tris: int) -> Dictionary:
	var src_index: PackedInt32Array = src_arrays[Mesh.ARRAY_INDEX]
	var tris_before: int = src_index.size() / 3
	var verts_before: int = (src_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var importer: ImporterMesh = ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, src_arrays)
	importer.generate_lods(NORMAL_MERGE_ANGLE, 60.0, [])
	var target: int = maxi(int(tris_before * part_ratio), min_tris)
	var chosen: PackedInt32Array = src_index
	var chosen_tris: int = tris_before
	var lod_count: int = importer.get_surface_lod_count(0)
	for i: int in lod_count:
		var lod: PackedInt32Array = importer.get_surface_lod_indices(0, i)
		var t: int = lod.size() / 3
		if t >= target and t < chosen_tris:
			chosen = lod
			chosen_tris = t
	# generate_lods yeni vertex eklemiş olabilir; güncel dizileri kullan
	var compact: Array = _compact(importer.get_surface_arrays(0), chosen)
	return {
		"arrays": compact,
		"tris_before": tris_before, "tris_after": chosen_tris,
		"verts_before": verts_before, "verts_after": (compact[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		"lod_count": lod_count,
	}


func _to_importer_mesh(node: Node) -> ImporterMesh:
	if node is ImporterMeshInstance3D:
		return (node as ImporterMeshInstance3D).mesh
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return ImporterMesh.from_mesh((node as MeshInstance3D).mesh)
	return null


func _find_mesh_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is MeshInstance3D or n is ImporterMeshInstance3D:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


## Yalnızca kullanılan vertex'leri tutar; index dizisini yeniden numaralandırır. Vertex başına tüm
## öznitelikler (normal, UV, UV2, renk) aynen taşınır — UV/doku bağlantısı bozulmaz.
func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var order: PackedInt32Array = PackedInt32Array()  # yeni id → eski id
	var new_index: PackedInt32Array = PackedInt32Array()
	new_index.resize(indices.size())
	var next_id: int = 0
	for i: int in indices.size():
		var old: int = indices[i]
		var mapped: int = remap[old]
		if mapped == -1:
			mapped = next_id
			remap[old] = mapped
			order.append(old)
			next_id += 1
		new_index[i] = mapped
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	for k: int in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_INDEX or k == Mesh.ARRAY_TANGENT or arrays[k] == null:
			continue  # tanjant yazılmaz: Godot import (ensure_tangents) yeniden üretir, GLB %25 küçülür
		var src: Variant = arrays[k]
		var stride: int = 1
		if k == Mesh.ARRAY_TANGENT or k == Mesh.ARRAY_BONES or k == Mesh.ARRAY_WEIGHTS:
			stride = (src as Array).size() / verts.size() if src is Array else src.size() / verts.size()
		if src is Array:
			continue  # özel dizi biçimleri kullanılmıyor
		var dst: Variant = src.duplicate()
		dst.resize(order.size() * stride)
		for n: int in order.size():
			var old: int = order[n]
			for j: int in stride:
				dst[n * stride + j] = src[old * stride + j]
		out[k] = dst
	out[Mesh.ARRAY_INDEX] = new_index
	return out


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				out[a.trim_prefix("--")] = args[i + 1]
				i += 2
			else:
				out[a.trim_prefix("--")] = "true"  # değersiz bayrak (ör. --rename)
				i += 1
		else:
			i += 1
	return out


func _size_mb(path: String) -> float:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return (f.get_length() / 1048576.0) if f else 0.0
