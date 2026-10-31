class_name PetManager
extends Node
## GARAJ DOSTLARI (2026-10-31) — evcil hayvanın VERİSİ: sahiplik, ad, dostluk, açılan numaralar, aksesuarlar ve geliş
## zamanı. GarageSystem kodla kurar ("pets" grubu, SaveManager'dan ÖNCE); kayıt "pets". Görünüm (garajda dolaşan kedi)
## world/pets/pet_world.gd'dedir; bu sınıf sahneye dokunmaz.
##
## Kullanıcı kararları (2026-10-31, bkz. docs/EVCIL_HAYVAN_RAPORU.md ve hafıza "garaj-dostlari"):
##   - Tek hayvan: TEKİR (turuncu tekir kedi), ANA garajda yaşar.
##   - SEVİYE ARRIVAL_LEVEL ödülü. Seviyeyi o an geçen oyuncuda geliş hemen hazır olur; güncellemeden önce zaten geçmiş
##     eski oyuncu kediyi BİR SONRAKİ seviye atlayışında alır (açılışta kendiliğinden gelmez).
##   - Ad ZORUNLU (ad ekranında süzgeçten geçer); ödül YOK, yalnız eğlence. Sevdikçe dostluk artar, numaralar açılır,
##     hiçbir şey düşmez (bakım yükü / ceza yok).
##   - Aksesuarlar yalnız elmasla (150–400).

## Kedi gelmeye hazır (geliş sinyali sahnesini / ad ekranını açar). Bekleyen geliş açılışta da yeniden yayınlanabilir.
signal arrival_ready
## Kedi sahiplenildi (ad verildi).
signal adopted(pet_name: String)
signal name_changed(pet_name: String)
## Dostluk puanı değişti.
signal friendship_changed(points: int)
## Yeni numara açıldı (ilk kez).
signal trick_unlocked(trick: StringName)
## Aksesuar alındı / takıldı / çıkarıldı.
signal accessories_changed

const ARRIVAL_LEVEL: int = 5
const DEFAULT_NAME: String = "Tekir"
const NAME_MAX: int = 14
## Sevme sayılırken iki dokunuş arasında en az bu kadar sn (art arda dokunmak puanı şişirmesin)
const PET_COOLDOWN: float = 1.2
## Günde en çok bu kadar sevgi puanı (sevme + olta atlayışı birlikte). Kullanıcı kararı (2026-10-31): "sınırsız sevip
## hemen 60 oluyor, güzel değil" → günde 5: numaralar 2., 6., 12. günde açılır. Sınır dolunca sevmek yine kalp ve tepki
## verir, yalnız puan saymaz; arayüz sınırı SÖYLEMEZ (kullanıcı: "kendi fark etsin"). Gün = cihazın yerel tarihi.
const DAILY_LOVE: int = 5
## Numaralar ve açıldıkları dostluk puanı (sıra = açılış sırası). Klip adları assets/pets/tekir.glb'dedir.
const TRICKS: Array[Dictionary] = [
	{"id": &"trick_paw", "points": 10},
	{"id": &"trick_beg", "points": 30},
	{"id": &"trick_roll", "points": 60},
]

## Aksesuarlar (yalnız elmas; kullanıcı kararı 150–400). Yuva başına bir tane takılır: BOYUN (tasma / bandana) ve
## BAŞ (kasket / kask). Modeller assets/pets/acc/<id>.glb + raf simgesi icon_<id>.png (tools/pets/tekir_acc.py).
const ACCESSORIES: Array[Dictionary] = [
	{"id": &"collar_red", "name": "TASMA", "slot": &"neck", "gems": 150},
	{"id": &"bandana", "name": "BANDANA", "slot": &"neck", "gems": 200},
	{"id": &"cap", "name": "USTA KEPİ", "slot": &"head", "gems": 250},
	{"id": &"helmet", "name": "KASK", "slot": &"head", "gems": 400},
]

var _adopted: bool = false
var _name: String = ""
var _friendship: int = 0
var _arrival_pending: bool = false
var _accessories: Array[StringName] = []
var _equipped: Dictionary = {}        # yuva (String) → aksesuar kimliği (StringName)
var _last_pet_msec: int = -100000
var _love_day: String = ""       # günlük sayacın günü (YYYY-AA-GG)
var _love_today: int = 0


func _ready() -> void:
	add_to_group("pets")
	_connect_progress.call_deferred()


func _connect_progress() -> void:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress and not progress.level_up.is_connected(_on_level_up):
		progress.level_up.connect(_on_level_up)


# --- Sorgular -------------------------------------------------------------------------------

func is_adopted() -> bool:
	return _adopted


func pet_name() -> String:
	return _name if _adopted else ""


func friendship() -> int:
	return _friendship


func is_arrival_pending() -> bool:
	return _arrival_pending and not _adopted


func unlocked_tricks() -> Array[StringName]:
	var out: Array[StringName] = []
	for t: Dictionary in TRICKS:
		if _friendship >= int(t["points"]):
			out.append(t["id"])
	return out


func is_trick_unlocked(trick: StringName) -> bool:
	return unlocked_tricks().has(trick)


## Bugün sayılan sevgi puanı ve kalan hak.
func love_today() -> int:
	_roll_day()
	return _love_today


func love_left() -> int:
	return maxi(DAILY_LOVE - love_today(), 0)


func _roll_day() -> void:
	var today: String = Time.get_date_string_from_system()
	if today != _love_day:
		_love_day = today
		_love_today = 0


## Sıradaki numara ve kaç puan kaldığı ({} = hepsi açık).
func next_trick() -> Dictionary:
	for t: Dictionary in TRICKS:
		if _friendship < int(t["points"]):
			return {"id": t["id"], "points": int(t["points"]), "left": int(t["points"]) - _friendship}
	return {}


