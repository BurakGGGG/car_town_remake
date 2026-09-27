class_name CarRig
extends RefCounted
## Bir araç instance'ına CarAppearance uygular ve tekerleklerini döndürür.
## Tek sistem: Main dünyasındaki araç, GarageScreen önizlemesi ve CarGallery thumbnail'i
## aynı sınıfla güncellenir.
##
## Materyal izolasyonu: GLB'nin tek materyali tüm parçalar ve aynı aracın tüm instance'ları
## arasında paylaşıldığı için ASLA yerinde değiştirilmez. Rig, instance'a özel
## StandardMaterial3D'ler üretir ve `set_surface_override_material(0, …)` ile sadece ilgili
## roldeki MeshInstance3D'lere takar; orijinal kaynak ve diğer instance'lar etkilenmez.
##
## Teker pivotu: GLB'de pivotlar araç orijininde. Her teker grubu için pivot = grubun ilk
## mesh'inin (lastik) AABB merkezi; dönüş  base * T(p) * R * T(-p)  ile uygulanır.
## steer_deg: + = sola. Sadece ön gruplar (fl, fr) direksiyon alır.
##
## Materyaller: body_color yalnızca body + mirrors'a gider. Cam, farlar, stoplar, ızgara, siyah
## plastikler, plaka, sis farı, egzoz, anten ve lastikler gerçek araç görünümüne uygun SABİT
## materyallerde kalır (rig'ler arasında paylaşılan, GLB'den bağımsız kaynaklar).
##
## Dokulu modeller (GLB materyalinde albedo dokusu varsa): görünüm dokudan gelir, düz renk basılmaz.
## PAINT_ROLES (kaportaya boya girebilecek tüm roller) → car_paint.gdshader + aracın UV'sindeki PAINT MASK (assets/cars/optimized/
## <id>_paintmask.png, tools/make_paint_mask.gd üretir): yalnızca maskede beyaz olan kaporta texel'leri
## body_color'a çevrilir, dokunun gölge/parlama/panel detayı korunur. Gövde mesh'ine kaynamış cam, far ve
## trim (BMW/Getz ön camı, tek mesh Toros) maskede siyah olduğu için boya almaz. Maske yoksa boyama
## kapalıdır (doku aynen). rims / cam → doku × (renk / varsayılan renk) — varsayılanda doku aynen.
## Tek mesh tekerler → wheel_split.gdshader doku modu (jant rengi body_color'dan bağımsız).
## Farlar / stoplar → doku + emisyon (headlights_enabled / taillights_enabled). Diğer roller GLB
## materyalinde kalır. Aynı CarAppearance API'si; dokusuz eski modeller için eski yol değişmeden çalışır.

const META_KEY: StringName = &"car_rig"
const WHEEL_SHADER: Shader = preload("res://vehicles/wheel_split.gdshader")
## Bir tekerlek grubundaki mesh, en küçük tekerin bu katından büyükse tekerlek sayılmaz
## (çamurluk/kemer parça haritasına yanlışlıkla girmiş olur). Ölçüldü: temiz tekerler
## birbirinden en çok %8 farklı, bulaşmış gruplar %40 büyük çıkıyor.
const WHEEL_MEMBER_TOLERANCE: float = 1.25
## Bir üyenin merkezi, lastiğin ekseninden (Y-Z düzleminde) lastik çapının bu katından uzaksa
## tekerleğin parçası değildir. Jant/göbek eş merkezlidir; kaliper/kemer değildir.
const WHEEL_AXIS_TOLERANCE: float = 0.22
const PAINT_SHADER: Shader = preload("res://vehicles/car_paint.gdshader")
const PAINT_MATCH: float = 0.03  # body_color fabrika boyasına bu kadar yakınsa doku aynen (yeniden boyama yok)
## Boya shader'ının uygulandığı roller: kaporta + dokuda kaporta rengi olabilen parçalar (renkli tampon,
## ızgara çerçevesi, plaka yuvası...). Hangi TEXEL'in boyanacağına maske karar verir; maskede siyah olan
## her şey dokudaki haliyle kalır, bu yüzden bu rollerin fazladan eklenmesi görünümü değiştirmez.
const PAINT_ROLES: Array[StringName] = [
	&"body", &"mirrors", &"black_trim", &"grille", &"plate", &"fog_lights", &"exhaust", &"antenna",
]
const RIM_RATIO: float = 0.78  # teker yarıçapının bu oranının içi jant sayılır
const RIM_METALLIC: float = 0.55
const RIM_ROUGHNESS: float = 0.4

