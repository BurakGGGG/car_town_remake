class_name CollectionRewards
extends Node
## KOLEKSİYON ÖDÜLLERİ (2026-10-25; planlar/Auto Yard Özellik Raporu P1, kullanıcının soru-cevap kararları):
##   SET          CrateCatalog.sets() (21 set; hurdalık klasikleri de setlerde). Setin bütün araçlarına BİR KEZ sahip olmak
##                yeter (keşif: sonra satılsa da sayılır). Ödül elmas + ₺, setteki araçların NADİRLİĞİNE göre araç başına
##                toplanır (SET_GEMS / SET_MONEY); hurdalık klasiklerinin nadirliği kademesinden (basit nadir, klasik epik,
##                yarış efsanevi). Her set bir kez.
##   KİLOMETRE    keşfedilen araç sayısı (kasa + hurdalık: edinilebilir bütün katalog) 10 / 20 / 35 / 50 / 72 → elmas.
##   TAM KOLEKSİYON  son taş (72): ayrıca KOLEKSİYONER çerçevesi + KOLEKSİYONER KUPASI (dekor, mağazada yok) + unvanı.
## Ödül araç keşfedilir keşfedilmez hesaba geçer (VehicleOwnership.vehicle_discovered); `rewarded` → HUD sayaçları bekletir,
## SET TAMAMLANDI! ekranı (CollectionRewardScreen) oyun sakinken açılır, TOPLA'da paralar sayaçlara uçar.
## Durum kayıtta ("collection"); eski kayıtta bu bölüm yoksa bugün tamam olanlar ÖDÜLSÜZ işaretlenir (mark_existing).
## Eski kasa kilometre taşları (CrateManager 5/10/14/16, yalnız kasa araçları) bunun yerine geçti.
## GarageSystem kurar (SaveManager'dan önce), "collection_rewards" grubundan bulunur.

## Yeni ödül(ler): {sets: Array[StringName], milestones: Array[int], money, gems, final: bool}.
signal rewarded(entry: Dictionary)

## Set ödülü, araç başına (nadirliğe göre): elmas ve ₺ (kullanıcı kararı: elmas "daha cimri", ×0,6).
const SET_GEMS: Dictionary = {&"common": 2, &"rare": 5, &"epic": 9, &"legendary": 18}
const SET_MONEY: Dictionary = {&"common": 5000, &"rare": 10000, &"epic": 20000, &"legendary": 40000}
## Hurdalık klasiklerinin set ödülündeki nadirliği (restorasyon kademesi → nadirlik).
const RESTORATION_RARITY: Dictionary = {&"basic": &"rare", &"classic": &"epic", &"race": &"legendary"}
## Kilometre taşları: keşfedilen araç sayısı → elmas. En büyüğü TAM KOLEKSİYON.
const MILESTONES: Dictionary = {10: 10, 20: 20, 35: 40, 50: 80, 72: 150}
const FINAL_FRAME: String = "collector"
const FINAL_DECOR: StringName = &"collector_trophy"
const FINAL_HONOR: String = "collector"

var _paid_sets: Array[StringName] = []
var _paid_milestones: Array[int] = []
var _ownership: VehicleOwnership


func _ready() -> void:
	add_to_group("collection_rewards")
	_connect.call_deferred()


func _connect() -> void:
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if _ownership:
		_ownership.vehicle_discovered.connect(func(_id: StringName) -> void: check())


## Yeni tamamlanan set / geçilen taş varsa ödülü öder ve `rewarded` yayar. Ödenen özet ya da boş.
func check() -> Dictionary:
	if _ownership == null:
		return {}
	var entry: Dictionary = _pending()
	if entry.is_empty():
		return {}
	_pay(entry)
	rewarded.emit(entry)
	return entry


## Bugün tamam olan setler ve geçilmiş taşlar ödülsüz işaretlenir (bu bölümü olmayan eski kayıt).
func mark_existing() -> void:
	if _ownership == null:
		_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var entry: Dictionary = _pending()
	for set_id: StringName in entry.get("sets", []):
		_paid_sets.append(set_id)
	for count: int in entry.get("milestones", []):
		_paid_milestones.append(count)


func is_set_paid(set_id: StringName) -> bool:
	return _paid_sets.has(set_id)


func is_milestone_paid(count: int) -> bool:
	return _paid_milestones.has(count)


