class_name CarGarageManager
extends Node
## GARAJLARIM — oyuncunun ARAÇ garajları: alınmış / inşaattaki garajlar, iç yükseltme seviyeleri ve süren işler,
## araçların hangi garajın hangi park yerinde durduğu ve BEKLEME OTOPARKI. Veri CarGarageCatalog'da.
## Kararlar: docs/GARAJLAR_TASARIM.md §2–4.
##
## SAHİPLİK VehicleOwnership'tedir; burası yalnızca YERLEŞİMİ tutar ve her sahiplik değişiminde uzlaştırır
## (reconcile): satılan araç yerinden çıkar, yeni araç (galeri, kasa, hediye, hurdalık) boş yeri olan EN ÜST garaja
## park eder, yer yoksa BEKLER — kaybolmaz. Yer açılınca (satış, PARK YERİ, inşaat bitişi) bekleyenler geliş sırasıyla
## kendiliğinden park eder. Bekleyen araç yarışa / modifiyeye / boyaya giremez, satılabilir.
##
## Süreler gerçek saatle (unix) işler: oyun kapalıyken de dolar; süre dolunca iş kendiliğinden biter.
## Garaj başına aynı anda TEK iç yükseltme işi. Para hemen düşer.
## Kodla kurulur (GarageSystem, SaveManager'dan ÖNCE), "car_garages" grubundan bulunur. Kayıt SaveManager'da
## ("car_garages" bölümü, SAHİPLİKTEN ÖNCE yüklenir: sahiplik yüklenince uzlaştırma kayıttaki yerleşimi bulur).
## Arkadaş garajı ziyaretinde kurulmaz: GarageScreen yöneticisiz eski tek garaj görünümüne düşer.

## Bir araç yer değiştirdi / geldi / gitti.
signal layout_changed
## Satın alma, inşaat, iç yükseltme (seviye ya da süren iş) değişti.
signal garages_changed
## Yer yok: araç bekleme otoparkına girdi.
signal vehicle_waiting(vehicle_id: StringName)
## Bekleyen araçlar garaja girdi (geliş sırasıyla).
signal waiting_parked(vehicle_ids: Array[StringName])
signal build_finished(garage: StringName)
signal upgrade_finished(garage: StringName, item: StringName, level: int)
## ELMASLA BİTİR: elmas harcandı (HUD sesi).
signal gem_finished(garage: StringName)
signal purchase_failed(garage: StringName, status: int)

enum Status {
	OWNED,          ## garaj alınmış
	BUILDING,       ## inşaatta
	BUYABLE,        ## alınabilir
	NEEDS_LEVEL,    ## oyuncu seviyesi yetmiyor
	TOO_EXPENSIVE,  ## bakiye yetmiyor
	UNKNOWN,        ## katalogda yok
}

enum ItemStatus {
	BUYABLE,
	MAXED,          ## en yüksek seviyede
	NOT_OWNED,      ## garaj alınmamış (ya da inşaatta)
	BUSY,           ## bu garajda başka bir iş sürüyor
	TOO_EXPENSIVE,
}

## GarageScreen ve TÜM ARAÇLAR panosunun sözde garajı: bekleme otoparkı.
const WAITING: StringName = &"waiting"
## Biten işlere bakma aralığı (sn).
const POLL: float = 0.5
## Biten işler günlüğü (OTO MANŞET): en çok bu kadar kayıt, en çok bu kadar eski (sn).
const DONE_KEEP: int = 20
const DONE_MAX_AGE: float = 8.0 * 86400.0

## Test / hata ayıklama: saate eklenen sn (süreyi ileri sarmak için).
var clock_offset: float = 0.0

## Alınmış garajlar: id → {"levels": {kalem: seviye}, "slots": Array[StringName] (kapasite boyunda, &"" = boş yer)}.
var _garages: Dictionary = {}
## İnşaatta: id → bitiş (unix sn).
var _building: Dictionary = {}
## İç yükseltme işleri: garaj id → {"item", "level", "end"}.
var _jobs: Dictionary = {}
## Bekleme otoparkı, geliş sırasıyla.
var _waiting: Array[StringName] = []
## Biten inşaat / iç yükseltme işleri: {"garage", "item" (inşaatta &""), "level", "at"}. `at` işin PLANLANAN bitişi:
## oyun kapalıyken dolan iş açılışta kapanır ama OTO MANŞET'in "sen yokken" penceresine doğru düşer.
var _done: Array[Dictionary] = []
var _poll: float = 0.0


