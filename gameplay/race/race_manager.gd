class_name RaceManager
extends Node
## DRAG YARIŞI AKIŞI — rakibin yoldan gelmesi, davet, yarış sonucu ve ödül.
##
## Car Town zinciri: GARAJ → YARIŞ ŞERİDİNDEN rakip gelir → durup 🏁 balonu açar → davet plakası →
## YARIŞ → sonuç → garaja dönüş. Oyuncu normal trafikte araç SÜRMEZ; yarış ayrı bir moddur.
##
## YARIŞ ŞERİDİ: şehir trafiğinin bir şeridi yarışa ayrıldı (`TrafficManager.race_lane_spawn`).
## O şeritte normal NPC doğmaz; yalnızca buradan çağrılan davet araçları girer. Rakip şeridin
## başında doğar, duruş noktasına kadar normal sürer, orada durup balonunu açar. Oyuncu kabul
## etmezse süre dolunca DÜMDÜZ devam edip şeritten çıkar ve bir süre sonra arkadan yenisi gelir.
##
## MEVCUT SİSTEMLERİ YENİDEN KULLANIR, KOPYALAMAZ:
##   - rakip, TrafficManager'ın zaten yoldaki araçlarından seçilir (RepairManager'ın müşteri seçme
##     yöntemiyle aynı mantık: uygun, sağlam, meşgul olmayan bir NPC),
##   - araç, tamir müşterisiyle aynı "yol kenarına yanaş" koduyla durur (TrafficVehicle._pull_over),
##   - balon ve tıklama mevcut CarBubble + CarHitbox yoludur,
##   - ekranlar UiRouter'dan açılır (kendi ESC/navigation mantığı yok).
##
## Sahnede World/Gameplay/RaceManager olarak durur, "race" grubundan bulunur (autoload yok).
## Kayıt: yalnızca KİŞİSEL REKORLAR saklanır (araç başına en iyi 300 m süresi + rekor koşunun
## mesafe izi, ilerleme çubuğundaki "hayalet" için). SaveManager "race" bölümü olarak okur/yazar;
## eski kayıtta bölüm yoktur → rekorsuz başlanır (sürüm atlamaz).

## Yoldan gelen rakip durdu ve davet açık (HUD balonu/plakası için).
signal challenger_ready(vehicle: Node3D)
## Rakip davet vermeden çekildi ya da yarış bitti.
signal challenger_left(vehicle: Node3D)
## Yarış bitti: ödül verildi (HUD bildirimi için).
signal race_finished(won: bool, money: int, xp: int)
## Oyuncu rakibin 🏁 balonuna/aracına dokundu → davet panosu açılmalı.
signal challenge_clicked(vehicle: Node3D)
## Kişisel rekor değişti (otomatik kayıt için).
signal records_changed

## Bir rakip gittikten sonra yenisi ne kadar sonra gelir (sn).
@export var challenge_interval_min: float = 5.0
@export var challenge_interval_max: float = 10.0
## Yarıştan sonra yeni rakip için beklenen en az süre.
@export var cooldown: float = 12.0
## Rakibin durduğu nokta: yarış şeridindeki bu yol noktası. Yön bir sonraki noktadan türetilir,
## yani sahnede ayrı bir işaret (Marker3D) gerekmez. Garaja yakın şerit (x = 0,3) kuzeyden
## gelir, kavşağın hemen öncesinde durur; kabul edilmezse dümdüz devam edip güneyden çıkar.
@export var stop_waypoint: StringName = &"N_in_approach"
## İSTEĞE BAĞLI el ile duruş noktası. Yarış şeridinin üstünde DEĞİLSE yok sayılır (uyarı basar):
## eski sürümde davet tamir şeridinde açılıyordu, oradaki işaret artık geçerli değil.
@export var challenge_spot: Node3D

## KAZANMA ÖDÜLLERİ — rakibin sınıfına göre (₺, XP). Kaybetmek para KAYBETTİRMEZ: yalnızca
## teselli XP'si verilir, böylece yarış ekonomide geriye götürmez (yakıt/ücret de yoktur).
const WIN_REWARD: Dictionary = {
	"D": {"money": 450, "xp": 25},
	"C": {"money": 700, "xp": 35},
	"B": {"money": 1000, "xp": 50},
	"A": {"money": 1400, "xp": 70},
	"S": {"money": 2000, "xp": 100},   # süper sporlar (GT3, Huracán, 488 Pista, RS6)
}
## Sahiplik düğümü yoksa (test sahnesi) yarışa çıkan araç.
const FALLBACK_VEHICLE: StringName = &"tofas_sahin"

