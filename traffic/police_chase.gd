class_name PoliceChase
extends Node
## POLİS KOVALAMACASI — oyun açıldıktan 15 sn sonra, sonra 2 dakikada bir (kullanıcı kararı) şehirde: ekran dışından normal trafikten çok hızlı bir şüpheli girer,
## kısa süre sonra arkasından polis (Vito ya da Bentley; tavan ışıkları çakar, siren çalar) daha da hızlı gelir.
## Aradaki mesafe yol boyunca kapanır; harita kenarında polis şüphelinin hemen arkasındadır — yakalama ekran
## dışında olur. Polis araçları oyuncunun edinebileceği araçlar DEĞİLDİR (cars.json "obtainable": false); yalnızca
## burada görünür. TrafficManager'ın çocuğu olarak kodla kurulur (sahne değişikliği yok).
##
## Sürüş: iki araç da kovalamacanın hazırladığı yol çizgisinde (spawn noktası → waypoint zinciri → kaybolma
## noktası), yolun ORTA çizgisinde gider (TrafficVehicle.Mode.CHASE). Konumu her karede bu düğüm verir:
## şüpheli sabit hızla, polis "şüphelinin ilerleme oranına göre küçülen mesafe" kadar geride — polis hep daha
## hızlıdır ama asla çarpmaz / geçmez. Normal trafik arkadan gelen ya da karşıdan yaklaşan kovalamacaya sağa
## çekilip yavaşlayarak yol verir (TrafficManager.chase_pressure); kovalamaca sürerken kavşakta karşı eksen bekler.
## Bir ekran (garaj, mağaza, pano) açıkken kovalamaca başlamaz, siren susar.

signal chase_started(police_id: StringName, suspect_id: StringName)
signal chase_finished

const POLICE_IDS: Array[StringName] = [&"police_vito", &"police_bentley"]
## Şüphelinin hızı (birim/sn). Normal trafik 0,55–0,9: kovalamaca ~2,2 kat hızlı.
const SUSPECT_SPEED: float = 1.9
## Polis şüpheli ile aynı noktadan bu kadar geride girer; yolun sonunda aradaki mesafe GAP_END'e iner
## (araç boyu trafikte ~0,6: sondaki mesafe polisin tamponu şüphelinin tamponuna değecek kadar).
const GAP_START: float = 2.6
const GAP_END: float = 0.72
## Şerit ortasından yolun orta çizgisine kayma (iki yönlü şeritlerin arası 0,6).
const CENTER_OFFSET: float = 0.3
## Şüphelinin zikzakı (yan sapma genliği, birim) ve hızı (rad/sn).
const WEAVE: float = 0.045
const WEAVE_RATE: float = 4.2
## Normal trafik bu mesafeden itibaren yol verir; kovalamaca geçtikten sonra bu mesafede şeridine döner.
const YIELD_DISTANCE: float = 3.2
const YIELD_AFTER: float = 1.2
## Başlayamadıysa (ekran açık, model yükleniyor, giriş dolu) bu kadar sonra yeniden dener.
const RETRY: float = 12.0
## Polis modeli kovalamacadan bu kadar önce arka planda yüklenmeye başlar.
const PRELOAD_LEAD: float = 20.0
## Emniyet: kovalamaca bu süreden uzun sürerse (araç takılırsa) kapatılır.
const MAX_DURATION: float = 40.0

## İlk kovalamaca oyun açıldıktan bu kadar sonra; sonrakiler bir öncekinin BİTİŞİNDEN interval sn sonra.
@export var first_delay: float = 15.0
@export var interval_min: float = 120.0
@export var interval_max: float = 120.0

var _manager: TrafficManager
var _siren: PoliceSiren
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0
var _police_id: StringName = &""
var _police_scene: PackedScene
var _loading: String = ""
var _suspect: TrafficVehicle
var _police: TrafficVehicle
var _spawn: TrafficWaypoint
var _points: PackedVector3Array = PackedVector3Array()
var _axis: int = 0
var _distance: float = 0.0     # şüphelinin yol çizgisindeki konumu
var _length: float = 0.0
var _core_end: float = 0.0     # bu konumdan sonra görünmeyen araç silinebilir (yol ucu dünyanın kenarına taşınmışsa)
var _elapsed: float = 0.0
var _active: bool = false
## Siren sesi polis modeliyle birlikte arka plan iş parçacığında sentezlenir (telefonda ana iş parçacığında
## ~100 ms'lik takılma olurdu). Sonuç ana iş parçacığında PoliceSiren önbelleğine konur.
var _siren_task: int = -1
var _siren_kind: PoliceSiren.Kind = PoliceSiren.Kind.WAIL
var _siren_result: AudioStreamWAV


