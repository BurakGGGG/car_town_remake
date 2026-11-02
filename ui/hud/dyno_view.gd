class_name DynoView
extends Node
## DİNO ATÖLYESİ SAHNESİ (2026-11-02, kullanıcı: "C dinamometre olsun, çizimini iyi yap, dinamometre gerçekçi olsun").
## Pişmiş oda (tools/garages/dynoroom.py → assets/garages/dynoroom/) garaj ekranının SubViewport'una kurulur (ModGarageView
## ile aynı yol: oda + "DynoStage", kamera / ışık ayarları kaydedilip çıkışta geri verilir). Bu düğüm aynı zamanda
## DENETLEYİCİDİR: fizik (DynoSim), motor sesi (EngineVoice) ve görseller (dönen merdaneler / tekerler / fan, araç
## titremesi, egzoz alevi) burada; DynoScreen (arayüz) yalnız girdiyi verir ve durumu okur.
##
## Yerleşim (Blender metresinde, dynoroom.py ile aynı): arka teker SABİT arka merdanenin üstüne (RearAxle işareti),
## ön merdane taşıyıcısı (FrontCarriage) ön tekerin altına kayar, fan aracın burnunun önüne taşınır (uzun araçta
## rampanın önüne, zemine), gergi kayışları dört köşeden en yakın halkalara, egzoz emiş hortumu tavandaki makaradan
## (HoseStart) egzoz ucuna kodla kurulur.
## Kullanıcı kararları (2026-11-02): tek kamera (sağ ön 3/4), START yok — araç atölyeye ÇALIŞIR hâlde gelir (marş sesi
## yok, rölanti kısa sürede açılır), vites yok, DİNO KOŞUSU düğmesi yok: rölantiden kesiciye her tam gaz çekiş bir ÖLÇÜMDÜR
## (DynoSim.pulls), tepe gücü en iyi ölçüm olarak kaydedilir (pull_measured). Yalnız çeken aksın merdanesi ve tekerleri
## döner (FWD ön, RWD arka, AWD ikisi). Açıkken garaj müziği kısılır (GameMusic.dyno), motor sesi öne çıkar: kendi BUS'ı
## (sert sınırlayıcı → SFX) sayesinde yüksek çalınır, tam gazda / patlamada kırpılmaz; rölanti ile tam gaz arası farkın
## yalnız bir kısmı çalınır (DYNAMICS), rölanti de dolgun duyulur (kullanıcı: "dinamometrede motor sesi çok az").

## Rölantiden kesiciye tam gaz çekiş bitti: tepe güç (gösterge ölçeği) ve yeni rekor mu.
signal pull_measured(peak_hp: float, record: bool)

const GARAGE: StringName = &"dynoroom"
## dynoroom.py ile aynı (Blender metresi)
const CX: float = 6.2
const DECK: float = 0.36
const WB_MIN: float = 1.75
const WB_MAX: float = 4.7
const FRAME_FRONT_FROM_REAR: float = 6.1     # REAR_Y − FRAME_Y0
const RAMP_L: float = 1.5
const FAN_GAP: float = 1.25
const ROOM_MAX: Vector2 = Vector2(12.3, 14.3)
const ROOM_MIN: Vector2 = Vector2(0.7, 0.7)
## Dikey görüş açısı (Blender 24 mm, 16:9).
const FOV_WIDE: float = 45.7
## Motor sesi: kendi bus'ı (sınırlayıcı tavanı) → SFX. Düzey (yarışta oyuncu motoru −6 dB, SFX'e doğrudan), katman
## farklarının çalınan payı ve fan dönüşü (tur/sn).
const BUS: StringName = &"DynoEngine"
const ENGINE_DB: float = 6.0
const DYNAMICS: float = 0.6
const LIMIT_CEILING_DB: float = -1.0
const FAN_RPS: float = 6.0
const STRAP_COLOR: Color = Color("E8701A")

var active: bool = false
var vehicle_id: StringName = &""
var interior: GarageInterior
var sim: DynoSim
var voice: EngineVoice

