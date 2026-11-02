class_name DriftEvent
extends Node
## JAPON DRIFT GÖSTERİSİ (2026-11-02, kullanıcı: "5 yeni japon otomobilimiz var. gtr hariç 4ü gerçekten tam bir drift
## makinesi. nadir bir olasılıkla 2şer araç olacak şekilde şehirde drift atıp gitmelerini istiyorum ... lastik sesleri,
## dumanlar, güzel drift görüntüsü ve tam o araçlar geçerken oyun müziğinin biraz değişip japon drift müziği gibi olmasını
## istiyorum. tam girmeden sahneye müzik başlayacak, oyuncu anlayacak ve işlerini bitirip bakacak. gerçekten nadir").
##
## NE OLUR: Supra / NSX / RX-7 / AE86'dan (DRIFT_IDS; R34 dört çeker, yok) şehirde olmayan ikisi TANDEM gelir: giriş
## yolunda manji (sağa sola savrularak kayma), virajdan önce çalım, kavşakta büyük açılı dönüş, çıkış yolunda yine manji,
## sonra uzaklaşır. Arka lastiklerden kalın duman (DriftSmoke), yolda kalan siyah izler (SkidMarks, ~1 dk), lastik
## cıyağı ve aracın kendi pişmiş motor sesi yüksek devirde (EngineVoice). Rota ve pozlar önceden hesaplanır (DriftLine).
## MÜZİK: gösteri başlarken garaj teması susar, JAPON DRIFT TEMASI (Eurobeat, tools/music/drift_theme.py) girişiyle
## başlar; giriş MUSIC_DROP sn sürer ve "drop" tam öndeki aracın ekrana girdiği ana denk gelir (araçlar o andan
## APPROACH sn önce ekran dışında doğar: motor sesi yaklaşırken duyulur). Saat müziğin çalma konumuna bağlıdır.
##
## NADİRLİK: şehir ekranda geçen süreyle sayılır (dünyayı örten yer / eğitim sırasında saymaz), oturumlar arası kalıcı
## (user://city_events.cfg): ilk gösteri toplam FIRST_AFTER sn sonra, sonra EVERY aralığında bir. Süre dolunca koşullar
## (ekran / pano açık değil, kovalamaca / trafik polisi / yarış daveti yok, eğitim yok) ve kamera uygun olana dek bekler.
## ROTA (kullanıcı: "sürekli aynı yoldan gelmesin, 4 yoldan da rastgele gelebilir"): giriş yolu dört yoldan RASTGELE
## (bir önceki gösterinin girişi hemen tekrarlanmaz); dönüş yönü kameranın gördüğüne göre ağırlıklı (görünen dönüş daha
## olası, ikisi de mümkün). Seçilen yolun hiçbir dönüşü ekranda değilse sıradaki rastgele yol denenir.
## OPTİMİZASYON: rotalar (çizgi + iki aracın çizelgesi) yalnız gösteri yaklaşınca arka plan iş parçacığında kurulur ve
## gösteriden sonra bırakılır; modeller arka planda yüklenir, sonra bırakılır; arka teker noktaları araç başına bir kez
## ölçülür; duman tek MultiMesh (yalnız canlı topaklar işlenir, boştayken düğüm uyur); izler tek mesh (yalnız büyüyen
## şeritler yeniden hesaplanır, solarken yalnız bir shader değeri değişir); boştayken saniyede birkaç ucuz sayaç işlemi.
##
## SAHNE (çarpışma yok): HAZIRLIK'ta yeni araç doğmaz (yarış daveti de), kavşağa yalnız boşalması gereken iki şerit
## (giriş şeridi ve çıkış yolunun karşı şeridi) girer; bu şeritler, kavşak ve çıkış yolunun başı boşalınca gösteri başlar
## (PREPARE_MAX'ta boşalmazsa vazgeçilir). Gösteride kavşak herkese kapalı; araçlar kavşağı geçince açılır, gidince doğum
## sürer. Bekleyen müşterinin sabrı bu sırada işlemez (kaldırımdan çıkıp yola girmesin).
## Test için: CT_DRIFT_IN=<sn> ortam değişkeni sayacı kurar; QA / test start_now ile hemen başlatır.

signal show_started(lead_id: StringName, follow_id: StringName)
signal show_finished

enum Phase { IDLE, LOADING, PREPARE, SHOW }

