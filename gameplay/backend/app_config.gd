class_name AppConfig
extends Node
## UZAKTAN AYAR (2026-10-21): Firestore config/app belgesi. Yönetim paneli (firebase/admin) yazar; oyun açılışta, öne
## gelince ve REFRESH_SEC'te bir OTURUMSUZ okur (Firestore REST + HTTPRequest: misafir de okur, eklenti gerekmez,
## masaüstünde de çalışır). Belgenin alanları:
##   min_code          bu sürüm kodunun ALTI oynayamaz → GÜNCELLEME GEREKLİ (kapanmaz, mağazaya gider)
##   latest_code       altındakilere YENİ SÜRÜM VAR (kapatılabilir; sürüm başına bir kez)
##   update_text       {tr, en, es, de, fr} güncelleme penceresindeki açıklama (isteğe bağlı)
##   maintenance       true → BAKIMDAYIZ (kapanmaz, TEKRAR DENE); maintenance_text {dil: metin}, maintenance_until (unix sn)
##   notice            {id, title: {dil}, text: {dil}, until (unix sn, 0 = süresiz)} DUYURU, kimlik başına bir kez
##   event             {id, title: {dil}, text: {dil}, money_mult, xp_mult, start, end (unix sn)} CANLI ETKİNLİK: etkinken
##                     tamir (iş başlarken sabitlenir: balondaki tutar doğru kalır) ve yarış ödülleri çarpılır; çarpan 1–3
## Metin alanları dil sözlüğüdür; oyuncunun dili yoksa İngilizce, o da yoksa Türkçe gösterilir (text_of).
##
## YARIŞ ÖĞRENMESİ (2026-10-22, docs/KOSU_ESLESTIRME.md Faz 2): ikinci belge config/race_learning — gece fonksiyonunun
## topladığı tablo {table: {bağlam: {kol: {s, n}}}, events, days, at} + panelin alanları {off, window, weight}. Seyrek
## değişir: LEARNING_REFRESH'te bir okunur, son hali aynı dosyada saklanır (çevrimdışı da son tablo). RaceLearning okur.
##
## Son okunan belge user://app_config.json'da durur: internet yokken de son bilinen kural geçerlidir (zorunlu güncelleme
## uçak moduyla atlatılamaz). Okuma başarısızsa (ağ yok, belge yok) eldeki kural değişmez. Geliştirme sürümü
## (AppInfo kodu 0: editör / masaüstü) güncelleme ve bakım kapısına takılmaz; duyuruyu görür.
##
## Kökte durur (sahne yenilense de yaşar, kapı oyun yeniden kurulurken de açık kalır); LoadingScreen kurar (ensure).
## Pencereleri AppGate çizer (çocuğu).

signal changed

const NODE_NAME: String = "AppConfig"
const URL: String = "https://firestore.googleapis.com/v1/projects/car-town-remake/databases/(default)/documents/config/app"
const LEARNING_URL: String = "https://firestore.googleapis.com/v1/projects/car-town-remake/databases/(default)/documents/config/race_learning"
## Öğrenme tablosu gecede bir değişir: oyun açıkken en çok bu aralıkla okunur (sn).
const LEARNING_REFRESH: float = 21600.0
const FILE: String = "user://app_config.json"
const STORE_PACKAGE: String = "com.autoyard.app"
## Oyun açıkken belge bu aralıkla yeniden okunur; öne gelince son okumadan bu kadar geçtiyse hemen (sn).
const REFRESH_SEC: float = 900.0
const RESUME_SEC: float = 120.0
const TIMEOUT_SEC: float = 10.0

const GATE_NONE: StringName = &""
const GATE_UPDATE: StringName = &"update"
const GATE_MAINTENANCE: StringName = &"maintenance"

## Boşsa ağdan okunmaz (testler apply ile belge verir).
var url: String = URL
var learning_url: String = LEARNING_URL

var _config: Dictionary = {}
var _state: Dictionary = {}       # {config, fetched_at, seen: {duyuru kimliği: true}, dismissed_latest}
var _http: HTTPRequest
var _timer: Timer
var _busy: bool = false
var _last_fetch: float = -1.0e9
var _learning_http: HTTPRequest
var _learning_busy: bool = false
var _last_learning_fetch: float = -1.0e9


## Kökte bir tane kurar (LoadingScreen açılışta çağırır).
static func ensure(tree: SceneTree) -> void:
	if tree == null or tree.root.has_node(NODE_NAME):
		return
	var config: AppConfig = AppConfig.new()
	config.name = NODE_NAME
	tree.root.add_child.call_deferred(config)


static func of(tree: SceneTree) -> AppConfig:
	return tree.root.get_node_or_null(NODE_NAME) as AppConfig if tree else null


