class_name RepairManager
extends Node
## Tamir döngüsü (Car Town tarzı, sakin trafik):
## 1) Müşteri + ARIZA: belirli aralıklarla (customer_interval) trafikteki SAĞLAM bir NPC'ye katalogdan
##    (RepairType.defaults(): MOTOR / FREN / LASTİK / KAPORTA) ağırlıkla bir arıza atanır; araç önünde
##    boş bir yol kenarı bekleme noktası (repair_wait_spots) varsa oraya yanaşıp durur ve balonunda
##    arıza adını gösterir (REPAIR_REQUESTED → REPAIR_WAITING). Arıza müşteri olurken seçilir, o
##    döngü boyunca değişmez; araç trafiğe dönünce sıfırlanır. Normal trafik aracında ne balon ne arıza
##    vardır. Aynı anda en fazla waiting_limit() araç bekler (garaj seviyesine bağlı, bkz. SUPPLY: 3–4);
##    sınır doluysa yeni müşteri oluşmaz.
##    SABIR: bekleyen müşteri CUSTOMER_PATIENCE sn içinde tamire alınmazsa vazgeçip gider (korna, trafiğe
##    döner, customer_left). Son PATIENCE_WARN sn'de balonda geri sayım. Seçiliyken (plakası açık) ve eğitim
##    sürerken sabır azalmaz. İki müşteri ASLA aynı anda gitmez: geri sayımlar en az COUNTDOWN_GAP sn arayla
##    başlar (sırası gelmeyen 0:20'de bekler), gidişler de aynı aralıkla.
## 2) TAMİRE AL: oyuncu bekleyen aracı seçip onaylayınca araç ANINDA boş bir CarSpot'a ışınlanır ve o
##    aracın ARIZASININ süresiyle sayaç başlar (REPAIR_BAY). Sürüş animasyonu yok. Kaç CarSpot'un aktif
##    olduğu GarageUpgradeManager'ın "repair_capacity" seviyesinden gelir (Lv1 = 1, Lv2 = 2, Lv3 = 3;
##    sahnedeki CarSpot sayısıyla sınırlı). Tüm alanlar doluysa TAMİRE AL kapalıdır ("TAMİR ALANI DOLU"),
##    müşteri yol kenarında beklemeye devam eder. Tamir süresi = arızanın süresi × hız geliştirmesinin
##    çarpanı (Lv1 1.0 … Lv5 0.6); RepairType.duration'a dokunulmaz.
## 3) Sayaç bitince ödül VERİLMEZ: araç CarSpot'ta kalır, ₺ balonu açılır (REPAIR_COMPLETE →
##    REWARD_WAITING). Oyuncu PARA TOPLA deyince (collect) arızanın ödülü + XP bir kez verilir, araç boş
##    bir yol spawn noktasına ışınlanır, balonlar kapanır, arızası sıfırlanır ve waypoint zincirinden
##    trafiğe devam eder (TRAFFIC); ileride yeniden müşteri olabilir (yeni arıza atanır).
## Aynı araç örneği bütün döngüyü yapar (ikinci bir araç instance'ı yok); TrafficManager.max_vehicles
## sınırına dahildir (yol hiçbir zaman kalabalıklaşmaz).
##
## Seçim mevcut car_hitbox.gd'den okunur (selected_car). HUD bu node'u "repair_manager" grubundan
## bulur, sinyallerini dinler; TAMİRE AL → start_repair, PARA TOPLA → collect.
## PARA: yalnızca EconomyManager ("economy" grubu) — TAMİRE AL'da arızanın cost'u düşülür (yetmezse iş
## açılmaz), PARA TOPLA'da reward eklenir. XP / seviye: PlayerProgress.
## Sinyal spam yok: repair_progress en çok progress_interval'da bir.

signal target_changed(car: Node3D)                 # seçili tamir edilebilir araç (null = yok)
signal customer_marked(car: Node3D)                # NPC tamir istedi (yol kenarına yanaşıyor, balon açık)
signal customer_stopped(car: Node3D)               # müşteri bekleme noktasına yerleşti
signal customer_left(car: Node3D)                  # müşteri beklemekten sıkılıp gitti
signal repair_started(car: Node3D)                 # TAMİRE AL: araç CarSpot'ta, sayaç başladı
signal repair_progress(car: Node3D, progress: float)
signal repair_ready(car: Node3D)                   # sayaç bitti; ödül PARA TOPLA'yı bekliyor (CarSpot dolu)
signal repair_collected(car: Node3D, reward: int, xp: int)  # para + XP verildi, araç yola ışınlandı
signal gem_finished(car: Node3D)                   # ELMASLA BİTİR: elmas harcandı, iş anında bitti (HUD sesi)
signal repair_cancelled(car: Node3D)
signal job_collected(job_id: StringName, reward: int)   # iş türü + ödül (görev sayaçları; repair_collected ile aynı anda)
signal repair_slot_freed(car: Node3D)              # CarSpot boşaldı

const CarHitbox: GDScript = preload("res://car_hitbox.gd")