const DRIFT_IDS: Array[StringName] = [&"toyota_supra", &"honda_nsx", &"mazda_rx7", &"toyota_ae86"]
const FIRST_AFTER: float = 9.0 * 60.0
const EVERY: Vector2 = Vector2(14.0 * 60.0, 24.0 * 60.0)
## Modeller süre dolmadan bu kadar önce arka planda yüklenir; koşullar uygun değilse RETRY sn'de bir yeniden bakılır.
const PRELOAD_LEAD: float = 25.0
const RETRY: float = 3.0
## Hazırlık bu sürede boşalmazsa vazgeçilir, ABORT_PAUSE sonra yeniden denenir.
const PREPARE_MAX: float = 25.0
const ABORT_PAUSE: float = 40.0
## Müzikte "drop" (tools/music/drift_theme.py: 155 BPM, 4 ölçü giriş) ve ekrana girmeden önceki yaklaşma süresi.
const MUSIC_DROP: float = 16.0 * 60.0 / 155.0
const APPROACH: float = 2.2
## Rota puanı: kameranın gördüğü çizgi uzunluğu (virajdaki kısım iki kat sayılır); en az bu kadar olmalı. Dönüş ağırlığı
## = puan + TURN_BIAS (görünmeyen ama eşiği geçen dönüş de seçilebilsin).
const MIN_SCORE: float = 3.0
const TURN_BIAS: float = 2.0
## Dört giriş yönü (rota sırası: her girişin önce sağa, sonra sola dönüşü).
const ENTRIES: Array[Vector3] = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
## Hazırlıkta sahne bu aralıkla denetlenir (sn).
const STAGE_CHECK: float = 0.25
const SCORE_STEP: float = 0.1
## Ekranın HUD şeritleri (oran): üstte profil / düğmeler, altta plakalar — rota orada görünse de sayılmaz.
const SCREEN_TOP: float = 0.14
const SCREEN_BOTTOM: float = 0.86
const SCREEN_SIDE: float = 0.04
## Araç tıklama kutusu benzeri gövde (yarı boy / yarı en, birim): arka teker hizası ve test.
const HALF_LENGTH: float = 0.335
const HALF_WIDTH: float = 0.135
## Sesler (dB, Ambience bus'ında; kaynak dinleyiciden unit_size uzaktayken). Ölçüldü (qa/drift_event_qa.gd, bus kayıtları):
## iki motor tam gazda / yüksek devirde çok gür; araçlar ekranın ortasından geçerken toplam ses müziğin ~3 dB üstünde,
## cıyak motorun ~4 dB altında kalsın.
const ENGINE_DB: float = -16.0
const ENGINE_DYNAMICS: float = 0.8
const SQUEAL_DB: float = -14.0
const SQUEAL_PATH: String = "res://assets/audio/sfx/drift_squeal.wav"
const UNIT_SIZE: float = 3.5
const MAX_DISTANCE: float = 30.0
const AIR_CUTOFF: float = 6000.0
## Kalıcı sayaç.
const STATE_PATH: String = "user://city_events.cfg"
const SAVE_EVERY: float = 20.0
## Aynı şerit sayılan yön benzerliği.
const LANE_DOT: float = 0.9
## Araçlar kavşağı geçince ışıkta bekleyen (ekrandaki) bir araç bu olasılıkla, bu kadar sonra "dıt-dıt" çalar (seyirci).
const CHEER_CHANCE: float = 0.7
const CHEER_DELAY: float = 0.5

## Önceden hesaplanan rotalar (sekiz; arka plan iş parçacığında bir kez): {"line", "lead", "follow"}.
static var _routes: Array[Dictionary] = []

var phase: Phase = Phase.IDLE
var _manager: TrafficManager
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _left: float = FIRST_AFTER
var _save_timer: float = SAVE_EVERY
var _retry: float = 0.0
var _ids: Array[StringName] = []
var _loading: Dictionary = {}       # id → yol (arka planda yükleniyor)
var _scenes: Dictionary = {}        # id → PackedScene
var _route_task: int = -1
var _route_result: Array[Dictionary] = []
var _route: Dictionary = {}
var _last_entry: int = -1
var _prepare_time: float = 0.0
var _stage_timer: float = 0.0
var _router_ref: UiRouter
var _director_ref: TutorialDirector
var _wheel_offsets: Array = []      # araç başına arka teker noktaları (araç uzayında, y = 0)
var _tracks: Array[DriftLine.Track] = []
var _clock: float = 0.0
var _spawn_clock: float = 0.0       # araçların doğduğu saat (gösteri saatinde)
var _track_offset: float = 0.0      # o anda çizelgenin zamanı
var _cars: Array[TrafficVehicle] = []
var _spawned: bool = false
var _crossing_open: bool = false
var _music_on: bool = false
var _smoke: DriftSmoke
var _marks: SkidMarks
## Araç başına ses: {"engine": AudioStreamPlayer3D, "voice": EngineVoice, "squeal": AudioStreamPlayer3D,
## "squeal_db": float, "pitch": float, "last": Vector3}
var _audio: Array[Dictionary] = []
## Kayıt dışı (test / QA): sayaç kalıcı dosyaya yazılmaz.
var persist: bool = true
## Ek kazanç (dB; QA motoru / cıyağı ayrı ölçmek için -80 yapar).
var engine_gain_db: float = 0.0
var squeal_gain_db: float = 0.0


