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
##
## SAHA (docs/HURDALIK_TASARIM.md §4–5):
##  * Sahada günün araçları durur (yard_cars): her YEREL GECE YARISI yeniden çekilir. Havuz = açık
##    kademelerin modeli hazır, henüz restore edilmemiş ve projede olmayan araçları. Çekiliş günden ve
##    oyuncuya özel bir tuzdan türetilir: oyun yeniden açılınca aynı araçlar durur. Dünkülerden
##    kaçınılır (havuz yetiyorsa). Başlatılan araç sahadan kalkar, yeri yenilenene kadar boş kalır.
##  * Aranabilir yığınlar (search_pile): aranan yığın refill_minutes sonra yeniden dolar. Sonuç saf şans:
##    empty_chance ile boş, değilse parts_min..parts_max parça — AÇIK kademelerin reçetelerinde geçen
##    parçalardan eşit olasılıkla (temel oyuncuya kullanamayacağı fiberglas düşmesin). İLK arama her
##    zaman doludur (Cemo'nun dersi). Kurallar restorations.json "yard" (ekonomi simülasyonu ayarlar).
##  * Tamirden düşme: hurdalık açıksa PARA TOPLA ile biten her tamirde repair_drop olasılıkla 1 parça
##    (aynı havuzdan; parts_gained kaynağı &"repair").
##  * Arkadaştan isteme (orijinal "Ask Friends", kullanıcı kararı 2026-10-12): oyuncu bir parçayı
##    ASK_COOLDOWN'da bir İSTER (set_ask); istek açık garajda ASK_LIFETIME boyunca görünür (SocialManager
##    yayınlar). Gelen hediyeler (SocialManager.collect_gifts) bir kez eklensin diye kimlikleri burada,
##    kayıtta hatırlanır (gift_seen): sunucu bugünün hediyesini silmeye izin vermez.
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
## Sahadaki araçlar ya da yığınların durumu değişti (yenilenme, arama, başlatılan araç).
signal yard_changed
## Hurdalık açıldı (OPEN_BAYS'inci tamir alanı satın alındı). Bir kez.
signal opened
## Oyuncu hurdalığa geldi (harita yolculuğu).
signal visited(count: int)
## Yığın arandı. parts: {part_id: adet}; boşsa hiçbir şey çıkmadı.
signal pile_searched(index: int, parts: Dictionary)

enum Status { MODEL_PENDING, TIER_LOCKED, AVAILABLE, IN_PROGRESS, READY, COMPLETED }

const BASIC_TIER: StringName = &"basic"
## Hurdalık bu kadar tamir alanı açılınca açılır (docs/HURDALIK_TASARIM.md §1): proje bir alanı
## kapladığı için tamir hiç durmaz.
const OPEN_BAYS: int = 2
## Arkadaştan parça isteme aralığı ve isteğin açık garajda görünme süresi (sn).
const ASK_COOLDOWN: int = 6 * 3600
const ASK_LIFETIME: int = 24 * 3600
## Hatırlanan en çok hediye kimliği (eski kayıtlar düşer).
const MAX_SEEN_GIFTS: int = 400
## Envanterde parça başına üst sınır (bozuk / şişirilmiş kayda karşı).
const MAX_STACK: int = 9999

var _inventory: Dictionary = {}          # part_id → adet
var _projects: Array[Dictionary] = []    # {"car": StringName, "bay": int, "installed": {part_id: int}}
var _completed: Array[StringName] = []   # restore edilmiş araçlar (tamamlanma sırasıyla)
var _yard_day: int = -1                    # sahanın çekildiği yerel gün
var _yard_cars: Array[StringName] = []     # o gün çekilen araçlar (başlatılanlar da listede kalır)
var _yard_prev: Array[StringName] = []     # önceki çekiliş (dünküler tekrar gelmesin)
var _yard_salt: int = 0                    # oyuncuya özel çekiliş tuzu (ilk kullanımda üretilir)
var _pile_ready_at: Array[int] = []        # yığın başına yeniden dolma anı (unix; ≤ şimdi → dolu)
var _searches: int = 0                     # toplam arama (ilki her zaman dolu)
var _visits: int = 0                       # hurdalığa kaç kez gelindi
var _ask: Dictionary = {}                  # {"part": StringName, "at": unix} — arkadaşlardan istenen parça
var _gift_seen: Array[String] = []         # toplanmış hediye belge kimlikleri
## Test: -1 değilse saat ve gün bundan (GemRewards yoksa).
var test_now: int = -1


func _ready() -> void:
	add_to_group("junkyard")
	_connect.call_deferred()   # tamir alanı yöneticisi hazır olsun


