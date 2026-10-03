class_name GarageDecor
## GARAJ DEKORASYONU KATALOĞU — veri: res://decor/decorations.json (tek kaynak).
##
## Car Town'daki "Edit Garage" karşılığı. ÖNEMLİ FARK: Car Town'da eşyalar para ÜRETİRDİ
## (langırt, benzin pompası: tıklayınca 10 dakikada 13 coin). Bizde tamir döngüsü zaten
## dakikada ~3.400 ₺ basıyor ve 10. saatte 1,1 milyon ₺ ölü para birikiyor (ölçüldü,
## docs/AUDIT_2026_09.md §6). Bu yüzden eşyalar GELİR DEĞİL, GİDER: ödenen paranın bir kısmı
## GARAJ DEĞERİne yazılır, yani rütbe merdivenini uzatır ve biriken parayı emer.
##
## YENİ EŞYA = decorations.json'a bir kayıt + assets/decor/<id>.glb (ya da kayıtta scene_path).
## Kod değişmez; kategori, yerleşim türü ve fiyat kayıttan gelir, boyut modelden ölçülür.

## Eşya türleri (= palet kategorileri). JSON'da küçük harf ad olarak yazılır.
enum Kind {
	FLOOR_SURFACE,   # zemin kaplaması (yerleştirilmez, uygulanır)
	WALL_SURFACE,    # duvar kaplaması (yerleştirilmez, uygulanır)
	WORKSHOP,        # atölye eşyası
	LOUNGE,          # yaşam alanı eşyası
	WALL_ITEM,       # duvara asılan
	YARD,            # avlu düzeni: bariyer, konteyner, pompa...
	PLANT,           # bitki / peyzaj
	VEHICLE,         # SERGİ: sahip olunan araçlar (katalogda değil, VehicleOwnership'ten gelir)
}

## Yerleşim türleri.
const PLACE_FLOOR: StringName = &"floor"      # zemine, X/Z serbest, y otomatik
const PLACE_WALL: StringName = &"wall"        # garajın iç duvar yüzüne, yön duvardan
const PLACE_SURFACE: StringName = &"surface"  # zemin/duvar kaplaması: tek seçim, uygulanır

const DATA_PATH: String = "res://decor/decorations.json"
const KIND_KEYS: Dictionary = {
	"floor_surface": Kind.FLOOR_SURFACE, "wall_surface": Kind.WALL_SURFACE,
	"workshop": Kind.WORKSHOP, "lounge": Kind.LOUNGE, "wall_item": Kind.WALL_ITEM,
	"yard": Kind.YARD, "plant": Kind.PLANT,
}
## Kayıtta yoksa kullanılan değerler (JSON "defaults" bunları ezer).
const DEFAULT_ROTATION_STEP: float = 45.0

static var _items: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _defaults: Dictionary = {}
static var _loaded: bool = false


static func all() -> Array[Dictionary]:
	_ensure_loaded()
	return _items


static func get_item(id: StringName) -> Dictionary:
	_ensure_loaded()
	if is_vehicle(id):
		return _vehicle_item(id)
	return _by_id.get(id, {})


# --- Araç sergisi ----------------------------------------------------------------------
## Garajda sergilenen araç, dekor örneği olarak yaşar (konum, yön, geri al, kayıt aynı yoldan): eşya id'si
## "car:<araç id>". Sahiplik DEPO'dan değil VehicleOwnership'ten gelir (DecorManager.owned_of);
## her sahip olunan araç bir kez sergilenir, satılınca sergi de kalkar. Fiyatı / garaj değeri yoktur.
const VEHICLE_PREFIX: String = "car:"
## Sergilenen aracın dönüş adımı (derece): araç 15°'de açıyla durabilsin.
const VEHICLE_ROTATION_STEP: float = 15.0
static var _vehicle_items: Dictionary = {}


static func vehicle_item_id(vehicle_id: StringName) -> StringName:
	return StringName(VEHICLE_PREFIX + String(vehicle_id))


static func is_vehicle(id: StringName) -> bool:
	return String(id).begins_with(VEHICLE_PREFIX)


## "car:x" → x (araç değilse boş).
static func vehicle_of(id: StringName) -> StringName:
	return StringName(String(id).substr(VEHICLE_PREFIX.length())) if is_vehicle(id) else &""


static func _vehicle_item(id: StringName) -> Dictionary:
	if _vehicle_items.has(id):
		return _vehicle_items[id]
	var entry: Dictionary = CarCatalog.get_entry(vehicle_of(id))
	if entry.is_empty():
		return {}
	var item: Dictionary = {
		"id": id, "title": "%s %s" % [String(entry.get("brand", "")).to_upper(), String(entry.get("model", "")).to_upper()],
		"kind": Kind.VEHICLE, "placement": String(PLACE_FLOOR), "price": 0, "value": 0, "min_rank": 1,
		"rotation_step": VEHICLE_ROTATION_STEP, "vehicle": true,
	}
	_vehicle_items[id] = item
	return item