func _ready() -> void:
	name = "DriftEvent"
	_manager = get_parent() as TrafficManager
	_rng.randomize()
	_load_state()
	var env: String = OS.get_environment("CT_DRIFT_IN")
	if env != "" and env.is_valid_float():
		_left = maxf(float(env), 0.0)


func _exit_tree() -> void:
	if _route_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_route_task)
		_route_task = -1
	if _music_on:
		GameMusic.drift(get_tree(), false)
		_music_on = false
	_save_state()


# --- Dış API (TrafficManager, PoliceChase, RepairManager…) -----------------------------------------------

## Hazırlık ya da gösteri sürüyor mu (kovalamaca / trafik polisi / dörtlü / müşteri sabrı bekler).
func is_busy() -> bool:
	return phase == Phase.PREPARE or phase == Phase.SHOW


## Yeni trafik aracı ve yarış daveti doğmasın mı?
func holds_spawns() -> bool:
	return is_busy()


## Bu araç kavşağa girmesin mi? Hazırlıkta yalnız boşalan iki şerit (giriş şeridi, çıkış yolunun karşı şeridi) girer;
## gösteride araçlar kavşağı geçene dek kimse girmez.
func blocks_crossing(vehicle: TrafficVehicle) -> bool:
	if phase == Phase.PREPARE:
		var heading: Vector3 = _heading(vehicle)
		var line: DriftLine = _route.get("line") as DriftLine
		if line == null:
			return true
		return heading.dot(line.entry_dir) < LANE_DOT and heading.dot(-line.exit_dir()) < LANE_DOT
	return phase == Phase.SHOW and not _crossing_open


## Gösterideki araçlar.
func vehicles() -> Array[TrafficVehicle]:
	var out: Array[TrafficVehicle] = []
	for car: TrafficVehicle in _cars:
		if is_instance_valid(car):
			out.append(car)
	return out


## Gösteri için ayrılmış modeller (yükleniyor / bekliyor / şehirde): aynı modelden ikinci araç doğmasın.
func reserved_models() -> Array[StringName]:
	return _ids if phase != Phase.IDLE else ([] as Array[StringName])


## Bir sonraki gösteriye kalan şehir süresi (sn).
func time_left() -> float:
	return _left


## Sayacı kurar (test / QA).
func set_time_left(seconds: float) -> void:
	_left = seconds


## Şimdi başlat (QA / test): modeller eşzamanlı yüklenir. `entry` / `turn` verilirse o rota (yoksa kameraya göre),
## `pair` verilirse o iki araç, `skip_prepare` ile şeritlerin boşalması beklenmez.
func start_now(entry: Vector3 = Vector3.ZERO, turn: int = 0, pair: Array[StringName] = [], skip_prepare: bool = false) -> bool:
	if is_busy() or _manager == null:
		return false
	_ids = pair.duplicate() if pair.size() == 2 else _pick_pair()
	if _ids.size() < 2:
		return false
	for id: StringName in _ids:
		if not _scenes.has(id):
			_scenes[id] = load(CarCatalog.scene_path(id)) as PackedScene
	_loading.clear()
	if _routes.is_empty():
		_ensure_routes(true)
	phase = Phase.LOADING
	if not _choose_route(entry, turn):
		_reset(RETRY)
		return false
	if skip_prepare:
		_start_show()
	else:
		_begin_prepare()
	return true


# --- Akış ------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match phase:
		Phase.IDLE:
			_count(delta)
			if _left <= PRELOAD_LEAD:
				_begin_loading()
		Phase.LOADING:
			_count(delta)
			_poll_loading()
			_ensure_routes(false)
			if _left > 0.0 or not _loading.is_empty() or _routes.is_empty():
				return
			_retry -= delta
			if _retry > 0.0:
				return
			_retry = RETRY
			if _conditions_ok() and _models_free() and _choose_route(Vector3.ZERO, 0):
				_begin_prepare()
		Phase.PREPARE:
			_prepare_time += delta
			_stage_timer -= delta
			if _stage_timer > 0.0:
				return
			_stage_timer = STAGE_CHECK
			if not _conditions_ok(true):
				_reset(ABORT_PAUSE)
			elif _stage_ready():
				_start_show()
			elif _prepare_time > PREPARE_MAX:
				print("DriftEvent: şeritler boşalmadı, vazgeçildi")
				_reset(ABORT_PAUSE)
		Phase.SHOW:
			_tick_show(delta)


## Şehir görünürken sayaç işler (eğitimde ve dünyayı örten yerde durur).
func _count(delta: float) -> void:
	if _left <= 0.0 or not _city_visible() or _tutorial_running():
		return
	_left = maxf(_left - delta, 0.0)
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = SAVE_EVERY
		_save_state()


func _begin_loading() -> void:
	_ids = _pick_pair()
	if _ids.size() < 2:
		_left = PRELOAD_LEAD + 30.0   # dört araç da şehirde (çok nadir): biraz sonra
		return
	phase = Phase.LOADING
	_retry = 0.0
	for id: StringName in _ids:
		var path: String = CarCatalog.scene_path(id)
		if path != "" and ResourceLoader.load_threaded_request(path) == OK:
			_loading[id] = path
	_ensure_routes(false)


