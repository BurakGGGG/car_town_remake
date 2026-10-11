class_name JunkyardManager
extends Node
## HURDALIK / RESTORASYON durumu: parça envanteri, süren projeler, tamamlanan restorasyonlar.
## Orijinal Car Town Junk Yard'ının kuralları (docs/HURDALIK_ARASTIRMA.md §3, kararlar §7):
##  * Parçalar GENEL ve yığılabilir. Envanterde biriktirilir, projeye "envanterden eklenir".
##  * Proje bir TAMİR ALANINI kaplar ("Requires one available workbay"). O alana müşteri gelmez
##    (RepairManager.free_bay / is_busy projeleri dolu sayar). Alan yoksa proje başlamaz.
##  * İlerleme = takılan parça toplamı / gereken parça toplamı.
##  * %100 olunca finish() aracı garaja verir (VehicleOwnership.add_vehicle) ve alanı boşaltır.
##  * quit() projeyi bırakır: takılmış parçalar envantere geri döner, alan boşalır.
##  * Usta kademeleri, tamamlanmış TEMEL restorasyon sayısıyla açılır (orijinal: 10 → Master Mechanic).
##  * Eksik parça gemle alınabilir (buy_missing). ONAY arayüzün işidir; burası yalnızca hesaplar ve öder.
##
## Kodla kurulur (GarageSystem._ensure_crate_system), "junkyard" grubundan bulunur. Kayıt: SaveManager
## state() / load_state() / reset() üzerinden "junkyard" bölümü (eski kayıtta yoktur: boş envanter).
## Kare başına iş yapmaz.

## Envanter, proje ya da tamamlananlar değişti (kayıt bunu dinler).
signal junkyard_changed
## Envantere parça girdi. source: &"pile" (hurda yığını), &"repair" (tamir işi), &"gift" (arkadaş),
## &"gem" (satın alma), &"refund" (bırakılan projeden dönüş), &"debug".
signal parts_gained(part_id: StringName, amount: int, source: StringName)
signal project_started(vehicle_id: StringName, bay: int)
signal project_progress(vehicle_id: StringName, progress: float)
signal project_completed(vehicle_id: StringName)
signal project_quit(vehicle_id: StringName)
## Bir usta kademesi açıldı (tamamlanan temel restorasyon sayısı eşiği geçti).
signal tier_unlocked(tier_id: StringName)

enum Status { MODEL_PENDING, TIER_LOCKED, AVAILABLE, IN_PROGRESS, READY, COMPLETED }

const BASIC_TIER: StringName = &"basic"
## Envanterde parça başına üst sınır (bozuk / şişirilmiş kayda karşı).
const MAX_STACK: int = 9999

var _inventory: Dictionary = {}          # part_id → adet
var _projects: Array[Dictionary] = []    # {"car": StringName, "bay": int, "installed": {part_id: int}}
var _completed: Array[StringName] = []   # restore edilmiş araçlar (tamamlanma sırasıyla)


func _ready() -> void:
	add_to_group("junkyard")


# --- Envanter ------------------------------------------------------------------------

func part_count(part_id: StringName) -> int:
	return int(_inventory.get(part_id, 0))


func inventory() -> Dictionary:
	return _inventory.duplicate()


func total_parts() -> int:
	var total: int = 0
	for n: Variant in _inventory.values():
		total += int(n)
	return total


## Envantere parça ekler. Bilinmeyen parça ya da adet ≤ 0 → false.
func add_parts(part_id: StringName, amount: int, source: StringName = &"debug") -> bool:
	if amount <= 0 or not RestorationCatalog.is_part(part_id):
		return false
	_inventory[part_id] = mini(part_count(part_id) + amount, MAX_STACK)
	parts_gained.emit(part_id, amount, source)
	junkyard_changed.emit()
	return true


# --- Durum sorguları ------------------------------------------------------------------

func completed_ids() -> Array[StringName]:
	return _completed.duplicate()


func is_completed(vehicle_id: StringName) -> bool:
	return _completed.has(vehicle_id)


## Tamamlanmış TEMEL restorasyon sayısı (usta kademelerinin kilidi buna bakar).
func basic_completed_count() -> int:
	var n: int = 0
	for id: StringName in _completed:
		if RestorationCatalog.tier_of(id) == BASIC_TIER:
			n += 1
	return n


