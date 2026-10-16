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

@export var max_speed: float = 0.8        # birim/sn
@export var acceleration: float = 0.6     # birim/sn²
@export var braking: float = 1.4          # birim/sn²
@export var turn_speed: float = 2.4       # rad/sn (küçük yön düzeltmeleri)
@export var reach_distance: float = 0.14  # waypoint'e "vardı" sayılan mesafe
@export var follow_distance: float = 1.3  # öndeki araca bu mesafede yavaşla
@export var stop_distance: float = 0.72   # bu mesafede dur (araç boyu ~0.6)
@export var lock_check_distance: float = 0.9  # kavşak geçiş izni bu mesafeden itibaren sorgulanır

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
## Müşterinin arızası (request_repair ile atanır; trafiğe dönünce null olur). Müşteri değilken null.
var fault: RepairType
## Arıza şiddeti (RepairType.severity_min..max arası); ilk sürümde yalnızca veri, süreyi etkilemez.
var fault_severity: float = 1.0
## Görünüm (boya / jant); dil değişiminde tamirdeki araç aynı renkle yeniden kurulsun diye tutulur.
var appearance: CarAppearance
var _bubble: CarBubble
var _bubble_shape: CollisionShape3D  # CarHitbox altında: balon görünürken balona tıklamak da aracı seçer
var _in_intersection: bool = false
var _spot: Node3D                 # yol kenarı bekleme noktası (REPAIR_REQUESTED / REPAIR_WAITING)
var _arrived: bool = false        # bekleme noktasına vardı, yerinde yerleşiyor
## Yarıştan sonra araç bir süre müşteri olarak seçilmez: yol kenarından kalkıp akışa karışsın
## (yoksa RaceManager onu bıraktığı anda RepairManager aynı kaldırımda müşteri yapıyor).
var _race_cooldown: float = 0.0
var _yield_shift: float = 0.0     # polise yol verirken şeridin sağına kayma (TRAFFIC kipinde)
## --- Kovalamaca (CHASE): yol çizgisi, üzerindeki konum ve orta çizgiye kayma ---
var _chase_points: PackedVector3Array = PackedVector3Array()
var _chase_lengths: PackedFloat32Array = PackedFloat32Array()   # her noktaya kadarki toplam uzunluk
var chase_distance: float = 0.0   # yol çizgisi üzerindeki konum (PoliceChase sürer)
var chase_offset: float = 0.0     # sola (orta çizgiye) kayma


func setup(traffic_manager: TrafficManager, scene: PackedScene, look: CarAppearance, start: TrafficWaypoint, model_scale: float) -> void:
	manager = traffic_manager
	appearance = look
	model = scene.instantiate() as Node3D
	# Bağlam çarpanı × aracın GERÇEK boyutundan türeyen ölçek: Getz gerçekten küçük, E60 gerçekten
	# uzun görünür (CarCatalog.model_scale; cars.json "real_dimensions"dan türetilmiştir).
	model.scale = Vector3.ONE * model_scale * CarCatalog.model_scale(vehicle_id)
	add_child(model)
	rig = CarRig.new(model)   # for_node değil: oyuncu araçlarının görünüm kaydına bağlanmaz
	rig.apply(look)
	rig.set_steer(0.0)        # düz gidiş: ön tekerler düz
	rig.set_lod_bias(CarRig.LOD_BIAS_NPC)  # trafik: alt detay kademeleri
	rig.optimize(false)   # gövde parçaları birleşir (çizim çağrısı); tekerler dönmek için ayrı kalır
	_add_hitbox()
	_add_bubble()
	_place_at(start)
	speed = max_speed * 0.5


