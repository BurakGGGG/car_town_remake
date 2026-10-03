class_name CrateCatalog
## ARAÇ TESLİMAT KASALARI kataloğu — kasa ve nadirlik bilgisinin TEK kaynağı.
## Veri: res://vehicles/crates.json (yalnızca metadata; kasa modeli burada YÜKLENMEZ — dünyadaki
## kasa kurulurken tembel yüklenir, bkz. world/crate_visual.gd). Aracın nadirliği cars.json'dadır.
##
## OLASILIK: bir aracın bir kasadan çıkma olasılığı = nadirlik ağırlığı / havuzdaki ağırlıkların
## toplamı. Oyuncunun sahip olduğu ya da keşfettiği araçlar olasılığı DEĞİŞTİRMEZ; ekranda
## gösterilen oran her zaman gerçek orandır (docs/vehicle_crate_design_v2.md §7).
## Kayıtlar salt okunurdur.

const DATA_PATH: String = "res://vehicles/crates.json"

## Nadirlikler, düşükten yükseğe (sıra kopya hurdası ve yıldız görselleri için de kullanılır).
const RARITY_ORDER: Array[StringName] = [&"common", &"rare", &"epic", &"legendary"]

## Kasa dünyadaki boyutunun yedeği (JSON'da world_size yoksa).
const DEFAULT_WORLD_SIZE: Vector3 = Vector3(0.72, 0.38, 0.46)

static var _crates: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _rarities: Dictionary = {}   # id → {"label", "weight", "color"}
static var _world_size: Vector3 = DEFAULT_WORLD_SIZE
static var _sets: Array[Dictionary] = []   # koleksiyon setleri: {"id", "name", "cars": Array[StringName]}
static var _loaded_from: String = ""


static func all() -> Array[Dictionary]:
	_ensure_loaded()
	return _crates


