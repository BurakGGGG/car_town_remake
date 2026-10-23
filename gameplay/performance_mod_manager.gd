class_name PerformanceModManager
extends Node
## PERFORMANS MODİFİYESİ — oyuncunun araç başına yapısı (kategori → kademe), parça satın alma ve TAKMA.
## Model ve sayılar PerformanceMods'ta (docs/PERFORMANS_MODIFIYE_TASARIM.md); bu node durumu tutar.
##
## TAKMA bir tamir alanında olur (CarSpot): parça alınınca araç lifte çıkar, kademenin süresi boyunca alan
## doludur (müşteri alınamaz, restorasyon başlatılamaz — RepairManager._project_bays bunu okur). Süre gerçek
## saatle (unix) işler: oyun kapalıyken de dolar. Süre bitince araç alanda HAZIR bekler; oyuncu araca dokununca
## parça takılır (collect), yapı güncellenir, alan boşalır. Bir araca aynı anda tek parça takılır.
## Para hemen düşer; araç satılırsa yapısı ve süren takma silinir, para geri dönmez (karar: 2026-10-13).
##
## Kodla kurulur (GarageSystem, SaveManager'dan ÖNCE), "performance_mods" grubundan bulunur. Kayıt
## SaveManager'da ("performance" bölümü). Arkadaş garajı ziyaretinde hiç kurulmaz.

## Yapı değişti (parça takıldı, satış, kayıt yükleme).
signal mods_changed(vehicle_id: StringName)
## Parça alındı, araç tamir alanına girdi.
signal install_started(vehicle_id: StringName, category: StringName, stage: int)
## Takma süresi doldu: araç alanda HAZIR bekliyor.
signal install_ready(vehicle_id: StringName)
## Parça takıldı (oyuncu araca dokundu). Sınıf atladıysa old_class != new_class.
signal install_completed(vehicle_id: StringName, category: StringName, stage: int, old_class: String,
	new_class: String)
## Süren takmalar değişti (alan görünümü bunu izler).
signal jobs_changed
## ELMASLA BİTİR: elmas harcandı, takma anında bitiyor (HUD sesi).
signal gem_finished(vehicle_id: StringName)
## Satın alma olmadı (neden: Status).
signal purchase_failed(vehicle_id: StringName, category: StringName, status: int)

enum Status {
	BUYABLE,        ## alınabilir
	MAXED,          ## EFSANE takılı
	NOT_OWNED,      ## araç oyuncunun değil
	NEEDS_LEVEL,    ## kademenin oyuncu seviyesi yetmiyor
	INSTALLING,     ## bu araca zaten bir parça takılıyor
	NO_BAY,         ## boş tamir alanı yok
	TOO_EXPENSIVE,  ## bakiye yetmiyor
}

## Takmanın HAZIR olup olmadığına bakma aralığı (sn).
const POLL: float = 0.5

## Test / hata ayıklama: saate eklenen sn (süreyi ileri sarmak için).
var clock_offset: float = 0.0

var _builds: Dictionary = {}   # araç id → {kategori: kademe}
var _floors: Dictionary = {}   # araç id → gösterilen 0-100 oranının tabanı
var _jobs: Array[Dictionary] = []   # {car, category, stage, bay, start, end}
var _ready_cars: Dictionary = {}    # HAZIR sinyali verilmiş araçlar
var _poll: float = 0.0


func _ready() -> void:
	add_to_group("performance_mods")
	_publish_all()
	_connect.call_deferred()


func _connect() -> void:
	var ownership: VehicleOwnership = _ownership()
	if ownership:
		ownership.ownership_changed.connect(_on_ownership_changed)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	_check_ready()


func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset


# --- Sorgu ----------------------------------------------------------------------------------

func stage_of(vehicle_id: StringName, category: StringName) -> int:
	return int((_builds.get(vehicle_id, {}) as Dictionary).get(category, 0))


func build_of(vehicle_id: StringName) -> Dictionary:
	return (_builds.get(vehicle_id, {}) as Dictionary).duplicate()


## Bu kategoride sıradaki kademe (EFSANE takılıysa STAGES + 1).
func next_stage(vehicle_id: StringName, category: StringName) -> int:
	return stage_of(vehicle_id, category) + 1


func price(vehicle_id: StringName, category: StringName) -> int:
	var stage: int = next_stage(vehicle_id, category)
	return PerformanceMods.price(vehicle_id, category, stage) if stage <= PerformanceMods.STAGES else 0


