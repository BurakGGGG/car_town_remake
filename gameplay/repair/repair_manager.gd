class_name RepairManager
extends Node
## Tamir döngüsü (Car Town tarzı, sakin trafik):
## 1) Müşteri + ARIZA: belirli aralıklarla (customer_interval) trafikteki SAĞLAM bir NPC'ye katalogdan
##    (RepairType.defaults(): MOTOR / FREN / LASTİK / KAPORTA) ağırlıkla bir arıza atanır; araç önünde
##    boş bir yol kenarı bekleme noktası (repair_wait_spots) varsa oraya yanaşıp durur ve balonunda
##    arıza adını gösterir (REPAIR_REQUESTED → REPAIR_WAITING). Arıza müşteri olurken seçilir, o
##    döngü boyunca değişmez; araç trafiğe dönünce sıfırlanır. Normal trafik aracında ne balon ne arıza
##    vardır. Aynı anda en fazla waiting_limit() araç bekler (garaj seviyesine bağlı, bkz. SUPPLY);
##    sınır doluysa yeni müşteri oluşmaz.
##    Bekleyen müşteri tamire alınana kadar gitmez (süresiz).
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
signal repair_started(car: Node3D)                 # TAMİRE AL: araç CarSpot'ta, sayaç başladı
signal repair_progress(car: Node3D, progress: float)
signal repair_ready(car: Node3D)                   # sayaç bitti; ödül PARA TOPLA'yı bekliyor (CarSpot dolu)
signal repair_collected(car: Node3D, reward: int, xp: int)  # para + XP verildi, araç yola ışınlandı
signal repair_cancelled(car: Node3D)
signal job_collected(job_id: StringName, reward: int)   # iş türü + ödül (görev sayaçları; repair_collected ile aynı anda)
signal repair_slot_freed(car: Node3D)              # CarSpot boşaldı

const CarHitbox: GDScript = preload("res://car_hitbox.gd")

## GARAJ SEVİYESİ → MÜŞTERİ ARZI. Ölçüm (bkz. docs/GDD.md): garaj büyümeden müşteri akışı
## dakikada ~2,4'te sabit kalıyor, bu yüzden 2. ve 3. tamir alanı ekonomik olarak işe yaramıyordu
## (kuyruk hep boş, bay doluluğu %38). Garaj seviyesi artık arzı da büyütür:
##   interval → customer_interval_min/max çarpanı (küçük = sık müşteri)
##   waiting  → aynı anda yol kenarında bekleyebilen müşteri. 2026-09-27: kullanıcı kararıyla
##              HER SEVİYEDE 2 — garaj büyüdükçe 3-4 araç birikmesi kaldırımı tıkıyor ve dağınık
##              görünüyordu. Garaj seviyesinin arz katkısı artık yalnızca sıklık ve değer üzerinden.
##   spots    → kullanılan bekleme noktası sayısı; waiting ile aynı tutulur (fazlası kullanılmaz)
##   reward   → müşteri değeri çarpanı (daha iyi sınıf araçlar gelir)
##   traffic  → TrafficManager.max_vehicles. 4. seviyede 8 yerine 10: ÖLÇÜLDÜ (20 dk, sv.15, 3 alan,
##              tamir hızı 5) — trafik 8'de garaj 4 yalnızca 2.206 ₺/dk veriyordu (garaj 3: 2.021),
##              yani 60.000 ₺'lik son genişleme 5,4 saatte kendini amorti ediyordu. Aday araç havuzu
##              büyümediği için kısalan müşteri aralığı karşılığını bulamıyor (bay'deki araçlar yoldan
##              çekiliyor). Trafik 10 ile aynı yapılandırma 2.798 ₺/dk (+%27, amorti 77 dk).
const SUPPLY: Array[Dictionary] = [
	{"interval": 1.00, "waiting": 2, "spots": 2, "reward": 1.00, "traffic": 4},
	{"interval": 0.80, "waiting": 2, "spots": 2, "reward": 1.15, "traffic": 6},
	{"interval": 0.62, "waiting": 2, "spots": 2, "reward": 1.30, "traffic": 8},
	{"interval": 0.48, "waiting": 2, "spots": 2, "reward": 1.45, "traffic": 10},
]
const SPOT_AHEAD_MIN: float = 0.5   # bekleme noktası aracın bu kadar önünde olmalı (yanaşma payı)
const SPOT_AHEAD_MAX: float = 3.2   # aracın noktayı "görebildiği" pencere (1.8 iken adaylar çok seyrekti)
const SPOT_SIDE_MAX: float = 0.6    # noktanın şeride yanal uzaklığı en çok (kaldırım kenarı ~0.36)
const SPOT_CLEAR: float = 0.9       # nokta çevresinde bu yarıçapta bekleyen araç varsa dolu sayılır
const PATH_SIDE: float = 0.55       # yanaşma yolunun bu kadar yanında duran araç varsa o nokta seçilmez

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