func _init(load_cache: bool = true) -> void:
	if load_cache:
		_state = _read()
		var cached: Variant = _state.get("config")
		_config = cached if cached is Dictionary else {}


func _ready() -> void:
	add_to_group("app_config")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_learning_http = HTTPRequest.new()
	_learning_http.timeout = TIMEOUT_SEC
	_learning_http.request_completed.connect(_on_learning_completed)
	add_child(_learning_http)
	_timer = Timer.new()
	_timer.wait_time = REFRESH_SEC
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	add_child(AppGate.new(self))
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _seconds() - _last_fetch > RESUME_SEC:
			refresh()


## Belgeyi yeniden okur (BAKIMDAYIZ → TEKRAR DENE de bunu çağırır). Öğrenme tablosu vakti geldiyse o da.
func refresh() -> void:
	if url.is_empty():
		return
	_refresh_learning()
	if _busy or _http == null:
		return
	_busy = true
	_last_fetch = _seconds()
	if _http.request(url) != OK:
		_busy = false


func _refresh_learning() -> void:
	if _learning_busy or learning_url.is_empty() or _learning_http == null \
			or _seconds() - _last_learning_fetch < LEARNING_REFRESH:
		return
	_learning_busy = true
	_last_learning_fetch = _seconds()
	if _learning_http.request(learning_url) != OK:
		_learning_busy = false


func _on_learning_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_learning_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 404):
		_last_learning_fetch = -1.0e9   # sonraki yenilemede yeniden dene
		return
	var learning: Dictionary = {}
	if code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		var fields: Variant = (parsed as Dictionary).get("fields", {}) if parsed is Dictionary else {}
		learning = decode_fields(fields if fields is Dictionary else {})
	apply_learning(learning)


## Öğrenme belgesini uygular ve saklar (testler doğrudan çağırır). Belge yoksa boş: öğrenme başlangıç kuralıyla çalışır.
func apply_learning(learning: Dictionary) -> void:
	_state["learning"] = learning
	_write()


func learning() -> Dictionary:
	var raw: Variant = _state.get("learning", {})
	return raw if raw is Dictionary else {}


## config/race_learning'in son hali (AppConfig kurulmamışsa — testler, ziyaret — boş).
static func learning_of(tree: SceneTree) -> Dictionary:
	var config: AppConfig = of(tree)
	return config.learning() if config else {}


func is_busy() -> bool:
	return _busy


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	if code == 404:
		apply({})   # belge yok = kural yok (panel belgeyi sildi)
		return
	if code != 200:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		var fields: Variant = (parsed as Dictionary).get("fields", {})
		apply(decode_fields(fields if fields is Dictionary else {}))


## Yeni belgeyi uygular ve cihazda saklar (testler doğrudan çağırır).
func apply(config: Dictionary) -> void:
	_state["config"] = config
	_state["fetched_at"] = int(Time.get_unix_time_from_system())
	_write()
	if config == _config:
		return
	_config = config
	changed.emit()


func config() -> Dictionary:
	return _config


# --- Kapı / pencereler ---------------------------------------------------------------

## Oyunu kapatan durum: GATE_UPDATE, GATE_MAINTENANCE ya da GATE_NONE. Geliştirme sürümü kapıya takılmaz.
func gate() -> StringName:
	if AppInfo.is_dev_build():
		return GATE_NONE
	if SaveSafe.i(_config.get("min_code", 0)) > AppInfo.version_code():
		return GATE_UPDATE
	if _config.get("maintenance", false) == true:
		return GATE_MAINTENANCE
	return GATE_NONE


## Kapatılabilir YENİ SÜRÜM VAR penceresi gösterilsin mi (bu sürüm için daha önce kapatılmadıysa).
func soft_update() -> bool:
	if AppInfo.is_dev_build():
		return false
	var latest: int = SaveSafe.i(_config.get("latest_code", 0))
	return latest > AppInfo.version_code() and latest > SaveSafe.i(_state.get("dismissed_latest", 0))


func dismiss_soft_update() -> void:
	_state["dismissed_latest"] = SaveSafe.i(_config.get("latest_code", 0))
	_write()


## Gösterilmemiş, süresi dolmamış duyuru: {id, title, text} ya da boş.
func pending_notice() -> Dictionary:
	var notice: Variant = _config.get("notice")
	if not notice is Dictionary:
		return {}
	var id: String = SaveSafe.s((notice as Dictionary).get("id", ""))
	var text: String = text_of((notice as Dictionary).get("text"))
	if id.is_empty() or text.is_empty() or _seen().has(id):
		return {}
	var until: int = SaveSafe.i((notice as Dictionary).get("until", 0))
	if until > 0 and int(Time.get_unix_time_from_system()) > until:
		return {}
	return {"id": id, "title": text_of((notice as Dictionary).get("title")), "text": text}