func _poll_loading() -> void:
	for id: StringName in _loading.keys():
		var path: String = _loading[id]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.THREAD_LOAD_LOADED:
				_scenes[id] = ResourceLoader.load_threaded_get(path) as PackedScene
		_loading.erase(id)


## Şehirde olmayan iki drift aracı (karışık sıra: önde giden rastgele).
func _pick_pair() -> Array[StringName]:
	var used: Dictionary = _manager.models_in_use() if _manager else {}
	var free: Array[StringName] = []
	for id: StringName in DRIFT_IDS:
		if not used.has(id) and CarCatalog.scene_path(id) != "":
			free.append(id)
	free.shuffle()
	return free.slice(0, 2) if free.size() >= 2 else ([] as Array[StringName])


## Seçilen modeller hâlâ yüklü ve şehirde değil mi (bu arada müşteri olarak gelmiş olabilir)?
func _models_free() -> bool:
	if _ids.size() < 2:
		return false
	for id: StringName in _ids:
		if not _scenes.has(id) or _scenes[id] == null:
			_reset(RETRY)
			return false
	return true


## Gösteri başlayabilir mi: ekran / pano kapalı, şehir görünür, eğitim yok, kovalamaca / trafik polisi / yarış daveti
## yok. `preparing`: hazırlık sürerken (pano açılırsa vazgeçilir).
func _conditions_ok(preparing: bool = false) -> bool:
	if _manager == null or not _city_visible() or _tutorial_running():
		return false
	var router: UiRouter = _router()
	if router and router.top() != &"":
		return false
	if _manager.chase and _manager.chase.is_active():
		return false
	if _manager.police and _manager.police.is_busy():
		return false
	if not preparing:
		for vehicle: TrafficVehicle in _manager.vehicles:
			if is_instance_valid(vehicle) and vehicle.race_lane:
				return false
	return true


# --- Rota ------------------------------------------------------------------------------------------

## Sekiz rotanın çizgi + çizelgeleri (araçtan bağımsız): bir kez, arka planda. `wait`: hemen bekle (QA / test).
func _ensure_routes(wait: bool) -> void:
	if not _routes.is_empty():
		return
	if _route_task < 0:
		_route_task = WorkerThreadPool.add_task(_build_routes)
	if not wait and not WorkerThreadPool.is_task_completed(_route_task):
		return
	WorkerThreadPool.wait_for_task_completion(_route_task)
	_route_task = -1
	_routes = _route_result
	_route_result = []


## İş parçacığında: yalnız bu düğümün alanına yazar.
func _build_routes() -> void:
	var out: Array[Dictionary] = []
	for e: int in ENTRIES.size():
		for turn: int in [-1, 1]:
			var line: DriftLine = DriftLine.build(ENTRIES[e], turn)
			var lead: DriftLine.Track = line.lead_track(&"", maxf(line.corner_from - 9.5, 0.0))
			var follow: DriftLine.Track = line.follow_track(&"", lead)
			out.append({"line": line, "lead": lead, "follow": follow, "entry": e})
	_route_result = out


## Giriş yolu rastgele (bir önceki giriş en sona bırakılır), dönüş kameraya göre ağırlıklı (bkz. başlık). `entry` /
## `turn` verilirse o rota. Hiçbir yolun hiçbir dönüşü görünmüyorsa false (sonra yeniden denenir).
func _choose_route(entry: Vector3, turn: int) -> bool:
	if entry != Vector3.ZERO:
		for route: Dictionary in _routes:
			var line: DriftLine = route["line"]
			if line.entry_dir.dot(entry.normalized()) > 0.99 and line.turn == turn:
				_route = route
				_last_entry = int(route["entry"])
				return true
		return false
	var camera: Camera3D = _manager.get_viewport().get_camera_3d() if _manager.is_inside_tree() else null
	var order: Array[int] = [0, 1, 2, 3]
	order.shuffle()
	if _last_entry >= 0:
		order.erase(_last_entry)
		order.append(_last_entry)   # aynı yoldan art arda gelmesin (başka yol görünmüyorsa yine de olabilir)
	for e: int in order:
		var options: Array[Dictionary] = []
		var weights: Array[float] = []
		var total: float = 0.0
		for route: Dictionary in _routes:
			if int(route["entry"]) != e:
				continue
			var score: float = route_score(route["line"], camera) if camera else MIN_SCORE
			if score >= MIN_SCORE:
				options.append(route)
				weights.append(score + TURN_BIAS)
				total += score + TURN_BIAS
		if options.is_empty():
			continue
		var pick: float = _rng.randf() * total
		var k: int = 0
		while k < options.size() - 1 and pick > weights[k]:
			pick -= weights[k]
			k += 1
		_route = options[k]
		_last_entry = e
		return true
	return false


