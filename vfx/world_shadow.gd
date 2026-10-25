class_name WorldShadow
extends Node
## ŞEHİR GÖLGESİ (2026-10-25) — bina, ağaç, dekor, park etmiş araç ve tabelaların zemine düşen gölgesi; kare başına
## maliyeti yalnızca zemin shader'larında bir doku okuması.
##
## Neden gerçek zamanlı gölge değil: GL Compatibility'de gölgeli güneş her alıcıyı EK bir ışık geçişinde yeniden çizer
## (şehirde çizim çağrısı ~3 katına çıkar) ve denendiğinde garaj karoları beyaza dönüyordu (qa/gorunum_lab.gd "golge").
## Bunun yerine statik nesneler GÜNEŞ YÖNÜNDEN, dik izdüşümle, ayrı bir dünyada BİR KEZ beyaz siluet olarak çizilir
## (PİŞİRME), görüntü tek kanallı küçük bir dokuya (1024² R8 = 1 MB) indirilir ve zeminler onu okur
## (world_shadow.gdshaderinc). İzdüşüm güneş ışını boyunca sabit olduğundan zeminin yüksekliği fark etmez.
##
## ALICI = düz zemin (yol, kaldırım, çimen, garaj zemini, otopark, işaretler): gölge DÜŞÜRMEZ, yalnız alır; düz renkli
## StandardMaterial3D'ler aynı görünümdeki world_ground.gdshader'a çevrilir. DÖKÜCÜ = diğer her şey (yükseklik taşıyan,
## cast_shadow kapalı olmayan). Hareket eden araçlar (Traffic) haritaya girmez — kendi gölgelerini taşırlar (CarShadow).
## Dekor / alan / garaj seviyesi değişince harita kısa bir beklemeyle yeniden pişirilir (tek kare + geri okuma).

const META: StringName = &"world_shadow"
const GROUP: StringName = &"world_shadow"
## Saklanan doku boyu (R8: 1024² = 1 MB). Siluet doğrudan bu boyda MSAA 4× ile çizilir (yumuşak kenar, küçük geri
## okuma); MSAA'nın bozuk olduğu GPU'da (PowerVR, GameSettings.msaa_supported) iki katı boyda çizilip küçültülür.
const MAP_SIZE: int = 1024
const LOW_MAP_SIZE: int = 512
## Haritanın kapsadığı dünya (kameranın gidebileceği sınırın biraz dışı; WorldCamera.world_min/max).
const AREA_MIN: Vector2 = Vector2(-12.0, -10.5)
const AREA_MAX: Vector2 = Vector2(10.2, 11.8)
## Bundan alçak ve zemin hizasındaki geometri ALICI sayılır (kaldırım üstü 0,02; bordür 0,022).
const FLAT_HEIGHT: float = 0.04
const GROUND_TOP: float = 0.035
## Gölgenin zemindeki rengi (ortam ışığının mavimsi tonu) ve gücü: zeminin rengini çarpan değer. GL Compatibility'de
## ALBEDO sRGB uzayındadır (motor ışıklandırmadan önce doğrusala çevirir), yani bu, ekrandaki rengin çarpanıdır.
const TINT: Color = Color(0.32, 0.37, 0.54, 1.0)
## Değişiklikten sonra yeniden pişirme beklemesi (art arda gelen değişiklikler tek pişirmede birleşir).
const REBAKE_DELAY: float = 0.25
## Garaj bölge pişirmesinde parselin çevresine pay (duvarlar, kenardaki eşyalar) ve dökücülerin en üst yüksekliği (dünya).
const GARAGE_MARGIN: float = 0.35
const REGION_TOP: float = 1.4
## DİSK ÖNBELLEĞİ: harita, onu belirleyen oyun durumunun (dekor, duvarlar, garaj seviyeleri, tamir alanları, güneş, boyut,
## sürüm) özetiyle birlikte saklanır; açılışta durum aynıysa yeniden çizilmez (açılışta pişirme ~0,1 sn sürüyordu —
## masaüstü, ilk shader derlemesi dahil; telefonda birkaç katı). Ziyaret / düzenleme sonrası pişirme önbelleği tazeler.
const CACHE_PATH: String = "user://world_shadow.bin"
const CACHE_VERSION: int = 2
const CACHE_SAVE_DELAY: float = 2.0
## Showroom binasının (tek mesh) zemin yüzeyleri — tools/world/showroom.py materyal adları (GLB'de "SR_" önekli).
const SHOWROOM_GROUND: PackedStringArray = ["paver", "asphalt", "line", "lawn"]
## Haritaya girmeyen alt ağaçlar (sahne kökünün çocukları): trafik araçları hareket eder; ön ısıtma düğümleri zeminin
## altında birkaç kare durur (pişirmeye girse gölgeleri zemine izdüşerdi).
const DYNAMIC_ROOTS: PackedStringArray = ["Traffic", "HUD", "WorldPrewarm"]
## Bu gruptaki düğümler (ve altları) haritaya girmez: kendi gölgesini taşıyanlar (CarShadow sahipleri) ve geçici
## efektler. Geçici efekt sınıfları ayrıca türünden tanınır (_is_transient).
const DYNAMIC_GROUP: StringName = &"world_shadow_dynamic"
## Bundan alçakta kalan (zemin altı) geometri gölge düşürmez.
const UNDERGROUND: float = -0.2

