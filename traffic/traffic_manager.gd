class_name TrafficManager
extends Node3D
## Şehir trafiği (Car Town tarzı): NPC araçları doğurur, listeler, düz hatlarda dolaştırır,
## takip mesafesi sorgularını ve kavşak geçiş sırasını yönetir.
## Waypoint'ler TrafficPath altındaki TrafficWaypoint node'larıdır (traffic.tscn içinde bakılmış):
## her hat düz bir başlangıç → bitiş rotasıdır; dönüş yok.
## Kavşak: doğu-batı ve kuzey-güney hatları kesiştiği için araçlar iç içe geçmesin diye
## eksen bazlı geçiş sırası vardır — aynı eksenin araçları birlikte geçer, karşı eksen bekler,
## uzun süre bekleyen eksen sıra alır. TRAFİK LAMBASI varsa (TrafficLights, WorldDressing kurar) araç
## kavşağa yalnızca kendi ekseni YEŞİLKEN girer; eksen kilidi yine geçerlidir (kavşaktaki araç boşaltır).
## Araç modelleri: CarCatalog'dan (traffic=true kayıtlar). Aynı anda en fazla pool_size model
## bellekte tutulur (havuz); gerisi katalogda yalnızca metadata olarak durur. Havuz
## pool_rotate_interval'da bir başka bir katalog modeliyle tazelenir: yeni model arka planda
## (ResourceLoader threaded) yüklenir, havuzdan çıkan modelin sahnesi bırakılır ve son NPC'si
## despawn olunca (queue_free) mesh belleği kendiliğinden serbest kalır. Görünüm: NPC'ye özel
## CarAppearance kopyası + CarRig.
## AYNI MODELDEN TEK ARAÇ: şehirde (yol, kenarda bekleyen müşteri, liftteki araç, yarış rakibi, kovalamaca
## şüphelisi / polisi) bir modelden aynı anda EN FAZLA BİR araç bulunur — trafik çeşitli görünsün. Rastgele doğan
## araç ve şüpheli havuzun KULLANILMAYAN modellerinden seçilir; hepsi kullanımdaysa kullanılmayan bir katalog
## modeli yüklenir ve araç o hazır olunca doğar. Havuz dolunca önce kullanımdaki (zaten sahnede olan) model
## çıkarılır, boştaki modeller doğmaya hazır kalır. Yarış rakibinin modelini RaceManager yine boştakilerden seçer.
## Yarış rakibi için istenen trafiğe KAPALI modeller (S sınıfı) ayrı tutulur (_race_models): rakip o modelle
## gelir, ama şehirde rastgele doğan araçlar yalnızca şehir havuzundan (traffic=true) seçilir.
## KAÇAN KAYBEDEN: yarışı oyuncuya kaybeden rakip (TrafficVehicle.flee) kırmızıya bakmadan kaçar; yaklaşırken kavşağı
## talep eder (runner_crossing) — karşı eksen yeşilde bile yeni araç sokamaz, bekletilen araç korna çalar; trafik ona
## kovalamacadaki gibi yol verir (chase_pressure). Kalkışta lastik sesi (TrafficSfx).
## EGZOTİK ARAÇ (2026-10-17, kullanıcı: "trafikte tek tük egzotik araç geçsin, 20'de 1"): rastgele doğan araçların
## ortalama EXOTIC_EVERY'de biri trafiğe kapalı süper araçlardan (cars.json "exotic": GT3 / Huracán / 488 Pista / iki Bugatti / LaFerrari) biridir;
## art arda gelmesin diye arada en az EXOTIC_MIN_GAP araç olur. Sıra gelince model hemen arka planda yüklenir (yarışa
## özel modellerin yanına), araç doğunca listeden düşer (sahnesini araç tutar). Egzotik yalnızca GEÇER: tamir müşterisi
## olmaz (RepairManager). Motor sesi CityAmbience'ta (ExoticEngine).
## TRAFİK POLİSİ (TrafficPolice, çocuk düğüm): araçlar birbirini bekleyip kilitlenince (find_deadlock) karşı şeritten polis
## gelir, kilidin önünde durup siren çalar, en öndeki aracı geçirir.
## Polis kovalamacası: PoliceChase (çocuk düğüm, kodla kurulur) açılıştan 15 sn sonra, sonra 2 dakikada bir şüpheli + polis gönderir;
## bu araçlar `vehicles` listesinde DEĞİLDİR (sayılmaz, müşteri / rakip olmaz). Trafik onlara yol verir
## (chase_pressure) ve kovalamaca sürerken kavşakta karşı eksen bekler.

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
## Bir araç dörtlü yakıp durdu (start_hazard).
signal hazard_started(vehicle: TrafficVehicle)
## Süper araç ışıktan gaza basıp kalktı (TrafficVehicle.start_launch): CityAmbience lastik cıyağı çalar.
signal vehicle_launched(vehicle: TrafficVehicle)

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
## Egzotik araç ortalama bu kadar rastgele doğumda bir, en az EXOTIC_MIN_GAP normal araçtan sonra gelir: aradan sonraki
## her doğumda 1 / (EXOTIC_EVERY − EXOTIC_MIN_GAP) şansla sıra gelir → ortalama aralık tam EXOTIC_EVERY.
const EXOTIC_EVERY: int = 20
const EXOTIC_MIN_GAP: int = 8
## Takip mesafelerinin (TrafficVehicle.stop_distance / follow_distance) varsaydığı iki yarım boy: burun 0,3 + 0,3.
const NOMINAL_LENGTH: float = 0.6
## Bu hızın altındaki araç "duruyor" sayılır (kilit araması).
const STILL_SPEED: float = 0.03
## DÖRTLÜ (2026-10-20, kullanıcı: "araçlar bazı yerlerde durup dörtlü yaksınlar, 3–5 saniye sonra devam etsinler,
## nadir olarak"): HAZARD_GAP'te bir, ekranda görünen uygun bir araç HAZARD_TIME saniye durur. Görünen uygun araç
## yoksa HAZARD_RETRY sonra yeniden bakılır (ekran dışında durması boşa olur).
const HAZARD_GAP: Vector2 = Vector2(50.0, 110.0)
const HAZARD_TIME: Vector2 = Vector2(3.0, 5.0)
const HAZARD_RETRY: float = 6.0

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
var _exotics: Array[StringName] = []       # cars.json "exotic" modelleri
var _since_exotic: int = 0                 # son egzotikten beri doğan rastgele araç
var _exotic_next: StringName = &""         # sırası gelen egzotik (yükleniyor / doğmayı bekliyor)
var _rotate_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var chase: PoliceChase
var police: TrafficPolice
## Kavşağın trafik lambası (TrafficLights kendini bağlar; yoksa yalnızca eksen sırası).
var lights: TrafficLights
## Yarışı kaybedip kaçan araçlar ve kavşağı talep eden kaçak (karşı eksen beklesin), talep zamanı, korna çalanlar.
var _runners: Array[TrafficVehicle] = []
var _runner_claim: TrafficVehicle
var _claim_since: float = 0.0
var _honked: Dictionary = {}   # araç → korna çaldığı kaçak
var sfx: TrafficSfx
## Şehir çevre sesleri (uğultu, araç lastikleri, kuşlar, ara sıra korna / uzak cıyaklama).
var ambience: CityAmbience
var _hazard_timer: float = 0.0
## Kaçak kavşakta takılırsa (beklenmedik engel) talep bu kadar sonra düşer: karşı eksen sonsuza dek beklemesin.
const RUNNER_CLAIM_MAX: float = 8.0