## Rotanın ekranda (HUD şeritleri hariç) görünen uzunluğu; kavşaktaki dönüş iki kat sayılır.
static func route_score(line: DriftLine, camera: Camera3D) -> float:
	var rect: Rect2 = camera.get_viewport().get_visible_rect()
	var area: Rect2 = Rect2(rect.size.x * SCREEN_SIDE, rect.size.y * SCREEN_TOP,
		rect.size.x * (1.0 - SCREEN_SIDE * 2.0), rect.size.y * (SCREEN_BOTTOM - SCREEN_TOP))
	var score: float = 0.0
	var s: float = maxf(line.corner_from - 6.0, 0.0)
	while s < minf(line.corner_to + 6.0, line.length):
		var p: Vector3 = line.point_at(s) + Vector3.UP * 0.12
		if camera.is_position_in_frustum(p) and area.has_point(camera.unproject_position(p)):
			score += SCORE_STEP * (2.0 if s >= line.corner_from and s <= line.corner_to else 1.0)
		s += SCORE_STEP
	return score


# --- Hazırlık: şeritlerin boşalması ---------------------------------------------------------------------

func _begin_prepare() -> void:
	phase = Phase.PREPARE
	_prepare_time = 0.0
	_stage_timer = 0.0
	_save_state()   # son giriş yolu (sonraki gösteri başka yoldan)
	print("DriftEvent: hazırlık — %s + %s, giriş %s, dönüş %d" % [_ids[0], _ids[1],
		(_route["line"] as DriftLine).entry_dir, (_route["line"] as DriftLine).turn])


## Sahne boş mu: giriş şeridinde (kavşağa varmadan) ve çıkış yolunun karşı şeridinde araç yok, kavşak boş, giriş yolundan
## uzaklaşan araç ekrandan çıkmış, çıkış yolunda öne geçmiş araç uzaklaşmış (yetişilmesin), yanaşan / kaldırımdan çıkan
## müşteri yok. Kaldırımda bekleyen müşteriler ve tamirdekiler sayılmaz (çizgi onlardan uzak).
func _stage_ready() -> bool:
	var line: DriftLine = _route["line"]
	var f: Vector3 = line.entry_dir
	var e: Vector3 = line.exit_dir()
	var lf: Vector3 = Vector3.UP.cross(f)
	for vehicle: TrafficVehicle in _manager.vehicles:
		if not is_instance_valid(vehicle) or vehicle.in_bay() or vehicle.is_waiting():
			continue
		if vehicle.race_lane:
			return false
		var p: Vector3 = TrafficVehicle._flat(vehicle.global_position - DriftLine.CENTER)
		if absf(p.x) < 0.85 and absf(p.z) < 0.85:
			return false   # kavşakta
		var h: Vector3 = _heading(vehicle)
		var on_entry: bool = p.dot(f) < 0.0 and absf(p.dot(lf)) < 0.85
		var on_exit: bool = p.dot(e) > 0.0 and absf(p.dot(f)) < 0.85
		if on_entry and h.dot(f) > LANE_DOT:
			return false   # giriş şeridi boşalmadı
		if on_entry and h.dot(-f) > LANE_DOT and not _manager.is_hidden(vehicle.global_position):
			return false   # giriş yolundan uzaklaşan hâlâ ekranda (karşıdan gelen drift araçlarıyla burun buruna)
		if on_exit and h.dot(-e) > LANE_DOT:
			return false   # çıkış yolunun karşı şeridi boşalmadı
		if on_exit and (vehicle.is_customer() or vehicle.is_merging()):
			return false   # kaldırıma yanaşıyor / kaldırımdan çıkıyor
		if on_exit and h.dot(e) > LANE_DOT and p.dot(e) < 3.2:
			return false   # çıkış yolunda az önde: drift araçları yetişir
	return true


## Aracın yolda gittiği yön (gövdenin ileri ekseni, düz).
static func _heading(vehicle: TrafficVehicle) -> Vector3:
	var z: Vector3 = vehicle.global_transform.basis.z
	z.y = 0.0
	return z.normalized() if z.length_squared() > 0.0001 else Vector3.FORWARD


# --- Gösteri -----------------------------------------------------------------------------------------

func _start_show() -> void:
	phase = Phase.SHOW
	# Öndeki aracın ekrana girdiği çizelge anı: drop o ana denk gelir; araçlar APPROACH önce ekran dışında doğar. Doğmadan
	# hemen önce kameraya göre yeniden ölçülür (oyuncu müziği duyup kamerayı kaydırmış olabilir).
	var t_visible: float = _visible_time()
	_track_offset = maxf(t_visible - APPROACH, 0.0)
	_spawn_clock = maxf(MUSIC_DROP - (t_visible - _track_offset), 0.0)
	_clock = 0.0
	_spawned = false
	_crossing_open = false
	_cars.clear()
	_music_on = GameMusic.drift(get_tree(), true)
	if _smoke == null or not is_instance_valid(_smoke):
		_smoke = DriftSmoke.new()
		_manager.add_child(_smoke)
	_marks = SkidMarks.new()
	_manager.add_child(_marks)
	show_started.emit(_ids[0], _ids[1])
	print("DriftEvent: gösteri — %s önde, %s arkada; ekrana %.1f sn sonra" % [_ids[0], _ids[1], _spawn_clock + t_visible - _track_offset])