var _active: Array[RepairState] = []   # açık işler (her biri bir CarSpot'ta); en fazla capacity() tane
var _target: Node3D
var _progress_timer: float = 0.0
var _customer_timer: float = 3.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()  # müşteri kararı (trafik RNG'sinden bağımsız)
var _traffic: TrafficManager


func _ready() -> void:
	add_to_group("repair_manager")
	_rng.randomize()
	if repair_types.is_empty():
		repair_types = RepairType.defaults()
	_connect_traffic.call_deferred()


func _process(delta: float) -> void:
	_poll_target()
	_tick_active(delta)
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
		_traffic.max_vehicles = int(_supply()["traffic"])


## Şu an süren iş sayısı (tamir + ödül bekleyen).
func active_count() -> int:
	return _active.size()


## Tüm tamir alanları dolu mu (TAMİRE AL'dan para toplanana kadar)?
func is_busy() -> bool:
	return _active.size() >= capacity()


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
		if not is_instance_valid(repair_car_spots[i]):
			continue
		var used: bool = false
		for state: RepairState in _active:
			if state.bay_index == i:
				used = true
				break
		if not used:
			return i
	return -1


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
	_active.append(state)
	_progress_timer = progress_interval
	var on_exit: Callable = _on_car_exiting.bind(vehicle)
	if not vehicle.tree_exiting.is_connected(on_exit):
		vehicle.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	var spot: Node3D = repair_car_spots[bay]
	var p: Vector3 = spot.global_position
	vehicle.enter_bay(Vector3(p.x, 0.0, p.z), spot.global_rotation.y)
	var bays_node: RepairBayManager = _bays()
	if bays_node:
		bays_node.raise_lift(bay, vehicle)   # lift kalkar, araç üstünde
	repair_started.emit(vehicle)
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
	var lift_bays: RepairBayManager = _bays()
	if lift_bays:
		lift_bays.release_lift(state.bay_index)   # araç eski kotuna iner, lift alçak kalır
	if is_instance_valid(vehicle):
		var on_exit: Callable = _on_car_exiting.bind(vehicle)
		if vehicle.tree_exiting.is_connected(on_exit):
			vehicle.tree_exiting.disconnect(on_exit)
		vehicle.return_to_traffic(_pick_return_point())
	repair_slot_freed.emit(vehicle)
	return true


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
	var bays_node: RepairBayManager = _bays()
	if bays_node:
		bays_node.release_lift(state.bay_index)
	repair_cancelled.emit(car)


func _on_car_exiting(car: Node3D) -> void:
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


## Sayaç dolunca ve yerde yer varsa: önünde boş bekleme noktası olan trafikteki bir NPC müşteri olur.
func _tick_customers(delta: float) -> void:
	if _traffic == null or repair_wait_spots.is_empty():
		return
	_customer_timer -= delta
	if _customer_timer > 0.0 or waiting_count() >= waiting_limit():
		return
	var options: Array[Dictionary] = _candidates()
	if options.is_empty():
		return  # uygun araç/nokta yok: sonraki karede yeniden dene
	var pick: Dictionary = options[_rng.randi() % options.size()]
	var job: RepairType = _pick_fault(unlocked_types(_player_level()))
	if job == null:
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
	customer_stopped.emit(vehicle)


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
