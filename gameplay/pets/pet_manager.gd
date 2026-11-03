class_name PetManager
extends Node
## GARAJ DOSTLARI (2026-10-31) — evcil hayvanların VERİSİ: hangi hayvanlar var, adları, dostlukları, açılan numaralar,
## giydikleri, hangilerinin garajda olduğu, ortak aksesuar dolabı ve ilk kedinin geliş zamanı. GarageSystem kodla kurar
## ("pets" grubu, SaveManager'dan ÖNCE); kayıt "pets". Görünüm (garajda dolaşan kediler) world/pets/pet_world.gd'dedir
## (garaj yuvası başına bir PetWorld); bu sınıf sahneye dokunmaz.
##
## Kullanıcı kararları (bkz. docs/EVCIL_HAYVAN_RAPORU.md ve hafıza "garaj-dostlari"):
##   - İlk hayvan TEKİR (turuncu tekir kedi), SEVİYE ARRIVAL_LEVEL ödülü, ücretsiz. Seviyeyi o an geçen oyuncuda geliş
##     hemen hazır olur; güncellemeden önce zaten geçmiş eski oyuncu kediyi BİR SONRAKİ seviye atlayışında alır.
##   - Ad ZORUNLU (ad ekranında süzgeçten geçer); ödül YOK, yalnız eğlence. Sevdikçe dostluk artar, numaralar açılır,
##     hiçbir şey düşmez (bakım yükü / ceza yok).
##   - Aksesuarlar yalnız elmasla (150–400); 2026-11-03 GÖVDE yuvasına dört kıyafet (tools/pets/tekir_wear.py).
##   - 2026-11-03 HAYVANLAR ekranı (taslak "Ekran C"): beyaz (mavi göz) ve siyah (yeşil göz) kedi ELMASLA alınır, her
##     hayvanın kendi adı / dostluğu / giydikleri var; garajda AYNI ANDA EN ÇOK MAX_OUT hayvan, ötekiler evde bekler.
##     Aksesuar dolabı ORTAK: bir kez alınan eşyayı her hayvan giyebilir (giydikleri hayvan başına).
##
## "Odaktaki" hayvan: eski tek kedili arayüz (yakın kamera kartı, sevme, aksesuar rafı) odaktaki hayvanla çalışır;
## yakın kamera açılırken odak dokunulan kediye geçer (focus). Hayvan başına sorgular uid alır (worn_of, fur_of ...).

## İlk kedi gelmeye hazır (geliş sinyali sahnesini / ad ekranını açar). Bekleyen geliş açılışta da yeniden yayınlanabilir.
signal arrival_ready
## İlk kedi sahiplenildi (ad verildi).
signal adopted(pet_name: String)
## Bir hayvanın adı değişti.
signal name_changed(pet_name: String)
## Odaktaki hayvanın dostluk puanı değişti.
signal friendship_changed(points: int)
## Odaktaki hayvanda yeni numara açıldı (ilk kez).
signal trick_unlocked(trick: StringName)
## Aksesuar alındı / takıldı / çıkarıldı (herhangi bir hayvanda).
signal accessories_changed
## Odaktaki hayvanın tüy rengi değişti (FURS kimliği).
signal fur_changed(fur: StringName)
## Hayvan listesi, garajdakiler ya da odak değişti (satın alma, garaja çıkar / eve gönder, kayıt yükleme).
signal pets_changed