const GROUND_SHADER: Shader = preload("res://vfx/world_ground.gdshader")
const MARKING_SHADER: Shader = preload("res://vfx/world_ground_marking.gdshader")
const RECEIVER_SHADERS: Array[Shader] = [
	preload("res://vfx/world_ground.gdshader"), preload("res://vfx/world_ground_marking.gdshader"),
	preload("res://vfx/grass.gdshader"), preload("res://vfx/floor_tiles.gdshader"),
]

var _texture: ImageTexture
var _param_u: Vector4 = Vector4.ZERO
var _param_v: Vector4 = Vector4.ZERO
var _converted: Dictionary = {}   # kaynak StandardMaterial3D (ya da null) → ShaderMaterial
var _receivers: Array[ShaderMaterial] = []
var _baking: bool = false
var _pending: bool = false
var _timer: SceneTreeTimer
## Sıradaki pişirmenin kapsamı: bütün harita mı, yoksa yalnız bir bölge mi (dünya XZ; dekor değişikliği garajı etkiler).
var _want_full: bool = true
var _want_region: Rect2 = Rect2()
## Haritanın CPU kopyası (bölge pişirmesi üstüne yapıştırılır) — R8, MAP_SIZE².
var _image: Image
## Diske yazılacak önbellek özeti (yazma ertelenir: düzenleyicide her bırakışta 1 MB yazılmasın).
var _unsaved_signature: String = ""
var _save_timer: SceneTreeTimer
var _cast_material: StandardMaterial3D
var _skip_material: StandardMaterial3D
## Son pişirmenin ölçümleri (QA): döküler, alıcılar, süre (ms).
var last_stats: Dictionary = {}
## QA: doluysa ham pişirme görüntüsü bu klasöre yazılır, biçim / süre basılır.
static var debug_dir: String = ""
## Gölgenin gücü (0 = kapalı; QA karşılaştırması).
var strength: float = 1.0:
	set(value):
		strength = value
		for material: ShaderMaterial in _receivers:
			material.set_shader_parameter("world_shadow_tint", tint_value())
		for node: Node in get_tree().get_nodes_in_group(CarShadow.GROUP):
			(node as CarShadow).apply_tint(tint_value())


## Son pişirilen harita (QA).
func texture() -> Texture2D:
	return _texture


func _ready() -> void:
	name = "WorldShadow"
	add_to_group(GROUP)
	_cast_material = StandardMaterial3D.new()
	_cast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cast_material.albedo_color = Color.WHITE
	_cast_material.cull_mode = BaseMaterial3D.CULL_DISABLED   # ince levhalar (tabela, çit) güneşe arkasını dönse de gölge düşürür
	_skip_material = StandardMaterial3D.new()
	_skip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_skip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_skip_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	_connect_sources.call_deferred()
	request_bake(0.0)


## Haritayı (kısa bir beklemeyle) yeniden pişir. Art arda çağrılar tek pişirmede birleşir. `region` (dünya XZ) verilirse
## yalnız o bölgedeki dökücülerin izdüşümü yeniden çizilir (dekor düzenlemesi: masaüstünde ~20 ms → birkaç ms, geri okunan
## görüntü ~16 kat küçük); boşsa bütün harita.
func request_bake(delay: float = REBAKE_DELAY, region: Rect2 = Rect2()) -> void:
	if region.has_area():
		_want_region = region if not _want_region.has_area() else _want_region.merge(region)
	else:
		_want_full = true
	if _baking:
		_pending = true
		return
	if _timer != null:
		return
	_timer = get_tree().create_timer(delay)
	_timer.timeout.connect(func() -> void:
		_timer = null
		var full: bool = _want_full or _image == null
		var area: Rect2 = _want_region
		_want_full = false
		_want_region = Rect2()
		if full:
			_bake()
		else:
			_bake_region(area))