## Rekor izinin örnek aralığı (sn, yarış saatine göre: GO'dan itibaren).
const TRACE_STEP: float = 0.25
## Kayıttan gelen süre bu aralık dışındaysa yok sayılır (bozuk / elle oynanmış kayıt).
const RECORD_MIN: float = 3.0
const RECORD_MAX: float = 60.0
const TRACE_MAX: int = 240

## Kaybedince verilen XP oranı (para yok).
const LOSS_XP_RATIO: float = 0.3

## Rakip duruş noktasına bu kadar yaklaşınca davet açılır (balon çıkar).
const ARRIVE_DISTANCE: float = 0.45
## El ile verilen duruş noktası şeritten bu kadar uzaksa yok sayılır.
const SPOT_TOLERANCE: float = 1.5

var _timer: float = 0.0
var _challenger: TrafficVehicle
## Duruş noktası: yarış şeridindeki waypoint'ten türetilen, gidiş yönüne dönük işaret.
var _stop: Marker3D
var _rival_id: StringName = &""
var _traffic: TrafficManager
const CarHitbox: GDScript = preload("res://car_hitbox.gd")

var _rng := RandomNumberGenerator.new()
## Davet açıkken oyuncu kabul etmezse rakip bu süre sonunda yola döner (bekleyen araç kalıcı
## olarak yolu işgal etmesin). Yarış sürerken sayaç işlemez.
@export var challenge_timeout: float = 30.0
var _wait: float = 0.0
## Yarış ekranı açıkken rakip beklemeye devam eder (zaman aşımı durur).
var _racing: bool = false
## EĞİTİM (drag yarışı dersi) anlatırken rakip yoldan çekilip gitmesin: zaman aşımı durur.
var tutorial_hold: bool = false
## Aynı yarışın ödülü iki kez verilmesin diye: ödül verildiğinde işaretlenir.
var _reward_paid: bool = false
## KİŞİSEL REKORLAR: araç id → {"time": sn, "trace": PackedFloat32Array (her TRACE_STEP'te metre)}.
var _records: Dictionary = {}


func _ready() -> void:
	add_to_group("race")
	_rng.randomize()
	_timer = _rng.randf_range(challenge_interval_min, challenge_interval_max)
	_connect_traffic.call_deferred()


func _process(delta: float) -> void:
	if _traffic == null:
		return
	if is_instance_valid(_challenger):
		if _challenger.mode == TrafficVehicle.Mode.TRAFFIC:
			# Şeritte geliyor: duruş noktasına varınca durup balonunu açar
			if _stop and _flat_distance(_challenger.global_position, _stop.global_position) <= ARRIVE_DISTANCE:
				_open_challenge()
			return
		# Davete dokunuldu mu? (mevcut araç seçimi yolu: CarHitbox.selected_car)
		if has_challenge() and CarHitbox.selected_car == _challenger:
			CarHitbox.clear_selection(get_tree())
			challenge_clicked.emit(_challenger)
		if not _racing and not tutorial_hold:
			_wait -= delta
			if _wait <= 0.0:
				release_challenger()   # oyuncu ilgilenmedi: dümdüz devam edip şeritten çıkar
		return
	_timer -= delta
	if _timer <= 0.0:
		_send_challenger()


## Yarış ekranı açık/kapalı: açıkken rakip beklemeye devam eder.
func set_racing(value: bool) -> void:
	_racing = value
	if not value:
		_wait = challenge_timeout


# --- Rakip seçimi -----------------------------------------------------------------

## Oyuncunun sınıfına yakın bir rakip seçilir: kendi sınıfı ya da bir üst sınıf. Katı kilit yok —
## oyuncunun sahip OLMADIĞI araçlar da rakip olabilir (Car Town'da da rakipler dışarıdan gelir).
func rival_id_for(player_id: StringName) -> StringName:
	var player_class: String = String(CarCatalog.get_entry(player_id).get("class", "D"))
	var order: Array[String] = ["D", "C", "B", "A", "S"]
	var index: int = maxi(order.find(player_class), 0)
	var wanted: Array[String] = [order[index]]
	if index + 1 < order.size():
		wanted.append(order[index + 1])
	var pool: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		if wanted.has(String(entry.get("class", ""))):
			pool.append(entry["id"])
	if pool.is_empty():
		pool.append(player_id)
	return pool[_rng.randi_range(0, pool.size() - 1)]


