extends "res://qa/teaser/teaser.gd"
## REELS — oyuncunun KENDİ garajı (kayıttan), 4 sn, dikey 1080x1920, 60 fps. Üç liftte tamir sürerken
## (oyunun kendi tamir efektleri: kaynak, fren taşlaması, motor dumanı) kamera garajı baştan sona gezer.
## Kamera OYUN KAMERASININ AYNISI: ortografik, 45° yatay / 25° eğim (Main.tscn MainCamera); yalnızca
## oyuncunun kaydırması ve yakınlaştırması gibi pan + zoom. Ek efekt / boya yok: araçlar fabrika renginde.
## Kayıt yalıtılmış kopyadan okunur (asıl kayda dokunulmaz); HUD ve 2B arayüz karede yoktur (yalnızca
## SubViewport'un 3B dünyası çekilir), dünya plakaları (LAYER_WORLD_UI) ve müşteri balonları gizlenir.
##   QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/teaser/reels_garaj.gd \
##       --display-driver x11 --disable-vsync --fixed-fps 60 --resolution 540x960 -- reels <çıktı> [adım|probe]
## adım N > 0: her N. kare yarım boyda, süper örneklemesiz (kurgu provası). probe: anahtar bakışlardan durağan kare.
const Kit = preload("res://qa/teaser/garage_kit.gd")
const REEL_FPS: float = 60.0
const DURATION: float = 4.0
## Kayıttan önce dönen süre: kıvılcım / duman karenin ilk anında havada olsun.
const PREROLL: float = 1.2
## Süper örnekleme: 3B bu katta çizilir, kare Lanczos ile 1080x1920'ye indirilir (ince eşyada titreme yok).
const SS: int = 2
## Oyun kamerasının açısı (MainCamera: yaw 45°, pitch −25°).
const CAM_YAW: float = 45.0
const CAM_PITCH: float = -25.0
## Liftlerdeki müşteri araçları (fabrika renginde, oyunda boya kapalıyken müşteriler de böyle gelir):
## [alan, araç, kalkık mı, iş].
const LIFTS: Array = [
	[0, &"vw_golf_7", true, &"body"],
	[1, &"ford_focus", true, &"brakes"],
	[2, &"tofas_sahin", false, &"engine"],
]
## İş vuruşlarının aralığı (sn) ve ilk vuruş kayması: her lift kendi ritminde.
const BEAT: Array[float] = [0.34, 0.29, 0.45]
const OFFSET: Array[float] = [0.05, 0.19, 0.0]
## Kamera odağı (zemindeki kare ortası, garaj koordinatı u = sağ kenardan sola, v = önden arkaya; metre)
## ve ortografik size (kare yüksekliği, dünya birimi): [u, v, size]. Liftler → orta (simülatör, sergi
## araçları) → bahçe ve lüks salon. Eşit aralıklı Catmull-Rom.
const KEYS: Array = [
	[3.95, 0.9, 2.6],
	[2.9, 1.3, 2.75],
	[1.9, 1.7, 2.9],
	[1.0, 2.1, 3.0],
]

var kit: Kit
var fx: Array[RepairFx] = []
var probe: bool = false
var _next_hit: Array[float] = []
var _basis: Basis


func _initialize() -> void:
	super()
	probe = OS.get_cmdline_user_args().has("probe")
	if preview_step == 0:
		vp.size = Vector2i(W * SS, H * SS)
	_basis = Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0))


func _run() -> void:
	kit = Kit.new()
	await kit.boot(self)
	# Müşteri akışı durur (yolda balonlu araç olmaz); trafik akmaya devam eder
	var repair: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	if repair:
		repair.set_process(false)
	kit.hud.visible = false
	for spec: Array in LIFTS:
		var car: Node3D = kit.lift_car(int(spec[0]), spec[1], 1.0 if spec[2] else 0.0)
		var f: RepairFx = RepairFx.new()
		current_scene.add_child(f)
		f.setup(car, spec[3])
		f._working = false   # vuruşları kurgu zamanına göre _hits() verir
		fx.append(f)
		_next_hit.append(-PREROLL + OFFSET[fx.size() - 1])
	var cam: Camera3D = kit.attach_camera()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.05
	cam.far = 60.0
	cam.cull_mask &= ~WorldCamera.LAYER_WORLD_UI
	await frames(120)   # lift kalkışı, gölgeler, trafik otursun
	_hide_markers()
	if probe:
		await _probe()
	else:
		seed(7)
		await record(tick)
	print("REELS bitti: %d kare → %s" % [_saved, out_dir])
	quit(0)


