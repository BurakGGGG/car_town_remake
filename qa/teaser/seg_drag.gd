extends RefCounted
## 12–17 sn GÜCÜNÜ PİSTTE GÖSTER! Oyunun drag pisti (DragTrack) + egzoz alevi / patinaj dumanı (DragFx).
## Ferrari 488 Pista ile Lamborghini Huracán burun buruna: çıkış ağacı → patinaj → kalkışta araçlar
## yerdeki kameranın iki yanından geçer → yandan takip → tepeden drone → bitişte ağır çekim ve foto finiş
## donması (17,0'da müzik kesilir, logo gelir).
const D = preload("res://qa/teaser/teaser.gd")
const FERRARI: StringName = &"ferrari_488_pista"
const LAMBO: StringName = &"lambo_huracan"
const CAR_SCALE: float = 1.2
const LANE: float = DragTrack.LANE_OFFSET
const GO: float = 12.9
const ACCEL: float = 8.0
const CUTS: Array[float] = [12.0, 12.45, 12.9, 13.7, 14.9, 16.1]   # kalkıştan sonra 150 BPM ızgarası
## Vites değişimi alevleri (global saniye) — ses bandı aynı anlarda patlama çalar.
const SHIFTS: Array[float] = [13.3, 14.1, 15.3]
const FINISH_CROSS: float = 16.45

var d: D
var world: Node3D
var cam: Camera3D
var track: DragTrack
var cars: Array[Node3D] = []
var rigs: Array[CarRig] = []
var fx: Array[DragFx] = []
var lanes: Array[float] = [-LANE, LANE]
var speed_mat: ShaderMaterial
var speed_rect: ColorRect
var title: Label
var _prev_t: float = -1.0
var _prev_s: Array[float] = [0.0, 0.0]


