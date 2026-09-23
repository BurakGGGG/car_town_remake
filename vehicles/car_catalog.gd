class_name CarCatalog
## Araç kataloğu — araç bilgisinin TEK kaynağı. Veri: res://vehicles/cars.json (yalnızca metadata;
## model/sahne yüklenmez). Galeri, Garaj, Trafik ve görünüm varsayılanı buradan okur.
##
## Kayıt alanları (normalize edilmiş):
##   id (StringName), brand, model, display_name, year (int), price (int), condition (0–1),
##   category, scene_path (oyunun kullandığı sahne: wrapper .tscn veya doğrudan optimized .glb),
##   source_path (editör kaynağı, export dışı), optimized_path, default_color (fabrika boyası),
##   available_colors (Array[Color]), world_node (Main.tscn'deki node adı; yoksa boş),
##   plate_color (galeri plakası siluet rengi), traffic (bool: NPC trafiğinde kullanılsın mı),
##   label (isteğe bağlı plaka metni; boşsa MARKA\nMODEL).
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


## Ham JSON kaydını tipli kayda çevirir; zorunlu alan eksikse boş döner.
static func _normalize(raw: Dictionary) -> Dictionary:
	var id: String = String(raw.get("id", ""))
	var scene: String = String(raw.get("scene_path", ""))
	if id == "" or scene == "":
		push_warning("CarCatalog: id/scene_path eksik kayıt atlandı: %s" % raw)
		return {}
	var brand: String = String(raw.get("brand", ""))
	var model: String = String(raw.get("model", ""))
	var colors: Array[Color] = []
	for c: Variant in raw.get("available_colors", []):
		colors.append(_color(c, Color.WHITE))
	return {
		"id": StringName(id),
		"brand": brand,
		"model": model,
		"display_name": String(raw.get("display_name", ("%s %s" % [brand, model]).strip_edges())),
		"label": String(raw.get("label", "")),
		"year": int(raw.get("year", 0)),
		"price": int(raw.get("price", 0)),
		"condition": clampf(float(raw.get("condition", 1.0)), 0.0, 1.0),
		"category": String(raw.get("category", "")),
		"scene_path": scene,
		"source_path": String(raw.get("source_path", "")),
		"optimized_path": String(raw.get("optimized_path", "")),
		"default_color": _color(raw.get("default_color", "#FFFFFF"), Color.WHITE),
		"available_colors": colors,
		"world_node": StringName(String(raw.get("world_node", ""))),
		"plate_color": _color(raw.get("plate_color", "#F3E8CF"), Color("F3E8CF")),
		"traffic": bool(raw.get("traffic", true)),
	}


## "#RRGGBB" / "RRGGBB" metni ya da [r, g, b(, a)] float dizisi.
static func _color(value: Variant, fallback: Color) -> Color:
	if value is String:
		var text: String = value
		return Color.html(text) if Color.html_is_valid(text) else fallback
	if value is Array and (value as Array).size() >= 3:
		var a: Array = value
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return fallback
