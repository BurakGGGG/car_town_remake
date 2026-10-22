class_name GarageInterior
extends Node3D
## GARAJLARIM 3D iç mekânı (docs/GARAJLAR_TASARIM.md §7) — Blender'da kurulup ışığı PİŞİRİLMİŞ sahne
## (tools/garages/export_garage.py). Ortam IŞIKSIZ çizilir: köşe rengi / dokular ekran değeridir (Blender'ın AgX
## görüntü dönüşümünden geçmiş). Yalnız araçlar gerçek zamanlı ışık alır (ışık / ortam ayarları `setup()`'ta).
##
## GLB düğüm adları sözleşmedir:
##   Shell, Props, …          hep duranlar (köşe rengi)
##   <Kalem>_L<n>             seviye kalemleri (Walls / Lights / Lift / Park): yalnız seçili seviye görünür
##   Decal_<Kalem>_L<n>       o seviyenin zemine düşen gölgesi (çarpımlı, decal_<kalem>_l<n>.png)
##   Floor                    zemin: floor_<zemin sv>_<ışık sv>.png (her çift ayrı pişmiş, tam ışıklı)
##   DeckTop / Backdrop       çatı katı otoparkın güvertesi (deck.png) ve fon perdesi (backdrop.png)
##   TableTop, Car            MODİFİYE GARAJI: döner tablanın üstü (ModGarageView yarı saydam yapar) ve araç yeri;
##                            seviyesiz garajın zemini tek doku (floor.png)
##   Beam_*                   ışık huzmeleri (katkılı)
##   Slot_<n>, Slot_Tow       park yerleri: araç burnu düğümün +Z'sine bakar
## Blender metre; oyunda 1 birim = 4,39 m (araçlar 1,0 boyuna normalize): kök METER ölçeğiyle küçülür.

const METER: float = 1.0 / 4.39
const DIR: Dictionary = {
	&"mahalle": "res://assets/garages/mahalle/",
	&"sanayi": "res://assets/garages/sanayi/",
	&"neon": "res://assets/garages/neon/",
	&"showroom": "res://assets/garages/showroom/",
	&"hangar": "res://assets/garages/hangar/",
	&"waiting": "res://assets/garages/rooftop/",
	&"modgarage": "res://assets/garages/modgarage/",
}
const FILE: Dictionary = {
	&"mahalle": "mahalle.glb",
	&"sanayi": "sanayi.glb",
	&"neon": "neon.glb",
	&"showroom": "showroom.glb",
	&"hangar": "hangar.glb",
	&"waiting": "rooftop.glb",
	&"modgarage": "modgarage.glb",
}
## Seviye kalemleri: CarGarageCatalog kalemi → GLB adı öneki.
const ITEM_NODES: Dictionary = {
	&"walls": "Walls",
	&"lights": "Lights",
	&"lift": "Lift",
	&"park": "Park",
}
## IŞIKLAR seviyesinin pişmiş ortama genel çarpanı: köşe rengi orta düzenle (sv.2) pişer; sv.1 çıplak ampul daha loş
## ve sıcak, sv.3 LED daha parlak ve beyaz. Zemin her seviyede ayrı pişmiştir (çarpan almaz).
const LIGHT_TINT: Array[Color] = [Color(0.86, 0.8, 0.72), Color(1.0, 1.0, 1.0), Color(1.06, 1.06, 1.08)]

