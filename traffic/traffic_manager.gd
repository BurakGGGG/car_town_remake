class_name TrafficManager
extends Node3D
## Şehir trafiği (Car Town tarzı): NPC araçları doğurur, listeler, düz hatlarda dolaştırır,
## takip mesafesi sorgularını ve kavşak geçiş sırasını yönetir.
## Waypoint'ler TrafficPath altındaki TrafficWaypoint node'larıdır (traffic.tscn içinde bakılmış):
## her hat düz bir başlangıç → bitiş rotasıdır; dönüş yok.
## Kavşak: doğu-batı ve kuzey-güney hatları kesiştiği için araçlar iç içe geçmesin diye
## eksen bazlı geçiş sırası vardır — aynı eksenin araçları birlikte geçer, karşı eksen bekler,
## uzun süre bekleyen eksen sıra alır.
## Araç modelleri: CarCatalog'dan (traffic=true kayıtlar). Aynı anda en fazla pool_size model
## bellekte tutulur (havuz); gerisi katalogda yalnızca metadata olarak durur. Havuz
## pool_rotate_interval'da bir başka bir katalog modeliyle tazelenir: yeni model arka planda
## (ResourceLoader threaded) yüklenir, havuzdan çıkan modelin sahnesi bırakılır ve son NPC'si
## despawn olunca (queue_free) mesh belleği kendiliğinden serbest kalır. Görünüm: NPC'ye özel
## CarAppearance kopyası + CarRig.
## Yarış rakibi için istenen trafiğe KAPALI modeller (S sınıfı) ayrı tutulur (_race_models): rakip o modelle
## gelir, ama şehirde rastgele doğan araçlar yalnızca şehir havuzundan (traffic=true) seçilir.

## Aynı anda sahnedeki NPC üst sınırı (Car Town tarzı sakin trafik: 3–4). Yol kenarında tamir bekleyen
## ve CarSpot'taki araçlar da bu sayıya dahildir (4 = 3 trafik + 1 bekleyen); yolda hiçbir zaman 4'ten
## fazla NPC olmaz, tamirdeki araç yola dönünce yeni spawn açılmaz.
@export_range(1, 20) var max_vehicles: int = 4
## YARIŞ ŞERİDİ — bu spawn noktası normal trafiğe KAPALIDIR. O şeride yalnızca RaceManager'ın
## davet araçları girer (şehir trafiği oraya araç koymaz). Boş bırakılırsa bütün şeritler normal
## trafiğe açılır.
@export var race_lane_spawn: StringName = &"N_in_spawn"
@export var spawn_interval: float = 2.0
## Bir eksen bu süreden uzun geçiyorsa ve karşı eksen bekliyorsa yeni araç almaz (adalet).
@export var crossing_max_hold: float = 4.0
@export var model_scale: float = 0.6
@export var min_speed: float = 0.55
@export var max_speed: float = 0.9
## Spawn noktası çevresinde bu mesafede araç varsa bekle.
@export var spawn_clearance: float = 1.6
## Aynı anda bellekte tutulan NPC model sayısı (katalog büyüse de bu sayı aşılmaz).
@export_range(1, 12) var pool_size: int = 4
## Havuzdaki bir model bu sürede bir katalogdan başka bir modelle değiştirilir (0 = sabit havuz).
@export var pool_rotate_interval: float = 45.0
@export var paint_palette: Array[Color] = [
	Color(0.93, 0.93, 0.92), Color(0.75, 0.76, 0.79), Color(0.12, 0.12, 0.13), Color(0.80, 0.14, 0.12),
	Color(0.15, 0.27, 0.50), Color(0.16, 0.40, 0.25), Color(0.45, 0.47, 0.50), Color(0.90, 0.62, 0.15),
]

## Yeni NPC sahneye eklendi ve kuruldu (tamir sistemi müşteri kararını bununla verir).
signal vehicle_spawned(vehicle: TrafficVehicle)