const ARRIVAL_LEVEL: int = 5
const DEFAULT_NAME: String = "Tekir"
const NAME_MAX: int = 14
## Ad değiştirme ücreti (kullanıcı kararı 2026-11-03: "kedi adlarını ilk sefer ücretsiz, sonra ad değişimi 100 elmas").
## Her hayvanın İLK adı ücretsiz (ilk kedide gelişteki ad, alınan kedide alınınca açılan ad ekranı); sonrakiler elmaslı.
const RENAME_GEMS: int = 100
## Garajda aynı anda en çok bu kadar hayvan (kullanıcı kararı 2026-11-03: "aynı anda 2 hayvan").
const MAX_OUT: int = 2
## Sevme sayılırken iki dokunuş arasında en az bu kadar sn (art arda dokunmak puanı şişirmesin)
const PET_COOLDOWN: float = 1.2
## Günde en çok bu kadar sevgi puanı (hayvan başına; sevme + olta atlayışı birlikte). Kullanıcı kararı (2026-10-31):
## "sınırsız sevip hemen 60 oluyor, güzel değil" → günde 5: numaralar 2., 6., 12. günde açılır. Sınır dolunca sevmek yine
## kalp ve tepki verir, yalnız puan saymaz; arayüz sınırı SÖYLEMEZ (kullanıcı: "kendi fark etsin"). Gün = cihazın tarihi.
const DAILY_LOVE: int = 5
## Numaralar ve açıldıkları dostluk puanı (sıra = açılış sırası). Klip adları assets/pets/tekir.glb'dedir.
const TRICKS: Array[Dictionary] = [
	{"id": &"trick_paw", "points": 10},
	{"id": &"trick_beg", "points": 30},
	{"id": &"trick_roll", "points": 60},
]

## Aksesuarlar (yalnız elmas; kullanıcı kararı 150–400). Yuva başına bir tane takılır: BOYUN (tasma / bandana),
## BAŞ (kasket / kask) ve GÖVDE (kıyafetler). Modeller assets/pets/acc/<id>.glb + raf simgesi icon_<id>.png
## (tools/pets/tekir_acc.py, kıyafetler tools/pets/tekir_wear.py).
const ACCESSORIES: Array[Dictionary] = [
	{"id": &"collar_red", "name": "TASMA", "slot": &"neck", "gems": 150},
	{"id": &"bandana", "name": "BANDANA", "slot": &"neck", "gems": 200},
	{"id": &"cap", "name": "USTA KEPİ", "slot": &"head", "gems": 250},
	{"id": &"helmet", "name": "KASK", "slot": &"head", "gems": 400},
	{"id": &"vest", "name": "İKAZ YELEĞİ", "slot": &"body", "gems": 200},
	{"id": &"sweater", "name": "ÖRGÜ KAZAK", "slot": &"body", "gems": 250},
	{"id": &"race_jacket", "name": "YARIŞ MONTU", "slot": &"body", "gems": 350},
	{"id": &"leather_jacket", "name": "DERİ CEKET", "slot": &"body", "gems": 400},
]
## Takılma sırası (worn() bu sırayla döner).
const SLOTS: Array[StringName] = [&"neck", &"head", &"body"]
## Birlikte giyilemeyenler: bandananın üçgeni göğüste kıyafetin altında kalıyor → biri takılınca öteki çıkar.
const CLASHES: Dictionary = {&"bandana": [&"body"]}

## Tüy renkleri: aynı model, iskelet ve hareketler, yalnız gövde dokusu değişir (tools/pets/tekir_fur.py →
## assets/pets/fur/).
const FURS: Array[Dictionary] = [
	{"id": &"orange"},   # turuncu tekir, kehribar göz (modelin kendi dokusu)
	{"id": &"white"},    # beyaz, mavi göz
	{"id": &"black"},    # siyah, yeşil göz
]
const DEFAULT_FUR: StringName = &"orange"

## Alınabilir hayvanlar (HAYVANLAR ekranının sırası). gems 0 = ilk kedi (sv5 ödülü, satılmaz); her çeşitten bir tane.
## Portreler assets/pets/portraits/<id>.jpg (tam boy) + <id>_face.png (yuvarlak yüz), qa/pet_portraits.gd.
const VARIANTS: Array[Dictionary] = [
	{"id": &"orange", "fur": &"orange", "gems": 0, "name": "TURUNCU TEKİR",
		"caption": "Turuncu tekir · garajın kedisi", "default_name": "Tekir"},
	{"id": &"white", "fur": &"white", "gems": 500, "name": "BEYAZ KEDİ",
		"caption": "Mavi gözlü beyaz · garajın kedisi", "default_name": "Pamuk"},
	{"id": &"black", "fur": &"black", "gems": 750, "name": "SİYAH KEDİ",
		"caption": "Yeşil gözlü siyah · garajın kedisi", "default_name": "Gece"},
]
## Ekranda YAKINDA olarak görünenler (henüz modeli yok).
const SOON: Array[Dictionary] = [{"id": &"dog", "name": "KÖPEK"}]