func mark_notice_seen(id: String) -> void:
	var seen: Dictionary = _seen()
	seen[id] = true
	_state["seen"] = seen
	_write()


func update_text() -> String:
	return text_of(_config.get("update_text"))


func maintenance_text() -> String:
	return text_of(_config.get("maintenance_text"))


## Bakımın tahmini bitişi (unix sn) ya da 0.
func maintenance_until() -> int:
	return SaveSafe.i(_config.get("maintenance_until", 0))


# --- Canlı etkinlik ------------------------------------------------------------------

## Şu an süren etkinlik {id, title, text, money_mult, xp_mult, start, end} ya da boş. Geliştirme sürümünde de geçerli.
func active_event() -> Dictionary:
	var raw: Variant = _config.get("event")
	if not raw is Dictionary:
		return {}
	var e: Dictionary = raw
	var now: int = int(Time.get_unix_time_from_system())
	var start: int = SaveSafe.i(e.get("start", 0))
	var end: int = SaveSafe.i(e.get("end", 0))
	if SaveSafe.s(e.get("id", "")).is_empty() or end <= now or start > now:
		return {}
	var money: float = clampf(SaveSafe.f(e.get("money_mult", 1.0)), 1.0, 3.0)
	var xp: float = clampf(SaveSafe.f(e.get("xp_mult", 1.0)), 1.0, 3.0)
	if money <= 1.0 and xp <= 1.0:
		return {}
	return {"id": SaveSafe.s(e["id"]), "title": text_of(e.get("title")), "text": text_of(e.get("text")),
		"money_mult": money, "xp_mult": xp, "start": start, "end": end}


## Etkinliğin para çarpanı (etkinlik yoksa / AppConfig kurulmamışsa 1). Tamir işi başlarken ve yarış ödülünde.
static func money_multiplier(tree: SceneTree) -> float:
	var config: AppConfig = of(tree)
	return float(config.active_event().get("money_mult", 1.0)) if config else 1.0


static func xp_multiplier(tree: SceneTree) -> float:
	var config: AppConfig = of(tree)
	return float(config.active_event().get("xp_mult", 1.0)) if config else 1.0


## Mağaza sayfası: Android'de Play uygulaması, başka yerde web sayfası.
func open_store() -> void:
	if OS.get_name() == "Android":
		OS.shell_open("market://details?id=" + STORE_PACKAGE)
	else:
		OS.shell_open("https://play.google.com/store/apps/details?id=" + STORE_PACKAGE)


## Dil sözlüğünden oyuncunun dilindeki metin (yoksa en, o da yoksa tr); düz metin olduğu gibi döner.
static func text_of(value: Variant) -> String:
	if value is String:
		return value
	if not value is Dictionary:
		return ""
	var texts: Dictionary = value
	for lang: String in [Loc.current(), "en", "tr"]:
		var text: String = SaveSafe.s(texts.get(lang, "")).strip_edges()
		if not text.is_empty():
			return text
	return ""


# --- Firestore REST biçimi -----------------------------------------------------------

## REST belgesinin "fields" sözlüğü → düz sözlük ({"min_code": {"integerValue": "10"}} → {"min_code": 10}).
static func decode_fields(fields: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in fields:
		var value: Variant = fields[key]
		out[str(key)] = decode_value(value if value is Dictionary else {})
	return out


static func decode_value(value: Dictionary) -> Variant:
	if value.has("integerValue"):
		return str(value["integerValue"]).to_int()
	if value.has("doubleValue"):
		return float(str(value["doubleValue"]).to_float())
	if value.has("booleanValue"):
		return value["booleanValue"] == true
	if value.has("stringValue"):
		return str(value["stringValue"])
	if value.has("mapValue"):
		var map: Variant = (value["mapValue"] as Dictionary).get("fields", {}) if value["mapValue"] is Dictionary else {}
		return decode_fields(map if map is Dictionary else {})
	if value.has("arrayValue"):
		var items: Array = []
		var raw: Variant = (value["arrayValue"] as Dictionary).get("values", []) if value["arrayValue"] is Dictionary else []
		for item: Variant in (raw if raw is Array else []):
			items.append(decode_value(item if item is Dictionary else {}))
		return items
	return null


# --- Cihaz durumu --------------------------------------------------------------------

func _seen() -> Dictionary:
	var seen: Variant = _state.get("seen", {})
	return seen if seen is Dictionary else {}


func _seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _read() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed if parsed is Dictionary else {}


func _write() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_state, "\t"))
