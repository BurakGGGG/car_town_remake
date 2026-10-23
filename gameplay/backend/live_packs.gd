class_name LivePacks
extends Node
## İÇERİK PAKETLERİ (2026-10-23): güncelleme atmadan gelen içerik — etkinlik afişi, yeni dekor eşyaları (model paketin
## içinde). Paket Godot .pck dosyasıdır (tools/live_pack/build_pack.sh kurar); listesi config/app.packs'te
## ({id, url, sha256, size}, yönetim paneli yazar). Akış:
##   1. açılışta (LoadingScreen, kayıt okunmadan ÖNCE) cihazdaki paketler bağlanır: mount_cached — böylece paketten alınmış
##      eşyalar kayıt yüklenirken katalogdadır
##   2. AppConfig her okunduğunda listede olup cihazda olmayan (ya da özeti değişmiş) paket arka planda indirilir, SHA-256
##      tutarsa saklanır ve bağlanır; DecorManager.revive_dormant bekleyen eşyaları yerine koyar
## GÜVENLİK: paket yalnızca listedeki özetle birebir aynıysa bağlanır; ProjectSettings.load_resource_pack(..., false) —
## paket oyunun var olan hiçbir dosyasını EZEMEZ (Play kuralı: uygulama kendini Play dışından güncellemez). Paket yalnızca
## res://live/<kimlik>/ altına içerik (model, doku, resim, tanım) getirir, oyun kodu getirmez; tanımdaki model yolları da
## bu klasörün dışını gösteremez.
## Paket tanımı res://live/<kimlik>/pack.json: {id, banner: "banner.png" (ham PNG, isteğe bağlı), decor: [decorations.json
## kaydı + scene_path (paketin içinde) + title {dil} + event_only]}.
## Aynı kimlikli paketin yenisi (özet değişti) indirilir ama bu oturumda bağlanamaz (eski dosyalar bağlı): sonraki açılışta.

signal pack_ready(pack_id: String)

const NODE_NAME: String = "LivePacks"
const DIR: String = "user://live_packs/"
const INDEX: String = DIR + "index.json"
const ROOT: String = "res://live/"
## İndirme üst sınırı (bayt): listedeki boyut yanlış yazılsa da telefon şişmesin.
const MAX_BYTES: int = 64 * 1024 * 1024
const TIMEOUT_SEC: float = 120.0
## Başarısız indirme bu süre geçmeden yeniden denenmez (sn; uygulama açıkken).
const RETRY_SEC: float = 600.0

## Bu oturumda bağlanan paketler: kimlik → tanım (pack.json).
static var _mounted: Dictionary = {}

var _config: AppConfig
var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _failed_at: Dictionary = {}   # kimlik → Time.get_ticks_msec


func _init(config: AppConfig = null) -> void:
	name = NODE_NAME
	_config = config


func _ready() -> void:
	add_to_group("live_packs")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	_http.use_threads = true
	_http.request_completed.connect(_on_completed)
	add_child(_http)
	if _config:
		_config.changed.connect(sync)
	sync.call_deferred()


# --- Sorgu ---------------------------------------------------------------------------------

static func valid_id(pack_id: String) -> bool:
	return RegEx.create_from_string("^[a-z0-9_]{1,40}$").search(pack_id) != null


static func is_mounted(pack_id: String) -> bool:
	return _mounted.has(pack_id)


static func manifest(pack_id: String) -> Dictionary:
	return _mounted.get(pack_id, {})


## Paketin afişi (tanımda "banner": ham PNG). Yoksa / bağlı değilse null.
static func banner(pack_id: String) -> Texture2D:
	var file: String = SaveSafe.s(manifest(pack_id).get("banner", ""))
	if file.is_empty():
		return null
	var path: String = ROOT + pack_id + "/" + file
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


# --- Açılış: cihazdaki paketler -------------------------------------------------------------

## Cihazda saklanan (önceden indirilmiş, özeti tutan) paketleri bağlar. Kayıt okunmadan önce çağrılır. Dönen: kaç paket.
static func mount_cached() -> int:
	var index: Dictionary = _read_index()
	var count: int = 0
	for pack_id: String in index:
		var rec: Dictionary = index[pack_id] if index[pack_id] is Dictionary else {}
		var path: String = DIR + SaveSafe.s(rec.get("file", ""))
		if is_mounted(pack_id) or not valid_id(pack_id) or not FileAccess.file_exists(path):
			continue
		if FileAccess.get_sha256(path) != SaveSafe.s(rec.get("sha256", "")):
			push_warning("LivePacks: '%s' dosyası bozuk, yeniden indirilecek" % pack_id)
			continue
		if mount(pack_id, path):
			count += 1
	return count


## Paketi bağlar ve tanımındaki eşyaları kataloğa ekler (oyunun dosyalarını ezmez).
static func mount(pack_id: String, path: String) -> bool:
	if is_mounted(pack_id):
		return true
	if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(path), false):
		push_warning("LivePacks: '%s' bağlanamadı" % pack_id)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + pack_id + "/pack.json"))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if SaveSafe.s(data.get("id", "")) != pack_id:
		push_warning("LivePacks: '%s' paketinin tanımı yok ya da kimliği tutmuyor" % pack_id)
		return false
	var items: Array = []
	var raw: Variant = data.get("decor", [])
	for v: Variant in (raw if raw is Array else []):
		var item: Dictionary = _decor_entry(pack_id, v)
		if not item.is_empty():
			items.append(item)
	data["decor"] = items
	_mounted[pack_id] = data
	GarageDecor.register_pack_items(pack_id, items)
	return true


