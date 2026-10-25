class_name TrafficVehicle
extends Node3D
## Şehirde kendi kendine dolaşan NPC araç (Car Town tarzı): kendi şeridinde düz gider,
## waypoint'ten waypoint'e "ray üstünde" ilerler, öndeki araca göre yavaşlar/durur.
## Fizik yok. Görünüm ve tekerlekler mevcut CarRig / CarAppearance ile (kayıt defterine girmeyen,
## bu araca özel materyaller). Oyuncu kontrolü yoktur.
## Seçim: park halindeki araçlarla aynı car_hitbox.gd (CarHitbox + SelectionRing) çalışma zamanında
## eklenir; seçilen araç bu node'dur (selected_car).
##
## Durumlar (mode) — aynı araç örneği durum değiştirerek trafik → tamir → trafik döngüsünü yapar:
##   TRAFFIC          normal sürüş, balon yok.
##   REPAIR_REQUESTED tamir ihtiyacı oluştu: waypoint takibinden çıkar, şeridinin sağındaki bekleme
##                    noktasına (yol kenarı) yanaşır; balonda yalnızca 🔧 işareti (arıza adı araç
##                    üstünde yazmaz — araca ya da balona tıklayınca HUD plakasında görünür).
##   REPAIR_WAITING   yol kenarında duruyor (hız 0, nokta yönünde), 🔧 balonu açık, oyuncuyu bekler
##                    (süresiz: tamire alınana kadar gitmez).
##   REPAIR_BAY       "TAMİRE AL": araç anında CarSpot'a ışınlanır (sürüş animasyonu yok), balonda
##                    "TAMİR", trafikten çıkmıştır (takip/sayım dışı).
##   REPAIR_COMPLETE  sayaç bitti: ödül balonu (₺ +150) açılır; hemen ardından REWARD_WAITING.
##   REWARD_WAITING   oyuncu parayı toplayana kadar CarSpot'ta kalır.
##   → TRAFFIC        para toplanınca boş bir yol spawn noktasına ışınlanır, balon kapanır, ARIZA SIFIRLANIR
##                    (fault = null, durum NORMAL) ve araç waypoint zincirinden yoluna devam eder; ileride
##                    yeniden müşteri olursa yeni bir arıza atanır.
## Arıza durumu (repair_status) mode'dan ayrı tutulur (NORMAL → DAMAGED → REPAIRING → REPAIRED → NORMAL).
##   CHASE            polis kovalamacası (PoliceChase): şüpheli ya da polis. Waypoint takibi yerine kovalamacanın
##                    hazırladığı yol çizgisinde, yolun ORTA çizgisinde hızlı gider; trafik ona yol verir, kavşak
##                    kilidine ve öndeki araca bakmaz. Seçilemez, müşteri / rakip olmaz, şehir sayacına girmez.
## Yol verme: TRAFFIC kipindeki araç arkadan gelen ya da karşıdan yaklaşan kovalamaca aracını görünce sağa
## çekilir ve yavaşlar (TrafficManager.chase_pressure); kovalamaca geçince şeridine döner.

signal reached_despawn(vehicle: TrafficVehicle)
## Yol kenarındaki bekleme noktasına yerleşti (REPAIR_WAITING).
signal customer_stopped(vehicle: TrafficVehicle)

## Arıza durumu (koşul).
enum RepairStatus { NORMAL, DAMAGED, REPAIRING, REPAIRED }
## Araç durumu (hareket / tamir döngüsü).
## RACE_CHALLENGE: yarış daveti veren rakip — tamir akışıyla AYNI yanaşma kodunu kullanır
## (yol kenarına çekilir, döner, balon açar) ama arıza/tamir durumuna hiç dokunmaz.
enum Mode { TRAFFIC, REPAIR_REQUESTED, REPAIR_WAITING, REPAIR_BAY, REPAIR_COMPLETE, REWARD_WAITING,
	RACE_CHALLENGE, CHASE }