var _root: Node
var _camera: Camera3D
var _key: DirectionalLight3D
var _saved: Dictionary = {}
var _hidden: Array[Node3D] = []
var _stage: Node3D
var _car: Node3D
var _rig: CarRig
var _fx: DragFx
var _player: AudioStreamPlayer
var _drum_front: Node3D
var _drum_rear: Node3D
var _carriage: Node3D
var _fan: Node3D
var _fan_blades: Node3D
var _car_home: Vector3
var _bounds: AABB                 # aracın dünya sınırları (yerleştirildikten sonra)
var _front_axle_z: float = 0.0
var _rear_axle_z: float = 0.0
var _exhaust: Vector3
var _fan_angle: float = 0.0
var _fan_speed: float = 0.0
var _pulls_seen: int = 0
var _time: float = 0.0


func _ready() -> void:
	set_process(false)


## Atölyeyi açar: oda `root`a kurulur, araç dinoya konur, `hide` düğümleri gizlenir. Sahne / araç yoksa false.
func enter(vehicle: StringName, root: Node, camera: Camera3D, key_light: DirectionalLight3D, hide: Array[Node3D]) -> bool:
	exit()
	var created: GarageInterior = GarageInterior.create(GARAGE)
	if created == null:
		return false
	interior = created
	vehicle_id = vehicle
	_root = root
	_camera = camera
	_key = key_light
	_saved = {
		"projection": camera.projection, "size": camera.size, "fov": camera.fov, "keep_aspect": camera.keep_aspect,
		"transform": camera.transform, "environment": camera.environment, "near": camera.near, "far": camera.far,
		"v_offset": camera.v_offset, "h_offset": camera.h_offset,
		"key_transform": key_light.transform if key_light else Transform3D(), "key_color": key_light.light_color if key_light else Color.WHITE,
		"key_energy": key_light.light_energy if key_light else 1.0, "key_shadow": key_light.shadow_enabled if key_light else false,
		"key_mask": key_light.light_cull_mask if key_light else 0xFFFFFFFF,
	}
	_hidden.clear()
	for node: Node3D in hide:
		if node and node.visible:
			node.visible = false
			_hidden.append(node)
	root.add_child(interior)
	_stage = Node3D.new()
	_stage.name = "DynoStage"
	root.add_child(_stage)
	_configure()
	if not _spawn_car():
		exit()
		return false
	_drum_front = node("DrumFront")
	_drum_rear = node("DrumRear")
	_carriage = node("FrontCarriage")
	_fan = node("Fan")
	_fan_blades = node("FanBlades")
	# Dönen parçalar pişmiş ışıkla çizilmez: ışık geometriye yapışık döner (çukurun karanlık alt yüzü üste gelip merdane
	# görünmez oluyordu) → gerçek zamanlı ışıklı metal (araç gibi; ışık dünyada sabit, tırtıllar döndükçe parlar)
	_shade(_drum_front, Color("8A9097"), 0.85, 0.32)
	_shade(_drum_rear, Color("8A9097"), 0.85, 0.32)
	_shade(_fan_blades, Color("3A3E44"), 0.5, 0.45)
	_place_rig()
	sim = DynoSim.new(vehicle)
	_player = AudioStreamPlayer.new()
	_player.name = "DynoEngine"
	_player.bus = _ensure_bus()
	_player.volume_db = ENGINE_DB
	add_child(_player)
	voice = EngineVoice.new(_player, RaceAudio.bank_for(vehicle))
	voice.dynamics = DYNAMICS
	voice.popped.connect(_on_popped)
	# Araç çalışır hâlde gelir: fizik rölantide, ses marşsız açılır
	sim.start_engine()
	voice.resume()
	active = true
	_time = 0.0
	_pulls_seen = 0
	_apply_camera(_shot())
	set_process(true)
	if is_inside_tree():
		GameMusic.dyno(get_tree(), true)
	return true


