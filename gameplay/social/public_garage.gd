class_name PublicGarage
extends RefCounted
## HERKESE AÇIK GARAJ: kayıt sözlüğünün (SaveManager.snapshot) yalnızca GÖRSEL kısmı.
## Arkadaşlar bunu okur ve garajı ziyaret modunda aynı kodla kurar (GarageVisit).
##
## İçinde OLANLAR: sürüm, oyuncu seviyesi, garaj seviyeleri, tamir alanları (sayı + yerleşim), dekor
## (eşyalar, zemin karoları, duvarlar), araçlar (sahip olunanlar + boyalar; dekor araçları bunlara bakar).
## OLMAYANLAR: para, XP, gem, kasalar, görevler, reklam sayaçları, ustalık. Bunlar başkasına gösterilmez.
## YARIŞ (2026-10-16): araç başına takılı performans kademeleri ("performance.builds") — arkadaşın aracı yarışa
## onun modifiyeleriyle gelir (RaceManager). Takma işleri ve gösterge tabanı taşınmaz.
##
## Biçim kayıt sözlüğüyle aynıdır (SaveManager.validate / _apply olduğu gibi okur); ikinci bir model yok.

## Kaydın içinden alınan alanlar. "progress" ve "vehicles" ayrıca süzülür (aşağıda).
const COPIED_KEYS: Array[String] = ["garage_upgrades", "repair_bays", "decor"]
## Firestore kuralıyla aynı sınır (garages.garage_json.size() < 20000).
const MAX_JSON: int = 19000


## Kayıt sözlüğünden açık garaj sözlüğü.
static func from_snapshot(snapshot: Dictionary) -> Dictionary:
	var out: Dictionary = {"version": snapshot.get("version", SaveManager.SAVE_VERSION)}
	for key: String in COPIED_KEYS:
		if snapshot.has(key):
			out[key] = snapshot[key]
	var progress: Dictionary = snapshot.get("progress", {}) if snapshot.get("progress") is Dictionary else {}
	out["progress"] = {"level": SaveSafe.i(progress.get("level", 1))}
	var vehicles: Dictionary = snapshot.get("vehicles", {}) if snapshot.get("vehicles") is Dictionary else {}
	# Koleksiyon (keşif, kopya, yarış aracı) garajda görünmez: taşınmaz
	var out_vehicles: Dictionary = {}
	for key: String in ["owned", "paint"]:
		if vehicles.has(key):
			out_vehicles[key] = vehicles[key]
	out["vehicles"] = out_vehicles
	var performance: Dictionary = snapshot.get("performance", {}) if snapshot.get("performance") is Dictionary else {}
	if performance.get("builds") is Dictionary and not (performance["builds"] as Dictionary).is_empty():
		out["performance"] = {"builds": performance["builds"]}
	return out


## Arkadaşın garajından yarış verisi: {cars: Array[String] (tekil), paint: {id: hex}, builds: {id: {kategori: kademe}}}.
## Biçimsiz değerler atlanır (sunucudan gelen veri).
static func race_data(garage: Dictionary) -> Dictionary:
	var vehicles: Dictionary = garage.get("vehicles", {}) if garage.get("vehicles") is Dictionary else {}
	var cars: Array[String] = []
	var owned: Variant = vehicles.get("owned", [])
	if owned is Array:
		for raw: Variant in owned:
			var id: String = SaveSafe.s(raw)
			if not id.is_empty() and not cars.has(id) and not CarCatalog.get_entry(StringName(id)).is_empty():
				cars.append(id)
	var paint: Dictionary = {}
	var raw_paint: Variant = vehicles.get("paint", {})
	if raw_paint is Dictionary:
		for key: Variant in raw_paint:
			var hex: String = SaveSafe.s((raw_paint as Dictionary)[key])
			if cars.has(SaveSafe.s(key)) and Color.html_is_valid(hex):
				paint[SaveSafe.s(key)] = hex
	var builds: Dictionary = {}
	var performance: Dictionary = garage.get("performance", {}) if garage.get("performance") is Dictionary else {}
	var raw_builds: Variant = performance.get("builds", {})
	if raw_builds is Dictionary:
		for key: Variant in raw_builds:
			var id: String = SaveSafe.s(key)
			if cars.has(id) and (raw_builds as Dictionary)[key] is Dictionary:
				var stages: Dictionary = PerformanceMods.normalized((raw_builds as Dictionary)[key])
				var clean: Dictionary = {}
				for category: StringName in stages:
					clean[String(category)] = int(stages[category])
				if not clean.is_empty():
					builds[id] = clean
	return {"cars": cars, "paint": paint, "builds": builds}


## Sıralı anahtarlı JSON (değişti mi karşılaştırması için tek biçim).
static func to_json(garage: Dictionary) -> String:
	return JSON.stringify(garage, "", true)


## Sunucudan gelen JSON'u okur. Geçersizse ya da sürümü desteklenmiyorsa boş sözlük.
## `max_len`: oyunla gelen öne çıkan garajlar sunucudan geçmez, Firestore sınırına bağlı değildir.
## Yalnızca AÇIK bölümler döner (from_snapshot süzgeci): belgeyi oyunu atlayıp elle yazan biri tamir işi, ekonomi,
## ilerleme gibi bölümler eklerse ziyaret modunda SaveManager._apply onları da yüklüyordu.
static func parse(json: String, max_len: int = MAX_JSON) -> Dictionary:
	if json.is_empty() or json.length() > max_len:
		return {}
	var raw: Variant = JSON.parse_string(json)
	if not raw is Dictionary:
		return {}
	var version: int = SaveSafe.i((raw as Dictionary).get("version", 0))
	if version < SaveManager.MIN_VERSION or version > SaveManager.SAVE_VERSION:
		return {}
	return from_snapshot(raw)


## Oyuncu seviyesi (liste satırında gösterilir).
static func level_of(garage: Dictionary) -> int:
	var progress: Dictionary = garage.get("progress", {}) if garage.get("progress") is Dictionary else {}
	return maxi(SaveSafe.i(progress.get("level", 1)), 1)