const WHEEL_RADIUS: float = 0.1  # model uzayında (ölçek öncesi)
const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")
const PULL_OVER_SPEED: float = 0.45   # yol kenarına yanaşma hızı
const PULL_OVER_TURN: float = 3.0     # yanaşma dönüş hızı (rad/sn)
## KALDIRIMDAN ÇIKIŞ (sıkılan müşteri): bekleme noktaları arası ~0,4 boşluk var, şerit ortası ~0,36 yanda. Araç
## önce yerinde kırar, açısı yetince yavaşça şeride çıkar, ortaya oturunca düzelip normal sürer. Eskiden uzaktaki yol
## noktasına neredeyse paralel gidiyor, öndeki bekleyenlerin İÇİNDEN geçiyordu (kullanıcı bildirdi; qa/musteri_cikis_qa).
const MERGE_AIM: float = 0.28          # şerit çizgisinde ne kadar ileriyi hedefler (küçük = keskin çıkış)
const MERGE_TURN: float = 2.8          # rad/sn
const MERGE_SPEED: float = 0.3         # çıkış hızı sınırı
## Şerit ortasına bu kadar yaklaşıp bu açıdan az sapınca çıkış biter (öndekinden kurtuldu); kalan küçük düzeltmeyi
## normal sürüş yapar — yoksa son birkaç santim ~1 sn sürüyordu.
const MERGE_DONE: float = 0.06
const MERGE_DONE_ANGLE: float = 0.3
const PULL_OVER_REACH: float = 0.06   # bekleme noktasına varış yarıçapı
const PARK_TURN_SPEED: float = 2.5    # yerinde nokta yönüne dönüş (rad/sn)
const BUBBLE_GAP: float = 0.12        # tavanın üstünde boşluk
const BUBBLE_PICK_DEPTH: float = 0.26   # balon tıklama kutusunun derinliği (billboard döndüğü için geniş)
const RACE_REJOIN_TIME: float = 6.0     # yarıştan sonra tekrar müşteri olmadan önce geçen süre (sn)
## Polise yol verme: şeridin sağına bu kadar kayar (kaldırımda bekleyen müşterilere çarpmasın diye küçük; kovalamaca
## yolun orta çizgisinden geçtiği için aradaki açıklık ~0,38 — araç eni 0,27) ve hızını bu orana kadar düşürür.
const YIELD_SHIFT: float = 0.08
const YIELD_SLOW: float = 0.35
const YIELD_SHIFT_RATE: float = 0.3    # birim/sn (kayma hızı)
## KAÇAN KAYBEDEN: yarışı oyuncuya kaybeden rakip (flee) şeritten kaçar gibi çıkar — normal trafiğin ~2 katı hız,
## sert kalkış, yolun ORTA çizgisinde zikzak (önündeki yavaş aracın yanından geçer; trafik kovalamacadaki gibi yol
## verir), kırmızı ışığa bakmaz (kavşakta karşı yönden araç varsa onun çıkmasını bekler, çarpışma yok).
## Yan hareket DİREKSİYONLA olur (öteleme yok): durduğu yerden kalkıp ileri giderken burnunu orta çizgiye kırar, zikzağı
## da burnunu sağa sola çevirerek çizer — eskiden yan kayma doğrudan konuma ekleniyordu, araç yolun ortasına ışınlanıyordu.
const RUNNER_SPEED: float = 1.75
const RUNNER_ACCEL: float = 1.7
const RUNNER_BRAKING: float = 3.2
const RUNNER_SHIFT: float = 0.29        # şerit ortasından yolun orta çizgisine (sola)
const RUNNER_WEAVE: float = 0.15        # zikzak genliği (iki dalga: düzensiz)
const RUNNER_WEAVE_RATE: float = 3.1
const RUNNER_WEAVE2: float = 0.04
const RUNNER_WEAVE_RATE2: float = 7.3
const RUNNER_AIM: float = 0.6           # direksiyon hedefi: şeritte bu kadar ileri
const RUNNER_TURN: float = 3.6          # rad/sn (hızla ölçeklenir: dururken yerinde dönmez)
## SÜRÜŞ CANLILIĞI (kaçak, kovalamaca): sola hız → ön teker açısı, sola ivme → gövde dışa yatar, hızlanma → burun kalkar.
const FLAIR_STEER: float = 30.0         # derece / (birim/sn)
const FLAIR_STEER_MAX: float = 26.0
const FLAIR_ROLL: float = 0.035         # rad / (birim/sn²)
const FLAIR_ROLL_MAX: float = 0.1
const FLAIR_PITCH: float = 0.02
const FLAIR_PITCH_MAX: float = 0.05
## Kovalamacada savrulurken arka kayar (hafif drift görüntüsü): yön, hareket yönünden yan hızla bu kadar sapar (rad).
const CHASE_SLIP: float = 0.1
## DÖRTLÜ (TrafficManager seyrek seçer): şeridinde yumuşak frenle durur, dörtlüleri yanar, birkaç saniye sonra devam eder.
const HAZARD_BRAKING: float = 0.75
## SÜPER ARAÇ KALKIŞI (2026-10-20, kullanıcı: "süper araçlar önleri boş olunca ışıktan çıkarken dümdüz hızlıca basıp
## gitsinler, çok nadir olmasın 4'te 1 falan"): egzotik araç kırmızıda en önde dururken (önü LAUNCH_CLEAR kadar boş)
## yeşil yanınca LAUNCH_CHANCE ile gaza basar: kavşaktan DÜZ geçer, LAUNCH_DISTANCE boyunca hızlı gider, sonra normal
## hıza süzülür. Önüne araç çıkarsa (LAUNCH_ABORT), sonraki kavşağa yaklaşırsa ya da kovalamaca gelirse erken biter.
## Gövde gazda arkaya oturur (_drive_flair), ExoticEngine ivmeden tam gazı ve vites atışlarını kendisi çalar.
const LAUNCH_CHANCE: float = 0.25
const LAUNCH_CLEAR: float = 3.5
const LAUNCH_SPEED: float = 2.0
const LAUNCH_ACCEL: float = 2.0
const LAUNCH_BRAKING: float = 2.6
const LAUNCH_COAST: float = 0.9      # kalkış bitince normal hıza süzülme (birim/sn²)
const LAUNCH_DISTANCE: float = 7.0
const LAUNCH_ABORT: float = 2.6
## Kavşak çıkışından en az bu kadar uzaklaşmadan durmaz: arkadaki araç kavşağın içinde beklemesin (karşı yönü tıkardı).
const HAZARD_EXIT_CLEAR: float = 1.2

@export var max_speed: float = 0.8        # birim/sn
@export var acceleration: float = 0.6     # birim/sn²
@export var braking: float = 1.4          # birim/sn²
@export var turn_speed: float = 2.4       # rad/sn (küçük yön düzeltmeleri)
@export var reach_distance: float = 0.14  # waypoint'e "vardı" sayılan mesafe
@export var follow_distance: float = 1.3  # öndeki araca bu mesafede yavaşla
@export var stop_distance: float = 0.72   # bu mesafede dur (araç boyu ~0.6)
@export var lock_check_distance: float = 0.9  # kavşak geçiş izni bu mesafeden itibaren sorgulanır
## Işık yeşil değilse bu mesafeden (giriş noktasına, yol boyunca) yavaşlamaya başlar: bekleme yeri girişten 0,3–1,4
## geride; izin sorgusu (0,9) ve giriş noktasının ancak 0,79 kala görülmesi yumuşak duruşa yetmiyordu.
@export var light_lookahead: float = 2.2

