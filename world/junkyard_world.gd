class_name JunkyardWorld
extends Node3D
## HURDALIK DÜNYASI — Blender'da kodla kurulan sahne (tools/world/export_junkyard.py) burada oyuna bağlanır.
## Şehirle hiçbir bağı yoktur: JunkyardScreen kendi SubViewport'unda (own_world_3d) bunu kurar.
##
## Sahnede ne var:
##   Static_*            hareketsiz her şey, bölge bölge birleşik (az düğüm, az çizim çağrısı)
##   Terrain             tabakalı çöl tepeleri
##   SearchPile_N        aranabilir hurda yığınları + SearchRing_N (sarı kesik halka: "aranabilir")
##   DailyCarSpot_N      günün araçlarının yeri (boş düğüm; hurda varyantı buraya konur)
##   Crane_Hook          vincin mıknatısı + taşıdığı araba (sallanır)
##   Press_Ram           pres çenesi (iner / kalkar)
##   Necati, Cemo, Dog   figürler (hafif nefes / sallanma)
##   FireBarrel_N        ateş varilleri (alev materyali titrer)
## Zemin sahnede YOK: dokusu (gölge pişirilmiş) burada düz bir dörtgene giydirilir.
##
## IŞIK PİŞMİŞTİR: güneş, gök ışığı, gölgeler ve sekme ışığı Cycles'ta köşe rengine ve zemin dokusuna
## pişirilir (neden: export_junkyard.py başı — telefonda gerçek zamanlı yapılamıyordu, sahne kararıyordu).
## Burada her şey IŞIKSIZ (unshaded) çizilir: sahnede ışık yok, en ucuz çizim yolu. Kamera açısı sabit
## olduğu için kayıp yok. glTF köşe rengini getirir ama materyalde kullanmaz → materyaller burada
## yeniden kurulur (Blender materyal adı JYS_<tür>; ışıklılar JYS_emit_<renk>_<güç> düz parlak renk).
##
## KOORDİNAT: Blender metre (X doğu, Y kuzey, Z yukarı) → Godot (x, z, -y). Saha 64 × 50 m.
## Hareket eden / değişen nesnelerin (günün araçları) altına yumuşak gölge lekesi konur; hurda
## varyantlarının ışığı meydandaki yerlerinde pişirilmiştir.

const SCENE_PATH: String = "res://assets/world/junkyard.glb"
const GROUND_TEXTURE: String = "res://assets/world/junkyard_ground.png"
const WRECK_DIR: String = "res://assets/world/junk_wrecks/"
## Zemin dokusunun kapsadığı alan, Blender metresiyle (junk_ground.py G_X0, G_Y0, G_X1 - G_X0, G_Y1 - G_Y0).
const GROUND_RECT: Rect2 = Rect2(-8.0, -12.0, 108.0, 68.0)
const PILE_COUNT: int = 6
const DAILY_COUNT: int = 3
## Kameranın gezebileceği zemin (Godot X/Z). Saha + kapının önündeki yol + batıdaki hurda dağları.
const CAMERA_MIN: Vector2 = Vector2(-6.0, -54.0)
const CAMERA_MAX: Vector2 = Vector2(86.0, 10.0)
## Açılışta kameranın baktığı yer: giriş + meydan (Blender 39,7 / 18).
const START_FOCUS: Vector3 = Vector3(39.7, 0.0, -18.0)
## Ortografik yükseklik (m). Açılışta yatayda ~40 m (16:9).
const START_ZOOM: float = 22.0
const MIN_ZOOM: float = 11.0
const MAX_ZOOM: float = 34.0
## Blender güneşinin (Euler 68° / 0 / -115°) Godot'taki ışınım yönü: batı-kuzeybatıdan, alçak (22°).
## Işık pişmiş; bu yalnız gölge lekelerinin yönü için.
const SUN_DIRECTION: Vector3 = Vector3(0.840, -0.375, 0.392)
## Blender'ın "AgX - Medium High Contrast" görünümüne yakın ton eşleme.
const AGX_CONTRAST: float = 1.25
## Işıklılar: ışık rengi → parlaklık çarpanı (Blender gücü 3 / 7 / 12).
const EMITS: Dictionary = {"FFC94A": 1.6, "FFD08A": 2.2, "FF6A1A": 2.6}
const FIRE_KEY: String = "FF6A1A"
const SIGN_INK: Color = Color("7A2A20")
## Yığın / araç seçimi: ekranda merkezden bu yarıçap (dünya metresi → piksel) içinde dokunuş sayılır.
const PILE_PICK_RADIUS: float = 2.8
const CAR_PICK_RADIUS: float = 2.6