## Araç ışığı / kamera / arka plan (Blender önizlemesiyle uyumlu). Konumlar Blender metresinde (X doğu, Y kuzey, Z yukarı).
const SETUP: Dictionary = {
	&"mahalle": {
		"camera": Vector3(14.5, -8.0, 9.0), "target": Vector3(7.4, 5.5, 0.4), "fov": 31.4,
		"bounds": Rect2(1.5, 1.0, 11.0, 8.0),
		"key_dir": Vector3(-0.35, 0.45, -0.82), "key_color": Color(1.0, 0.9, 0.78), "key_energy": 1.15,
		"ambient": Color(0.62, 0.55, 0.48), "ambient_energy": 0.8, "background": Color(0.035, 0.028, 0.024),
		"beam_gain": 1.0,
	},
	&"sanayi": {
		"camera": Vector3(18.6, -10.2, 11.6), "target": Vector3(9.5, 7.7, 0.4), "fov": 31.4,
		"bounds": Rect2(1.5, 1.0, 15.0, 12.0),
		"key_dir": Vector3(-0.3, 0.5, -0.8), "key_color": Color(0.95, 0.97, 1.0), "key_energy": 1.1,
		"ambient": Color(0.56, 0.59, 0.65), "ambient_energy": 0.8, "background": Color(0.02, 0.025, 0.035),
		"beam_gain": 0.8,
	},
	&"neon": {
		"camera": Vector3(24.5, -11.8, 13.0), "target": Vector3(13.6, 8.25, 0.3), "fov": 31.4,
		"bounds": Rect2(2.0, 1.0, 22.0, 13.0),
		# araçlar neonla boyanır: anahtar ışık soğuk-pembe, ortam mor
		"key_dir": Vector3(-0.2, 0.6, -0.78), "key_color": Color(0.88, 0.82, 1.0), "key_energy": 0.95,
		"ambient": Color(0.5, 0.44, 0.62), "ambient_energy": 0.7, "background": Color(0.008, 0.008, 0.016),
		"beam_gain": 0.8,
		"light_tint": [Color(0.8, 0.86, 0.82), Color(1.0, 1.0, 1.0), Color(1.05, 1.03, 1.08)],   # sv.1 soluk yeşilimsi floresan
	},
	&"showroom": {
		"camera": Vector3(24.5, -12.5, 14.0), "target": Vector3(13.6, 8.3, 0.3), "fov": 31.4,
		"bounds": Rect2(2.0, 1.0, 22.0, 14.0),
		"key_dir": Vector3(0.35, 0.3, -0.85), "key_color": Color(1.0, 0.99, 0.96), "key_energy": 1.2,
		"ambient": Color(0.76, 0.78, 0.82), "ambient_energy": 0.85, "background": Color(0.11, 0.12, 0.14),
		"beam_gain": 0.8,
		# nötr: sıcak / loş varsayılan çarpan beyaz salonu beje çeviriyordu
		"light_tint": [Color(0.9, 0.9, 0.92), Color(1.0, 1.0, 1.0), Color(1.04, 1.04, 1.06)],
	},
	&"hangar": {
		"camera": Vector3(32.5, -16.5, 19.5), "target": Vector3(17.8, 11.4, 0.5), "fov": 31.4,
		"bounds": Rect2(2.0, 1.0, 30.0, 20.0),
		"key_dir": Vector3(0.9, -0.1, -0.42), "key_color": Color(1.0, 0.76, 0.56), "key_energy": 1.2,
		"ambient": Color(0.62, 0.56, 0.52), "ambient_energy": 0.75, "background": Color(0.05, 0.035, 0.03),
		"beam_gain": 0.6,
	},
	&"waiting": {
		"camera": Vector3(26.5, -15.0, 14.5), "target": Vector3(11.3, 7.9, -0.2), "fov": 31.4,
		"bounds": Rect2(2.0, 2.0, 20.0, 12.0),
		"key_dir": Vector3(0.9, 0.42, -0.17), "key_color": Color(1.0, 0.72, 0.5), "key_energy": 1.25,
		# ortam ışığı az mor ve zayıf: 0,75 / mavi-mor iken beyaz araçlar leylak görünüyordu
		"ambient": Color(0.64, 0.58, 0.6), "ambient_energy": 0.5, "background": Color(0.16, 0.11, 0.2),
		"beam_gain": 0.45,   # direk huzmeleri oyunda önizlemeden belirgin: parlak sütun gibi duruyordu
	},
	# MODİFİYE GARAJI (ModGarageView): kamera kodda (kategoriye göre); bounds kameranın kalabileceği oda içi
	&"modgarage": {
		"camera": Vector3(15.9, 1.4, 2.5), "target": Vector3(9.5, 9.8, 1.45), "fov": 44.0,
		"bounds": Rect2(1.1, 1.1, 17.8, 13.8), "height": 4.4,   # köşe kolonları 0,7 m: kamera onların dışında
		"key_dir": Vector3(0.25, 0.35, -0.9), "key_color": Color(1.0, 0.88, 0.74), "key_energy": 1.05,
		"ambient": Color(0.58, 0.5, 0.44), "ambient_energy": 0.7, "background": Color(0.012, 0.011, 0.012),
		"beam_gain": 1.0,
	},
}

