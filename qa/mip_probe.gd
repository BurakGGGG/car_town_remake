extends SceneTree
## ARAÇ DOKUSU MIP ÖLÇÜMÜ: oyundaki en yakın kadrajlarda araç pikselleri dokunun hangi mip
## seviyesinden okunuyor ve 2048² yerine 1536² / 1024² doku ekranda ne kadar fark ediyor.
##
## Telefonu birebir taklit eder: pencere 2400x1080 + content_scale_factor 1,35 (scale.mobile) →
## tuval 1067x480; garaj / showroom SubViewport'u da telefondaki gibi 1067x480 çizilir, şehir tam
## çözünürlükte. Masaüstü ekranı 2400 genişliği almadığı için Xephyr içinde çalıştırılır:
##   Xephyr :7 -screen 2400x1080x24 -ac -br -noreset -nolisten tcp &
##   DISPLAY=:7 CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/mip_probe.gd --display-driver x11 \
##     --resolution 2400x1080 --position 0,0 -- [araç_id ...]
##
## Çıktı: her kadraj için LOD dağılımı (lod < 0: büyütülüyor, 0–1: mip 0 karışıyor, ≥ 1: mip 0 hiç
## okunmuyor → 1024² ile AYNI piksel) ve 2048 / 1536 / 1024 PSNR'ı; görüntüler OUT altına.
## Çeşitler içe aktarma ayarından bağımsız olarak kaynak JPEG'den (2048²) üretilir: içe aktarıcının
## size_limit süzgeci (kübik) + ETC2. "gürültü" aynı karenin tekrarıdır; garajda canlı bir öğe kareler
## arasında değiştiği için oradaki PSNR anlamsız, LOD dağılımı geçerlidir.
## 2026-10-17 sonucu (docs/MESH_BUTCESI.md "Paket boyutu 2"): araç dokuları 1024²'ye indirildi.
const OUT: String = "/home/burak/Projects/ct_shots/mip_probe/"
const SIZES: Array[int] = [2048, 1536, 1024]
const LOD_SHADER: String = """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
uniform float tex_size = 2048.0;
void fragment() {
	vec2 t = UV * tex_size;
	vec2 dx = dFdx(t);
	vec2 dy = dFdy(t);
	float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-10));
	// Ayrık bant renkleri: 0/1 kanallar sRGB dönüşümünden etkilenmez
	vec3 c = vec3(1.0, 0.0, 0.0);                 // ≥ 2
	if (lod < 2.0) c = vec3(1.0, 1.0, 0.0);       // 1–2
	if (lod < 1.0) c = vec3(0.0, 1.0, 1.0);       // 0,415–1
	if (lod < 0.415) c = vec3(0.0, 0.0, 1.0);     // 0–0,415
	if (lod < 0.0) c = vec3(1.0, 0.0, 1.0);       // büyütme
	ALBEDO = c;
}
"""

var _lod_material: ShaderMaterial
var _variants: Dictionary = {}   # doku yolu → {boyut: Texture2D}
var _cars: PackedStringArray = []
var _report: PackedStringArray = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_factor = 1.35
	var shader: Shader = Shader.new()
	shader.code = LOD_SHADER
	_lod_material = ShaderMaterial.new()
	_lod_material.shader = shader
	_cars = OS.get_cmdline_user_args()
	if _cars.is_empty():
		_cars = PackedStringArray(["tofas_sahin", "lambo_huracan", "mercedes_w123", "hyundai_getz"])
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(240)
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	for id: String in _cars:
		own.add_vehicle(StringName(id))
	await _frames(10)
	var hud: Node = _find(current_scene, "HUD")
	var router: Node = hud.get("router")
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera

	# 1) Şehir: trafikteki araçlar, oyuncunun yakınlaşma sınırında ve kasa açılışının yakın çekiminde
	var traffic: Node = get_first_node_in_group("traffic")
	traffic.process_mode = Node.PROCESS_MODE_DISABLED   # araçlar kareler arasında yer değiştirmesin
	for zoom: float in [camera.min_zoom, 1.35]:
		var car: Node3D = _nearest_traffic(camera)
		if car == null:
			_report.append("şehir: trafik aracı yok")
			break
		camera.follow(car.global_position, zoom)
		await _frames(120)
		camera.set_process(false)
		await _capture("sehir_zoom_%.2f" % zoom, root)
		camera.set_process(true)
	traffic.process_mode = Node.PROCESS_MODE_INHERIT

	# 2) Showroom: açılış ve en yakın zoom, iki açı
	router.call("open", &"showroom")
	await _frames(30)
	var showroom: Node = router.call("screen", &"showroom")
	for id: String in _cars:
		showroom.call("_show_vehicle", StringName(id))
		await _frames(120)
		for zoom: float in [1.0, ShowroomScreen.ZOOM_MIN]:
			for yaw: float in [-38.0, -90.0]:
				showroom.set_process(false)
				(showroom.get("_display_root") as Node3D).rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
				showroom.set("_zoom", zoom)
				showroom.set("_zoom_target", zoom)
				showroom.call("_apply_camera")
				var vp: SubViewport = showroom.get("_viewport")
				await _capture("showroom_%s_z%.2f_y%d" % [id, zoom, int(yaw)], vp)
	router.call("close_all")
	await _frames(30)

	# 3) Garaj: liftteki araç
	router.call("open", &"garage")
	await _frames(40)
	var garage: Node = router.call("screen", &"garage")
	for id: String in _cars:
		garage.call("_show_vehicle", StringName(id), false)
		await _frames(120)
		var vp: SubViewport = _first_subviewport(garage)
		await _capture("garaj_%s" % id, vp)

	print("\n=== MIP ÖLÇÜMÜ (lod: 2048² dokuda; <0 büyütme, ≥1 → 1024² ile aynı; gürültü = aynı karenin tekrarı) ===")
	for line: String in _report:
		print(line)
	quit()


