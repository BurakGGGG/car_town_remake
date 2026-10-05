class_name PublicGarage
extends RefCounted
## HERKESE AÇIK GARAJ: kayıt sözlüğünün (SaveManager.snapshot) yalnızca GÖRSEL kısmı.
## Arkadaşlar bunu okur ve garajı ziyaret modunda aynı kodla kurar (GarageVisit).
##
## İçinde OLANLAR: sürüm, oyuncu seviyesi, garaj seviyeleri, tamir alanları (sayı + yerleşim), dekor
## (eşyalar, zemin karoları, duvarlar), araçlar (sahip olunanlar + boyalar; dekor araçları bunlara bakar).
## OLMAYANLAR: para, XP, gem, kasalar, görevler, reklam sayaçları, ustalık. Bunlar başkasına gösterilmez.
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
	return out


## Sıralı anahtarlı JSON (değişti mi karşılaştırması için tek biçim).
static func to_json(garage: Dictionary) -> String:
	return JSON.stringify(garage, "", true)


## Sunucudan gelen JSON'u okur. Geçersizse ya da sürümü desteklenmiyorsa boş sözlük.
static func parse(json: String) -> Dictionary:
	if json.is_empty() or json.length() > MAX_JSON:
		return {}
	var raw: Variant = JSON.parse_string(json)
	if not raw is Dictionary:
		return {}
	var version: int = SaveSafe.i((raw as Dictionary).get("version", 0))
	if version < SaveManager.MIN_VERSION or version > SaveManager.SAVE_VERSION:
		return {}
	return raw


## Oyuncu seviyesi (liste satırında gösterilir).
static func level_of(garage: Dictionary) -> int:
	var progress: Dictionary = garage.get("progress", {}) if garage.get("progress") is Dictionary else {}
	return maxi(SaveSafe.i(progress.get("level", 1)), 1)
