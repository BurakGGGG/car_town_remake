class_name TrafficPolice
extends Node
## TRAFİK POLİSİ — şehirde trafik KİLİTLENİNCE yolu açar (kullanıcı fikri, 2026-10-26: telefonda garajın önünde kuyruk
## kalıcı olarak durdu). Kilit: iki ya da daha çok araç birbirini "önümde" sayıp sonsuza dek bekler — ör. bekleyen
## müşteri sıkılıp kaldırımdan şeride çıkarken şeritte gelen araçla burun buruna gelir; ikisi de öbürünü bekler,
## arkalarındaki kuyruk da onları (TrafficManager.find_deadlock).
##
## Sahne: tepe lambaları çakan bir polis KARŞI ŞERİTTEN siren çalarak gelir, kilidin tam önünde (en öndeki aracın
## hizasında, karşı şeritte) durur; siren biraz daha çalıp susar, polis bir kez kalın kornasıyla "DAT DAT" yapar
## (PoliceSiren.blast; kullanıcı isteği) ve hemen ardından kilidin EN ÖNDEKİ aracını geçirir (o araç birkaç saniye
## kilitteki öbür araçları engel saymaz — TrafficVehicle.wave_through), arkadakiler onu izler. Kuyruk açılınca polis
## yoluna devam eder (lambalar çakarak), ekran dışında kaybolur. Polis durduğu sürece kendi şeridindeki araçlar onun
## arkasında bekler (TrafficManager.distance_to_vehicle_ahead engel sayar).
##
## Polis araçları PoliceChase'inkiler (oyuncu edinemez); model arka planda yüklenir, sürüş kovalamacanın yol çizgisi
## kipiyle (TrafficVehicle.Mode.CHASE, place_on_chase_path) — trafik listesine girmez, müşteri / rakip olmaz.
## Kovalamaca sürerken müdahale başlamaz (aynı polis modeli iki kez çıkmasın); müdahale sürerken kovalamaca beklenir.
## TrafficManager'ın çocuğu olarak kodla kurulur.

signal intervened(head: TrafficVehicle)   ## polis kilidin önünde durdu ve en öndeki aracı geçirdi
signal horn_blasted                       ## "dat dat" çaldı (geçirmeden hemen önce)
signal finished                           ## polis ekrandan çıktı (ya da müdahale iptal oldu)

enum Phase { IDLE, LOADING, APPROACH, STOPPED, CLEARING, LEAVE }
## Durunca: siren biraz daha çalar → susar, kısa sessizlik → "dat dat" → geçirir.
enum Stop { SIREN, PAUSE, HORN }

