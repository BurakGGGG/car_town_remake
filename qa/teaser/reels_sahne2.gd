extends "res://qa/teaser/teaser.gd"
## REELS SAHNE 2 — oyuncunun KENDİ garajı (kayıttan), 4 sn, dikey 1080x1920, 30 fps. Kamera OYUN KAMERASI
## (ortografik, 45° / −25°): 0–1 sn tüm garaj → 1–3 sn yavaşça liftlere / çalışma alanına → 3–4 sn en güzel
## araçların olduğu karede durur. Tasarım değişmez; yalnızca boş kalan yerlere oyunun kendi kataloğundan
## eklemeler (çıplak duvarlara duvar eşyası, boş garaj yoluna sahip olunan bir sergi aracı). Her ekleme
## oyunun yerleşim kuralından (GarageDecorView.is_valid) geçer; geçmeyen eklenmez ve "SAHNE2 GEÇERSİZ" basar.
## HUD / 2B arayüz yok (yalnızca SubViewport'un 3B dünyası), dünya plakaları ve müşteri balonları gizli.
##   QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/teaser/reels_sahne2.gd \
##       --display-driver x11 --disable-vsync --fixed-fps 30 --resolution 540x960 -- sahne2 <çıktı> [adım|probe]
const Kit = preload("res://qa/teaser/garage_kit.gd")
const REEL_FPS: float = 30.0
const DURATION: float = 4.0
const PREROLL: float = 1.2
const SS: int = 2
const CAM_YAW: float = 45.0
const CAM_PITCH: float = -25.0
## Liftlerdeki müşteri araçları (fabrika renginde): [alan, araç, kalkık mı, iş].
const LIFTS: Array = [
	[0, &"vw_golf_7", true, &"body"],
	[1, &"ford_focus", true, &"brakes"],
	[2, &"tofas_sahin", false, &"tires"],
]
const BEAT: Array[float] = [0.36, 0.3, 0.5]
const OFFSET: Array[float] = [0.05, 0.2, 0.0]
## Eklemeler (garaj koordinatı u = sağ kenardan sola, v = önden arkaya; metre):
## zemin [eşya, u, v, yaw] · duvar [eşya, "back"/"left", u_ya_da_v].
const EXTRAS: Array = [
	["car:lambo_huracan", 1.9, 1.28, 0.0],
	["neon_car", "back", 2.25],
	["checkered_flags", "back", 2.95],
	["neon_bolt", "back", 3.55],
	["tyre_hanger", "back", 4.45],
	["pegboard", "left", 0.75],
	["rim_display", "left", 1.4],
	["sign_tires", "left", 2.05],
]
## AÇILIŞ: tüm garajı (zemin + 0,45 yükseklik) kapsayan kare [u0, v0, u1, v1]; oyun kamerası gibi dünya
## sınırına kıstırılır (harita kenarı görünmez).
const FRAME_ALL: Array = [0.0, 0.0, 4.725, 2.975]
const MARGIN: float = 0.03
## Sonraki anahtarlar: kare ortasındaki zemin noktası (u, v) ve ortografik size (sahne 1: 2,6–3,0; daha geniş).
## ÇALIŞMA: üç lift, takım dolapları, atölye, Murat 124 / W123, Huracán. SON: Huracán, E60, RS6, Porsche, W123.
const FRAME_WORK: Array = [2.91, 1.21, 4.0]
const FRAME_END: Array = [1.8, 1.9, 4.7]

var kit: Kit
var fx: Array[RepairFx] = []
var probe: bool = false
var _next_hit: Array[float] = []
var _basis: Basis
var _keys: Array = []   # [odak, size]
var _world_cam: WorldCamera


func _initialize() -> void:
	super()
	probe = OS.get_cmdline_user_args().has("probe")
	if preview_step == 0:
		vp.size = Vector2i(W * SS, H * SS)
	_basis = Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0))