func is_tier_unlocked(tier_id: StringName) -> bool:
	if RestorationCatalog.tier(tier_id).is_empty():
		return false
	return basic_completed_count() >= RestorationCatalog.tier_requirement(tier_id)


func status(vehicle_id: StringName) -> Status:
	if not RestorationCatalog.has_model(vehicle_id):
		return Status.MODEL_PENDING
	if _project_index(vehicle_id) >= 0:
		return Status.READY if progress(vehicle_id) >= 1.0 else Status.IN_PROGRESS
	if is_completed(vehicle_id) and _owned(vehicle_id):
		return Status.COMPLETED
	if not is_tier_unlocked(RestorationCatalog.tier_of(vehicle_id)):
		return Status.TIER_LOCKED
	return Status.AVAILABLE


func projects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in _projects:
		out.append(p.duplicate(true))
	return out


func project_count() -> int:
	return _projects.size()


func has_project(vehicle_id: StringName) -> bool:
	return _project_index(vehicle_id) >= 0


## Projenin kapladığı tamir alanı (yoksa -1).
func bay_of(vehicle_id: StringName) -> int:
	var i: int = _project_index(vehicle_id)
	return int(_projects[i]["bay"]) if i >= 0 else -1


## Proje kaplayan tamir alanlarının indeksleri (RepairManager bunlara müşteri göndermez).
func occupied_bays() -> Array[int]:
	var out: Array[int] = []
	for p: Dictionary in _projects:
		out.append(int(p["bay"]))
	return out


## Bu alandaki projenin aracı (yoksa &"").
func project_at_bay(bay: int) -> StringName:
	for p: Dictionary in _projects:
		if int(p["bay"]) == bay:
			return p["car"]
	return &""


func installed(vehicle_id: StringName, part_id: StringName) -> int:
	var i: int = _project_index(vehicle_id)
	return int((_projects[i]["installed"] as Dictionary).get(part_id, 0)) if i >= 0 else 0


## Bu parçadan daha kaç tane takılmalı.
func missing(vehicle_id: StringName, part_id: StringName) -> int:
	return maxi(RestorationCatalog.required(vehicle_id, part_id) - installed(vehicle_id, part_id), 0)


## 0..1 (proje yoksa 0; tamamlanmışsa 1).
func progress(vehicle_id: StringName) -> float:
	var i: int = _project_index(vehicle_id)
	if i < 0:
		return 1.0 if is_completed(vehicle_id) else 0.0
	var total: int = RestorationCatalog.total_required(vehicle_id)
	if total <= 0:
		return 0.0
	var done: int = 0
	var inst: Dictionary = _projects[i]["installed"]
	for part_id: StringName in RestorationCatalog.recipe(vehicle_id):
		done += mini(int(inst.get(part_id, 0)), RestorationCatalog.required(vehicle_id, part_id))
	return float(done) / float(total)


# --- Proje akışı ---------------------------------------------------------------------

## Proje başlatılabilir mi? bay < 0 → RepairManager'dan ilk boş tamir alanı istenir.
func can_start(vehicle_id: StringName, bay: int = -1) -> bool:
	if status(vehicle_id) != Status.AVAILABLE or _owned(vehicle_id):
		return false
	return _resolve_bay(bay) >= 0


## Restorasyonu başlatır: araç bir tamir alanına yerleşir. Başarısızsa hiçbir şey değişmez.
func start(vehicle_id: StringName, bay: int = -1) -> bool:
	if not can_start(vehicle_id, bay):
		return false
	var target: int = _resolve_bay(bay)
	_projects.append({"car": vehicle_id, "bay": target, "installed": {}})
	project_started.emit(vehicle_id, target)
	junkyard_changed.emit()
	return true


## Envanterden bu parçayı projeye takar (eksik kadar, envanter yettiğince). Takılan adedi döner.
func install(vehicle_id: StringName, part_id: StringName) -> int:
	var i: int = _project_index(vehicle_id)
	if i < 0:
		return 0
	var n: int = mini(missing(vehicle_id, part_id), part_count(part_id))
	if n <= 0:
		return 0
	_inventory[part_id] = part_count(part_id) - n
	if int(_inventory[part_id]) == 0:
		_inventory.erase(part_id)
	_put(i, part_id, n)
	return n


## Envanterdeki tüm uygun parçaları takar. Toplam takılan adedi döner.
func install_all(vehicle_id: StringName) -> int:
	var total: int = 0
	for part_id: StringName in RestorationCatalog.recipe(vehicle_id):
		total += install(vehicle_id, part_id)
	return total