func _pending() -> Dictionary:
	var sets: Array[StringName] = []
	var milestones: Array[int] = []
	var money: int = 0
	var gems: int = 0
	for set_entry: Dictionary in CrateCatalog.sets():
		var set_id: StringName = set_entry["id"]
		if _paid_sets.has(set_id) or not set_complete(set_entry, _ownership):
			continue
		sets.append(set_id)
		var reward: Dictionary = set_reward(set_entry)
		money += int(reward["money"])
		gems += int(reward["gems"])
	var found: int = found_count(_ownership)
	var final: bool = false
	for count: int in milestone_list():
		if found >= count and not _paid_milestones.has(count):
			milestones.append(count)
			gems += int(MILESTONES[count])
			final = final or count == final_milestone()
	if sets.is_empty() and milestones.is_empty():
		return {}
	return {"sets": sets, "milestones": milestones, "money": money, "gems": gems, "final": final}


func _pay(entry: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	for set_id: StringName in entry["sets"]:
		_paid_sets.append(set_id)
	for count: int in entry["milestones"]:
		_paid_milestones.append(count)
	var economy: EconomyManager = tree.get_first_node_in_group("economy") as EconomyManager
	if economy and int(entry["money"]) > 0:
		economy.add_money(int(entry["money"]))
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress and int(entry["gems"]) > 0:
		progress.add_gems(int(entry["gems"]))
	if entry["final"]:
		var profile: PlayerProfile = tree.get_first_node_in_group("player_profile") as PlayerProfile
		if profile:
			profile.grant_frame(FINAL_FRAME)
			profile.grant_honor(FINAL_HONOR)
		var decor: DecorManager = tree.get_first_node_in_group("decor") as DecorManager
		if decor:
			decor.grant(FINAL_DECOR, 1)
	var save: SaveManager = tree.get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.save_game()


# --- Kurallar (statik: koleksiyon ekranı ve testler de kullanır) -------------------------

## Setin bütün araçlarına bir kez sahip olunmuş mu.
static func set_complete(set_entry: Dictionary, ownership: VehicleOwnership) -> bool:
	if ownership == null:
		return false
	var cars: Array = set_entry["cars"]
	for car: StringName in cars:
		if not ownership.is_discovered(car):
			return false
	return not cars.is_empty()


## Setin ödülü: {gems, money} — araç başına nadirliğine göre toplam.
static func set_reward(set_entry: Dictionary) -> Dictionary:
	var gems: int = 0
	var money: int = 0
	for car: StringName in set_entry["cars"]:
		var rarity: StringName = car_rarity(car)
		gems += int(SET_GEMS.get(rarity, 0))
		money += int(SET_MONEY.get(rarity, 0))
	return {"gems": gems, "money": money}


## Aracın set ödülündeki nadirliği: kasa aracı kendi nadirliği, hurdalık klasiği kademesinden.
static func car_rarity(car: StringName) -> StringName:
	if RestorationCatalog.is_restoration(car):
		return RESTORATION_RARITY.get(RestorationCatalog.tier_of(car), &"rare")
	return CrateCatalog.rarity_of(car)


## Keşfedilen araç sayısı: edinilebilir bütün katalog (kasa + hurdalık).
static func found_count(ownership: VehicleOwnership) -> int:
	if ownership == null:
		return 0
	var n: int = 0
	for car: StringName in ownership.discovered_ids():
		if CarCatalog.is_obtainable(car):
			n += 1
	return n


## Toplanabilecek araç sayısı (edinilebilir bütün katalog).
static func total_count() -> int:
	var n: int = 0
	for entry: Dictionary in CarCatalog.all():
		if CarCatalog.is_obtainable(StringName(String(entry["id"]))):
			n += 1
	return n


static func milestone_list() -> Array[int]:
	var out: Array[int] = []
	for count: Variant in MILESTONES:
		out.append(int(count))
	out.sort()
	return out


static func final_milestone() -> int:
	return milestone_list().back()


# --- Kayıt (SaveManager) ---------------------------------------------------------------

func state() -> Dictionary:
	var sets: Array[String] = []
	for set_id: StringName in _paid_sets:
		sets.append(String(set_id))
	return {"sets": sets, "milestones": _paid_milestones.duplicate()}


func load_state(data: Dictionary) -> void:
	_paid_sets.clear()
	_paid_milestones.clear()
	for set_id: Variant in (data.get("sets", []) if data.get("sets") is Array else []):
		var id: StringName = StringName(SaveSafe.s(set_id))
		if not id.is_empty() and not _paid_sets.has(id):
			_paid_sets.append(id)
	for count: Variant in (data.get("milestones", []) if data.get("milestones") is Array else []):
		var n: int = SaveSafe.i(count)
		if MILESTONES.has(n) and not _paid_milestones.has(n):
			_paid_milestones.append(n)


func reset() -> void:
	_paid_sets.clear()
	_paid_milestones.clear()