func _run() -> void:
	kit = Kit.new()
	await kit.boot(self)
	var repair: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	if repair:
		repair.set_process(false)   # yeni müşteri / balon yok; trafik akar
	kit.hud.visible = false
	_add_extras()
	await frames(10)
	kit.view.refresh()
	for spec: Array in LIFTS:
		var car: Node3D = kit.lift_car(int(spec[0]), spec[1], 1.0 if spec[2] else 0.0)
		var f: RepairFx = RepairFx.new()
		current_scene.add_child(f)
		f.setup(car, spec[3])
		f._working = false
		fx.append(f)
		_next_hit.append(-PREROLL + OFFSET[fx.size() - 1])
	var cam: Camera3D = kit.attach_camera()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.05
	cam.far = 60.0
	cam.cull_mask &= ~WorldCamera.LAYER_WORLD_UI
	# Geniş açılışta haritanın uzak köşesi kareye girerse gökyüzü değil çim rengi görünsün (ölçülen çim)
	cam.environment.background_mode = Environment.BG_COLOR
	cam.environment.background_color = Color(0.257, 0.416, 0.158)
	var aspect: float = float(vp.size.x) / float(vp.size.y)
	_world_cam = current_scene.find_child("MainCamera", true, false) as WorldCamera
	_keys.append(_clamp_world(_frame(FRAME_ALL, aspect)))
	for k: Array in [FRAME_WORK, FRAME_END]:
		_keys.append(_clamp_world([Vector3(Kit.X(float(k[0])), 0.0, Kit.Z(float(k[1]))), float(k[2])]))
	if probe:
		# Eklenen her duvar eşyasına yakın bakış (model denetimi)
		for e: Array in EXTRAS:
			if e.size() == 3:
				var u: float = float(e[2]) if e[1] == "back" else 4.55
				var v: float = 2.85 if e[1] == "back" else float(e[2])
				_keys.append([Vector3(Kit.X(u), 0.25, Kit.Z(v)), 0.9])
	await frames(120)
	for n: Node in current_scene.find_children("CarBubble", "", true, false):
		(n as Node3D).visible = false
	if probe:
		for i: int in _keys.size():
			_place(_keys[i][0], _keys[i][1])
			await frames(3)
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			img.resize(W / 2, H / 2, Image.INTERPOLATE_LANCZOS)
			img.save_png("%s/probe_%02d.png" % [out_dir, i])
			_saved += 1
	else:
		seed(11)
		await record(tick)
	print("SAHNE2 bitti: %d kare → %s" % [_saved, out_dir])
	quit(0)


## Eklemeler kayıttaki tasarımın ÜSTÜNE: eşya envantere eklenir, oyunun kuralıyla geçerliyse yerleştirilir.
func _add_extras() -> void:
	var decor: DecorManager = kit.decor
	var view: GarageDecorView = kit.view
	var st: Dictionary = decor.state()
	var owned: Dictionary = st.get("owned", {})
	for e: Array in EXTRAS:
		if not GarageDecor.is_vehicle(StringName(e[0])):
			owned[String(e[0])] = int(owned.get(String(e[0]), 0)) + 1
	st["owned"] = owned
	decor.load_state(st)
	var area: DecorArea = view.area()
	var added: int = 0
	for e: Array in EXTRAS:
		var item: StringName = StringName(e[0])
		var pos: Vector3
		var yaw: float = 0.0
		if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
			var along: float = Kit.X(float(e[2])) if e[1] == "back" else Kit.Z(float(e[2]))
			var mount: Dictionary = area.mount_on(e[1], along, view.wall_width(item))
			pos = mount["position"]
			yaw = float(mount["yaw"])
		else:
			pos = Vector3(Kit.X(float(e[1])), area.floor_y, Kit.Z(float(e[2])))
			yaw = float(e[3])
		if not view.is_valid(item, pos, yaw):
			print("SAHNE2 GEÇERSİZ: ", e, " boyut=", view.footprint_size(item))
			continue
		if decor.add_instance(item, pos, yaw) == "":
			print("SAHNE2 eklenemedi (envanter): ", e)
			continue
		added += 1
	print("SAHNE2 eklenen %d / %d, toplam eşya %d" % [added, EXTRAS.size(), decor.instance_count()])


## Ortografik kare: kutunun köşeleri kamera düzlemine izdüşürülür; ortası odak, boyu (en/oran ya da
## yükseklik, hangisi büyükse) + pay = size.
func _frame(box: Array, aspect: float) -> Array:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for u: float in [float(box[0]), float(box[2])]:
		for v: float in [float(box[1]), float(box[3])]:
			for h: float in [0.0, 0.45]:
				var p: Vector3 = Vector3(Kit.X(u), h, Kit.Z(v))
				var s: Vector2 = Vector2(p.dot(_basis.x), p.dot(_basis.y))
				lo = lo.min(s)
				hi = hi.max(s)
	var c: Vector2 = (lo + hi) * 0.5
	var size: float = maxf((hi.x - lo.x) / aspect, hi.y - lo.y) / (1.0 - 2.0 * MARGIN)
	return [_basis.x * c.x + _basis.y * c.y, size]


## Karenin dört köşesinin zemindeki izi oyun kamerasının dünya sınırları (world_min / world_max) içinde
## kalacak şekilde odak zeminde kaydırılır (WorldCamera._apply_focus'un aynısı, ortografik).
func _clamp_world(key: Array) -> Array:
	if _world_cam == null:
		return key
	var focus: Vector3 = key[0]
	var size: float = float(key[1])
	var aspect: float = float(vp.size.x) / float(vp.size.y)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var origin: Vector3 = focus + _basis.x * corner.x * size * aspect * 0.5 + _basis.y * corner.y * size * 0.5
		var dir: Vector3 = -_basis.z
		var hit: Vector3 = origin + dir * (-origin.y / dir.y)
		lo = lo.min(Vector2(hit.x, hit.z))
		hi = hi.max(Vector2(hit.x, hit.z))
	var a: Vector2 = _world_cam.world_min - lo
	var b: Vector2 = _world_cam.world_max - hi
	var shift: Vector2 = Vector2(clampf(0.0, a.x, b.x) if a.x <= b.x else (a.x + b.x) * 0.5,
		clampf(0.0, a.y, b.y) if a.y <= b.y else (a.y + b.y) * 0.5)
	if shift != Vector2.ZERO:
		print("SAHNE2 dünya sınırı kaydırması ", shift)
	return [focus + Vector3(shift.x, 0.0, shift.y), size]