## GARAJ SEVİYESİ → MÜŞTERİ ARZI. Ölçüm (bkz. docs/GDD.md): garaj büyümeden müşteri akışı
## dakikada ~2,4'te sabit kalıyor, bu yüzden 2. ve 3. tamir alanı ekonomik olarak işe yaramıyordu
## (kuyruk hep boş, bay doluluğu %38). Garaj seviyesi artık arzı da büyütür:
##   interval → customer_interval_min/max çarpanı (küçük = sık müşteri)
##   waiting  → aynı anda yol kenarında bekleyebilen müşteri. 2026-10-16 kullanıcı kararı: 3–4 araç
##              bekleyebilir (1–2. seviye 3, 3–4. seviye 4), çok bekleyen sabrı bitince gider (eskiden
##              her seviyede 2'ydi ve bekleyen hiç gitmiyordu — birikip kaldırımı tıkıyordu).
##   spots    → kullanılan bekleme noktası sayısı; waiting ile aynı tutulur (fazlası kullanılmaz)
##   reward   → müşteri değeri çarpanı (daha iyi sınıf araçlar gelir)
##   traffic  → TrafficManager.max_vehicles (+ eski 2'nin üstündeki bekleyen müşteri kadar: bekleyenler bu
##              sayıya dahil, yoksa 3 müşteri beklerken yolda tek araç kalırdı). 4. seviyede 8 yerine 10: ÖLÇÜLDÜ (20 dk, sv.15, 3 alan,
##              tamir hızı 5) — trafik 8'de garaj 4 yalnızca 2.206 ₺/dk veriyordu (garaj 3: 2.021),
##              yani 60.000 ₺'lik son genişleme 5,4 saatte kendini amorti ediyordu. Aday araç havuzu
##              büyümediği için kısalan müşteri aralığı karşılığını bulamıyor (bay'deki araçlar yoldan
##              çekiliyor). Trafik 10 ile aynı yapılandırma 2.798 ₺/dk (+%27, amorti 77 dk).
const SUPPLY: Array[Dictionary] = [
	{"interval": 1.00, "waiting": 3, "spots": 3, "reward": 1.00, "traffic": 4},
	{"interval": 0.80, "waiting": 3, "spots": 3, "reward": 1.15, "traffic": 6},
	{"interval": 0.62, "waiting": 4, "spots": 4, "reward": 1.30, "traffic": 8},
	{"interval": 0.48, "waiting": 4, "spots": 4, "reward": 1.45, "traffic": 10},
]
## Trafik ölçümünün yapıldığı bekleme sınırı: bunun üstündeki her bekleyen müşteri trafik sınırına eklenir.
const BASE_WAITING: int = 2
## Müşterinin sabrı (sn, bekleme noktasına yerleşince rastgele) ve balonda geri sayımın başladığı kalan süre.
const CUSTOMER_PATIENCE: Vector2 = Vector2(75.0, 110.0)
const PATIENCE_WARN: float = 20.0
## Geri sayım başlangıçları (ve gidişler) arasındaki en kısa süre. Kullanıcı (2026-10-19): aynı anda sıkılıp çıkan
## iki müşteri kaldırımdan birlikte şeride kırıp birbirini ve trafiği kilitliyordu. Şeride katılma ~2,3 sn sürer.
const COUNTDOWN_GAP: float = 5.0
const SPOT_AHEAD_MIN: float = 0.5   # bekleme noktası aracın bu kadar önünde olmalı (yanaşma payı)
const SPOT_AHEAD_MAX: float = 3.2   # aracın noktayı "görebildiği" pencere (1.8 iken adaylar çok seyrekti)
const SPOT_SIDE_MAX: float = 0.6    # noktanın şeride yanal uzaklığı en çok (kaldırım kenarı ~0.36)
const SPOT_CLEAR: float = 0.9       # nokta çevresinde bu yarıçapta bekleyen araç varsa dolu sayılır
const PATH_SIDE: float = 0.55       # yanaşma yolunun bu kadar yanında duran araç varsa o nokta seçilmez
## Uygun araç / nokta yoksa tarama bu aralıkla yinelenir. Eskiden her karede: oturmuş oyunda sayaç hep dolu
## olduğundan trafik × nokta taraması kare başı betiğin en büyük kalemiydi. Araç noktayı 0,5–3,2 birimlik
## pencerede görür (saniyelerce): 0,1 sn gecikme seçimi değiştirmez.
const CANDIDATE_RETRY: float = 0.1

## Arıza kataloğu; boşsa RepairType.defaults() (MOTOR / FREN / LASTİK / KAPORTA).
@export var repair_types: Array[RepairType] = []
## repair_progress sinyali en çok bu aralıkla yayınlanır (sn).
@export_range(0.02, 1.0, 0.01) var progress_interval: float = 0.1

@export_group("Müşteri")
## İki müşteri arasındaki süre (sn, rastgele aralık). Uygun araç yoksa ilk fırsatta.
@export_range(1.0, 120.0, 0.5) var customer_interval_min: float = 6.0
@export_range(1.0, 120.0, 0.5) var customer_interval_max: float = 14.0
## Yol kenarı bekleme noktaları (garaja bitişik kaldırımın kenarında, şerit yönüne bakar: araç önü +Z).
@export var repair_wait_spots: Array[Node3D] = []

@export_group("Tamir Noktaları (ana haritadaki CarSpot'lar)")
## Ana haritadaki CarSpot node'ları, sırayla kullanılır: TAMİRE AL ile araç boş olana ışınlanır
## (konum + Y dönüşü). Kaç tanesinin açık olduğunu "repair_capacity" geliştirmesi belirler.
@export var repair_car_spots: Array[Node3D] = []

## DİL DEĞİŞİMİ sahneyi baştan kurar (GameSettings.set_language); süren işler kayda girmediği için
## kaybolurdu. carry_over() eski sahnedeki işleri buraya yazar, yeni sahnenin RepairManager'ı alır ve
## aynı modeli aynı renkle aynı CarSpot'a kurar (aradaki gerçek süre de işler).
const RESTORE_TIMEOUT: float = 20.0   # model bu sürede yüklenemezse iş bırakılır (alan sonsuza dek kilitlenmesin)
static var _carried: Array[Dictionary] = []
static var _carried_at: int = 0
## Dil değişiminde işler devirle gelir; aynı işler kayıtta da durduğu için yeni sahne kayıttakileri almamalı.
static var _skip_saved: bool = false
## YARIM KALAN İŞLER (2026-10-17, OTO MANŞET): oyun kapanırken alandaki işler kayda girer (jobs_state). Açılışta
## (load_jobs) alanları hemen ayrılır ama araçları kurulmaz: OfflineEarnings yokluk süresini (sunucu saatiyle)
## bulunca resume_saved_jobs çağırır — o sürede bitenler tam ödülle gazeteye gider, bitmeyenler alana geri kurulur.
## OfflineEarnings yoksa (testler) HOLD_TIMEOUT sonra kayıttaki saatle kendisi devam eder.
const HOLD_TIMEOUT: float = 12.0
## Kare süresi en çok bu kadar sayaca işler: arka plandan dönüşteki dev kare yokluğu iki kez saymasın (yokluk
## advance_all ile açıkça eklenir).
const MAX_TICK: float = 0.5
var _hold_time: float = 0.0

var _active: Array[RepairState] = []   # açık işler (her biri bir CarSpot'ta); en fazla capacity() tane
var _restoring: Array[Dictionary] = []   # devralınmış, aracı henüz kurulamamış işler (alanları ayrılmış)
var _restore_time: float = 0.0
var _target: Node3D
var _progress_timer: float = 0.0
var _customer_timer: float = 3.0
var _patience_clock: float = 0.0          # sabır saati (eğitimde durur): aşağıdaki iki zaman bununla ölçülür
var _last_countdown: float = -INF         # en son geri sayımın başladığı an
var _last_departure: float = -INF         # en son sıkılıp giden müşterinin anı
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()  # müşteri kararı (trafik RNG'sinden bağımsız)
var _traffic: TrafficManager