func _ready() -> void:
	add_to_group("traffic")   # GameSettings düşük kalitede max_vehicles'ı azaltır
	_rng.randomize()
	_collect_spawn_points(self)
	chase = PoliceChase.new()
	add_child(chase)
	police = TrafficPolice.new()
	add_child(police)
	sfx = TrafficSfx.new()
	add_child(sfx)
	ambience = CityAmbience.new()
	add_child(ambience)
	for entry: Dictionary in CarCatalog.all():
		if entry["traffic"]:
			_candidates.append(entry["id"])
	_exotics = CarCatalog.exotic_ids()
	for i: int in mini(pool_size, _candidates.size()):
		_request_model(_candidates[i])
	_rotate_timer = pool_rotate_interval
	_spawn_timer = 0.3
	_hazard_timer = _rng.randf_range(HAZARD_GAP.x, HAZARD_GAP.y) * 0.6


func _physics_process(delta: float) -> void:
	_poll_pending()
	_rotate_pool(delta)
	_hazard_timer -= delta
	if _hazard_timer <= 0.0:
		_hazard_timer = _rng.randf_range(HAZARD_GAP.x, HAZARD_GAP.y) if start_hazard() else HAZARD_RETRY
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
	var model: Dictionary = _next_model()
	if model.is_empty():
		return false   # havuzdaki her model şehirde ya da sıradaki egzotik yükleniyor: sonra doğar
	var candidates: Array[TrafficWaypoint] = spawn_points.duplicate()
	candidates.shuffle()
	for point: TrafficWaypoint in candidates:
		var start: Vector3 = hidden_start(point)
		if _is_clear(start):
			_spawn_at(point, model, start)
			_count_spawn(model["id"])
			return true
	return false