## Hayvanlar (sıra = alınış sırası). Kayıt: {uid, variant, fur, name, named (ücretsiz ilk ad kullanıldı mı),
## friendship, love_day, love_today, equipped {yuva: aksesuar}, slot (garaj yuvası 0..MAX_OUT-1, -1 = evde)}.
var _list: Array[Dictionary] = []
var _focus: String = ""
var _arrival_pending: bool = false
var _accessories: Array[StringName] = []
var _screen_seen: bool = false
var _next_uid: int = 1
var _last_pet_msec: Dictionary = {}   # uid → son sayılan sevme (kayda girmez)


func _ready() -> void:
	add_to_group("pets")
	_connect_progress.call_deferred()


func _connect_progress() -> void:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress and not progress.level_up.is_connected(_on_level_up):
		progress.level_up.connect(_on_level_up)


# --- Katalog ---------------------------------------------------------------------------------

static func accessory(id: StringName) -> Dictionary:
	for a: Dictionary in ACCESSORIES:
		if a["id"] == id:
			return a
	return {}


static func slot_of(id: StringName) -> StringName:
	return StringName(accessory(id).get("slot", &""))


## İki aksesuar birlikte giyilemez mi (aynı yuva ya da CLASHES).
static func clashes(a: StringName, b: StringName) -> bool:
	if a == &"" or b == &"" or a == b:
		return false
	var sa: StringName = slot_of(a)
	var sb: StringName = slot_of(b)
	if sa == sb:
		return true
	return (CLASHES.get(a, []) as Array).has(sb) or (CLASHES.get(b, []) as Array).has(sa)


static func has_fur(id: StringName) -> bool:
	for f: Dictionary in FURS:
		if f["id"] == id:
			return true
	return false


static func variant(id: StringName) -> Dictionary:
	for v: Dictionary in VARIANTS:
		if v["id"] == id:
			return v
	return {}


# --- Hayvanlar ---------------------------------------------------------------------------------

func is_adopted() -> bool:
	return not _list.is_empty()


func is_arrival_pending() -> bool:
	return _arrival_pending and _list.is_empty()


## Hayvanların kimlikleri (alınış sırası).
func uids() -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in _list:
		out.append(String(p["uid"]))
	return out


## Bir hayvanın bilgisi (kopya; yoksa {}): uid, variant, fur, name, friendship, equipped, slot.
func pet_info(uid: String) -> Dictionary:
	var p: Dictionary = _rec(uid)
	return p.duplicate(true) if not p.is_empty() else {}


func uid_of_variant(id: StringName) -> String:
	for p: Dictionary in _list:
		if p["variant"] == id:
			return String(p["uid"])
	return ""


func owns_variant(id: StringName) -> bool:
	return uid_of_variant(id) != ""


## Garaj yuvasındaki hayvan ("" = boş). Yuvalar kararlı: biri eve gidince öteki yerinden kımıldamaz.
func pet_in_slot(slot: int) -> String:
	for p: Dictionary in _list:
		if int(p["slot"]) == slot:
			return String(p["uid"])
	return ""


## Garajdaki hayvanlar (yuva sırasıyla).
func out_pets() -> Array[String]:
	var out: Array[String] = []
	for s: int in MAX_OUT:
		var uid: String = pet_in_slot(s)
		if uid != "":
			out.append(uid)
	return out


func is_out(uid: String) -> bool:
	return int(_rec(uid).get("slot", -1)) >= 0


func garage_full() -> bool:
	return out_pets().size() >= MAX_OUT