static func get_entry(crate_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _by_id.get(crate_id, {})


static func exists(crate_id: StringName) -> bool:
	return not get_entry(crate_id).is_empty()


static func price(crate_id: StringName) -> int:
	return int(get_entry(crate_id).get("price_gems", 0))


static func min_level(crate_id: StringName) -> int:
	return int(get_entry(crate_id).get("min_level", 1))


static func pool(crate_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(get_entry(crate_id).get("pool", []))
	return out


## Dünyadaki kasanın dış ölçüsü (x uzun kenar, y yükseklik, z kısa kenar).
static func world_size() -> Vector3:
	_ensure_loaded()
	return _world_size


## Koleksiyon setleri (kasaları keser, tema üzerinden kurulur).
static func sets() -> Array[Dictionary]:
	_ensure_loaded()
	return _sets


## Aracın hangi kasadan çıktığı (yoksa &"").
static func crate_of(vehicle_id: StringName) -> StringName:
	for entry: Dictionary in all():
		if (entry["pool"] as Array).has(vehicle_id):
			return entry["id"]
	return &""


# --- Nadirlik ----------------------------------------------------------------------

static func rarity_of(vehicle_id: StringName) -> StringName:
	return StringName(CarCatalog.get_entry(vehicle_id).get("rarity", &"common"))


static func rarity_weight(rarity: StringName) -> float:
	_ensure_loaded()
	return float(_rarities.get(rarity, {}).get("weight", 0.0))


static func rarity_label(rarity: StringName) -> String:
	_ensure_loaded()
	return String(_rarities.get(rarity, {}).get("label", String(rarity).to_upper()))


static func rarity_color(rarity: StringName) -> Color:
	_ensure_loaded()
	return _rarities.get(rarity, {}).get("color", Color.GRAY)


static func rarity_rank(rarity: StringName) -> int:
	return maxi(RARITY_ORDER.find(rarity), 0)


# --- Olasılık ----------------------------------------------------------------------

## Kasadaki her aracın olasılığı, havuz sırasıyla: [{"id", "rarity", "chance"}]. Toplam 1.
static func odds(crate_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array[StringName] = pool(crate_id)
	var total: float = 0.0
	for id: StringName in ids:
		total += rarity_weight(rarity_of(id))
	if total <= 0.0:
		return out
	for id: StringName in ids:
		var rarity: StringName = rarity_of(id)
		out.append({"id": id, "rarity": rarity, "chance": rarity_weight(rarity) / total})
	return out


## Nadirlik başına toplam olasılık (kasa ekranındaki özet satırı): {rarity → chance}.
static func rarity_odds(crate_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in odds(crate_id):
		out[row["rarity"]] = float(out.get(row["rarity"], 0.0)) + float(row["chance"])
	return out


## Kasadan bir araç seçer (ağırlıklı, bağımsız). Havuz boşsa &"".
static func roll(crate_id: StringName, rng: RandomNumberGenerator) -> StringName:
	var rows: Array[Dictionary] = odds(crate_id)
	if rows.is_empty():
		return &""
	var weights: PackedFloat32Array = PackedFloat32Array()
	for row: Dictionary in rows:
		weights.append(float(row["chance"]))
	var index: int = rng.rand_weighted(weights)
	return rows[clampi(index, 0, rows.size() - 1)]["id"]


# --- Yükleme -----------------------------------------------------------------------

static func load_from(path: String = DATA_PATH) -> bool:
	_crates = []
	_by_id = {}
	_rarities = {}
	_sets = []
	_world_size = DEFAULT_WORLD_SIZE
	_loaded_from = path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CrateCatalog: '%s' açılamadı (%d)" % [path, FileAccess.get_open_error()])
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		push_error("CrateCatalog: '%s' geçersiz JSON" % path)
		return false
	for raw: Variant in (data as Dictionary).get("rarities", []):
		if raw is Dictionary:
			var r: Dictionary = raw
			_rarities[StringName(str(r.get("id", "")))] = {
				"label": str(r.get("label", "")),
				"weight": maxf(float(r.get("weight", 0.0)), 0.0),
				"color": Color.html(str(r.get("color", "#808080"))) if Color.html_is_valid(str(r.get("color", ""))) else Color.GRAY,
			}
	var size: Variant = (data as Dictionary).get("world_size", null)
	if size is Array and (size as Array).size() == 3:
		_world_size = Vector3(float(size[0]), float(size[1]), float(size[2]))
	for raw: Variant in (data as Dictionary).get("sets", []):
		if raw is Dictionary:
			var cars: Array[StringName] = []
			for v: Variant in (raw as Dictionary).get("cars", []):
				if not CarCatalog.get_entry(StringName(str(v))).is_empty():
					cars.append(StringName(str(v)))
			var set_entry: Dictionary = {"id": StringName(str(raw.get("id", ""))), "name": str(raw.get("name", "")), "cars": cars}
			set_entry.make_read_only()
			_sets.append(set_entry)
	for raw: Variant in (data as Dictionary).get("crates", []):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = _normalize(raw)
		if entry.is_empty() or _by_id.has(entry["id"]):
			continue
		entry.make_read_only()
		_crates.append(entry)
		_by_id[entry["id"]] = entry
	return true


static func _ensure_loaded() -> void:
	if _loaded_from == "":
		load_from(DATA_PATH)


static func _normalize(raw: Dictionary) -> Dictionary:
	var id: StringName = StringName(str(raw.get("id", "")))
	if id == &"":
		push_warning("CrateCatalog: id'siz kasa atlandı")
		return {}
	var pool_ids: Array[StringName] = []
	for v: Variant in raw.get("pool", []):
		var vid: StringName = StringName(str(v))
		if CarCatalog.get_entry(vid).is_empty():
			push_warning("CrateCatalog: '%s' havuzundaki '%s' katalogda yok, atlandı" % [id, vid])
			continue
		if not pool_ids.has(vid):
			pool_ids.append(vid)
	var color_text: String = str(raw.get("color", "#A08060"))
	return {
		"id": id,
		"display_name": str(raw.get("display_name", String(id).to_upper())),
		"short_name": str(raw.get("short_name", raw.get("display_name", String(id).to_upper()))),
		"price_gems": maxi(int(raw.get("price_gems", 0)), 0),
		"min_level": maxi(int(raw.get("min_level", 1)), 1),
		"pool": pool_ids,
		"color": Color.html(color_text) if Color.html_is_valid(color_text) else Color("A08060"),
		"scene_path": str(raw.get("scene_path", "")),
		"icon": str(raw.get("icon", "")),
		"open_effect": str(raw.get("open_effect", "")),
		"scale": maxf(float(raw.get("scale", 1.0)), 0.01),
	}
