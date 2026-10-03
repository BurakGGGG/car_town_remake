class_name CarCatalog
## Araç kataloğu — araç bilgisinin TEK kaynağı. Veri: res://vehicles/cars.json (yalnızca metadata;
## model/sahne yüklenmez). Galeri, Garaj, Trafik ve görünüm varsayılanı buradan okur.
##
## Kayıt alanlarının TEK tanımı aşağıdaki SCHEMA tablosudur; bu belge onu tekrarlamaz.
## Yeni bir alan eklemek = SCHEMA'ya bir satır eklemek (başka hiçbir yeri değiştirmeye gerek yok).
## Zincir: Katalog → scene_path → CarPartMap (parça rolleri) → CarRig → CarAppearance.
## Yeni araç: source GLB → tools/optimize_car.gd → optimized GLB (+ isteğe bağlı wrapper .tscn)
## → cars.json'a kayıt → CarPartMap'e rol haritası. Başka kod değişikliği gerekmez.
##
## Kayıtlar salt okunurdur; sahne yükleme çağırana aittir (load / ResourceLoader), böylece
## yalnızca ihtiyaç duyulan modeller bellekte olur.

const DATA_PATH: String = "res://vehicles/cars.json"

static var _entries: Array[Dictionary] = []
static var _by_id: Dictionary = {}      # id → kayıt
static var _by_node: Dictionary = {}    # world_node → kayıt
static var _by_scene: Dictionary = {}   # scene_path → kayıt
static var _loaded_from: String = ""
static var _last_parse_msec: float = 0.0


## Tüm kayıtlar, dosyadaki sırayla (salt okunur Dictionary'ler).
static func all() -> Array[Dictionary]:
	_ensure_loaded()
	return _entries


static func size() -> int:
	_ensure_loaded()
	return _entries.size()


static func get_entry(id: StringName) -> Dictionary:
	_ensure_loaded()
	return _by_id.get(id, {})


## Main.tscn'deki araç node adına göre kayıt (seçim sistemi node adlarıyla çalışır).
static func find(node_name: StringName) -> Dictionary:
	_ensure_loaded()
	return _by_node.get(node_name, {})


static func find_by_scene(scene_path: String) -> Dictionary:
	_ensure_loaded()
	return _by_scene.get(scene_path, {})


## ARACIN OYUN ÖLÇEĞİ — gerçek boyuttan türetilmiş çarpan (cars.json "model_scale").
## Aracı sahneye koyan HER yer (trafik, garaj, showroom, drag) kendi bağlam çarpanını bununla
## çarpar; böylece dört yerde de aynı fiziksel oran görünür. Koda araç adı gömülmez.
static func model_scale(id: StringName) -> float:
	var entry: Dictionary = get_entry(id)
	return float(entry.get("model_scale", 1.0)) if not entry.is_empty() else 1.0


## Sahne yolundan ölçek (garaj/showroom yalnızca yolu biliyor).
static func model_scale_for_scene(scene_path_value: String) -> float:
	var entry: Dictionary = find_by_scene(scene_path_value)
	return float(entry.get("model_scale", 1.0)) if not entry.is_empty() else 1.0


static func scene_path(id: StringName) -> String:
	return String(get_entry(id).get("scene_path", ""))


## Galeri plakası metni: kayıttaki "label" varsa o, yoksa "MARKA\nMODEL" (to_upper Türkçe İ üretmez;
## gerekirse label alanı ile elle verilir).
static func label(entry: Dictionary) -> String:
	var custom: String = entry.get("label", "")
	if custom != "":
		return custom
	return "%s\n%s" % [String(entry.get("brand", "")).to_upper(), String(entry.get("model", "")).to_upper()]


## Fabrika boyası. Katalogda olmayan sahneler için CarPartMap.default_paint'e düşer.
static func default_color_for(scene_path_: String) -> Color:
	var entry: Dictionary = find_by_scene(scene_path_)
	if not entry.is_empty():
		return entry["default_color"]
	return CarPartMap.get_map(scene_path_).get("default_paint", Color.WHITE)


## Son yüklemenin ayrıştırma süresi (ms) — ölçüm için.
static func last_parse_msec() -> float:
	return _last_parse_msec