func _place(focus: Vector3, size: float) -> void:
	kit.cam.global_transform = Transform3D(_basis, focus + _basis.z * 20.0)
	kit.cam.size = size


func record(tick_fn: Callable) -> void:
	var first: int = -roundi(PREROLL * REEL_FPS)
	var count: int = roundi(DURATION * REEL_FPS)
	for f: int in range(first, count):
		frame_index = f
		tick_fn.call(float(f) / REEL_FPS)
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
	reset_post()
	set_post(&"vignette", 0.0)
	set_post(&"grain", 0.0)
	_hits(t)
	_camera(clampf(t, 0.0, DURATION))


## 0–1 sn: tüm garaj, çok hafif yaklaşma (log-boy hızı ZOOM0). 1–3,75 sn: odak ve boy Catmull-Rom ile
## açılış → çalışma alanı → son kare; ilerleme kübik Hermite (1. saniyedeki hafif yaklaşmadan yumuşakça
## hızlanır, son karede sıfıra iner). 3,7–4 sn: son karede durur (kıvılcımlar sürer).
const ZOOM0: float = 0.1
const PROGRESS: Array = [[1.0, 0.0, 0.6], [2.5, 1.0, 0.7], [3.7, 2.0, 0.0]]   # [t, s, ds/dt]


func _camera(t: float) -> void:
	var a: Array = _keys[0]
	var a1: Array = [a[0], float(a[1]) * exp(-ZOOM0)]
	if t <= 1.0:
		_place(a[0], float(a[1]) * exp(-ZOOM0 * t))
		return
	var s: float = _progress(t)
	var pts: Array = [a1, a1, _keys[1], _keys[2], _keys[2]]
	var i: int = mini(int(s), 1)
	var k: float = s - float(i)
	var p0: Array = pts[i]
	var p1: Array = pts[i + 1]
	var p2: Array = pts[i + 2]
	var p3: Array = pts[i + 3]
	var focus: Vector3 = _cr(p0[0], p1[0], p2[0], p3[0], k)
	# Boy log uzayında: yakınlaşma algısı eşit hızlı
	var size: float = exp(_cr(Vector3.ONE * log(float(p0[1])), Vector3.ONE * log(float(p1[1])),
		Vector3.ONE * log(float(p2[1])), Vector3.ONE * log(float(p3[1])), k).x)
	_place(focus, size)


static func _progress(t: float) -> float:
	if t >= float(PROGRESS[PROGRESS.size() - 1][0]):
		return float(PROGRESS[PROGRESS.size() - 1][1])
	for j: int in PROGRESS.size() - 1:
		var q0: Array = PROGRESS[j]
		var q1: Array = PROGRESS[j + 1]
		if t <= float(q1[0]):
			var h: float = float(q1[0]) - float(q0[0])
			var x: float = (t - float(q0[0])) / h
			var x2: float = x * x
			var x3: float = x2 * x
			return (2.0 * x3 - 3.0 * x2 + 1.0) * float(q0[1]) + (x3 - 2.0 * x2 + x) * h * float(q0[2]) \
				+ (-2.0 * x3 + 3.0 * x2) * float(q1[1]) + (x3 - x2) * h * float(q1[2])
	return 0.0


func _hits(t: float) -> void:
	for i: int in fx.size():
		while t >= _next_hit[i]:
			_next_hit[i] += BEAT[i] * randf_range(0.85, 1.15)
			_hit(fx[i], StringName(LIFTS[i][3]))


## Oyunun tamir efekti (RepairFx) vuruşu; kıvılcım kameraya bakan yanda.
func _hit(f: RepairFx, job: StringName) -> void:
	var cam_local: Vector3 = f.to_local(kit.cam.global_position)
	var side: float = signf(cam_local.x) if cam_local.x != 0.0 else 1.0
	var end: float = signf(cam_local.z) if cam_local.z != 0.0 else 1.0
	match job:
		&"body":
			f._spark_at(f._point(side, randf_range(0.3, 0.6), randf_range(-0.6, 0.6)), Color(0.75, 0.88, 1.0), true)
		&"brakes":
			var ez: float = end if randf() < 0.7 else -end
			f._spark_at(f._point(side * 0.95, 0.22, ez * 0.62), Color(1.0, 0.72, 0.28), true)
		&"tires":
			f._spin_left = 0.45
			f._spark_at(f._point(side * 0.95, 0.22, end * 0.62), Color(1.0, 0.8, 0.4), false)


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, s: float) -> Vector3:
	return 0.5 * (2.0 * p1 + (p2 - p0) * s + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s * s
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * s * s * s)