## Garajın dekor / tamir alanı değişikliği: yalnız garaj parselinin (duvarlar dahil) çevresi yeniden pişer.
func _request_garage_bake() -> void:
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if view == null:
		request_bake()
		return
	request_bake(REBAKE_DELAY, view.lot_rect().grow(GARAGE_MARGIN))


func _connect_sources() -> void:
	var decor: Node = get_tree().get_first_node_in_group("decor")
	if decor and decor.has_signal("placement_changed"):
		decor.connect("placement_changed", _request_garage_bake)
	var view: Node = get_tree().get_first_node_in_group("garage_decor_view")
	if view and view.has_signal("area_changed"):
		view.connect("area_changed", _request_garage_bake)
	var bays: Node = get_tree().get_first_node_in_group("repair_bays")   # tamir alanı açıldı / taşındı (lift)
	for source_signal: String in ["bays_changed", "layout_changed"]:
		if bays and bays.has_signal(source_signal):
			bays.connect(source_signal, _request_garage_bake)
	var garage: Node = get_tree().get_first_node_in_group("garage_system")
	if garage and garage.has_signal("level_changed"):
		garage.connect("level_changed", func(_level: int) -> void: request_bake())


# --- Pişirme ---------------------------------------------------------------------------------------

func _bake() -> void:
	var scene: Node = get_tree().current_scene
	var sun: DirectionalLight3D = _find_sun(scene)
	if scene == null or sun == null or not is_inside_tree():
		return
	_baking = true
	var started: int = Time.get_ticks_usec()
	var world: World3D = get_viewport().get_world_3d()
	var map_size: int = MAP_SIZE if GameSettings.shadows_enabled() else LOW_MAP_SIZE
	var msaa: bool = GameSettings.msaa_supported()
	var bake_size: int = map_size if msaa else map_size * 2

	var casters: Array[GeometryInstance3D] = []
	var receivers: Array[GeometryInstance3D] = []
	_classify(scene, world, casters, receivers)
	var t_classify: int = Time.get_ticks_usec()
	if debug_dir != "":
		var roots: Dictionary = {}
		for gi: GeometryInstance3D in casters:
			var parts: PackedStringArray = str(scene.get_path_to(gi)).split("/")
			var key: String = "/".join(parts.slice(0, mini(3, parts.size() - 1)))
			roots[key] = int(roots.get(key, 0)) + 1
		print("WorldShadow dökücüler: ", roots)

	var to_sun: Vector3 = sun.global_transform.basis.z.normalized()
	var signature: String = _signature(to_sun, map_size)
	if _load_cache(signature, map_size):
		_apply_receivers(receivers)
		last_stats = {"casters": casters.size(), "receivers": receivers.size(), "materials": _receivers.size(),
			"ms": (Time.get_ticks_usec() - started) / 1000.0, "cached": true, "size": map_size}
		_finish_bake()
		return
	var basis: Basis = Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	var right: Vector3 = basis.x
	var up: Vector3 = basis.y
	var top: float = 0.2
	for gi: GeometryInstance3D in casters:
		top = maxf(top, _world_aabb(gi).end.y)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for corner: int in 8:
		var p: Vector3 = Vector3(AREA_MIN.x if corner & 1 == 0 else AREA_MAX.x, -0.15 if corner & 2 == 0 else top,
			AREA_MIN.y if corner & 4 == 0 else AREA_MAX.y)
		var q: Vector2 = Vector2(p.dot(right), p.dot(up))
		lo = lo.min(q)
		hi = hi.max(q)
	var extent: float = maxf(hi.x - lo.x, hi.y - lo.y)
	var center: Vector2 = (lo + hi) * 0.5

	var viewport: SubViewport = _bake_viewport(Vector2i(bake_size, bake_size), msaa, extent,
		Transform3D(basis, right * center.x + up * center.y + to_sun * 100.0), casters)
	var t_build: int = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var t_draw: int = Time.get_ticks_usec()
	var image: Image = viewport.get_texture().get_image() if is_instance_valid(viewport) else null
	var t_read: int = Time.get_ticks_usec()
	if is_instance_valid(viewport):
		viewport.queue_free()
	if image == null or image.is_empty():
		_finish_bake()
		return
	if debug_dir != "":
		print("WorldShadow süreler (ms): sınıflama %.1f kopya %.1f kare %.1f geri okuma %.1f" % [
			(t_classify - started) / 1000.0, (t_build - t_classify) / 1000.0, (t_draw - t_build) / 1000.0,
			(t_read - t_draw) / 1000.0])
		image.save_png(debug_dir + "_ham.png")
	var t_conv: int = Time.get_ticks_usec()
	image.convert(Image.FORMAT_R8)
	if image.get_width() != map_size:
		image.resize(map_size, map_size, Image.INTERPOLATE_BILINEAR)
	if debug_dir != "":
		print("WorldShadow süreler (ms): küçültme %.1f" % ((Time.get_ticks_usec() - t_conv) / 1000.0))
	_image = image
	if _texture != null and _texture.get_width() == map_size:
		_texture.update(image)
	else:
		_texture = ImageTexture.create_from_image(image)
	_param_u = Vector4(right.x / extent, right.y / extent, right.z / extent, 0.5 - center.x / extent)
	_param_v = Vector4(-up.x / extent, -up.y / extent, -up.z / extent, 0.5 + center.y / extent)
	_apply_receivers(receivers)
	_queue_save(signature)
	last_stats = {"casters": casters.size(), "receivers": receivers.size(), "materials": _receivers.size(),
		"ms": (Time.get_ticks_usec() - started) / 1000.0, "extent": extent, "size": map_size,
		"work_ms": (t_build - started + Time.get_ticks_usec() - t_draw) / 1000.0}
	_finish_bake()