## Sıradaki rastgele aracın modeli: egzotik sırası geldiyse o (yüklenene dek {}: sıradaki doğum bekler), yoksa havuzdan
## şehirde olmayan bir model.
func _next_model() -> Dictionary:
	if _exotic_next != &"" and is_model_in_use(_exotic_next):
		_exotic_next = _pick_exotic()   # bu arada yarış rakibi olarak şehre geldi: başka bir egzotik
		if _exotic_next != &"":
			_request_model(_exotic_next)
	if _exotic_next != &"":
		var entry: Dictionary = _pool_entry(_exotic_next)
		if not entry.is_empty():
			return entry
		if _pending.has(_exotic_next):
			return {}
		_exotic_next = &""   # yüklenemedi ya da yarış modelleri arasından düştü: bu sefer normal araç
	return _free_model()


## Doğan rastgele araç sayılır. Egzotik doğunca sayaç sıfırlanır ve modeli listeden düşer (sahnesini araç tutar; rakip
## olarak yeniden istenirse yüklenir). Aradan sonra sıra gelince model HEMEN yüklenmeye başlar: sonraki doğuma hazır olur.
func _count_spawn(id: StringName) -> void:
	if _exotics.has(id):
		_since_exotic = 0
		_exotic_next = &""
		for i: int in range(_race_models.size() - 1, -1, -1):
			if _race_models[i]["id"] == id:
				_race_models.remove_at(i)
		return
	_since_exotic += 1
	if _exotic_next == &"" and _since_exotic >= EXOTIC_MIN_GAP \
			and _rng.randf() < 1.0 / float(EXOTIC_EVERY - EXOTIC_MIN_GAP):
		_exotic_next = _pick_exotic()
		if _exotic_next != &"":
			_request_model(_exotic_next)


## Şehirde olmayan rastgele bir egzotik model (&"" = yok).
func _pick_exotic() -> StringName:
	var used: Dictionary = models_in_use()
	var options: Array[StringName] = []
	for id: StringName in _exotics:
		if not used.has(id):
			options.append(id)
	return options[_rng.randi() % options.size()] if not options.is_empty() else &""


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
## `appearance`: arkadaş rakibin boyası (RaceManager); null → rastgele NPC rengi.
func spawn_challenger(wanted: StringName = &"", appearance: CarAppearance = null) -> TrafficVehicle:
	if race_spawn_point == null or _pool.is_empty():
		return null
	var start: Vector3 = hidden_start(race_spawn_point)
	if not _is_clear(start):
		return null   # şeritte hâlâ bekleyen biri var: sonra denenir
	var entry: Dictionary = {}
	if wanted != &"":
		if is_model_in_use(wanted):
			return null   # bu model şehirde: aynısından ikinci araç çıkmaz (RaceManager başka rakip seçer)
		entry = _pool_entry(wanted)
		if entry.is_empty():
			request_model(wanted)
			return null
	else:
		entry = _free_model()
		if entry.is_empty():
			return null
	var vehicle: TrafficVehicle = _spawn_at(race_spawn_point, entry, start, appearance)
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
## `entry` verilmezse boştaki bir model seçilir; boşta model yoksa araç doğmaz (null).
func _spawn_at(point: TrafficWaypoint, entry: Dictionary = {}, start: Vector3 = Vector3.INF,
		appearance: CarAppearance = null) -> TrafficVehicle:
	var model: Dictionary = entry if not entry.is_empty() else _free_model()
	if model.is_empty():
		return null
	var vehicle: TrafficVehicle = TrafficVehicle.new()
	vehicle.name = "Npc_%d" % (_rng.randi() % 100000)
	vehicle.max_speed = _rng.randf_range(min_speed, max_speed)
	vehicle.acceleration = _rng.randf_range(0.5, 0.8)
	vehicle.stop_distance = _rng.randf_range(0.76, 0.95)   # kuyrukta öndekine fazla yanaşmaz, aralar aynı olmaz
	add_child(vehicle)
	vehicle.vehicle_id = model["id"]
	vehicle.setup(self, model["scene"], appearance if appearance else _random_appearance(model["id"]), point, model_scale)
	if start != Vector3.INF:
		vehicle.global_position = Vector3(start.x, vehicle.global_position.y, start.z)
	vehicle.reached_despawn.connect(_on_vehicle_despawn)
	vehicles.append(vehicle)
	vehicle_spawned.emit(vehicle)
	return vehicle