var manager: TrafficManager
var target: TrafficWaypoint
var speed: float = 0.0
var model: Node3D
var rig: CarRig
## Hareket ekseni: 0 = X (doğu-batı), 1 = Z (kuzey-güney). Kavşak geçiş sırası için.
var axis: int = 0
## Arıza durumu (RepairManager değiştirir). Araçlar SAĞLAM doğar; müşteri olan DAMAGED olur.
var repair_status: RepairStatus = RepairStatus.NORMAL
var mode: Mode = Mode.TRAFFIC
## Yarış şeridinde mi doğdu? (Şehir trafiği sayacına girmez; RaceManager yönetir.)
var race_lane: bool = false
## Bu aracın KATALOG kimliği — yarışta aynı model çıksın diye (yoldaki araç = rakip araç).
var vehicle_id: StringName = &""
## Burnun araç merkezine uzaklığı (CarHitbox kutusundan): dur çizgisine burun hizalanır; takip mesafesi de
## bunu kullanır (TrafficManager.distance_to_vehicle_ahead).
var _front: float = 0.3
## Bu kavşak girişi için seçilen duruş: burnun dur çizgisini geçtiği mesafe (− = çizginin gerisinde).
var _stop_entry: TrafficWaypoint
var _stop_overshoot: float = 0.0
## Müşterinin arızası (request_repair ile atanır; trafiğe dönünce null olur). Müşteri değilken null.
var fault: RepairType
## Arıza şiddeti (RepairType.severity_min..max arası); ilk sürümde yalnızca veri, süreyi etkilemez.
var fault_severity: float = 1.0
## Görünüm (boya / jant); dil değişiminde tamirdeki araç aynı renkle yeniden kurulsun diye tutulur.
var appearance: CarAppearance
## Yarış daveti balonunda gösterilecek arkadaş fotoğrafı (RaceManager; null = yalnızca damalı bayrak).
var race_avatar: Texture2D
var race_avatar_illustrated: bool = true
var _bubble: CarBubble
var _bubble_shape: CollisionShape3D  # CarHitbox altında: balon görünürken balona tıklamak da aracı seçer
var _in_intersection: bool = false
var _spot: Node3D                 # yol kenarı bekleme noktası (REPAIR_REQUESTED / REPAIR_WAITING)
var _arrived: bool = false        # bekleme noktasına vardı, yerinde yerleşiyor
## Yarıştan sonra araç bir süre müşteri olarak seçilmez: yol kenarından kalkıp akışa karışsın
## (yoksa RaceManager onu bıraktığı anda RepairManager aynı kaldırımda müşteri yapıyor).
var _race_cooldown: float = 0.0
var _yield_shift: float = 0.0     # polise yol verirken şeridin sağına kayma (TRAFFIC kipinde); kaçarken − (sola)
## Yarışı kaybetti, kaçıyor (bkz. RUNNER_*); yol ucunda kaybolana dek sürer.
var fleeing: bool = false
var _flee_time: float = 0.0
var _merging: bool = false     # kaldırımdan şeride çıkıyor (give_up)
## Tamir müşterisinin kalan sabrı (sn; RepairManager sayar). Bitince vazgeçip gider (give_up).
var patience: float = 0.0
var _patience_shown: int = -1
## Şu anki yol parçasının başı (son varılan nokta); kaçağın şerit çizgisi buradan hedefe uzanır. INF = bilinmiyor.
var _segment_from: Vector3 = Vector3.INF
var _flair_left_velocity: float = 0.0
var _flair_roll: float = 0.0
var _flair_pitch: float = 0.0
var _flair_speed: float = 0.0
var _last_weave: float = 0.0
## --- Kovalamaca (CHASE): yol çizgisi, üzerindeki konum ve orta çizgiye kayma ---
var _chase_points: PackedVector3Array = PackedVector3Array()
var _chase_lengths: PackedFloat32Array = PackedFloat32Array()   # her noktaya kadarki toplam uzunluk
var chase_distance: float = 0.0   # yol çizgisi üzerindeki konum (PoliceChase sürer)
var chase_offset: float = 0.0     # sola (orta çizgiye) kayma
## Öndeki araç (TrafficManager.distance_to_vehicle_ahead her ölçümde yazar; yoksa null).
var leader: TrafficVehicle
## Önündeki araç yüzünden duruyor (kırmızı / kavşak sırası değil) — saniye; yürüyünce 0. CityAmbience korna için okur.
var stuck_time: float = 0.0
## Bu karede kırmızıda / kavşak sırasında bekliyor (ya da öndeki öyle bekleyen kuyruğun içinde).
var waiting_light: bool = false
var _hazard_left: float = 0.0
var _last_exit: Vector3 = Vector3.INF   # son geçilen kavşak çıkışı
var _light_stop: bool = false            # kırmızıda en önde duruyor (önü boş): yeşilde kalkış zarı atılır
var _launch_from: Vector3 = Vector3.INF  # süper araç kalkışının başladığı yer (INF: kalkış yok)
## Kalkış olasılığı (QA gerçek akışı görmek için 1 yapar).
var launch_chance: float = LAUNCH_CHANCE
var _hazards: HazardLights
var _scene_path: String = ""


func setup(traffic_manager: TrafficManager, scene: PackedScene, look: CarAppearance, start: TrafficWaypoint, model_scale: float) -> void:
	manager = traffic_manager
	appearance = look
	_scene_path = scene.resource_path
	model = scene.instantiate() as Node3D
	# Bağlam çarpanı × aracın GERÇEK boyutundan türeyen ölçek: Getz gerçekten küçük, E60 gerçekten
	# uzun görünür (CarCatalog.model_scale; cars.json "real_dimensions"dan türetilmiştir).
	model.scale = Vector3.ONE * model_scale * CarCatalog.model_scale(vehicle_id)
	add_child(model)
	rig = CarRig.new(model)   # for_node değil: oyuncu araçlarının görünüm kaydına bağlanmaz
	rig.apply(look)
	rig.set_steer(0.0)        # düz gidiş: ön tekerler düz
	rig.set_lod_bias(CarRig.LOD_BIAS_NPC)  # trafik: alt detay kademeleri
	rig.optimize(false, true)   # gövde parçaları birleşir (çizim çağrısı); tekerler dönmek için ayrı kalır; şehir: uzak kademe
	CarShadow.attach(self, model)   # pişmiş şehir gölgesiyle aynı yönde, araçla dönen gölge
	_add_hitbox()
	_add_bubble()
	_place_at(start)
	speed = max_speed * 0.5