## Tanımdaki dekor kaydı: model yolu paketin klasöründe olmalı; başlık / açıklama dil sözlüğüyse oyuncunun dilinde.
static func _decor_entry(pack_id: String, raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var item: Dictionary = (raw as Dictionary).duplicate(true)
	var scene: String = SaveSafe.s(item.get("scene_path", ""))
	if not scene.begins_with(ROOT + pack_id + "/") or scene.contains(".."):
		push_warning("LivePacks: '%s' eşyasının modeli paketin dışında, atlandı" % item.get("id", ""))
		return {}
	for key: String in ["title", "desc"]:
		if item.get(key) is Dictionary:
			item[key] = AppConfig.text_of(item[key])
	item["title"] = Loc.upper(SaveSafe.s(item.get("title", "")))   # katalogdaki eşya adları gibi BÜYÜK harf
	item.erase("exclusive")   # kurucu eşya yalnızca oyunun kendisinden gelir
	return item


# --- İndirme --------------------------------------------------------------------------------

## Listede olup cihazda olmayan / özeti değişmiş paketleri sıraya koyar.
func sync() -> void:
	if _config == null:
		return
	var index: Dictionary = _read_index()
	var now: int = Time.get_ticks_msec()
	for pack: Dictionary in _config.packs():
		var pack_id: String = pack["id"]
		var rec: Dictionary = index.get(pack_id, {}) if index.get(pack_id) is Dictionary else {}
		var have: bool = SaveSafe.s(rec.get("sha256", "")) == pack["sha256"] \
			and FileAccess.file_exists(DIR + SaveSafe.s(rec.get("file", "")))
		if have:
			if not is_mounted(pack_id):
				_mount_and_revive(pack_id, DIR + SaveSafe.s(rec["file"]))
			continue
		if _queued(pack_id) or now - int(_failed_at.get(pack_id, -RETRY_SEC * 2000.0)) < int(RETRY_SEC * 1000.0):
			continue
		_queue.append(pack)
	_next()


func busy() -> bool:
	return not _current.is_empty() or not _queue.is_empty()


func _queued(pack_id: String) -> bool:
	if SaveSafe.s(_current.get("id", "")) == pack_id:
		return true
	for p: Dictionary in _queue:
		if p["id"] == pack_id:
			return true
	return false


func _next() -> void:
	if not _current.is_empty() or _queue.is_empty() or _http == null:
		return
	_current = _queue.pop_front()
	DirAccess.make_dir_recursive_absolute(DIR)
	_http.download_file = DIR + String(_current["id"]) + ".part"
	_http.body_size_limit = mini(maxi(int(_current["size"]) * 2, 1024 * 1024), MAX_BYTES)
	if _http.request(String(_current["url"])) != OK:
		_fail("istek başlamadı")


func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _current.is_empty():
		return
	var part: String = DIR + String(_current["id"]) + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("indirme hatası (%d / %d)" % [result, code])
		return
	if FileAccess.get_sha256(part) != String(_current["sha256"]):
		_fail("özet tutmuyor")
		return
	var pack_id: String = _current["id"]
	var file: String = "%s-%s.pck" % [pack_id, String(_current["sha256"]).left(12)]
	var index: Dictionary = _read_index()
	var old: Dictionary = index.get(pack_id, {}) if index.get(pack_id) is Dictionary else {}
	if DirAccess.rename_absolute(part, DIR + file) != OK:
		_fail("dosya taşınamadı")
		return
	index[pack_id] = {"sha256": _current["sha256"], "file": file, "at": int(Time.get_unix_time_from_system())}
	_write_index(index)
	var old_file: String = SaveSafe.s(old.get("file", ""))
	if not old_file.is_empty() and old_file != file and not is_mounted(pack_id):
		DirAccess.remove_absolute(DIR + old_file)   # bağlı değilse eski sürüm silinir (bağlıysa sonraki açılışta)
	_current = {}
	_mount_and_revive(pack_id, DIR + file)
	_next()


func _mount_and_revive(pack_id: String, path: String) -> void:
	if is_mounted(pack_id) or not mount(pack_id, path):
		return
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager if is_inside_tree() else null
	if decor:
		decor.revive_dormant()
	pack_ready.emit(pack_id)


func _fail(reason: String) -> void:
	push_warning("LivePacks: '%s' indirilemedi: %s" % [_current.get("id", ""), reason])
	DirAccess.remove_absolute(DIR + String(_current.get("id", "")) + ".part")
	_failed_at[String(_current.get("id", ""))] = Time.get_ticks_msec()
	_current = {}
	_next()


# --- Cihaz dizini ---------------------------------------------------------------------------

static func _read_index() -> Dictionary:
	if not FileAccess.file_exists(INDEX):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	return parsed if parsed is Dictionary else {}


static func _write_index(index: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file: FileAccess = FileAccess.open(INDEX, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(index, "\t"))
