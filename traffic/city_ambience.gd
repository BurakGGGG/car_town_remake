class_name CityAmbience
extends Node3D
## ŞEHİR ÇEVRE SESLERİ (2026-10-17, kullanıcı: "bazen korna, kuş sesleri, lastik sesleri. çok kafa ağrıtmasın ama
## canlı hissettirsin şehir"). Ses dosyası yok — açılışta arka plan iş parçacığında KODLA sentezlenir (TrafficSfx /
## PoliceSiren gibi), hazır olunca yavaşça açılır. Katmanlar:
##   UĞULTU  — uzaktan şehir uğultusu: çok kısık, kalın (yumuşak gürültü, yavaşça dalgalanır), döngü.
##   LASTİK  — yoldaki her aracın lastik / yol sesi: aracın hızıyla açılır (kırmızıda bekleyen ya da tamirdeki araç
##             susar, kovalamaca daha yüksek ve tiz). Araç ekranın ortasından geçerken yükselir.
##   KUŞLAR  — ekrandaki / yakındaki ağaç kümelerinden: serçe, iki notalı ıslık, trill, karatavuk, güvercin. Bir kuş
##             1–3 cümle öter, sonra BIRD_GAP sessizlik.
##   KORNA   — HORN_GAP'te bir, ekrandaki (yoksa yakındaki) yoldaki bir araçtan kısa korna (dıt / dıt-dıt / uzun /
##             kamyon / sabırsız); araç ekranda yoksa uzaktan.
##   CIYAK   — SQUEAL_GAP'te bir, ekran dışındaki bir yoldan uzak lastik cıyaklaması.
##   MOTOR   — EGZOTİK araçlarda ExoticEngine (2026-10-17); diğer her trafik aracında tipine göre TrafficEngine
##             (2026-10-20, kullanıcı: "araç seslerini çeşitlendir ve daha da güzel olsun": küçük / büyük benzinli,
##             altı, V8, dizel, kamyonet, eski karbüratörlü, elektrikli). Aynı anda dinleyiciye en yakın ENGINE_VOICES
##             aracın motoru duyulur. Lastik sesi de araç boyuna göre üç çeşit (küçük / orta / iri).
##   KALKIŞ CIYAĞI — süper araç ışıktan gaza basınca (TrafficManager.vehicle_launched) aracın lastiklerinden kısa cıyak
##             (motorun tam gazını ExoticEngine ivmeden kendisi çalar).
##   BAĞLAMLI KORNA — dörtlü yakıp duran aracın arkasındaki araç kısa süre sonra, uzun sıkışan araç ara sıra korna
##             çalar (2026-10-20, kullanıcı: "sokakta trafikte bazen korna sesleri olsun"); her aracın kornası tipine
##             göre (TrafficEngine.horn_kind: ince tek ton, klasik çift ton, kalın, kamyonet, eski "mıık", elektrikli).
## "Kafa ağrıtmasın": hepsi kısık ve seyrek; aynı anda en çok bir korna, bir cıyak, iki kuş; tekrar hissi olmasın diye
## her olayda perde ve konum değişir.
##
## 3B KONUM: AudioListener3D kameranın baktığı zemin noktasının üstünde, kameranın yönünde (ekranın sağı = sağ kulak);
## uzaklık kısar ve boğar (Godot hava sönümü). Kendi "Ambience" bus'ı → SFX (ayarlardaki efekt düzeyi uygulanır).
## Dünyayı örten YER ekranlarında (garaj, mağaza, yarış, harita, hurdalık, ayarlar) susar; pano açıkken kısılır.
## TrafficManager kodla kurar (sahne değişikliği yok).

const MIX_RATE: int = 22050
const BUS: StringName = &"Ambience"
## Bus düzeyi: pano (MODAL) açıkken bu kadar kısık; dünya örtülünce sessiz. Değişim hızı (dB/sn).
const PANEL_DB: float = -9.0
const SILENT_DB: float = -60.0
const FADE_RATE: float = 24.0

## Katman düzeyleri (dB). 3B seslerde: kaynak dinleyiciden UNIT_SIZE uzaktayken.
const HUM_DB: float = -24.0
const TIRE_DB: float = -19.0
const BIRD_DB: float = -15.0
const HORN_DB: float = -14.0
const SQUEAL_DB: float = -14.0
const CHIRP_DB: float = -13.0

## Seyreklik (sn aralıkları): kuş öbekleri arası, bir kuşun cümleleri arası, korna, uzak cıyaklama.
const BIRD_GAP: Vector2 = Vector2(6.0, 16.0)
const PHRASE_GAP: Vector2 = Vector2(0.5, 1.8)
const HORN_GAP: Vector2 = Vector2(28.0, 65.0)   # rastgele korna (bağlamlı kornalar ayrıca)
const SQUEAL_GAP: Vector2 = Vector2(60.0, 140.0)