## Öndeki aracın çizelgede ilk göründüğü an (sn); kamera rotayı hiç görmüyorsa virajın başına varış anı.
func _visible_time() -> float:
	var lead: DriftLine.Track = _route["lead"]
	var corner_from: float = (_route["line"] as DriftLine).corner_from
	var t_corner: float = -1.0
	for i: int in lead.position.size():
		if t_corner < 0.0 and lead.s[i] >= corner_from - 1.5:
			t_corner = float(i) * DriftLine.DT
		if not _manager.is_hidden(lead.position[i]):
			return float(i) * DriftLine.DT
	return t_corner if t_corner >= 0.0 else lead.duration() * 0.5


## Doğma anı geldi: görünme anı şimdiki kameraya göre yeniden ölçülür. Öndeki araç drop'tan önce görünecekse doğum
## ertelenir; değilse çizelge görünme anı tam drop'a denk gelecek yerden başlar.
func _ready_to_spawn() -> bool:
	if _clock < _spawn_clock:
		return false
	var t_visible: float = _visible_time()
	var until_drop: float = MUSIC_DROP - _clock
	if t_visible < until_drop - DriftLine.DT:
		_track_offset = 0.0
		_spawn_clock = MUSIC_DROP - t_visible   # doğma yeri bile görünüyor: drop'a kadar bekle
		return _clock >= _spawn_clock
	_track_offset = maxf(t_visible - maxf(until_drop, 0.0), 0.0)
	_spawn_clock = _clock
	return true


func _tick_show(delta: float) -> void:
	_clock += delta
	if _music_on:
		var position: float = GameMusic.drift_position(get_tree())
		if position >= 0.0:
			# Saat müziğe bağlı: küçük farklar birkaç karede kapanır (araç zıplamasın), büyük fark (takılma) hemen
			var drift: float = position - _clock
			_clock = position if absf(drift) > 0.3 else _clock + drift * 0.2
	if _music_on and not _city_visible():
		GameMusic.drift(get_tree(), false)   # dünya örtüldü (garaj, harita, yarış…): tema kesilir, garaj teması döner
		_music_on = false
	if not _spawned:
		if not _ready_to_spawn():
			return
		_spawn_cars()
	var t: float = _clock - _spawn_clock + _track_offset
	var line: DriftLine = _route["line"]
	var remaining: int = 0
	var follow_past: bool = true
	for k: int in _cars.size():
		var car: TrafficVehicle = _cars[k]
		if not is_instance_valid(car):
			continue
		var track: DriftLine.Track = _tracks[k]
		var s: float = track.sample_f(track.s, t)
		if t >= track.duration() or (s > line.corner_to + 2.5 and _manager.is_hidden(car.global_position)):
			_remove_car(k)
			continue
		remaining += 1
		if s < line.corner_to + 1.2:
			follow_past = false
		_place(car, track, t, delta, k)
	if follow_past and not _crossing_open:
		_crossing_open = true
		if _rng.randf() < CHEER_CHANCE:
			get_tree().create_timer(CHEER_DELAY).timeout.connect(_cheer)
	if remaining == 0:
		_finish()


func _spawn_cars() -> void:
	_spawned = true
	_tracks = [_route["lead"], _route["follow"]]
	_wheel_offsets.clear()
	for k: int in 2:
		var id: StringName = _ids[k]
		var scene: PackedScene = _scenes.get(id) as PackedScene
		if scene == null:
			_cars.append(null)
			_audio.append({})
			_wheel_offsets.append(PackedVector3Array())
			continue
		var look: CarAppearance = _appearance(id)
		var car: TrafficVehicle = _manager.spawn_drift_vehicle(id, scene, look)
		_cars.append(car)
		_audio.append(_make_audio(id, k))
		_wheel_offsets.append(_measure_rear_wheels(car))
	var t: float = _clock - _spawn_clock + _track_offset
	for k: int in _cars.size():
		if is_instance_valid(_cars[k]):
			_place(_cars[k], _tracks[k], t, 0.0, k)


## Fabrika rengi (boya kapalıyken trafik de öyle; AE86 beyaz, RX-7 sarı… ikonik).
static func _appearance(id: StringName) -> CarAppearance:
	var look: CarAppearance = CarAppearance.new()
	look.body_color = CarCatalog.default_color_for(CarCatalog.scene_path(id))
	return look