func _ready() -> void:
	name = "PoliceChase"
	_manager = get_parent() as TrafficManager
	_rng.randomize()
	_timer = first_delay
	_siren = PoliceSiren.new()
	add_child(_siren)


func _physics_process(delta: float) -> void:
	if _active:
		_drive(delta)
		return
	_poll_loading()
	_timer -= delta
	if _timer <= PRELOAD_LEAD and _police_scene == null and _loading == "":
		_request_police()
	if _timer > 0.0:
		return
	if not start():
		_timer = RETRY


## Kovalamaca sürüyor mu?
func is_active() -> bool:
	return _active


## Canlı kovalamaca araçları (şüpheli, polis).
func vehicles() -> Array[TrafficVehicle]:
	var out: Array[TrafficVehicle] = []
	for vehicle: TrafficVehicle in [_suspect, _police]:
		if is_instance_valid(vehicle):
			out.append(vehicle)
	return out


func suspect() -> TrafficVehicle:
	return _suspect if is_instance_valid(_suspect) else null


func police() -> TrafficVehicle:
	return _police if is_instance_valid(_police) else null


## Kovalamaca bu eksenin kavşağa girişini tutuyor mu? (Kovalamacanın kendi ekseni geçer, karşı eksen bekler.)
func holds_crossing(axis: int) -> bool:
	return _active and axis != _axis


## Bir sonraki kovalamacaya kalan süre (sn).
func time_left() -> float:
	return _timer


## Şimdi başlat (QA / test). Polis modeli henüz yüklenmediyse eşzamanlı yüklenir. `lane`: belirli bir
## doğma noktası (verilmezse rastgele boş şerit); `police_id`: belirli polis aracı.
func start_now(lane: TrafficWaypoint = null, police_id: StringName = &"") -> bool:
	if police_id != &"" and police_id != _police_id:
		_police_scene = null
	if _police_scene == null:
		_police_id = police_id if police_id != &"" else POLICE_IDS[_rng.randi() % POLICE_IDS.size()]
		_police_scene = load(CarCatalog.scene_path(_police_id)) as PackedScene
		_loading = ""
	return start(true, lane)


## Kovalamacayı başlatır; koşullar uygun değilse false (zamanlayıcı RETRY sonra yeniden dener).
func start(ignore_screens: bool = false, lane: TrafficWaypoint = null) -> bool:
	if _active or _manager == null or _police_scene == null:
		return false
	if not ignore_screens and _screen_open():
		return false
	var model: Dictionary = _manager.random_city_model()
	if model.is_empty() or _manager.spawn_points.is_empty():
		return false
	var options: Array[TrafficWaypoint] = _manager.spawn_points.duplicate()
	options.shuffle()
	if lane:
		options = [lane]
	_spawn = null
	for point: TrafficWaypoint in options:
		if _manager.is_clear(_manager.hidden_start(point)) and not _route(point).is_empty():
			_spawn = point
			break
	if _spawn == null:
		return false
	_points = _route(_spawn)
	var direction: Vector3 = _points[1] - _points[0]
	_axis = 0 if absf(direction.x) >= absf(direction.z) else 1
	_suspect = _manager.spawn_chase_vehicle(_spawn, model, _manager.npc_appearance(model["id"]))
	_suspect.start_chase(_points, CENTER_OFFSET)
	_length = _suspect.chase_length()
	var end: TrafficWaypoint = _route_end(_spawn)
	_core_end = _length
	if end and end.has_meta(TrafficManager.CORE_META):
		var core: Vector3 = end.get_meta(TrafficManager.CORE_META)
		_core_end = _length - Vector2(end.global_position.x - core.x, end.global_position.z - core.z).length()
	_police = null
	_distance = 0.0
	_elapsed = 0.0
	_active = true
	chase_started.emit(_police_id, StringName(model["id"]))
	return true