## Bu parçanın eksiğini gemle tamamlamanın bedeli (0 = eksik yok ya da gemle alınamaz).
func missing_gem_cost(vehicle_id: StringName, part_id: StringName) -> int:
	return missing(vehicle_id, part_id) * RestorationCatalog.part_gem_price(part_id)


## Projedeki bütün eksiklerin gem bedeli (önce envanter kullanılır varsayılmaz: arayüz install_all'ı
## önce çağırmalıdır, yoksa envanterde olan parça için de gem ödenir).
func all_missing_gem_cost(vehicle_id: StringName) -> int:
	var total: int = 0
	for part_id: StringName in RestorationCatalog.recipe(vehicle_id):
		total += missing_gem_cost(vehicle_id, part_id)
	return total


## Bu parçanın eksiğini gemle alıp takar. Gem yetmezse ya da eksik yoksa hiçbir şey değişmez.
## ONAY arayüzdedir (orijinaldeki onaysız "Buy All" en çok şikâyet edilen şeydi).
func buy_missing(vehicle_id: StringName, part_id: StringName) -> bool:
	var i: int = _project_index(vehicle_id)
	var n: int = missing(vehicle_id, part_id)
	var cost: int = missing_gem_cost(vehicle_id, part_id)
	if i < 0 or n <= 0 or cost <= 0:
		return false
	var progress_node: PlayerProgress = _progress()
	if progress_node == null or not progress_node.spend_gems(cost):
		return false
	parts_gained.emit(part_id, n, &"gem")
	_put(i, part_id, n)
	return true


## Önce envanterdekileri takar, kalan bütün eksikleri TEK ödemeyle gemle alır. Gem yetmezse yalnızca
## envanterden takılanlar kalır, gem harcanmaz.
func buy_all_missing(vehicle_id: StringName) -> bool:
	var i: int = _project_index(vehicle_id)
	if i < 0:
		return false
	install_all(vehicle_id)
	var cost: int = all_missing_gem_cost(vehicle_id)
	if cost <= 0:
		return progress(vehicle_id) >= 1.0
	var progress_node: PlayerProgress = _progress()
	if progress_node == null or not progress_node.spend_gems(cost):
		return false
	for part_id: StringName in RestorationCatalog.recipe(vehicle_id):
		var n: int = missing(vehicle_id, part_id)
		if n > 0:
			parts_gained.emit(part_id, n, &"gem")
			_put(i, part_id, n)
	return true


## %100 projeyi bitirir: araç garaja (depoya) girer, tamir alanı boşalır.
func finish(vehicle_id: StringName) -> bool:
	var i: int = _project_index(vehicle_id)
	if i < 0 or progress(vehicle_id) < 1.0:
		return false
	var ownership: VehicleOwnership = _ownership()
	if ownership and not ownership.is_owned(vehicle_id) and not ownership.add_vehicle(vehicle_id):
		return false   # katalogda yok (model kaldırılmış): proje bekler
	var before: Array[StringName] = _unlocked_tiers()
	_projects.remove_at(i)
	if not _completed.has(vehicle_id):
		_completed.append(vehicle_id)
	project_completed.emit(vehicle_id)
	for tier_id: StringName in _unlocked_tiers():
		if not before.has(tier_id):
			tier_unlocked.emit(tier_id)
	junkyard_changed.emit()
	return true


## Projeyi bırakır: takılan parçalar envantere döner, tamir alanı boşalır.
func quit(vehicle_id: StringName) -> bool:
	var i: int = _project_index(vehicle_id)
	if i < 0:
		return false
	_refund(_projects[i]["installed"])
	_projects.remove_at(i)
	project_quit.emit(vehicle_id)
	junkyard_changed.emit()
	return true


# --- Kayıt ----------------------------------------------------------------------------

func state() -> Dictionary:
	var parts: Dictionary = {}
	for part_id: StringName in _inventory:
		parts[String(part_id)] = int(_inventory[part_id])
	var projects_out: Array = []
	for p: Dictionary in _projects:
		var inst: Dictionary = {}
		for part_id: StringName in p["installed"]:
			inst[String(part_id)] = int(p["installed"][part_id])
		projects_out.append({"car": String(p["car"]), "bay": int(p["bay"]), "installed": inst})
	var done: Array = []
	for id: StringName in _completed:
		done.append(String(id))
	return {"parts": parts, "projects": projects_out, "completed": done}


