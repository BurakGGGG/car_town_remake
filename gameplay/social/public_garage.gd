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
## DEPOLARIM: ÖZET ("car_garage_summary": alınmış depolar + toplam park yeri) — profil rozeti ve arkadaşın lüks deposu
## haberi için. 2026-10-20'den beri ziyarette depolar da gezilir (kullanıcı kararı): "car_garages" = {"garages": {id:
## {"levels", "slots"}}} — yalnız iç kalem seviyeleri ve park yerlerindeki araçlar. Süren işler, inşaat, otopark ve
## faturalar taşınmaz. Belge alanı değil garaj JSON'unun içinde: Firestore kuralı değişmeden taşınır; JSON sınırı
## aşılırsa yerleşim düşürülür, özet kalır (without_depots).
##
## Biçim kayıt sözlüğüyle aynıdır (SaveManager.validate / _apply olduğu gibi okur); ikinci bir model yok.

## Kaydın içinden alınan alanlar. "progress" ve "vehicles" ayrıca süzülür (aşağıda).
const COPIED_KEYS: Array[String] = ["garage_upgrades", "repair_bays", "decor"]
## Belgeye yazılan (CloudPack ile SIKIŞMIŞ) metnin sınırı: Firestore kuralıyla aynı (garages.garage_json.size() < 20000).
## Açık JSON çok daha büyük olabilir (sıkışınca ~1/6); okurken açık metnin sınırı CloudPack.MAX_PLAIN.
const MAX_JSON: int = 19000
const SUMMARY_KEY: String = "car_garage_summary"


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
	var summary: Dictionary = car_garage_summary(snapshot)
	if not summary.is_empty():
		out[SUMMARY_KEY] = summary
	var depots: Dictionary = depot_layout(snapshot)
	if not depots.is_empty():
		out["car_garages"] = {"garages": depots}
	return out


## Depoların görünür yerleşimi {id: {"levels": {kalem: seviye}, "slots": [araç id | ""]}} — kayıttan ya da sunucudan gelen
## açık garajdan; bilinmeyen depo / kalem / araç atılır, seviye ve park yeri sayısı katalog sınırlarına çekilir.
static func depot_layout(garage: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var section: Variant = garage.get("car_garages", {})
	var rows: Variant = (section as Dictionary).get("garages", {}) if section is Dictionary else {}
	if not rows is Dictionary:
		return out
	for id: StringName in CarGarageCatalog.ids():
		var row: Variant = (rows as Dictionary).get(String(id))
		if not row is Dictionary:
			continue
		var levels: Dictionary = {}
		var raw_levels: Variant = (row as Dictionary).get("levels", {})
		for item: StringName in CarGarageCatalog.ITEMS:
			var level: int = SaveSafe.i((raw_levels as Dictionary).get(String(item), 1)) if raw_levels is Dictionary else 1
			levels[String(item)] = clampi(level, 1, CarGarageCatalog.max_level(id, item))
		var size: int = CarGarageCatalog.capacity_at(id, int(levels[String(CarGarageCatalog.PARK)]))
		var slots: Array = []
		var raw_slots: Variant = (row as Dictionary).get("slots", [])
		for i: int in size:
			var car: String = SaveSafe.s((raw_slots as Array)[i]) if raw_slots is Array and i < (raw_slots as Array).size() else ""
			slots.append(car if not car.is_empty() and not CarCatalog.get_entry(StringName(car)).is_empty() else "")
		out[String(id)] = {"levels": levels, "slots": slots}
	return out


## JSON sınırı aşılınca: depo yerleşimi düşürülmüş kopya (özet kalır).
static func without_depots(garage: Dictionary) -> Dictionary:
	var out: Dictionary = garage.duplicate()
	out.erase("car_garages")
	return out


## Araç garajlarının özeti {"own": Array[String] (merdiven sırasıyla), "cap": int}; yoksa boş. Kayıttan ("car_garages"
## bölümü: garajların PARK YERİ seviyesinden) ya da açık garajdan (SUMMARY_KEY, sunucudan gelen veri: süzülür) okunur.
static func car_garage_summary(garage: Dictionary) -> Dictionary:
	var own: Array = []
	var cap: int = 0
	if garage.get("car_garages") is Dictionary:
		var garages: Variant = (garage["car_garages"] as Dictionary).get("garages", {})
		if not garages is Dictionary:
			return {}
		for id: StringName in CarGarageCatalog.ids():
			var row: Variant = (garages as Dictionary).get(String(id))
			if not row is Dictionary:
				continue
			own.append(String(id))
			var levels: Variant = (row as Dictionary).get("levels", {})
			var park: int = SaveSafe.i((levels as Dictionary).get(String(CarGarageCatalog.PARK), 1)) if levels is Dictionary else 1
			cap += CarGarageCatalog.capacity_at(id, clampi(park, 1, CarGarageCatalog.max_level(id, CarGarageCatalog.PARK)))
	elif garage.get(SUMMARY_KEY) is Dictionary:
		var raw: Dictionary = garage[SUMMARY_KEY]
		var listed: Array = raw.get("own", []) if raw.get("own") is Array else []
		for id: StringName in CarGarageCatalog.ids():
			if listed.has(String(id)):
				own.append(String(id))
		cap = clampi(SaveSafe.i(raw.get("cap", 0)), 0, CarGarageCatalog.total_max_capacity())
	if own.is_empty():
		return {}
	return {"own": own, "cap": cap}


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


## Sunucudan gelen JSON'u okur (sıkışık ya da düz). Geçersizse ya da sürümü desteklenmiyorsa boş sözlük.
## `max_len`: açılmış metnin sınırı (oyunla gelen öne çıkan garajlar kendi sınırını verir).
## Yalnızca AÇIK bölümler döner (from_snapshot süzgeci): belgeyi oyunu atlayıp elle yazan biri tamir işi, ekonomi,
## ilerleme gibi bölümler eklerse ziyaret modunda SaveManager._apply onları da yüklüyordu.
static func parse(text: String, max_len: int = CloudPack.MAX_PLAIN) -> Dictionary:
	var json: String = CloudPack.unpack(text)
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