## İSİM TABELASININ yeri (NameSign, kullanıcı isteği 2026-10-21): Blender metresinde kök noktası (karoların alt ortası),
## yüzün yönü (0 = güneye / kameraya, 90 = doğuya), en çok genişlik, karo boyu, direk boyu (çatı katında tabela korkuluğun
## üstüne basar). Kök duvardan ~0,11 × boy önde: karoların arkası duvara değer. Pişmiş pencere / saat / ışıkların altında.
const SIGN_ANCHORS: Dictionary = {
	&"waiting": {"pos": Vector3(11.0, 15.92, 1.46), "yaw": 0.0, "width": 12.0, "height": 1.25, "posts": 0.35},
	&"mahalle": {"pos": Vector3(6.6, 9.9, 1.86), "yaw": 0.0, "width": 8.6, "height": 0.62},
	# kolonlar (x 6 / 12) arasında, piktogramların altında
	&"sanayi": {"pos": Vector3(8.95, 13.82, 2.4), "yaw": 0.0, "width": 5.0, "height": 0.7},
	# önde serbest duran kolonlar duvara sola kayarak izdüşüyor (x 9,4 → ~6,6, 17,8 → ~16,6): aralarında
	&"neon": {"pos": Vector3(11.4, 14.84, 2.0), "yaw": 0.0, "width": 6.6, "height": 0.72},
	&"showroom": {"pos": Vector3(13.0, 15.82, 3.12), "yaw": 0.0, "width": 8.0, "height": 0.66},
	# asılı uçak (x ~20) sağ yarıyı örtüyor: sol yarıda
	&"hangar": {"pos": Vector3(8.5, 21.78, 5.9), "yaw": 0.0, "width": 10.0, "height": 1.0},
}

var garage: StringName = &""
var _model: Node3D
var _base: StandardMaterial3D        # köşe renkli ışıksız (IŞIKLAR çarpanı albedo_color'da)
var _beam: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _levels: Dictionary = {}


static func has_scene(id: StringName) -> bool:
	return FILE.has(id) and ResourceLoader.exists(String(DIR[id]) + String(FILE[id]))


## Sahneyi kurar (bulunamazsa null). Kökün ölçeği METER: alt düğümler Blender metresinde kalır.
static func create(id: StringName) -> GarageInterior:
	if not has_scene(id):
		return null
	var scene: PackedScene = load(String(DIR[id]) + String(FILE[id])) as PackedScene
	if scene == null:
		return null
	var interior: GarageInterior = GarageInterior.new()
	interior.name = "Interior_%s" % id
	interior.garage = id
	interior.scale = Vector3.ONE * METER
	interior._model = scene.instantiate() as Node3D
	interior.add_child(interior._model)
	interior._apply_materials()
	return interior


## Kalem seviyeleri: {&"floor": 1, &"walls": 2, &"lights": 1, &"lift": 3, &"park": 2}. Eksik kalem 1 sayılır.
func set_levels(levels: Dictionary) -> void:
	_levels = levels.duplicate()
	for child: Node in _model.get_children():
		var parsed: Array = _parse_level(String(child.name))
		if parsed.is_empty():
			continue
		var item: StringName = parsed[0]
		(child as Node3D).visible = int(_levels.get(item, 1)) == int(parsed[1])
	var lights: int = clampi(int(_levels.get(&"lights", 1)), 1, 3)
	if _base:
		var tints: Array = setup().get("light_tint", LIGHT_TINT)
		_base.albedo_color = tints[lights - 1] if is_leveled() else Color.WHITE
	if _floor_material and is_leveled():
		var floor_level: int = clampi(int(_levels.get(&"floor", 1)), 1, 3)
		_floor_material.albedo_texture = load(String(DIR[garage]) + "floor_%d_%d.png" % [floor_level, lights]) as Texture2D


## Seviye kalemli garaj mı (çatı katı otoparkın ve modifiye garajının kalemi yok).
func is_leveled() -> bool:
	return garage != &"waiting" and garage != &"modgarage"


## Adıyla bir GLB düğümü (TableTop, Car …); yoksa null.
func part(node_name: String) -> Node3D:
	return _model.get_node_or_null(node_name) as Node3D