func _connect() -> void:
	var repair: RepairManager = _repair()
	if repair:
		repair.repair_collected.connect(func(_car: Node3D, _reward: int, _xp: int) -> void: roll_repair_drop())
	var bays: RepairBayManager = _bays()
	if bays:
		bays.bay_unlocked.connect(func(_index: int) -> void:
			if bays.unlocked_count() == OPEN_BAYS:
				opened.emit())


# --- Kilit / ziyaret --------------------------------------------------------------------

## Hurdalık açık mı (OPEN_BAYS tamir alanı satın alınmış mı)? Tamir alanı yöneticisi yoksa (test) açık.
func is_open() -> bool:
	var bays: RepairBayManager = _bays()
	return bays == null or bays.unlocked_count() >= OPEN_BAYS


## Harita yolculuğu hurdalığa vardı.
func record_visit() -> void:
	_visits += 1
	visited.emit(_visits)
	junkyard_changed.emit()


func visit_count() -> int:
	return _visits


# --- Arkadaştan isteme / hediye ------------------------------------------------------------

## Açık (süresi dolmamış) istek: {"part", "at"} ya da boş.
func current_ask() -> Dictionary:
	if _ask.is_empty() or _now() - int(_ask.get("at", 0)) >= ASK_LIFETIME:
		return {}
	return _ask.duplicate()


## Yeni istek için kalan süre (0 = istenebilir).
func ask_seconds_left() -> int:
	if _ask.is_empty():
		return 0
	return maxi(int(_ask.get("at", 0)) + ASK_COOLDOWN - _now(), 0)


func can_ask() -> bool:
	return ask_seconds_left() <= 0


## Arkadaşlardan bu parçayı ister (yayınlamak SocialManager'ın işi). Bekleme sürüyorsa false.
func set_ask(part_id: StringName) -> bool:
	if not can_ask() or not RestorationCatalog.is_part(part_id):
		return false
	_ask = {"part": part_id, "at": _now()}
	junkyard_changed.emit()
	return true


## Yayınlanamayan isteği geri alır (SocialManager): bekleme sıfırlanır, oyuncu yeniden isteyebilir.
func clear_ask() -> void:
	_ask = {}
	junkyard_changed.emit()


func gift_seen(gift_id: String) -> bool:
	return _gift_seen.has(gift_id)


## Arkadaştan gelen hediye: bir kez eklenir (aynı kimlik ikinci kez gelirse false).
func receive_gift(gift_id: String, part_id: StringName) -> bool:
	if gift_id.is_empty() or _gift_seen.has(gift_id) or not RestorationCatalog.is_part(part_id):
		return false
	_gift_seen.append(gift_id)
	while _gift_seen.size() > MAX_SEEN_GIFTS:
		_gift_seen.pop_front()
	return add_parts(part_id, 1, &"gift")


## Sunucudan temizlenen eski hediye kimliği artık hatırlanmaz.
func forget_gift(gift_id: String) -> void:
	_gift_seen.erase(gift_id)


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
	if _yard_cars.has(vehicle_id):
		yard_changed.emit()   # sahadan kalkar
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


# --- Saha: günün araçları ------------------------------------------------------------------

## Sahadaki araçlar, yer sırasıyla (restorations.json yard "daily_cars" kadar). Başlatılan ya da
## restore edilen aracın yeri &"" (boş) döner. Gün değiştiyse önce yeniden çekilir.
func yard_cars() -> Array[StringName]:
	_ensure_yard()
	var out: Array[StringName] = []
	for id: StringName in _yard_cars:
		out.append(id if status(id) == Status.AVAILABLE and not _owned(id) else &"")
	return out


## Sahadaki araçların yenilenmesine (yerel gece yarısı) kalan saniye.
func seconds_to_yard_refresh() -> int:
	var unix: int = _now()
	return clampi(_day_start(_day_of(unix) + 1) - unix, 0, 86400)


## Restorasyon havuzu: açık kademelerin modeli hazır, hiç restore edilmemiş, projede olmayan araçları.
func yard_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Dictionary in RestorationCatalog.cars():
		var id: StringName = entry["id"]
		if is_completed(id) or has_project(id) or _owned(id):
			continue
		if is_tier_unlocked(entry["tier"]):
			out.append(id)
	return out


func _ensure_yard() -> void:
	var day: int = _day_of(_now())
	if day < _yard_day:
		return   # saat geri alındı: saha geri gitmez
	if day == _yard_day and not _yard_cars.is_empty():
		return
	if _yard_salt == 0:
		_yard_salt = randi_range(1, 0x7FFFFFFF)
	if day != _yard_day and not _yard_cars.is_empty():
		_yard_prev = _yard_cars.duplicate()
	_yard_day = day
	_yard_cars = _roll_yard(day)
	yard_changed.emit()
	junkyard_changed.emit()


