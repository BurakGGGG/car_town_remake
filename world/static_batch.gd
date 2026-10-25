class_name StaticBatch
extends Node3D
## STATİK TOPLU ÇİZİM (2026-10-25) — kıpırdamayan sahne parçaları (garaj dekoru, şehrin ağaç / çalı / bank / çiçeklikleri,
## showroom binası) birkaç çizim çağrısıyla çizilir.
##
## Ölçüldü (dekorlu kayıt, qa/render_breakdown.gd): 67 dekor eşyası 187 çizim çağrısı, yalnız 16 bin üçgen — zayıf
## telefonda (GL Compatibility) darboğaz çağrı sayısı. 248 yüzeyin 112 farklı materyali var (her eşyanın kendi rengi), bu
## yüzden "aynı materyali birleştir" tek başına yetmiyor. İki tür toplu mesh kurulur:
##   1) DÜZ RENK: dokusuz, ışıklı, opak, varsayılan ayarlı StandardMaterial3D'lerin yüzeyleri TEK mesh'te; renk köşe
##      rengine, pürüz / metaliklik UV2'ye, specular köşe alfasına yazılır (vfx/static_batch.gdshader). Görünüm aynı (aynı
##      ışık modeli; renk 8 bit köşe renginde).
##   2) KALANLAR (dokulu, ışık saçan...): materyal başına bir mesh. Saydam yüzeyler birleşmez (sıralama bozulur).
## build(): asıl parçalar silinmez, yalnız çizimden çıkar (layers = 0): dokunarak seçme (_ray_body), kutular ve düzenleyici
## aynen çalışır. GarageDecorView düzenleme moduna girerken toplu çizimi kaldırır (eşyalar taşınır, soluklaşır), çıkınca
## kurar. merge_surfaces(): tek bir mesh'in (showroom binası) düz renkli yüzeylerini birleştirir.

const SHADER: Shader = preload("res://vfx/static_batch.gdshader")
const SHADER_DOUBLE: Shader = preload("res://vfx/static_batch_double.gdshader")
const META_LAYERS: StringName = &"static_batch_layers"
## Varsayılandan farklı olabilecek (köşeye taşınan) StandardMaterial3D ayarları; geri kalan HER ayar varsayılan olmalı.
## Arka yüz ayıklaması (cull_mode) da serbest: çift yüzlüler ayrı yüzeyde, ayıklamasız shader'la çizilir.
const FLAT_PROPS: PackedStringArray = ["albedo_color", "roughness", "metallic", "metallic_specular", "resource_name",
	"resource_local_to_scene", "resource_path", "script", "render_priority", "cull_mode"]

## QA: kapalıyken toplu çizim kurulmaz (önce / sonra karşılaştırması).
static var enabled: bool = true
static var _flat_materials: Dictionary = {}   # cull_mode → ShaderMaterial
static var _lod_cache: Dictionary = {}         # mesh örnek kimliği → LOD kademesi var mı
static var _default: StandardMaterial3D
static var _flat_cache: Dictionary = {}   # materyal örnek kimliği → bool
static var _key_cache: Dictionary = {}    # materyal örnek kimliği → ayar anahtarı

var _sources: Array[GeometryInstance3D] = []