## Kilit bu sıklıkla aranır (sn). Kilitteki araç en az JAM_TIME sn önündeki yüzünden durmuş olmalı (dörtlü yakan
## araç 3–5 sn, sıkılan müşterinin kaldırımdan çıkışı ~2,3 sn: bunlar kilit sayılmaz).
const CHECK_EVERY: float = 1.0
const JAM_TIME: float = 6.0
## Bir müdahale bitince yenisi en erken bu kadar sonra (sn); polis gelemediyse (rota yok, doğma yeri dolu) yeniden
## deneme aralığı.
const COOLDOWN: float = 15.0
const RETRY: float = 8.0
## Polisin doğma yeri (karşı şeridin haritanın dışındaki ucu) doluysa boşalmasını en çok bu kadar bekler (sn).
const SPAWN_WAIT: float = 12.0
## Doğma yeri dolu sayılır: polisin şeridinde (yanal SPAWN_LANE içinde) SPAWN_GAP'ten yakın araç varsa.
const SPAWN_GAP: float = 1.2
const SPAWN_LANE: float = 0.4
## Sürüş (birim/sn, birim/sn²). Normal trafik 0,55–0,9: polis acele eder ama kovalamaca (2,35) kadar değil.
const APPROACH_SPEED: float = 1.35
const LEAVE_SPEED: float = 1.1
const ACCEL: float = 1.3
const BRAKE: float = 1.2
## Durma yeri: en öndeki aracın merkezinden yol yönünde bu kadar ileri (polis burnu kilidin başını geçmiş durur).
const STOP_AHEAD: float = 0.2
## Karşı şeridin ortasından yol ortasına doğru kayma: kilide yakın, yine de karşı şeritte durur.
const LANE_SHIFT: float = 0.08
## Karşı şeridin çizgisi durma yerine en çok bu kadar uzak olabilir (iki şeridin arası 0,6; kaldırımdan çıkan
## müşteri kendi şeridinin ~0,4 sağında).
const MATCH_DISTANCE: float = 1.2
## Rota denemesi: kavşaklarda dallanan zincirden rastgele rota; her doğma noktası için bu kadar deneme.
const ROUTE_TRIES: int = 6
## Durduktan sonra siren bu kadar daha çalar; susunca HORN_PAUSE sonra "dat dat"; korna bitince RELEASE_AFTER_HORN
## sonra en öndeki geçer. Aynı müdahalede sıradaki araç kornasız NEXT_RELEASE sonra geçirilir (korna bir kez).
const SIREN_ON_STOP: float = 1.2
const HORN_PAUSE: float = 0.35
const RELEASE_AFTER_HORN: float = 0.2
const NEXT_RELEASE: float = 1.0
## Geçirilen araç bu kadar sn kilitteki araçları engel saymaz.
const WAVE_SECONDS: float = 4.0
## Geçirdikten sonra en az bu kadar, kuyruk açılmazsa en çok CLEAR_MAX bekler; kilit sürüyorsa sıradakini geçirir.
const CLEAR_WAIT: float = 2.5
const CLEAR_MAX: float = 10.0
const MAX_RELEASES: int = 4
## Karşı şeritte öndeki araca bu mesafede durur (kuyrukta beklerken).
const FOLLOW_GAP: float = 0.85
## Yaklaşırken önündeki bir engel yüzünden bu kadar sn durursa olduğu yerde "vardı" sayılır.
const BLOCKED_ARRIVE: float = 2.5
## Emniyet: müdahale bu kadar sn'den uzun sürerse polis kaldırılır.
const MAX_DURATION: float = 70.0
## Polis kavşak girişine bu kadar kala karşı eksenden kavşakta araç varsa bekler.
const CROSS_LOOK: float = 0.6

var _manager: TrafficManager
var _siren: PoliceSiren
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _phase: Phase = Phase.IDLE
var _check: float = CHECK_EVERY
var _cooldown: float = 0.0
var _police_id: StringName = &""
var _loading: String = ""
var _police_scene: PackedScene
var _siren_task: int = -1
var _siren_kind: PoliceSiren.Kind = PoliceSiren.Kind.WAIL
var _siren_result: AudioStreamWAV
var _horn_result: AudioStreamWAV
var _stop: Stop = Stop.SIREN
var _police: TrafficVehicle
## Kilit: halkadaki araçlar ve en öndeki (geçirilecek) araç.
var _members: Array[TrafficVehicle] = []
var _head: TrafficVehicle
## Polisin rotası (yol çizgisi), her noktanın waypoint'i (doğma yeri için null), durma mesafesi.
var _route: Dictionary = {}
var _distance: float = 0.0
var _speed: float = 0.0
var _stop_at: float = 0.0
var _core_end: float = 0.0
var _timer: float = 0.0
var _elapsed: float = 0.0
var _blocked_for: float = 0.0
var _releases: int = 0


func _ready() -> void:
	name = "TrafficPolice"
	_manager = get_parent() as TrafficManager
	_rng.randomize()
	_siren = PoliceSiren.new()
	add_child(_siren)


func _physics_process(delta: float) -> void:
	_collect_siren(false)
	match _phase:
		Phase.IDLE:
			_cooldown = maxf(_cooldown - delta, 0.0)
			_check -= delta
			if _check <= 0.0:
				_check = CHECK_EVERY
				if _cooldown <= 0.0:
					_look_for_jam()
		Phase.LOADING:
			_elapsed += delta
			_poll_loading()
		_:
			_elapsed += delta
			if _elapsed > MAX_DURATION or not is_instance_valid(_police):
				_finish()
				return
			_drive(delta)


## Müdahale sürüyor mu (yükleme dahil)? PoliceChase bu sırada başlamaz.
func is_busy() -> bool:
	return _phase != Phase.IDLE