func _ready() -> void:
	add_to_group("repair_manager")
	_rng.randomize()
	if repair_types.is_empty():
		repair_types = RepairType.defaults()
	add_child(RepairFxDirector.new())   # yalnızca görsel: iş efektleri, bitiş parıltısı, altın paralar
	_connect_traffic.call_deferred()


func _process(delta: float) -> void:
	_tick_hold(delta)
	_tick_restore(delta)
	_poll_target()
	_tick_active(minf(delta, MAX_TICK))
	_tick_customers(delta)


func _tick_active(delta: float) -> void:
	if _active.is_empty():
		return
	_progress_timer -= delta
	var tick: bool = _progress_timer <= 0.0
	if tick:
		_progress_timer = progress_interval
	for state: RepairState in _active.duplicate():
		if not is_instance_valid(state.car):
			_cancel_state(state)
			continue
		if state.phase != RepairState.Phase.REPAIRING:
			continue
		var done: bool = state.advance(delta)
		if done or tick:
			repair_progress.emit(state.car, state.repair_progress)
		if done:
			_finish_state(state)


# --- Sorgu ---------------------------------------------------------------------

## Şu an seçili tamir edilebilir araç (yoksa null).
func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


## Araç bu sistemle tamir edilebilir mi? Yalnızca trafik araçları (TrafficVehicle).
func is_repairable(car: Node3D) -> bool:
	return is_instance_valid(car) and car is TrafficVehicle


## Aynı anda kullanılabilen tamir alanı sayısı = SATIN ALINMIŞ tamir alanı sayısı
## (üst sınır: sahnedeki CarSpot sayısı). Garaj seviyesi alanı yalnızca ORTAYA ÇIKARIR;
## satın alınmadıkça kapasite artmaz ve kilitli CarSpot'a araç gönderilmez.
func capacity() -> int:
	var bays: RepairBayManager = _bays()
	var wanted: int = bays.unlocked_count() if bays else repair_car_spots.size()
	return clampi(wanted, 1, maxi(repair_car_spots.size(), 1))


## Açılmış tamir alanları (sahnede yoksa null: eski davranış, hepsi açık sayılır).
func _bays() -> RepairBayManager:
	if not is_inside_tree():
		return null   # sahne kapanırken (araç ağaçtan çıkarken) grup araması olmaz
	return get_tree().get_first_node_in_group("repair_bays") as RepairBayManager


## Bu garaj seviyesinin müşteri arzı ayarları.
func _supply() -> Dictionary:
	var upgrades: GarageUpgradeManager = _upgrades()
	var level: int = upgrades.garage_level() if upgrades else 1
	return SUPPLY[clampi(level - 1, 0, SUPPLY.size() - 1)]


## Aynı anda yol kenarında bekleyebilen müşteri sayısı (garaj seviyesine bağlı).
func waiting_limit() -> int:
	return int(_supply()["waiting"])


## Müşteri ödül çarpanı (garaj seviyesine bağlı).
func reward_multiplier() -> float:
	return float(_supply()["reward"])


## Bu garaj seviyesinde kullanılan bekleme noktaları (garaj büyüdükçe kaldırımda daha çok yer açılır).
func active_wait_spots() -> Array[Node3D]:
	var limit: int = mini(int(_supply()["spots"]), repair_wait_spots.size())
	var out: Array[Node3D] = []
	for i: int in limit:
		if is_instance_valid(repair_wait_spots[i]):
			out.append(repair_wait_spots[i])
	return out


## Garaj seviyesi değişince trafik yoğunluğu da güncellenir (daha büyük garaj = daha canlı şehir).
func _apply_supply() -> void:
	if _traffic:
		_traffic.max_vehicles = traffic_limit(_supply())


## Bir arz satırının trafik sınırı: ölçülen trafik + BASE_WAITING'in üstündeki bekleyen müşteri sayısı.
static func traffic_limit(supply: Dictionary) -> int:
	return int(supply["traffic"]) + maxi(int(supply["waiting"]) - BASE_WAITING, 0)


## Şu an süren iş sayısı (tamir + ödül bekleyen).
func active_count() -> int:
	return _active.size()


## Tüm tamir alanları dolu mu (TAMİRE AL'dan para toplanana kadar)? Restorasyon projesi kaplayan alan
## da doludur (hurdalık: "Requires one available workbay").
func is_busy() -> bool:
	return _active.size() + _project_bays().size() >= capacity()


## Yol kenarında tamir bekleyen (yanaşan dahil) araç sayısı.
func waiting_count() -> int:
	if _traffic == null:
		return 0
	var count: int = 0
	for v: TrafficVehicle in _traffic.vehicles:
		if v.is_customer():
			count += 1
	return count


## TAMİRE AL yapılabilir mi: yol kenarında bekleyen müşteri, CarSpot boş.
func can_start(car: Node3D) -> bool:
	if not is_repairable(car) or is_busy() or _free_bay() < 0:
		return false
	return (car as TrafficVehicle).is_customer()


## Kullanılabilir ilk boş CarSpot'un indeksi (yoksa -1). Kapasitenin üstündeki alanlar kapalıdır.
func _free_bay() -> int:
	var limit: int = mini(capacity(), repair_car_spots.size())
	for i: int in limit:
		if is_bay_free(i):
			return i
	return -1


## Hurdalığın restorasyon projesi için boş alan (tamir işiyle aynı kural).
func free_bay() -> int:
	return _free_bay()


## Bu alan açık ve boş mu: tamir işi, devralınan iş ya da restorasyon projesi yok.
func is_bay_free(i: int) -> bool:
	if i < 0 or i >= mini(capacity(), repair_car_spots.size()) or not is_instance_valid(repair_car_spots[i]):
		return false
	for state: RepairState in _active:
		if state.bay_index == i:
			return false
	for job: Dictionary in _restoring:
		if int(job["bay"]) == i:
			return false   # devralınan iş aracını bekliyor
	return not _project_bays().has(i)