func exit() -> void:
	if not active and interior == null:
		return
	active = false
	set_process(false)
	if is_inside_tree():
		GameMusic.dyno(get_tree(), false)
	if voice:
		voice.stop_all()
	voice = null
	sim = null
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null
	_car = null
	_rig = null
	_fx = null
	_drum_front = null
	_drum_rear = null
	_carriage = null
	_fan = null
	_fan_blades = null
	for node: Node in [_stage, interior]:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	_stage = null
	interior = null
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	if is_instance_valid(_camera) and not _saved.is_empty():
		for key: String in ["projection", "size", "fov", "keep_aspect", "transform", "environment", "near", "far", "v_offset",
				"h_offset"]:
			_camera.set(key, _saved[key])
	if is_instance_valid(_key) and not _saved.is_empty():
		_key.transform = _saved["key_transform"]
		_key.light_color = _saved["key_color"]
		_key.light_energy = _saved["key_energy"]
		_key.shadow_enabled = _saved["key_shadow"]
		_key.light_cull_mask = _saved["key_mask"]
	_saved.clear()


# --- Girdi (DynoScreen) -----------------------------------------------------------------------------

## Atölyenin (iç içe olabilen) düğümü: ön merdane taşıyıcının, kanatlar fanın altında (GarageInterior.part yalnız üst düzey).
func node(node_name: String) -> Node3D:
	return interior.find_child(node_name, true, false) as Node3D if interior else null


func set_throttle(value: float) -> void:
	if sim:
		sim.throttle = clampf(value, 0.0, 1.0)


func is_engine_on() -> bool:
	return sim != null and sim.running


## Motor sesinin bus'ı: yoksa kurulur (sert sınırlayıcı, çıkışı SFX → ayarlardaki efekt düzeyi uygulanır).
static func _ensure_bus() -> StringName:
	if AudioServer.get_bus_index(BUS) >= 0:
		return BUS
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, GameSettings.SFX_BUS)
	var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMIT_CEILING_DB
	limiter.release = 0.15
	AudioServer.add_bus_effect(index, limiter)
	return BUS


# --- Kare ----------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active or sim == null:
		return
	_time += delta
	sim.step(delta)
	var bank: EngineBank = voice.bank
	voice.update(delta, _sound_rpm(bank), sim.throttle if sim.running else 0.0, sim.limiter)
	if sim.pulls != _pulls_seen:
		_pulls_seen = sim.pulls
		_on_pull()
	_animate(delta)


## Fizik devri → ses bankasının devri (rölanti–kırmızı aralığına oranla; RaceAudio.sound_rpm ile aynı).
func _sound_rpm(bank: EngineBank) -> float:
	var x: float = (sim.rpm - sim.spec.idle_rpm) / maxf(sim.spec.redline_rpm - sim.spec.idle_rpm, 1.0)
	var low: float = maxf(bank.idle_rpm(), 600.0) if not bank.is_electric() else 400.0
	if bank.is_electric():
		x = sim.rpm / maxf(sim.spec.redline_rpm, 1.0)
	return maxf(low + x * (bank.redline_rpm() - low), 0.0)


## Tam gaz çekiş bitti: tepe güç en iyi ölçüm adayı.
func _on_pull() -> void:
	var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
	var record: bool = mods != null and mods.record_dyno(vehicle_id, sim.peak_hp)
	pull_measured.emit(sim.peak_hp, record)


func best_hp() -> float:
	var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
	return mods.dyno_best(vehicle_id) if mods else 0.0