## UI'ın tek karar noktası (sıra: sahiplik → tavan → takılıyor → seviye → alan → para).
func status(vehicle_id: StringName, category: StringName) -> Status:
	var ownership: VehicleOwnership = _ownership()
	if ownership and not ownership.is_owned(vehicle_id):
		return Status.NOT_OWNED
	var stage: int = next_stage(vehicle_id, category)
	if stage > PerformanceMods.STAGES:
		return Status.MAXED
	if has_job(vehicle_id):
		return Status.INSTALLING
	if _player_level() < PerformanceMods.required_level(stage):
		return Status.NEEDS_LEVEL
	if _free_bay() < 0:
		return Status.NO_BAY
	var economy: EconomyManager = _economy()
	if economy and not economy.can_afford(PerformanceMods.price(vehicle_id, category, stage)):
		return Status.TOO_EXPENSIVE
	return Status.BUYABLE


func has_job(vehicle_id: StringName) -> bool:
	return _job_index(vehicle_id) >= 0


## Süren takma: {car, category, stage, bay, start, end}; yoksa boş.
func job_of(vehicle_id: StringName) -> Dictionary:
	var i: int = _job_index(vehicle_id)
	return _jobs[i].duplicate() if i >= 0 else {}


func jobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for job: Dictionary in _jobs:
		out.append(job.duplicate())
	return out


## Kalan takma süresi (sn); takma yoksa 0.
func remaining(vehicle_id: StringName) -> float:
	var i: int = _job_index(vehicle_id)
	return maxf(float(_jobs[i]["end"]) - now(), 0.0) if i >= 0 else 0.0


## Takmanın ilerlemesi (0-1).
func progress(vehicle_id: StringName) -> float:
	var i: int = _job_index(vehicle_id)
	if i < 0:
		return 0.0
	var job: Dictionary = _jobs[i]
	var duration: float = maxf(float(job["end"]) - float(job["start"]), 0.001)
	return clampf((now() - float(job["start"])) / duration, 0.0, 1.0)


func is_ready(vehicle_id: StringName) -> bool:
	return has_job(vehicle_id) and remaining(vehicle_id) <= 0.0


## Takmaların kapladığı tamir alanları (RepairManager bunlara müşteri göndermez).
func occupied_bays() -> Array[int]:
	var out: Array[int] = []
	for job: Dictionary in _jobs:
		out.append(int(job["bay"]))
	return out


func job_at_bay(bay: int) -> StringName:
	for job: Dictionary in _jobs:
		if int(job["bay"]) == bay:
			return job["car"]
	return &""


# --- Satın alma / takma ------------------------------------------------------------------------

## Sıradaki kademeyi alır: para düşer, araç ilk boş tamir alanına girer, süre başlar. Herhangi bir adım
## tutmazsa hiçbir şey değişmez (false, purchase_failed).
func purchase(vehicle_id: StringName, category: StringName) -> bool:
	if not PerformanceMods.CATEGORIES.has(category):
		return false
	var gate: Status = status(vehicle_id, category)
	if gate != Status.BUYABLE:
		purchase_failed.emit(vehicle_id, category, gate)
		return false
	var stage: int = next_stage(vehicle_id, category)
	var bay: int = _free_bay()
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(PerformanceMods.price(vehicle_id, category, stage)):
		purchase_failed.emit(vehicle_id, category, Status.TOO_EXPENSIVE)
		return false
	var start: float = now()
	_jobs.append({"car": vehicle_id, "category": category, "stage": stage, "bay": bay, "start": start,
		"end": start + PerformanceMods.install_time(stage)})
	install_started.emit(vehicle_id, category, stage)
	jobs_changed.emit()
	_request_save()
	return true


## HAZIR takmayı bitirir: parça yapıya eklenir, alan boşalır. Süre dolmadıysa false.
func collect(vehicle_id: StringName) -> bool:
	var i: int = _job_index(vehicle_id)
	if i < 0 or float(_jobs[i]["end"]) > now():
		return false
	var job: Dictionary = _jobs[i]
	_jobs.remove_at(i)
	_ready_cars.erase(vehicle_id)
	var category: StringName = job["category"]
	var stage: int = int(job["stage"])
	var old_class: String = PerformanceMods.class_of(vehicle_id)
	# Gösterge tabanı: yeni yapının 0-100'ü öncekinden kötü görünmez
	var floor_ratio: float = float(PerformanceMods.stats(vehicle_id)["zero_100_ratio"])
	var build: Dictionary = PerformanceMods.with_stage(_builds.get(vehicle_id, {}), category,
		maxi(stage, stage_of(vehicle_id, category)))
	_builds[vehicle_id] = build
	var measured: float = PerformanceMods.zero_100_ratio(vehicle_id, build)
	if measured > floor_ratio + 0.00001:
		_floors[vehicle_id] = floor_ratio
	else:
		_floors.erase(vehicle_id)
	_publish(vehicle_id)
	var new_class: String = PerformanceMods.class_of(vehicle_id)
	install_completed.emit(vehicle_id, category, stage, old_class, new_class)
	mods_changed.emit(vehicle_id)
	jobs_changed.emit()
	_request_save()
	return true