func _drive(delta: float) -> void:
	_elapsed += delta
	_distance += SUSPECT_SPEED * delta
	var progress: float = clampf(_distance / maxf(_length, 0.001), 0.0, 1.0)
	if is_instance_valid(_suspect):
		_suspect.place_on_chase_path(minf(_distance, _length), WEAVE * sin(_elapsed * WEAVE_RATE))
		if _gone(_suspect, _distance):
			_suspect.queue_free()
			_suspect = null
	var behind: float = _distance - lerpf(GAP_START, GAP_END, smoothstep(0.0, 1.0, progress))
	if _police == null and behind >= 0.0 and _suspect != null:
		_police = _manager.spawn_chase_vehicle(_spawn, {"id": _police_id, "scene": _police_scene},
			_manager.npc_appearance(_police_id))
		_police.start_chase(_points, CENTER_OFFSET)
		_collect_siren(true)   # normalde çoktan bitmiştir (PRELOAD_LEAD önce başladı)
		_siren.follow(_police, PoliceSiren.kind_for(_police_id))
	if is_instance_valid(_police):
		_police.place_on_chase_path(clampf(behind, 0.0, _length))
		if _gone(_police, behind):
			_police.queue_free()
			_police = null
			_siren.stop()
	if (_suspect == null and _police == null) or _elapsed > MAX_DURATION:
		_finish()


## Araç yolun sonuna vardı ya da kenara taşınmış yol ucunun eski yerini geçip görünmez oldu mu?
func _gone(vehicle: TrafficVehicle, distance: float) -> bool:
	if distance >= _length:
		return true
	return distance > _core_end and _manager.is_hidden(vehicle.global_position)


func _finish() -> void:
	for vehicle: TrafficVehicle in vehicles():
		vehicle.queue_free()
	_suspect = null
	_police = null
	_siren.stop()
	_active = false
	_police_scene = null   # bellek: polis modeli bir sonraki kovalamacaya kadar tutulmaz
	_police_id = &""
	_timer = _rng.randf_range(interval_min, interval_max)
	chase_finished.emit()


## Doğma noktasından kaybolma noktasına yol çizgisi (ilk nokta: görünmeyen doğma yeri).
func _route(point: TrafficWaypoint) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array([_manager.hidden_start(point)])
	var at: TrafficWaypoint = point.pick_next()
	var guard: int = 0
	while at != null and guard < 64:
		out.append(at.global_position)
		if at.is_despawn:
			return out
		at = at.pick_next()
		guard += 1
	return PackedVector3Array()   # kaybolma noktasına varmayan zincir: kovalamacaya uygun değil


func _route_end(point: TrafficWaypoint) -> TrafficWaypoint:
	var at: TrafficWaypoint = point.pick_next()
	var guard: int = 0
	while at != null and not at.is_despawn and guard < 64:
		at = at.pick_next()
		guard += 1
	return at


func _request_police() -> void:
	_police_id = POLICE_IDS[_rng.randi() % POLICE_IDS.size()]
	var path: String = CarCatalog.scene_path(_police_id)
	if path != "" and ResourceLoader.load_threaded_request(path) == OK:
		_loading = path
	_siren_kind = PoliceSiren.kind_for(_police_id)
	if _siren_task < 0 and not PoliceSiren.has_stream(_siren_kind):
		_siren_task = WorkerThreadPool.add_task(_build_siren.bind(_siren_kind), false, "polis sireni")


## İş parçacığında: yalnızca bu düğümün alanına yazar (önbelleğe ana iş parçacığı koyar).
func _build_siren(kind: PoliceSiren.Kind) -> void:
	_siren_result = PoliceSiren.build(kind)


func _collect_siren(wait: bool) -> void:
	if _siren_task < 0 or (not wait and not WorkerThreadPool.is_task_completed(_siren_task)):
		return
	WorkerThreadPool.wait_for_task_completion(_siren_task)
	_siren_task = -1
	PoliceSiren.store(_siren_kind, _siren_result)
	_siren_result = null


func _exit_tree() -> void:
	_collect_siren(true)


func _poll_loading() -> void:
	_collect_siren(false)
	if _loading == "":
		return
	match ResourceLoader.load_threaded_get_status(_loading):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_police_scene = ResourceLoader.load_threaded_get(_loading) as PackedScene
	_loading = ""


func _screen_open() -> bool:
	var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter if is_inside_tree() else null
	return router != null and router.top() != &""