func _animate(delta: float) -> void:
	# Yalnız çeken aks döner (öbür aksın tekerleri ve merdanesi durur)
	if _drum_front:
		_drum_front.rotation.x = -sim.drum_angle if sim.drives_front else 0.0
	if _drum_rear:
		_drum_rear.rotation.x = -sim.drum_angle if sim.drives_rear else 0.0
	if _rig:
		var wheel: float = rad_to_deg(sim.wheel_angle)
		_rig.set_axle_spin(wheel if sim.drives_front else 0.0, wheel if sim.drives_rear else 0.0)
	# Fan: motor çalışırken döner (yavaşça hızlanır / durur)
	_fan_speed = move_toward(_fan_speed, FAN_RPS if sim.running else 0.0, delta * 2.5)
	_fan_angle = fposmod(_fan_angle + _fan_speed * TAU * delta, TAU)
	if _fan_blades:
		_fan_blades.rotation.z = _fan_angle
	# Motor titremesi: rölantide hafif, devirle ve gazla artar
	if _car and sim.running:
		var amp: float = (0.00025 + 0.0009 * sim.rpm_ratio() + 0.0006 * sim.throttle)
		var f: float = maxf(sim.rpm, 600.0) / 60.0
		_car.position = _car_home + Vector3(sin(_time * f * 0.9) * amp * 0.5, absf(sin(_time * f * 1.3)) * amp,
			0.0)
	elif _car:
		_car.position = _car_home


func _shade(target: Node3D, color: Color, metal: float, rough: float) -> void:
	var mesh: MeshInstance3D = target as MeshInstance3D
	if mesh == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	mesh.material_override = material


func _on_popped(strength: float) -> void:
	if _fx:
		_fx.flame(clampf(strength, 0.2, 1.0) * 0.85)


# --- Kurulum ------------------------------------------------------------------------------------------

func _configure() -> void:
	var setup: Dictionary = interior.setup()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.02
	_camera.far = 60.0
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = setup["background"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = setup["ambient"]
	env.ambient_light_energy = float(setup["ambient_energy"])
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # oda pişmiş ekran değeri
	_camera.environment = env
	if _key:
		_key.global_basis = Basis.looking_at(GarageInterior.blender_dir(setup["key_dir"]), Vector3.UP)
		_key.light_color = setup["key_color"]
		_key.light_energy = float(setup["key_energy"])
		_key.shadow_enabled = false
		_key.light_cull_mask = 0xFFFFFFFF


func _spawn_car() -> bool:
	var scene_path: String = CarCatalog.scene_path(vehicle_id)
	var scene: PackedScene = load(scene_path) as PackedScene if scene_path != "" else null
	if scene == null:
		return false
	var at: Vector3 = interior.marker("RearAxle").origin
	_car = scene.instantiate() as Node3D
	_car.name = String(vehicle_id)
	_stage.add_child(_car)
	_car.scale = Vector3.ONE * CarCatalog.model_scale(vehicle_id)
	_car.global_position = at
	_rig = CarRig.for_node(_car)
	_rig.apply(CarAppearance.get_for(scene_path))
	_rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	_rig.optimize(false)   # tekerler ayrı: merdanede döner
	for node: Node in _car.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Arka teker arka merdanenin tepesine, araç dinonun ortasına
	var bounds: AABB = _world_bounds(_car)
	var rear: Vector3 = _axle(false)
	var offset: Vector3 = Vector3(at.x - bounds.get_center().x, at.y - bounds.position.y, at.z - rear.z)
	_car.global_position += offset
	_car_home = _car.position
	_bounds = AABB(bounds.position + offset, bounds.size)
	_rear_axle_z = rear.z + offset.z
	_front_axle_z = _axle(true).z
	_exhaust = _exhaust_point()
	_fx = DragFx.new(_bounds.size.z)
	_stage.add_child(_fx)
	var length: float = _bounds.size.z
	_fx.global_position = _exhaust - Vector3(0.0, 0.12 * length, -0.6 * length)
	return true


## Ön taşıyıcı, fan, kayışlar, hortum: araca göre.
func _place_rig() -> void:
	var m: float = GarageInterior.METER
	if _carriage:
		var near_z: float = _rear_axle_z + WB_MIN * m
		var far_z: float = _rear_axle_z + WB_MAX * m
		var p: Vector3 = _carriage.global_position
		_carriage.global_position = Vector3(p.x, p.y, clampf(_front_axle_z, near_z, far_z))
	if _fan:
		var deck_front_z: float = _rear_axle_z + (FRAME_FRONT_FROM_REAR - 0.5) * m
		var fan_z: float = _bounds.end.z + FAN_GAP * m
		var p: Vector3 = _fan.global_position
		if fan_z <= deck_front_z:
			_fan.global_position = Vector3(p.x, interior.marker("RearAxle").origin.y - 0.03 * m, fan_z)
		else:
			_fan.global_position = Vector3(p.x, interior.blender_point(Vector3(CX, 0.0, 0.0)).y,
				_rear_axle_z + (FRAME_FRONT_FROM_REAR + RAMP_L + 0.7) * m)
	_build_straps()
	_build_hose()


func _build_straps() -> void:
	var m: float = GarageInterior.METER
	var cx: float = _bounds.get_center().x
	var y: float = _bounds.position.y + 0.22 * m
	for front: bool in [true, false]:
		var tow_z: float = (_bounds.end.z - 0.35 * m) if front else (_bounds.position.z + 0.35 * m)
		for side: int in [-1, 1]:
			var top: Vector3 = Vector3(cx + side * 0.55 * m, y, tow_z)
			var anchor: Vector3 = _anchor_for(front, side, tow_z + (1.4 * m if front else -1.4 * m))
			_strap(top, anchor)


func _anchor_for(front: bool, side: int, want_z: float) -> Vector3:
	var suffix: String = "_L" if side < 0 else "_R"
	var names: Array[String] = ["Anchor_R0"]
	if front:
		names = ["Anchor_F0", "Anchor_F1", "Anchor_F2"]
	var best: Vector3 = Vector3.ZERO
	var best_err: float = INF
	for n: String in names:
		var p: Vector3 = interior.marker(n + suffix).origin
		var err: float = absf(p.z - want_z)
		if err < best_err:
			best_err = err
			best = p
	return best


## Kayış: kumaş şerit (ince kutu) + ortada cırcır.
func _strap(a: Vector3, b: Vector3) -> void:
	var m: float = GarageInterior.METER
	var strap: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.05 * m, 0.012 * m, a.distance_to(b))
	strap.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = STRAP_COLOR
	material.roughness = 0.8
	strap.material_override = material
	strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(strap)
	strap.global_position = (a + b) * 0.5
	strap.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	var ratchet: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.09 * m, 0.06 * m, 0.15 * m)
	ratchet.mesh = box
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color("B9BEC4")
	steel.metallic = 0.8
	steel.roughness = 0.35
	ratchet.material_override = steel
	_stage.add_child(ratchet)
	ratchet.global_position = a.lerp(b, 0.45)
	ratchet.global_basis = strap.global_basis