func _physics_process(delta: float) -> void:
	if _hazard_left > 0.0 and mode != Mode.TRAFFIC:
		_end_hazard()   # müşteri / rakip / kovalamaca oldu
	match mode:
		Mode.REPAIR_REQUESTED, Mode.RACE_CHALLENGE:
			_pull_over(delta)
			return
		Mode.CHASE:
			return   # PoliceChase konumu her karede kendisi verir (place_on_chase_path)
		Mode.TRAFFIC:
			pass
		_:
			return  # yol kenarında bekliyor / CarSpot'ta: hareket yok
	if _race_cooldown > 0.0:
		_race_cooldown = maxf(_race_cooldown - delta, 0.0)
	if target == null:
		return
	if manager and manager.can_leave_early(self, target):
		_arrive(target)   # yol ucu kenara taşındı ama araç görünmüyor: eski yerinde silinir
		return
	# Polise yol verme: sağa kay + yavaşla. Yön ve mesafe şeridin kendisinden (kaymasız konum) ölçülür,
	# yoksa direksiyon aracı hemen şerit ortasına geri çeker. Kaçan araç ise orta çizgiye kayar, zikzak çizer.
	var lane_position: Vector3
	var runner_aim: Vector3 = Vector3.INF
	var lateral_before: float = 0.0
	var pressure: float = 0.0
	var merge_aim: Vector3 = Vector3.INF
	if _merging and not fleeing:
		# Kaldırımdan çıkış: şerit çizgisinde hemen ilerideki noktaya keskin dönüş
		var lane_now: Dictionary = _lane_frame()
		var aligned: bool = absf(_forward().signed_angle_to(lane_now["dir"], Vector3.UP)) < MERGE_DONE_ANGLE
		if absf(float(lane_now["lateral"])) < MERGE_DONE and aligned:
			_merging = false
		else:
			merge_aim = (lane_now["point"] as Vector3) + (lane_now["dir"] as Vector3) * MERGE_AIM
	if fleeing:
		# Kaçak: şerit çizgisine göre gerçek yanal konum ölçülür, direksiyon orta çizgi + zikzak hedefine çevrilir
		_flee_time += delta
		var lane: Dictionary = _lane_frame()
		lane_position = lane["point"]
		_yield_shift = lane["lateral"]
		lateral_before = _yield_shift
		var pace: float = clampf(speed / max_speed, 0.0, 1.0)
		var weave: float = RUNNER_WEAVE * sin(_flee_time * RUNNER_WEAVE_RATE) \
			+ RUNNER_WEAVE2 * sin(_flee_time * RUNNER_WEAVE_RATE2 + 1.3)
		var goal: float = (-RUNNER_SHIFT + weave * pace) * clampf(speed / 0.4, 0.0, 1.0)
		runner_aim = lane_position + (lane["dir"] as Vector3) * RUNNER_AIM + (lane["right"] as Vector3) * goal
	else:
		pressure = manager.chase_pressure(self) if manager else 0.0
		var right: Vector3 = _forward().cross(Vector3.UP)
		var shift: float = move_toward(_yield_shift, YIELD_SHIFT * pressure, YIELD_SHIFT_RATE * delta)
		global_position += right * (shift - _yield_shift)
		_yield_shift = shift
		lane_position = global_position - right * _yield_shift
	var to_target: Vector3 = _flat(target.global_position - lane_position)
	var distance: float = to_target.length()

	# Kavşak girişi: geçiş izni alınmadan giriş noktası geçilmez. Giriş noktası bir sonraki nokta da olabilir
	# (yaklaşma noktası → giriş): mesafe yol boyunca ölçülür. Işık yeşil değilse izin sorgusundan önce, uzaktan
	# yavaşlar; bekleme yeri dur çizgisinin gerisi (yaya geçidi kavşakla çizgi arasında).
	var entry: TrafficWaypoint = null
	var to_entry: float = INF
	if target.intersection_entry:
		entry = target
		to_entry = distance
	elif distance < light_lookahead:
		for next: TrafficWaypoint in target.get_next():
			if next.intersection_entry:
				entry = next
				to_entry = distance + _flat(next.global_position - target.global_position).length()
				break
	var hold: bool = false
	if entry and fleeing:
		# Kırmızıya bakmaz; karşı eksen kavşağa yeni araç sokamaz (claim), kavşaktaki araç çıkınca dalar
		hold = to_entry < light_lookahead and not manager.runner_crossing(self, to_entry)
	elif entry and to_entry < lock_check_distance:
		hold = not manager.request_crossing(self)
	elif entry and to_entry < light_lookahead:
		hold = not manager.light_allows(axis)
	var blocked: bool = hold and target == entry   # giriş noktasını geçmek yalnızca hedef girişken kilitlenir

	if distance < reach_distance and not blocked:
		_arrive(target)
		if target == null:
			return
		to_target = _flat(target.global_position - lane_position)
		distance = to_target.length()

	# Küçük yön düzeltmesi (hatlar düz; ani dönüş yok). Kaçak: zikzak hedefine direksiyon (hızla ölçekli)
	var forward: Vector3 = _forward()
	var steer_to: Vector3 = to_target if runner_aim == Vector3.INF else _flat(runner_aim - global_position)
	if merge_aim != Vector3.INF:
		steer_to = _flat(merge_aim - global_position)
	var merge_error: float = 0.0
	if steer_to.length() > 0.001:
		var angle_error: float = forward.signed_angle_to(steer_to.normalized(), Vector3.UP)
		merge_error = angle_error
		var rate: float = turn_speed if runner_aim == Vector3.INF else RUNNER_TURN * clampf(speed / 0.35, 0.1, 1.0)
		if merge_aim != Vector3.INF:
			rate = MERGE_TURN
		var turn: float = clampf(angle_error, -rate * delta, rate * delta)
		if absf(turn) > 0.0001:
			rotate_y(turn)
			forward = _forward()

	# Hedef hız: hız sınırı, öndeki araç, kavşak izni
	var desired: float = max_speed
	if target.speed_limit > 0.0 and not fleeing:
		desired = minf(desired, target.speed_limit)
	var ahead: float = manager.distance_to_vehicle_ahead(self)
	if ahead < stop_distance:
		desired = 0.0
	elif ahead < follow_distance:
		desired = minf(desired, max_speed * (ahead - stop_distance) / (follow_distance - stop_distance))
	if hold:
		var stop_at: float = reach_distance + 0.3 if fleeing else _stop_point(entry)   # kaçan: çizgiye kadar dalar
		desired = minf(desired, clampf((to_entry - stop_at) * 1.2, 0.0, max_speed))
		if to_entry < stop_at + 0.02:
			desired = 0.0
	desired *= 1.0 - (1.0 - YIELD_SLOW) * pressure
	waiting_light = hold or (ahead < follow_distance and leader != null and leader.waiting_light)
	if _hazard_left > 0.0:
		if pressure > 0.0 or fleeing:
			_end_hazard()   # kovalamaca yaklaşıyor: yol açılır
		else:
			desired = 0.0
			if speed < 0.02:
				_hazard_left -= delta
				if _hazard_left <= 0.0:
					_end_hazard()
	if merge_aim != Vector3.INF:
		# Açı hedefe dönmeden ilerlemez (yerinde kırar), döndükçe yavaşça çıkar
		desired = minf(desired, MERGE_SPEED * clampf(1.0 - absf(merge_error) / 0.6, 0.1, 1.0))
	# Süper araç kalkışı: kırmızıda en önde (önü boş) duran egzotik, yeşilde zar atar
	if hold and speed < 0.03 and ahead > LAUNCH_CLEAR:
		_light_stop = true
	elif _light_stop and not hold:
		_light_stop = false
		if ahead > LAUNCH_CLEAR and not fleeing and pressure <= 0.0 and roll_launch():
			start_launch()
	if _launch_from != Vector3.INF:
		var gone: float = _flat(global_position - _launch_from).length()
		if gone > LAUNCH_DISTANCE or ahead < LAUNCH_ABORT or pressure > 0.0 or fleeing or hold \
				or (gone > 2.0 and entry != null and to_entry < light_lookahead):
			_launch_from = Vector3.INF
		else:
			desired = LAUNCH_SPEED if target.speed_limit <= 0.0 else minf(LAUNCH_SPEED, target.speed_limit)
	var rate_up: float = LAUNCH_ACCEL if _launch_from != Vector3.INF else acceleration
	var rate_down: float = HAZARD_BRAKING if _hazard_left > 0.0 else braking
	if speed > max_speed + 0.01:   # kalkıştan dönüş: önünde araç / ışık varsa sert, yoksa süzülerek
		rate_down = LAUNCH_BRAKING if ahead < follow_distance * 2.5 or hold else LAUNCH_COAST
	if desired > speed:
		speed = minf(speed + rate_up * delta, desired)
	else:
		speed = maxf(speed - rate_down * delta, desired)
	stuck_time = stuck_time + delta if speed < 0.03 and ahead < stop_distance + 0.05 and not waiting_light else 0.0

	global_position += forward * speed * delta

	# Tekerlek dönüşü (CarRig pivot sistemi); direksiyon düz kalır — kaçakta direksiyon + gövde canlılığı
	if rig and speed > 0.0:
		rig.spin_wheels(rad_to_deg(speed * delta / (WHEEL_RADIUS * model.scale.x)))
	if fleeing:
		var lateral_now: float = float(_lane_frame()["lateral"]) if target else lateral_before
		_drive_flair(-(lateral_now - lateral_before) / maxf(delta, 0.001), delta)
	elif _launch_from != Vector3.INF or absf(_flair_pitch) > 0.001:
		_drive_flair(0.0, delta)   # kalkışta gövde arkaya oturur, bitince düzelir