## Restorasyon projelerinin kapladığı alanlar (hurdalık yoksa boş) + teslim töreni sürenler (proje
## kayıtta bitti ama araç henüz liftte kutlanıyor) + performans parçası takılan araçlar.
func _project_bays() -> Array[int]:
	if not is_inside_tree():
		return []
	var junkyard: JunkyardManager = get_tree().get_first_node_in_group("junkyard") as JunkyardManager
	var out: Array[int] = junkyard.occupied_bays() if junkyard else []
	var restoration: RestorationBays = get_tree().get_first_node_in_group("restoration_bays") as RestorationBays
	if restoration:
		for bay: int in restoration.celebrating_bays():
			if not out.has(bay):
				out.append(bay)
	var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
	if mods:
		for bay: int in mods.occupied_bays():
			if not out.has(bay):
				out.append(bay)
	var mod_bays: PerformanceBays = get_tree().get_first_node_in_group("performance_bays") as PerformanceBays
	if mod_bays:
		for bay: int in mod_bays.busy_bays():   # parçası takılıp alandan çıkan araç (animasyon)
			if not out.has(bay):
				out.append(bay)
	return out


## Bu iş şu anki seviyede açık mı?
func is_unlocked(type: RepairType) -> bool:
	return type != null and type.min_level <= _player_level()


## Bu iş için maliyet ödenebilir mi? (Para tek kaynak: EconomyManager.)
func can_afford(type: RepairType) -> bool:
	var economy: EconomyManager = _economy()
	return type != null and (economy == null or economy.can_afford(type.cost))


## Araç + iş birlikte başlatılabilir mi (seviye, maliyet, CarSpot, araç durumu)?
func can_start_type(car: Node3D, type: RepairType) -> bool:
	return can_start(car) and is_unlocked(type) and can_afford(type)


## Bu aracın ödülü toplanabilir mi (CarSpot'ta, sayaç bitmiş)?
func can_collect(car: Node3D) -> bool:
	var state: RepairState = get_state(car)
	return state != null and state.phase == RepairState.Phase.REWARD_WAITING


## Tüm iş kataloğu (katalog sırasıyla).
func get_repair_types() -> Array[RepairType]:
	return repair_types


## Bu oyuncu/garaj/alan durumunda gelebilecek arızalar (müşteri seçimi bu listeden yapılır).
## Uzun işler yalnızca garaj büyüdükten VE alan açıldıktan sonra gelir (RepairType.min_garage_level
## / min_bays): tek alanı olan oyuncunun 5 dakikalık bir işle kilitlenmesi engellenir.
func unlocked_types(level: int) -> Array[RepairType]:
	var upgrades: GarageUpgradeManager = _upgrades()
	var garage: int = upgrades.garage_level() if upgrades else 1
	var bays: RepairBayManager = _bays()
	var bay_count: int = bays.unlocked_count() if bays else 1
	var out: Array[RepairType] = []
	for t: RepairType in repair_types:
		if t.min_level <= level and t.min_garage_level <= garage and t.min_bays <= bay_count:
			out.append(t)
	return out


## Bu aracın süren işi (yoksa null).
func get_state(car: Node3D) -> RepairState:
	for state: RepairState in _active:
		if state.car == car:
			return state
	return null


## Şu an CarSpot'u kullanan araç (yoksa null).
func get_spot_occupant() -> Node3D:
	for state: RepairState in _active:
		if is_instance_valid(state.car):
			return state.car
	return null


## CarSpot'lardaki araçlar (boş alanlar atlanır).
func get_spot_occupants() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for state: RepairState in _active:
		if is_instance_valid(state.car):
			out.append(state.car)
	return out


# --- Akış ----------------------------------------------------------------------

## TAMİRE AL: araç anında CarSpot'a ışınlanır, ARIZASININ süresiyle sayaç başlar. İş her zaman aracın
## kendi arızasıdır (type verilirse yalnızca aracın arızası yoksa kullanılır — test/araç içindir).
## Maliyet/seviye kontrolü durur (katalogda cost 0, min_level 1). Koşullar uygun değilse false: coin
## düşmez, araç yol kenarında beklemeye devam eder.
func start_repair(car: Node3D, type: RepairType = null) -> bool:
	if not can_start(car):
		return false
	var vehicle: TrafficVehicle = car as TrafficVehicle
	if vehicle.fault != null:
		type = vehicle.fault
	if type == null:
		var open_types: Array[RepairType] = unlocked_types(_player_level())
		type = open_types[0] if not open_types.is_empty() else null
	if type == null or not is_unlocked(type):
		return false
	var bay: int = _free_bay()
	if bay < 0:
		return false
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(type.cost):
		return false  # bakiye yetmiyor: iş açılmaz, araç yol kenarında beklemeye devam eder
	var state: RepairState = RepairState.new(vehicle, type, vehicle.fault_severity)
	state.bay_index = bay
	var upgrades: GarageUpgradeManager = _upgrades()
	if upgrades:
		state.duration_scale = upgrades.repair_speed_multiplier()  # hız geliştirmesi: süre × çarpan
	# Ödül çarpanı iş BAŞLARKEN sabitlenir: garaj seviyesi (müşteri değeri) × iş ustalığı
	var mastery_start: JobMastery = _mastery()
	state.reward_scale = reward_multiplier() * (mastery_start.reward_multiplier(type.id) if mastery_start else 1.0)
	state.start()
	_occupy_bay(vehicle, state)
	repair_progress.emit(vehicle, 0.0)
	return true


## Ödüllü reklamla kısaltma yalnızca bu kadar saniyeden uzun kalan işlerde sunulur (kısa işlerde değmez).
const BOOST_MIN_REMAINING: float = 40.0
## Kısaltma: kalan sürenin bu oranı silinir.
const BOOST_FRACTION: float = 0.5


## Bu araçtaki iş ödüllü reklamla kısaltılabilir mi?
func can_boost(car: Node3D) -> bool:
	var state: RepairState = get_state(car)
	return state != null and state.is_repairing and not state.boosted \
			and state.remaining >= BOOST_MIN_REMAINING


## Reklam ödülü hak edildi: işin kalan süresi yarıya iner. Süre bittiyse iş normal akışla tamamlanır.
func boost_repair(car: Node3D) -> bool:
	var state: RepairState = get_state(car)
	if state == null or not can_boost(car) or not state.boost(BOOST_FRACTION):
		return false
	repair_progress.emit(state.car, state.repair_progress)
	return true


## Uzun iş (GemSkip.MIN_JOB_SECONDS+) sürerken kalan süreyi elmasla bitirmenin fiyatı; sunulmuyorsa 0.
func gem_skip_cost(car: Node3D) -> int:
	var state: RepairState = get_state(car)
	if state == null or not state.is_repairing or state.repair_duration < GemSkip.MIN_JOB_SECONDS:
		return 0
	return GemSkip.cost(state.remaining)