func _ready() -> void:
	add_to_group("car_garages")
	_ensure_starter()
	_connect.call_deferred()


func _connect() -> void:
	var ownership: VehicleOwnership = _ownership()
	if ownership and not ownership.ownership_changed.is_connected(reconcile):
		ownership.ownership_changed.connect(reconcile)
	reconcile()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	_check_timers()


func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset


# --- Garajlar -----------------------------------------------------------------------------

func is_owned(garage: StringName) -> bool:
	return _garages.has(garage)


func is_building(garage: StringName) -> bool:
	return _building.has(garage)


## Alınmış garajlar, merdiven sırasıyla.
func owned_garages() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CarGarageCatalog.ids():
		if _garages.has(id):
			out.append(id)
	return out


func status(garage: StringName) -> Status:
	if not CarGarageCatalog.has(garage):
		return Status.UNKNOWN
	if _garages.has(garage):
		return Status.OWNED
	if _building.has(garage):
		return Status.BUILDING
	if _player_level() < CarGarageCatalog.required_level(garage):
		return Status.NEEDS_LEVEL
	var economy: EconomyManager = _economy()
	if economy and not economy.can_afford(CarGarageCatalog.price(garage)):
		return Status.TOO_EXPENSIVE
	return Status.BUYABLE


## SATIN AL: para düşer, inşaat başlar (süresiz garaj hemen açılır). Kilitliyse hiçbir şey değişmez.
func purchase(garage: StringName) -> bool:
	var gate: Status = status(garage)
	if gate != Status.BUYABLE:
		purchase_failed.emit(garage, gate)
		return false
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(CarGarageCatalog.price(garage)):
		purchase_failed.emit(garage, Status.TOO_EXPENSIVE)
		return false
	var duration: float = CarGarageCatalog.build_time(garage)
	if duration <= 0.0:
		_open_garage(garage)
	else:
		_building[garage] = now() + duration
		garages_changed.emit()
	_request_save()
	return true


## İnşaatın kalan süresi (sn); inşaatta değilse 0.
func build_remaining(garage: StringName) -> float:
	return maxf(float(_building.get(garage, 0.0)) - now(), 0.0) if _building.has(garage) else 0.0


func build_gem_cost(garage: StringName) -> int:
	return GemSkip.cost_long(build_remaining(garage)) if _building.has(garage) else 0


## ELMASLA BİTİR (inşaat): elmas yetmezse hiçbir şey değişmez.
func finish_build_with_gems(garage: StringName) -> bool:
	var cost: int = build_gem_cost(garage)
	if cost <= 0 or not _spend_gems(cost):
		return false
	gem_finished.emit(garage)
	_building[garage] = now()
	_check_timers()
	return true


