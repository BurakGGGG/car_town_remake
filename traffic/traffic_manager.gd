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

## Aynı anda sahnedeki NPC üst sınırı (Car Town tarzı sakin trafik: 3–4). Yol kenarında tamir bekleyen
## ve CarSpot'taki araçlar da bu sayıya dahildir (4 = 3 trafik + 1 bekleyen); yolda hiçbir zaman 4'ten
## fazla NPC olmaz, tamirdeki araç yola dönünce yeni spawn açılmaz.
@export_range(1, 20) var max_vehicles: int = 4
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

var vehicles: Array[TrafficVehicle] = []
var spawn_points: Array[TrafficWaypoint] = []
var _spawn_timer: float = 0.0
var _crossing: Array[TrafficVehicle] = []   # şu an kavşakta (veya geçiş izni almış) araçlar
var _crossing_axis: int = -1                # kavşağı kullanan eksen (-1 = boş)
var _crossing_since: float = 0.0
var _waiting_axis: int = -1                 # geçiş bekleyen karşı eksen
var _candidates: Array[StringName] = []  # trafiğe uygun katalog id'leri (yalnızca id, model yok)
var _pool: Array[Dictionary] = []          # {id, scene}: yüklenmiş, spawn'a hazır modeller (en eski önde)
var _pending: Dictionary = {}              # id → scene_path (arka planda yükleniyor)
var _rotate_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
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
	if _spawn_timer <= 0.0 and vehicles.size() < max_vehicles:
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
		if _is_clear(point.global_position):
			_spawn_at(point)
			return true
	return false


func _spawn_at(point: TrafficWaypoint) -> void:
	var vehicle: TrafficVehicle = TrafficVehicle.new()
	vehicle.name = "Npc_%d" % (_rng.randi() % 100000)
	vehicle.max_speed = _rng.randf_range(min_speed, max_speed)
	vehicle.acceleration = _rng.randf_range(0.5, 0.8)
	add_child(vehicle)
	vehicle.setup(self, _pool.pick_random()["scene"], _random_appearance(), point, model_scale)
	vehicle.reached_despawn.connect(_on_vehicle_despawn)
	vehicles.append(vehicle)
	vehicle_spawned.emit(vehicle)


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
	for item: Dictionary in _pool:
		if item["id"] == id:
			return true
	return false


## Şu an bellekteki NPC modelleri (ölçüm / hata ayıklama).
func loaded_model_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Dictionary in _pool:
		out.append(item["id"])
	return out


func _random_appearance() -> CarAppearance:
	var appearance: CarAppearance = CarAppearance.new()  # NPC'ye özel; oyuncu araçlarının kaydına girmez
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

func _collect_spawn_points(node: Node) -> void:
	if node is TrafficWaypoint and (node as TrafficWaypoint).is_spawn:
		spawn_points.append(node)
	for child: Node in node.get_children():
		_collect_spawn_points(child)