## Yol ucu dünyanın kenarına taşınmış (WorldDressing) doğma / kaybolma noktasının ESKİ konumu.
## Böyle bir noktada araç, eski konumdan başlayıp dışarı doğru kameranın görmediği İLK yerde doğar;
## kaybolma noktasına giderken eski konumu geçip görünmez olunca silinir. Varsayılan görünümde eski
## konumlar zaten ekran dışında: yolculuk süresi ve müşteri sıklığı değişmez. Oyuncu uzaklaşıp
## kenara baktığında araç yolun ortasında birden belirip kaybolmaz.
const CORE_META: StringName = &"core_position"
## Görünmezlik sınaması: aracın merkezi + gövdesinin uçları (en, boy, tavan) ekran dışında olmalı.
const HIDE_PROBES: Array[Vector3] = [Vector3.ZERO, Vector3(0.4, 0.0, 0.0), Vector3(-0.4, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.4), Vector3(0.0, 0.0, -0.4), Vector3(0.0, 0.35, 0.0)]
## Doğma yeri aranırken eski konumdan dışarı doğru adım.
const HIDE_STEP: float = 0.3
## Bellekte tutulan yarışa özel model sayısı (rakip değişince eskisi bırakılır).
const RACE_MODEL_LIMIT: int = 2

var vehicles: Array[TrafficVehicle] = []
var spawn_points: Array[TrafficWaypoint] = []
## Yarış şeridinin başı — `spawn_points` içinde DEĞİLDİR, yalnızca RaceManager kullanır.
var race_spawn_point: TrafficWaypoint
## Bütün yol noktaları (yarış rakibi yol kenarından akışa geri dönerken en yakın noktayı arar).
var waypoints: Array[TrafficWaypoint] = []
var _spawn_timer: float = 0.0
var _crossing: Array[TrafficVehicle] = []   # şu an kavşakta (veya geçiş izni almış) araçlar
var _crossing_axis: int = -1                # kavşağı kullanan eksen (-1 = boş)
var _crossing_since: float = 0.0
var _waiting_axis: int = -1                 # geçiş bekleyen karşı eksen
var _candidates: Array[StringName] = []  # trafiğe uygun katalog id'leri (yalnızca id, model yok)
var _pool: Array[Dictionary] = []          # {id, scene}: yüklenmiş, spawn'a hazır modeller (en eski önde)
## Yalnızca yarış rakibi için yüklenen, trafiğe KAPALI modeller (traffic=false: S sınıfı süper araçlar).
## Şehir havuzuna girmezler: eskiden rakip modeli havuza girince şehirde rastgele doğan araçların
## dörtte biri GT3 / Huracán / 488 oluyordu.
var _race_models: Array[Dictionary] = []
var _pending: Dictionary = {}              # id → scene_path (arka planda yükleniyor)
var _rotate_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("traffic")   # GameSettings düşük kalitede max_vehicles'ı azaltır
	_rng.randomize()
	_collect_spawn_points(self)
	for entry: Dictionary in CarCatalog.all():
		if entry["traffic"]:
			_candidates.append(entry["id"])
	for i: int in mini(pool_size, _candidates.size()):
		_request_model(_candidates[i])
	_rotate_timer = pool_rotate_interval
	_spawn_timer = 0.3