func phase() -> Phase:
	return _phase


## Sahnedeki polis aracı (yoksa null).
func police() -> TrafficVehicle:
	return _police if is_instance_valid(_police) else null


## Trafiğin engel sayacağı polis: yoldaysa (yaklaşırken de: arkasından gelen araç içinden geçmesin).
func obstacle() -> TrafficVehicle:
	return _police if is_instance_valid(_police) and _phase != Phase.LOADING else null


## Müdahalenin geçirdiği / geçireceği araç (QA / test).
func head() -> TrafficVehicle:
	return _head if is_instance_valid(_head) else null


func siren_playing() -> bool:
	return _siren.is_playing()


## Polis kavşaktan geçerken karşı eksen kavşağa yeni araç sokmaz (kovalamacadaki gibi).
func holds_crossing(axis: int) -> bool:
	if not is_instance_valid(_police) or (_phase != Phase.APPROACH and _phase != Phase.LEAVE):
		return false
	return axis != _axis()


## Polisin o anki ekseni (0 = X, 1 = Z): rota kavşakta dönebilir, doğuştaki eksen yetmez.
func _axis() -> int:
	var forward: Vector3 = _police.global_transform.basis.z
	return 0 if absf(forward.x) >= absf(forward.z) else 1


## Şimdi bir kilit ara ve varsa müdahaleye başla (QA / test; normalde saniyede bir kendiliğinden).
func check_now() -> bool:
	if _phase != Phase.IDLE:
		return false
	_look_for_jam()
	return _phase != Phase.IDLE


func _look_for_jam() -> void:
	if _manager == null or (_manager.chase and _manager.chase.is_active()):
		return
	var ring: Array[TrafficVehicle] = _manager.find_deadlock(JAM_TIME)
	if ring.is_empty():
		return
	_members = ring
	_head = front_most(ring)
	_releases = 0
	_elapsed = 0.0
	print("TrafficPolice: kilit — %s; en öndeki %s" % [_describe(ring), _head.vehicle_id])
	_police_id = PoliceChase.POLICE_IDS[_rng.randi() % PoliceChase.POLICE_IDS.size()]
	var path: String = CarCatalog.scene_path(_police_id)
	if path == "" or ResourceLoader.load_threaded_request(path) != OK:
		_reset()
		_cooldown = RETRY
		return
	_loading = path
	_siren_kind = PoliceSiren.kind_for(_police_id)
	if _siren_task < 0 and not (PoliceSiren.has_stream(_siren_kind) and PoliceSiren.has_stream(PoliceSiren.Kind.HORN)):
		_siren_task = WorkerThreadPool.add_task(_build_siren.bind(_siren_kind), false, "trafik polisi sireni")
	_phase = Phase.LOADING


## Halkanın en öndeki aracı: araçların ortalama yol yönünde en ilerde olan (kuyruğun başı).
static func front_most(ring: Array[TrafficVehicle]) -> TrafficVehicle:
	var heading: Vector3 = Vector3.ZERO
	for vehicle: TrafficVehicle in ring:
		heading += vehicle.lane_direction()
	if heading.length() < 0.001:
		return ring[0]
	heading = heading.normalized()
	var best: TrafficVehicle = ring[0]
	for vehicle: TrafficVehicle in ring:
		if vehicle.global_position.dot(heading) > best.global_position.dot(heading):
			best = vehicle
	return best


## Model yüklenince rota bulunur; polis doğma yeri boşalınca doğar (dolu kaldıkça her karede yeniden bakılır).
func _poll_loading() -> void:
	if _loading != "":
		match ResourceLoader.load_threaded_get_status(_loading):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return
			ResourceLoader.THREAD_LOAD_LOADED:
				_police_scene = ResourceLoader.load_threaded_get(_loading) as PackedScene
		_loading = ""
	if _police_scene == null or not _valid_jam():
		_reset()
		return
	if _route.is_empty():
		_route = find_route(_manager, _head, STOP_AHEAD)
		if _route.is_empty():
			print("TrafficPolice: kilidin karşı şeridinde rota yok, müdahale yok")
			_reset()
			_cooldown = RETRY
			return
	if _spawn():
		return
	if _elapsed > SPAWN_WAIT:
		_reset()
		_cooldown = RETRY