func owns_accessory(id: StringName) -> bool:
	return _accessories.has(id)


static func accessory(id: StringName) -> Dictionary:
	for a: Dictionary in ACCESSORIES:
		if a["id"] == id:
			return a
	return {}


static func slot_of(id: StringName) -> StringName:
	return StringName(accessory(id).get("slot", &""))


func is_worn(id: StringName) -> bool:
	return id != &"" and equipped(slot_of(id)) == id


## Takılı aksesuarlar (yuva sırası: boyun, baş).
func worn() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot: StringName in [&"neck", &"head"]:
		var id: StringName = equipped(slot)
		if id != &"":
			out.append(id)
	return out


func equipped(slot: StringName) -> StringName:
	return _equipped.get(String(slot), &"")


# --- Eylemler -------------------------------------------------------------------------------

## Ad verip sahiplenir (ad ekranı süzgeçten geçirmiş olmalı). Boş ad reddedilir.
func adopt(new_name: String) -> bool:
	var clean: String = new_name.strip_edges().substr(0, NAME_MAX)
	if clean.is_empty():
		return false
	var first: bool = not _adopted
	_adopted = true
	_name = clean
	_arrival_pending = false
	_request_save()
	if first:
		adopted.emit(_name)
	else:
		name_changed.emit(_name)
	return true


## Sevme dokunuşu. Bekleme süresi içindeki ya da günlük sınır (DAILY_LOVE) dolduktan sonraki dokunuş tepki oynatır
## ama puan saymaz. Puan sayıldıysa true.
func pet() -> bool:
	if not _adopted:
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last_pet_msec < int(PET_COOLDOWN * 1000.0):
		return false
	_last_pet_msec = now
	_roll_day()
	if _love_today >= DAILY_LOVE:
		return false
	_love_today += 1
	var before: Array[StringName] = unlocked_tricks()
	_friendship += 1
	friendship_changed.emit(_friendship)
	for t: StringName in unlocked_tricks():
		if not before.has(t):
			trick_unlocked.emit(t)
	_request_save()
	return true


## Aksesuar sahipliği (elmas harcamayı mağaza yapar, burada yalnız kayıt).
func grant_accessory(id: StringName) -> void:
	if _accessories.has(id):
		return
	_accessories.append(id)
	_request_save()
	accessories_changed.emit()


## Elmasla satın alır ve hemen takar (aynı yuvadakinin yerine). Elmas yetmezse / zaten varsa / kedi yoksa false
## döner ve HİÇBİR ŞEY değişmez.
func buy_accessory(id: StringName) -> bool:
	var info: Dictionary = accessory(id)
	if info.is_empty() or _accessories.has(id) or not _adopted:
		return false
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	if progress == null or not progress.spend_gems(int(info["gems"])):
		return false
	_accessories.append(id)
	_equipped[String(info["slot"])] = id
	_request_save()
	accessories_changed.emit()
	return true


## Sahip olunan aksesuarı takar / takılıysa çıkarır.
func toggle_accessory(id: StringName) -> void:
	if not _accessories.has(id):
		return
	equip(slot_of(id), &"" if is_worn(id) else id)


func equip(slot: StringName, id: StringName) -> void:
	if id != &"" and not _accessories.has(id):
		return
	if id == &"":
		_equipped.erase(String(slot))
	else:
		_equipped[String(slot)] = id
	_request_save()
	accessories_changed.emit()


func _on_level_up(level: int) -> void:
	if _adopted or level < ARRIVAL_LEVEL or _arrival_pending:
		return
	_arrival_pending = true
	_request_save()
	arrival_ready.emit()


# --- Kayıt ----------------------------------------------------------------------------------

func state() -> Dictionary:
	var acc: Array = []
	for a: StringName in _accessories:
		acc.append(String(a))
	var eq: Dictionary = {}
	for slot: String in _equipped:
		eq[slot] = String(_equipped[slot])
	return {"adopted": _adopted, "name": _name, "friendship": _friendship, "arrival": _arrival_pending,
		"accessories": acc, "equipped": eq, "love_day": _love_day, "love_today": _love_today}


func load_state(data: Dictionary) -> void:
	_adopted = bool(data.get("adopted", false))
	_name = SaveSafe.s(data.get("name", "")).strip_edges().substr(0, NAME_MAX)
	if _adopted and _name.is_empty():
		_name = DEFAULT_NAME
	_friendship = maxi(SaveSafe.i(data.get("friendship", 0)), 0)
	_arrival_pending = bool(data.get("arrival", false)) and not _adopted
	_love_day = SaveSafe.s(data.get("love_day", ""))
	_love_today = clampi(SaveSafe.i(data.get("love_today", 0)), 0, DAILY_LOVE)
	_accessories.clear()
	var acc: Variant = data.get("accessories", [])
	if acc is Array:
		for a: Variant in acc:
			if a is String and not String(a).is_empty() and not _accessories.has(StringName(a)):
				_accessories.append(StringName(a))
	_equipped.clear()
	var eq: Variant = data.get("equipped", {})
	if eq is Dictionary:
		for slot: Variant in eq:
			var id: StringName = StringName(SaveSafe.s(eq[slot]))
			if _accessories.has(id):
				_equipped[String(slot)] = id
	# Oyun sırasında yüklenen kayıt (bulut eşitleme, sıfırlama): garajdaki kedinin üstü tazelensin
	accessories_changed.emit()
	friendship_changed.emit(_friendship)


func reset() -> void:
	load_state({})


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.request_save()