## Bölge pişirmesi: haritanın yalnız `area`nın (dünya XZ, zeminden REGION_TOP'a) izdüşümünü kapsayan piksel dikdörtgeni
## yeniden çizilip CPU kopyasına yapıştırılır; o dikdörtgene izdüşen bütün dökücüler (bölge dışındakiler dahil) çizime girer.
## İzdüşüm haritanın kendi parametrelerinden (önbellekten yüklenmiş olsa da aynı); güneş değiştiyse bütün harita.
func _bake_region(area: Rect2) -> void:
	var scene: Node = get_tree().current_scene
	var sun: DirectionalLight3D = _find_sun(scene)
	if scene == null or sun == null or not is_inside_tree() or _image == null:
		return
	var to_sun: Vector3 = sun.global_transform.basis.z.normalized()
	var axis_u: Vector3 = Vector3(_param_u.x, _param_u.y, _param_u.z)
	var extent: float = 1.0 / maxf(axis_u.length(), 1e-6)
	var right: Vector3 = axis_u * extent
	var up: Vector3 = -Vector3(_param_v.x, _param_v.y, _param_v.z) * extent
	var map_size: int = _image.get_width()
	if absf(right.dot(to_sun)) > 0.001 or absf(up.dot(to_sun)) > 0.001 \
			or map_size != (MAP_SIZE if GameSettings.shadows_enabled() else LOW_MAP_SIZE):
		_bake()
		return
	_baking = true
	var started: int = Time.get_ticks_usec()
	var center: Vector2 = Vector2((0.5 - _param_u.w) * extent, (_param_v.w - 0.5) * extent)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for corner: int in 8:
		var p: Vector3 = Vector3(area.position.x if corner & 1 == 0 else area.end.x, -0.15 if corner & 2 == 0 else REGION_TOP,
			area.position.y if corner & 4 == 0 else area.end.y)
		var pixel: Vector2 = _to_pixel(p, right, up, center, extent, map_size)
		lo = lo.min(pixel)
		hi = hi.max(pixel)
	var rect: Rect2i = Rect2i(Vector2i(floori(lo.x) - 2, floori(lo.y) - 2), Vector2i.ZERO)
	rect.end = Vector2i(ceili(hi.x) + 2, ceili(hi.y) + 2)
	rect = rect.intersection(Rect2i(0, 0, map_size, map_size))
	var world: World3D = get_viewport().get_world_3d()
	var casters: Array[GeometryInstance3D] = []
	var receivers: Array[GeometryInstance3D] = []
	_classify(scene, world, casters, receivers)
	_apply_receivers(receivers)   # yeniden kurulan garaj zemini de gölge değerlerini alsın
	if rect.size.x < 4 or rect.size.y < 4:
		_finish_bake()
		return
	var touching: Array[GeometryInstance3D] = []
	var rect_f: Rect2 = Rect2(rect)
	for gi: GeometryInstance3D in casters:
		var box: AABB = _world_aabb(gi)
		var b_lo: Vector2 = Vector2(INF, INF)
		var b_hi: Vector2 = Vector2(-INF, -INF)
		for corner: int in 8:
			var pixel: Vector2 = _to_pixel(box.get_endpoint(corner), right, up, center, extent, map_size)
			b_lo = b_lo.min(pixel)
			b_hi = b_hi.max(pixel)
		if rect_f.intersects(Rect2(b_lo, b_hi - b_lo), true):
			touching.append(gi)
	var msaa: bool = GameSettings.msaa_supported()
	var mult: int = 1 if msaa else 2
	var u0: float = (rect.position.x / float(map_size) - 0.5) * extent + center.x
	var u1: float = (rect.end.x / float(map_size) - 0.5) * extent + center.x
	var v0: float = center.y + (0.5 - rect.position.y / float(map_size)) * extent
	var v1: float = center.y + (0.5 - rect.end.y / float(map_size)) * extent
	var viewport: SubViewport = _bake_viewport(rect.size * mult, msaa, v0 - v1,
		Transform3D(Basis(right, up, to_sun), right * (u0 + u1) * 0.5 + up * (v0 + v1) * 0.5 + to_sun * 100.0), touching)
	var t_build: int = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var t_draw: int = Time.get_ticks_usec()
	var image: Image = viewport.get_texture().get_image() if is_instance_valid(viewport) else null
	if is_instance_valid(viewport):
		viewport.queue_free()
	if image == null or image.is_empty() or _image == null:
		_finish_bake()
		return
	image.convert(Image.FORMAT_R8)
	if mult != 1:
		image.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_BILINEAR)
	_image.blit_rect(image, Rect2i(Vector2i.ZERO, rect.size), rect.position)
	_texture.update(_image)
	_queue_save(_signature(to_sun, map_size))
	# "iş": ana iş parçacığının kendi süresi (bekleme karesi hariç)
	last_stats = {"casters": touching.size(), "receivers": receivers.size(), "materials": _receivers.size(),
		"ms": (Time.get_ticks_usec() - started) / 1000.0, "region": rect, "size": map_size,
		"work_ms": (t_build - started + Time.get_ticks_usec() - t_draw) / 1000.0}
	_finish_bake()