## `roots` altındaki görünür MeshInstance3D / MultiMeshInstance3D'leri toplar; hiçbiri yoksa null. Ağaçta olmayan bir
## düğüm döner: çağıran `root`'un altına ekler (dönüşümler root'un uzayında). Bütün yüzeyleri toplanamayan parça (saydam
## yüzeyli eşya) olduğu gibi çizilmeye devam eder.
## `keep_lod`: LOD kademesi olan modeller (şehrin ağaçları) toplanmaz — birleşik mesh hep en detaylı kademede çizilirdi.
static func build(roots: Array[Node3D], root: Node3D, batch_name: String = "StaticBatch", keep_lod: bool = false) -> StaticBatch:
	if DisplayServer.get_name() == "headless" or not enabled:
		return null   # sahte işleyici mesh dizilerini okuyamaz
	var to_root: Transform3D = root.global_transform.affine_inverse()
	# Anahtarlarda kaynağın gölge ayarı da var: gölge yazmayan parça (showroom salonu) toplu çizimde de yazmasın.
	var flats: Dictionary = {}           # "cull|gölge" → [SurfaceTool, aralıklar: [köşe sayısı, Color(renk, specular), Vector2(pürüz, metal)], cull, gölge]
	var grouped: Dictionary = {}         # "ayar anahtarı|gölge" → [SurfaceTool, Material, gölge]
	var sources: Array[GeometryInstance3D] = []
	for top: Node3D in roots:
		if top == null or not top.is_visible_in_tree():
			continue
		var parts: Array[Node] = top.find_children("*", "GeometryInstance3D", true, false)
		if top is GeometryInstance3D:
			parts.push_front(top)
		for node: Node in parts:
			var part: GeometryInstance3D = node as GeometryInstance3D
			if not part.is_visible_in_tree() or part.layers == 0:
				continue
			var mesh: Mesh = _mesh_of(part)
			if mesh == null or not _takeable(part, mesh) or (keep_lod and _has_lods(mesh)):
				continue   # saydam / üçgen olmayan yüzeyli (ya da LOD'lu) parça olduğu gibi çizilir
			var xforms: Array[Transform3D] = _instances(part, to_root)
			for s: int in mesh.get_surface_count():
				var material: Material = _material_of(part, mesh, s)
				var vertices: int = _vertex_count(mesh, s) if is_flat(material) else 0
				for xf: Transform3D in xforms:
					if is_flat(material):
						var std: StandardMaterial3D = material as StandardMaterial3D
						var flat_key: String = "%d|%d" % [std.cull_mode, part.cast_shadow]
						if not flats.has(flat_key):
							var tool: SurfaceTool = SurfaceTool.new()
							tool.begin(Mesh.PRIMITIVE_TRIANGLES)
							flats[flat_key] = [tool, [], std.cull_mode, part.cast_shadow]
						var entry: Array = flats[flat_key]
						(entry[0] as SurfaceTool).append_from(mesh, s, xf)
						var c: Color = std.albedo_color
						(entry[1] as Array).append([vertices, Color(c.r, c.g, c.b, std.metallic_specular),
							Vector2(std.roughness, std.metallic)])
					else:
						var key: String = "%s|%d" % [_key(material), part.cast_shadow]
						if not grouped.has(key):
							var tool: SurfaceTool = SurfaceTool.new()
							tool.begin(Mesh.PRIMITIVE_TRIANGLES)
							grouped[key] = [tool, material, part.cast_shadow]
						((grouped[key] as Array)[0] as SurfaceTool).append_from(mesh, s, xf)
			sources.append(part)
	if sources.is_empty():
		return null
	var batch: StaticBatch = StaticBatch.new()
	batch.name = batch_name
	for flat_key: String in flats:
		var entry: Array = flats[flat_key]
		var flat_mi: MeshInstance3D = _flat_mesh(entry[0], entry[1], int(entry[2]))
		flat_mi.cast_shadow = int(entry[3]) as GeometryInstance3D.ShadowCastingSetting
		batch.add_child(flat_mi)
	for key: String in grouped:
		var pair: Array = grouped[key]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = (pair[0] as SurfaceTool).commit()
		mi.material_override = pair[1]
		mi.cast_shadow = int(pair[2]) as GeometryInstance3D.ShadowCastingSetting
		batch.add_child(mi)
	batch._sources = sources
	for part: GeometryInstance3D in sources:
		part.set_meta(META_LAYERS, part.layers)
		part.layers = 0
	return batch