## Detay kademeleri (LOD). Geometri kademeleri Godot'un import sırasında ürettiği LOD zincirinden
## gelir (meshes/generate_lods); hangi kademenin çizileceğini mesh'in ekrandaki boyutu seçer.
## Bu katsayı seçimi instance başına kaydırır: 1.0 = varsayılan, >1 daha uzun süre detaylı kalır,
## <1 daha erken sadeleşir. Uzaklaşan araç kendiliğinden bir alt kademeye iner.
const LOD_BIAS_GARAGE: float = 4.0  # LOD0: garaj önizlemesi, tam detay
const LOD_BIAS_WORLD: float = 1.0   # LOD1: şehirdeki oyuncu araçları ve galeri thumbnail'leri
const LOD_BIAS_NPC: float = 0.5     # LOD2–LOD3: trafik araçları (uzaktakiler en sade kademeye iner)

## Görünümden bağımsız sabit materyaller (rol → StandardMaterial3D), tüm rig'ler paylaşır.
static var _fixed_materials: Dictionary = {}
## Geometrik olarak bölünmüş mesh'ler ("scene|part" → ArrayMesh), tüm instance'lar paylaşır.
static var _split_meshes: Dictionary = {}

## Araç tipi (.tscn yolu) → canlı rig listesi; CarAppearance.changed → apply_to_all.
static var _rigs: Dictionary = {}

var root: Node3D
var scene_path: String
var spin_deg: float = 0.0
var steer_deg: float = 0.0

var _all_meshes: Array[MeshInstance3D] = []  # bu aracın tüm mesh'leri (LOD katsayısı için)
var _parts: Dictionary = {}       # rol → Array[MeshInstance3D] (yüzey 0)
var _surface_parts: Dictionary = {}  # rol → Array[[MeshInstance3D, yüzey indeksi]] (bölünmüş mesh'ler)
var _wheel_groups: Array[Dictionary] = []  # {front, pivot, meshes, bases}
var _materials: Dictionary = {}   # rol → StandardMaterial3D (bu instance'a özel)
var _paint_materials: Dictionary = {}  # rol → ShaderMaterial (dokulu model: body / mirrors)
var _wheel_dropped: PackedStringArray = PackedStringArray()  # gruptan elenen parçalar (denetim)
var _wheel_materials: Array[ShaderMaterial] = []  # tek mesh tekerler için (bu instance'a özel)
var _last_applied: CarAppearance
var _albedo: Texture2D               # GLB'nin albedo dokusu (dokusuz modelde null)
var _paint_mask: Texture2D           # UV paint mask (yoksa null → boyama kapalı)
var _mask_probed: bool = false        # maske diskten bir kez arandı mı (tembel yükleme)
var _default_paint: Color = Color.WHITE  # CarPartMap.default_paint (dokudaki fabrika boyası)


## Node'a bağlı rig'i döndürür (yoksa kurar, node meta'sında saklar ve kayıt defterine ekler).
static func for_node(car_root: Node3D) -> CarRig:
	if car_root.has_meta(META_KEY):
		return car_root.get_meta(META_KEY)
	var rig: CarRig = CarRig.new(car_root)
	car_root.set_meta(META_KEY, rig)
	if not _rigs.has(rig.scene_path):
		_rigs[rig.scene_path] = []
	(_rigs[rig.scene_path] as Array).append(rig)
	return rig


## Aynı araç tipinin kayıtlı tüm canlı instance'larına görünümü uygular.
static func apply_to_all(path: String, appearance: CarAppearance) -> void:
	if not _rigs.has(path):
		return
	var alive: Array = []
	for rig: CarRig in _rigs[path]:
		if is_instance_valid(rig.root) and rig.root.is_inside_tree():
			rig.apply(appearance)
			alive.append(rig)
	_rigs[path] = alive


func _init(car_root: Node3D) -> void:
	root = car_root
	scene_path = car_root.scene_file_path
	_resolve_parts()


# --- Görünüm ------------------------------------------------------------------