func _to_pixel(p: Vector3, right: Vector3, up: Vector3, center: Vector2, extent: float, map_size: int) -> Vector2:
	return Vector2((p.dot(right) - center.x) / extent + 0.5, 0.5 - (p.dot(up) - center.y) / extent) * map_size


## Pişirme görüntüsü: ayrı dünyada, güneş yönünden dik izdüşümle bakan kamera ve dökücülerin beyaz kopyaları.
## Bir kez çizilir (UPDATE_ONCE); çağıran frame_post_draw'dan sonra görüntüyü alıp düğümü siler.
func _bake_viewport(size: Vector2i, msaa: bool, height: float, view: Transform3D,
		casters: Array[GeometryInstance3D]) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "ShadowBake"
	viewport.size = size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X if msaa else Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = height
	camera.near = 1.0
	camera.far = 200.0
	var environment: Environment = Environment.new()   # ortamsız dünya ışığı başka görüntülerden sızdırır (Compatibility)
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	camera.environment = environment
	camera.transform = view
	viewport.add_child(camera)
	for gi: GeometryInstance3D in casters:
		var copy: GeometryInstance3D = _caster_copy(gi)
		if copy:
			viewport.add_child(copy)
	add_child(viewport)
	camera.make_current()
	return viewport


func _finish_bake() -> void:
	_baking = false
	if _pending:
		_pending = false
		request_bake()


# --- Disk önbelleği ---------------------------------------------------------------------------------