## Kovalamaca aracı: aynı kurulum (model, CarRig, görünüm), ama trafik listesine GİRMEZ ve vehicle_spawned
## yayılmaz (RepairManager onu müşteri yapmasın). Yaşamını PoliceChase yönetir.
func spawn_chase_vehicle(point: TrafficWaypoint, entry: Dictionary, appearance: CarAppearance) -> TrafficVehicle:
	var vehicle: TrafficVehicle = TrafficVehicle.new()
	vehicle.name = "Chase_%d" % (_rng.randi() % 100000)
	add_child(vehicle)
	vehicle.vehicle_id = entry["id"]
	vehicle.setup(self, entry["scene"], appearance, point, model_scale)
	return vehicle


## Rastgele bir şehir modeli — şehirde henüz OLMAYAN (kovalamaca şüphelisi); boşta model yoksa {}.
func random_city_model() -> Dictionary:
	return _free_model()


## Şu an şehirde olan modeller (id → true): trafik listesi (yol, bekleyen müşteri, lift, yarış şeridi) +
## kovalamaca araçları.
func models_in_use() -> Dictionary:
	var used: Dictionary = {}
	for vehicle: TrafficVehicle in vehicles:
		if is_instance_valid(vehicle):
			used[vehicle.vehicle_id] = true
	if chase:
		for vehicle: TrafficVehicle in chase.vehicles():
			used[vehicle.vehicle_id] = true
	if police and police.police():
		used[police.police().vehicle_id] = true
	return used


func is_model_in_use(id: StringName) -> bool:
	return models_in_use().has(id)


## Havuzdan şehirde olmayan rastgele bir model. Hepsi kullanımdaysa boştaki bir katalog modelini yüklemeye
## başlar ve {} döner (çağıran sonra yeniden dener).
func _free_model() -> Dictionary:
	var used: Dictionary = models_in_use()
	var free: Array[Dictionary] = []
	for entry: Dictionary in _pool:
		if not used.has(entry["id"]):
			free.append(entry)
	if not free.is_empty():
		return free[_rng.randi() % free.size()]
	for id: StringName in _pending:
		if _candidates.has(id) and not used.has(id):
			return {}   # boştaki bir şehir modeli zaten yolda
	var options: Array[StringName] = []
	for id: StringName in _candidates:
		if not used.has(id) and not _pool_has(id):
			options.append(id)
	if not options.is_empty():
		_request_model(options[_rng.randi() % options.size()])
	return {}


func _on_vehicle_despawn(vehicle: TrafficVehicle) -> void:
	vehicles.erase(vehicle)
	_runners.erase(vehicle)
	_honked.erase(vehicle)
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
					_pool.remove_at(_eviction_index())
				_pool.append({"id": id, "scene": scene})
			_:
				push_warning("TrafficManager: '%s' yüklenemedi" % path)
				_pending.erase(id)