## Egzoz emiş hortumu: makaradan (HoseStart) egzoz ucunun hemen arkasına sarkan körüklü boru + huni.
func _build_hose() -> void:
	var m: float = GarageInterior.METER
	var start: Vector3 = interior.marker("HoseStart").origin
	var end: Vector3 = _exhaust - Vector3(0.0, 0.0, 0.55 * m)
	# Kübik Bézier: makaradan aşağı sarkar, egzozun arkasından YATAY gelip huniye girer
	var p1: Vector3 = start + Vector3(0.0, -1.6 * m, 0.0)
	var p2: Vector3 = end + Vector3(0.0, 0.05 * m, -1.1 * m)
	var points: PackedVector3Array = PackedVector3Array()
	var n: int = 90
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		var u: float = 1.0 - t
		points.append(start * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + end * t * t * t)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 10
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i: int in points.size():
		var dir: Vector3 = (points[mini(i + 1, n)] - points[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = dir.cross(Vector3.UP).normalized()
		if side.length() < 0.01:
			side = Vector3.RIGHT
		var up: Vector3 = side.cross(dir).normalized()
		var r: float = (0.082 if i % 2 == 0 else 0.072) * m
		var ring: PackedVector3Array = PackedVector3Array()
		var ring_n: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides)
			var offset: Vector3 = side * cos(a) + up * sin(a)
			ring.append(points[i] + offset * r)
			ring_n.append(offset)
		rings.append(ring)
		normals.append(ring_n)
	for i: int in n:
		for k: int in sides:
			var k2: int = (k + 1) % sides
			for idx: Array in [[i, k], [i + 1, k], [i + 1, k2], [i, k], [i + 1, k2], [i, k2]]:
				st.set_normal(normals[idx[0]][idx[1]])
				st.add_vertex(rings[idx[0]][idx[1]])
	var hose: MeshInstance3D = MeshInstance3D.new()
	hose.mesh = st.commit()
	var rubber: StandardMaterial3D = StandardMaterial3D.new()
	rubber.albedo_color = Color("1D1E21")
	rubber.roughness = 0.75
	hose.material_override = rubber
	hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(hose)
	# Huni: egzoza bakan geniş ağız
	var funnel: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.075 * m
	cone.bottom_radius = 0.14 * m
	cone.height = 0.3 * m
	cone.radial_segments = 16
	funnel.mesh = cone
	funnel.material_override = rubber
	_stage.add_child(funnel)
	funnel.global_position = end + Vector3(0.0, 0.0, 0.17 * m)
	funnel.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # geniş ağız +Z'ye (egzoza)


# --- Kamera -------------------------------------------------------------------------------------------

## Çekim: [konum, hedef, dikey fov] — Blender metresinde araca göre kurulur (sağ ön 3/4; dynoroom.py "dyno" açısı).
func _shot() -> Array:
	var center: Vector3 = _to_blender(_bounds.get_center())
	var cam: Vector3 = Vector3(center.x + 5.6, center.y - 6.2, 2.6)
	var target: Vector3 = Vector3(center.x - 0.4, center.y + 0.3, 0.75)
	cam.x = clampf(cam.x, ROOM_MIN.x, ROOM_MAX.x)
	cam.y = clampf(cam.y, ROOM_MIN.y, ROOM_MAX.y)
	return [interior.blender_point(cam), interior.blender_point(target), FOV_WIDE]


func _apply_camera(shot: Array) -> void:
	_camera.global_position = shot[0]
	_camera.look_at(shot[1], Vector3.UP)
	_camera.fov = float(shot[2])


## Dünya → Blender metresi (X doğu, Y kuzey, Z yukarı).
func _to_blender(world: Vector3) -> Vector3:
	var local: Vector3 = interior.to_local(world)
	return Vector3(local.x, -local.z, local.y)


# --- Ölçüm --------------------------------------------------------------------------------------------

func _axle(front: bool) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for wheel: Dictionary in _rig.wheel_points():
		if bool(wheel["front"]) == front:
			sum += wheel["position"]
			count += 1
	if count == 0:   # tekersiz model: uçlardan tahmin
		var b: AABB = _world_bounds(_car)
		return Vector3(b.get_center().x, b.position.y, b.end.z - b.size.z * 0.2 if front else b.position.z + b.size.z * 0.2)
	return sum / float(count)


## Egzoz ucu (dünya): egzoz rolündeki parçaların ortası; yoksa arka tamponun altı.
func _exhaust_point() -> Vector3:
	var merged: AABB = AABB()
	var found: bool = false
	for mesh: MeshInstance3D in _rig.get_meshes(&"exhaust"):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	if found:
		var c: Vector3 = merged.get_center()
		return Vector3(c.x, c.y, merged.position.z)
	return Vector3(_bounds.get_center().x + _bounds.size.x * 0.25, _bounds.position.y + _bounds.size.y * 0.22,
		_bounds.position.z)


## Hızlı (kaba) dünya sınırları: mesh kutularının köşelerinden — dönük düğümde biraz şişer ama ucuz (araca dokununca
## beliren plakanın yeri için yeter; dinoya yerleştirme _world_bounds ile).
static func quick_bounds(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Köşe noktalarından dünya sınırları (dönük düğümlerde mesh AABB'si şişer: E60 tuzağı).
static func _world_bounds(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf: Transform3D = mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = xf * v
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box