## ELMASLA BİTİR: elmas düşer, iş anında biter (PARA TOPLA bekler). Elmas yetmezse hiçbir şey değişmez.
func finish_with_gems(car: Node3D) -> bool:
	var cost: int = gem_skip_cost(car)
	var state: RepairState = get_state(car)
	if cost <= 0 or state == null:
		return false
	var progress_node: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress_node == null or not progress_node.spend_gems(cost):
		return false
	if state.advance(state.remaining + 0.001):
		repair_progress.emit(state.car, state.repair_progress)
		_finish_state(state)
	gem_finished.emit(state.car)
	return true


## İş açılır: araç state.bay_index'teki CarSpot'a ışınlanır, lift kalkar.
func _occupy_bay(vehicle: TrafficVehicle, state: RepairState) -> void:
	_active.append(state)
	_progress_timer = progress_interval
	# Tek seferlik DEĞİL: ziyarette sahne ağaçtan çıkıp geri takılınca da bağlı kalmalı
	var on_exit: Callable = _on_car_exiting.bind(vehicle)
	if not vehicle.tree_exiting.is_connected(on_exit):
		vehicle.tree_exiting.connect(on_exit)
	var spot: Node3D = repair_car_spots[state.bay_index]
	var p: Vector3 = spot.global_position
	vehicle.enter_bay(Vector3(p.x, 0.0, p.z), spot.global_rotation.y)
	var bays_node: RepairBayManager = _bays()
	if bays_node:
		bays_node.raise_lift(state.bay_index, vehicle)   # lift kalkar, araç üstünde
	repair_started.emit(vehicle)


# --- Dil değişiminde devir ------------------------------------------------------

## Sahne yeniden kurulmadan hemen önce çağrılır: süren işler (araç modeli, rengi, arıza, alan, geçen
## süre, çarpanlar) yeni sahneye devredilmek üzere saklanır.
static func carry_over(tree: SceneTree) -> void:
	_carried = []
	var manager: RepairManager = tree.get_first_node_in_group("repair_manager") as RepairManager if tree else null
	if manager == null:
		return
	for state: RepairState in manager._active:
		var car: TrafficVehicle = state.car as TrafficVehicle
		if not is_instance_valid(car) or state.repair_type == null:
			continue
		_carried.append({
			"vehicle": car.vehicle_id, "appearance": car.appearance, "type": state.repair_type.id,
			"severity": state.severity, "bay": state.bay_index, "elapsed": state.elapsed,
			"duration_scale": state.duration_scale, "reward_scale": state.reward_scale, "boosted": state.boosted,
		})
	_carried_at = Time.get_ticks_msec()
	_skip_saved = true


## Yeni sahnede: devredilen işleri al (araçlar model yüklendikçe _tick_restore'da kurulur).
func _take_carried() -> void:
	if _carried.is_empty():
		return
	var gap: float = float(Time.get_ticks_msec() - _carried_at) / 1000.0   # yenileme sırasında geçen süre
	for job: Dictionary in _carried:
		var bay: int = int(job["bay"])
		if bay < 0 or bay >= repair_car_spots.size() or _type_by_id(job["type"]) == null:
			continue
		job["elapsed"] = float(job["elapsed"]) + gap
		_restoring.append(job)
	_carried = []
	_restore_time = RESTORE_TIMEOUT


func _tick_restore(delta: float) -> void:
	if _restoring.is_empty() or _traffic == null:
		return
	_restore_time -= delta
	for job: Dictionary in _restoring.duplicate():
		if job.get("hold", false):
			continue   # kayıttan gelen iş yokluk süresini bekliyor (resume_saved_jobs)
		if int(job["bay"]) >= capacity():
			_restoring.erase(job)   # alan artık yok (kayıt farklı yüklendi): iş bırakılır
			continue
		var vehicle: TrafficVehicle = _traffic.spawn_model(job["vehicle"], job["appearance"])
		if vehicle == null:
			if _restore_time <= 0.0:
				push_warning("RepairManager: '%s' modeli yüklenemedi, devralınan iş bırakıldı" % job["vehicle"])
				_restoring.erase(job)
			continue
		_restoring.erase(job)
		var type: RepairType = _type_by_id(job["type"])
		vehicle.fault = type
		vehicle.fault_severity = float(job["severity"])
		var state: RepairState = RepairState.new(vehicle, type, vehicle.fault_severity)
		state.bay_index = int(job["bay"])
		state.duration_scale = float(job["duration_scale"])
		state.reward_scale = float(job["reward_scale"])
		state.boosted = bool(job["boosted"])
		state.start()
		state.elapsed = float(job["elapsed"])
		_occupy_bay(vehicle, state)
		if state.advance(0.0):
			_finish_state(state)   # yenileme sırasında bitti (ya da zaten para bekliyordu)


# --- Yarım kalan işler (kayıt / yokluk) ----------------------------------------------------------

## Kayda giden süren işler: devirdekiyle aynı alanlar + görünüm renkleri (CarAppearance kaynağı JSON'a girmez) +
## kaydın anı (OfflineEarnings yoksa yokluk buradan ölçülür).
func jobs_state() -> Array:
	var out: Array = []
	var at: int = int(Time.get_unix_time_from_system())
	for state: RepairState in _active:
		var car: TrafficVehicle = state.car as TrafficVehicle
		if not is_instance_valid(car) or state.repair_type == null:
			continue
		out.append(_saved_job(car.vehicle_id, car.appearance, state.repair_type.id, state.severity, state.bay_index,
			state.elapsed, state.duration_scale, state.reward_scale, state.boosted, at))
	for job: Dictionary in _restoring:   # henüz kurulamamış (ya da yokluğu bekleyen) işler de kaybolmasın
		out.append(_saved_job(job["vehicle"], job.get("appearance") as CarAppearance, job["type"], job["severity"], job["bay"],
			job["elapsed"], job["duration_scale"], job["reward_scale"], job["boosted"], int(job.get("saved_at", at))))
	return out


static func _saved_job(vehicle: StringName, look: CarAppearance, type: StringName, severity: float, bay: int, elapsed: float,
		duration_scale: float, reward_scale: float, boosted: bool, at: int) -> Dictionary:
	var colors: Dictionary = {}
	if look:
		colors = {"body": look.body_color.to_html(false), "wheel": look.wheel_color.to_html(false),
			"glass": look.glass_color.to_html(true)}
	return {"vehicle": String(vehicle), "colors": colors, "type": String(type), "severity": snappedf(severity, 0.001),
		"bay": bay, "elapsed": snappedf(elapsed, 0.01), "duration_scale": duration_scale, "reward_scale": reward_scale,
		"boosted": boosted, "saved_at": at}