## Tek mesh'in düz renkli yüzeylerini (keep(materyal) false olanlar) TEK yüzeyde (çift yüzlüler ayrı bir yüzeyde)
## birleştirir; diğer yüzeyler materyalleriyle olduğu gibi kopyalanır. Birleşecek bir şey yoksa null.
static func merge_surfaces(mesh: Mesh, keep: Callable) -> ArrayMesh:
	if DisplayServer.get_name() == "headless" or not enabled or mesh == null:
		return null
	var flats: Dictionary = {}   # cull_mode → [SurfaceTool, aralıklar]
	var merged: int = 0
	var kept: Array[int] = []
	var array_mesh: ArrayMesh = mesh as ArrayMesh
	for s: int in mesh.get_surface_count():
		var material: Material = mesh.surface_get_material(s)
		var triangles: bool = array_mesh == null or array_mesh.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES
		if not triangles or not is_flat(material) or bool(keep.call(material)):
			kept.append(s)
			continue
		var std: StandardMaterial3D = material as StandardMaterial3D
		if not flats.has(std.cull_mode):
			var tool: SurfaceTool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			flats[std.cull_mode] = [tool, []]
		var entry: Array = flats[std.cull_mode]
		(entry[0] as SurfaceTool).append_from(mesh, s, Transform3D.IDENTITY)
		var c: Color = std.albedo_color
		(entry[1] as Array).append([_vertex_count(mesh, s), Color(c.r, c.g, c.b, std.metallic_specular),
			Vector2(std.roughness, std.metallic)])
		merged += 1
	if merged < 2:
		return null
	var out: ArrayMesh = ArrayMesh.new()
	for cull: int in flats:
		var holder: MeshInstance3D = _flat_mesh((flats[cull] as Array)[0], (flats[cull] as Array)[1], cull)
		var flat_mesh: ArrayMesh = holder.mesh as ArrayMesh
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat_mesh.surface_get_arrays(0))
		out.surface_set_material(out.get_surface_count() - 1, holder.material_override)
		holder.free()
	for s: int in kept:
		var primitive: Mesh.PrimitiveType = array_mesh.surface_get_primitive_type(s) if array_mesh else Mesh.PRIMITIVE_TRIANGLES
		out.add_surface_from_arrays(primitive, mesh.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
	return out


static func _mesh_of(part: GeometryInstance3D) -> Mesh:
	if part is MeshInstance3D:
		return (part as MeshInstance3D).mesh
	if part is MultiMeshInstance3D and (part as MultiMeshInstance3D).multimesh:
		return (part as MultiMeshInstance3D).multimesh.mesh
	return null


static func _material_of(part: GeometryInstance3D, mesh: Mesh, surface: int) -> Material:
	if part is MeshInstance3D:
		return (part as MeshInstance3D).get_active_material(surface)
	return part.material_override if part.material_override else mesh.surface_get_material(surface)


## Parçanın root'a göre dönüşümleri: MeshInstance3D'de bir, MultiMesh'te görünür her örnek için bir.
static func _instances(part: GeometryInstance3D, to_root: Transform3D) -> Array[Transform3D]:
	var base: Transform3D = to_root * part.global_transform
	if not part is MultiMeshInstance3D:
		return [base]
	var multi: MultiMesh = (part as MultiMeshInstance3D).multimesh
	var count: int = multi.instance_count if multi.visible_instance_count < 0 else mini(multi.visible_instance_count,
		multi.instance_count)
	var out: Array[Transform3D] = []
	for i: int in count:
		out.append(base * multi.get_instance_transform(i))
	return out


## Asıl parçaları geri açar ve toplu çizimi siler.
func dissolve() -> void:
	for part: GeometryInstance3D in _sources:
		if is_instance_valid(part) and part.has_meta(META_LAYERS):
			part.layers = int(part.get_meta(META_LAYERS))
			part.remove_meta(META_LAYERS)
	_sources.clear()
	if get_parent():
		get_parent().remove_child(self)
	queue_free()


static func _flat_mesh(tool: SurfaceTool, ranges: Array, cull: int) -> MeshInstance3D:
	var arrays: Array = tool.commit_to_arrays()
	var colors: PackedColorArray = PackedColorArray()
	var params: PackedVector2Array = PackedVector2Array()
	for entry: Array in ranges:
		var count: int = entry[0]
		var c: PackedColorArray = PackedColorArray()
		c.resize(count)
		c.fill(entry[1])
		colors.append_array(c)
		var p: PackedVector2Array = PackedVector2Array()
		p.resize(count)
		p.fill(entry[2])
		params.append_array(p)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = params
	arrays[Mesh.ARRAY_TEX_UV] = null       # dokusuz: gerekmez
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not _flat_materials.has(cull):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER_DOUBLE if cull == BaseMaterial3D.CULL_DISABLED else SHADER
		_flat_materials[cull] = material
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Flat" if cull == BaseMaterial3D.CULL_BACK else "FlatDouble"
	mi.mesh = mesh
	mi.material_override = _flat_materials[cull]
	return mi


## Köşe rengine taşınabilir mi: dokusuz, opak, ışıklı ve renk / pürüz / metaliklik / specular DIŞINDAKİ her ayarı
## varsayılan bir StandardMaterial3D.
static func is_flat(material: Material) -> bool:
	var std: StandardMaterial3D = material as StandardMaterial3D
	if std == null:
		return false
	var id: int = std.get_instance_id()
	if _flat_cache.has(id):
		return _flat_cache[id]
	if _default == null:
		_default = StandardMaterial3D.new()
	var flat: bool = std.next_pass == null
	for prop: Dictionary in std.get_property_list():
		if not flat:
			break
		var prop_name: String = prop["name"]
		if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE) or prop_name in FLAT_PROPS:
			continue
		var value: Variant = std.get(prop_name)
		var base: Variant = _default.get(prop_name)
		flat = typeof(value) == typeof(base) and value == base
	flat = flat and std.cull_mode != BaseMaterial3D.CULL_FRONT
	_flat_cache[id] = flat
	return flat