func _roll_yard(day: int) -> Array[StringName]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([day, _yard_salt])
	var pool: Array[StringName] = yard_pool()
	var fresh: Array[StringName] = []
	for id: StringName in pool:
		if not _yard_prev.has(id):
			fresh.append(id)
	var count: int = RestorationCatalog.yard_int("daily_cars")
	var out: Array[StringName] = []
	# Önce dün sahada olmayanlardan, yetmezse bütün havuzdan
	for source: Array[StringName] in [fresh, pool]:
		var bag: Array[StringName] = source.duplicate()
		while out.size() < count and not bag.is_empty():
			var id: StringName = bag.pop_at(rng.randi_range(0, bag.size() - 1))
			if not out.has(id):
				out.append(id)
	return out


# --- Saha: hurda yığınları ------------------------------------------------------------------

func pile_count() -> int:
	return RestorationCatalog.yard_int("piles")


func pile_ready(index: int) -> bool:
	return index >= 0 and index < pile_count() and pile_seconds_left(index) <= 0


## Yığının yeniden dolmasına kalan saniye (0 = aranabilir).
func pile_seconds_left(index: int) -> int:
	if index < 0 or index >= _pile_ready_at.size():
		return 0
	return maxi(_pile_ready_at[index] - _now(), 0)


## En yakın dolacak yığına kalan saniye (boş yığın yoksa 0).
func next_pile_seconds() -> int:
	var best: int = 0
	for i: int in pile_count():
		var left: int = pile_seconds_left(i)
		if left > 0 and (best == 0 or left < best):
			best = left
	return best


## REKLAMLA DOLDUR (ödüllü reklam, AdPolicy.JUNK_REFILL): en yakın dolacak boş yığın hemen dolar. Dönen: dolan yığın
## (-1 = boş yığın yok).
func refill_pile() -> int:
	var best: int = -1
	var best_left: int = 0
	for i: int in pile_count():
		var left: int = pile_seconds_left(i)
		if left > 0 and (best < 0 or left < best_left):
			best = i
			best_left = left
	if best < 0:
		return -1
	_pile_ready_at[best] = _now()
	yard_changed.emit()
	junkyard_changed.emit()
	return best


## Yığının dolduğu / dolacağı an (unix sn; 0 = hiç aranmadı). OTO MANŞET "sen yokken doldu" haberine bakar.
func pile_ready_at(index: int) -> int:
	return _pile_ready_at[index] if index >= 0 and index < _pile_ready_at.size() else 0


func ready_pile_count() -> int:
	var n: int = 0
	for i: int in pile_count():
		if pile_ready(i):
			n += 1
	return n


