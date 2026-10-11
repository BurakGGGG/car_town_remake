class_name RestorationCatalog
## HURDALIK / RESTORASYON kataloğu — parça türleri, kademeler ve restore edilebilir araçların TEK kaynağı.
## Veri: res://vehicles/restorations.json. Araştırma ve kararlar: docs/HURDALIK_ARASTIRMA.md.
##
## Restorasyon aracı ancak vehicles/cars.json'da AYNI id ile kayıtlıysa (modeli hazırsa) oyunda görünür.
## Kaydı olmayan plan aracı "model bekleniyor" sayılır: all_planned() onu döndürür, cars() döndürmez.
## Parçalar genel ve yığılabilir (orijinal Car Town gibi): her araç kendi reçetesinden adet ister.
## Kayıtlar salt okunurdur.

const DATA_PATH: String = "res://vehicles/restorations.json"

static var _parts: Array[Dictionary] = []
static var _part_by_id: Dictionary = {}
static var _tiers: Array[Dictionary] = []
static var _tier_by_id: Dictionary = {}
static var _planned: Array[Dictionary] = []   # json'daki sırayla, modeli olsun olmasın
static var _by_id: Dictionary = {}
static var _yard: Dictionary = {}
static var _loaded_from: String = ""
## Saha kuralları eksikse (eski / bozuk veri) kullanılan değerler.
const YARD_DEFAULTS: Dictionary = {
	"daily_cars": 3, "piles": 6, "refill_minutes": 480, "empty_chance": 0.25, "parts_min": 1, "parts_max": 1,
	"repair_drop": 0.1,
}


# --- Parçalar ------------------------------------------------------------------------

static func parts() -> Array[Dictionary]:
	_ensure_loaded()
	return _parts