func _physics_process(delta: float) -> void:
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
	# yoksa direksiyon aracı hemen şerit ortasına geri çeker.
	var pressure: float = manager.chase_pressure(self) if manager else 0.0
	var right: Vector3 = _forward().cross(Vector3.UP)
	var shift: float = move_toward(_yield_shift, YIELD_SHIFT * pressure, YIELD_SHIFT_RATE * delta)
	global_position += right * (shift - _yield_shift)
	_yield_shift = shift
	var lane_position: Vector3 = global_position - right * _yield_shift
	var to_target: Vector3 = _flat(target.global_position - lane_position)
	var distance: float = to_target.length()

	# Kavşak girişi: geçiş izni alınmadan giriş noktası geçilmez
	var blocked: bool = target.intersection_entry and distance < lock_check_distance and not manager.request_crossing(self)

	if distance < reach_distance and not blocked:
		_arrive(target)
		if target == null:
			return
		to_target = _flat(target.global_position - lane_position)
		distance = to_target.length()

	# Küçük yön düzeltmesi (hatlar düz; ani dönüş yok)
	var forward: Vector3 = _forward()
	if distance > 0.001:
		var angle_error: float = forward.signed_angle_to(to_target.normalized(), Vector3.UP)
		var turn: float = clampf(angle_error, -turn_speed * delta, turn_speed * delta)
		if absf(turn) > 0.0001:
			rotate_y(turn)
			forward = _forward()

	# Hedef hız: hız sınırı, öndeki araç, kavşak izni
	var desired: float = max_speed
	if target.speed_limit > 0.0:
		desired = minf(desired, target.speed_limit)
	var ahead: float = manager.distance_to_vehicle_ahead(self)
	if ahead < stop_distance:
		desired = 0.0
	elif ahead < follow_distance:
		desired = minf(desired, max_speed * (ahead - stop_distance) / (follow_distance - stop_distance))
	if blocked:
		desired = minf(desired, clampf((distance - reach_distance) * 1.2, 0.0, max_speed))
		if distance < reach_distance + 0.02:
			desired = 0.0
	desired *= 1.0 - (1.0 - YIELD_SLOW) * pressure
	if desired > speed:
		speed = minf(speed + acceleration * delta, desired)
	else:
		speed = maxf(speed - braking * delta, desired)

	global_position += forward * speed * delta

	# Tekerlek dönüşü (CarRig pivot sistemi); direksiyon düz kalır
	if rig and speed > 0.0:
		rig.spin_wheels(rad_to_deg(speed * delta / (WHEEL_RADIUS * model.scale.x)))


func _arrive(point: TrafficWaypoint) -> void:
	if point.intersection_entry:
		_in_intersection = true
	if point.intersection_exit and _in_intersection:
		_in_intersection = false
		manager.finish_crossing(self)
	if point.is_despawn:
		if _in_intersection:
			manager.finish_crossing(self)
		target = null
		reached_despawn.emit(self)
		return
	target = point.pick_next()


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
	_face(moved if moved.length() > 0.002 else along)
	speed = absf(travelled) / maxf(get_physics_process_delta_time(), 0.001)
	if rig and travelled > 0.0:
		rig.spin_wheels(rad_to_deg(travelled / (WHEEL_RADIUS * model.scale.x)))


## Kovalamaca aracı mı?
func is_chasing() -> bool:
	return mode == Mode.CHASE


func bubble_visible() -> bool:
	return _bubble != null and _bubble.visible


## Hedeflenen / durulan yol kenarı bekleme noktası (müşteri değilse null).
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
	_bubble.show_glyph(CarBubble.GLYPH_FLAG)   # yalnızca damalı bayrak, yazı yok
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
	target = manager.nearest_waypoint_ahead(self) if manager else null


## Yarış daveti veren rakip mi (RaceManager / HUD sorar)?
func is_challenger() -> bool:
	return mode == Mode.RACE_CHALLENGE


## Yarıştan yeni çıktı mı? (RepairManager bu araca müşteri rolü vermez.)
func busy_after_race() -> bool:
	return _race_cooldown > 0.0


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
	_bubble.show_wrench()   # araç üstünde yazı yok: arıza HUD plakasında (araca tıklayınca) görünür
	_sync_bubble_shape()


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