## Yığını arar: bulunanları envantere ekler, yığın refill_minutes boyunca boş kalır (boş arama da
## yığını boşaltır). Dönüş {"ok": arandı mı, "parts": {part_id: adet}} — parts boşsa bir şey çıkmadı.
func search_pile(index: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if not pile_ready(index):
		return {"ok": false, "parts": {}}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	while _pile_ready_at.size() < pile_count():
		_pile_ready_at.append(0)
	var found: Dictionary = {}
	var first: bool = _searches == 0
	_searches += 1
	if first or rng.randf() >= RestorationCatalog.yard_rule("empty_chance"):
		var pool: Array[StringName] = droppable_parts()
		var n: int = rng.randi_range(RestorationCatalog.yard_int("parts_min"), RestorationCatalog.yard_int("parts_max"))
		for k: int in n:
			if pool.is_empty():
				break
			var part_id: StringName = pool[rng.randi_range(0, pool.size() - 1)]
			found[part_id] = int(found.get(part_id, 0)) + 1
	_pile_ready_at[index] = _now() + RestorationCatalog.yard_int("refill_minutes") * 60
	for part_id: StringName in found:
		_add_quiet(part_id, int(found[part_id]))
		parts_gained.emit(part_id, int(found[part_id]), &"pile")
	pile_searched.emit(index, found)
	yard_changed.emit()
	junkyard_changed.emit()
	return {"ok": true, "parts": found}


## Yığınlardan düşebilen parçalar: AÇIK kademelerin reçetelerinde geçenler (katalog sırasıyla).
func droppable_parts() -> Array[StringName]:
	var used: Dictionary = {}
	for entry: Dictionary in RestorationCatalog.cars():
		if is_tier_unlocked(entry["tier"]):
			for part_id: StringName in entry["recipe"]:
				used[part_id] = true
	var out: Array[StringName] = []
	for part_id: StringName in RestorationCatalog.part_ids():
		if used.has(part_id):
			out.append(part_id)
	return out


func search_count() -> int:
	return _searches


## Biten tamir: hurdalık açıksa repair_drop olasılıkla 1 parça düşer. Düşen parça (yoksa &"").
func roll_repair_drop(rng: RandomNumberGenerator = null) -> StringName:
	if not is_open():
		return &""
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if rng.randf() >= RestorationCatalog.yard_rule("repair_drop"):
		return &""
	var pool: Array[StringName] = droppable_parts()
	if pool.is_empty():
		return &""
	var part_id: StringName = pool[rng.randi_range(0, pool.size() - 1)]
	add_parts(part_id, 1, &"repair")
	return part_id


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
	var yard_cars_out: Array = []
	for id: StringName in _yard_cars:
		yard_cars_out.append(String(id))
	var yard_prev_out: Array = []
	for id: StringName in _yard_prev:
		yard_prev_out.append(String(id))
	return {"parts": parts, "projects": projects_out, "completed": done, "yard": {
		"day": _yard_day, "cars": yard_cars_out, "prev": yard_prev_out, "salt": _yard_salt,
		"piles": _pile_ready_at.duplicate(), "searches": _searches, "visits": _visits,
		"ask": {"part": String(_ask.get("part", "")), "at": int(_ask.get("at", 0))} if not _ask.is_empty() else {},
		"gift_seen": _gift_seen.duplicate(),
	}}


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
	_load_yard(data.get("yard", {}))
	junkyard_changed.emit()


func _load_yard(raw: Variant) -> void:
	_yard_day = -1
	_yard_cars = []
	_yard_prev = []
	_yard_salt = 0
	_pile_ready_at = []
	_searches = 0
	_visits = 0
	_ask = {}
	_gift_seen = []
	if not (raw is Dictionary):
		return
	var ask: Variant = raw.get("ask", {})
	if ask is Dictionary and RestorationCatalog.is_part(StringName(SaveSafe.s(ask.get("part", "")))):
		_ask = {"part": StringName(SaveSafe.s(ask.get("part", ""))),
			"at": clampi(SaveSafe.i(ask.get("at", 0)), 0, _now())}   # gelecekten gelen zaman beklemeyi uzatmasın
	var seen: Variant = raw.get("gift_seen", [])
	if seen is Array:
		for v: Variant in seen:
			var id: String = SaveSafe.s(v)
			if id.begins_with("p_") and not _gift_seen.has(id) and _gift_seen.size() < MAX_SEEN_GIFTS:
				_gift_seen.append(id)
	_visits = maxi(SaveSafe.i(raw.get("visits", 0)), 0)
	_yard_day = SaveSafe.i(raw.get("day", -1))
	_yard_salt = clampi(SaveSafe.i(raw.get("salt", 0)), 0, 0x7FFFFFFF)
	_searches = maxi(SaveSafe.i(raw.get("searches", 0)), 0)
	for key: String in ["cars", "prev"]:
		var list: Variant = raw.get(key, [])
		if not (list is Array):
			continue
		for v: Variant in list:
			var id: StringName = StringName(str(v))
			if RestorationCatalog.is_restoration(id):
				(_yard_cars if key == "cars" else _yard_prev).append(id)
	var piles: Variant = raw.get("piles", [])
	if piles is Array:
		# Kayıttan gelen dolma anı, şimdiden bir tam süreden ileride olamaz (bozuk / oynanmış kayıt)
		var limit: int = _now() + RestorationCatalog.yard_int("refill_minutes") * 60
		for v: Variant in piles:
			if _pile_ready_at.size() >= 6:
				break
			_pile_ready_at.append(clampi(SaveSafe.i(v), 0, limit))


func reset() -> void:
	load_state({})


# --- İç -------------------------------------------------------------------------------

func _now() -> int:
	var gem: GemRewards = _gem()
	if gem:
		return gem.now_unix()
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())


func _day_of(unix: int) -> int:
	var gem: GemRewards = _gem()
	if gem:
		return gem.day_key(unix)
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return floori(float(unix + bias_min * 60) / 86400.0)


## Yerel günün başladığı unix anı (_day_of'un tersi).
func _day_start(day: int) -> int:
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return day * 86400 - bias_min * 60


func _bays() -> RepairBayManager:
	return get_tree().get_first_node_in_group("repair_bays") as RepairBayManager if is_inside_tree() else null


func _gem() -> GemRewards:
	return get_tree().get_first_node_in_group("gem_rewards") as GemRewards if is_inside_tree() else null


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