## Kataloğu verilen JSON dosyasından (yeniden) yükler. Varsayılan: DATA_PATH.
static func load_from(path: String = DATA_PATH) -> bool:
	var t0: int = Time.get_ticks_usec()
	_entries = []
	_by_id = {}
	_by_node = {}
	_by_scene = {}
	_loaded_from = path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CarCatalog: '%s' açılamadı (%d)" % [path, FileAccess.get_open_error()])
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not ((data as Dictionary).get("cars", null) is Array):
		push_error("CarCatalog: '%s' geçersiz (beklenen: {\"cars\": [...]})" % path)
		return false
	for raw: Variant in (data as Dictionary)["cars"]:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = _normalize(raw)
		if entry.is_empty():
			continue
		if _by_id.has(entry["id"]):
			push_warning("CarCatalog: tekrarlayan id '%s' atlandı" % entry["id"])
			continue
		entry.make_read_only()
		_entries.append(entry)
		_by_id[entry["id"]] = entry
		_by_scene[entry["scene_path"]] = entry
		if entry["world_node"] != &"":
			_by_node[entry["world_node"]] = entry
	_last_parse_msec = (Time.get_ticks_usec() - t0) / 1000.0
	return true


static func _ensure_loaded() -> void:
	if _loaded_from == "":
		load_from(DATA_PATH)


## Alan türleri (SCHEMA "kind" sütunu).
enum Kind { TEXT, NAME, INT, FLOAT, BOOL, COLOR, COLOR_LIST, STATS, DIMENSIONS }

## "race" bloğundaki alanlar ve alan yoksa kullanılan değerler. Yarış istatistikleri cars.json'da
## TEK KAYNAKTADIR; burada yalnızca eksik alanın güvenli varsayılanı vardır (sınıfa göre kabaca D).
const RACE_STATS: Dictionary = {"top_speed": 100, "acceleration": 55, "reaction": 50, "grip": 50}

## GERÇEK ARAÇ ÖLÇÜLERİ (metre) — "real_dimensions" bloğu. Kaynak: üretici/teknik veri siteleri,
## bkz. docs/VEHICLE_SCALE.md. Oyun ölçeği bu tablodan TÜRETİLİR (model_scale), koda gömülmez.
const DIMENSIONS: Dictionary = {"length_m": 4.39, "width_m": 1.75, "height_m": 1.45, "wheelbase_m": 2.60}

## ÖLÇEK REFERANSI: 16 aracın ortalama gerçek uzunluğu (m). Bir aracın oyundaki ölçeği
## `gerçek uzunluk / REFERENCE_LENGTH_M`'dir; yani ortalama araç 1,0 ölçekte kalır ve MEVCUT dünya
## ölçeği değişmez (trafik 0,6 · drag 1,2 · showroom 0,88 · garaj 1,0 bağlam çarpanları aynı).
const REFERENCE_LENGTH_M: float = 4.39

## KAYIT ŞEMASI — cars.json'daki alanların TEK tanımı. _normalize bu tabloyu gezer; elle alan
## kopyalanmaz. Eskiden tablo yoktu ve _normalize sabit bir sözlük kurduğu için JSON'a eklenen
## yeni alan SESSİZCE düşüyordu (min_level / min_garage_rank bu yüzden çalışmamıştı, 2026-09-26).
## Tabloda olmayan bir alan JSON'da görülürse artık uyarı verilir — yazım hatası da sessiz kalmaz.
##   key      : JSON ve kayıt anahtarı
##   kind     : tür dönüşümü
##   default  : alan yoksa kullanılan değer ("" / 0 / 1.0 / Color / [] ...)
##   required : boşsa kayıt tamamen atlanır
##   min/max  : sayısal sınır (isteğe bağlı)
const SCHEMA: Array[Dictionary] = [
	{"key": "id", "kind": Kind.NAME, "default": &"", "required": true},
	{"key": "brand", "kind": Kind.TEXT, "default": ""},
	{"key": "model", "kind": Kind.TEXT, "default": ""},
	{"key": "display_name", "kind": Kind.TEXT, "default": ""},   # boşsa "MARKA MODEL" türetilir
	{"key": "label", "kind": Kind.TEXT, "default": ""},          # galeri plakası metni; boşsa MARKA\nMODEL
	{"key": "year", "kind": Kind.INT, "default": 0},
	{"key": "price", "kind": Kind.INT, "default": 0, "min": 0},
	{"key": "condition", "kind": Kind.FLOAT, "default": 1.0, "min": 0.0, "max": 1.0},
	{"key": "category", "kind": Kind.TEXT, "default": ""},
	{"key": "class", "kind": Kind.TEXT, "default": ""},          # D/C/B/A — yalnızca gösterim
	{"key": "rarity", "kind": Kind.NAME, "default": &"common"},  # kasa nadirliği (bkz. CrateCatalog) — sınıftan BAĞIMSIZ
	{"key": "min_level", "kind": Kind.INT, "default": 1, "min": 1},          # showroom kilidi (oyuncu seviyesi)
	{"key": "min_garage_rank", "kind": Kind.INT, "default": 1, "min": 1},    # showroom kilidi (GarageValue rütbesi)
	{"key": "scene_path", "kind": Kind.TEXT, "default": "", "required": true},
	{"key": "source_path", "kind": Kind.TEXT, "default": ""},
	{"key": "optimized_path", "kind": Kind.TEXT, "default": ""},
	{"key": "default_color", "kind": Kind.COLOR, "default": Color.WHITE},
	{"key": "available_colors", "kind": Kind.COLOR_LIST, "default": []},
	{"key": "world_node", "kind": Kind.NAME, "default": &""},
	{"key": "plate_color", "kind": Kind.COLOR, "default": Color("F3E8CF")},
	{"key": "traffic", "kind": Kind.BOOL, "default": true},
	{"key": "race", "kind": Kind.STATS, "default": {}},   # drag yarışı statları (bkz. RACE_STATS)
	{"key": "real_dimensions", "kind": Kind.DIMENSIONS, "default": {}},  # gerçek dış ölçüler (m)
	{"key": "model_scale", "kind": Kind.FLOAT, "default": 1.0, "min": 0.01},  # gerçek boyuta göre ölçek
]