## Aracı çizelgedeki poza koyar; duman, iz ve sesleri besler.
func _place(car: TrafficVehicle, track: DriftLine.Track, t: float, delta: float, k: int) -> void:
	var at: Vector3 = track.sample_position(t)
	var yaw: float = track.sample_angle(track.yaw, t)
	var speed: float = track.sample_f(track.speed, t)
	car.place_drift(at, yaw, track.sample_f(track.roll, t), track.sample_f(track.pitch, t), track.sample_f(track.steer, t),
		track.sample_f(track.front_spin, t), track.sample_f(track.rear_spin, t), speed)
	var strength: float = track.sample_f(track.intensity, t)
	var travel: float = track.sample_angle(track.travel, t)
	var velocity: Vector3 = Vector3(sin(travel), 0.0, cos(travel)) * speed
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var left: Vector3 = Vector3.UP.cross(forward)
	var slip: float = track.sample_f(track.slip, t)
	var visible: bool = not _manager.is_hidden(car.global_position)
	var offsets: PackedVector3Array = _wheel_offsets[k] if k < _wheel_offsets.size() else PackedVector3Array()
	for w: int in offsets.size():
		var key: int = k * 2 + w
		var wheel: Vector3 = at + forward * offsets[w].z + left * offsets[w].x
		_marks.add(key, wheel, strength)
		if delta > 0.0 and visible:
			# Teker topağı geriye ve kayan tarafa (kuyruğun açıldığı yana) fırlatır
			var back: Vector3 = (-forward * 0.75 + left * -signf(slip) * 0.45).normalized()
			_smoke.emit(key, wheel, velocity, back, strength * (1.0 if w == 0 else 0.85), delta)
	if delta > 0.0:
		_drive_audio(k, car, track, t, delta, strength)


## Arka tekerlerin yerdeki noktası araç uzayında (x sola, z ileri; doğduğunda bir kez, CarRig teker eksenlerinden;
## bulunamazsa gövde ölçüsünden). Her karede yalnızca gövde yönüyle döndürülür.
static func _measure_rear_wheels(car: TrafficVehicle) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var forward: Vector3 = car.global_transform.basis.z
	var left: Vector3 = car.global_transform.basis.x
	if car.rig:
		for point: Dictionary in car.rig.wheel_points():
			if not bool(point["front"]):
				var rel: Vector3 = (point["position"] as Vector3) - car.global_position
				out.append(Vector3(rel.dot(left), 0.0, rel.dot(forward)))
	if out.size() < 2:
		out = PackedVector3Array([Vector3(HALF_WIDTH * 0.8, 0.0, -HALF_LENGTH * 0.62),
			Vector3(-HALF_WIDTH * 0.8, 0.0, -HALF_LENGTH * 0.62)])
	return out


## Işıkta bekleyen, ekranda görünen bir araç kısa çift korna çalar.
func _cheer() -> void:
	if _manager == null or _manager.ambience == null:
		return
	var waiting: Array[TrafficVehicle] = []
	for vehicle: TrafficVehicle in _manager.vehicles:
		if is_instance_valid(vehicle) and vehicle.mode == TrafficVehicle.Mode.TRAFFIC and vehicle.speed < 0.05 \
				and not _manager.is_hidden(vehicle.global_position):
			waiting.append(vehicle)
	if not waiting.is_empty():
		_manager.ambience.honk_from(waiting[_rng.randi() % waiting.size()], 1)


func _remove_car(k: int) -> void:
	var car: TrafficVehicle = _cars[k]
	if is_instance_valid(car):
		car.queue_free()
	_cars[k] = null
	if _marks:
		_marks.add(k * 2, Vector3.ZERO, 0.0)
		_marks.add(k * 2 + 1, Vector3.ZERO, 0.0)
	if k < _audio.size():
		for part: String in ["engine", "squeal"]:
			var node: Node = _audio[k].get(part) as Node
			if node:
				node.queue_free()
		_audio[k] = {}


func _finish() -> void:
	for k: int in _cars.size():
		_remove_car(k)
	_cars.clear()
	_audio.clear()
	_routes = []   # bellek: rotalar bir sonraki gösteriden önce arka planda yeniden kurulur
	if _marks:
		_marks.release()
		_marks = null
	print("DriftEvent: gösteri bitti")
	_reset(_rng.randf_range(EVERY.x, EVERY.y))
	show_finished.emit()


## Boşa dön: tutulan her şey bırakılır, sayaç `next` sn'ye kurulur (müzik çalıyorsa kendi sonuna kadar sürer).
func _reset(next: float) -> void:
	if phase == Phase.PREPARE or (phase == Phase.SHOW and not _spawned):
		if _music_on:
			GameMusic.drift(get_tree(), false)
	_music_on = false
	for k: int in _cars.size():
		_remove_car(k)
	_cars.clear()
	_audio.clear()
	_wheel_offsets.clear()
	if _marks:
		_marks.release()
		_marks = null
	phase = Phase.IDLE
	_ids.clear()
	_scenes.clear()
	for id: StringName in _loading:
		ResourceLoader.load_threaded_get(_loading[id])   # yarım yüklemeyi bırakmadan önce bitir (askıda kalmasın)
	_loading.clear()
	_route = {}
	_left = maxf(next, PRELOAD_LEAD + 1.0) if next > RETRY else next
	_save_state()