## Kilit hâlâ duruyor mu (model yüklenirken çözülmüş olabilir)?
func _valid_jam() -> bool:
	if not is_instance_valid(_head) or not _manager.vehicles.has(_head):
		return false
	for vehicle: TrafficVehicle in _members:
		if not is_instance_valid(vehicle) or not vehicle.blocks_traffic() or vehicle.speed > TrafficManager.STILL_SPEED:
			return false
	return true


## Polisi karşı şeridin rotasının başında (ekran dışı) doğurur; doğma yeri doluysa false (sonra yeniden denenir).
func _spawn() -> bool:
	var spawn: TrafficWaypoint = _route["spawn"]
	var points: PackedVector3Array = _route["points"]
	if not _spawn_clear(points[0], TrafficVehicle._flat(points[1] - points[0]).normalized()):
		return false
	_police = _manager.spawn_chase_vehicle(spawn, {"id": _police_id, "scene": _police_scene},
		_manager.npc_appearance(_police_id))
	_police.start_chase(_route["points"], LANE_SHIFT)
	_stop_at = float(_route["stop"])
	_core_end = _police.chase_length()
	var end: TrafficWaypoint = _route["end"]
	if end and end.has_meta(TrafficManager.CORE_META):
		var core: Vector3 = end.get_meta(TrafficManager.CORE_META)
		_core_end -= Vector2(end.global_position.x - core.x, end.global_position.z - core.z).length()
	_distance = 0.0
	_speed = APPROACH_SPEED
	_elapsed = 0.0
	_blocked_for = 0.0
	_collect_siren(true)
	_siren.follow(_police, _siren_kind)
	_phase = Phase.APPROACH
	return true


## Kilidin başının karşı şeridinden geçen rota: {spawn, end, points, waypoints, stop}. Durma yeri `head`'in yol
## yönünde `ahead` ilerisi; rota o noktanın yanından TERS yönde geçmeli ve aradaki kavşaklar mümkünse az olmalı.
## Uygun rota yoksa {}.
static func find_route(manager: TrafficManager, head: TrafficVehicle, ahead: float) -> Dictionary:
	var forward: Vector3 = head.lane_direction()
	var goal: Vector3 = TrafficVehicle._flat(head.global_position) + forward * ahead
	var best: Dictionary = {}
	var best_score: float = INF
	for spawn: TrafficWaypoint in manager.spawn_points:
		for attempt: int in ROUTE_TRIES:
			var route: Dictionary = trace_route(spawn)
			if route.is_empty():
				continue
			var points: PackedVector3Array = route["points"]
			var waypoints: Array = route["waypoints"]
			var travelled: float = 0.0
			var crossings: int = 0
			for i: int in range(1, points.size()):
				var a: Vector3 = TrafficVehicle._flat(points[i - 1])
				var b: Vector3 = TrafficVehicle._flat(points[i])
				var segment: Vector3 = b - a
				var length: float = segment.length()
				if length < 0.001:
					continue
				var direction: Vector3 = segment / length
				var t: float = clampf((goal - a).dot(direction), 0.0, length)
				var miss: float = (a + direction * t).distance_to(goal)
				if direction.dot(forward) < -0.8 and miss < MATCH_DISTANCE:
					var score: float = miss + crossings * 0.5
					if score < best_score:
						best_score = score
						best = route.duplicate()
						best["stop"] = travelled + t
				travelled += length
				var point: TrafficWaypoint = waypoints[i]
				if point and point.intersection_entry:
					crossings += 1
	return best


## Doğma yeri boş mu: yalnız polisin şeridindeki araçlar sayılır (yanındaki şeritte kilitli kuyruk varken de çıkar).
func _spawn_clear(at: Vector3, direction: Vector3) -> bool:
	var others: Array[TrafficVehicle] = _manager.vehicles.duplicate()
	if _manager.chase:
		others.append_array(_manager.chase.vehicles())
	for other: TrafficVehicle in others:
		if not is_instance_valid(other):
			continue
		var offset: Vector3 = TrafficVehicle._flat(other.global_position - at)
		if absf(offset.cross(direction).y) < SPAWN_LANE and absf(offset.dot(direction)) < SPAWN_GAP:
			return false
	return true