## Haritayı belirleyen durumun özeti. Dökücülerin kendisi değil (araçlar birleşince düğümler değişir, görüntü değişmez),
## onları kuran oyun durumu: dekor örnekleri + duvarlar, garaj seviyeleri, tamir alanları ve yerleşimleri.
func _signature(to_sun: Vector3, map_size: int) -> String:
	var tree: SceneTree = get_tree()
	var parts: Array = [CACHE_VERSION, ProjectSettings.get_setting("application/config/version", ""), map_size,
		to_sun.snapped(Vector3.ONE * 0.0001)]
	var decor: Node = tree.get_first_node_in_group("decor")
	if decor and decor.has_method("instances") and decor.has_method("walls"):
		parts.append(decor.call("instances"))
		parts.append(decor.call("walls"))
	var upgrades: Node = tree.get_first_node_in_group("garage_upgrades")
	if upgrades and upgrades.has_method("levels"):
		parts.append(upgrades.call("levels"))
	var bays: Node = tree.get_first_node_in_group("repair_bays")
	if bays and bays.has_method("state") and bays.has_method("layout_state"):
		parts.append(bays.call("state"))
		parts.append(bays.call("layout_state"))
	return var_to_str(parts).md5_text()


func _load_cache(signature: String, map_size: int) -> bool:
	if debug_dir != "" or not FileAccess.file_exists(CACHE_PATH):
		return false
	var file: FileAccess = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null or file.get_pascal_string() != signature or int(file.get_32()) != map_size:
		return false
	var u: Vector4 = Vector4(file.get_float(), file.get_float(), file.get_float(), file.get_float())
	var v: Vector4 = Vector4(file.get_float(), file.get_float(), file.get_float(), file.get_float())
	var data: PackedByteArray = file.get_buffer(map_size * map_size)
	if data.size() != map_size * map_size:
		return false
	var image: Image = Image.create_from_data(map_size, map_size, false, Image.FORMAT_R8, data)
	_image = image
	if _texture != null and _texture.get_width() == map_size:
		_texture.update(image)
	else:
		_texture = ImageTexture.create_from_image(image)
	_param_u = u
	_param_v = v
	return true


## Önbelleği kısa bir beklemeyle yazar (art arda pişirmeler tek yazmada birleşir); uygulama arka plana geçerken /
## kapanırken bekleyen yazma hemen yapılır.
func _queue_save(signature: String) -> void:
	_unsaved_signature = signature
	if _save_timer != null or not is_inside_tree():
		return
	_save_timer = get_tree().create_timer(CACHE_SAVE_DELAY)
	_save_timer.timeout.connect(func() -> void:
		_save_timer = null
		_flush_cache())


func _flush_cache() -> void:
	if _unsaved_signature != "" and _image != null:
		_save_cache(_unsaved_signature, _image)
	_unsaved_signature = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_flush_cache()


func _save_cache(signature: String, image: Image) -> void:
	var file: FileAccess = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_pascal_string(signature)
	file.store_32(image.get_width())
	for value: float in [_param_u.x, _param_u.y, _param_u.z, _param_u.w, _param_v.x, _param_v.y, _param_v.z, _param_v.w]:
		file.store_float(value)
	file.store_buffer(image.get_data())


## Pişirme dünyasına girecek kopya: aynı mesh, beyaz düz materyal. Showroom'un zemin yüzeyleri görünmez kalır.
func _caster_copy(gi: GeometryInstance3D) -> GeometryInstance3D:
	var copy: GeometryInstance3D = null
	if gi is MultiMeshInstance3D:
		var multi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		multi.multimesh = (gi as MultiMeshInstance3D).multimesh
		multi.material_override = _cast_material
		copy = multi
	elif gi is MeshInstance3D:
		var source: MeshInstance3D = gi as MeshInstance3D
		var mesh_copy: MeshInstance3D = MeshInstance3D.new()
		mesh_copy.mesh = source.mesh
		var mixed: bool = source.has_meta(META)
		for s: int in source.mesh.get_surface_count():
			var hide: bool = mixed and (source.get_meta(META) as PackedInt32Array).has(s)
			mesh_copy.set_surface_override_material(s, _skip_material if hide else _cast_material)
		copy = mesh_copy
	elif gi is CSGShape3D:
		var meshes: Array = (gi as CSGShape3D).get_meshes()
		if meshes.size() < 2 or meshes[1] == null:
			return null
		var csg_copy: MeshInstance3D = MeshInstance3D.new()
		csg_copy.mesh = meshes[1]
		csg_copy.material_override = _cast_material
		csg_copy.transform = gi.global_transform * (meshes[0] as Transform3D)
		return csg_copy
	if copy:
		copy.transform = gi.global_transform
	return copy


# --- Sınıflandırma -----------------------------------------------------------------------------------