## Süren takmayı elmasla bitirmenin fiyatı (kalan süre; HAZIR / takma yoksa 0).
func gem_skip_cost(vehicle_id: StringName) -> int:
	return GemSkip.cost(remaining(vehicle_id)) if has_job(vehicle_id) else 0


## ELMASLA BİTİR: elmas düşer, parça hemen takılır (HAZIR beklenmez; araç alandan çıkar).
## Elmas yetmezse hiçbir şey değişmez (false).
func finish_with_gems(vehicle_id: StringName) -> bool:
	var cost: int = gem_skip_cost(vehicle_id)
	if cost <= 0:
		return false
	var progress_node: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	if progress_node == null or not progress_node.spend_gems(cost):
		return false
	gem_finished.emit(vehicle_id)
	finish_now(vehicle_id)
	return collect(vehicle_id)


## REKLAMLA KISALT (ödüllü reklam, AdPolicy.TIME_SKIP): bu takmadan düşecek süre (sn; takma başına bir kez, kısa
## kalan sürede teklif yok → 0).
func ad_cut(vehicle_id: StringName) -> float:
	var i: int = _job_index(vehicle_id)
	if i < 0 or bool(_jobs[i].get("ad_cut", false)):
		return 0.0
	return AdPolicy.time_cut(remaining(vehicle_id))


## Reklam ödülü: kalan süre ad_cut kadar kısalır, takma işaretlenir (ikinci kez kısaltılmaz).
func apply_ad_cut(vehicle_id: StringName) -> bool:
	var cut: float = ad_cut(vehicle_id)
	if cut <= 0.0:
		return false
	var i: int = _job_index(vehicle_id)
	_jobs[i]["end"] = float(_jobs[i]["end"]) - cut
	_jobs[i]["ad_cut"] = true
	_check_ready()
	jobs_changed.emit()
	_request_save()
	return true


## Kalan süreyi bitirir (test / hata ayıklama; elmasla bitirme de buradan geçer).
func finish_now(vehicle_id: StringName) -> void:
	var i: int = _job_index(vehicle_id)
	if i < 0:
		return
	_jobs[i]["end"] = minf(float(_jobs[i]["end"]), now())
	_check_ready()


func _check_ready() -> void:
	for job: Dictionary in _jobs:
		var id: StringName = job["car"]
		if float(job["end"]) <= now() and not _ready_cars.has(id):
			_ready_cars[id] = true
			install_ready.emit(id)


## Satılan aracın yapısı ve süren takması silinir (para geri dönmez).
func _on_ownership_changed() -> void:
	var ownership: VehicleOwnership = _ownership()
	if ownership == null:
		return
	var changed: Array[StringName] = []
	for id: StringName in _builds.keys():
		if not ownership.is_owned(id):
			_builds.erase(id)
			_floors.erase(id)
			changed.append(id)
	var jobs_gone: bool = false
	for i: int in range(_jobs.size() - 1, -1, -1):
		var id: StringName = _jobs[i]["car"]
		if not ownership.is_owned(id):
			_jobs.remove_at(i)
			_ready_cars.erase(id)
			jobs_gone = true
	for id: StringName in changed:
		_publish(id)
		mods_changed.emit(id)
	if jobs_gone:
		jobs_changed.emit()
	if jobs_gone or not changed.is_empty():
		_request_save()


# --- Kayıt -------------------------------------------------------------------------------------