## Garaja çıkarır (on) ya da eve gönderir. Garaj doluysa / hayvan yoksa false, hiçbir şey değişmez.
func set_out(uid: String, on: bool) -> bool:
	var p: Dictionary = _rec(uid)
	if p.is_empty():
		return false
	if on == (int(p["slot"]) >= 0):
		return true
	if on:
		var free: int = _free_slot()
		if free < 0:
			return false
		p["slot"] = free
	else:
		p["slot"] = -1
	_request_save()
	pets_changed.emit()
	return true


## Elmasla yeni hayvan alır: varsayılan adla gelir, garajda yer varsa garaja çıkar. Yeni uid; olmadıysa "" (kedi yok,
## bilinmeyen / satılmayan çeşit, zaten var, elmas yetmiyor) ve HİÇBİR ŞEY değişmez.
func buy_pet(id: StringName) -> String:
	var v: Dictionary = variant(id)
	if v.is_empty() or int(v["gems"]) <= 0 or owns_variant(id) or not is_adopted():
		return ""
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	if progress == null or not progress.spend_gems(int(v["gems"])):
		return ""
	var p: Dictionary = _new_pet(id, String(v["default_name"]))
	p["slot"] = _free_slot()
	_request_save()
	pets_changed.emit()
	return String(p["uid"])


## Eski arayüz bu hayvanla çalışır (yakın kamera kartı, sevme, aksesuar rafı).
func focus(uid: String) -> void:
	if _rec(uid).is_empty() or uid == _focus:
		return
	_focus = uid
	pets_changed.emit()
	friendship_changed.emit(friendship())


func focused() -> String:
	return String(_cur().get("uid", ""))


## Bu hayvanın adını değiştirmenin ücreti (elmas): ilk ad ücretsiz, sonrası RENAME_GEMS.
func rename_cost(uid: String) -> int:
	var p: Dictionary = _rec(uid)
	return RENAME_GEMS if not p.is_empty() and bool(p.get("named", true)) else 0


## Adı değiştirir; ilk ad ücretsiz, sonrası RENAME_GEMS elmas. Aynı ad: ücret yok, değişiklik yok (true). Elmas yetmezse /
## hayvan yoksa / ad boşsa false ve HİÇBİR ŞEY değişmez.
func rename(uid: String, new_name: String) -> bool:
	var p: Dictionary = _rec(uid)
	var clean: String = new_name.strip_edges().substr(0, NAME_MAX)
	if p.is_empty() or clean.is_empty():
		return false
	if clean == String(p["name"]):
		p["named"] = true   # aynı adı onaylamak da ilk adı kullanır (yeni kedide varsayılan adı beğendi)
		_request_save()
		return true
	var cost: int = rename_cost(uid)
	if cost > 0:
		var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
			if is_inside_tree() else null
		if progress == null or not progress.spend_gems(cost):
			return false
	p["name"] = clean
	p["named"] = true
	_request_save()
	name_changed.emit(clean)
	pets_changed.emit()
	return true


func name_of(uid: String) -> String:
	return String(_rec(uid).get("name", ""))


func friendship_of(uid: String) -> int:
	return int(_rec(uid).get("friendship", 0))


func fur_of(uid: String) -> StringName:
	return StringName(_rec(uid).get("fur", DEFAULT_FUR))


