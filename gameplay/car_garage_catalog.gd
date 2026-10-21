class_name CarGarageCatalog
extends RefCounted
## ARAÇ DEPOLARI (DEPOLARIM) kataloğu — depoların ve iç yükseltme kalemlerinin TEK kaynağı. Yalnızca veri;
## durum CarGarageManager'da. Kararlar: docs/GARAJLAR_TASARIM.md §2–3, §10 (2026-10-20: 5 "garaj" depoya döndü,
## kimlikler aynı kaldı). Fiyat / süre / seviye şartı taslaktır, ayar burada yapılır. Depoların altında ücretli
## OTOPARK durur (CarGarageManager.WAITING; katalogda değil).
##
## Ana dünyadaki "GARAJ SEVİYESİ" (GarageUpgrade, tamirhanenin büyüklüğü) bundan AYRIDIR.
##
## Kalemler:
##   PARK  — park yeri (kapasite). `park` satırları: [eklenen yer, ücret ₺, süre sn]; seviye 1 = taban kapasite.
##   FLOOR / LIGHTS / WALLS / LIFT — yalnızca görünüm + garaj değeri (denge bonusu YOK, kullanıcı kararı).
##           `visual` satırları: [ücret ₺, süre sn]; seviye 1 = taban, en çok VISUAL_LEVELS.

const MAHALLE: StringName = &"mahalle"
const SANAYI: StringName = &"sanayi"
const NEON: StringName = &"neon"
const SHOWROOM: StringName = &"showroom"
const HANGAR: StringName = &"hangar"

const PARK: StringName = &"park"
const FLOOR: StringName = &"floor"
const LIGHTS: StringName = &"lights"
const WALLS: StringName = &"walls"
const LIFT: StringName = &"lift"
const ITEMS: Array[StringName] = [PARK, FLOOR, LIGHTS, WALLS, LIFT]
const VISUAL_LEVELS: int = 3

## Ucuzdan pahalıya. 2026-10-21 zorluk turu: MAHALLE / SANAYİ PARK YERİ genişletmesi iki kat (fiyat ve süre).
## `tint`: Faz 3'ün Blender garajları gelene kadar geçici kutu garajın duvar rengi.
const GARAGES: Array[Dictionary] = [
	{"id": MAHALLE, "name": "MAHALLE DEPOSU", "price": 50000, "build": 1800, "level": 1, "slots": 4,
		"park": [[1, 40000, 600], [1, 80000, 1200]],
		"visual": [[10000, 300], [20000, 600]], "tint": Color("E9DFC8")},
	{"id": SANAYI, "name": "SANAYİ DEPOSU", "price": 150000, "build": 3600, "level": 5, "slots": 6,
		"park": [[2, 200000, 1200], [2, 400000, 2400]],
		"visual": [[40000, 600], [80000, 1200]], "tint": Color("C98B6B")},
	{"id": NEON, "name": "YERALTI DEPOSU", "price": 900000, "build": 14400, "level": 12, "slots": 8,
		"park": [[2, 200000, 1200], [2, 300000, 1800], [2, 450000, 2700]],
		"visual": [[100000, 1200], [200000, 2700]], "tint": Color("6E6A86")},
	{"id": SHOWROOM, "name": "VİTRİN DEPOSU", "price": 3000000, "build": 43200, "level": 20, "slots": 10,
		"park": [[2, 250000, 1800], [2, 350000, 2700], [2, 500000, 3600], [2, 700000, 5400]],
		"visual": [[150000, 1800], [300000, 5400]], "tint": Color("BFD8E2")},
	{"id": HANGAR, "name": "HANGAR DEPOSU", "price": 8000000, "build": 86400, "level": 30, "slots": 18,
		"park": [[3, 500000, 2700], [3, 750000, 4500], [3, 1000000, 5400], [3, 1500000, 7200]],
		"visual": [[250000, 2700], [450000, 7200]], "tint": Color("9DA7A0")},
]


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Dictionary in GARAGES:
		out.append(entry["id"])
	return out


static func has(id: StringName) -> bool:
	return not get_entry(id).is_empty()


static func get_entry(id: StringName) -> Dictionary:
	for entry: Dictionary in GARAGES:
		if entry["id"] == id:
			return entry
	return {}


## Merdivendeki yeri (0 = MAHALLE); bilinmeyen garaj -1.
static func rank(id: StringName) -> int:
	for i: int in GARAGES.size():
		if GARAGES[i]["id"] == id:
			return i
	return -1


static func display_name(id: StringName) -> String:
	return Loc.t(String(get_entry(id).get("name", String(id).to_upper())))


static func price(id: StringName) -> int:
	return int(get_entry(id).get("price", 0))


static func build_time(id: StringName) -> float:
	return float(get_entry(id).get("build", 0))


static func required_level(id: StringName) -> int:
	return int(get_entry(id).get("level", 1))


static func tint(id: StringName) -> Color:
	return get_entry(id).get("tint", Color.WHITE)


static func item_name(item: StringName) -> String:
	match item:
		PARK: return Loc.t("PARK YERİ")
		FLOOR: return Loc.t("ZEMİN")
		LIGHTS: return Loc.t("IŞIKLAR")
		WALLS: return Loc.t("DUVAR / VİTRİN")
		LIFT: return Loc.t("LİFT / PLATFORM")
	return String(item).to_upper()


## Kalemin en yüksek seviyesi (seviye 1 = taban).
static func max_level(id: StringName, item: StringName) -> int:
	if item == PARK:
		return (get_entry(id).get("park", []) as Array).size() + 1
	return VISUAL_LEVELS if ITEMS.has(item) else 1


## `level`'e (2..max) çıkmanın satırı: PARK [yer, ücret, süre], görsel [ücret, süre]. Yoksa boş.
static func _step(id: StringName, item: StringName, level: int) -> Array:
	var rows: Array = get_entry(id).get("park" if item == PARK else "visual", [])
	var index: int = level - 2
	if not ITEMS.has(item) or index < 0 or index >= rows.size():
		return []
	return rows[index]


## `level`'e çıkmanın ücreti (₺); tanımsızsa 0.
static func step_cost(id: StringName, item: StringName, level: int) -> int:
	var row: Array = _step(id, item, level)
	if row.is_empty():
		return 0
	return int(row[1] if item == PARK else row[0])


## `level`'e çıkmanın süresi (sn).
static func step_time(id: StringName, item: StringName, level: int) -> float:
	var row: Array = _step(id, item, level)
	if row.is_empty():
		return 0.0
	return float(row[2] if item == PARK else row[1])


## PARK kaleminin `level`'deki kapasitesi.
static func capacity_at(id: StringName, park_level: int) -> int:
	var total: int = int(get_entry(id).get("slots", 0))
	for level: int in range(2, mini(park_level, max_level(id, PARK)) + 1):
		total += int(_step(id, PARK, level)[0])
	return total


static func max_capacity(id: StringName) -> int:
	return capacity_at(id, max_level(id, PARK))


## Bütün garajların en yüksek kapasitesi toplamı (edinilebilir araç sayısıyla karşılaştırmak için).
static func total_max_capacity() -> int:
	var total: int = 0
	for entry: Dictionary in GARAGES:
		total += max_capacity(entry["id"])
	return total


## Garajın ve bütün iç yükseltmelerinin toplam ücreti (ayar ve garaj değeri hesapları için).
static func full_cost(id: StringName) -> int:
	var total: int = price(id)
	for item: StringName in ITEMS:
		for level: int in range(2, max_level(id, item) + 1):
			total += step_cost(id, item, level)
	return total