## Havuzdan çıkarılacak model: şehirde kullanılan EN ESKİ model (sahnedeki örneği yaşamaya devam eder,
## aynı modelden ikinci araç zaten doğamaz); hiçbiri kullanımda değilse en eski model.
func _eviction_index() -> int:
	var used: Dictionary = models_in_use()
	for i: int in _pool.size():
		if used.has(_pool[i]["id"]):
			return i
	return 0


## Havuzu katalogdan başka bir modelle tazeler (katalog havuzdan büyükse).
func _rotate_pool(delta: float) -> void:
	if pool_rotate_interval <= 0.0 or _candidates.size() <= pool_size:
		return
	_rotate_timer -= delta
	if _rotate_timer > 0.0:
		return
	_rotate_timer = pool_rotate_interval
	var used: Dictionary = models_in_use()
	var options: Array[StringName] = []
	for id: StringName in _candidates:
		if not _pool_has(id) and not _pending.has(id) and not used.has(id):
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


## NPC görünümü (kovalamaca araçları da bununla kurulur; polis kaplamalı olduğu için fabrika renginde kalır).
func npc_appearance(id: StringName) -> CarAppearance:
	return _random_appearance(id)


func _random_appearance(id: StringName = &"") -> CarAppearance:
	var appearance: CarAppearance = CarAppearance.new()  # NPC'ye özel; oyuncu araçlarının kaydına girmez
	if not GameFeatures.PAINT or not VehicleOwnership.is_paintable(id):
		# Boya kapalıyken hiçbir araç rastgele renge boyanmaz: NPC de FABRİKA rengiyle çıkar. Kaplamalı (polis)
		# araç da her zaman fabrika renginde.
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
	if chase:
		for vehicle: TrafficVehicle in chase.vehicles():
			if vehicle.global_position.distance_to(position) < spawn_clearance:
				return false
	return true


## Polise yol verme baskısı (0 = yok, 1 = hemen kenara): aynı yönde ARKADAN gelen ya da karşı şeritte
## ÖNDEN yaklaşan kovalamaca aracı yakınsa. Kavşaktaki çapraz eksen araçları zaten kilitle bekler.
func chase_pressure(vehicle: TrafficVehicle) -> float:
	var pushers: Array[TrafficVehicle] = []
	if chase and chase.is_active():
		pushers = chase.vehicles()
	for runner: TrafficVehicle in _runners:
		if is_instance_valid(runner) and runner != vehicle:
			pushers.append(runner)
	if pushers.is_empty():
		return 0.0
	var forward: Vector3 = vehicle.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: float = 0.0
	for other: TrafficVehicle in pushers:
		var other_forward: Vector3 = other.global_transform.basis.z
		other_forward.y = 0.0
		var alignment: float = other_forward.normalized().dot(forward)
		if absf(alignment) < 0.7:
			continue   # çapraz eksen
		var delta: Vector3 = other.global_position - vehicle.global_position
		delta.y = 0.0
		var along: float = delta.dot(forward)
		if absf(delta.cross(forward).y) > 1.0:
			continue   # başka yol
		var approaching: bool = (alignment > 0.0 and along < 0.0) or (alignment < 0.0 and along > 0.0)
		var gap: float = absf(along)
		if approaching and gap < PoliceChase.YIELD_DISTANCE:
			best = maxf(best, clampf(1.5 - gap / PoliceChase.YIELD_DISTANCE * 1.5, 0.0, 1.0))
		elif not approaching and gap < PoliceChase.YIELD_AFTER:
			best = maxf(best, 1.0 - gap / PoliceChase.YIELD_AFTER)   # geçti: yavaşça şeride dön
	return best


# --- Takip mesafesi ----------------------------------------------------------