func run(director: D) -> void:
	d = director
	world = Node3D.new()
	d.vp.add_child(world)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = DragTrack.sky()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("CBD9E2")
	e.ambient_light_energy = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env_node.environment = e
	world.add_child(env_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -130.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.shadow_enabled = true
	world.add_child(sun)
	track = DragTrack.new()
	world.add_child(track)
	for i: int in 2:
		var id: StringName = LAMBO if i == 0 else FERRARI   # Lambo kameraya yakın şeritte (teker yakın çekimleri)
		var car: Node3D = d.spawn_car(id, world, CAR_SCALE)
		car.position = Vector3(lanes[i], 0.0, DragTrack.START_Z)
		cars.append(car)
		rigs.append(D.rig_of(car))
		var f: DragFx = DragFx.new(CAR_SCALE)
		world.add_child(f)
		fx.append(f)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 220.0
	world.add_child(cam)
	cam.make_current()
	var lines_layer: CanvasLayer = CanvasLayer.new()
	lines_layer.layer = 19
	d.vp.add_child(lines_layer)
	speed_rect = ColorRect.new()
	speed_rect.size = Vector2(D.W, D.H)
	speed_mat = ShaderMaterial.new()
	speed_mat.shader = preload("res://vfx/speed_lines.gdshader")
	speed_mat.set_shader_parameter(&"aspect", float(D.W) / float(D.H))
	speed_rect.material = speed_mat
	speed_rect.visible = false
	lines_layer.add_child(speed_rect)
	title = d.make_title("GÜCÜNÜ\nPİSTTE GÖSTER!", 112, 0.14, 900, D.BRAND_GOLD)
	await d.frames(5)
	await d.record(tick)


## Yarış mesafesi (birim) — kalkıştan sonra sabit ivme; iki araç arasında küçük, değişen fark.
func _distance(i: int, t: float) -> float:
	var tau: float = maxf(0.0, t - GO)
	var s: float = 0.5 * ACCEL * tau * tau
	var gap: float = 0.22 * sin(tau * 2.3 + 0.4) * minf(1.0, tau * 1.5)
	return s + (gap if i == 0 else -gap)


func _crossed(at: float, t: float) -> bool:
	return _prev_t < at and t >= at


func tick(t: float) -> void:
	d.reset_post()
	var shot: int = 0
	for i: int in CUTS.size():
		if t >= CUTS[i]:
			shot = i
	var s0: float = CUTS[shot]
	var s1: float = CUTS[shot + 1] if shot + 1 < CUTS.size() else 17.0
	var k: float = D.span(t, s0, s1)
	d.set_post(&"white", D.pulse(t, s0, 0.12) * (0.8 if shot == 0 else 0.4))
	d.set_post(&"aberration", 0.6 + D.pulse(t, s0, 0.18) * 7.0)
	d.set_post(&"vignette", 0.5)
	d.set_post(&"grain", 0.03)
	# Çıkış ağacı: 3-2-1 sarı, GO yeşil
	var step: int = 4
	if t >= 12.15:
		step = 3
	if t >= 12.4:
		step = 2
	if t >= 12.65:
		step = 1
	if t >= GO:
		step = 0
	track.set_lights(step)
	var dist: Array[float] = [_distance(0, t), _distance(1, t)]
	if shot == 5:
		dist = _finish_distance(t)
	for i: int in 2:
		var car: Node3D = cars[i]
		var z: float = DragTrack.START_Z + dist[i]
		var rev: float = 1.0 if t < GO else 0.25
		car.position = Vector3(lanes[i], sin(t * 70.0 + i) * 0.0025 * rev, z)
		var tau: float = t - GO
		# Kalkışta burun kalkar, sonra oturur; vites anlarında küçük baş eğme
		var pitch: float = 0.0
		if tau > 0.0:
			pitch = -0.05 * exp(-tau * 3.0) * sin(minf(tau * 9.0, PI))
		for sh: float in SHIFTS:
			pitch += 0.02 * D.pulse(t, sh, 0.25)
		car.rotation = Vector3(pitch, 0.0, sin(t * 53.0 + i * 2.0) * 0.004 * rev)
		var moved: float = dist[i] - _prev_s[i] if _prev_t >= 0.0 else 0.0
		var spin: float = moved / (0.1 * CAR_SCALE)
		if t < GO + 0.3 and t > 12.3:
			spin += 0.9   # patinaj: teker yerinde döner
		rigs[i].spin_wheels(rad_to_deg(spin))
		_prev_s[i] = dist[i]
		fx[i].follow(car)
		var burn: float = 1.0 if (t > 12.3 and t < GO + 0.45) else 0.0
		fx[i].set_smoke(burn)
		for sh: float in SHIFTS:
			if _crossed(sh + i * 0.04, t):
				fx[i].flame(1.0)
		if _crossed(GO + 0.05, t):
			fx[i].flame(0.8)
	var mid: float = DragTrack.START_Z + (dist[0] + dist[1]) * 0.5
	var flow: float = 0.0
	match shot:
		0:
			# Önden: iki burun yan yana, ağaç ışıkları yanıyor (şerit çizgisinin dibinde değil, biraz yukarıda)
			var pos: Vector3 = Vector3(-0.15, 0.24, 2.3).lerp(Vector3(-0.1, 0.2, 1.9), D.smooth(k))
			D.look_cam(cam, pos + D.shake(t, 0.003, 3.0), Vector3(0.0, 0.14, -0.6))
			cam.fov = 32.0
		1:
			# Lambo arka teker: patinaj dumanı, egzoz (dış taraftan)
			var c: Vector3 = cars[0].position
			var pos: Vector3 = c + Vector3(-0.62, 0.08, -0.95).lerp(Vector3(-0.55, 0.07, -0.8), k)
			D.look_cam(cam, pos + D.shake(t, 0.006, 4.0), c + Vector3(-0.05, 0.1, -0.35), -4.0)
			cam.fov = 50.0
		2:
			# KALKIŞ: kamera Lambo şeridinin dışında yerde; araçlar kameranın dibinden fırlar
			var pos: Vector3 = Vector3(-LANE - 0.42, 0.07, 2.6)
			D.look_cam(cam, pos + D.shake(t, 0.02 * D.pulse(t, GO, 0.6) + 0.004, 3.0), Vector3(-0.15, 0.17, -0.5))
			cam.fov = 60.0
			d.set_post(&"white", maxf(D.pulse(t, GO, 0.1) * 0.6, 0.0))
			flow = D.span(t, GO + 0.3, GO + 0.9)
		3:
			# Yandan takip: dış taraftan, aracın hızında
			var pos: Vector3 = Vector3(-LANE - 1.05, 0.2, mid + 0.55)
			D.look_cam(cam, pos + D.shake(t, 0.012, 2.5), Vector3(0.1, 0.12, mid + 0.25), -2.0)
			cam.fov = 52.0
			flow = 0.8
		4:
			# Tepeden drone: pist ekranda yukarı akar (dikey kadraj)
			var pos: Vector3 = Vector3(0.0, 3.3, mid - 1.1)
			D.look_cam(cam, pos + D.shake(t, 0.01, 2.0), Vector3(0.0, 0.0, mid + 0.9), 0.0)
			cam.fov = 50.0
			flow = 1.0
		5:
			_shot_finish(t, k, dist)
	speed_rect.visible = flow > 0.01
	if speed_rect.visible:
		speed_mat.set_shader_parameter(&"intensity", flow)
		var a: Vector2 = cam.unproject_position(cars[0].position)
		var b: Vector2 = cam.unproject_position(cars[0].position + Vector3(0.0, 0.0, 1.0))
		var dir: Vector2 = (a - b)
		speed_mat.set_shader_parameter(&"flow", dir.normalized() if dir.length() > 0.001 else Vector2(0.0, 1.0))
		d.set_post(&"zoom_blur", flow * 0.35)
	_punch(title, t, 12.08, 16.88)
	_prev_t = t


## Bitiş: araçlar bitiş çizgisine gerçek hızla gelir, çizgide ağır çekim (0,12×), 16,55–17,0 donar.
func _finish_distance(t: float) -> Array[float]:
	var line: float = DragTrack.TRACK_LENGTH
	var v: float = 18.0
	# Zaman bükme: 16,1–16,25 gerçek hız, 16,25–16,45 yavaşlar, çizgide neredeyse durur, 16,55'te donar
	var local: float = 0.0
	var tt: float = CUTS[5]
	var dt: float = 1.0 / D.FPS
	while tt < t - 0.0001:
		var rate: float = 1.0
		if tt >= 16.25:
			rate = lerpf(1.0, 0.1, D.smooth(D.span(tt, 16.25, 16.45)))
		if tt >= 16.55:
			rate = 0.0
		local += dt * rate
		tt += dt
	var cross_local: float = (16.25 - CUTS[5]) + 0.2 * 0.55 + 0.1 * 0.1
	var nose: float = 0.5 * CAR_SCALE
	var base: float = line - DragTrack.START_Z - nose - v * (cross_local - local)
	return [base + 0.012, base - 0.012]


func _shot_finish(t: float, k: float, dist: Array[float]) -> void:
	var line_z: float = DragTrack.TRACK_LENGTH
	var freeze: float = D.span(t, 16.5, 16.6)
	# Bitiş çizgisinin dışından, çizgi hizasında alçak kamera; araçlar soldan gelip çizgiyi geçer
	var pos: Vector3 = Vector3(-LANE - 2.1, 0.2, line_z + 0.05).lerp(Vector3(-LANE - 1.8, 0.17, line_z + 0.1), D.smooth(k))
	D.look_cam(cam, pos + D.shake(t, 0.004 * (1.0 - freeze), 2.0), Vector3(0.2, 0.15, line_z - 0.15), -3.0)
	cam.fov = lerpf(40.0, 33.0, D.smooth(D.span(t, 16.2, 16.6)))
	# Foto finiş: donma anında beyaz flaş + soğuk ton
	d.set_post(&"white", maxf(D.pulse(t, CUTS[5], 0.12) * 0.4, D.pulse(t, 16.55, 0.18) * 0.9))
	if t >= 16.55:
		d.set_post(&"tint", Vector3(0.92, 0.98, 1.1))
		d.set_post(&"aberration", 2.0)
		d.set_post(&"vignette", 0.7)


func _punch(label: Label, t: float, at: float, out_at: float) -> void:
	if t < at:
		label.modulate.a = 0.0
		return
	var k: float = D.span(t, at, at + 0.16)
	label.modulate.a = D.ease_out(k, 2.0) * (1.0 - D.span(t, out_at, out_at + 0.1))
	var s: float = lerpf(1.7, 1.0, D.ease_out(k, 4.0)) + D.pulse(t, at + 0.16, 0.12) * 0.06
	for sh: float in SHIFTS:
		s += D.pulse(t, sh, 0.15) * 0.04
	label.scale = Vector2.ONE * s
	label.rotation = deg_to_rad(lerpf(-6.0, 0.0, D.ease_out(k, 3.0)))