## DÖRTLÜ için uygun mu: trafikte, kaçmıyor / şeride çıkmıyor, kavşakta ya da kavşağa yaklaşırken değil (kavşağı
## tıkamasın), yolda ilerliyor.
func can_hazard_stop() -> bool:
	if mode != Mode.TRAFFIC or fleeing or _merging or race_lane or _hazard_left > 0.0 or _in_intersection or is_launching() \
			or target == null or target.intersection_entry or speed < 0.35:
		return false
	if _last_exit != Vector3.INF and _flat(global_position - _last_exit).length() < HAZARD_EXIT_CLEAR:
		return false
	for next: TrafficWaypoint in target.get_next():
		if next.intersection_entry:
			return false
	return true


## Dörtlüyü yakar ve `seconds` saniye durur (durduktan sonra sayılır), sonra dörtlüyü söndürüp devam eder.
func hazard_stop(seconds: float) -> bool:
	if not can_hazard_stop():
		return false
	_hazard_left = seconds
	if _hazards == null and model:
		_hazards = HazardLights.attach(model, rig, _scene_path)
	if _hazards:
		_hazards.set_on(true)
	return true


## Dörtlü yakmış ve durmuş (arkadaki araç korna çalabilir).
func is_hazard_stopped() -> bool:
	return _hazard_left > 0.0 and speed < 0.05


func hazards_on() -> bool:
	return _hazards != null and _hazards.is_on()


func _end_hazard() -> void:
	_hazard_left = 0.0
	if _hazards:
		_hazards.set_on(false)


## Bekleme yeri: aracın merkezinin giriş noktasına mesafesi. Dur çizgisi yoksa eski yer (giriş noktası). Her kavşak
## girişi için bir kez seçilir — sürücüler aynı durmaz: çoğu çizgiye fazla yanaşmaz (biraz geride), bazısı daha da
## geride, bazısı çizginin hemen gerisinde, azı yaya geçidinin üstünde (kavşağa hiç girmeden).
func _stop_point(entry: TrafficWaypoint) -> float:
	var gap: float = manager.stop_line_gap(entry) if manager else -1.0
	if gap < 0.0:
		return reach_distance
	if _stop_entry != entry:
		_stop_entry = entry
		_stop_overshoot = stop_overshoot(randf(), randf())
	return maxf(gap + _front - _stop_overshoot, reach_distance)


## Burnun dur çizgisini geçme payı (birim; − = gerisinde; araç 0,6 birim). `pick` sürücü tipi, `spread` tip içi dağılım.
static func stop_overshoot(pick: float, spread: float) -> float:
	if pick < 0.40:
		return lerpf(-0.26, -0.12, spread)   # çoğu: çizgiye yanaşmaz, rahat bir boşluk bırakır
	if pick < 0.60:
		return lerpf(-0.48, -0.30, spread)   # temkinli: daha da geride
	if pick < 0.85:
		return lerpf(-0.10, -0.03, spread)   # çizginin hemen gerisinde
	if pick < 0.97:
		return lerpf(0.04, 0.14, spread)     # yaya geçidinin üstüne taşan
	return lerpf(0.18, 0.26, spread)         # geçidin çoğunu kapatan (kavşak kenarının gerisinde)


## Kaçağın şerit çizgisi: hedef noktadan geçen, yol parçası yönünde doğru. Yön: son varılan noktadan hedefe; o
## bilinmiyorsa hedefin bir sonraki noktasına (yollar düz hatlar); o da yoksa araçtan hedefe.
func _lane_frame() -> Dictionary:
	var anchor: Vector3 = _flat(target.global_position)
	var dir: Vector3 = Vector3.ZERO
	if _segment_from != Vector3.INF:
		dir = anchor - _flat(_segment_from)
	if dir.length() < 0.05:
		var nexts: Array[TrafficWaypoint] = target.get_next()
		if not nexts.is_empty():
			dir = _flat(nexts[0].global_position) - anchor
	if dir.length() < 0.05:
		dir = anchor - _flat(global_position)
	dir = dir.normalized() if dir.length() > 0.0001 else _forward()
	var right: Vector3 = dir.cross(Vector3.UP)
	var rel: Vector3 = _flat(global_position) - anchor
	var point: Vector3 = anchor + dir * rel.dot(dir)
	return {"point": Vector3(point.x, global_position.y, point.z), "dir": dir, "right": right, "lateral": rel.dot(right)}


## Sürüş canlılığı: `left_velocity` (birim/sn, sola +) → ön teker açısı; değişimi (yanal ivme) → gövde dışa yatar;
## hız değişimi → burun kalkar / iner. Model kökünün yerel dönüşü (araç düğümünün yönü değişmez).
func _drive_flair(left_velocity: float, delta: float) -> void:
	if model == null or delta <= 0.0:
		return
	var left_accel: float = (left_velocity - _flair_left_velocity) / delta
	_flair_left_velocity = lerpf(_flair_left_velocity, left_velocity, 1.0 - exp(-14.0 * delta))
	var forward_accel: float = (speed - _flair_speed) / delta
	_flair_speed = speed
	_flair_roll = lerpf(_flair_roll, clampf(left_accel * FLAIR_ROLL, -FLAIR_ROLL_MAX, FLAIR_ROLL_MAX), 1.0 - exp(-7.0 * delta))
	_flair_pitch = lerpf(_flair_pitch, clampf(-forward_accel * FLAIR_PITCH, -FLAIR_PITCH_MAX, FLAIR_PITCH_MAX),
		1.0 - exp(-5.0 * delta))
	model.rotation = Vector3(_flair_pitch, 0.0, _flair_roll)
	if rig:
		rig.set_steer(clampf(_flair_left_velocity * FLAIR_STEER, -FLAIR_STEER_MAX, FLAIR_STEER_MAX))


func _arrive(point: TrafficWaypoint) -> void:
	_segment_from = point.global_position
	if point.intersection_entry:
		_in_intersection = true
	if point.intersection_exit:
		_last_exit = point.global_position
	if point.intersection_exit and _in_intersection:
		_in_intersection = false
		manager.finish_crossing(self)
	if point.is_despawn:
		if _in_intersection:
			manager.finish_crossing(self)
		target = null
		reached_despawn.emit(self)
		return
	target = _straightest(point) if _launch_from != Vector3.INF else point.pick_next()


## Kalkışta kavşaktan düz geçilir: yönü aracın burnuna en yakın sonraki nokta.
func _straightest(point: TrafficWaypoint) -> TrafficWaypoint:
	var best: TrafficWaypoint = null
	var best_dot: float = -2.0
	var forward: Vector3 = _forward()
	for next: TrafficWaypoint in point.get_next():
		var dir: Vector3 = _flat(next.global_position - point.global_position)
		var dot: float = forward.dot(dir.normalized()) if dir.length() > 0.001 else -1.0
		if dot > best_dot:
			best_dot = dot
			best = next
	return best