func _nearest_traffic(camera: Camera3D) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for v: Node in get_first_node_in_group("traffic").find_children("*", "Node3D", true, false):
		var n: Node3D = v as Node3D
		if not (n is TrafficVehicle) or not n.is_visible_in_tree():
			continue
		var d: float = n.global_position.distance_to(camera.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _first_subviewport(node: Node) -> SubViewport:
	for c: Node in node.find_children("*", "SubViewport", true, false):
		return c as SubViewport
	return null


## Kadrajdaki tüm araç materyalleri (doku yolu _car_albedo içeren).
func _car_instances(scope: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in scope.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s: int in mi.mesh.get_surface_count():
			if _albedo_path(mi.get_active_material(s)) != "":
				out.append(mi)
				break
	return out


func _albedo_path(m: Material) -> String:
	if m != null and m.has_meta(&"probe_src"):
		return m.get_meta(&"probe_src")
	if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture:
		var p: String = (m as BaseMaterial3D).albedo_texture.resource_path
		return p if p.contains("_car_albedo") else ""
	if m is ShaderMaterial:
		for u: Dictionary in (m as ShaderMaterial).shader.get_shader_uniform_list():
			var v: Variant = (m as ShaderMaterial).get_shader_parameter(u["name"])
			if v is Texture2D and (v as Texture2D).resource_path.contains("_car_albedo"):
				return (v as Texture2D).resource_path
	return ""


func _variant(path: String, size: int) -> Texture2D:
	if not _variants.has(path):
		_variants[path] = {}
	var cache: Dictionary = _variants[path]
	if not cache.has(size):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		img.convert(Image.FORMAT_RGB8)
		if size < img.get_width():
			img.resize(size, size, Image.INTERPOLATE_CUBIC)   # içe aktarıcının size_limit süzgeci
		img.generate_mipmaps()
		img.compress(Image.COMPRESS_ETC2)
		cache[size] = ImageTexture.create_from_image(img)
	return cache[size]


func _set_variant(instances: Array[GeometryInstance3D], size: int) -> void:
	for gi: GeometryInstance3D in instances:
		var mi: MeshInstance3D = gi as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var p: String = _albedo_path(m)
			if p == "" and m != null and m.has_meta(&"probe_src"):
				p = m.get_meta(&"probe_src")
			if p == "":
				continue
			m.set_meta(&"probe_src", p)
			var tex: Texture2D = _variant(p, size)
			if m is BaseMaterial3D:
				(m as BaseMaterial3D).albedo_texture = tex
			elif m is ShaderMaterial:
				for u: Dictionary in (m as ShaderMaterial).shader.get_shader_uniform_list():
					var v: Variant = (m as ShaderMaterial).get_shader_parameter(u["name"])
					if v is Texture2D and ((v as Texture2D).resource_path == p or (v as Texture2D).resource_path == ""):
						(m as ShaderMaterial).set_shader_parameter(u["name"], tex)


func _grab(vp: Viewport) -> Image:
	await _frames(3)
	RenderingServer.force_draw()
	await _frames(1)
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Ortamın ton eşleme / ışıma / renk ayarı LOD kodunu bozmasın.
func _neutral_env(vp: Viewport, on: bool, saved: Array) -> void:
	var envs: Array[Environment] = []
	var cam: Camera3D = vp.get_camera_3d()
	if cam and cam.environment:
		envs.append(cam.environment)
	var w3d: World3D = vp.find_world_3d()
	if w3d and w3d.environment:
		envs.append(w3d.environment)
	for n: Node in (vp if vp != root else current_scene).find_children("*", "WorldEnvironment", true, false):
		if (n as WorldEnvironment).environment:
			envs.append((n as WorldEnvironment).environment)
	if on:
		for e: Environment in envs:
			saved.append([e, e.tonemap_mode, e.tonemap_exposure, e.glow_enabled, e.adjustment_enabled, e.fog_enabled])
			e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			e.tonemap_exposure = 1.0
			e.glow_enabled = false
			e.adjustment_enabled = false
			e.fog_enabled = false
	else:
		for s: Array in saved:
			var e: Environment = s[0]
			e.tonemap_mode = s[1]
			e.tonemap_exposure = s[2]
			e.glow_enabled = s[3]
			e.adjustment_enabled = s[4]
			e.fog_enabled = s[5]


func _capture(label: String, vp: Viewport) -> void:
	var scope: Node = vp if vp != root else current_scene
	var instances: Array[GeometryInstance3D] = _car_instances(scope)
	if instances.is_empty():
		_report.append("%-40s araç yok" % label)
		return
	# --- LOD görüntüsü
	var saved_override: Array[Material] = []
	for gi: GeometryInstance3D in instances:
		saved_override.append(gi.material_override)
		gi.material_override = _lod_material
	var saved_env: Array = []
	_neutral_env(vp, true, saved_env)
	var lod_img: Image = await _grab(vp)
	_neutral_env(vp, false, saved_env)
	for i: int in instances.size():
		instances[i].material_override = saved_override[i]
	var w: int = lod_img.get_width()
	var h: int = lod_img.get_height()
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w * h)
	var bins: Array[int] = [0, 0, 0, 0, 0]   # <0, 0–0.415, 0.415–1, 1–2, ≥2
	var count: int = 0
	var box: Rect2i = Rect2i()
	for y: int in h:
		for x: int in w:
			var c: Color = lod_img.get_pixel(x, y)
			var band: int = _band(c)
			if band < 0:
				continue
			mask[y * w + x] = 1
			count += 1
			box = Rect2i(x, y, 1, 1) if count == 1 else box.expand(Vector2i(x, y))
			bins[band] += 1
	if count == 0:
		_report.append("%-40s araç pikseli yok" % label)
		return
	lod_img.save_png(OUT + label + "_lod.png")
	# --- Doku çeşitleri
	var shots: Array[Image] = []
	for size: int in SIZES:
		_set_variant(instances, size)
		shots.append(await _grab(vp))
	_set_variant(instances, SIZES[0])
	var again: Image = await _grab(vp)
	var psnr: PackedStringArray = ["gürültü %.1f dB" % _psnr(shots[0], again, mask)]
	for k: int in range(1, shots.size()):
		psnr.append("%d: %.1f dB" % [SIZES[k], _psnr(shots[0], shots[k], mask)])
	var pct: Callable = func(n: int) -> String: return "%5.1f%%" % (100.0 * n / count)
	_report.append("%-40s %dx%d  araç %6d px | lod<0 %s  0–0,4 %s  0,4–1 %s  1–2 %s  ≥2 %s | %s" % [label, w, h, count,
		pct.call(bins[0]), pct.call(bins[1]), pct.call(bins[2]), pct.call(bins[3]), pct.call(bins[4]), ", ".join(psnr)])
	# Yan yana: araç kutusu, 1:1
	box = box.grow(6).intersection(Rect2i(0, 0, w, h))
	var sheet: Image = Image.create(box.size.x * shots.size(), box.size.y, false, Image.FORMAT_RGB8)
	for k: int in shots.size():
		sheet.blit_rect(shots[k], box, Vector2i(box.size.x * k, 0))
	sheet.save_png(OUT + label + "_2048_1536_1024.png")
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png(OUT + label + "_2048_1536_1024_x2.png")


const BAND_COLORS: Array[Color] = [Color(1, 0, 1), Color(0, 0, 1), Color(0, 1, 1), Color(1, 1, 0), Color(1, 0, 0)]


func _band(c: Color) -> int:
	for i: int in BAND_COLORS.size():
		var b: Color = BAND_COLORS[i]
		if absf(c.r - b.r) < 0.12 and absf(c.g - b.g) < 0.12 and absf(c.b - b.b) < 0.12:
			return i
	return -1


func _psnr(a: Image, b: Image, mask: PackedByteArray) -> float:
	var w: int = a.get_width()
	var sum: float = 0.0
	var n: int = 0
	for y: int in a.get_height():
		for x: int in w:
			if mask[y * w + x] == 0:
				continue
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			sum += (ca.r - cb.r) ** 2 + (ca.g - cb.g) ** 2 + (ca.b - cb.b) ** 2
			n += 3
	var mse: float = sum / maxf(float(n), 1.0)
	return 99.0 if mse <= 0.0 else 10.0 * log(1.0 / mse) / log(10.0)


func _find(node: Node, n: String) -> Node:
	if node.name == n:
		return node
	for c: Node in node.get_children():
		var f: Node = _find(c, n)
		if f:
			return f
	return null