## Pencerede (from, to] biten işler, bitiş sırasıyla (OTO MANŞET, NewsSources).
func finished_between(from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _done:
		if float(entry["at"]) > from and float(entry["at"]) <= to:
			out.append(entry.duplicate())
	return out


# --- İç yükseltmeler ----------------------------------------------------------------------

## Kalemin seviyesi (1 = taban); garaj alınmamışsa 0.
func item_level(garage: StringName, item: StringName) -> int:
	if not _garages.has(garage):
		return 0
	return int((_garages[garage]["levels"] as Dictionary).get(item, 1))


func item_status(garage: StringName, item: StringName) -> ItemStatus:
	if not _garages.has(garage) or not CarGarageCatalog.ITEMS.has(item):
		return ItemStatus.NOT_OWNED
	if item_level(garage, item) >= CarGarageCatalog.max_level(garage, item):
		return ItemStatus.MAXED
	if _jobs.has(garage):
		return ItemStatus.BUSY
	var economy: EconomyManager = _economy()
	if economy and not economy.can_afford(next_item_cost(garage, item)):
		return ItemStatus.TOO_EXPENSIVE
	return ItemStatus.BUYABLE


## Sıradaki seviyenin ücreti (en yüksekteyse 0).
func next_item_cost(garage: StringName, item: StringName) -> int:
	return CarGarageCatalog.step_cost(garage, item, item_level(garage, item) + 1)


func next_item_time(garage: StringName, item: StringName) -> float:
	return CarGarageCatalog.step_time(garage, item, item_level(garage, item) + 1)


## YÜKSELT: para düşer, iş başlar (süre dolunca seviye artar; PARK YERİ ise yer açılır).
func upgrade_item(garage: StringName, item: StringName) -> bool:
	if item_status(garage, item) != ItemStatus.BUYABLE:
		return false
	var cost: int = next_item_cost(garage, item)
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(cost):
		return false
	var level: int = item_level(garage, item) + 1
	_jobs[garage] = {"item": item, "level": level, "end": now() + CarGarageCatalog.step_time(garage, item, level)}
	garages_changed.emit()
	_check_timers()   # süresiz adım (0 sn) hemen biter
	_request_save()
	return true


## Garajda süren iş: {"item", "level", "end"}; yoksa boş.
func job_of(garage: StringName) -> Dictionary:
	return (_jobs.get(garage, {}) as Dictionary).duplicate()


func job_remaining(garage: StringName) -> float:
	return maxf(float(_jobs[garage]["end"]) - now(), 0.0) if _jobs.has(garage) else 0.0


func job_gem_cost(garage: StringName) -> int:
	return GemSkip.cost_long(job_remaining(garage)) if _jobs.has(garage) else 0


func finish_job_with_gems(garage: StringName) -> bool:
	var cost: int = job_gem_cost(garage)
	if cost <= 0 or not _spend_gems(cost):
		return false
	gem_finished.emit(garage)
	_jobs[garage]["end"] = now()
	_check_timers()
	return true


# --- Yerleşim ----------------------------------------------------------------------------

func capacity(garage: StringName) -> int:
	return (_garages[garage]["slots"] as Array).size() if _garages.has(garage) else 0


func used(garage: StringName) -> int:
	return cars_in(garage).size()


func total_capacity() -> int:
	var total: int = 0
	for id: StringName in _garages:
		total += capacity(id)
	return total


## Garajdaki araçlar, park yeri sırasıyla (WAITING: bekleyenler, geliş sırasıyla).
func cars_in(garage: StringName) -> Array[StringName]:
	if garage == WAITING:
		return _waiting.duplicate()
	var out: Array[StringName] = []
	if _garages.has(garage):
		for id: StringName in _garages[garage]["slots"]:
			if id != &"":
				out.append(id)
	return out


## Park yerleri (kapasite boyunda, &"" = boş) — Faz 3'ün 3D yerleşimi için.
func slots_of(garage: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _garages.has(garage):
		out.assign(_garages[garage]["slots"])
	return out


## Aracın garajı; bekliyorsa WAITING, yerleşimde yoksa &"".
func garage_of(vehicle_id: StringName) -> StringName:
	for id: StringName in _garages:
		if (_garages[id]["slots"] as Array).has(vehicle_id):
			return id
	return WAITING if _waiting.has(vehicle_id) else &""


func is_waiting(vehicle_id: StringName) -> bool:
	return _waiting.has(vehicle_id)


func waiting_ids() -> Array[StringName]:
	return _waiting.duplicate()


## Aracın gidebileceği garajlar (kendi garajı hariç, boş yeri olan alınmış garajlar).
func move_targets(vehicle_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var current: StringName = garage_of(vehicle_id)
	for id: StringName in owned_garages():
		if id != current and used(id) < capacity(id):
			out.append(id)
	return out


## TAŞI: araç hedef garajın ilk boş yerine geçer. Hedef doluysa ya da araç sahipte değilse false.
func move(vehicle_id: StringName, garage: StringName) -> bool:
	var ownership: VehicleOwnership = _ownership()
	if (ownership and not ownership.is_owned(vehicle_id)) or not move_targets(vehicle_id).has(garage):
		return false
	_remove(vehicle_id)
	_put(garage, vehicle_id)
	layout_changed.emit()
	reconcile()   # araç bekleme otoparkından çıktıysa yeri olan başka bekleyen yok; yine de tutarlı kalsın
	_request_save()
	return true


## Sahiplikle uzlaştırır: satılan araç çıkar, yeni araç en üst boş garaja (yoksa beklemeye), bekleyenler boş yerlere.
## Değişiklik yoksa sinyal yok, kayıt yok.
func reconcile() -> void:
	var ownership: VehicleOwnership = _ownership()
	if ownership == null:
		return
	var owned: Array[StringName] = ownership.owned_vehicle_ids()
	var keep: Dictionary = {}
	for id: StringName in owned:
		keep[id] = true
	var changed: bool = false
	# 1) Gidenler (ve aynı aracın ikinci kopyası: bozuk kayıt)
	var seen: Dictionary = {}
	for garage: StringName in _garages:
		var slots: Array = _garages[garage]["slots"]
		for i: int in slots.size():
			var id: StringName = slots[i]
			if id != &"" and (not keep.has(id) or seen.has(id)):
				slots[i] = &""
				changed = true
			elif id != &"":
				seen[id] = true
	for i: int in range(_waiting.size() - 1, -1, -1):
		if not keep.has(_waiting[i]) or seen.has(_waiting[i]):
			_waiting.remove_at(i)
			changed = true
	for id: StringName in _waiting:
		seen[id] = true
	# 2) Gelenler: en üst boş garaja, yer yoksa beklemeye
	var arrived_waiting: Array[StringName] = []
	for id: StringName in owned:
		if seen.has(id):
			continue
		var target: StringName = _best_free()
		if target != &"":
			_put(target, id)
		else:
			_waiting.append(id)
			arrived_waiting.append(id)
		changed = true
	# 3) Bekleyenler yer açıldıkça girer
	var parked: Array[StringName] = []
	while not _waiting.is_empty():
		var target: StringName = _best_free()
		if target == &"":
			break
		var id: StringName = _waiting.pop_front()
		_put(target, id)
		if not arrived_waiting.has(id):
			parked.append(id)
		changed = true
	if not changed:
		return
	layout_changed.emit()
	_request_save()
	for id: StringName in arrived_waiting:
		if _waiting.has(id):
			vehicle_waiting.emit(id)
	if not parked.is_empty():
		waiting_parked.emit(parked)


# --- Garaj değeri -------------------------------------------------------------------------

## Garajlara ve iç yükseltmelere bugüne kadar ödenen ₺ (inşaattaki garaj ve süren iş dahil: para düştü).
func spent_total() -> int:
	var total: int = 0
	for id: StringName in CarGarageCatalog.ids():
		if _building.has(id):
			total += CarGarageCatalog.price(id)
		if not _garages.has(id):
			continue
		total += CarGarageCatalog.price(id)
		for item: StringName in CarGarageCatalog.ITEMS:
			for level: int in range(2, item_level(id, item) + 1):
				total += CarGarageCatalog.step_cost(id, item, level)
	for id: StringName in _jobs:
		total += CarGarageCatalog.step_cost(id, _jobs[id]["item"], int(_jobs[id]["level"]))
	return total


## Arkadaşlara açık özet (profil rozeti, arkadaşın lüks garajı haberi): {"own": alınmış garajlar merdiven sırasıyla,
## "cap": toplam park yeri}. Biçim PublicGarage.car_garage_summary ile aynı.
func public_summary() -> Dictionary:
	var own: Array = []
	for id: StringName in owned_garages():
		own.append(String(id))
	return {"own": own, "cap": total_capacity()}


# --- Kayıt -------------------------------------------------------------------------------

func state() -> Dictionary:
	var garages: Dictionary = {}
	for id: StringName in _garages:
		var levels: Dictionary = {}
		for item: StringName in _garages[id]["levels"]:
			levels[String(item)] = int(_garages[id]["levels"][item])
		var slots: Array = []
		for car: StringName in _garages[id]["slots"]:
			slots.append(String(car))
		garages[String(id)] = {"levels": levels, "slots": slots}
	var building: Dictionary = {}
	for id: StringName in _building:
		building[String(id)] = float(_building[id])
	var jobs: Dictionary = {}
	for id: StringName in _jobs:
		jobs[String(id)] = {"item": String(_jobs[id]["item"]), "level": int(_jobs[id]["level"]), "end": float(_jobs[id]["end"])}
	var waiting: Array = []
	for car: StringName in _waiting:
		waiting.append(String(car))
	var done: Array = []
	for entry: Dictionary in _done:
		done.append({"garage": String(entry["garage"]), "item": String(entry["item"]), "level": int(entry["level"]),
			"at": float(entry["at"])})
	return {"garages": garages, "building": building, "jobs": jobs, "waiting": waiting, "done": done}


## Kayıttan: bilinmeyen garaj / kalem / araç atılır, seviyeler sınırlanır, park yerleri kapasiteye göre kesilir ya da
## uzatılır. Saat geri alınmışsa süre kısalmaz ama adımın süresinden uzun da kalmaz. Uzlaştırma YAPMAZ: sahiplik
## henüz yüklenmemiş olabilir (SaveManager sahiplikten sonra reconcile çağırır). Eski kayıtta yoktur: yalnız MAHALLE.
func load_state(data: Dictionary) -> void:
	_garages.clear()
	_building.clear()
	_jobs.clear()
	_waiting.clear()
	_done.clear()
	var seen: Dictionary = {}
	var garages: Variant = data.get("garages", {})
	if garages is Dictionary:
		for raw: Variant in garages:
			var id: StringName = StringName(SaveSafe.s(raw))
			var row: Variant = (garages as Dictionary)[raw]
			if not CarGarageCatalog.has(id) or not row is Dictionary:
				continue
			var levels: Dictionary = {}
			var raw_levels: Variant = (row as Dictionary).get("levels", {})
			for item: StringName in CarGarageCatalog.ITEMS:
				var level: int = SaveSafe.i((raw_levels as Dictionary).get(String(item), 1)) if raw_levels is Dictionary else 1
				levels[item] = clampi(level, 1, CarGarageCatalog.max_level(id, item))
			var slots: Array[StringName] = []
			slots.resize(CarGarageCatalog.capacity_at(id, int(levels[CarGarageCatalog.PARK])))
			slots.fill(&"")
			var raw_slots: Variant = (row as Dictionary).get("slots", [])
			if raw_slots is Array:
				for i: int in mini((raw_slots as Array).size(), slots.size()):
					var car: StringName = StringName(SaveSafe.s((raw_slots as Array)[i]))
					if car != &"" and not CarCatalog.get_entry(car).is_empty() and not seen.has(car):
						slots[i] = car
						seen[car] = true
			_garages[id] = {"levels": levels, "slots": slots}
	var building: Variant = data.get("building", {})
	if building is Dictionary:
		for raw: Variant in building:
			var id: StringName = StringName(SaveSafe.s(raw))
			if CarGarageCatalog.has(id) and not _garages.has(id):
				_building[id] = minf(SaveSafe.f((building as Dictionary)[raw]), now() + CarGarageCatalog.build_time(id))
	var jobs: Variant = data.get("jobs", {})
	if jobs is Dictionary:
		for raw: Variant in jobs:
			var id: StringName = StringName(SaveSafe.s(raw))
			var job: Variant = (jobs as Dictionary)[raw]
			if not _garages.has(id) or not job is Dictionary:
				continue
			var item: StringName = StringName(SaveSafe.s((job as Dictionary).get("item", "")))
			var level: int = SaveSafe.i((job as Dictionary).get("level", 0))
			if not CarGarageCatalog.ITEMS.has(item) or level != item_level(id, item) + 1 \
					or level > CarGarageCatalog.max_level(id, item):
				continue
			var end: float = minf(SaveSafe.f((job as Dictionary).get("end", now())), now() + CarGarageCatalog.step_time(id, item, level))
			_jobs[id] = {"item": item, "level": level, "end": end}
	var waiting: Variant = data.get("waiting", [])
	if waiting is Array:
		for raw: Variant in waiting:
			var car: StringName = StringName(SaveSafe.s(raw))
			if car != &"" and not CarCatalog.get_entry(car).is_empty() and not seen.has(car):
				_waiting.append(car)
				seen[car] = true
	var done: Variant = data.get("done", [])
	if done is Array:
		for raw: Variant in done:
			if not raw is Dictionary:
				continue
			var id: StringName = StringName(SaveSafe.s((raw as Dictionary).get("garage", "")))
			var item: StringName = StringName(SaveSafe.s((raw as Dictionary).get("item", "")))
			if CarGarageCatalog.has(id) and (item == &"" or CarGarageCatalog.ITEMS.has(item)):
				_done.append({"garage": id, "item": item, "level": SaveSafe.i((raw as Dictionary).get("level", 1)),
					"at": SaveSafe.f((raw as Dictionary).get("at", 0.0))})
		_trim_done()
	_ensure_starter()
	garages_changed.emit()
	layout_changed.emit()


## Yeni oyun: yalnız MAHALLE GARAJI, boş.
func reset() -> void:
	load_state({})


# --- İç ----------------------------------------------------------------------------------

## Başlangıç garajı (ücretsiz) her zaman vardır.
func _ensure_starter() -> void:
	if not _garages.has(CarGarageCatalog.MAHALLE):
		_garages[CarGarageCatalog.MAHALLE] = _new_garage(CarGarageCatalog.MAHALLE)


func _new_garage(garage: StringName) -> Dictionary:
	var levels: Dictionary = {}
	for item: StringName in CarGarageCatalog.ITEMS:
		levels[item] = 1
	var slots: Array[StringName] = []
	slots.resize(CarGarageCatalog.capacity_at(garage, 1))
	slots.fill(&"")
	return {"levels": levels, "slots": slots}


func _open_garage(garage: StringName) -> void:
	_log_done(garage, &"", 1, float(_building.get(garage, now())))
	_building.erase(garage)
	_garages[garage] = _new_garage(garage)
	build_finished.emit(garage)
	garages_changed.emit()
	reconcile()   # bekleyenler yeni garaja girer


func _check_timers() -> void:
	var t: float = now()
	for id: StringName in _building.keys():
		if float(_building[id]) <= t:
			_open_garage(id)
			_request_save()
	for id: StringName in _jobs.keys():
		var job: Dictionary = _jobs[id]
		if float(job["end"]) > t or not _garages.has(id):
			continue
		_jobs.erase(id)
		var item: StringName = job["item"]
		var level: int = int(job["level"])
		_garages[id]["levels"][item] = level
		_log_done(id, item, level, float(job["end"]))
		if item == CarGarageCatalog.PARK:
			var slots: Array = _garages[id]["slots"]
			while slots.size() < CarGarageCatalog.capacity_at(id, level):
				slots.append(&"")
		upgrade_finished.emit(id, item, level)
		garages_changed.emit()
		reconcile()
		_request_save()


func _log_done(garage: StringName, item: StringName, level: int, at: float) -> void:
	_done.append({"garage": garage, "item": item, "level": level, "at": at})
	_trim_done()


func _trim_done() -> void:
	var oldest: float = now() - DONE_MAX_AGE
	_done.assign(_done.filter(func(entry: Dictionary) -> bool: return float(entry["at"]) >= oldest))
	while _done.size() > DONE_KEEP:
		_done.pop_front()


## Boş yeri olan EN ÜST garaj; yoksa &"".
func _best_free() -> StringName:
	var ids: Array[StringName] = CarGarageCatalog.ids()
	for i: int in range(ids.size() - 1, -1, -1):
		var id: StringName = ids[i]
		if _garages.has(id) and (_garages[id]["slots"] as Array).has(&""):
			return id
	return &""


func _put(garage: StringName, vehicle_id: StringName) -> void:
	var slots: Array = _garages[garage]["slots"]
	slots[slots.find(&"")] = vehicle_id


func _remove(vehicle_id: StringName) -> void:
	_waiting.erase(vehicle_id)
	for id: StringName in _garages:
		var slots: Array = _garages[id]["slots"]
		var i: int = slots.find(vehicle_id)
		if i >= 0:
			slots[i] = &""


func _spend_gems(cost: int) -> bool:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	return progress != null and progress.spend_gems(cost)


func _player_level() -> int:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	return progress.level if progress else 99


func _ownership() -> VehicleOwnership:
	return get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership if is_inside_tree() else null


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager if is_inside_tree() else null


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager") if is_inside_tree() else null
	if save and save.has_method(&"request_save"):
		save.request_save()