## Doğma noktasından kaybolma noktasına rastgele bir rota (kavşakta pick_next): {spawn, end, points, waypoints}.
## Polis haritanın DIŞINDAKİ uçtan başlar (doğma noktasının kendisi; dünya kenarına taşınmış noktalar kameranın
## göremediği yerde): trafik aracı gibi ekranın hemen kenarında (hidden_start) doğsaydı kenardaki kilidin dibinde
## belirirdi — garaj önündeki bekleme noktaları batı girişinin eski yerine çok yakın.
static func trace_route(spawn: TrafficWaypoint) -> Dictionary:
	var points: PackedVector3Array = PackedVector3Array([spawn.global_position])
	var waypoints: Array = [null]
	var at: TrafficWaypoint = spawn.pick_next()
	var guard: int = 0
	while at != null and guard < 64:
		points.append(at.global_position)
		waypoints.append(at)
		if at.is_despawn:
			return {"spawn": spawn, "end": at, "points": points, "waypoints": waypoints}
		at = at.pick_next()
		guard += 1
	return {}


func _drive(delta: float) -> void:
	var desired: float = 0.0
	match _phase:
		Phase.APPROACH:
			var remaining: float = _stop_at - _distance
			desired = minf(APPROACH_SPEED, sqrt(2.0 * BRAKE * maxf(remaining, 0.0)))
			if remaining <= 0.02:
				desired = 0.0
		Phase.STOPPED:
			_timer -= delta
			if _timer <= 0.0:
				_stop_step()
		Phase.CLEARING:
			_timer += delta
			if _timer >= CLEAR_WAIT:
				_check_cleared()
		Phase.LEAVE:
			desired = LEAVE_SPEED
	if _phase == Phase.APPROACH or _phase == Phase.LEAVE:
		var gap: float = _gap_ahead()
		if gap < FOLLOW_GAP:
			desired = 0.0
		elif gap < FOLLOW_GAP * 2.0:
			desired = minf(desired, desired * (gap - FOLLOW_GAP) / FOLLOW_GAP)
		if _cross_blocked():
			desired = 0.0
	_speed = move_toward(_speed, desired, (ACCEL if desired > _speed else BRAKE * 1.6) * delta)
	_distance = minf(_distance + _speed * delta, _police.chase_length())
	_police.place_on_chase_path(_distance)
	if _phase == Phase.APPROACH:
		_blocked_for = _blocked_for + delta if _speed < 0.02 else 0.0
		var arrived: bool = _stop_at - _distance <= 0.03 and _speed < 0.05
		if arrived or (_blocked_for > BLOCKED_ARRIVE and _stop_at - _distance < 3.0):
			_speed = 0.0
			_stop = Stop.SIREN
			_timer = SIREN_ON_STOP
			_phase = Phase.STOPPED
	elif _phase == Phase.LEAVE:
		if _distance >= _police.chase_length() or (_distance > _core_end and _manager.is_hidden(_police.global_position)):
			_finish()


## Duruş adımı: siren susar → "dat dat" → geçirir.
func _stop_step() -> void:
	match _stop:
		Stop.SIREN:
			_siren.stop()
			_stop = Stop.PAUSE
			_timer = HORN_PAUSE
		Stop.PAUSE:
			_timer = _siren.blast(_police) + RELEASE_AFTER_HORN
			_stop = Stop.HORN
			horn_blasted.emit()
		Stop.HORN:
			_release()


## En öndeki aracı geçirir: kilitteki öbür araçları birkaç saniye engel saymaz.
func _release() -> void:
	if not _valid_jam():
		_leave()
		return
	_head.wave_through(_members, WAVE_SECONDS)
	_releases += 1
	_timer = 0.0
	_phase = Phase.CLEARING
	intervened.emit(_head)