## Parçanın bütün yüzeyleri toplanabilir mi (üçgen; düz renk ya da birleşebilir materyal). MultiMesh örnek rengi /
## özel verisi kullanıyorsa toplanmaz (birleşik mesh'te kaybolurdu).
static func _takeable(part: GeometryInstance3D, mesh: Mesh) -> bool:
	if part is MultiMeshInstance3D:
		var multi: MultiMesh = (part as MultiMeshInstance3D).multimesh
		if multi.use_colors or multi.use_custom_data or multi.transform_format != MultiMesh.TRANSFORM_3D:
			return false
	var array_mesh: ArrayMesh = mesh as ArrayMesh   # PrimitiveMesh (kutu, silindir) hep üçgen
	for s: int in mesh.get_surface_count():
		if array_mesh and array_mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var material: Material = _material_of(part, mesh, s)
		if not is_flat(material) and (material == null or not _mergeable(material)):
			return false
	return true


static func _has_lods(mesh: Mesh) -> bool:
	var id: int = mesh.get_instance_id()
	if not _lod_cache.has(id):
		var any: bool = false
		for s: int in mesh.get_surface_count():
			any = any or not (RenderingServer.mesh_get_surface(mesh.get_rid(), s).get("lods", []) as Array).is_empty()
		_lod_cache[id] = any
	return _lod_cache[id]


static func _vertex_count(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_array_len(surface)
	return (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


## Başka yüzeylerle aynı mesh'te çizilebilir mi (saydam olanlar sıralama ister, birleşmez).
static func _mergeable(material: Material) -> bool:
	var base: BaseMaterial3D = material as BaseMaterial3D
	if base:
		return base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			or base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return false   # ShaderMaterial: saydamlığı / köşe işlemi bilinmez


## Aynı çizimi veren materyallerin ortak anahtarı (saklanan ayarların hepsi).
static func _key(material: Material) -> String:
	var id: int = material.get_instance_id()
	if _key_cache.has(id):
		return _key_cache[id]
	var parts: PackedStringArray = [material.get_class()]
	for prop: Dictionary in material.get_property_list():
		var prop_name: String = prop["name"]
		if int(prop["usage"]) & PROPERTY_USAGE_STORAGE and prop_name not in ["resource_name", "resource_path", "script"]:
			var value: Variant = material.get(prop_name)
			parts.append("%s=%s" % [prop_name, str(value.get_instance_id()) if value is Object else var_to_str(value)])
	var key: String = "|".join(parts)
	_key_cache[id] = key
	return key