## Kayıttan gelen işler: alanları hemen ayrılır (oyuncu o arada aynı alana iş açamasın), araçları yokluk süresi
## bilinince kurulur. Dil değişimindeki yeniden kurulumda işler devirle geldiği için kayıttakiler alınmaz.
func load_jobs(jobs: Array) -> void:
	for job: Dictionary in _restoring.duplicate():
		if job.get("hold", false):
			_restoring.erase(job)   # yeniden yükleme: eski kayıttan bekleyenler bırakılır
	if _skip_saved:
		_skip_saved = false
		return
	for raw: Variant in jobs:
		if not raw is Dictionary:
			continue
		var data: Dictionary = raw
		var type: RepairType = _type_by_id(StringName(SaveSafe.s(data.get("type", ""))))
		var bay: int = SaveSafe.i(data.get("bay", -1))
		var vehicle: StringName = StringName(SaveSafe.s(data.get("vehicle", "")))
		if type == null or bay < 0 or bay >= repair_car_spots.size() or vehicle == &"":
			continue
		var look: CarAppearance = null
		var colors: Dictionary = data.get("colors", {}) if data.get("colors") is Dictionary else {}
		if Color.html_is_valid(SaveSafe.s(colors.get("body", ""))):
			look = CarAppearance.new()
			look.body_color = Color.html(SaveSafe.s(colors["body"]))
			if Color.html_is_valid(SaveSafe.s(colors.get("wheel", ""))):
				look.wheel_color = Color.html(SaveSafe.s(colors["wheel"]))
			if Color.html_is_valid(SaveSafe.s(colors.get("glass", ""))):
				look.glass_color = Color.html(SaveSafe.s(colors["glass"]))
		_restoring.append({"vehicle": vehicle, "appearance": look, "type": type.id,
			"severity": clampf(SaveSafe.f(data.get("severity", 1.0)), 0.1, 3.0), "bay": bay,
			"elapsed": maxf(SaveSafe.f(data.get("elapsed", 0.0)), 0.0),
			"duration_scale": clampf(SaveSafe.f(data.get("duration_scale", 1.0)), 0.1, 1.0),
			"reward_scale": clampf(SaveSafe.f(data.get("reward_scale", 1.0)), 0.1, 10.0),
			"boosted": SaveSafe.b(data.get("boosted", false)), "saved_at": SaveSafe.i(data.get("saved_at", 0)), "hold": true})
	_hold_time = HOLD_TIMEOUT


## Yokluk süresi bilindi: o sürede biten kayıttaki işler [{type, reward, xp}] olarak döner (ödülü gazete verir), kalanlar
## geçen süre eklenip alana kurulur.
func resume_saved_jobs(away: float) -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	for job: Dictionary in _restoring.duplicate():
		if not job.get("hold", false):
			continue
		var type: RepairType = _type_by_id(job["type"])
		job["elapsed"] = float(job["elapsed"]) + maxf(away, 0.0)
		if type and float(job["elapsed"]) >= type.duration * float(job["duration_scale"]):
			_restoring.erase(job)
			done.append(_settled(type, int(round(float(type.reward) * float(job["reward_scale"])))))
		else:
			job.erase("hold")
	_restore_time = RESTORE_TIMEOUT
	return done


## OfflineEarnings hiç sormadıysa (yalnız oyun testleri): kayıttaki saatle devam edilir, bitenler kendi ödülünü alır.
func _tick_hold(delta: float) -> void:
	if _hold_time <= 0.0:
		return
	_hold_time -= delta
	if _hold_time > 0.0:
		return
	var held: Array[Dictionary] = []
	for job: Dictionary in _restoring:
		if job.get("hold", false):
			held.append(job)
	if held.is_empty():
		return
	var away: float = maxf(float(int(Time.get_unix_time_from_system()) - int(held[0].get("saved_at", 0))), 0.0) \
		if int(held[0].get("saved_at", 0)) > 0 else 0.0
	for job: Dictionary in resume_saved_jobs(away):
		_grant(job)


## Arka plandan dönüş: süren işler geçen süre kadar ilerler (bitenler ₺ balonuyla bekler).
func advance_all(seconds: float) -> void:
	if seconds <= 0.0:
		return
	for state: RepairState in _active.duplicate():
		if is_instance_valid(state.car) and state.phase == RepairState.Phase.REPAIRING and state.advance(seconds):
			repair_progress.emit(state.car, state.repair_progress)
			_finish_state(state)
	for job: Dictionary in _restoring:
		if not job.get("hold", false):
			job["elapsed"] = float(job["elapsed"]) + seconds


## Uzun yokluktan dönüş: bitip ₺ balonu bekleyen işler ödülü verilmeden kapatılır (araç yola döner, alan boşalır) ve
## [{type, reward, xp}] olarak döner — ödülü gazete verir.
func settle_finished() -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	for state: RepairState in _active.duplicate():
		if state.phase != RepairState.Phase.REWARD_WAITING:
			continue
		done.append(_settled(state.repair_type, state.repair_reward))
		state.is_collected = true
		_release(state)
	return done


## Biten işin gazete kaydı: ödül işin başındaki çarpanla, XP ustalık çarpanıyla (ustalık sayacı ödeme anında işler).
func _settled(type: RepairType, reward: int) -> Dictionary:
	var mastery: JobMastery = _mastery()
	var xp: int = int(round(float(type.xp) * (mastery.xp_multiplier(type.id) if mastery else 1.0)))
	return {"type": String(type.id), "reward": reward, "xp": xp}


func _grant(job: Dictionary) -> void:
	var economy: EconomyManager = _economy()
	if economy:
		economy.add_money(int(job["reward"]))
	var player: PlayerProgress = _player()
	if player:
		player.add_xp(int(job["xp"]))
	var mastery: JobMastery = _mastery()
	if mastery:
		mastery.record(StringName(job["type"]))


func _type_by_id(id: StringName) -> RepairType:
	for t: RepairType in repair_types:
		if t.id == id:
			return t
	return null