## İşaretçi düğümün dünya dönüşümü (ölçeksiz); yoksa boş dönüşüm.
func marker(node_name: String) -> Transform3D:
	return _marker_transform(part(node_name))


func levels() -> Dictionary:
	return _levels.duplicate()


## Park yeri sayısı (Slot_0 … Slot_<n-1>; Slot_Tow hariç).
func slot_count() -> int:
	var n: int = 0
	while _model.get_node_or_null("Slot_%d" % n) != null:
		n += 1
	return n


## Park yerinin dünya dönüşümü (ölçeksiz: konum + yön). Yoksa boş dönüşüm.
func slot_transform(index: int) -> Transform3D:
	return _marker_transform(_model.get_node_or_null("Slot_%d" % index) as Node3D)


## Çekicinin kasası (çatı katı otopark); yoksa null dönüşüm ve has_tow false.
func has_tow() -> bool:
	return _model.get_node_or_null("Slot_Tow") != null


func tow_transform() -> Transform3D:
	return _marker_transform(_model.get_node_or_null("Slot_Tow") as Node3D)


func setup() -> Dictionary:
	return SETUP.get(garage, SETUP[&"mahalle"])


## İsim tabelasının yeri (SIGN_ANCHORS); bu iç mekânda tabela yeri yoksa boş.
func sign_anchor() -> Dictionary:
	return SIGN_ANCHORS.get(garage, {})


## Blender metresindeki noktayı (X doğu, Y kuzey, Z yukarı) bu iç mekânın dünya konumuna çevirir.
func blender_point(p: Vector3) -> Vector3:
	return to_global(Vector3(p.x, p.z, -p.y))


## Blender yönünü oyun yönüne (ölçeksiz).
static func blender_dir(d: Vector3) -> Vector3:
	return Vector3(d.x, d.z, -d.y).normalized()


func _marker_transform(node: Node3D) -> Transform3D:
	if node == null:
		return Transform3D()
	var t: Transform3D = node.global_transform
	return Transform3D(t.basis.orthonormalized(), t.origin)


## "Walls_L2" → [&"walls", 2]; "Decal_Lift_L3" → [&"lift", 3]; seviye kalemi değilse boş.
func _parse_level(node_name: String) -> Array:
	var stem: String = node_name.trim_prefix("Decal_")
	var cut: int = stem.rfind("_L")
	if cut < 0 or not stem.substr(cut + 2).is_valid_int():
		return []
	var prefix: String = stem.substr(0, cut)
	for item: StringName in ITEM_NODES:
		if ITEM_NODES[item] == prefix:
			return [item, stem.substr(cut + 2).to_int()]
	return []


# --- Materyaller ----------------------------------------------------------------------------------

func _apply_materials() -> void:
	_base = StandardMaterial3D.new()
	_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_base.vertex_color_use_as_albedo = true
	_base.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam = StandardMaterial3D.new()
	_beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.vertex_color_use_as_albedo = true
	_beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gain: float = float(setup().get("beam_gain", 1.0))
	_beam.albedo_color = Color(gain, gain, gain)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var node_name: String = String(mi.name)
		var material: Material = _base
		if node_name.begins_with("Beam_"):
			material = _beam
		elif node_name.begins_with("Decal_"):
			material = _decal_material(node_name)
		elif node_name == "Floor":
			_floor_material = _texture_material(null if is_leveled() else load(String(DIR[garage]) + "floor.png") as Texture2D)
			material = _floor_material
		elif node_name == "DeckTop":
			material = _texture_material(load(String(DIR[garage]) + "deck.png") as Texture2D)
		elif node_name == "Backdrop":
			material = _texture_material(load(String(DIR[garage]) + "backdrop.png") as Texture2D)
		for s: int in (mi.mesh.get_surface_count() if mi.mesh else 0):
			mi.set_surface_override_material(s, material)
	set_levels({})


func _texture_material(texture: Texture2D) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


## Zemine düşen gölge: dokusu ekran değerine doğrudan çarpılır (pişirme oranı, 1 = gölgesiz).
func _decal_material(node_name: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = load(String(DIR[garage]) + node_name.to_lower() + ".png") as Texture2D
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material