func _physics_process(delta: float) -> void:
	_poll_pending()
	_rotate_pool(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and city_vehicle_count() < max_vehicles:
		if _try_spawn():
			_spawn_timer = spawn_interval
		else:
			_spawn_timer = 0.5


# --- Spawn / despawn ---------------------------------------------------------

func _try_spawn() -> bool:
	if spawn_points.is_empty() or _pool.is_empty():
		return false
	var candidates: Array[TrafficWaypoint] = spawn_points.duplicate()
	candidates.shuffle()
	for point: TrafficWaypoint in candidates:
		var start: Vector3 = hidden_start(point)
		if _is_clear(start):
			_spawn_at(point, {}, start)
			return true
	return false


## Bu noktada doğacak aracın başlangıç yeri (CORE_META'ya bakın). Nokta taşınmamışsa kendisi.
func hidden_start(point: TrafficWaypoint) -> Vector3:
	if not point.has_meta(CORE_META):
		return point.global_position
	var core: Vector3 = point.get_meta(CORE_META)
	var far: Vector3 = point.global_position
	var steps: int = maxi(int(core.distance_to(far) / HIDE_STEP), 1)
	for i: int in steps + 1:
		var at: Vector3 = core.lerp(far, float(i) / float(steps))
		if is_hidden(at):
			return at
	return far


## Bu konumdaki bir araç kameradan görünmüyor mu? (Kamera yoksa — başsız testler — görünmez sayılır.)
func is_hidden(position: Vector3) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return true
	for probe: Vector3 in HIDE_PROBES:
		if camera.is_position_in_frustum(position + probe):
			return false
	return true


## Kaybolma noktasına giden araç erken silinebilir mi: noktanın eski konumunu geçti ve görünmüyor.
func can_leave_early(vehicle: TrafficVehicle, point: TrafficWaypoint) -> bool:
	if point == null or not point.is_despawn or not point.has_meta(CORE_META):
		return false
	var core: Vector3 = point.get_meta(CORE_META)
	var outward: Vector3 = point.global_position - core
	if outward.length_squared() < 0.0001 or (vehicle.global_position - core).dot(outward) < 0.0:
		return false
	return is_hidden(vehicle.global_position)


## Şehir trafiğindeki araç sayısı — yarış şeridindekiler SAYILMAZ (o şerit ayrı yönetiliyor,
## bekleyen bir rakip yüzünden şehir boşalmasın).
func city_vehicle_count() -> int:
	var total: int = 0
	for vehicle: TrafficVehicle in vehicles:
		if not vehicle.race_lane:
			total += 1
	return total


## Yarış daveti aracı: RaceManager çağırır, yarış şeridinin başında doğar. Aynı `vehicles`
## listesinde yaşar (takip mesafesi, kavşak ve kuyruk mantığı ortaktır) ama şehir sayacına girmez.
##
## `wanted` verilirse rakip TAM O MODELLE gelir — yoldan gelen araç ile yarışta çıkan araç aynı
## olsun diye (eskiden yoldan Getz geliyor, yarışta BMW başlıyordu). Model havuzda yoksa arka
## planda yüklenmeye başlar ve null döner; RaceManager birkaç saniye sonra yeniden dener.
func spawn_challenger(wanted: StringName = &"") -> TrafficVehicle:
	if race_spawn_point == null or _pool.is_empty():
		return null
	var start: Vector3 = hidden_start(race_spawn_point)
	if not _is_clear(start):
		return null   # şeritte hâlâ bekleyen biri var: sonra denenir
	var entry: Dictionary = {}
	if wanted != &"":
		entry = _pool_entry(wanted)
		if entry.is_empty():
			request_model(wanted)
			return null
	var vehicle: TrafficVehicle = _spawn_at(race_spawn_point, entry, start)
	vehicle.race_lane = true
	return vehicle


## Yüklenmiş model kaydı ({id, scene}; şehir havuzu ya da yarışa özel) — yoksa boş sözlük.
func _pool_entry(id: StringName) -> Dictionary:
	for entry: Dictionary in _pool + _race_models:
		if entry["id"] == id:
			return entry
	return {}


## Modeli arka planda yüklemeye başlar (RaceManager rakip modeli için kullanır).
func request_model(id: StringName) -> void:
	_request_model(id)


## Bu modelde ve bu görünümde bir araç doğurur (dil değişiminde tamir alanındaki aracı yeni sahnede
## aynen kurmak için; RepairManager hemen CarSpot'a ışınlar). Model henüz yüklenmemişse yüklemeyi
## başlatır ve null döner: çağıran sonraki karelerde yeniden dener.
func spawn_model(id: StringName, appearance: CarAppearance) -> TrafficVehicle:
	if spawn_points.is_empty():
		return null
	var entry: Dictionary = _pool_entry(id)
	if entry.is_empty():
		request_model(id)
		return null
	return _spawn_at(spawn_points[0], entry, Vector3.INF, appearance)


## `start`: doğma yeri (hidden_start); verilmezse noktanın kendisi. Araç noktadan bir sonrakine giden
## doğru üzerinde kalır, yönü ve hedefi değişmez. `appearance` verilmezse rastgele NPC görünümü.
func _spawn_at(point: TrafficWaypoint, entry: Dictionary = {}, start: Vector3 = Vector3.INF,
		appearance: CarAppearance = null) -> TrafficVehicle:
	var vehicle: TrafficVehicle = TrafficVehicle.new()
	vehicle.name = "Npc_%d" % (_rng.randi() % 100000)
	vehicle.max_speed = _rng.randf_range(min_speed, max_speed)
	vehicle.acceleration = _rng.randf_range(0.5, 0.8)
	add_child(vehicle)
	var model: Dictionary = entry if not entry.is_empty() else _pool.pick_random()
	vehicle.vehicle_id = model["id"]
	vehicle.setup(self, model["scene"], appearance if appearance else _random_appearance(model["id"]), point, model_scale)
	if start != Vector3.INF:
		vehicle.global_position = Vector3(start.x, vehicle.global_position.y, start.z)
	vehicle.reached_despawn.connect(_on_vehicle_despawn)
	vehicles.append(vehicle)
	vehicle_spawned.emit(vehicle)
	return vehicle


func _on_vehicle_despawn(vehicle: TrafficVehicle) -> void:
	vehicles.erase(vehicle)
	finish_crossing(vehicle)
	vehicle.queue_free()


# --- Model havuzu (tembel yükleme) ---------------------------------------------

## Katalog modelini arka planda yüklemeye başlar; hazır olunca _poll_pending havuza alır.
func _request_model(id: StringName) -> void:
	if _pending.has(id) or _pool_has(id):
		return
	var path: String = CarCatalog.scene_path(id)
	if path == "":
		push_warning("TrafficManager: katalogda '%s' için sahne yok" % id)
		return
	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_warning("TrafficManager: '%s' yükleme isteği başarısız (%d)" % [path, err])
		return
	_pending[id] = path


## Biten yüklemeleri havuza alır; havuz doluysa en eski model çıkar (sahnesi bırakılır).
func _poll_pending() -> void:
	if _pending.is_empty():
		return
	for id: StringName in _pending.keys():
		var path: String = _pending[id]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.THREAD_LOAD_LOADED:
				var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
				_pending.erase(id)
				if scene == null:
					continue
				if not _candidates.has(id):
					while _race_models.size() >= RACE_MODEL_LIMIT:
						_race_models.pop_front()
					_race_models.append({"id": id, "scene": scene})
					continue
				while _pool.size() >= pool_size:
					_pool.pop_front()
				_pool.append({"id": id, "scene": scene})
			_:
				push_warning("TrafficManager: '%s' yüklenemedi" % path)
				_pending.erase(id)


## Havuzu katalogdan başka bir modelle tazeler (katalog havuzdan büyükse).
func _rotate_pool(delta: float) -> void:
	if pool_rotate_interval <= 0.0 or _candidates.size() <= pool_size:
		return
	_rotate_timer -= delta
	if _rotate_timer > 0.0:
		return
	_rotate_timer = pool_rotate_interval
	var options: Array[StringName] = []
	for id: StringName in _candidates:
		if not _pool_has(id) and not _pending.has(id):
			options.append(id)
	if not options.is_empty():
		_request_model(options[_rng.randi() % options.size()])


func _pool_has(id: StringName) -> bool:
	return not _pool_entry(id).is_empty()


## Şu an bellekteki NPC modelleri (ölçüm / hata ayıklama; yarışa özel modeller dahil).
func loaded_model_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Dictionary in _pool + _race_models:
		out.append(item["id"])
	return out


## Şehirde rastgele doğabilecek modeller (yalnızca traffic=true).
func city_model_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Dictionary in _pool:
		out.append(item["id"])
	return out


func _random_appearance(id: StringName = &"") -> CarAppearance:
	var appearance: CarAppearance = CarAppearance.new()  # NPC'ye özel; oyuncu araçlarının kaydına girmez
	if not GameFeatures.PAINT:
		# Boya kapalıyken hiçbir araç rastgele renge boyanmaz: NPC de FABRİKA rengiyle çıkar.
		appearance.body_color = CarCatalog.default_color_for(CarCatalog.scene_path(id))
		return appearance
	appearance.body_color = paint_palette.pick_random() if not paint_palette.is_empty() else Color.WHITE
	if _rng.randf() < 0.2:
		appearance.wheel_color = Color(0.2, 0.2, 0.22)  # ara sıra koyu jant
	return appearance


## Bu noktanın spawn_clearance yarıçapında araç yok mu? (yola dönüş noktası seçimi de bunu kullanır)
func is_clear(position: Vector3) -> bool:
	return _is_clear(position)


func _is_clear(position: Vector3) -> bool:
	for vehicle: TrafficVehicle in vehicles:
		if vehicle.global_position.distance_to(position) < spawn_clearance:
			return false
	return true


# --- Takip mesafesi ----------------------------------------------------------

## Aracın önünde, aynı yönde ve yakın şeritte olan en yakın aracın mesafesi (yoksa INF).
func distance_to_vehicle_ahead(vehicle: TrafficVehicle) -> float:
	var forward: Vector3 = vehicle.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: float = INF
	for other: TrafficVehicle in vehicles:
		if other == vehicle or not other.blocks_traffic():
			continue  # yol kenarında bekleyen / CarSpot'taki araç trafiği durdurmaz
		var delta: Vector3 = other.global_position - vehicle.global_position
		delta.y = 0.0
		var along: float = delta.dot(forward)
		if along <= 0.0:
			continue
		var lateral: float = absf(delta.cross(forward).y)
		if lateral > 0.35:
			continue
		var other_forward: Vector3 = other.global_transform.basis.z
		other_forward.y = 0.0
		if other_forward.normalized().dot(forward) < 0.3:
			continue  # karşıdan gelen
		best = minf(best, along)
	return best


# --- Kavşak geçiş sırası (eksen bazlı) ------------------------------------------

## Araç kavşağa girebilir mi? Aynı eksen birlikte geçer; karşı eksen bekler.
## Karşı eksen crossing_max_hold'dan uzun beklediyse mevcut eksen yeni araç almaz.
func request_crossing(vehicle: TrafficVehicle) -> bool:
	_prune_crossing()
	if _crossing.has(vehicle):
		return true
	var now: float = Time.get_ticks_msec() / 1000.0
	if _crossing.is_empty():
		_crossing_axis = vehicle.axis
		_crossing_since = now
		_waiting_axis = -1
	elif vehicle.axis != _crossing_axis:
		_waiting_axis = vehicle.axis
		return false
	elif _waiting_axis != -1 and now - _crossing_since > crossing_max_hold:
		return false  # karşı eksen bekliyor: sıra ona geçsin
	_crossing.append(vehicle)
	return true


func finish_crossing(vehicle: TrafficVehicle) -> void:
	_crossing.erase(vehicle)
	if _crossing.is_empty():
		_crossing_axis = -1


func _prune_crossing() -> void:
	var alive: Array[TrafficVehicle] = []
	for v: TrafficVehicle in _crossing:
		if is_instance_valid(v):
			alive.append(v)
	_crossing = alive
	if _crossing.is_empty():
		_crossing_axis = -1


# --- Kurulum -------------------------------------------------------------------

## Aracın ÖNÜNDEKİ en yakın yol noktası (yol kenarında duran araç akışa böyle döner: ışınlanma yok).
## Aracın ÖNÜNDEKİ en yakın yol noktası. (Model önü +Z'dir — burada -Z yazıyordu, yani araç
## yarıştan/tamirden dönerken ARKASINDAKİ noktayı hedefleyip geri dönüyordu.)
func nearest_waypoint_ahead(vehicle: TrafficVehicle) -> TrafficWaypoint:
	var forward: Vector3 = vehicle.global_transform.basis.z
	var best: TrafficWaypoint = null
	var best_distance: float = 1e9
	for point: TrafficWaypoint in waypoints:
		var to_point: Vector3 = point.global_position - vehicle.global_position
		to_point.y = 0.0
		var distance: float = to_point.length()
		if distance < 0.2 or distance > best_distance:
			continue
		if forward.dot(to_point.normalized()) < 0.3:
			continue   # arkada kalan noktalar geri dönüş için uygun değil
		best = point
		best_distance = distance
	return best


func _collect_spawn_points(node: Node) -> void:
	if node is TrafficWaypoint:
		waypoints.append(node)
		if (node as TrafficWaypoint).is_spawn:
			if node.name == race_lane_spawn:
				race_spawn_point = node   # yarış şeridi: şehir trafiğine kapalı
			else:
				spawn_points.append(node)
	for child: Node in node.get_children():
		_collect_spawn_points(child)