## 3B ses: dinleyici zemin odağının LISTENER_HEIGHT üstünde (tam altından geçen ses birden patlamasın).
const LISTENER_HEIGHT: float = 1.2
const UNIT_SIZE: float = 2.5
const MAX_DISTANCE: float = 24.0
const AIR_CUTOFF: float = 3500.0
## Kuşlar dinleyiciye bu kadar yakın ağaçlardan öter (yoksa en yakın ağaçtan).
const BIRD_RANGE: float = 7.0
## Lastik: bu hızda (birim/sn) tam düzey; normal trafik 0,55–0,9, kovalamaca ~2,5 (en çok TIRE_MAX katı).
const TIRE_REF_SPEED: float = 0.8
const TIRE_MAX: float = 1.8
## Motor: aynı anda en çok bu kadar aracın motoru duyulur (dinleyiciye en yakınlar); seçim bu aralıkla tazelenir.
const ENGINE_VOICES: int = 6
const VOICE_REFRESH: float = 0.25
## Lastik çeşidi araç boyundan (gerçek uzunluk, m): kısa → küçük, uzun / kamyonet → iri.
const TIRE_SMALL_LENGTH: float = 4.1
const TIRE_BIG_LENGTH: float = 5.0
## Bağlamlı korna: önündeki dörtlü yakmış araç yüzünden duran araç sıkışma süresi HAZARD_HONK_AFTER'ı geçince
## HAZARD_HONK_CHANCE ile; başka sebeple (müşteri yanaşıyor, kuyruk) sıkışan JAM_HONK_AFTER'da JAM_HONK_CHANCE ile.
## Her duruşta en çok bir kez; kornalar arası en az HONK_SPACING sn (kakofoni olmasın).
const HAZARD_HONK_AFTER: Vector2 = Vector2(1.0, 2.2)
const HAZARD_HONK_CHANCE: float = 0.65
const JAM_HONK_AFTER: Vector2 = Vector2(4.5, 8.0)
const JAM_HONK_CHANCE: float = 0.3
const HONK_SPACING: float = 1.6
## Rastgele kornada basış desenlerinin ağırlığı (TrafficEngine.HORN_PATTERNS sırası: dıt, dıt-dıt, uzun, sabırsız).
const HORN_PATTERN_WEIGHTS: Array[float] = [0.35, 0.35, 0.2, 0.1]
## Uzak cıyaklama dinleyiciden bu uzaklıkta, bir yolun üstünde.
const SQUEAL_DISTANCE: Vector2 = Vector2(8.0, 12.0)
## Yolların orta çizgileri (doğu-batı yolu z = 0,6, kuzey-güney yolu x = 0,6).
const ROAD_CENTER: float = 0.6

## Kuş türleri (ağırlık: şehirde serçe çok, güvercin az).
enum Bird { SPARROW, TIT, TRILL, BLACKBIRD, PIGEON }
const BIRD_WEIGHTS: Array[float] = [0.34, 0.2, 0.14, 0.2, 0.12]
const VARIANTS: int = 3

## Arka planda üretilen ses bankası: "hum", "tire" / "tire_small" / "tire_big" (döngü), "birds" (tür → varyantlar),
## "horns" (uzak korna), "car_horns" (TrafficEngine.Horn → 4 basış deseni), "squeals", "engines" (silindir sayısı →
## egzotik motor döngüsü), "traffic_engines" (TrafficEngine.Kind → döngü).
static var _bank: Dictionary = {}

var _manager: TrafficManager
var _router: UiRouter
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _task: int = -1
var _started: bool = false
var _bus: int = -1
var _bus_db: float = SILENT_DB
var _listener: AudioListener3D
var _hum: AudioStreamPlayer
var _birds: Array[AudioStreamPlayer3D] = []
var _horns: Array[AudioStreamPlayer3D] = []
var _horn_targets: Array[Node3D] = [null, null]
var _last_honk: float = -100.0
var _clock: float = 0.0
var _squeal: AudioStreamPlayer3D
var _chirp: AudioStreamPlayer3D
var _chirp_target: Node3D
## araç → {"player", "last", "speed", "pitch", "engine" (egzotikte ExoticEngine), "motor" (diğerlerinde TrafficEngine),
## "audible", "honk_at" (bu duruşta korna eşiği; korna çalındıysa / çalınmayacaksa INF)}
var _tires: Dictionary = {}
var _voice_timer: float = 0.0
## Duyulan motor sınırı (QA motorsuz ölçüm için 0 yapar).
var engine_voices: int = ENGINE_VOICES
var _bird_timer: float = 0.0
var _bird_phrases: int = 0
var _bird_kind: int = 0
var _bird_spot: Vector3 = Vector3.ZERO
var _bird_pitch: float = 1.0
var _bird_turn: int = 0
var _horn_timer: float = 0.0
var _squeal_timer: float = 0.0
var _trees: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	name = "CityAmbience"
	_manager = get_parent() as TrafficManager
	_rng.randomize()
	_bus = _ensure_bus()
	AudioServer.set_bus_volume_db(_bus, SILENT_DB)
	_listener = AudioListener3D.new()
	_listener.name = "Listener"
	add_child(_listener)
	_hum = AudioStreamPlayer.new()
	_hum.name = "Hum"
	_hum.bus = BUS
	_hum.volume_db = HUM_DB
	add_child(_hum)
	for i: int in 2:
		_birds.append(_player("Bird%d" % i, BIRD_DB))
	for i: int in 2:
		_horns.append(_player("Horn%d" % i, HORN_DB))
	_squeal = _player("Squeal", SQUEAL_DB)
	_chirp = _player("Chirp", CHIRP_DB)
	if _manager:
		_manager.vehicle_launched.connect(_on_launched)
	_bird_timer = _rng.randf_range(2.0, 5.0)   # ilk kuş erken: şehir açılışta canlı
	_horn_timer = _rng.randf_range(HORN_GAP.x, HORN_GAP.y) * 0.5
	_squeal_timer = _rng.randf_range(SQUEAL_GAP.x, SQUEAL_GAP.y)
	if _bank.is_empty():
		_task = WorkerThreadPool.add_task(_synthesize)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Bus: bir kez kurulur (sahne yeniden yüklense de aynı), SFX'e gider.
