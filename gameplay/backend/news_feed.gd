class_name NewsFeed
extends Node
## HABERLER KUTUSU'nun yayın akışı (2026-10-25, docs/HABERLER.md). Yönetim paneli haberleri news/{id}'ye yazar (Haberler
## sekmesi; koleksiyon yalnız sunucunun) ve her kayıtta yayındaki haberleri TEK belgeye toplar: config/news = {items, at}.
## Oyun yalnız o belgeyi okur (1 okuma; koleksiyonu listelemek oyuncu başına onlarca okuma olurdu). AppConfig'in çocuğu:
## kökte yaşar, onunla aynı yolla OTURUMSUZ REST okur (misafir de) — açılışta, öne gelince, REFRESH_SEC'te bir ve kutu
## açılınca (FRESH_SEC'ten eskiyse). Son liste user://news_feed.json'da durur (internetsiz de son haberler). Haber:
##   kind     update (GÜNCELLEME) | event (ETKİNLİK) | notice (DUYURU)
##   title / text  dil sözlüğü (oyuncunun dili yoksa en, o da yoksa tr — AppConfig.text_of; dil gösterirken çözülür)
##   image    izinli https adresi (Firebase Storage / autoyard.online) ya da boş (türün hazır kapağı)
##   action   {kind, url}: market | event | quests | showroom | friends | invite | store | url (yalnız https)
##   start / end   unix sn; 0 = hemen / süresiz (ileri tarihli yayın, bitince kutudan kalkar)
##   pinned   listenin üstünde durur
##   code     güncelleme notu: bu sürüm kodu ve üstünü yükleyen görür
##   target   {langs, min_level, max_level, min_code, max_code} (0 / boş = sınırsız)
##   at       oyunda gösterilen zaman ("2 SA ÖNCE")
## Süzme oyunda yapılır (visible): yayın zamanı, dil, seviye, sürüm. Telefon bildirimi sunucudan (functions newsPush).

signal changed

const NODE_NAME: String = "NewsFeed"
const URL: String = "https://firestore.googleapis.com/v1/projects/car-town-remake/databases/(default)/documents/config/news"
const FILE: String = "user://news_feed.json"
const REFRESH_SEC: float = 900.0
const RESUME_SEC: float = 120.0
## Kutu açılınca son okumadan bu kadar geçtiyse yeniden okunur.
const FRESH_SEC: float = 60.0
const TIMEOUT_SEC: float = 10.0
const MAX_TEXT: int = 600
const KINDS: Array[String] = ["update", "event", "notice"]
const ACTIONS: Array[String] = ["market", "event", "quests", "showroom", "friends", "invite", "store", "url"]
## Kapak resmi yalnız bu adreslerden indirilir (panel Storage'a yükler; site de olabilir).
const IMAGE_HOSTS: Array[String] = ["firebasestorage.googleapis.com", "storage.googleapis.com", "autoyard.online"]

var url: String = URL
var _items: Array[Dictionary] = []   # normalize edilmiş, en yeni önde
var _http: HTTPRequest
var _timer: Timer
var _busy: bool = false
var _last_fetch: float = -1.0e9


static func of(tree: SceneTree) -> NewsFeed:
	var config: AppConfig = AppConfig.of(tree)
	return config.get_node_or_null(NODE_NAME) as NewsFeed if config else null


func _init(load_cache: bool = true) -> void:
	name = NODE_NAME
	if load_cache:
		_items = _parse_list(_read())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_timer = Timer.new()
	_timer.wait_time = REFRESH_SEC
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _seconds() - _last_fetch > RESUME_SEC:
			refresh()


func refresh() -> void:
	if _busy or _http == null or url.is_empty():
		return
	_busy = true
	_last_fetch = _seconds()
	if _http.request(url) != OK:
		_busy = false


## Kutu açıldı: liste FRESH_SEC'ten eskiyse yeniden okunur.
func refresh_if_stale() -> void:
	if _seconds() - _last_fetch > FRESH_SEC:
		refresh()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		return   # ağ yok: eldeki liste kalır
	if code == 404:
		apply([])   # belge yok = yayında haber yok
		return
	if code != 200:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var fields: Variant = (parsed as Dictionary).get("fields", {})
	var doc: Dictionary = AppConfig.decode_fields(fields if fields is Dictionary else {})
	apply(doc.get("items", []) if doc.get("items") is Array else [])


## Yeni listeyi uygular ve cihazda saklar (testler doğrudan çağırır). docs: config/news.items = [{id, …haber alanları}].
func apply(docs: Array) -> void:
	var items: Array[Dictionary] = _parse_list(docs)
	_write(docs)
	if items == _items:
		return
	_items = items
	changed.emit()


## Bütün (süzülmemiş) haberler, en yeni önde.
func items() -> Array[Dictionary]:
	return _items