## Kuyruk açıldı mı? Kilit sürüyorsa (aynı ya da yeni halka) sıradaki en öndekini geçirir; yoksa polis gider.
func _check_cleared() -> void:
	var ring: Array[TrafficVehicle] = _manager.find_deadlock(1.0)
	if not ring.is_empty() and _releases < MAX_RELEASES:
		if _timer >= CLEAR_MAX or not is_instance_valid(_head) or _head.speed < TrafficManager.STILL_SPEED:
			_members = ring
			_head = front_most(ring)
			_stop = Stop.HORN   # korna bir kez: sıradaki araç kornasız geçirilir
			_timer = NEXT_RELEASE
			_phase = Phase.STOPPED
		return
	_leave()


func _leave() -> void:
	_siren.stop()   # kilit polis gelmeden çözüldüyse siren hâlâ çalıyor olabilir
	_phase = Phase.LEAVE


## Polisin şeridinde önündeki araç (kilidin araçları hariç): aynı yönde, yakın şeritte. Yoksa INF.
func _gap_ahead() -> float:
	var forward: Vector3 = TrafficVehicle._flat(_police.global_transform.basis.z).normalized()
	var best: float = INF
	for other: TrafficVehicle in _manager.vehicles:
		if not is_instance_valid(other) or not other.blocks_traffic() or _members.has(other):
			continue
		var offset: Vector3 = TrafficVehicle._flat(other.global_position - _police.global_position)
		var along: float = offset.dot(forward)
		if along <= 0.0 or absf(offset.cross(forward).y) > 0.3:
			continue
		if TrafficVehicle._flat(other.global_transform.basis.z).normalized().dot(forward) < 0.3:
			continue
		best = minf(best, along - maxf(_police._front + other._front - TrafficManager.NOMINAL_LENGTH, 0.0))
	return best


## Önündeki kavşak girişine yaklaşırken karşı eksenden kavşakta araç varsa bekler (ışığa bakmaz: sirenli polis).
func _cross_blocked() -> bool:
	var points: PackedVector3Array = _route["points"]
	var waypoints: Array = _route["waypoints"]
	var travelled: float = 0.0
	for i: int in range(1, points.size()):
		travelled += TrafficVehicle._flat(points[i] - points[i - 1]).length()
		if travelled < _distance:
			continue
		if travelled - _distance > CROSS_LOOK:
			return false
		var point: TrafficWaypoint = waypoints[i]
		if point and point.intersection_entry:
			return _manager.cross_traffic_in_intersection(_axis())
	return false


func _finish() -> void:
	if is_instance_valid(_police):
		_police.queue_free()
	finished.emit()
	_reset()
	_cooldown = COOLDOWN


func _reset() -> void:
	_police = null
	_siren.stop()
	_members.clear()
	_head = null
	_route = {}
	_police_scene = null   # bellek: model bir sonraki müdahaleye kadar tutulmaz
	_loading = ""
	_phase = Phase.IDLE


func _describe(ring: Array[TrafficVehicle]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for vehicle: TrafficVehicle in ring:
		parts.append("%s(%s%s, %.1f sn)" % [vehicle.vehicle_id, TrafficVehicle.Mode.keys()[vehicle.mode],
			", çıkıyor" if vehicle.is_merging() else "", vehicle.stuck_time])
	return " ↔ ".join(parts)


## İş parçacığında: yalnızca bu düğümün alanına yazar (önbelleğe ana iş parçacığı koyar).
func _build_siren(kind: PoliceSiren.Kind) -> void:
	_siren_result = PoliceSiren.build(kind)
	_horn_result = PoliceSiren.build(PoliceSiren.Kind.HORN)


func _collect_siren(wait: bool) -> void:
	if _siren_task < 0 or (not wait and not WorkerThreadPool.is_task_completed(_siren_task)):
		return
	WorkerThreadPool.wait_for_task_completion(_siren_task)
	_siren_task = -1
	PoliceSiren.store(_siren_kind, _siren_result)
	PoliceSiren.store(PoliceSiren.Kind.HORN, _horn_result)
	_siren_result = null
	_horn_result = null


func _exit_tree() -> void:
	_collect_siren(true)
	if _loading != "":
		ResourceLoader.load_threaded_get(_loading)   # yarım kalan yüklemeyi bekle (sahne kapanırken sızmasın)