func _classify(scene: Node, world: World3D, casters: Array[GeometryInstance3D],
		receivers: Array[GeometryInstance3D]) -> void:
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != scene and (node.is_in_group(DYNAMIC_GROUP) or _is_transient(node) \
				or (node.get_parent() == scene and String(node.name) in DYNAMIC_ROOTS)):
			continue
		if node is Node3D and not (node as Node3D).visible:
			continue
		if node is Viewport or node is CanvasLayer:
			continue
		stack.append_array(node.get_children())
		var gi: GeometryInstance3D = node as GeometryInstance3D
		if gi == null or gi is Label3D or gi is SpriteBase3D or gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		if gi.get_world_3d() != world or not _has_geometry(gi) or gi.layers == 0:
			continue   # layers 0: çizilmiyor (ör. dekorun toplu çizime devredilmiş asıl parçaları)
		if gi is CSGShape3D and not (gi as CSGShape3D).is_root_shape():
			continue
		var box: AABB = _world_aabb(gi)
		if box.size.y < FLAT_HEIGHT and box.end.y < GROUND_TOP and not _inside_object(gi, scene):
			receivers.append(gi)
			continue
		if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or _is_effect(gi) or box.end.y < UNDERGROUND:
			continue
		if gi is MeshInstance3D and _mark_mixed(gi as MeshInstance3D):
			receivers.append(gi)
		casters.append(gi)


## Gelip giden sahne parçaları: kasalar (kendi gölgeleriyle), tamir / açılış / restorasyon efektleri.
func _is_transient(node: Node) -> bool:
	return node is CrateDelivery or node is RepairFx or node is CrateRevealFx or node is RestorationFinale


## Dekor eşyasının / garaj kurgusunun alçak parçası (dolap tablası, lift rayı) zemin değil, nesnenin parçasıdır.
func _inside_object(gi: GeometryInstance3D, scene: Node) -> bool:
	var node: Node = gi.get_parent()
	while node != null and node != scene:
		if node.name == &"DecorBodies" or node.name == &"PlacedObjects":
			return true
		node = node.get_parent()
	return false


## Showroom binası tek mesh: zemin yüzeylerinin indeksleri işaretlenir (pişirmede gizli, alıcı olarak gölgeli).
func _mark_mixed(mi: MeshInstance3D) -> bool:
	if mi.material_override != null or mi.mesh.get_surface_count() < 2:
		return false
	var ground: PackedInt32Array = []
	for s: int in mi.mesh.get_surface_count():
		if is_showroom_ground(mi.mesh.surface_get_material(s)):
			ground.append(s)
	if ground.is_empty():
		return false
	mi.set_meta(META, ground)
	return true


## Showroom'un otopark / kaldırım / çizgi / çim yüzeyi mi (gölge alır, haritaya çizilmez).
static func is_showroom_ground(material: Material) -> bool:
	return material != null and material.resource_name.to_lower().trim_prefix("sr_") in SHOWROOM_GROUND


func _is_effect(gi: GeometryInstance3D) -> bool:
	var material: BaseMaterial3D = gi.material_override as BaseMaterial3D
	return material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			and material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR


func _has_geometry(gi: GeometryInstance3D) -> bool:
	if gi is MeshInstance3D:
		return (gi as MeshInstance3D).mesh != null and (gi as MeshInstance3D).mesh.get_surface_count() > 0
	if gi is MultiMeshInstance3D:
		var multi: MultiMesh = (gi as MultiMeshInstance3D).multimesh
		return multi != null and multi.mesh != null and multi.instance_count > 0 and multi.visible_instance_count != 0
	return gi is CSGShape3D


func _world_aabb(gi: GeometryInstance3D) -> AABB:
	if gi is MultiMeshInstance3D:
		return gi.global_transform * (gi as MultiMeshInstance3D).multimesh.get_aabb()
	return gi.global_transform * gi.get_aabb()


func _find_sun(scene: Node) -> DirectionalLight3D:
	if scene == null:
		return null
	var sun: DirectionalLight3D = scene.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		return sun
	for node: Node in scene.find_children("*", "DirectionalLight3D", true, false):
		if (node as DirectionalLight3D).get_world_3d() == get_viewport().get_world_3d():
			return node as DirectionalLight3D
	return null


# --- Alıcılar ---------------------------------------------------------------------------------------