var camera: WorldCamera
var piles: Array[Node3D] = []
var rings: Array[Node3D] = []
var spots: Array[Node3D] = []
var _daily: Array[StringName] = []
var _daily_nodes: Array[Node3D] = []
var _materials: Dictionary = {}   # yüzey adı → StandardMaterial3D
var _hook: Node3D
var _ram: Node3D
var _ram_rest: float = 0.0
var _figures: Array[Node3D] = []
var _time: float = 0.0
var _shakes: Dictionary = {}   # yığın indeksi → Tween


## Sahne, zemin dokusu ve verilen hurda varyantlarını ARKA PLANDA yüklemeye başlar (harita yolculuğu
## sırasında). Kurulumdaki load() bitmiş yüklemeyi önbellekten alır, bitmemişse onu bekler.
static func preload_assets(daily: Array[StringName] = []) -> void:
	var paths: Array[String] = [SCENE_PATH, GROUND_TEXTURE]
	for id: StringName in daily:
		if id != &"":
			paths.append(WRECK_DIR + String(id) + ".glb")
	for path: String in paths:
		if ResourceLoader.exists(path) and not ResourceLoader.has_cached(path) \
				and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path)


func _ready() -> void:
	name = "JunkyardWorld"
	_build_environment()
	_build_ground()
	_load_scene()
	_build_signs()
	_build_camera()
	set_process(false)


## Ekran açıkken canlandırma çalışır; kapalıyken kare başına iş yok.
func set_active(on: bool) -> void:
	set_process(on)


# --- Kurulum -----------------------------------------------------------------------

func _build_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("C8B497")   # tozlu ufuk (kamera çoğunlukla zemini görür)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_agx_contrast = AGX_CONTRAST
	env.environment = environment
	add_child(env)


func _build_ground() -> void:
	var r: Rect2 = GROUND_RECT
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Blender UV (0,0) = güneybatı köşesi, doku satırları kuzeyden başlar (Godot v=0 üst)
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var uvs: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(blender(corners[i].x, corners[i].y, 0.0))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = load(GROUND_TEXTURE) as Texture2D
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = st.commit()
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _load_scene() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	var root: Node3D = packed.instantiate() as Node3D
	root.name = "Yard"
	add_child(root)
	_apply_materials(root)
	for i: int in PILE_COUNT:
		var pile: Node3D = root.find_child("SearchPile_%d" % i, true, false) as Node3D
		var ring: Node3D = root.find_child("SearchRing_%d" % i, true, false) as Node3D
		if pile:
			piles.append(_pivot(pile))
			rings.append(ring)
	for i: int in DAILY_COUNT:
		var spot: Node3D = root.find_child("DailyCarSpot_%d" % i, true, false) as Node3D
		if spot:
			spots.append(spot)
	_hook = root.find_child("Crane_Hook", true, false) as Node3D
	_ram = root.find_child("Press_Ram", true, false) as Node3D
	if _ram:
		_ram_rest = _ram.position.y
	for figure_name: String in ["Necati", "Cemo", "Dog"]:
		var figure: Node3D = root.find_child(figure_name, true, false) as Node3D
		if figure:
			_figures.append(figure)
			_add_blob(figure.position, 0.55 if figure_name != "Dog" else 0.45)


## Yığını tabanının ortasındaki bir pivota bağlar: seçim, toz ve sallanma bu noktayı kullanır. Geometriden
## ölçülür (eski dışa aktarımda yığınların orijini sahnenin köşesindeydi: altı yığın aynı noktaya
## izdüşüyor, sallanma köşe etrafında dönüyordu).
func _pivot(node: Node3D) -> Node3D:
	var mesh: MeshInstance3D = node as MeshInstance3D
	if mesh == null:
		var found: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
		mesh = found[0] as MeshInstance3D if not found.is_empty() else null
	if mesh == null or mesh.mesh == null:
		return node
	var box: AABB = mesh.global_transform * mesh.get_aabb()
	var pivot: Node3D = Node3D.new()
	pivot.name = String(node.name) + "_Pivot"
	node.get_parent().add_child(pivot)
	pivot.global_position = Vector3(box.get_center().x, 0.0, box.get_center().z)
	node.reparent(pivot, true)
	return pivot


## Bütün yüzeyler köşe rengini albedo olarak kullanan paylaşılan materyallere geçer.
func _apply_materials(node: Node) -> void:
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var source: Material = mi.mesh.surface_get_material(s)
			var key: String = source.resource_name if source else "JYS_matte"
			mi.set_surface_override_material(s, surface_material(key))