static func _ensure_bus() -> int:
	var index: int = AudioServer.get_bus_index(BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, GameSettings.SFX_BUS)
	return index


func _player(node_name: String, db: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = node_name
	player.bus = BUS
	player.volume_db = db
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	player.attenuation_filter_cutoff_hz = AIR_CUTOFF
	add_child(player)
	return player


## Çalıyor mu (bank hazır, uğultu başladı)? Test / QA.
func is_running() -> bool:
	return _started


## Bus'ın o anki düzeyi (dB; test / QA).
func bus_db() -> float:
	return _bus_db


## Lastik sesi çalan (hareket eden) araç sayısı (test / QA).
func rolling_count() -> int:
	var n: int = 0
	for entry: Dictionary in _tires.values():
		var player: AudioStreamPlayer3D = entry["player"]
		if player.playing and not player.stream_paused:
			n += 1
	return n


func _process(delta: float) -> void:
	_clock += delta
	if not _started:
		if not _ready_bank():
			return
		_start()
	var goal: float = _goal_db()
	_bus_db = move_toward(_bus_db, goal, FADE_RATE * delta)
	AudioServer.set_bus_volume_db(_bus, _bus_db)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		_listener.global_transform = Transform3D(camera.global_basis,
			WorldCamera.ground_point(camera) + Vector3.UP * LISTENER_HEIGHT)
		if not _listener.is_current():
			_listener.make_current()
	if goal <= SILENT_DB:
		return   # dünya örtülü: yeni olay başlamaz (sürenler bus'la birlikte söner)
	_tick_birds(delta, camera)
	_horn_timer -= delta
	if _horn_timer <= 0.0:
		_horn_timer = _rng.randf_range(HORN_GAP.x, HORN_GAP.y)
		_honk(camera)
	_squeal_timer -= delta
	if _squeal_timer <= 0.0:
		_squeal_timer = _rng.randf_range(SQUEAL_GAP.x, SQUEAL_GAP.y)
		_far_squeal()


func _physics_process(delta: float) -> void:
	if not _started or delta <= 0.0:
		return
	_update_tires(delta)
	if _chirp.playing and is_instance_valid(_chirp_target):
		_chirp.global_position = _chirp_target.global_position + Vector3.UP * 0.03
	for i: int in _horns.size():
		if _horns[i].playing and is_instance_valid(_horn_targets[i]):
			_horns[i].global_position = (_horn_targets[i] as Node3D).global_position + Vector3.UP * 0.1
	if _goal_db() > SILENT_DB:
		_context_honks()


## Bus hedefi: dünyayı örten YER ekranı → sessiz; pano → kısık; yoksa tam.
func _goal_db() -> float:
	if not is_instance_valid(_router):
		_router = get_tree().get_first_node_in_group("ui_router") as UiRouter
		if _router == null:
			return 0.0
	if Hud.WORLD_COVERING_PLACES.has(_router.current_place()):
		return SILENT_DB
	return PANEL_DB if _router.top() != &"" and _router.top() != _router.current_place() else 0.0


func _ready_bank() -> bool:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return not _bank.is_empty()


func _start() -> void:
	_started = true
	_hum.stream = _bank["hum"]
	_hum.play(_rng.randf() * (_bank["hum"] as AudioStreamWAV).get_length())
	var scenery: CityScenery = get_tree().get_first_node_in_group("city_scenery") as CityScenery
	if scenery:
		_trees = scenery.tree_spots()


# --- Lastik ---------------------------------------------------------------------------------

## Yoldaki (ve kovalamacadaki) her araca bir lastik sesi (boyuna göre çeşit) ve motor: konumu araçla gider, düzeyi ve
## perdesi hızıyla. Hız konum farkından ölçülür (her kip için aynı: trafik, kovalamaca, yarış daveti); durunca lastik
## duraklar, motor rölantiye iner. Motorlar yalnız dinleyiciye en yakın ENGINE_VOICES araçta duyulur.
func _update_tires(delta: float) -> void:
	var alive: Dictionary = {}
	_voice_timer -= delta
	var refresh: bool = _voice_timer <= 0.0
	if refresh:
		_voice_timer = VOICE_REFRESH
	for vehicle: Node3D in _vehicles():
		alive[vehicle] = true
		var entry: Dictionary = _tires.get(vehicle, {})
		var at: Vector3 = vehicle.global_position
		if entry.is_empty():
			entry = {"player": _tire_player(vehicle), "last": at, "speed": 0.0, "pitch": _rng.randf_range(0.92, 1.08),
				"engine": _engine_for(vehicle), "motor": _motor_for(vehicle), "audible": false, "honk_at": INF}
			_tires[vehicle] = entry
			refresh = true
		var moved: float = (at - (entry["last"] as Vector3)).length() / delta
		entry["last"] = at
		var speed: float = lerpf(float(entry["speed"]), moved, 1.0 - exp(-6.0 * delta))
		entry["speed"] = speed
		var player: AudioStreamPlayer3D = entry["player"]
		player.global_position = at + Vector3.UP * 0.05
		var level: float = speed / TIRE_REF_SPEED
		var rolling: bool = level > 0.06
		if rolling == player.stream_paused:
			player.stream_paused = not rolling
		if rolling:
			player.volume_db = TIRE_DB + linear_to_db(minf(level, TIRE_MAX))
			player.pitch_scale = float(entry["pitch"]) * (0.82 + 0.2 * minf(level, 3.0))
		var engine: ExoticEngine = entry["engine"]
		if engine:
			engine.global_position = at + Vector3.UP * 0.1
			engine.drive(speed, delta)
		var motor: TrafficEngine = entry["motor"]
		if motor:
			motor.global_position = at + Vector3.UP * 0.08
			motor.drive(speed, delta, _engine_running(vehicle), bool(entry["audible"]))
	for key: Variant in _tires.keys():   # silinmiş araç anahtarı tipli değişkene atanamaz
		if not alive.has(key):
			for part: String in ["player", "engine", "motor"]:
				if _tires[key][part]:
					(_tires[key][part] as Node).queue_free()
			_tires.erase(key)
	if refresh:
		_pick_engine_voices()


## Motoru duyulacak araçlar: dinleyiciye en yakın ENGINE_VOICES (motoru olan) araç, MAX_DISTANCE içinde.
func _pick_engine_voices() -> void:
	var ranked: Array[Array] = []
	var ear: Vector3 = _listener.global_position
	for key: Variant in _tires:
		var entry: Dictionary = _tires[key]
		entry["audible"] = false
		if entry["motor"] and is_instance_valid(key):
			var d: float = ((key as Node3D).global_position - ear).length()
			if d < MAX_DISTANCE:
				ranked.append([d, entry])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i: int in mini(ranked.size(), engine_voices):
		(ranked[i][1] as Dictionary)["audible"] = true


## Kontak açık mı: yolda / kovalamacada / yol kenarına yanaşırken evet; kenarda bekleyen müşteri, tamirdeki araç hayır.
static func _engine_running(vehicle: Node3D) -> bool:
	var traffic_vehicle: TrafficVehicle = vehicle as TrafficVehicle
	if traffic_vehicle == null:
		return true
	return traffic_vehicle.mode in [TrafficVehicle.Mode.TRAFFIC, TrafficVehicle.Mode.CHASE,
		TrafficVehicle.Mode.REPAIR_REQUESTED, TrafficVehicle.Mode.RACE_CHALLENGE]


func _tire_player(vehicle: Node3D) -> AudioStreamPlayer3D:
	var stream: AudioStreamWAV = _bank[_tire_key(vehicle)]
	var player: AudioStreamPlayer3D = _player("Tire", TIRE_DB)
	player.stream = stream
	player.play(_rng.randf() * stream.get_length())   # araçlar aynı fazda uğuldamasın
	player.stream_paused = true
	return player


## Lastik çeşidi: gerçek boy (cars.json real_dimensions) kısa → küçük, uzun ya da kamyonet → iri.
static func _tire_key(vehicle: Node3D) -> String:
	var traffic_vehicle: TrafficVehicle = vehicle as TrafficVehicle
	if traffic_vehicle == null:
		return "tire"
	var entry: Dictionary = CarCatalog.get_entry(traffic_vehicle.vehicle_id)
	var dims: Variant = entry.get("real_dimensions", {})
	var length: float = float((dims as Dictionary).get("length_m", 4.5)) if dims is Dictionary else 4.5
	if String(entry.get("category", "")) == "van" or length >= TIRE_BIG_LENGTH:
		return "tire_big"
	return "tire_small" if length < TIRE_SMALL_LENGTH else "tire"


## Egzotik olmayan trafik aracının motoru (polis aracına yok: sireni var). Döngü farklı yerden başlar, küçük perde farkı.
func _motor_for(vehicle: Node3D) -> TrafficEngine:
	var traffic_vehicle: TrafficVehicle = vehicle as TrafficVehicle
	if traffic_vehicle == null or traffic_vehicle.vehicle_id == &"" or CarCatalog.is_exotic(traffic_vehicle.vehicle_id) \
			or String(traffic_vehicle.vehicle_id).begins_with("police"):
		return null
	var kind: TrafficEngine.Kind = TrafficEngine.kind_of(traffic_vehicle.vehicle_id)
	var stream: AudioStreamWAV = (_bank["traffic_engines"] as Dictionary).get(kind)
	if stream == null:
		return null
	var motor: TrafficEngine = TrafficEngine.new()
	motor.setup(stream, kind, _rng.randf_range(0.95, 1.05), BUS)
	motor.attenuation_filter_cutoff_hz = AIR_CUTOFF
	add_child(motor)
	motor.global_position = vehicle.global_position
	motor.play(_rng.randf() * stream.get_length())
	motor.stream_paused = true
	return motor


## Yoldaki trafik araçlarının motorları (QA / test).
func traffic_engines() -> Array[TrafficEngine]:
	var out: Array[TrafficEngine] = []
	for entry: Dictionary in _tires.values():
		if entry["motor"]:
			out.append(entry["motor"])
	return out


## Şu an duyulan (sessiz olmayan) trafik motoru sayısı (QA / test).
func audible_engine_count() -> int:
	var n: int = 0
	for motor: TrafficEngine in traffic_engines():
		if motor.playing and not motor.stream_paused:
			n += 1
	return n


## Egzotik araca motor sesi (diğerlerine null). Döngü farklı yerden başlar, araç başına küçük perde farkı.
func _engine_for(vehicle: Node3D) -> ExoticEngine:
	var traffic_vehicle: TrafficVehicle = vehicle as TrafficVehicle
	if traffic_vehicle == null or not CarCatalog.is_exotic(traffic_vehicle.vehicle_id):
		return null
	var cylinders: int = ExoticEngine.cylinders_of(traffic_vehicle.vehicle_id)
	var stream: AudioStreamWAV = (_bank["engines"] as Dictionary).get(cylinders)
	if stream == null:
		return null
	var engine: ExoticEngine = ExoticEngine.new()
	engine.setup(stream, cylinders, _rng.randf_range(0.97, 1.03), BUS)
	engine.attenuation_filter_cutoff_hz = AIR_CUTOFF
	add_child(engine)
	engine.global_position = vehicle.global_position
	engine.play(_rng.randf() * stream.get_length())
	engine.stream_paused = true
	return engine


## Yoldaki egzotik araçların motorları (QA / test).
func exotic_engines() -> Array[ExoticEngine]:
	var out: Array[ExoticEngine] = []
	for entry: Dictionary in _tires.values():
		if entry["engine"]:
			out.append(entry["engine"])
	return out


func _vehicles() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _manager == null:
		return out
	for vehicle: TrafficVehicle in _manager.vehicles:
		if is_instance_valid(vehicle):
			out.append(vehicle)
	if _manager.chase:
		for vehicle: TrafficVehicle in _manager.chase.vehicles():
			out.append(vehicle)
	return out


# --- Kuşlar -----------------------------------------------------------------------------------

## Bir kuş seçilir (tür + ağaç + perde), 1–3 cümle öter; sonra sessizlik.
func _tick_birds(delta: float, camera: Camera3D) -> void:
	_bird_timer -= delta
	if _bird_timer > 0.0:
		return
	if _bird_phrases <= 0:
		_bird_phrases = _rng.randi_range(1, 3)
		_bird_kind = _pick_bird()
		_bird_spot = _pick_tree(camera)
		_bird_pitch = _rng.randf_range(0.93, 1.07)
	var variants: Array = (_bank["birds"] as Array)[_bird_kind]
	var player: AudioStreamPlayer3D = _birds[_bird_turn % _birds.size()]
	_bird_turn += 1
	player.stream = variants[_rng.randi() % variants.size()]
	player.pitch_scale = _bird_pitch * _rng.randf_range(0.98, 1.02)
	player.global_position = _bird_spot
	player.play()
	_bird_phrases -= 1
	_bird_timer = _rng.randf_range(PHRASE_GAP.x, PHRASE_GAP.y) if _bird_phrases > 0 \
		else _rng.randf_range(BIRD_GAP.x, BIRD_GAP.y)


func _pick_bird() -> int:
	var roll: float = _rng.randf()
	for kind: int in BIRD_WEIGHTS.size():
		roll -= BIRD_WEIGHTS[kind]
		if roll <= 0.0:
			return kind
	return Bird.SPARROW


## Dinleyicinin yakınındaki, mümkünse ekranda görünen bir ağaç; ağaç yoksa yakında rastgele bir nokta.
func _pick_tree(camera: Camera3D) -> Vector3:
	var focus: Vector3 = WorldCamera.ground_point(camera) if camera else Vector3.ZERO
	var near: Array[Vector3] = []
	var seen: Array[Vector3] = []
	var nearest: Vector3 = Vector3.INF
	for spot: Vector3 in _trees:
		var d: float = Vector2(spot.x - focus.x, spot.z - focus.z).length()
		if nearest == Vector3.INF or d < Vector2(nearest.x - focus.x, nearest.z - focus.z).length():
			nearest = spot
		if d <= BIRD_RANGE:
			near.append(spot)
			if camera and camera.is_position_in_frustum(spot):
				seen.append(spot)
	if not seen.is_empty():
		return seen[_rng.randi() % seen.size()]
	if not near.is_empty():
		return near[_rng.randi() % near.size()]
	if nearest != Vector3.INF:
		return nearest
	var a: float = _rng.randf() * TAU
	return focus + Vector3(cos(a), 0.6, sin(a)) * 4.0


# --- Korna ve uzak cıyaklama ------------------------------------------------------------------

## Yoldaki, mümkünse ekranda görünen hareketli bir araçtan kısa korna (aracın kendi kornası); yoksa uzaktan bir yoldan.
func _honk(camera: Camera3D) -> void:
	var seen: Array[Node3D] = []
	var moving: Array[Node3D] = []
	for key: Variant in _tires:
		if not is_instance_valid(key) or float(_tires[key]["speed"]) < 0.2:
			continue
		var vehicle: Node3D = key
		moving.append(vehicle)
		if camera and camera.is_position_in_frustum(vehicle.global_position):
			seen.append(vehicle)
	var pool: Array[Node3D] = seen if not seen.is_empty() else moving
	if pool.is_empty():
		var horns: Array = _bank["horns"]
		var player: AudioStreamPlayer3D = _free_horn(null)
		player.stream = horns[_rng.randi() % horns.size()]
		player.pitch_scale = _rng.randf_range(0.94, 1.07)
		player.global_position = _road_point(camera, _rng.randf_range(SQUEAL_DISTANCE.x, SQUEAL_DISTANCE.y))
		player.play()
		_last_honk = _clock
		return
	honk_from(pool[_rng.randi() % pool.size()], _pick_pattern())


## Aracın kendi kornası (TrafficEngine.horn_kind; egzotik / polis: klasik çift ton), `pattern` HORN_PATTERNS sırası.
## Kornalar arası HONK_SPACING'den kısaysa çalmaz (false).
func honk_from(vehicle: Node3D, pattern: int) -> bool:
	if not _started or _clock - _last_honk < HONK_SPACING or not is_instance_valid(vehicle):
		return false
	var horn: TrafficEngine.Horn = TrafficEngine.Horn.CLASSIC_DUAL
	var traffic_vehicle: TrafficVehicle = vehicle as TrafficVehicle
	if traffic_vehicle and traffic_vehicle.vehicle_id != &"" and not CarCatalog.is_exotic(traffic_vehicle.vehicle_id):
		horn = TrafficEngine.horn_kind(TrafficEngine.kind_of(traffic_vehicle.vehicle_id))
	var streams: Array = (_bank["car_horns"] as Dictionary)[horn]
	var player: AudioStreamPlayer3D = _free_horn(vehicle)
	player.stream = streams[clampi(pattern, 0, streams.size() - 1)]
	player.pitch_scale = _rng.randf_range(0.97, 1.03)
	player.global_position = vehicle.global_position + Vector3.UP * 0.1
	player.play()
	_last_honk = _clock
	return true


## Boş korna kanalı (ikisi de çalıyorsa önce başlayan); hedefi kaydedilir (ses araçla gider).
func _free_horn(target: Node3D) -> AudioStreamPlayer3D:
	var index: int = 0
	for i: int in _horns.size():
		if not _horns[i].playing:
			index = i
			break
		if _horns[i].get_playback_position() > _horns[index].get_playback_position():
			index = i
	_horn_targets[index] = target
	return _horns[index]


func _pick_pattern() -> int:
	var roll: float = _rng.randf()
	for i: int in HORN_PATTERN_WEIGHTS.size():
		roll -= HORN_PATTERN_WEIGHTS[i]
		if roll <= 0.0:
			return i
	return TrafficEngine.HORN_TAP


## Bağlamlı korna: önündeki araç yüzünden duran (kırmızı değil) araç, duruşun başında bir eşik seçer; eşik geçilince bir
## kez, şansına göre korna çalar. Öndeki dörtlü yakmışsa çabuk ve çoğunlukla (dıt / dıt-dıt), değilse geç ve seyrek
## (uzun / sabırsız).
func _context_honks() -> void:
	for key: Variant in _tires:
		var vehicle: TrafficVehicle = key as TrafficVehicle if is_instance_valid(key) else null
		if vehicle == null:
			continue
		var entry: Dictionary = _tires[key]
		if vehicle.stuck_time <= 0.0:
			entry["honk_at"] = -1.0   # yürüyor: sonraki duruşta yeni eşik
			continue
		var hazard: bool = vehicle.leader != null and is_instance_valid(vehicle.leader) and vehicle.leader.is_hazard_stopped()
		if float(entry["honk_at"]) < 0.0:
			var window: Vector2 = HAZARD_HONK_AFTER if hazard else JAM_HONK_AFTER
			var chance: float = HAZARD_HONK_CHANCE if hazard else JAM_HONK_CHANCE
			entry["honk_at"] = _rng.randf_range(window.x, window.y) if _rng.randf() < chance else INF
		if vehicle.stuck_time >= float(entry["honk_at"]):
			var pattern: int = (TrafficEngine.HORN_TAP if _rng.randf() < 0.5 else TrafficEngine.HORN_DOUBLE) if hazard \
				else (TrafficEngine.HORN_LONG if _rng.randf() < 0.5 else TrafficEngine.HORN_ANGRY)
			if honk_from(vehicle, pattern):
				entry["honk_at"] = INF


## Süper araç kalkışı: arka lastiklerden kısa cıyak (araçla birlikte gider).
func _on_launched(vehicle: TrafficVehicle) -> void:
	if not _started or _goal_db() <= SILENT_DB or not is_instance_valid(vehicle):
		return
	_chirp.stream = _bank["chirp"]
	_chirp.pitch_scale = _rng.randf_range(1.02, 1.12)
	_chirp_target = vehicle
	_chirp.global_position = vehicle.global_position + Vector3.UP * 0.03
	_chirp.play()


func _far_squeal() -> void:
	var squeals: Array = _bank["squeals"]
	_squeal.stream = squeals[_rng.randi() % squeals.size()]
	_squeal.pitch_scale = _rng.randf_range(0.92, 1.06)
	_squeal.global_position = _road_point(get_viewport().get_camera_3d(), _rng.randf_range(SQUEAL_DISTANCE.x, SQUEAL_DISTANCE.y))
	_squeal.play()


## Dinleyiciden `distance` uzakta, iki ana yoldan birinin üstünde bir nokta (ses ekran dışındaki yoldan gelir).
func _road_point(camera: Camera3D, distance: float) -> Vector3:
	var focus: Vector3 = WorldCamera.ground_point(camera) if camera else Vector3.ZERO
	var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
	if _rng.randf() < 0.5:
		return Vector3(focus.x + side * distance, 0.05, ROAD_CENTER)
	return Vector3(ROAD_CENTER, 0.05, focus.z + side * distance)


# --- Sentez (arka plan) ------------------------------------------------------------------------

static func _synthesize() -> void:
	_bank = AudioCache.fetch("city_ambience", _build_bank)   # tek atama: ana iş parçacığı yalnızca görev bitince okur


## Bankanın sentezi (sabit tohum: her seferinde aynı ses; AudioCache sürüm başına bir kez çağırır).
static func _build_bank() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261017
	var birds: Array = []
	for kind: int in BIRD_WEIGHTS.size():
		var variants: Array[AudioStreamWAV] = []
		for v: int in VARIANTS:
			variants.append(_to_wav(_bird_phrase(kind, rng), 0.8, false))
		birds.append(variants)
	var bank: Dictionary = {
		"hum": _to_wav(_make_hum(12.0, rng), 0.7, true),
		"tire": _to_wav(_make_tire(3.0, rng), 0.7, true),
		"tire_small": _to_wav(_make_tire(3.0, rng, 1.25, 0.7, 1.2), 0.62, true),
		"tire_big": _to_wav(_make_tire(3.0, rng, 0.72, 1.6, 0.8), 0.8, true),
		"birds": birds,
		"horns": [
			TrafficSfx.horn_stream([[0.0, 0.12]], 440.0, 554.0),                                  # kısa "dıt"
			TrafficSfx.horn_stream([[0.0, 0.1], [0.16, 0.12]], 415.0, 523.0),                     # "dıt-dıt"
			TrafficSfx.horn_stream([[0.0, 0.42]], 392.0, 494.0),                                  # uzun "döööt"
			TrafficSfx.horn_stream([[0.0, 0.55]], 196.0, 247.0),                                  # kamyon
			TrafficSfx.horn_stream([[0.0, 0.08], [0.13, 0.08], [0.26, 0.2]], 466.0, 587.0),      # sabırsız
		],
		"squeals": [TrafficSfx.squeal_stream(0.7, 11), TrafficSfx.squeal_stream(1.0, 23)],
		"chirp": TrafficSfx.squeal_stream(0.45, 41),
		"engines": {6: ExoticEngine.make_stream(6), 8: ExoticEngine.make_stream(8), 10: ExoticEngine.make_stream(10)},
		"traffic_engines": {},
		"car_horns": {},
	}
	for kind: int in TrafficEngine.Kind.values():
		(bank["traffic_engines"] as Dictionary)[kind] = TrafficEngine.make_stream(kind as TrafficEngine.Kind)
	for horn: int in TrafficEngine.Horn.values():
		(bank["car_horns"] as Dictionary)[horn] = TrafficEngine.horn_streams(horn as TrafficEngine.Horn)
	return bank


## UZAK ŞEHİR UĞULTUSU: kalın gürültü (alçak geçiren ×2) + uzaktan geçen araçlar gibi kabarıp sönen orta bant + çok
## hafif rüzgâr. Kabarmalar döngüde tam tur sayısında (dikiş yok); süzgeçler döngünün sonundan ısınır.
static func _make_hum(seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count: int = int(seconds * MIX_RATE)
	var white: PackedFloat32Array = _noise(count, rng)
	var low: PackedFloat32Array = _low_pass(_low_pass(white, 240.0), 240.0)
	var wide: PackedFloat32Array = _low_pass(white, 1300.0)
	var floor_band: PackedFloat32Array = _low_pass(white, 420.0)
	var air: PackedFloat32Array = _low_pass(white, 5000.0)
	var air_floor: PackedFloat32Array = _low_pass(white, 2200.0)
	var phases: Array[float] = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for i: int in count:
		var u: float = float(i) / float(count)
		var swell: float = 0.55 + 0.25 * sin(TAU * 2.0 * u + phases[0]) + 0.2 * sin(TAU * 5.0 * u + phases[1])
		var gust: float = 0.5 + 0.5 * sin(TAU * 3.0 * u + phases[2]) * sin(TAU * 1.0 * u + phases[3])
		out[i] = low[i] * 3.2 + (wide[i] - floor_band[i]) * 0.9 * swell + (air[i] - air_floor[i]) * 0.12 * gust
	return out


## LASTİK / YOL SESİ: asfaltta yuvarlanan lastik — 220–1600 Hz bandında gürültü + hafif gövde uğultusu, diş deseni
## gibi küçük titreşim (döngüde tam tur). `band` bandı kaydırır (küçük araç tiz, iri araç pes), `rumble` gövde
## uğultusunun payı, `tread` diş deseninin sıklığı.
static func _make_tire(seconds: float, rng: RandomNumberGenerator, band: float = 1.0, rumble_gain: float = 1.0,
		tread_rate: float = 1.0) -> PackedFloat32Array:
	var count: int = int(seconds * MIX_RATE)
	var white: PackedFloat32Array = _noise(count, rng)
	var band_top: PackedFloat32Array = _low_pass(_low_pass(white, 1600.0 * band), 1600.0 * band)
	var band_bottom: PackedFloat32Array = _low_pass(white, 220.0 * band)
	var rumble: PackedFloat32Array = _low_pass(_low_pass(white, 110.0 * band), 110.0 * band)
	var slow: float = round(63.0 * tread_rate)
	var fast: float = round(97.0 * tread_rate)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for i: int in count:
		var u: float = float(i) / float(count)
		var tread: float = 1.0 + 0.08 * sin(TAU * slow * u) + 0.05 * sin(TAU * fast * u)
		out[i] = ((band_top[i] - band_bottom[i]) * 1.4 + rumble[i] * 4.0 * rumble_gain) * tread
	return out


## Kuş cümlesi (tür başına farklı desen; rng her çağrıda başka varyant).
static func _bird_phrase(kind: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(1.6 * MIX_RATE))
	var t: float = 0.02
	match kind:
		Bird.SPARROW:   # cik-cik: kısa, aşağı kayan cıvıltılar
			for k: int in rng.randi_range(3, 6):
				if rng.randf() < 0.35:
					_note(out, t, 0.025, 3800.0, 5600.0, 0.5)   # önünde küçük kalkış
					t += 0.025
				var dur: float = rng.randf_range(0.045, 0.075)
				_note(out, t, dur, rng.randf_range(5200.0, 6400.0), rng.randf_range(3400.0, 4200.0),
					rng.randf_range(0.7, 1.0), 0.0, 0.0, 0.15, 0.7)
				t += dur + rng.randf_range(0.06, 0.12)
		Bird.TIT:   # "ti-tüü" ×3–4 (büyük baştankara)
			var high: float = rng.randf_range(4100.0, 4500.0)
			var low: float = rng.randf_range(2950.0, 3250.0)
			for k: int in rng.randi_range(3, 4):
				_note(out, t, 0.08, high, high - 200.0, 0.9)
				_note(out, t + 0.11, 0.12, low, low - 100.0, 0.85)
				t += 0.3
		Bird.TRILL:   # hızlı tekrar eden notalar, yavaşça söner
			var notes: int = rng.randi_range(12, 18)
			var base: float = rng.randf_range(3400.0, 3900.0)
			for k: int in notes:
				var fade: float = 1.0 - 0.45 * float(k) / float(notes)
				_note(out, t, 0.032, base, base + 1000.0, 0.8 * fade)
				t += 0.05
		Bird.BLACKBIRD:   # yumuşak, melodik ıslık (vibratolu), sonunda kısa tiz süs
			var scale: Array[float] = [1800.0, 2000.0, 2250.0, 2400.0, 2700.0, 3000.0]
			var previous: float = scale[rng.randi() % scale.size()]
			for k: int in rng.randi_range(3, 5):
				var next: float = scale[rng.randi() % scale.size()]
				var dur: float = rng.randf_range(0.12, 0.22)
				_note(out, t, dur, previous, next, 0.85, 7.0, 0.012, 0.05)
				previous = next
				t += dur + rng.randf_range(0.02, 0.06)
			_note(out, t, 0.06, 4600.0, 3800.0, 0.45)
		Bird.PIGEON:   # güvercin "hu-huuu-hu": kalın, nefesli
			var pitch: float = rng.randf_range(0.94, 1.06)
			_coo(out, t, 0.18, 440.0 * pitch, 420.0 * pitch, 0.6, rng)
			_coo(out, t + 0.26, 0.38, 470.0 * pitch, 425.0 * pitch, 1.0, rng)
			_coo(out, t + 0.72, 0.2, 420.0 * pitch, 400.0 * pitch, 0.55, rng)
	# Sert tiz kısılır (telefon hoparlöründe cızırtı olmasın); cümle sonundaki boşluk kırpılır
	var soft: PackedFloat32Array = _low_pass(out, 7500.0, false)
	var last: int = soft.size() - 1
	while last > 0 and absf(soft[last]) < 0.0005:
		last -= 1
	return soft.slice(0, mini(last + int(0.05 * MIX_RATE), soft.size()))


## Tek nota: f0 → f1 kayar (`curve` < 1 başta hızlı), isteğe bağlı vibrato, 2. harmonik, yumuşak çan zarfı.
static func _note(out: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float,
		vib_rate: float = 0.0, vib_depth: float = 0.0, h2: float = 0.12, curve: float = 1.0) -> void:
	var start: int = int(at * MIX_RATE)
	var count: int = int(dur * MIX_RATE)
	var phase: float = 0.0
	for i: int in count:
		if start + i >= out.size():
			return
		var u: float = float(i) / float(count)
		var f: float = lerpf(f0, f1, pow(u, curve)) * (1.0 + vib_depth * sin(TAU * vib_rate * float(i) / MIX_RATE))
		phase += TAU * f / MIX_RATE
		var env: float = pow(sin(PI * u), 0.7)
		out[start + i] += amp * env * (sin(phase) + h2 * sin(2.0 * phase))


## Güvercin hecesi: kalın ton + 2. / 3. harmonik + nefes gürültüsü, yavaş atak.
static func _coo(out: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float,
		rng: RandomNumberGenerator) -> void:
	var start: int = int(at * MIX_RATE)
	var count: int = int(dur * MIX_RATE)
	var phase: float = 0.0
	var breath: float = 0.0
	for i: int in count:
		if start + i >= out.size():
			return
		var u: float = float(i) / float(count)
		phase += TAU * lerpf(f0, f1, u) / MIX_RATE
		breath += 0.08 * (rng.randf_range(-1.0, 1.0) - breath)
		var env: float = smoothstep(0.0, 0.35, u) * smoothstep(1.0, 0.6, u)
		out[start + i] += amp * env * (0.6 * sin(phase) + 0.25 * sin(2.0 * phase) + 0.08 * sin(3.0 * phase) + 0.5 * breath)


static func _noise(count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for i: int in count:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## Tek kutuplu alçak geçiren. `circular`: döngülü ses için süzgeç dizinin sonundan ısınır (dikişte sıçrama olmaz).
static func _low_pass(x: PackedFloat32Array, cutoff: float, circular: bool = true) -> PackedFloat32Array:
	var a: float = 1.0 - exp(-TAU * cutoff / MIX_RATE)
	var n: int = x.size()
	var state: float = 0.0
	if circular:
		for i: int in range(n - mini(n, 8192), n):
			state += a * (x[i] - state)
	var y: PackedFloat32Array = PackedFloat32Array()
	y.resize(n)
	for i: int in n:
		state += a * (x[i] - state)
		y[i] = state
	return y


## Tepe `peak`'e ölçeklenip 16 bit; `loop`: ileri döngü.
static func _to_wav(samples: PackedFloat32Array, peak: float, loop: bool) -> AudioStreamWAV:
	var top: float = 0.0001
	for s: float in samples:
		top = maxf(top, absf(s))
	var gain: float = peak / top
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		LoopedWav.loop_forward(wav)
	return wav