func worn_of(uid: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var eq: Dictionary = _rec(uid).get("equipped", {})
	for slot: StringName in SLOTS:
		var id: StringName = StringName(eq.get(String(slot), &""))
		if id != &"":
			out.append(id)
	return out


## HAYVANLAR ekranı hiç açıldı mı (açılmadıysa sağ üstteki pati tabelasında ünlem).
func screen_seen() -> bool:
	return _screen_seen


func mark_screen_seen() -> void:
	if _screen_seen:
		return
	_screen_seen = true
	_request_save()
	pets_changed.emit()


# --- Odaktaki hayvan (yakın kamera kartı) ------------------------------------------------------

func pet_name() -> String:
	return String(_cur().get("name", ""))


func friendship() -> int:
	return int(_cur().get("friendship", 0))


func fur() -> StringName:
	return StringName(_cur().get("fur", DEFAULT_FUR))


func unlocked_tricks() -> Array[StringName]:
	var out: Array[StringName] = []
	var points: int = friendship()
	for t: Dictionary in TRICKS:
		if points >= int(t["points"]):
			out.append(t["id"])
	return out


func is_trick_unlocked(trick: StringName) -> bool:
	return unlocked_tricks().has(trick)


## Bugün sayılan sevgi puanı ve kalan hak.
func love_today() -> int:
	var p: Dictionary = _cur()
	if p.is_empty():
		return 0
	_roll_day(p)
	return int(p["love_today"])


func love_left() -> int:
	return maxi(DAILY_LOVE - love_today(), 0)


## Sıradaki numara ve kaç puan kaldığı ({} = hepsi açık).
func next_trick() -> Dictionary:
	var points: int = friendship()
	for t: Dictionary in TRICKS:
		if points < int(t["points"]):
			return {"id": t["id"], "points": int(t["points"]), "left": int(t["points"]) - points}
	return {}


func owns_accessory(id: StringName) -> bool:
	return _accessories.has(id)


func is_worn(id: StringName) -> bool:
	return id != &"" and equipped(slot_of(id)) == id


## Takılı aksesuarlar (yuva sırası: boyun, baş, gövde).
func worn() -> Array[StringName]:
	return worn_of(focused())


func equipped(slot: StringName) -> StringName:
	return StringName((_cur().get("equipped", {}) as Dictionary).get(String(slot), &""))


# --- Eylemler -------------------------------------------------------------------------------

## Ad verir: hiç hayvan yoksa İLK KEDİYİ sahiplenir (garaja çıkar, odak olur), varsa odaktakinin adını değiştirir
## (ad ekranı süzgeçten geçirmiş olmalı). Boş ad reddedilir.
func adopt(new_name: String) -> bool:
	var clean: String = new_name.strip_edges().substr(0, NAME_MAX)
	if clean.is_empty():
		return false
	if not _list.is_empty():
		return rename(focused(), clean)
	var p: Dictionary = _new_pet(&"orange", clean)
	p["slot"] = 0
	p["named"] = true   # gelişteki zorunlu ad = ücretsiz ilk ad
	_focus = String(p["uid"])
	_arrival_pending = false
	_request_save()
	adopted.emit(clean)
	pets_changed.emit()
	return true


## Sevme dokunuşu (odaktaki hayvan). Bekleme süresi içindeki ya da günlük sınır (DAILY_LOVE) dolduktan sonraki dokunuş
## tepki oynatır ama puan saymaz. Puan sayıldıysa true.
func pet() -> bool:
	var p: Dictionary = _cur()
	if p.is_empty():
		return false
	var uid: String = String(p["uid"])
	var now: int = Time.get_ticks_msec()
	if now - int(_last_pet_msec.get(uid, -100000)) < int(PET_COOLDOWN * 1000.0):
		return false
	_last_pet_msec[uid] = now
	_roll_day(p)
	if int(p["love_today"]) >= DAILY_LOVE:
		return false
	p["love_today"] = int(p["love_today"]) + 1
	var before: Array[StringName] = unlocked_tricks()
	p["friendship"] = int(p["friendship"]) + 1
	friendship_changed.emit(int(p["friendship"]))
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


## Elmasla satın alır ve odaktaki hayvana hemen takar (aynı yuvadakinin yerine). Elmas yetmezse / zaten varsa / hayvan
## yoksa false döner ve HİÇBİR ŞEY değişmez.
func buy_accessory(id: StringName) -> bool:
	var info: Dictionary = accessory(id)
	if info.is_empty() or _accessories.has(id) or _cur().is_empty():
		return false
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	if progress == null or not progress.spend_gems(int(info["gems"])):
		return false
	_accessories.append(id)
	_wear(_cur(), id)
	_request_save()
	accessories_changed.emit()
	return true


## Sahip olunan aksesuarı odaktaki hayvana takar / takılıysa çıkarır.
func toggle_accessory(id: StringName) -> void:
	if not _accessories.has(id):
		return
	equip(slot_of(id), &"" if is_worn(id) else id)


func equip(slot: StringName, id: StringName) -> void:
	var p: Dictionary = _cur()
	if p.is_empty() or (id != &"" and not _accessories.has(id)):
		return
	if id == &"":
		(p["equipped"] as Dictionary).erase(String(slot))
	else:
		_wear(p, id)
	_request_save()
	accessories_changed.emit()


## Takar; çakışan (aynı yuva ya da CLASHES) takılı olanı çıkarır.
func _wear(p: Dictionary, id: StringName) -> void:
	var eq: Dictionary = p["equipped"]
	for other: StringName in worn_of(String(p["uid"])):
		if clashes(id, other):
			eq.erase(String(slot_of(other)))
	eq[String(slot_of(id))] = id


## Odaktaki hayvanın tüy rengini değiştirir (QA / test; çeşidin rengi alınırken verilir). Bilinmeyen kimlik ya da aynı
## renk: hiçbir şey olmaz.
func set_fur(id: StringName) -> void:
	var p: Dictionary = _cur()
	if p.is_empty() or not has_fur(id) or id == StringName(p["fur"]):
		return
	p["fur"] = id
	_request_save()
	fur_changed.emit(id)


func _on_level_up(level: int) -> void:
	if is_adopted() or level < ARRIVAL_LEVEL or _arrival_pending:
		return
	_arrival_pending = true
	_request_save()
	arrival_ready.emit()


# --- İç ----------------------------------------------------------------------------------------

func _rec(uid: String) -> Dictionary:
	for p: Dictionary in _list:
		if p["uid"] == uid:
			return p
	return {}


## Odaktaki hayvan (yoksa garajdaki ilki, o da yoksa ilk hayvan; hiç yoksa {}). Sözlük kendisidir (değişiklik kalıcı).
func _cur() -> Dictionary:
	var p: Dictionary = _rec(_focus)
	if not p.is_empty():
		return p
	for s: int in MAX_OUT:
		p = _rec(pet_in_slot(s))
		if not p.is_empty():
			return p
	return _list[0] if not _list.is_empty() else {}


func _free_slot() -> int:
	for s: int in MAX_OUT:
		if pet_in_slot(s) == "":
			return s
	return -1


func _new_pet(id: StringName, pet_name_: String) -> Dictionary:
	var v: Dictionary = variant(id)
	var p: Dictionary = {"uid": "p%d" % _next_uid, "variant": id, "fur": StringName(v.get("fur", DEFAULT_FUR)),
		"name": pet_name_, "named": false, "friendship": 0, "love_day": "", "love_today": 0, "equipped": {}, "slot": -1}
	_next_uid += 1
	_list.append(p)
	return p


func _roll_day(p: Dictionary) -> void:
	var today: String = Time.get_date_string_from_system()
	if today != String(p["love_day"]):
		p["love_day"] = today
		p["love_today"] = 0


# --- Kayıt ----------------------------------------------------------------------------------

## Kayıt "pets": v2 hayvan listesi. ESKİ SÜRÜMLER (tek kedi) aynı kaydı bulutta okuyabilsin diye ilk hayvan eski
## alanlara da yazılır (adopted, name, friendship, equipped, love_*, fur).
func state() -> Dictionary:
	var acc: Array = []
	for a: StringName in _accessories:
		acc.append(String(a))
	var list: Array = []
	for p: Dictionary in _list:
		var eq: Dictionary = {}
		for slot: String in p["equipped"]:
			eq[slot] = String(p["equipped"][slot])
		list.append({"uid": p["uid"], "variant": String(p["variant"]), "fur": String(p["fur"]), "name": p["name"],
			"named": p["named"], "friendship": p["friendship"], "love_day": p["love_day"], "love_today": p["love_today"], "equipped": eq,
			"slot": p["slot"]})
	var out: Dictionary = {"v": 2, "arrival": _arrival_pending, "accessories": acc, "pets": list, "focus": _focus,
		"screen_seen": _screen_seen, "adopted": is_adopted()}
	if not list.is_empty():
		var first: Dictionary = list[0]
		for key: String in ["name", "friendship", "love_day", "love_today", "equipped", "fur"]:
			out[key] = first[key]
	return out


func load_state(data: Dictionary) -> void:
	_list.clear()
	_last_pet_msec.clear()
	_next_uid = 1
	_accessories.clear()
	var acc: Variant = data.get("accessories", [])
	if acc is Array:
		for a: Variant in acc:
			if a is String and not String(a).is_empty() and not _accessories.has(StringName(a)):
				_accessories.append(StringName(a))
	var raw: Variant = data.get("pets")
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary:
				_load_pet(entry)
	elif bool(data.get("adopted", false)):
		# v1 (tek kedi) kaydı: bütün alanlar kökte → tek hayvan, garajda
		var legacy: Dictionary = data.duplicate()
		legacy["variant"] = "orange"
		legacy["slot"] = 0
		_load_pet(legacy)
	_fix_slots()
	_arrival_pending = bool(data.get("arrival", false)) and _list.is_empty()
	_screen_seen = bool(data.get("screen_seen", false))
	_focus = SaveSafe.s(data.get("focus", ""))
	if _rec(_focus).is_empty():
		_focus = String(_list[0]["uid"]) if not _list.is_empty() else ""
	# Oyun sırasında yüklenen kayıt (bulut eşitleme, sıfırlama): garajdaki kedilerin üstü tazelensin
	accessories_changed.emit()
	friendship_changed.emit(friendship())
	fur_changed.emit(fur())
	pets_changed.emit()


func _load_pet(d: Dictionary) -> void:
	var id: StringName = StringName(SaveSafe.s(d.get("variant", "orange")))
	if variant(id).is_empty() or owns_variant(id):
		return   # bilinmeyen çeşit ya da aynı çeşitten ikinci (bozuk kayıt)
	var pet_name_: String = SaveSafe.s(d.get("name", "")).strip_edges().substr(0, NAME_MAX)
	if pet_name_.is_empty():
		pet_name_ = String(variant(id)["default_name"])
	var p: Dictionary = _new_pet(id, pet_name_)
	var uid: String = SaveSafe.s(d.get("uid", ""))   # kayıttaki kimlik korunur (yakın kamera odağı, yuva)
	if uid.begins_with("p") and uid.substr(1).is_valid_int() and _rec(uid).is_empty():
		p["uid"] = uid
		_next_uid = maxi(_next_uid, int(uid.substr(1)) + 1)
	var fur_id: StringName = StringName(SaveSafe.s(d.get("fur", "")))
	p["fur"] = fur_id if has_fur(fur_id) else StringName(variant(id)["fur"])
	p["named"] = bool(d.get("named", true))   # eski kayıt (v1 ya da alan yok): ad gelişte verildi
	p["friendship"] = maxi(SaveSafe.i(d.get("friendship", 0)), 0)
	p["love_day"] = SaveSafe.s(d.get("love_day", ""))
	p["love_today"] = clampi(SaveSafe.i(d.get("love_today", 0)), 0, DAILY_LOVE)
	p["slot"] = clampi(SaveSafe.i(d.get("slot", -1)), -1, MAX_OUT - 1)
	var eq: Variant = d.get("equipped", {})
	if eq is Dictionary:
		for slot: Variant in eq:
			var acc_id: StringName = StringName(SaveSafe.s(eq[slot]))
			if _accessories.has(acc_id) and String(slot_of(acc_id)) == String(slot):
				_wear(p, acc_id)


## Bozuk kayıtta iki hayvan aynı yuvadaysa ikincisi eve gider; hiç hayvan garajda değilse ve garajda kimse yoksa sorun
## değil (oyuncu hepsini eve gönderebilir).
func _fix_slots() -> void:
	var used: Dictionary = {}
	for p: Dictionary in _list:
		var s: int = int(p["slot"])
		if s < 0:
			continue
		if used.has(s):
			p["slot"] = -1
		else:
			used[s] = true


func reset() -> void:
	load_state({})


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.request_save()