## Sayaç bitti: ödül verilmez; araç CarSpot'ta ₺ balonuyla bekler.
func _finish_state(state: RepairState) -> void:
	var car: TrafficVehicle = state.car as TrafficVehicle
	if is_instance_valid(car):
		car.finish_repair(state.repair_reward)
		car.await_reward()
	var bays_node: RepairBayManager = _bays()
	if bays_node:
		bays_node.lower_lift(state.bay_index)   # tamir bitti: lift iner
	repair_ready.emit(car)


## PARA TOPLA: para + XP bir kez verilir, araç boş bir yol spawn noktasına ışınlanır, CarSpot boşalır.
func collect(car: Node3D) -> bool:
	if not can_collect(car):
		return false
	var state: RepairState = get_state(car)
	var vehicle: TrafficVehicle = state.car as TrafficVehicle
	state.is_collected = true
	_active.erase(state)
	var economy: EconomyManager = _economy()
	if economy:
		economy.add_money(state.repair_reward)
	# İŞ USTALIĞI: aynı arızayı çok yapmak XP'yi artırır, kademe atlayınca tek seferlik ödül düşer
	var mastery: JobMastery = _mastery()
	var xp_gain: int = state.repair_xp
	if mastery:
		xp_gain = int(round(float(xp_gain) * mastery.xp_multiplier(state.repair_type.id)))
	var player: PlayerProgress = _player()
	if player:
		player.add_xp(xp_gain)
	if mastery:
		mastery.record(state.repair_type.id)
	repair_collected.emit(vehicle, state.repair_reward, xp_gain)
	job_collected.emit(state.repair_type.id, state.repair_reward)
	_release(state)
	return true


## İş kapandı: lift iner, araç boş bir yol noktasından trafiğe döner, alan boşalır.
func _release(state: RepairState) -> void:
	var vehicle: TrafficVehicle = state.car as TrafficVehicle
	_active.erase(state)
	var lift_bays: RepairBayManager = _bays()
	if lift_bays:
		lift_bays.release_lift(state.bay_index)   # araç eski kotuna iner, lift alçak kalır
	if is_instance_valid(vehicle):
		var on_exit: Callable = _on_car_exiting.bind(vehicle)
		if vehicle.tree_exiting.is_connected(on_exit):
			vehicle.tree_exiting.disconnect(on_exit)
		vehicle.return_to_traffic(_pick_return_point())
	repair_slot_freed.emit(vehicle)


## Yola dönüş noktası: çevresi boş bir trafik spawn noktası (rastgele); hiçbiri boş değilse rastgele biri.
func _pick_return_point() -> TrafficWaypoint:
	if _traffic == null or _traffic.spawn_points.is_empty():
		return null
	var free: Array[TrafficWaypoint] = []
	for p: TrafficWaypoint in _traffic.spawn_points:
		if _traffic.is_clear(p.global_position):
			free.append(p)
	var pool: Array[TrafficWaypoint] = free if not free.is_empty() else _traffic.spawn_points
	return pool[_rng.randi() % pool.size()]


func _cancel_state(state: RepairState) -> void:
	var car: Node3D = state.car
	_active.erase(state)
	if is_instance_valid(car):
		var on_exit: Callable = _on_car_exiting.bind(car)
		if car.tree_exiting.is_connected(on_exit):
			car.tree_exiting.disconnect(on_exit)
	var bays_node: RepairBayManager = _bays()
	if bays_node:
		bays_node.release_lift(state.bay_index)
	repair_cancelled.emit(car)


## Yalnızca araç SİLİNİRKEN iş iptal olur. Arkadaş garajı ziyaretinde (GarageVisit) kendi sahne bütünüyle
## ağaçtan çıkarılır ama silinmez: tamir dönüşte kaldığı yerden sürmeli. Doğrudan free() edilen araç
## da _tick_active'in is_instance_valid denetimine takılır.
func _on_car_exiting(car: Node3D) -> void:
	if not car.is_queued_for_deletion():
		return
	var state: RepairState = get_state(car)
	if state:
		_cancel_state(state)


# --- Müşteri seçimi --------------------------------------------------------------

func _connect_traffic() -> void:
	_traffic = _find_traffic(get_tree().current_scene)
	if _traffic == null:
		push_warning("RepairManager: sahnede TrafficManager yok; müşteri seçilemez")
	if repair_wait_spots.is_empty():
		push_warning("RepairManager: yol kenarı bekleme noktası (repair_wait_spots) atanmamış; müşteri oluşmaz")
	if repair_car_spots.is_empty():
		push_warning("RepairManager: CarSpot atanmamış; tamir başlatılamaz")
	var upgrades: GarageUpgradeManager = _upgrades()
	if upgrades and not upgrades.levels_changed.is_connected(_apply_supply):
		upgrades.levels_changed.connect(_apply_supply)   # garaj büyüdü → trafik/arz güncellensin
	_apply_supply()
	_take_carried()


## Sayaç dolunca ve yerde yer varsa: önünde boş bekleme noktası olan trafikteki bir NPC müşteri olur.
func _tick_customers(delta: float) -> void:
	if _traffic == null or repair_wait_spots.is_empty():
		return
	_tick_patience(delta)
	_customer_timer -= delta
	if _customer_timer > 0.0 or waiting_count() >= waiting_limit():
		return
	var options: Array[Dictionary] = _candidates()
	if options.is_empty():
		_customer_timer = CANDIDATE_RETRY   # uygun araç/nokta yok: biraz sonra yeniden dene
		return
	var pick: Dictionary = options[_rng.randi() % options.size()]
	var job: RepairType = _pick_fault(unlocked_types(_player_level()))
	if job == null:
		_customer_timer = CANDIDATE_RETRY
		return
	var vehicle: TrafficVehicle = pick["vehicle"]
	vehicle.request_repair(pick["spot"], job, _rng.randf_range(job.severity_min, job.severity_max))
	if not vehicle.customer_stopped.is_connected(_on_customer_stopped):
		vehicle.customer_stopped.connect(_on_customer_stopped)
	var interval: float = float(_supply()["interval"])
	_customer_timer = _rng.randf_range(customer_interval_min * interval, customer_interval_max * interval)
	customer_marked.emit(vehicle)