func apply(appearance: CarAppearance) -> void:
	_last_applied = appearance
	if _albedo:
		_apply_textured(appearance)
		return

	# --- Görünüme bağlı (instance'a özel) materyaller ---
	var body: StandardMaterial3D = _material(&"body")
	body.albedo_color = appearance.body_color
	body.metallic = 0.15
	body.roughness = 0.45

	var rims: StandardMaterial3D = _material(&"rims")
	rims.albedo_color = appearance.wheel_color
	rims.metallic = RIM_METALLIC
	rims.roughness = RIM_ROUGHNESS

	# Lastik + jant tek mesh olan tekerler: shader yarıçapa göre ayırır, jant rengi buradan
	for wheel_mat: ShaderMaterial in _wheel_materials:
		wheel_mat.set_shader_parameter(&"rim_color", appearance.wheel_color)

	# Camlar OPAK füme: saydamlık kapalı, böylece boş kabin / ters yüzeyler görünmez
	var glass: StandardMaterial3D = _material(&"glass")
	glass.albedo_color = appearance.glass_color
	glass.metallic = 0.0
	glass.roughness = 0.22
	glass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	var head: StandardMaterial3D = _material(&"headlights")
	head.albedo_color = Color(0.93, 0.95, 0.97)  # beyaz/şeffaf lens
	head.roughness = 0.15
	head.emission_enabled = appearance.headlights_enabled
	head.emission = Color(1.0, 0.96, 0.82)
	head.emission_energy_multiplier = 3.0

	var tail: StandardMaterial3D = _material(&"taillights")
	tail.albedo_color = Color(0.72, 0.04, 0.05)  # kırmızı lens, açık/kapalı fark etmez
	tail.roughness = 0.25
	tail.emission_enabled = appearance.taillights_enabled
	tail.emission = Color(1.0, 0.12, 0.1)
	tail.emission_energy_multiplier = 2.5

	_assign(&"body", body)
	_assign(&"mirrors", body)   # ayna gövdesi araç rengi; ayna camı modelde ayrı değil
	_assign(&"rims", rims)
	_assign(&"glass", glass)
	_assign(&"headlights", head)
	_assign(&"taillights", tail)

	# --- Sabit gerçekçi materyaller ---
	for role: StringName in [&"tires", &"grille", &"black_trim", &"plate", &"fog_lights", &"exhaust", &"antenna"]:
		_assign(role, _fixed(role))

	for mesh: MeshInstance3D in _parts.get(&"hidden", []):
		mesh.visible = false


## Dokulu model: doku korunur; CarAppearance yalnızca boya anahtarı / ton / emisyon olarak uygulanır.
func _apply_textured(appearance: CarAppearance) -> void:
	# Fabrika rengindeyken boya shader'ı hiç takılmaz: GLB'nin kendi materyali kalır (ek doku örneklemesi
	# ve materyal değişimi yok). Yalnızca yeniden boyanan araçlar shader'a geçer.
	var repaint: bool = not _color_close(appearance.body_color, _default_paint) and _mask() != null
	var paint: ShaderMaterial = _paint_material(&"paint") if repaint else null
	if paint:
		paint.set_shader_parameter(&"tint", appearance.body_color)
		paint.set_shader_parameter(&"recolor", 1.0)
	for role: StringName in PAINT_ROLES:
		_assign(role, paint)

	var rim_tint: Color = _ratio_tint(appearance.wheel_color, CarAppearance.DEFAULT_RIM)
	var rims: StandardMaterial3D = _material(&"rims")
	rims.albedo_texture = _albedo
	rims.albedo_color = rim_tint
	rims.metallic = 0.25
	rims.roughness = RIM_ROUGHNESS
	for wheel_mat: ShaderMaterial in _wheel_materials:
		wheel_mat.set_shader_parameter(&"rim_tint", rim_tint)

	var glass: StandardMaterial3D = _material(&"glass")
	glass.albedo_texture = _albedo
	glass.albedo_color = _ratio_tint(appearance.glass_color, CarAppearance.DEFAULT_GLASS)
	glass.metallic = 0.0
	glass.roughness = 0.22
	glass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	var head: StandardMaterial3D = _material(&"headlights")
	head.albedo_texture = _albedo
	head.roughness = 0.2
	head.emission_enabled = appearance.headlights_enabled
	head.emission = Color(1.0, 0.96, 0.82)
	head.emission_energy_multiplier = 2.0

	var tail: StandardMaterial3D = _material(&"taillights")
	tail.albedo_texture = _albedo
	tail.roughness = 0.3
	tail.emission_enabled = appearance.taillights_enabled
	tail.emission = Color(1.0, 0.12, 0.1)
	tail.emission_energy_multiplier = 1.8

	_assign(&"rims", rims)
	_assign(&"glass", glass)
	_assign(&"headlights", head)
	_assign(&"taillights", tail)
	# tires, grille, black_trim, plate, fog_lights, exhaust, antenna: GLB'nin dokulu materyalinde kalır
	for mesh: MeshInstance3D in _parts.get(&"hidden", []):
		mesh.visible = false