# --- Ses ---------------------------------------------------------------------------------------------

func _make_audio(id: StringName, k: int) -> Dictionary:
	var entry: Dictionary = {"pitch": 1.0 + (0.05 if k == 0 else -0.05), "squeal_db": -60.0}
	var bank: EngineBank = EngineBank.for_vehicle(id)
	if bank:
		var engine: AudioStreamPlayer3D = _player("DriftEngine%d" % k, -80.0)
		engine.volume_db = ENGINE_DB + engine_gain_db
		var voice: EngineVoice = EngineVoice.new(engine, bank)
		voice.dynamics = ENGINE_DYNAMICS
		entry["engine"] = engine
		entry["voice"] = voice
		entry["bank"] = bank
	if ResourceLoader.exists(SQUEAL_PATH):
		var squeal: AudioStreamPlayer3D = _player("DriftSqueal%d" % k, -60.0)
		squeal.stream = load(SQUEAL_PATH) as AudioStream
		squeal.play(_rng.randf() * 3.0)
		entry["squeal"] = squeal
	return entry


func _player(node_name: String, db: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = node_name
	player.bus = CityAmbience.BUS
	player.volume_db = db
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	player.attenuation_filter_cutoff_hz = AIR_CUTOFF
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(player)
	return player


## Motor: çizelgedeki devir (kırmızı çizginin oranı) ve gaz; devir kesicide patlamalar. Cıyak: kayma şiddetiyle açılır,
## perdesi kayma açısı ve savrulma hızıyla oynar (geçişte tizleşir).
func _drive_audio(k: int, car: TrafficVehicle, track: DriftLine.Track, t: float, delta: float, strength: float) -> void:
	if k >= _audio.size():
		return
	var entry: Dictionary = _audio[k]
	var at: Vector3 = car.global_position + Vector3.UP * 0.1
	var engine: AudioStreamPlayer3D = entry.get("engine") as AudioStreamPlayer3D
	if engine:
		engine.global_position = at
		var bank: EngineBank = entry["bank"]
		var rpm_frac: float = track.sample_f(track.rpm, t)
		var rpm: float = lerpf(bank.idle_rpm(), bank.redline_rpm(), rpm_frac)
		(entry["voice"] as EngineVoice).update(delta, rpm, track.sample_f(track.throttle, t), rpm_frac >= 0.999)
	var squeal: AudioStreamPlayer3D = entry.get("squeal") as AudioStreamPlayer3D
	if squeal:
		squeal.global_position = at
		var slip: float = absf(track.sample_f(track.slip, t))
		var rate: float = absf(track.sample_f(track.slip_rate, t))
		var target: float = SQUEAL_DB + squeal_gain_db + linear_to_db(maxf(strength, 0.001)) if strength > 0.03 else -60.0
		var db: float = move_toward(float(entry["squeal_db"]), target, (90.0 if target > float(entry["squeal_db"]) else 40.0) * delta)
		entry["squeal_db"] = db
		squeal.volume_db = db
		squeal.pitch_scale = float(entry["pitch"]) * (0.9 + 0.16 * clampf(slip / 0.8, 0.0, 1.0) + 0.06 * clampf(rate / 3.0, 0.0, 1.0))


# --- Yardımcılar -----------------------------------------------------------------------------------------

## Yönlendirici / eğitim yöneticisi bir kez bulunur (her karede grup araması yapılmasın).
func _router() -> UiRouter:
	if not is_instance_valid(_router_ref) and is_inside_tree():
		_router_ref = get_tree().get_first_node_in_group("ui_router") as UiRouter
	return _router_ref if is_instance_valid(_router_ref) else null


## Şehrin dünyası görünüyor mu (garaj, mağaza, harita, yarış, hurdalık, ayarlar açık değil)?
func _city_visible() -> bool:
	var router: UiRouter = _router()
	return router == null or not Hud.WORLD_COVERING_PLACES.has(router.current_place())


func _tutorial_running() -> bool:
	if not is_instance_valid(_director_ref) and is_inside_tree():
		_director_ref = get_tree().get_first_node_in_group("tutorial_director") as TutorialDirector
	return is_instance_valid(_director_ref) and _director_ref.is_running()


func _load_state() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(STATE_PATH) == OK:
		_left = float(config.get_value("drift", "left", FIRST_AFTER))
		_last_entry = int(config.get_value("drift", "last_entry", -1))


func _save_state() -> void:
	if not persist:
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(STATE_PATH)
	config.set_value("drift", "left", _left)
	config.set_value("drift", "last_entry", _last_entry)
	config.save(STATE_PATH)