func _apply_receivers(receivers: Array[GeometryInstance3D]) -> void:
	_receivers.clear()
	for gi: GeometryInstance3D in receivers:
		if gi.material_override != null or not gi is MeshInstance3D:
			var material: Material = gi.material_override
			if material == null and gi is MultiMeshInstance3D:
				var mesh: Mesh = (gi as MultiMeshInstance3D).multimesh.mesh
				if mesh.get_surface_count() != 1:
					continue
				material = mesh.surface_get_material(0)
			elif material == null and gi is CSGShape3D:
				material = gi.get("material") as Material
				var csg_mesh: Mesh = gi.get("mesh") as Mesh   # CSGMesh3D: materyal verilmemişse mesh'inki
				if material == null and csg_mesh != null and csg_mesh.get_surface_count() > 0:
					material = csg_mesh.surface_get_material(0)
			var receiving: ShaderMaterial = _receiving(material)
			if receiving:
				gi.material_override = receiving
				_track(receiving)
			continue
		var mi: MeshInstance3D = gi as MeshInstance3D
		var only: PackedInt32Array = mi.get_meta(META, PackedInt32Array()) as PackedInt32Array
		for s: int in mi.mesh.get_surface_count():
			if not only.is_empty() and not only.has(s):
				continue
			var receiving: ShaderMaterial = _receiving(mi.get_active_material(s))
			if receiving:
				if mi.get_active_material(s) != receiving:
					mi.set_surface_override_material(s, receiving)
				_track(receiving)
	for material: ShaderMaterial in _receivers:
		material.set_shader_parameter("world_shadow_map", _texture)
		material.set_shader_parameter("world_shadow_u", _param_u)
		material.set_shader_parameter("world_shadow_v", _param_v)
		material.set_shader_parameter("world_shadow_tint", tint_value())


## Gölge rengi + güç, shader'lar için.
func tint_value() -> Vector4:
	var value: Vector4 = default_tint()
	value.w *= strength
	return value


static func default_tint() -> Vector4:
	return Vector4(TINT.r, TINT.g, TINT.b, TINT.a)


func _track(material: ShaderMaterial) -> void:
	if not _receivers.has(material):
		_receivers.append(material)


## Zemin materyalinin gölge alan karşılığı: gölge okuyan shader'lar olduğu gibi, düz StandardMaterial3D'ler aynı
## görünümdeki world_ground(_marking).gdshader'a çevrilir (kaynak başına bir kez). Çevrilemeyen (saydam, ışıksız,
## köşe rengi / normal haritalı) materyal gölgesiz kalır.
func _receiving(material: Material) -> ShaderMaterial:
	if material is ShaderMaterial:
		return material as ShaderMaterial if (material as ShaderMaterial).shader in RECEIVER_SHADERS else null
	if _converted.has(material):
		return _converted[material]
	var made: ShaderMaterial = null
	if material == null:
		# Materyalsiz yüzey motorun varsayılanıyla çizilir (GLES3: albedo 0,6, pürüz 0,8, metal 0,2).
		made = ShaderMaterial.new()
		made.shader = GROUND_SHADER
		made.set_shader_parameter("albedo", Color(0.6, 0.6, 0.6))
		made.set_shader_parameter("roughness", 0.8)
		made.set_shader_parameter("metallic", 0.2)
	elif material is StandardMaterial3D:
		made = _convert(material as StandardMaterial3D)
	_converted[material] = made
	return made


func _convert(source: StandardMaterial3D) -> ShaderMaterial:
	if source.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or source.vertex_color_use_as_albedo \
			or source.normal_enabled or source.emission_enabled or source.uv1_triplanar or source.next_pass != null:
		return null
	var scissor: bool = source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and not scissor:
		return null
	if scissor != (source.cull_mode == BaseMaterial3D.CULL_DISABLED) or (not scissor and source.cull_mode != BaseMaterial3D.CULL_BACK):
		return null   # iki shader: opak + arka yüz ayıklamalı, kesik + çift yüzlü
	var made: ShaderMaterial = ShaderMaterial.new()
	made.shader = MARKING_SHADER if scissor else GROUND_SHADER
	made.set_shader_parameter("albedo", source.albedo_color)
	if source.albedo_texture:
		made.set_shader_parameter("albedo_texture", source.albedo_texture)
	made.set_shader_parameter("uv1_scale", source.uv1_scale)
	made.set_shader_parameter("uv1_offset", source.uv1_offset)
	made.set_shader_parameter("roughness", source.roughness)
	made.set_shader_parameter("metallic", source.metallic)
	made.set_shader_parameter("specular", source.metallic_specular)
	if scissor:
		made.set_shader_parameter("alpha_scissor_threshold", source.alpha_scissor_threshold)
	made.render_priority = source.render_priority
	return made