## Renk / varsayılan renk oranı (kanal başına, ≤ 1): varsayılanda beyaz → doku aynen.
static func _ratio_tint(color: Color, base: Color) -> Color:
	return Color(minf(color.r / maxf(base.r, 0.01), 1.0), minf(color.g / maxf(base.g, 0.01), 1.0), minf(color.b / maxf(base.b, 0.01), 1.0))


static func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < PAINT_MATCH and absf(a.g - b.g) < PAINT_MATCH and absf(a.b - b.b) < PAINT_MATCH


## Boya maskesi (ilk istekte diskten yüklenir, sonuç — null da olsa — saklanır).
func _mask() -> Texture2D:
	if not _mask_probed:
		_mask_probed = true
		if _albedo:
			_paint_mask = _load_paint_mask(scene_path)
	return _paint_mask


## Dokulu gövde boyası materyali (rol başına bir kez; doku ve fabrika boyası sabit).
func _paint_material(role: StringName) -> ShaderMaterial:
	if not _paint_materials.has(role):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = PAINT_SHADER
		mat.set_shader_parameter(&"albedo_tex", _albedo)
		mat.set_shader_parameter(&"paint_mask", _mask())
		mat.set_shader_parameter(&"paint", _default_paint)
		_paint_materials[role] = mat
	return _paint_materials[role]


func _assign(role: StringName, material: Material) -> void:
	for mesh: MeshInstance3D in _parts.get(role, []):
		mesh.set_surface_override_material(0, material)
	for pair: Array in _surface_parts.get(role, []):
		(pair[0] as MeshInstance3D).set_surface_override_material(pair[1], material)


## Rol için görünümden bağımsız materyal (bir kez üretilir, rig'ler arasında paylaşılır).
static func _fixed(role: StringName) -> StandardMaterial3D:
	if _fixed_materials.has(role):
		return _fixed_materials[role]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	match role:
		&"tires":       # kauçuk
			mat.albedo_color = Color(0.05, 0.05, 0.05)
			mat.roughness = 0.95
		&"grille":
			mat.albedo_color = Color(0.06, 0.06, 0.06)
			mat.roughness = 0.75
		&"black_trim", &"antenna":
			mat.albedo_color = Color(0.08, 0.08, 0.09)
			mat.roughness = 0.85
		&"plate":
			mat.albedo_color = Color(0.95, 0.95, 0.93)
			mat.roughness = 0.5
		&"fog_lights":
			mat.albedo_color = Color(0.88, 0.90, 0.92)
			mat.roughness = 0.2
		&"exhaust":
			mat.albedo_color = Color(0.40, 0.40, 0.42)
			mat.metallic = 0.9
			mat.roughness = 0.4
		_:
			mat.albedo_color = Color.WHITE
			mat.roughness = 0.5
	_fixed_materials[role] = mat
	return mat


func get_applied() -> CarAppearance:
	return _last_applied


func has_role(role: StringName) -> bool:
	return not (_parts.get(role, []) as Array).is_empty()