static func exists(id: StringName) -> bool:
	return not get_item(id).is_empty()


## Yerleşim türü: &"floor" | &"wall" | &"surface".
static func placement(id: StringName) -> StringName:
	return StringName(String(get_item(id).get("placement", PLACE_FLOOR)))


static func is_surface(id: StringName) -> bool:
	return placement(id) == PLACE_SURFACE


## Döndürme adımı (derece). Kayıtta yoksa katalog varsayılanı.
static func rotation_step(id: StringName) -> float:
	var item: Dictionary = get_item(id)
	return float(item.get("rotation_step", _defaults.get("rotation_step", DEFAULT_ROTATION_STEP)))


## Modelin yolu: kayıtta scene_path varsa o, yoksa assets/decor/<id>.glb geleneği.
static func scene_path(id: StringName) -> String:
	return String(get_item(id).get("scene_path", ""))


## İşlevli eşya mı (ileride: ATM, parça rafı...)? Gövdeyle aynı dönüşümü paylaşan oyun düğümü
## `gameplay_scene` alanında verilir. Şu an katalogda işlevli eşya yok.
static func is_functional(id: StringName) -> bool:
	return bool(get_item(id).get("functional", _defaults.get("functional", false)))


## Palet kategorileri: katalogda GERÇEKTEN bulunan türler, tür sırasıyla (uydurma kategori yok).
static func categories() -> Array[int]:
	_ensure_loaded()
	var seen: Dictionary = {}
	for item: Dictionary in _items:
		seen[int(item["kind"])] = true
	var out: Array[int] = []
	for kind: int in Kind.values():
		if seen.has(kind):
			out.append(kind)
	return out


static func items_in(kind: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in all():
		if int(item["kind"]) == kind:
			out.append(item)
	return out


## Kategori başlığı (arayüz).
static func kind_title(kind: int) -> String:
	match kind:
		Kind.FLOOR_SURFACE: return "AVLU ZEMİNİ"
		Kind.WALL_SURFACE: return "GARAJ DUVARI"
		Kind.WORKSHOP: return "ATÖLYE"
		Kind.LOUNGE: return "YAŞAM ALANI"
		Kind.YARD: return "AVLU DÜZENİ"
		Kind.PLANT: return "BİTKİ"
		_: return "PANO"


## Kataloğu JSON'dan (yeniden) yükler. Test ve araçlar başka dosya verebilir.
static func load_from(path: String = DATA_PATH) -> bool:
	_items.clear()
	_by_id.clear()
	_defaults = {}
	_loaded = true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GarageDecor: katalog açılamadı (%s)" % path)
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not ((data as Dictionary).get("items") is Array):
		push_error("GarageDecor: katalog bozuk (%s)" % path)
		return false
	_defaults = (data as Dictionary).get("defaults", {})
	for raw: Variant in (data as Dictionary)["items"]:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = (raw as Dictionary).duplicate()
		var kind_key: String = String(entry.get("kind", ""))
		if not KIND_KEYS.has(kind_key) or String(entry.get("id", "")) == "":
			push_warning("GarageDecor: geçersiz kayıt atlandı (%s)" % entry)
			continue
		# Kod tarafı tür ve kimliği enum / StringName olarak görür (JSON'da okunur metin).
		entry["id"] = StringName(String(entry["id"]))
		entry["kind"] = int(KIND_KEYS[kind_key])
		entry["price"] = int(entry.get("price", 0))
		entry["value"] = int(entry.get("value", 0))
		entry["min_rank"] = int(entry.get("min_rank", 1))
		if not entry.has("placement"):
			entry["placement"] = String(PLACE_SURFACE) if kind_key.ends_with("_surface") \
					else (String(PLACE_WALL) if kind_key == "wall_item" else String(PLACE_FLOOR))
		if _by_id.has(entry["id"]):
			push_warning("GarageDecor: yinelenen id '%s' atlandı" % entry["id"])
			continue
		_by_id[entry["id"]] = entry
		# "retired": mağazadan / paletten / kasa havuzundan kalkar; eskiden alınmış kopya kayıtta
		# yüklenmeye ve garajda durmaya devam eder (ARAÇ LİFTİ: artık tamir alanının kendisi).
		if bool(entry.get("retired", false)):
			continue
		_items.append(entry)
	return true


static func _ensure_loaded() -> void:
	if not _loaded:
		load_from()