## Oyuncunun yarışa çıkaracağı araç: garajda YARIŞ ARACI olarak seçilen (VehicleOwnership.race_vehicle_id);
## seçilmemişse başlangıç aracı Tofaş Şahin. (Eskiden sahip olunan ilk araç dönüyordu: o da E46'ydı,
## oyuncu ilk dakikadan A sınıfıyla yarışıyordu.)
func player_vehicle_id() -> StringName:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership == null:
		return FALLBACK_VEHICLE
	var id: StringName = ownership.race_vehicle_id()
	return id if id != &"" else FALLBACK_VEHICLE


func challenger() -> TrafficVehicle:
	return _challenger if is_instance_valid(_challenger) else null


func rival_id() -> StringName:
	return _rival_id


## Hemen bir rakip getirir ve davetini AÇAR (hata ayıklama / test): şeridi baştan sona sürmesini
## beklemez, doğrudan duruş noktasına konur.
func request_challenge_now() -> bool:
	if not is_instance_valid(_challenger):
		_send_challenger()
	if not is_instance_valid(_challenger):
		return false
	if _challenger.mode == TrafficVehicle.Mode.TRAFFIC and _stop:
		_challenger.global_position = _stop.global_position
		_open_challenge()
	return true


## Yarış daveti açık mı?
func has_challenge() -> bool:
	return is_instance_valid(_challenger) and _challenger.mode == TrafficVehicle.Mode.RACE_CHALLENGE


# --- Ödül -------------------------------------------------------------------------

## Bir yarışın ödülü (₺, XP) — kazanan/kaybedene göre. UI de bunu kullanır (hardcode yok).
func reward_for(rival: StringName, won: bool) -> Dictionary:
	var rival_class: String = String(CarCatalog.get_entry(rival).get("class", "D"))
	var base: Dictionary = WIN_REWARD.get(rival_class, WIN_REWARD["D"])
	if won:
		return {"money": int(base["money"]), "xp": int(base["xp"])}
	return {"money": 0, "xp": int(round(float(base["xp"]) * LOSS_XP_RATIO))}


## Yarış bitti: ödül BİR KEZ verilir (aynı yarış iki kez ödül vermez), rakip yola döner.
func finish_race(won: bool) -> Dictionary:
	var reward: Dictionary = reward_for(_rival_id, won)
	if _reward_paid:
		return {"money": 0, "xp": 0}
	_reward_paid = true
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy and int(reward["money"]) > 0:
		economy.add_money(int(reward["money"]))
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress and int(reward["xp"]) > 0:
		progress.add_xp(int(reward["xp"]))
	race_finished.emit(won, int(reward["money"]), int(reward["xp"]))
	release_challenger()
	return reward


## Rakibi normal trafiğe geri gönderir (yarış bitti ya da vazgeçildi).
func release_challenger() -> void:
	var vehicle: TrafficVehicle = _challenger
	_challenger = null
	_rival_id = &""
	_timer = maxf(cooldown, _rng.randf_range(challenge_interval_min, challenge_interval_max))
	if is_instance_valid(vehicle):
		vehicle.end_race_challenge()
		challenger_left.emit(vehicle)


# --- Kişisel rekor ----------------------------------------------------------------

## Bu aracın rekoru (sn); yoksa -1.
func best_time(vehicle_id: StringName) -> float:
	var record: Dictionary = _records.get(vehicle_id, {})
	return float(record.get("time", -1.0))


## Rekor koşunun mesafe izi (metre, her TRACE_STEP saniyede bir); yoksa boş.
func best_trace(vehicle_id: StringName) -> PackedFloat32Array:
	var record: Dictionary = _records.get(vehicle_id, {})
	return record.get("trace", PackedFloat32Array())


## Bitmiş bir koşuyu bildirir. Rekoru geçtiyse kaydeder ve true döner (ilk koşu da rekordur).
func submit_time(vehicle_id: StringName, time: float, trace: PackedFloat32Array) -> bool:
	if vehicle_id == &"" or time < RECORD_MIN or time > RECORD_MAX:
		return false
	var previous: float = best_time(vehicle_id)
	if previous > 0.0 and time >= previous:
		return false
	_records[vehicle_id] = {"time": time, "trace": trace.slice(0, TRACE_MAX)}
	records_changed.emit()
	return true