## Aracın önünde, aynı yönde ve yakın şeritte olan en yakın aracın mesafesi (yoksa INF). Duran / yaklaşan trafik
## polisi de engeldir (arkasından gelen içinden geçmez); trafik polisinin geçirdiği araç kilitteki öbürlerini saymaz.
func distance_to_vehicle_ahead(vehicle: TrafficVehicle) -> float:
	var forward: Vector3 = vehicle.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: float = INF
	var nearest: TrafficVehicle = null
	# Kaçan araç orta çizgide gider: kendi şeridindeki (0,3 yanındaki) yavaş aracı engel saymaz, yanından geçer
	var lane_half: float = 0.18 if vehicle.fleeing else 0.35
	for other: TrafficVehicle in vehicles:
		if other == vehicle or not other.blocks_traffic() or vehicle.ignores(other):
			continue  # yol kenarında bekleyen / CarSpot'taki araç trafiği durdurmaz
		var gap: float = _gap_to(vehicle, other, forward, lane_half)
		if gap < best:
			best = gap
			nearest = other
	var cop: TrafficVehicle = police.obstacle() if police else null
	if cop and cop != vehicle:
		var gap: float = _gap_to(vehicle, cop, forward, lane_half)
		if gap < best:
			best = gap
			nearest = cop
	vehicle.leader = nearest
	return best


## `other` aracın önünde, aynı yönde ve şeridinde mi; öyleyse tampon arası mesafe, değilse INF.
func _gap_to(vehicle: TrafficVehicle, other: TrafficVehicle, forward: Vector3, lane_half: float) -> float:
	var delta: Vector3 = other.global_position - vehicle.global_position
	delta.y = 0.0
	var along: float = delta.dot(forward)
	if along <= 0.0 or absf(delta.cross(forward).y) > lane_half:
		return INF
	var other_forward: Vector3 = other.global_transform.basis.z
	other_forward.y = 0.0
	if other_forward.normalized().dot(forward) < 0.3:
		return INF  # karşıdan gelen
	# stop / follow mesafeleri ~0,6 boylu araca göre ayarlı: uzun araç (minibüs, kamyonet) aynı tampon
	# boşluğunu bıraksın diye fazla boy merkezden merkeze mesafeden düşülür (kısa araç yaklaşmaz)
	return along - maxf(vehicle._front + other._front - NOMINAL_LENGTH, 0.0)


## TRAFİK KİLİDİ: önündeki araç yüzünden en az `min_stuck` sn duran bir aracın "öndeki araç" zinciri (leader) kendi
## üstüne kapanıyorsa halkadaki araçlar — ör. kaldırımdan çıkan sıkılmış müşteri ile şeritte gelen araç burun buruna:
## ikisi de öbürünü önünde sayar, hiçbiri kımıldamaz. Zincirdeki her araç trafiği engelleyen kipte ve duruyor olmalı;
## kırmızıda / kavşak sırasında bekleyen kuyruk sayılmaz (stuck_time ışıkta artmaz). Halka yoksa boş.
func find_deadlock(min_stuck: float) -> Array[TrafficVehicle]:
	for start: TrafficVehicle in vehicles:
		if not is_instance_valid(start) or start.stuck_time < min_stuck:
			continue
		var chain: Array[TrafficVehicle] = []
		var at: TrafficVehicle = start
		while at != null and not chain.has(at) and chain.size() < 16:
			if not is_instance_valid(at) or not vehicles.has(at) or not at.blocks_traffic() or at.speed > STILL_SPEED:
				at = null
				break
			chain.append(at)
			at = at.leader if is_instance_valid(at.leader) else null
		if at != null and chain.has(at):
			return chain.slice(chain.find(at))
	return []


## DÖRTLÜ: `vehicle` verilmezse ekranda görünen uygun bir araç seçilir; kovalamaca sürerken olmaz. Duran araç (yoksa null).
func start_hazard(vehicle: TrafficVehicle = null) -> TrafficVehicle:
	if chase and chase.is_active():
		return null
	if vehicle == null:
		var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter
		if router and Hud.WORLD_COVERING_PLACES.has(router.current_place()):
			return null   # dünya örtülü (garaj, mağaza, yarış…): kimse görmez
		var seen: Array[TrafficVehicle] = []
		for candidate: TrafficVehicle in vehicles:
			if is_instance_valid(candidate) and candidate.can_hazard_stop() and not is_hidden(candidate.global_position):
				seen.append(candidate)
		if seen.is_empty():
			return null
		vehicle = seen[_rng.randi() % seen.size()]
	if not vehicle.hazard_stop(_rng.randf_range(HAZARD_TIME.x, HAZARD_TIME.y)):
		return null
	hazard_started.emit(vehicle)
	return vehicle