## Kalkış zarı: yalnız egzotik araç, LAUNCH_CHANCE ile.
func roll_launch() -> bool:
	return CarCatalog.is_exotic(vehicle_id) and randf() < launch_chance


## Süper araç kalkışını başlatır (yeşilde zar tutunca; test / QA doğrudan da çağırır).
func start_launch() -> void:
	_launch_from = global_position
	_flair_speed = speed
	if manager:
		manager.vehicle_launched.emit(self)


func is_launching() -> bool:
	return _launch_from != Vector3.INF


func is_in_intersection() -> bool:
	return _in_intersection


# --- Durum sorguları -----------------------------------------------------------------

## Yol kenarında tamir bekleyen (ya da yanaşmakta olan) müşteri mi?
func is_customer() -> bool:
	return mode == Mode.REPAIR_REQUESTED or mode == Mode.REPAIR_WAITING


## Bekleme noktasına yerleşmiş, oyuncuyu bekliyor mu?
func is_waiting() -> bool:
	return mode == Mode.REPAIR_WAITING


## CarSpot'ta mı (tamir / ödül bekliyor)? Trafik sayımı ve takip mesafesi dışında.
func in_bay() -> bool:
	return mode == Mode.REPAIR_BAY or mode == Mode.REPAIR_COMPLETE or mode == Mode.REWARD_WAITING


## Öndeki araç hesabına girer mi? Yol kenarında duran ve CarSpot'taki araçlar trafiği engellemez.
## Yarış rakibi de yol kenarında durduğu için trafik akışında "duran araç" sayılır.
func blocks_traffic() -> bool:
	return mode == Mode.TRAFFIC or mode == Mode.REPAIR_REQUESTED or mode == Mode.RACE_CHALLENGE


## Polise yol verirken şeridin sağına ne kadar kaydı (test / QA).
func yield_shift() -> float:
	return _yield_shift


# --- Polis kovalamacası (PoliceChase API) -----------------------------------------------

## Kovalamaca aracı yap: verilen yol çizgisinde (araç uzayında değil, dünya noktaları) sürülür. Seçilemez:
## tıklama kutusu kapatılır (hızla geçen araca dokunmak tamir / yarış plakası açmasın).
func start_chase(points: PackedVector3Array, offset: float) -> void:
	mode = Mode.CHASE
	target = null
	_chase_points = points
	_chase_lengths = PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		_chase_lengths.append(_chase_lengths[i - 1] + _flat(points[i] - points[i - 1]).length())
	chase_offset = offset
	var hitbox: StaticBody3D = get_node_or_null("CarHitbox") as StaticBody3D
	if hitbox:
		hitbox.input_ray_pickable = false
		for shape: Node in hitbox.get_children():
			if shape is CollisionShape3D:
				(shape as CollisionShape3D).disabled = true
	place_on_chase_path(0.0)


## Kovalamaca yolunda `distance`'taki yerel çerçeve: orta çizgi noktası (chase_offset kaymalı), ileri ve sol yön.
func chase_frame(distance: float) -> Dictionary:
	if _chase_points.size() < 2:
		return {}
	var i: int = 1
	while i < _chase_points.size() - 1 and _chase_lengths[i] < distance:
		i += 1
	var a: Vector3 = _chase_points[i - 1]
	var b: Vector3 = _chase_points[i]
	var segment: float = maxf(_chase_lengths[i] - _chase_lengths[i - 1], 0.0001)
	var t: float = clampf((distance - _chase_lengths[i - 1]) / segment, 0.0, 1.0)
	var along: Vector3 = _flat(b - a).normalized()
	var left: Vector3 = Vector3.UP.cross(along)
	return {"point": _flat(a.lerp(b, t)) + left * chase_offset, "along": along, "left": left}


## Kovalamaca yolunun toplam uzunluğu.
func chase_length() -> float:
	return _chase_lengths[_chase_lengths.size() - 1] if not _chase_lengths.is_empty() else 0.0


## Yol çizgisinde verilen noktaya yerleş (orta çizgiye kaymayla), hareket yönüne dön, tekerleri döndür.
## `weave`: o anki ek yan sapma (şüphelinin zikzakı).
func place_on_chase_path(distance: float, weave: float = 0.0) -> void:
	if _chase_points.size() < 2:
		return
	var travelled: float = distance - chase_distance
	chase_distance = distance
	var i: int = 1
	while i < _chase_points.size() - 1 and _chase_lengths[i] < distance:
		i += 1
	var a: Vector3 = _chase_points[i - 1]
	var b: Vector3 = _chase_points[i]
	var segment: float = maxf(_chase_lengths[i] - _chase_lengths[i - 1], 0.0001)
	var t: float = clampf((distance - _chase_lengths[i - 1]) / segment, 0.0, 1.0)
	var along: Vector3 = _flat(b - a).normalized()
	var left: Vector3 = Vector3.UP.cross(along)
	var previous: Vector3 = global_position
	var at: Vector3 = a.lerp(b, t) + left * (chase_offset + weave)
	global_position = Vector3(at.x, global_position.y, at.z)
	var moved: Vector3 = _flat(global_position - previous)
	var delta: float = maxf(get_physics_process_delta_time(), 0.001)
	var left_velocity: float = (weave - _last_weave) / delta
	_last_weave = weave
	# Savrulurken arka kayar: yön, hareket yönünden yan hızla biraz daha içe döner (drift görüntüsü)
	var facing: Vector3 = moved if moved.length() > 0.002 else along
	_face(facing.rotated(Vector3.UP, clampf(left_velocity * CHASE_SLIP, -0.12, 0.12)))
	speed = absf(travelled) / delta
	_drive_flair(left_velocity, delta)
	if rig and travelled > 0.0:
		rig.spin_wheels(rad_to_deg(travelled / (WHEEL_RADIUS * model.scale.x)))


## Kovalamaca aracı mı?
func is_chasing() -> bool:
	return mode == Mode.CHASE


func bubble_visible() -> bool:
	return _bubble != null and _bubble.visible


## Hedeflenen / durulan yol kenarı bekleme noktası (müşteri değilse null).
## Kaldırımdan şeride çıkıyor mu (give_up sonrası): kipi TRAFFIC olsa da araç hâlâ kaldırımdadır.
func is_merging() -> bool:
	return _merging


func wait_spot() -> Node3D:
	return _spot


# --- Yarış daveti (RaceManager API) -----------------------------------------------------

## Yoldan gelen rakip: verilen noktaya yanaşır, garaja dönük durur ve 🏁 balonunu açar.
## Tamir durumu (fault / repair_status) DEĞİŞMEZ: araç tamir müşterisi değildir.
func request_race_challenge(spot: Node3D) -> void:
	_yield_shift = 0.0
	_spot = spot
	target = null
	_arrived = false
	# Davet kavşağın içinde açılırsa kilit BIRAKILMALI, yoksa diğer eksen sonsuza kadar bekler
	# (enter_bay ile aynı koruma).
	if _in_intersection:
		_in_intersection = false
		if manager:
			manager.finish_crossing(self)
	mode = Mode.RACE_CHALLENGE
	if race_avatar:
		_bubble.show_avatar(race_avatar, race_avatar_illustrated)   # arkadaşın fotoğrafı + damalı bayrak
	else:
		_bubble.show_glyph(CarBubble.GLYPH_FLAG)   # isimsiz rakip: yalnızca damalı bayrak, yazı yok
	_sync_bubble_shape()