static func part(part_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _part_by_id.get(part_id, {})


static func part_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in parts():
		out.append(p["id"])
	return out


static func is_part(part_id: StringName) -> bool:
	return not part(part_id).is_empty()


static func part_name(part_id: StringName) -> String:
	return str(part(part_id).get("name", String(part_id).to_upper()))


## Eksik parçanın gemle tanesi (0 = gemle alınamaz).
static func part_gem_price(part_id: StringName) -> int:
	return int(part(part_id).get("gem_price", 0))


# --- Kademeler -----------------------------------------------------------------------

static func tiers() -> Array[Dictionary]:
	_ensure_loaded()
	return _tiers


static func tier(tier_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _tier_by_id.get(tier_id, {})


## Kademenin açılması için tamamlanmış olması gereken TEMEL restorasyon sayısı.
static func tier_requirement(tier_id: StringName) -> int:
	return int(tier(tier_id).get("requires_completed", 0))


# --- Araçlar -------------------------------------------------------------------------

## Plandaki tüm araçlar (modeli hazır olmayanlar dahil), json sırasıyla.
static func all_planned() -> Array[Dictionary]:
	_ensure_loaded()
	return _planned


## Oyunda kullanılabilen restorasyon araçları (cars.json'da kaydı olanlar). tier boşsa hepsi.
static func cars(tier_id: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in all_planned():
		if (tier_id == &"" or entry["tier"] == tier_id) and has_model(entry["id"]):
			out.append(entry)
	return out


static func get_entry(vehicle_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _by_id.get(vehicle_id, {})


## Bu araç restorasyonla kazanılan bir araç mı (modeli hazır olsun olmasın)?
static func is_restoration(vehicle_id: StringName) -> bool:
	return not get_entry(vehicle_id).is_empty()


static func has_model(vehicle_id: StringName) -> bool:
	return not CarCatalog.get_entry(vehicle_id).is_empty()


static func tier_of(vehicle_id: StringName) -> StringName:
	return StringName(get_entry(vehicle_id).get("tier", &""))


## Parça → gereken adet (kopya; değiştirilebilir).
static func recipe(vehicle_id: StringName) -> Dictionary:
	return (get_entry(vehicle_id).get("recipe", {}) as Dictionary).duplicate()


static func required(vehicle_id: StringName, part_id: StringName) -> int:
	return int((get_entry(vehicle_id).get("recipe", {}) as Dictionary).get(part_id, 0))


static func total_required(vehicle_id: StringName) -> int:
	var total: int = 0
	for n: Variant in (get_entry(vehicle_id).get("recipe", {}) as Dictionary).values():
		total += int(n)
	return total


# --- Saha ---------------------------------------------------------------------------

## Hurdalık sahası kuralı (restorations.json "yard"): daily_cars, piles, refill_minutes, empty_chance,
## parts_min, parts_max, repair_drop. Sayılar sınırlanır (bozuk veri oyunu kilitlemesin).
static func yard_rule(key: String) -> float:
	_ensure_loaded()
	return float(_yard.get(key, YARD_DEFAULTS.get(key, 0)))


static func yard_int(key: String) -> int:
	return int(yard_rule(key))


# --- Yükleme -----------------------------------------------------------------------

static func load_from(path: String = DATA_PATH) -> bool:
	_parts = []
	_part_by_id = {}
	_tiers = []
	_tier_by_id = {}
	_planned = []
	_by_id = {}
	_yard = {}
	_loaded_from = path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RestorationCatalog: '%s' açılamadı (%d)" % [path, FileAccess.get_open_error()])
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		push_error("RestorationCatalog: '%s' geçersiz JSON" % path)
		return false
	for raw: Variant in (data as Dictionary).get("parts", []):
		if not (raw is Dictionary):
			continue
		var id: StringName = StringName(str(raw.get("id", "")))
		if id == &"" or _part_by_id.has(id):
			continue
		var p: Dictionary = {
			"id": id,
			"name": str(raw.get("name", String(id).to_upper())),
			"gem_price": maxi(int(raw.get("gem_price", 0)), 0),
		}
		p.make_read_only()
		_parts.append(p)
		_part_by_id[id] = p
	for raw: Variant in (data as Dictionary).get("tiers", []):
		if not (raw is Dictionary):
			continue
		var id: StringName = StringName(str(raw.get("id", "")))
		if id == &"" or _tier_by_id.has(id):
			continue
		var t: Dictionary = {
			"id": id,
			"name": str(raw.get("name", String(id).to_upper())),
			"requires_completed": maxi(int(raw.get("requires_completed", 0)), 0),
		}
		t.make_read_only()
		_tiers.append(t)
		_tier_by_id[id] = t
	var yard: Variant = (data as Dictionary).get("yard", {})
	if yard is Dictionary:
		_yard = {
			"daily_cars": clampi(int(yard.get("daily_cars", 3)), 1, 3),
			"piles": clampi(int(yard.get("piles", 6)), 1, 6),
			"refill_minutes": clampi(int(yard.get("refill_minutes", 480)), 1, 7 * 24 * 60),
			"empty_chance": clampf(float(yard.get("empty_chance", 0.25)), 0.0, 0.95),
			"parts_min": clampi(int(yard.get("parts_min", 1)), 1, 10),
			"repair_drop": clampf(float(yard.get("repair_drop", 0.1)), 0.0, 1.0),
		}
		_yard["parts_max"] = clampi(int(yard.get("parts_max", 1)), int(_yard["parts_min"]), 10)
	for raw: Variant in (data as Dictionary).get("cars", []):
		if raw is Dictionary:
			var entry: Dictionary = _normalize(raw)
			if entry.is_empty() or _by_id.has(entry["id"]):
				continue
			entry.make_read_only()
			_planned.append(entry)
			_by_id[entry["id"]] = entry
	return true


static func _ensure_loaded() -> void:
	if _loaded_from == "":
		load_from(DATA_PATH)


static func _normalize(raw: Dictionary) -> Dictionary:
	var id: StringName = StringName(str(raw.get("id", "")))
	var tier_id: StringName = StringName(str(raw.get("tier", "")))
	if id == &"" or not _tier_by_id.has(tier_id):
		push_warning("RestorationCatalog: id'siz ya da kademesi bilinmeyen araç atlandı: %s" % raw)
		return {}
	var recipe_out: Dictionary = {}
	var raw_recipe: Variant = raw.get("recipe", {})
	if raw_recipe is Dictionary:
		for key: Variant in raw_recipe:
			var pid: StringName = StringName(str(key))
			var n: int = int(raw_recipe[key])
			if not _part_by_id.has(pid):
				push_warning("RestorationCatalog: '%s' reçetesinde bilinmeyen parça '%s'" % [id, pid])
				continue
			if n > 0:
				recipe_out[pid] = n
	if recipe_out.is_empty():
		push_warning("RestorationCatalog: '%s' reçetesi boş, atlandı" % id)
		return {}
	recipe_out.make_read_only()
	return {
		"id": id,
		"tier": tier_id,
		"name": str(raw.get("name", String(id))),
		"year": int(raw.get("year", 0)),
		"class": str(raw.get("class", "")),
		"recipe": recipe_out,
	}