# --- Kavşak geçiş sırası (eksen bazlı) ------------------------------------------

## Araç kavşağa girebilir mi? Aynı eksen birlikte geçer; karşı eksen bekler.
## Karşı eksen crossing_max_hold'dan uzun beklediyse mevcut eksen yeni araç almaz.
func request_crossing(vehicle: TrafficVehicle) -> bool:
	_prune_crossing()
	if _crossing.has(vehicle):
		return true
	if chase and chase.holds_crossing(vehicle.axis):
		return false   # kovalamaca geçiyor: karşı eksen kavşağa girmez
	if police and police.holds_crossing(vehicle.axis):
		return false   # sirenli trafik polisi geçiyor
	if _runner_holds(vehicle.axis):
		_honk(vehicle)
		return false   # karşıdan kaçak geliyor: yeşil olsa da bekler (korna)
	if lights and not lights.allows(vehicle.axis):
		return false   # kırmızı / sarı: giriş çizgisinde bekler
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


## KAÇAN ARAÇ kavşağa yaklaşıyor: kavşağı talep eder (karşı eksen yeni araç sokamaz), ışığa bakmaz. Kavşakta karşı
## eksenden araç varsa onun çıkmasını bekler (false = bekle); giriş noktasına yakınsa geçiş listesine girer.
func runner_crossing(runner: TrafficVehicle, to_entry: float) -> bool:
	_prune_crossing()
	var now: float = Time.get_ticks_msec() / 1000.0
	if _runner_claim != runner:
		_runner_claim = runner
		_claim_since = now
	if _crossing.has(runner):
		return true
	for other: TrafficVehicle in _crossing:
		if other.axis != runner.axis:
			return false
	if to_entry < runner.lock_check_distance:
		if _crossing.is_empty():
			_crossing_axis = runner.axis
			_crossing_since = now
			_waiting_axis = -1
		_crossing.append(runner)
	return true


## Yarışı kaybeden araç kaçmaya başladı (lastik sesi; yol verme listesi).
func runner_started(runner: TrafficVehicle) -> void:
	if not _runners.has(runner):
		_runners.append(runner)
	if sfx and not is_hidden(runner.global_position):
		sfx.screech()


## Kaçak karşı eksenden kavşağı talep etti mi (bu eksen yeni araç sokamaz)?
func _runner_holds(axis: int) -> bool:
	if _runner_claim == null:
		return false
	if not is_instance_valid(_runner_claim) or not _runner_claim.fleeing \
			or Time.get_ticks_msec() / 1000.0 - _claim_since > RUNNER_CLAIM_MAX:
		_runner_claim = null
		return false
	return _runner_claim.axis != axis


## Kaçak yüzünden duran araç bir kez korna çalar (ekranda görünüyorsa).
func _honk(vehicle: TrafficVehicle) -> void:
	if _honked.get(vehicle) == _runner_claim:
		return
	_honked[vehicle] = _runner_claim
	if sfx and not is_hidden(vehicle.global_position):
		sfx.honk()


## Işık bu eksene yeni geçiş veriyor mu (lamba yoksa her zaman).
func light_allows(axis: int) -> bool:
	return lights == null or lights.allows(axis)


## Kavşak girişinden dur çizgisine mesafe (lamba / çizgi yoksa -1: araç eskisi gibi giriş noktasında durur).
func stop_line_gap(entry: Node3D) -> float:
	return lights.stop_gap(entry) if lights else -1.0


## Kavşakta karşı eksenden (axis dışından) araç var mı? Sirenli polis ışığa bakmaz ama içindeki araca girmez.
func cross_traffic_in_intersection(axis: int) -> bool:
	_prune_crossing()
	for other: TrafficVehicle in _crossing:
		if other.axis != axis:
			return true
	return false


func finish_crossing(vehicle: TrafficVehicle) -> void:
	if vehicle == _runner_claim:
		_runner_claim = null
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


## Bu noktaya bağlanan önceki nokta (şeridin yönü için; kaldırımdan çıkan araç). Yoksa null.
func previous_waypoint(point: TrafficWaypoint) -> TrafficWaypoint:
	for other: TrafficWaypoint in waypoints:
		if other != point and other.get_next().has(point):
			return other
	return null


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