func state() -> Dictionary:
	var best: Dictionary = {}
	for id: StringName in _records:
		var record: Dictionary = _records[id]
		var trace: Array = []
		for meters: float in record["trace"]:
			trace.append(snappedf(meters, 0.1))
		best[String(id)] = {"time": snappedf(float(record["time"]), 0.001), "trace": trace}
	return {"best": best}


func load_state(data: Dictionary) -> void:
	_records.clear()
	var best: Variant = data.get("best", {})
	if not best is Dictionary:
		return
	for key: Variant in best:
		var raw: Variant = best[key]
		var id: StringName = StringName(SaveSafe.s(key))
		if not raw is Dictionary or id == &"" or CarCatalog.get_entry(id).is_empty():
			continue
		var time: float = SaveSafe.f((raw as Dictionary).get("time", 0.0))
		if time < RECORD_MIN or time > RECORD_MAX:
			continue
		var trace: PackedFloat32Array = PackedFloat32Array()
		var raw_trace: Variant = (raw as Dictionary).get("trace", [])
		if raw_trace is Array:
			for value: Variant in (raw_trace as Array).slice(0, TRACE_MAX):
				trace.append(clampf(SaveSafe.f(value), 0.0, DragRaceSim.DISTANCE))
		_records[id] = {"time": time, "trace": trace}


func reset() -> void:
	_records.clear()


# --- İç ---------------------------------------------------------------------------

func _connect_traffic() -> void:
	_traffic = _find_traffic(get_tree().current_scene if get_tree().current_scene else get_parent())
	if _traffic == null:
		push_warning("RaceManager: TrafficManager bulunamadı; yarış daveti gelmez")
		return
	if _traffic.race_spawn_point == null:
		push_warning("RaceManager: yarış şeridi (TrafficManager.race_lane_spawn) bulunamadı")
	_build_stop()


## Yarış şeridine yeni bir rakip salar. Şerit doluysa (önceki hâlâ çıkmadıysa) sonra denenir.
func _send_challenger() -> void:
	if _stop == null:
		_timer = 5.0
		return
	# Rakip modeli ÖNCE seçilir (oyuncunun sınıfına göre), araç o modelle yola çıkar: yoldan
	# gelen araç ile yarışta karşına çıkan araç AYNI olur.
	if _rival_id == &"":
		_rival_id = rival_id_for(player_vehicle_id())
	var vehicle: TrafficVehicle = _traffic.spawn_challenger(_rival_id)
	if vehicle == null:
		_timer = 2.0   # model yükleniyor ya da şerit dolu: birazdan yine dener
		return
	_challenger = vehicle
	_rival_id = vehicle.vehicle_id
	_reward_paid = false


## Rakip duruş noktasına geldi: durur, 🏁 balonunu açar ve zaman aşımı sayacı başlar.
func _open_challenge() -> void:
	_wait = challenge_timeout
	_challenger.request_race_challenge(_stop)
	challenger_ready.emit(_challenger)


## Duruş noktası: yarış şeridindeki waypoint'in konumu + gidiş yönü. Sahnede işaret gerekmez;
## el ile bir işaret verildiyse (challenge_spot) ve şeridin üstündeyse o kullanılır.
func _build_stop() -> void:
	var point: TrafficWaypoint = _waypoint(stop_waypoint)
	if point == null:
		push_warning("RaceManager: '%s' yol noktası yok; davet açılamaz" % stop_waypoint)
		return
	_stop = Marker3D.new()
	_stop.name = "RaceStop"
	add_child(_stop)
	_stop.global_position = point.global_position
	var next: Array[TrafficWaypoint] = point.get_next()
	if not next.is_empty():
		var direction: Vector3 = next[0].global_position - point.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			# Model önü +Z: araç şeridin gidiş yönüne dönük park eder
			_stop.rotation.y = atan2(direction.x, direction.z)
	if is_instance_valid(challenge_spot):
		if _flat_distance(challenge_spot.global_position, _stop.global_position) <= SPOT_TOLERANCE:
			_stop.global_transform = challenge_spot.global_transform
		else:
			push_warning("RaceManager: challenge_spot yarış şeridinde değil, yok sayıldı " +
				Loc.t("(şerit noktası %s, verilen %s)") % [_stop.global_position, challenge_spot.global_position])


func _waypoint(point_name: StringName) -> TrafficWaypoint:
	for point: TrafficWaypoint in _traffic.waypoints:
		if point.name == point_name:
			return point
	return null


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _find_traffic(node: Node) -> TrafficManager:
	if node == null:
		return null
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null