## Blender materyal adından (JYS_<tür> / JYS_emit_<renk>_<güç>) paylaşılan ışıksız materyal.
## Yüzey türleri (mat, metal, krom...) artık aynı: fark pişmiş ışığın içinde.
func surface_material(blender_name: String) -> StandardMaterial3D:
	var key: String = blender_name.trim_prefix("JYS_")
	if not key.begins_with("emit_"):
		key = "lit"
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED   # Blender'da arka yüz ayıklama kapalı (açık kabuklar)
	if key.begins_with("emit_"):
		var hex: String = key.get_slice("_", 1)
		material.albedo_color = Color(hex) * float(EMITS.get(hex, 1.0))
	else:
		material.vertex_color_use_as_albedo = true
	_materials[key] = material
	return material


func _build_signs() -> void:
	# Önizleme yazılarının yerleri (junkyard.py preview_text): levhaların hemen önünde
	_sign(Loc.t("HURDACI NECATİ"), blender(53.0, 5.07 - 0.02, 3.52), 0.0, 0.6)
	_sign(Loc.t("HURDALIK"), blender(64.36 + 0.02, 21.0, 5.85), 90.0, 1.0)


func _sign(text: String, pos: Vector3, yaw: float, height: float) -> void:
	var font: FontVariation = FontVariation.new()
	font.variation_embolden = 0.6
	font.spacing_glyph = 2
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 64
	label.pixel_size = height / 64.0
	label.outline_size = 0
	label.modulate = SIGN_INK
	label.shaded = false
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.basis = Basis(Vector3.UP, deg_to_rad(yaw))
	label.position = pos
	add_child(label)


func _build_camera() -> void:
	camera = WorldCamera.new()
	camera.name = "JunkyardCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 900.0
	camera.world_min = CAMERA_MIN
	camera.world_max = CAMERA_MAX
	camera.start_zoom = START_ZOOM
	camera.min_zoom = MIN_ZOOM
	camera.max_zoom = MAX_ZOOM
	camera.zoom_speed = 2.0
	# Şehir kamerasıyla aynı açı: güneydoğudan 45°, 25° yukarıdan (Main.tscn MainCamera)
	camera.basis = Basis.from_euler(Vector3(deg_to_rad(-25.0), deg_to_rad(45.0), 0.0))
	camera.position = START_FOCUS + camera.basis.z * 300.0
	add_child(camera)


## Yumuşak gölge lekesi (hareketli / değişen nesnelerin altı): pişirilmiş gölgeyle aynı yöne biraz kayık.
func _add_blob(at: Vector3, radius: float, parent: Node3D = null) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(radius * 2.6, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.12, 0.10, 0.12, 0.45)
	material.albedo_texture = _blob_texture()
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.mesh = quad
	blob.material_override = material
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flat: Vector3 = Vector3(SUN_DIRECTION.x, 0.0, SUN_DIRECTION.z).normalized()
	blob.position = Vector3(at.x, 0.02, at.z) + flat * radius * 0.5
	blob.rotation.y = atan2(-flat.z, flat.x)
	(parent if parent else self).add_child(blob)
	return blob


var _blob_tex: GradientTexture2D


func _blob_texture() -> GradientTexture2D:
	if _blob_tex == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = gradient
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(1.0, 0.5)
		_blob_tex.width = 64
		_blob_tex.height = 64
	return _blob_tex


# --- Günün araçları ------------------------------------------------------------------

## Sahadaki araçları gösterir (en fazla DAILY_COUNT; &"" → o yer boş).
func show_daily(ids: Array[StringName]) -> void:
	if ids == _daily and _daily_nodes.size() == spots.size():
		return
	_daily = ids.duplicate()
	for node: Node3D in _daily_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_daily_nodes.clear()
	for i: int in spots.size():
		var holder: Node3D = Node3D.new()
		holder.name = "DailyCar_%d" % i
		holder.position = spots[i].global_position - global_position
		add_child(holder)
		_daily_nodes.append(holder)
		var id: StringName = ids[i] if i < ids.size() else &""
		if id == &"":
			continue
		var wreck: Node3D = wreck_model(id)
		if wreck:
			holder.add_child(wreck)
			_add_blob(Vector3.ZERO, 1.7, holder)


## Restorasyon aracının paslı, tekerleksiz hurda varyantı (ön +Z, gerçek metre). Yoksa null.
func wreck_model(id: StringName) -> Node3D:
	var path: String = WRECK_DIR + String(id) + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	_apply_materials(model)
	return model


func daily_ids() -> Array[StringName]:
	return _daily


# --- Yığınlar -----------------------------------------------------------------------

## Yığının üstündeki sarı halka (aranabilir mi).
func set_pile_ready(index: int, on: bool) -> void:
	if index >= 0 and index < rings.size() and rings[index]:
		rings[index].visible = on