## Trafikteki SAĞLAM araç + önünde (SPOT_AHEAD_MIN..MAX), aynı yöne bakan, çevresi boş bekleme noktası
## çiftleri. Kavşak içinde / kavşağa giriş bekleyen araç seçilmez; nokta sıradaki waypoint'ten önce olmalı;
## yanaşma yolu üzerinde (araç ile nokta arasında, yakınında) duran başka araç olmamalı.
func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: TrafficVehicle in _traffic.vehicles:
		if v.mode != TrafficVehicle.Mode.TRAFFIC or v.repair_status != TrafficVehicle.RepairStatus.NORMAL:
			continue
		if v.busy_after_race():
			continue   # yarıştan yeni çıktı: önce yola karışsın
		if CarCatalog.is_exotic(v.vehicle_id):
			continue   # egzotik araç şehirden yalnızca geçer (TrafficManager)
		if v.is_in_intersection() or v.target == null or v.target.intersection_entry:
			continue
		var forward: Vector3 = _flat(v.global_transform.basis.z).normalized()
		var to_target: float = _flat(v.target.global_position - v.global_position).dot(forward)
		for spot: Node3D in active_wait_spots():
			var rel: Vector3 = _flat(spot.global_position - v.global_position)
			var along: float = rel.dot(forward)
			if along < SPOT_AHEAD_MIN or along > SPOT_AHEAD_MAX or along > to_target - 0.2:
				continue
			if absf(rel.cross(forward).y) > SPOT_SIDE_MAX:
				continue
			if _flat(spot.global_transform.basis.z).normalized().dot(forward) < 0.9:
				continue  # nokta bu şeridin yönüne bakmıyor (karşı kaldırım)
			if not _spot_free(spot) or not _path_clear(v, forward, along):
				continue
			out.append({"vehicle": v, "spot": spot})
	return out


## Araç ile nokta arasında, yola yakın duran (trafik dışı) araç var mı?
func _path_clear(v: TrafficVehicle, forward: Vector3, along: float) -> bool:
	for other: TrafficVehicle in _traffic.vehicles:
		if other == v or other.mode == TrafficVehicle.Mode.TRAFFIC or other.in_bay():
			continue
		var rel: Vector3 = _flat(other.global_position - v.global_position)
		var a: float = rel.dot(forward)
		if a > -0.4 and a < along + 0.4 and absf(rel.cross(forward).y) < PATH_SIDE:
			return false
	return true


## Nokta boş mu: hiçbir müşteri bu noktaya yanaşmıyor / burada durmuyor ve çevresinde trafik dışı araç yok.
func _spot_free(spot: Node3D) -> bool:
	var p: Vector3 = spot.global_position
	for v: TrafficVehicle in _traffic.vehicles:
		if v.wait_spot() == spot:
			return false
		if v.mode != TrafficVehicle.Mode.TRAFFIC and Vector2(v.global_position.x - p.x, v.global_position.z - p.z).length() < SPOT_CLEAR:
			return false
	return true


func _pick_fault(options: Array[RepairType]) -> RepairType:
	var total: float = 0.0
	for t: RepairType in options:
		total += maxf(t.weight, 0.0)
	if total <= 0.0:
		return null
	var roll: float = _rng.randf() * total
	for t: RepairType in options:
		roll -= maxf(t.weight, 0.0)
		if roll <= 0.0:
			return t
	return options[options.size() - 1]


func _on_customer_stopped(vehicle: TrafficVehicle) -> void:
	vehicle.patience = _rng.randf_range(CUSTOMER_PATIENCE.x, CUSTOMER_PATIENCE.y)
	customer_stopped.emit(vehicle)


## SABIR: bekleyen müşterinin süresi azalır; son PATIENCE_WARN sn balonda geri sayım, bitince gider.
## Seçili müşteri (oyuncu plakasına bakıyor) ve eğitim sürerken azalmaz.
## SIRA: geri sayıma girecek müşteri, bir öncekinin geri sayımı COUNTDOWN_GAP sn önce başlamadıysa tam PATIENCE_WARN'da
## bekler (balonda sayı yok); sayım bitip gidecek müşteri de son gidişten COUNTDOWN_GAP sn geçmediyse 0:01'de bekler —
## seçiliyken duran bir sayım sonradan başkasınınkiyle çakışabildiği için gidişte de denetlenir.
func _tick_patience(delta: float) -> void:
	if _tutorial_running():
		return
	_patience_clock += delta
	for vehicle: TrafficVehicle in _traffic.vehicles.duplicate():
		if not vehicle.is_waiting() or vehicle == _target:
			continue
		var left: float = vehicle.patience - delta
		if vehicle.patience >= PATIENCE_WARN and left < PATIENCE_WARN:
			if _patience_clock - _last_countdown < COUNTDOWN_GAP:
				vehicle.patience = PATIENCE_WARN   # sırası gelmedi: geri sayım henüz başlamaz
				continue
			_last_countdown = _patience_clock
		if left <= 0.0:
			if _patience_clock - _last_departure < COUNTDOWN_GAP:
				vehicle.patience = 0.01   # az önce biri gitti: o şeride katılana kadar 0:01'de bekler
				vehicle.show_patience(1)
				continue
			_last_departure = _patience_clock
			_dismiss_customer(vehicle)
			continue
		vehicle.patience = left
		if left < PATIENCE_WARN:
			vehicle.show_patience(ceili(left))


## Müşteri beklemekten sıkıldı: kaldırımdan çıkıp trafiğe döner (ekrandaysa korna çalar).
func _dismiss_customer(vehicle: TrafficVehicle) -> void:
	vehicle.give_up()
	if _traffic.sfx and not _traffic.is_hidden(vehicle.global_position):
		_traffic.sfx.honk()
	customer_left.emit(vehicle)


func _tutorial_running() -> bool:
	if not is_inside_tree():
		return false
	var director: Node = get_tree().get_first_node_in_group("tutorial_director")
	return director != null and director.has_method(&"is_running") and bool(director.call(&"is_running"))


func _find_traffic(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null


func _player_level() -> int:
	var player: PlayerProgress = _player()
	return player.level if player else 1


func _poll_target() -> void:
	var selected: Node3D = CarHitbox.selected_car
	var target: Node3D = selected if is_repairable(selected) else null
	if target != _target:
		_target = target
		target_changed.emit(target)


func _player() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress


## Paranın tek kaynağı (sahnede yoksa null: maliyet/ödül uygulanmaz, akış bozulmaz).
func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager


## İş ustalığı (sahnede yoksa null: XP çarpanı 1.0).
func _mastery() -> JobMastery:
	return get_tree().get_first_node_in_group("job_mastery") as JobMastery


## Garaj geliştirmeleri (sahnede yoksa null: hız çarpanı 1.0, kapasite 1).
func _upgrades() -> GarageUpgradeManager:
	return get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