## Müşteri balonları (TAMİR / bekleme).
func _hide_markers() -> void:
	for n: Node in current_scene.find_children("CarBubble", "", true, false):
		(n as Node3D).visible = false


## Odak (zemin noktası) + size → oyun açısındaki ortografik kamera.
func _place(focus: Vector3, size: float) -> void:
	kit.cam.global_transform = Transform3D(_basis, focus + _basis.z * 20.0)
	kit.cam.size = size


func _probe() -> void:
	for i: int in KEYS.size():
		var k: Array = KEYS[i]
		_place(_g(k[0], k[1]), float(k[2]))
		await frames(3)
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		img.resize(W / 2, H / 2, Image.INTERPOLATE_LANCZOS)
		img.save_png("%s/probe_%02d.png" % [out_dir, i])
		_saved += 1


## Bu sürümün kare döngüsü: önce PREROLL (yazılmaz), sonra 0..DURATION, 60 fps; kare indirilip yazılır.
func record(tick_fn: Callable) -> void:
	var first: int = -roundi(PREROLL * REEL_FPS)
	var count: int = roundi(DURATION * REEL_FPS)
	for f: int in range(first, count):
		frame_index = f
		var t: float = float(f) / REEL_FPS
		tick_fn.call(t)
		await process_frame
		if f < 0 or (preview_step > 0 and f % preview_step != 0):
			continue
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		if img.get_width() != W:
			img.resize(W, H, Image.INTERPOLATE_LANCZOS)
		if preview_step > 0:
			img.resize(W / 2, H / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/%05d.png" % [out_dir, f])
		_saved += 1


func tick(t: float) -> void:
	# Son işleme yok: oyundaki görüntünün aynısı
	reset_post()
	set_post(&"vignette", 0.0)
	set_post(&"grain", 0.0)
	_hits(t)
	_camera(clampf(t, 0.0, DURATION))


func _camera(t: float) -> void:
	var u: float = t / DURATION
	# Yumuşak kalkış ve varış, arada sabit hızlı kayma
	var e: float = lerpf(u, smooth(u), 0.55)
	var s: float = e * float(KEYS.size() - 1)
	var i: int = mini(int(s), KEYS.size() - 2)
	var k: float = s - float(i)
	var p0: Array = KEYS[maxi(i - 1, 0)]
	var p1: Array = KEYS[i]
	var p2: Array = KEYS[i + 1]
	var p3: Array = KEYS[mini(i + 2, KEYS.size() - 1)]
	var focus: Vector3 = _cr(_g(p0[0], p0[1]), _g(p1[0], p1[1]), _g(p2[0], p2[1]), _g(p3[0], p3[1]), k)
	var size: float = _cr(Vector3.ONE * float(p0[2]), Vector3.ONE * float(p1[2]), Vector3.ONE * float(p2[2]),
		Vector3.ONE * float(p3[2]), k).x
	_place(focus, size)


## Her lift kendi ritminde vurur; kıvılcım / duman kameraya bakan yanda çıkar.
func _hits(t: float) -> void:
	for i: int in fx.size():
		while t >= _next_hit[i]:
			_next_hit[i] += BEAT[i] * randf_range(0.85, 1.15)
			_hit(fx[i], StringName(LIFTS[i][3]))


func _hit(f: RepairFx, job: StringName) -> void:
	var cam_local: Vector3 = f.to_local(kit.cam.global_position)
	var side: float = signf(cam_local.x) if cam_local.x != 0.0 else 1.0
	var end: float = signf(cam_local.z) if cam_local.z != 0.0 else 1.0
	match job:
		&"body":
			f._spark_at(f._point(side * 1.0, randf_range(0.3, 0.6), randf_range(-0.6, 0.6)), Color(0.75, 0.88, 1.0), true)
		&"brakes":
			var ez: float = end if randf() < 0.7 else -end
			f._spark_at(f._point(side * 0.95, 0.22, ez * 0.62), Color(1.0, 0.72, 0.28), true)
		&"engine":
			f._puff(f._point(randf_range(-0.3, 0.3), 0.85, 0.72 * f._front), Color(0.86, 0.87, 0.88, 0.5))
			if randf() < 0.5:
				f._spark_at(f._point(randf_range(-0.4, 0.4), 0.7, 0.8 * f._front), Color(1.0, 0.75, 0.3), false)


## Garaj koordinatı → dünya (zemin).
static func _g(u: Variant, v: Variant) -> Vector3:
	return Vector3(Kit.X(float(u)), 0.0, Kit.Z(float(v)))


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, s: float) -> Vector3:
	return 0.5 * (2.0 * p1 + (p2 - p0) * s + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s * s
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * s * s * s)