## Bu oyuncunun şu an görmesi gereken haberler (zaman, dil, seviye, sürüm süzgeci).
func visible_items(now: int, lang: String, level: int, version: int, dev: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in _items:
		if visible(item, now, lang, level, version, dev):
			out.append(item)
	return out


static func visible(item: Dictionary, now: int, lang: String, level: int, version: int, dev: bool) -> bool:
	var start: int = int(item["start"])
	var end: int = int(item["end"])
	if (start > 0 and now < start) or (end > 0 and now >= end):
		return false
	var target: Dictionary = item["target"]
	var langs: Array = target["langs"]
	if not langs.is_empty() and not langs.has(lang):
		return false
	if (int(target["min_level"]) > 0 and level < int(target["min_level"])) \
			or (int(target["max_level"]) > 0 and level > int(target["max_level"])):
		return false
	if dev:
		return true   # geliştirme sürümü (kod 0) sürüm süzgecine takılmaz: panelden her haber denenebilsin
	if (int(target["min_code"]) > 0 and version < int(target["min_code"])) \
			or (int(target["max_code"]) > 0 and version > int(target["max_code"])):
		return false
	return not (item["kind"] == "update" and int(item["code"]) > version)


## Belgeden güvenli haber; kimliksiz ya da metinsiz belge boş döner. Metinler DİL SÖZLÜĞÜ olarak kalır.
static func normalize(doc: Dictionary) -> Dictionary:
	var id: String = SaveSafe.s(doc.get("id", "")).strip_edges()
	var title: Dictionary = _texts(doc.get("title"), 60)
	var text: Dictionary = _texts(doc.get("text"), MAX_TEXT)
	if id.is_empty() or (title.is_empty() and text.is_empty()):
		return {}
	var kind: String = SaveSafe.s(doc.get("kind", ""))
	var raw_target: Dictionary = doc.get("target", {}) if doc.get("target") is Dictionary else {}
	var langs: Array = []
	for lang: Variant in (raw_target.get("langs", []) if raw_target.get("langs") is Array else []):
		if lang is String and Loc.LANGUAGES.has(lang):
			langs.append(lang)
	return {
		"id": id,
		"kind": kind if KINDS.has(kind) else "notice",
		"title": title,
		"text": text,
		"image": clean_image(doc.get("image", "")),
		"action": clean_action(doc.get("action", {})),
		"start": maxi(SaveSafe.i(doc.get("start", 0)), 0),
		"end": maxi(SaveSafe.i(doc.get("end", 0)), 0),
		"pinned": doc.get("pinned", false) == true,
		"code": maxi(SaveSafe.i(doc.get("code", 0)), 0),
		"target": {
			"langs": langs,
			"min_level": maxi(SaveSafe.i(raw_target.get("min_level", 0)), 0),
			"max_level": maxi(SaveSafe.i(raw_target.get("max_level", 0)), 0),
			"min_code": maxi(SaveSafe.i(raw_target.get("min_code", 0)), 0),
			"max_code": maxi(SaveSafe.i(raw_target.get("max_code", 0)), 0),
		},
		"at": maxi(SaveSafe.i(doc.get("at", 0)), 0),
	}


## Kapak resmi adresi: yalnız https + izinli sunucu; değilse boş (oyun türün hazır kapağını çizer).
static func clean_image(value: Variant) -> String:
	var text: String = SaveSafe.s(value).strip_edges()
	if text.length() > 1000 or not text.begins_with("https://"):
		return ""
	var host: String = text.trim_prefix("https://").get_slice("/", 0).get_slice("?", 0).to_lower()
	return text if IMAGE_HOSTS.has(host) else ""


## Eylem düğmesi: {kind, url}; tanınmayan tür ya da https olmayan bağlantı → {kind: "", url: ""} (düğme yok).
static func clean_action(value: Variant) -> Dictionary:
	var none: Dictionary = {"kind": "", "url": ""}
	if not value is Dictionary:
		return none
	var kind: String = SaveSafe.s((value as Dictionary).get("kind", ""))
	if not ACTIONS.has(kind):
		return none
	var link: String = SaveSafe.s((value as Dictionary).get("url", "")).strip_edges()
	if kind == "url":
		if not link.begins_with("https://") or link.length() > 300 or link.contains(" "):
			return none
		return {"kind": kind, "url": link}
	return {"kind": kind, "url": ""}


## Dil sözlüğü (ya da düz metin → tr) → yalnız bilinen diller, kırpılmış; boş metinler atılır.
static func _texts(value: Variant, limit: int) -> Dictionary:
	var out: Dictionary = {}
	if value is String:
		value = {"tr": value}
	if not value is Dictionary:
		return out
	for lang: String in Loc.LANGUAGES:
		var text: String = SaveSafe.s((value as Dictionary).get(lang, "")).strip_edges()
		if not text.is_empty():
			out[lang] = text.left(limit)
	return out


static func _parse_list(docs: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in (docs if docs is Array else []):
		if raw is Dictionary:
			var item: Dictionary = normalize(raw)
			if not item.is_empty():
				out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	return out


func _seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _read() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed if parsed is Array else []


func _write(docs: Array) -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(docs))