func get_meshes(role: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	out.assign(_parts.get(role, []))
	return out


# --- Detay kademesi (LOD) -------------------------------------------------------

## Mesh'in tekerlek büyüklüğü: ebeveyn uzayında kutunun dikey/boyuna en büyük kenarı.
static func _wheel_extent(mesh: MeshInstance3D) -> float:
	var box: AABB = mesh.transform * mesh.get_aabb()
	return maxf(box.size.y, box.size.z)


## Bu instance'ın tüm mesh'lerine LOD katsayısını uygular (bkz. LOD_BIAS_* sabitleri).
func set_lod_bias(bias: float) -> void:
	for mesh: MeshInstance3D in _all_meshes:
		if is_instance_valid(mesh):
			mesh.lod_bias = bias


# --- Tekerlek ------------------------------------------------------------------

## Tüm tekerleri aks ekseninde verilen açıya getirir (derece).
func set_wheel_spin(degrees: float) -> void:
	spin_deg = fmod(degrees, 360.0)
	_update_wheels()


## Tekerleri aks ekseninde artımlı döndürür (derece).
func spin_wheels(delta_degrees: float) -> void:
	set_wheel_spin(spin_deg + delta_degrees)


## Ön tekerleri Y ekseninde direksiyon açısına çevirir (derece, + = sol).
func set_steer(degrees: float) -> void:
	steer_deg = degrees
	_update_wheels()


func _update_wheels() -> void:
	var spin: Basis = Basis(Vector3.RIGHT, deg_to_rad(spin_deg))
	for group: Dictionary in _wheel_groups:
		var rot: Basis = spin
		if group["front"]:
			rot = Basis(Vector3.UP, deg_to_rad(steer_deg)) * spin
		# Dönüş EBEVEYN uzayında, tekerin GERÇEK merkezi etrafında uygulanır. (Eskiden ilk
		# mesh'in KENDİ yerel kutu merkezi pivot alınıp dönüş mesh'in yerel uzayında
		# uygulanıyordu: parçaların yerel çerçeveleri farklı olduğunda teker kendi ekseninde
		# değil aracın içinde yörüngeye giriyordu — Şahin'de ölçülen kayma 0,229 birim.)
		var pivot: Vector3 = group["pivot"]
		var about: Transform3D = Transform3D(Basis(), pivot) * Transform3D(rot, Vector3.ZERO) \
			* Transform3D(Basis(), -pivot)
		var meshes: Array = group["meshes"]
		var bases: Array = group["bases"]
		for i: int in meshes.size():
			var mesh: MeshInstance3D = meshes[i]
			if is_instance_valid(mesh):
				mesh.transform = about * (bases[i] as Transform3D)


# --- Kurulum -----------------------------------------------------------------

func _resolve_parts() -> void:
	var map: Dictionary = CarPartMap.get_map(scene_path)
	if map.is_empty():
		push_warning("CarRig: '%s' için parça haritası yok" % scene_path)
		return
	var by_name: Dictionary = {}
	_collect_meshes(root, by_name)
	_all_meshes.assign(by_name.values())
	_default_paint = map.get("default_paint", Color.WHITE)
	_albedo = _find_albedo(_all_meshes)
	# Maske KURULUMDA yüklenmez: fabrika renginde hiç örneklenmez, araç başına 1.33 MB VRAM
	# (1024² kayıpsız) boşa giderdi. İlk yeniden boyamada _mask() ile yüklenir.

	for role: StringName in CarPartMap.ROLES:
		var list: Array[MeshInstance3D] = []
		for index: int in map.get(role, []):
			var mesh: MeshInstance3D = _find(by_name, index)
			if mesh:
				list.append(mesh)
		_parts[role] = list

	# Lastik + jant tek mesh: her teker için kendi merkezini bilen shader materyali
	for mesh: MeshInstance3D in _parts.get(&"wheels", []):
		var box: AABB = mesh.get_aabb()
		var wheel_mat: ShaderMaterial = ShaderMaterial.new()
		wheel_mat.shader = WHEEL_SHADER
		wheel_mat.set_shader_parameter(&"center", box.get_center())
		wheel_mat.set_shader_parameter(&"rim_radius", maxf(box.size.y, box.size.z) * 0.5 * RIM_RATIO)
		wheel_mat.set_shader_parameter(&"rim_metallic", RIM_METALLIC)
		wheel_mat.set_shader_parameter(&"rim_roughness", RIM_ROUGHNESS)
		if _albedo:
			wheel_mat.set_shader_parameter(&"albedo_tex", _albedo)
			wheel_mat.set_shader_parameter(&"use_texture", 1.0)
		_wheel_materials.append(wheel_mat)
		mesh.set_surface_override_material(0, wheel_mat)

	# Tek mesh'te iki rol (ör. Fluence ön cam + tavan): z eşiğine göre iki yüzeye bölünür
	for spec: Dictionary in map.get("split_z", []):
		var mesh: MeshInstance3D = _find(by_name, spec["part"])
		if mesh == null:
			continue
		mesh.mesh = _split_mesh_z(mesh.mesh, scene_path, spec["part"], spec["z"])
		_add_surface_part(StringName(spec["front"]), mesh, 0)
		_add_surface_part(StringName(spec["back"]), mesh, 1)

	var wheels: Dictionary = map.get("wheel_groups", {})
	var raw: Array = []
	var reference: float = INF
	for key: String in ["fl", "fr", "rl", "rr"]:
		var meshes: Array[MeshInstance3D] = []
		for index: int in wheels.get(key, []):
			var mesh: MeshInstance3D = _find(by_name, index)
			if mesh:
				meshes.append(mesh)
		if meshes.is_empty():
			continue
		# Grubun "çekirdeği": en büyük üye = lastik. Dört grubun en KÜÇÜK çekirdeği referanstır
		# (sokak araçlarında dört teker aynı boydadır).
		var core: float = 0.0
		for mesh: MeshInstance3D in meshes:
			core = maxf(core, _wheel_extent(mesh))
		reference = minf(reference, core)
		raw.append({"key": key, "meshes": meshes})
	for item: Dictionary in raw:
		# 1) BOYUT elemesi: en küçük tekerin belirgin şekilde üstündeki parça tekerlek değildir
		#    (çamurluk / kemer yanlışlıkla haritaya girmiş olur).
		var sized: Array[MeshInstance3D] = []
		var dropped: PackedStringArray = PackedStringArray()
		for mesh: MeshInstance3D in (item["meshes"] as Array[MeshInstance3D]):
			if _wheel_extent(mesh) <= reference * WHEEL_MEMBER_TOLERANCE:
				sized.append(mesh)
			else:
				dropped.append(mesh.name)
		if sized.is_empty():
			sized.assign(item["meshes"])
		# 2) Eksen, ELEMEDEN SONRA kalan en büyük üyeden (lastik) alınır. Eleneni eksen kabul
		#    etmek tekeri çamurluğun merkezi etrafında döndürüyordu (Audi'de ölçülen 0,099).
		var tyre: MeshInstance3D = sized[0]
		var tyre_extent: float = _wheel_extent(tyre)
		for mesh: MeshInstance3D in sized:
			var extent: float = _wheel_extent(mesh)
			if extent > tyre_extent:
				tyre_extent = extent
				tyre = mesh
		var axis: Vector3 = (tyre.transform * tyre.get_aabb()).get_center()
		# 3) EKSEN elemesi: jant/göbek lastikle eş merkezlidir; kaliper/kemer değildir.
		var kept: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in sized:
			var box: AABB = mesh.transform * mesh.get_aabb()
			var offset: Vector2 = Vector2(box.get_center().y - axis.y, box.get_center().z - axis.z)
			if mesh == tyre or offset.length() <= tyre_extent * WHEEL_AXIS_TOLERANCE:
				kept.append(mesh)
			else:
				dropped.append(mesh.name)
		if not dropped.is_empty():
			# Parça haritası tekerlek grubuna tekerlek OLMAYAN bir mesh koymuş (çamurluk / kemer).
			# Dönmesi gövdeyi döndürüyormuş gibi görünürdü; gruptan çıkarılır (görünür kalır).
			push_warning("CarRig: '%s' %s tekerlek grubundan çıkarılan parça(lar): %s"
				% [scene_path.get_file(), item["key"], ", ".join(dropped)])
		_wheel_dropped.append_array(dropped)
		var bases: Array[Transform3D] = []
		for mesh: MeshInstance3D in kept:
			bases.append(mesh.transform)
		_wheel_groups.append({
			"front": String(item["key"]).begins_with("f"),
			"tyre_index": maxi(kept.find(tyre), 0),
			"pivot": axis,   # EBEVEYN uzayında LASTİĞİN ekseni
			"meshes": kept,
			"bases": bases,
		})


func _add_surface_part(role: StringName, mesh: MeshInstance3D, surface: int) -> void:
	if not _surface_parts.has(role):
		_surface_parts[role] = []
	(_surface_parts[role] as Array).append([mesh, surface])


## Tek yüzeyli mesh'i üçgen merkezinin z'sine göre iki yüzeye böler (0: z > eşik, 1: gerisi).
## Eşik yakınındaki yatay üçgenler (|normal.y| > 0.9) tavan sayılır. Sonuç önbelleğe alınır;
## orijinal GLB kaynağı değişmez (MeshInstance yeni ArrayMesh'i gösterir).
static func _split_mesh_z(source: Mesh, path: String, part: int, z_split: float) -> ArrayMesh:
	# Optimize edilmiş asset'te bölme pipeline'da (tools/optimize_car.gd, aynı kural) yapılmıştır:
	# yüzey 0 ön, 1 arka. Mesh'e dokunulmaz, böylece Godot import LOD zinciri ve gölge mesh'i kalır.
	if source.get_surface_count() >= 2:
		return source as ArrayMesh
	var key: String = "%s|%d" % [path, part]
	if _split_meshes.has(key):
		return _split_meshes[key]
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var front: PackedInt32Array = PackedInt32Array()
	var back: PackedInt32Array = PackedInt32Array()
	for t: int in indices.size() / 3:
		var i0: int = indices[t * 3]
		var i1: int = indices[t * 3 + 1]
		var i2: int = indices[t * 3 + 2]
		var a: Vector3 = verts[i0]
		var b: Vector3 = verts[i1]
		var c: Vector3 = verts[i2]
		var cz: float = (a.z + b.z + c.z) / 3.0
		var is_front: bool = cz > z_split
		if is_front and cz < z_split + 0.04:
			var n: Vector3 = (b - a).cross(c - a)
			if n.length_squared() > 0.0 and absf(n.normalized().y) > 0.9:
				is_front = false
		var target: PackedInt32Array = front if is_front else back
		target.append(i0)
		target.append(i1)
		target.append(i2)
	var result: ArrayMesh = ArrayMesh.new()
	for part_indices: PackedInt32Array in [front, back]:
		var surface: Array = arrays.duplicate()
		surface[Mesh.ARRAY_INDEX] = part_indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	_split_meshes[key] = result
	return result


## Bu aracın mesh'lerini toplar. İç içe sahne instance'larına (ör. Main.tscn'de başka bir aracın
## çocuğu olarak duran araç) inmez; yoksa aynı "tripo_part_N" adları çakışır.
func _collect_meshes(node: Node, out: Dictionary) -> void:
	if node is MeshInstance3D:
		out[node.name] = node
	for child: Node in node.get_children():
		if child.scene_file_path != "" and child != root:
			continue
		_collect_meshes(child, out)


## Aracın UV paint mask'i: katalogdaki optimized_path'in yanındaki "<ad>_paintmask.png".
static func _load_paint_mask(path: String) -> Texture2D:
	var entry: Dictionary = CarCatalog.find_by_scene(path)
	var optimized: String = String(entry.get("optimized_path", ""))
	if optimized == "":
		return null
	var mask_path: String = optimized.get_basename() + "_paintmask.png"
	if not ResourceLoader.exists(mask_path):
		push_warning("CarRig: '%s' için paint mask yok (boyama kapalı): %s" % [path.get_file(), mask_path.get_file()])
		return null
	return load(mask_path) as Texture2D


## GLB materyalindeki albedo dokusu (ilk bulunan yüzey); dokusuz modelde null.
static func _find_albedo(meshes: Array[MeshInstance3D]) -> Texture2D:
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		for si: int in mesh.mesh.get_surface_count():
			var mat: BaseMaterial3D = mesh.mesh.surface_get_material(si) as BaseMaterial3D
			if mat and mat.albedo_texture:
				return mat.albedo_texture
	return null


func _find(by_name: Dictionary, index: int) -> MeshInstance3D:
	var mesh: MeshInstance3D = by_name.get(CarPartMap.part_name(index))
	if mesh == null:
		push_warning("CarRig: %s içinde tripo_part_%d bulunamadı" % [scene_path.get_file(), index])
	return mesh


## Bu instance'a özel, görünüme bağlı materyal (rol başına bir kez üretilir).
func _material(role: StringName) -> StandardMaterial3D:
	if not _materials.has(role):
		_materials[role] = StandardMaterial3D.new()
	return _materials[role]