func state() -> Dictionary:
	var builds: Dictionary = {}
	for id: StringName in _builds:
		var row: Dictionary = {}
		for category: StringName in _builds[id]:
			row[String(category)] = int(_builds[id][category])
		builds[String(id)] = row
	var floors: Dictionary = {}
	for id: StringName in _floors:
		floors[String(id)] = float(_floors[id])
	var jobs_out: Array = []
	for job: Dictionary in _jobs:
		jobs_out.append({"car": String(job["car"]), "category": String(job["category"]), "stage": int(job["stage"]),
			"bay": int(job["bay"]), "start": float(job["start"]), "end": float(job["end"]),
			"ad_cut": bool(job.get("ad_cut", false))})
	return {"builds": builds, "floors": floors, "jobs": jobs_out}


## Kayıttan: katalogda olmayan araç / bilinmeyen kategori atılır; bozuk takma bırakılır. Eski kayıtta yoktur.
func load_state(data: Dictionary) -> void:
	_builds.clear()
	_floors.clear()
	_jobs.clear()
	_ready_cars.clear()
	var builds: Variant = data.get("builds", {})
	if builds is Dictionary:
		for raw: Variant in builds:
			var id: StringName = StringName(SaveSafe.s(raw))
			var row: Variant = (builds as Dictionary)[raw]
			if CarCatalog.get_entry(id).is_empty() or not (row is Dictionary):
				continue
			var clean: Dictionary = PerformanceMods.normalized(row)
			if not clean.is_empty():
				_builds[id] = clean
	var floors: Variant = data.get("floors", {})
	if floors is Dictionary:
		for raw: Variant in floors:
			var id: StringName = StringName(SaveSafe.s(raw))
			var value: float = SaveSafe.f((floors as Dictionary)[raw])
			if _builds.has(id) and value > 0.0 and value < 1.0:
				_floors[id] = value
	var jobs_in: Variant = data.get("jobs", [])
	if jobs_in is Array:
		var used: Dictionary = {}
		for raw: Variant in jobs_in:
			if not (raw is Dictionary):
				continue
			var d: Dictionary = raw
			var id: StringName = StringName(SaveSafe.s(d.get("car", "")))
			var category: StringName = StringName(SaveSafe.s(d.get("category", "")))
			var stage: int = clampi(int(SaveSafe.f(d.get("stage", 0))), 1, PerformanceMods.STAGES)
			var bay: int = int(SaveSafe.f(d.get("bay", -1)))
			if CarCatalog.get_entry(id).is_empty() or not PerformanceMods.CATEGORIES.has(category) \
					or bay < 0 or used.has(bay) or _job_index(id) >= 0:
				continue
			used[bay] = true
			var start: float = SaveSafe.f(d.get("start", now()))
			var end: float = SaveSafe.f(d.get("end", start))
			# Saat geri alınmışsa süre kısalmaz ama sonsuza da uzamaz: en fazla kademenin süresi kalır
			end = minf(end, now() + PerformanceMods.install_time(stage))
			_jobs.append({"car": id, "category": category, "stage": stage, "bay": bay, "start": start, "end": end,
				"ad_cut": SaveSafe.b(d.get("ad_cut", false))})
	_publish_all()
	for id: StringName in _builds:
		mods_changed.emit(id)
	jobs_changed.emit()


## Yeni oyun: yapı yok, takma yok.
func reset() -> void:
	load_state({})


# --- İç ------------------------------------------------------------------------------------------

func _job_index(vehicle_id: StringName) -> int:
	for i: int in _jobs.size():
		if _jobs[i]["car"] == vehicle_id:
			return i
	return -1


## Yarış ve göstergeler PerformanceMods'un statik kopyasını okur.
func _publish(vehicle_id: StringName) -> void:
	PerformanceMods.set_build(vehicle_id, _builds.get(vehicle_id, {}))
	PerformanceMods.set_display_floor(vehicle_id, float(_floors.get(vehicle_id, 1.0)))


func _publish_all() -> void:
	PerformanceMods.clear()
	for id: StringName in _builds:
		_publish(id)


## İlk boş tamir alanı (RepairManager'ın kuralı: tamir işi, restorasyon, takma yok). Sahnesiz (test): 0-2.
func _free_bay() -> int:
	var repair: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager \
		if is_inside_tree() else null
	if repair:
		return repair.free_bay()
	var taken: Array[int] = occupied_bays()
	for i: int in 3:
		if not taken.has(i):
			return i
	return -1


func _player_level() -> int:
	var progress_node: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	return progress_node.level if progress_node else 99


func _ownership() -> VehicleOwnership:
	return get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership if is_inside_tree() else null


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager if is_inside_tree() else null


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager") if is_inside_tree() else null
	if save and save.has_method(&"request_save"):
		save.request_save()