## ARAMA animasyonu: yığın sarsılır, toz kalkar (~1 sn). Bitince `done` çağrılır.
func shake_pile(index: int, done: Callable = Callable()) -> void:
	if index < 0 or index >= piles.size():
		return
	var pile: Node3D = piles[index]
	if _shakes.has(index):
		(_shakes[index] as Tween).kill()
	pile.rotation = Vector3.ZERO
	var tween: Tween = create_tween()
	_shakes[index] = tween
	for k: int in 6:
		var a: float = deg_to_rad(2.4 * (1.0 - k / 6.0)) * (1.0 if k % 2 == 0 else -1.0)
		tween.tween_property(pile, "rotation", Vector3(a * 0.6, 0.0, a), 0.08)
	tween.tween_property(pile, "rotation", Vector3.ZERO, 0.12)
	tween.tween_interval(0.35)
	tween.finished.connect(func() -> void:
		_shakes.erase(index)
		if done.is_valid():
			done.call())
	_dust(pile.global_position)


func _dust(at: Vector3) -> void:
	var dust: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _blob_texture()
	material.vertex_color_use_as_albedo = true
	quad.material = material
	dust.mesh = quad
	dust.one_shot = true
	dust.amount = 18
	dust.lifetime = 1.1
	dust.explosiveness = 0.85
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.6
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.4
	dust.gravity = Vector3(0.0, -1.2, 0.0)
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.4
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.78, 0.68, 0.52, 0.7))
	ramp.set_color(1, Color(0.78, 0.68, 0.52, 0.0))
	dust.color_ramp = ramp
	dust.position = at - global_position + Vector3.UP * 0.8
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


# --- Seçim (dokunuş) ---------------------------------------------------------------

## Ekran noktasına (bu görüntü alanının pikseli) en yakın yığın ya da araç:
## {"kind": &"pile" | &"car", "index": int} ya da boş sözlük.
func pick(screen: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for i: int in piles.size():
		var d: float = _screen_distance(screen, piles[i].global_position + Vector3.UP * 0.9, PILE_PICK_RADIUS)
		if d < best_d:
			best_d = d
			best = {"kind": &"pile", "index": i}
	for i: int in _daily_nodes.size():
		if i >= _daily.size() or _daily[i] == &"":
			continue
		var d: float = _screen_distance(screen, _daily_nodes[i].global_position + Vector3.UP * 0.7, CAR_PICK_RADIUS)
		if d < best_d:
			best_d = d
			best = {"kind": &"car", "index": i}
	return best


## Ekranda noktaya uzaklık, yarıçapa oranlı (1 = kenar). Dışındaysa INF.
func _screen_distance(screen: Vector2, world: Vector3, radius: float) -> float:
	var center: Vector2 = camera.unproject_position(world)
	var edge: Vector2 = camera.unproject_position(world + camera.global_transform.basis.x * radius)
	var r: float = maxf(center.distance_to(edge), 1.0)
	var d: float = screen.distance_to(center) / r
	return d if d <= 1.0 else INF


## Dünya noktasının ekrandaki yeri (uçan ikon / plaka konumu için).
func screen_point(world: Vector3) -> Vector2:
	return camera.unproject_position(world)


func pile_position(index: int) -> Vector3:
	return piles[index].global_position if index >= 0 and index < piles.size() else Vector3.ZERO


func car_position(index: int) -> Vector3:
	return _daily_nodes[index].global_position if index >= 0 and index < _daily_nodes.size() else Vector3.ZERO


# --- Canlandırma ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _hook:
		# Mıknatıs halatta yavaşça sallanır (iki eksende farklı periyot: düzenli görünmesin)
		_hook.rotation = Vector3(sin(_time * 0.83) * 0.035, 0.0, sin(_time * 0.61 + 1.3) * 0.05)
	if _ram:
		# Pres: 5 sn döngü — yavaş iner, ezer, bekler, kalkar
		var phase: float = fmod(_time, 5.0)
		var down: float = 0.0
		if phase < 1.6:
			down = smoothstep(0.0, 1.6, phase)
		elif phase < 2.4:
			down = 1.0
		elif phase < 3.6:
			down = 1.0 - smoothstep(2.4, 3.6, phase)
		_ram.position.y = _ram_rest - down * 1.4
	for i: int in _figures.size():
		var figure: Node3D = _figures[i]
		figure.scale = Vector3(1.0, 1.0 + sin(_time * 1.7 + i * 2.1) * 0.012, 1.0)
	var fire: StandardMaterial3D = _materials.get("emit_%s_12" % FIRE_KEY) as StandardMaterial3D
	if fire:
		fire.albedo_color = Color(FIRE_KEY) * float(EMITS[FIRE_KEY]) \
			* (0.85 + 0.15 * sin(_time * 9.0) * sin(_time * 5.3 + 0.7))


## Blender metresi → Godot konumu.
static func blender(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)