## Yarış bitti / vazgeçildi: balon kapanır, araç normal trafiğe döner (aynı yerden devam eder).
func end_race_challenge() -> void:
	if mode != Mode.RACE_CHALLENGE:
		return
	_bubble.hide_bubble()
	_sync_bubble_shape()
	_spot = null
	_arrived = false
	mode = Mode.TRAFFIC
	speed = 0.0
	_race_cooldown = RACE_REJOIN_TIME
	_segment_from = Vector3.INF   # yanaşılan yerden: şerit yönü hedefin sonraki noktasından
	target = manager.nearest_waypoint_ahead(self) if manager else null


## Yarış daveti veren rakip mi (RaceManager / HUD sorar)?
func is_challenger() -> bool:
	return mode == Mode.RACE_CHALLENGE


## Yarıştan yeni çıktı mı ya da kaçıyor mu? (RepairManager bu araca müşteri rolü vermez.)
func busy_after_race() -> bool:
	return _race_cooldown > 0.0 or fleeing


## YARIŞI KAYBETTİ: trafiğe kaçarak döner (RaceManager, oyuncu dünyaya dönünce çağırır). Bkz. RUNNER_*.
func flee() -> void:
	if mode != Mode.TRAFFIC:
		return
	fleeing = true
	_flee_time = 0.0
	max_speed = RUNNER_SPEED
	acceleration = RUNNER_ACCEL
	braking = RUNNER_BRAKING
	if manager:
		manager.runner_started(self)


# --- Tamir döngüsü (RepairManager API) --------------------------------------------------

## Tamir ihtiyacı: waypoint takibinden çık, verilen yol kenarı noktasına yanaş, 🔧 balonu aç;
## tamire alınana kadar orada bekler.
func request_repair(spot: Node3D, job: RepairType, severity: float = 1.0) -> void:
	_yield_shift = 0.0
	_spot = spot
	target = null
	_arrived = false
	fault = job
	fault_severity = severity
	repair_status = RepairStatus.DAMAGED
	mode = Mode.REPAIR_REQUESTED
	_patience_shown = -1
	_bubble.show_wrench()   # araç üstünde yazı yok: arıza HUD plakasında (araca tıklayınca) görünür
	_sync_bubble_shape()


## Yanaşmayı beklemeden bekleme noktasına IŞINLANIR ve bekleyen müşteri olur (eğitimin ilk müşterisi: oyuncu
## aracın yoldan gelmesini beklemesin). Tamire alırken enter_bay de böyle ışınlar; efekt yok.
func arrive_now() -> void:
	if mode != Mode.REPAIR_REQUESTED or _spot == null:
		return
	global_position = Vector3(_spot.global_position.x, global_position.y, _spot.global_position.z)
	global_rotation.y = _spot.global_rotation.y
	speed = 0.0
	if _in_intersection:
		_in_intersection = false
		manager.finish_crossing(self)
	_arrived = true
	mode = Mode.REPAIR_WAITING
	customer_stopped.emit(self)


## Sabrı azalan müşteri: balonda geri sayım ("0:15"); `seconds` < 0 ise yalnızca anahtar (eski görünüm).
func show_patience(seconds: int) -> void:
	if seconds == _patience_shown or mode != Mode.REPAIR_WAITING:
		return
	_patience_shown = seconds
	if seconds < 0:
		_bubble.show_wrench()
	else:
		_bubble.show_text("%d:%02d" % [seconds / 60, seconds % 60], CarBubble.GLYPH_WRENCH)
	_sync_bubble_shape()


## BEKLEMEKTEN SIKILDI: balon kapanır, arıza sıfırlanır, kaldırımdan çıkıp trafiğe döner (bir süre yeniden
## müşteri seçilmez — aynı kaldırımda hemen geri yanaşmasın).
func give_up() -> void:
	if not is_customer():
		return
	_bubble.hide_bubble()
	_sync_bubble_shape()
	_spot = null
	_arrived = false
	fault = null
	fault_severity = 1.0
	repair_status = RepairStatus.NORMAL
	mode = Mode.TRAFFIC
	speed = 0.0
	_patience_shown = -1
	_race_cooldown = RACE_REJOIN_TIME * 2.0
	_segment_from = Vector3.INF
	target = manager.nearest_waypoint_ahead(self) if manager else null
	# Şerit çizgisi hedefin ÖNCEKİ noktasından: hedef yolun ucundaysa (sonrası yok) yön araçtan hedefe eğik çizilir,
	# araç o çizginin üstünde sayılır ve çıkış ilk karede "bitti" sanılırdı (öndekilerin içinden geçiyordu)
	var previous: TrafficWaypoint = manager.previous_waypoint(target) if manager and target else null
	if previous:
		_segment_from = previous.global_position
	_merging = target != null   # önce şeride çıkar (öndeki bekleyenlerin içinden geçmesin)


## "TAMİRE AL": anında CarSpot'a ışınlan (konum + yön), tamir başlar; "TAMİR" plakası.
func enter_bay(bay_position: Vector3, bay_yaw: float) -> void:
	global_position = Vector3(bay_position.x, global_position.y, bay_position.z)
	global_rotation.y = bay_yaw
	speed = 0.0
	target = null
	_spot = null
	if _in_intersection:
		_in_intersection = false
		manager.finish_crossing(self)
	repair_status = RepairStatus.REPAIRING
	mode = Mode.REPAIR_BAY
	_bubble.show_text(Loc.t("TAMİR"), CarBubble.GLYPH_WRENCH)
	_sync_bubble_shape()


## Sayaç bitti: tamir edilmiş; ödül balonu (₺ + tutar). Araç CarSpot'ta kalır.
func finish_repair(reward: int) -> void:
	repair_status = RepairStatus.REPAIRED
	mode = Mode.REPAIR_COMPLETE
	_bubble.show_text("+%d ₺" % reward, CarBubble.GLYPH_COIN)
	_sync_bubble_shape()


## Ödül toplanana kadar CarSpot'ta bekle.
func await_reward() -> void:
	mode = Mode.REWARD_WAITING


## Para toplandı: verilen yol spawn noktasına ışınlan, balonu kapat, ARIZAYI SIFIRLA (araç yeniden
## sağlam; ileride tekrar müşteri olabilir) ve waypoint zincirinden devam et.
func return_to_traffic(point: TrafficWaypoint) -> void:
	_bubble.hide_bubble()
	_sync_bubble_shape()
	_spot = null
	fault = null
	fault_severity = 1.0
	repair_status = RepairStatus.NORMAL
	mode = Mode.TRAFFIC
	if point == null:
		target = null
		reached_despawn.emit(self)
		return
	_place_at(point)
	_yield_shift = 0.0
	if manager:
		var start: Vector3 = manager.hidden_start(point)
		if manager.is_clear(start):
			global_position = Vector3(start.x, global_position.y, start.z)
	speed = max_speed * 0.5


