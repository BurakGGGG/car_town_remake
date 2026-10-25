class_name EventCar
extends Node
## ETKİNLİK ARACI (2026-10-26; P1 etkinlik takvimi + sınırlı süreli araç, kullanıcının soru-cevap kararları): süren
## etkinliğin `car` modülü (LiveEvent.car). Araç etkinlik boyunca ÖDÜNÇ verilir: yalnız ETKİNLİK YARIŞINDA kullanılır
## (günde DAILY_RACES hak, ödüllü reklamla +1 — AdPolicy.EVENT_RACE), garajda etiketiyle park eder (EventCarSpot).
## Etkinlik görevlerinin HEPSİ bitince araç oyuncunun olur (VehicleOwnership.add_vehicle: keşif / koleksiyon ödülleri de
## işler); zaten varsa görevler yine yapılır, ödül elmas + kasa (owned_gems / owned_crate). Etkinlik biterken görevler
## bitmemişse araç geri alınır ve ilerleme silinir: görev ilerlemesi etkinlik kimliğine bağlıdır (MissionManager), ödünç
## yalnız etkinlik sürerken vardır. Kayıt "event_car": {id, paid, day, used, extra}. GarageSystem kurar (SaveManager'dan
## ÖNCE), "event_car" grubundan bulunur.

signal changed
## Araç kazanıldı ya da (zaten vardı) teselli ödülü verildi: {car, owned, gems, crate, title}.
signal won(entry: Dictionary)

## Günde etkinlik yarışı hakkı (kullanıcı kararı); reklamla bir tane daha.
const DAILY_RACES: int = 3

## Testler: -1 değilse bugünün gün numarası (unix gün) yerine bu.
static var test_today: int = -1

var _id: String = ""   # durumun ait olduğu etkinlik
var _paid: bool = false
var _day: int = -1
var _used: int = 0
var _extra: int = 0


func _ready() -> void:
	add_to_group("event_car")
	_connect.call_deferred()


func _connect() -> void:
	var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
	if missions:
		missions.missions_changed.connect(check)
	check()


## Süren etkinliğin aracı (yoksa &"").
static func car_id() -> StringName:
	return StringName(LiveEvent.car().get("id", &""))


## Etkinlikte kazanılacak bir araç var ve henüz kazanılmadı.
func active() -> bool:
	_sync()
	return car_id() != &"" and not _paid


## Bu etkinliğin aracı kazanıldı (ya da teselli ödülü alındı).
func is_won() -> bool:
	_sync()
	return car_id() != &"" and _paid


## Araç oyuncuda zaten var mı (o zaman ödünç değil, kendi aracıyla yarışır; ödül teselli).
func owns_car() -> bool:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	return ownership != null and car_id() != &"" and ownership.is_owned(car_id())


## Ödünç araç garajda / yarışta (etkinlik sürüyor, kazanılmadı, oyuncuda yok).
func is_loan() -> bool:
	return active() and not owns_car()


## Görev ilerlemesi: x = biten, y = toplam.
func progress() -> Vector2i:
	var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
	if missions == null:
		return Vector2i.ZERO
	var tasks: Array[Dictionary] = missions.event_tasks()
	var done: int = 0
	for task: Dictionary in tasks:
		if bool(task["done"]):
			done += 1
	return Vector2i(done, tasks.size())


# --- Günlük haklar -------------------------------------------------------------

func tries_left() -> int:
	_sync()
	return maxi(DAILY_RACES + _extra - _used, 0)


func tries_total() -> int:
	_sync()
	return DAILY_RACES + _extra


## Bugün reklamla hak eklenebilir mi (günde bir; haklar bitmeden de alınabilir).
func can_add_try() -> bool:
	return active() and _extra == 0


## Ödüllü reklam izlendi: bugün +1 hak.
func add_try() -> void:
	if not can_add_try():
		return
	_extra = 1
	_changed()


## ETKİNLİK YARIŞI başlıyor: bir hak düşer (yarış yarıda bırakılsa da). Hak yoksa / araç yoksa false.
func use_try() -> bool:
	if not active() or tries_left() <= 0:
		return false
	_used += 1
	_changed()
	return true


# --- Ödül ------------------------------------------------------------------------

## Görevlerin hepsi bittiyse araç verilir (bir kez). missions_changed'e bağlı; açılışta da bakılır.
func check() -> void:
	if not active():
		return
	var p: Vector2i = progress()
	if p.y > 0 and p.x >= p.y:
		_pay()


func _pay() -> void:
	var car: Dictionary = LiveEvent.car()
	var vehicle: StringName = StringName(car.get("id", &""))
	var owned: bool = owns_car()
	_paid = true
	var entry: Dictionary = {"car": vehicle, "owned": owned, "gems": 0, "crate": &"",
		"title": SaveSafe.s(LiveEvent.current().get("title", ""))}
	var tree: SceneTree = get_tree()
	if not owned:
		var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		if ownership:
			ownership.add_vehicle(vehicle)
	else:
		var gems: int = int(car.get("owned_gems", 0))
		var progress_node: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
		if progress_node and gems > 0:
			progress_node.add_gems(gems)
			entry["gems"] = gems
		var crate: StringName = StringName(car.get("owned_crate", &""))
		var crates: CrateManager = tree.get_first_node_in_group("crates") as CrateManager
		if crate != &"" and crates and crates.grant_free(crate, "event") > 0:
			entry["crate"] = crate
	_changed()
	won.emit(entry)


# --- Durum ---------------------------------------------------------------------

## Etkinlik değiştiyse durum sıfırlanır; gün döndüyse haklar yenilenir.
func _sync() -> void:
	var event_id: String = LiveEvent.id()
	if event_id != _id and not event_id.is_empty():
		_id = event_id
		_paid = false
		_used = 0
		_extra = 0
		_day = _today()
	var today: int = _today()
	if today != _day:
		_day = today
		_used = 0
		_extra = 0


static func _today() -> int:
	return test_today if test_today >= 0 else floori(Time.get_unix_time_from_system() / 86400.0)


func _changed() -> void:
	changed.emit()
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.request_save()


func state() -> Dictionary:
	return {"id": _id, "paid": _paid, "day": _day, "used": _used, "extra": _extra}


func load_state(data: Dictionary) -> void:
	_id = SaveSafe.s(data.get("id", ""))
	_paid = data.get("paid", false) == true
	_day = SaveSafe.i(data.get("day", -1))
	_used = clampi(SaveSafe.i(data.get("used", 0)), 0, DAILY_RACES + 1)
	_extra = clampi(SaveSafe.i(data.get("extra", 0)), 0, 1)
	changed.emit()


func reset() -> void:
	_id = ""
	_paid = false
	_day = -1
	_used = 0
	_extra = 0
	changed.emit()