## Kayıttan yükler. Bozuk değerler temizlenir: bilinmeyen parça atlanır, adet 0..MAX_STACK'e çekilir,
## bilinmeyen araçlı ya da alanı çakışan proje bırakılır ve takılı parçaları envantere döner.
func load_state(data: Dictionary) -> void:
	_inventory = {}
	_projects = []
	_completed = []
	var parts: Variant = data.get("parts", {})
	if parts is Dictionary:
		for key: Variant in parts:
			var pid: StringName = StringName(str(key))
			var n: int = clampi(SaveSafe.i(parts[key]), 0, MAX_STACK)
			if n > 0 and RestorationCatalog.is_part(pid):
				_inventory[pid] = n
	var done: Variant = data.get("completed", [])
	if done is Array:
		for v: Variant in done:
			var id: StringName = StringName(str(v))
			if RestorationCatalog.is_restoration(id) and not _completed.has(id):
				_completed.append(id)
	var projects_in: Variant = data.get("projects", [])
	if projects_in is Array:
		for raw: Variant in projects_in:
			if not (raw is Dictionary):
				continue
			var car: StringName = StringName(str(raw.get("car", "")))
			var bay: int = SaveSafe.i(raw.get("bay", -1))
			var inst: Dictionary = {}
			var raw_inst: Variant = raw.get("installed", {})
			if raw_inst is Dictionary:
				for key: Variant in raw_inst:
					var pid: StringName = StringName(str(key))
					var need: int = RestorationCatalog.required(car, pid)
					var n: int = clampi(SaveSafe.i(raw_inst[key]), 0, MAX_STACK)
					if n <= 0 or not RestorationCatalog.is_part(pid):
						continue
					inst[pid] = mini(n, need)
					if n > need:   # reçeteden fazlası (reçete küçülmüş) envantere döner
						_add_quiet(pid, n - need)
			var valid: bool = RestorationCatalog.is_restoration(car) and bay >= 0 \
					and _project_index(car) < 0 and not occupied_bays().has(bay)
			if valid:
				_projects.append({"car": car, "bay": bay, "installed": inst})
			else:
				_refund(inst)
	junkyard_changed.emit()


func reset() -> void:
	load_state({})


# --- İç -------------------------------------------------------------------------------

func _project_index(vehicle_id: StringName) -> int:
	for i: int in _projects.size():
		if _projects[i]["car"] == vehicle_id:
			return i
	return -1


func _put(index: int, part_id: StringName, n: int) -> void:
	var p: Dictionary = _projects[index]
	var inst: Dictionary = p["installed"]
	inst[part_id] = int(inst.get(part_id, 0)) + n
	project_progress.emit(p["car"], progress(p["car"]))
	junkyard_changed.emit()


func _refund(inst: Dictionary) -> void:
	for part_id: StringName in inst:
		var n: int = int(inst[part_id])
		if n > 0 and RestorationCatalog.is_part(part_id):
			_add_quiet(part_id, n)
			parts_gained.emit(part_id, n, &"refund")


func _add_quiet(part_id: StringName, n: int) -> void:
	_inventory[part_id] = mini(part_count(part_id) + n, MAX_STACK)


func _unlocked_tiers() -> Array[StringName]:
	var out: Array[StringName] = []
	for t: Dictionary in RestorationCatalog.tiers():
		if is_tier_unlocked(t["id"]):
			out.append(t["id"])
	return out


## bay < 0: RepairManager'ın ilk boş alanı. bay ≥ 0: o alan gerçekten boş ve açık mı.
func _resolve_bay(bay: int) -> int:
	var repair: RepairManager = _repair()
	if repair == null:
		return bay if bay >= 0 and not occupied_bays().has(bay) else -1   # test / sahnesiz kullanım
	if bay < 0:
		return repair.free_bay()
	return bay if repair.is_bay_free(bay) else -1


func _owned(vehicle_id: StringName) -> bool:
	var ownership: VehicleOwnership = _ownership()
	return ownership != null and ownership.is_owned(vehicle_id)


func _repair() -> RepairManager:
	return get_tree().get_first_node_in_group("repair_manager") as RepairManager if is_inside_tree() else null


func _ownership() -> VehicleOwnership:
	return get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership if is_inside_tree() else null


func _progress() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress if is_inside_tree() else null