## Bekleme noktasına yanaşma: noktaya yönel, yaklaşınca yavaşla; varınca yerinde nokta yönüne dön.
func _pull_over(delta: float) -> void:
	var center: Vector3 = _flat(_spot.global_position)
	if _arrived:
		if _settle(center, _spot.global_rotation.y, delta):
			speed = 0.0
			# Yarış rakibi yerine oturunca KİPİ DEĞİŞMEZ: RACE_CHALLENGE olarak bekler.
			# (Tamir müşterisi burada REPAIR_WAITING'e geçer ve customer_stopped yayar.)
			if mode == Mode.REPAIR_REQUESTED:
				mode = Mode.REPAIR_WAITING
				customer_stopped.emit(self)
		return
	var to_goal: Vector3 = center - _flat(global_position)
	var distance: float = to_goal.length()
	var forward: Vector3 = _forward()
	if distance > 0.01:
		var angle_error: float = forward.signed_angle_to(to_goal.normalized(), Vector3.UP)
		var rate: float = PULL_OVER_TURN if distance > 0.15 else 6.0
		rotate_y(clampf(angle_error, -rate * delta, rate * delta))
		forward = _forward()
	var desired: float = minf(PULL_OVER_SPEED, maxf(distance * 1.2, 0.06))
	var ahead: float = manager.distance_to_vehicle_ahead(self)
	if ahead < stop_distance:
		desired = 0.0
	elif ahead < follow_distance:
		desired = minf(desired, max_speed * (ahead - stop_distance) / (follow_distance - stop_distance))
	if desired > speed:
		speed = minf(speed + acceleration * delta, desired)
	else:
		speed = maxf(speed - braking * delta, desired)
	global_position += forward * speed * delta
	if rig and speed > 0.0:
		rig.spin_wheels(rad_to_deg(speed * delta / (WHEEL_RADIUS * model.scale.x)))
	if distance < PULL_OVER_REACH:
		_arrived = true
		speed = 0.0


## Yerinde park: merkeze kay, hedef yöne dön; ikisi de tamamlanınca true.
func _settle(center: Vector3, goal_yaw: float, delta: float) -> bool:
	var here: Vector3 = _flat(global_position)
	var moved: Vector3 = here.move_toward(center, 0.12 * delta)
	global_position = Vector3(moved.x, global_position.y, moved.z)
	var diff: float = wrapf(goal_yaw - global_rotation.y, -PI, PI)
	var step: float = PARK_TURN_SPEED * delta
	if absf(diff) > step:
		global_rotation.y += signf(diff) * step
		return false
	global_rotation.y = goal_yaw
	return moved.distance_to(center) <= 0.001


## Verilen waypoint'e yerleş ve zincirin devamına yönel (spawn ve yola dönüş).
func _place_at(point: TrafficWaypoint) -> void:
	global_position = point.global_position
	_segment_from = point.global_position
	_in_intersection = false
	target = point.pick_next()
	if target:
		var dir: Vector3 = _flat(target.global_position - global_position)
		_face(dir)
		axis = 0 if absf(dir.x) >= absf(dir.z) else 1


# --- Seçim / balon -------------------------------------------------------------------

## Park halindeki araçlarla aynı yapı: CarHitbox (car_hitbox.gd + BoxShape) ve SelectionRing.
## Kutu, modelin ölçekli sınırlarından hesaplanır; zemin göstergesi car_hitbox.gd'de kurulur.
func _add_hitbox() -> void:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var b: AABB = model.transform * ((n as Node3D).transform * (n as MeshInstance3D).get_aabb())
			box = b if first else box.merge(b)
			first = false
		for c: Node in n.get_children():
			stack.append(c)
	if first:
		box = AABB(Vector3(-0.15, 0.0, -0.3), Vector3(0.3, 0.25, 0.6))
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "SelectionRing"
	ring.position = Vector3(0.0, box.size.y, 0.0)
	ring.visible = false
	add_child(ring)  # car_hitbox.gd _ready'de bunu arar; hitbox'tan önce eklenmeli
	var hitbox: StaticBody3D = StaticBody3D.new()
	hitbox.name = "CarHitbox"
	hitbox.set_script(CarHitboxScript)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	_front = clampf(box.end.z, 0.12, 0.6)   # model önü +Z
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	shape.position = box.get_center()
	hitbox.add_child(shape)
	add_child(hitbox)


## World-space balon: tavanın üstünde, kameraya dönük plaka (CarBubble). Gizli başlar; yalnızca tamir
## durumlarında açılır (normal trafikte asla). Balon görünürken CarHitbox'a balon boyutunda ikinci bir
## kutu eklenir: balona tıklamak da aracı seçer (car_hitbox.gd değişmeden).
func _add_bubble() -> void:
	var roof: float = 0.3
	var hitbox: StaticBody3D = get_node_or_null("CarHitbox")
	if hitbox:
		var shape: CollisionShape3D = hitbox.get_node_or_null("CollisionShape3D")
		if shape and shape.shape is BoxShape3D:
			roof = shape.position.y + (shape.shape as BoxShape3D).size.y * 0.5
	_bubble = CarBubble.new()
	_bubble.position = Vector3(0.0, roof + BUBBLE_GAP + CarBubble.HEIGHT * 0.5, 0.0)
	add_child(_bubble)
	if hitbox:
		_bubble_shape = CollisionShape3D.new()
		_bubble_shape.name = "BubbleShape"
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(CarBubble.WIDTH_ICON, CarBubble.HEIGHT + 0.04, BUBBLE_PICK_DEPTH)
		_bubble_shape.shape = box
		_bubble_shape.position = _bubble.position
		_bubble_shape.disabled = true
		hitbox.add_child(_bubble_shape)


## Balon tıklama kutusu yalnızca balon görünürken etkin; kutu plakanın o anki genişliğini alır.
func _sync_bubble_shape() -> void:
	if _bubble_shape == null:
		return
	_bubble_shape.disabled = not _bubble.visible
	var plate: Vector2 = _bubble.plate_size()
	(_bubble_shape.shape as BoxShape3D).size = Vector3(plate.x, plate.y + 0.04, BUBBLE_PICK_DEPTH)


func _exit_tree() -> void:
	# Despawn olan araç seçiliyse seçimi bırak (galeri/garaj serbest bırakılmış node okumasın)
	if CarHitboxScript.selected_car == self:
		CarHitboxScript.clear_selection(get_tree())


func _forward() -> Vector3:
	return _flat(global_transform.basis.z).normalized()  # model önü +Z


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	global_transform.basis = Basis.looking_at(-direction.normalized(), Vector3.UP)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