## Ham JSON kaydını SCHEMA'ya göre tipli kayda çevirir; zorunlu alan eksikse boş döner.
static func _normalize(raw: Dictionary) -> Dictionary:
	var entry: Dictionary = {}
	for field: Dictionary in SCHEMA:
		var key: String = field["key"]
		var value: Variant = _convert(raw.get(key, null), field)
		if bool(field.get("required", false)) and _is_blank(value):
			push_warning("CarCatalog: zorunlu alan '%s' eksik, kayıt atlandı: %s" % [key, raw])
			return {}
		entry[key] = value
	if String(entry["display_name"]) == "":
		entry["display_name"] = ("%s %s" % [entry["brand"], entry["model"]]).strip_edges()
	for key: Variant in raw:
		if not _known_key(String(key)):
			push_warning("CarCatalog: '%s' kaydında tanınmayan alan '%s' (SCHEMA'ya ekle)"
					% [entry["id"], key])
	return entry


static func _known_key(key: String) -> bool:
	for field: Dictionary in SCHEMA:
		if field["key"] == key:
			return true
	return false


static func _is_blank(value: Variant) -> bool:
	return value == null or value == "" or value == &""


## Tek bir alanı şemadaki türe çevirir (alan yoksa varsayılan).
static func _convert(value: Variant, field: Dictionary) -> Variant:
	var fallback: Variant = field["default"]
	match int(field["kind"]):
		Kind.TEXT:
			return String(value) if value != null else String(fallback)
		Kind.NAME:
			return StringName(String(value)) if value != null else StringName(fallback)
		Kind.INT:
			var i: int = int(value) if value != null else int(fallback)
			i = maxi(i, int(field["min"])) if field.has("min") else i
			return mini(i, int(field["max"])) if field.has("max") else i
		Kind.FLOAT:
			var f: float = float(value) if value != null else float(fallback)
			f = maxf(f, float(field["min"])) if field.has("min") else f
			return minf(f, float(field["max"])) if field.has("max") else f
		Kind.BOOL:
			return bool(value) if value != null else bool(fallback)
		Kind.COLOR:
			return _color(value, fallback) if value != null else fallback
		Kind.STATS:
			var raw: Dictionary = value if value is Dictionary else {}
			var stats: Dictionary = {}
			for key: String in RACE_STATS:
				stats[key] = maxi(int(raw.get(key, RACE_STATS[key])), 0)
			for key: Variant in raw:
				if not RACE_STATS.has(String(key)):
					push_warning("CarCatalog: 'race' bloğunda tanınmayan alan '%s'" % key)
			return stats
		Kind.DIMENSIONS:
			var dims_raw: Dictionary = value if value is Dictionary else {}
			var dims: Dictionary = {}
			for key: String in DIMENSIONS:
				dims[key] = maxf(float(dims_raw.get(key, DIMENSIONS[key])), 0.0)
			for key: Variant in dims_raw:
				if not DIMENSIONS.has(String(key)):
					push_warning("CarCatalog: 'real_dimensions' bloğunda tanınmayan alan '%s'" % key)
			return dims
		Kind.COLOR_LIST:
			var colors: Array[Color] = []
			for c: Variant in (value if value is Array else []):
				colors.append(_color(c, Color.WHITE))
			return colors
	return fallback



## "#RRGGBB" / "RRGGBB" metni ya da [r, g, b(, a)] float dizisi.
static func _color(value: Variant, fallback: Color) -> Color:
	if value is String:
		var text: String = value
		return Color.html(text) if Color.html_is_valid(text) else fallback
	if value is Array and (value as Array).size() >= 3:
		var a: Array = value
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return fallback
