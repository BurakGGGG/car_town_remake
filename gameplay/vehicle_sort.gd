class_name VehicleSort
extends RefCounted
## TÜM ARAÇLAR panosunun filtre ve sıralama kuralları — tek yer (pano yalnızca bunu çağırır, test de bunu sınar).
## Kayıt tutmaz, sinyali yoktur: her çağrıda RaceManager / VehicleOwnership / katalogdan okur.
##
## Filtreler (kullanıcı kararı 2026-10-19, docs/GARAJLAR_TASARIM.md §1): SINIF (modifiye dahil sınıf,
## PerformanceMods.class_of) ve NADİRLİK (katalog rarity). Gövde tipi ve yazıyla arama yok.
## Sıralama ölçüleri:
##   FASTEST    — modifiye dahil kusursuz 300 m süresi (sınıfı belirleyen değer), küçük önde
##   MOST_RACED — bu araçla biten yarış (RaceManager.vehicle_races)
##   MOST_WINS  — bu araçla kazanılan yarış
##   VALUE      — katalog fiyatı (garaj değerine katkısıyla aynı ölçü, GarageValue.vehicles_value)
##   NEWEST     — edinme sırası, en yeni önde (VehicleOwnership._owned alınma sırasıyla tutulur)
## Eşitlikte araç adına göre sıralanır: aynı değerli iki araç her açılışta aynı yerde durur.

const FASTEST: StringName = &"fastest"
const MOST_RACED: StringName = &"most_raced"
const MOST_WINS: StringName = &"most_wins"
const VALUE: StringName = &"value"
const NEWEST: StringName = &"newest"

## Seçicide görünme sırası.
const KEYS: Array[StringName] = [NEWEST, FASTEST, MOST_RACED, MOST_WINS, VALUE]


static func label(key: StringName) -> String:
	match key:
		FASTEST: return Loc.t("EN HIZLI")
		MOST_RACED: return Loc.t("EN ÇOK YARIŞILAN")
		MOST_WINS: return Loc.t("EN ÇOK KAZANAN")
		VALUE: return Loc.t("EN DEĞERLİ")
	return Loc.t("SON EKLENEN")


## Sınıf ("" = hepsi) ve nadirlik (&"" = hepsi) süzgeci; sıra korunur.
static func filter(ids: Array[StringName], klass: String, rarity: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if klass != "" and PerformanceMods.class_of(id) != klass:
			continue
		if rarity != &"" and CrateCatalog.rarity_of(id) != rarity:
			continue
		out.append(id)
	return out


## `ids` edinme sırasıyla gelmelidir (VehicleOwnership.owned_vehicle_ids). `race` yoksa yarış sayaçları 0 sayılır.
static func sort(ids: Array[StringName], key: StringName, race: RaceManager) -> Array[StringName]:
	var rows: Array[Dictionary] = []
	for i: int in ids.size():
		var id: StringName = ids[i]
		rows.append({"id": id, "metric": _metric(id, key, race, i),
			"name": String(CarCatalog.get_entry(id).get("display_name", id))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["metric"] != b["metric"]:
			return a["metric"] > b["metric"]
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	var out: Array[StringName] = []
	for row: Dictionary in rows:
		out.append(row["id"])
	return out


## Büyük = önde. FASTEST'te süre eksiye çevrilir; NEWEST'te listedeki sıra.
static func _metric(id: StringName, key: StringName, race: RaceManager, order: int) -> float:
	match key:
		FASTEST: return -PerformanceMods.time_300(id)
		MOST_RACED: return float(race.vehicle_races(id)) if race else 0.0
		MOST_WINS: return float(race.vehicle_wins(id)) if race else 0.0
		VALUE: return float(CarCatalog.get_entry(id).get("price", 0))
	return float(order)


## Kartın alt satırı: seçili sıralamanın ölçüsü ("GENEL 812", "12 YARIŞ", "85.000 ₺" …).
static func metric_text(id: StringName, key: StringName, race: RaceManager) -> String:
	match key:
		FASTEST: return Loc.t("GENEL %d") % PerformanceMods.overall(id)
		MOST_RACED: return Loc.t("%d YARIŞ") % (race.vehicle_races(id) if race else 0)
		MOST_WINS: return Loc.t("%d GALİBİYET") % (race.vehicle_wins(id) if race else 0)
		VALUE: return "%s ₺" % Hud.format_thousands(int(CarCatalog.get_entry(id).get("price", 0)))
	return ""
