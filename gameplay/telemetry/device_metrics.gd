class_name DeviceMetrics
extends Node
## CİHAZ METRİKLERİ (2026-11-03): misafir dahil HER cihazın özet sayıları sunucuda devices/d_{özet} belgesinde
## (firebase/functions/devices.js, callable `deviceMetrics`). Misafirin Firebase kaydı olmadığı için oyuncuların çoğu
## (~%62) hiçbir sayıma girmiyordu: "bildirimi kapalı oyuncu yüzdesi" gibi sorular yalnız hesaplılar için
## cevaplanabiliyordu. İLERLEME TUTULMAZ: yalnız özet sayılar (seviye, para, araç sayısı…), hesap türü, bildirim durumu,
## oyun süresi, açılış, izlenen ödüllü reklam, satın alma sayısı. UID YAZILMAZ (kullanım istatistiği hesaba bağlanmaz).
##
## KİMLİK: device_id() = ANDROID_ID'nin tuzlu SHA-256 özeti (davet sisteminin özetinden ayrı tuz). Yeniden kurulumda
## değişmez → bir telefon bir kez sayılır.
## RIZA: AYARLAR → KULLANIM İSTATİSTİKLERİ (GameSettings.analytics_enabled, Telemetry ile aynı anahtar). Kapalıyken
## hiçbir şey birikmez / gönderilmez; daha önce gönderildiyse sunucuya {forget} gider ve belge silinir.
##
## GÖNDERİM: açılıştan FIRST_DELAY sn sonra, oynarken HEARTBEAT'te bir, değişiklikte (bildirim, hesap, seviye, reklam,
## satın alma, ders) DIRTY_DELAY sonra (en sık MIN_GAP'te bir), uygulama arka plana geçince birikmiş süre varsa. Ağ yoksa
## RETRY_SEC beklemeleriyle yeniden. Android dışında (masaüstü, testler) gönderilmez — testler force_enabled + transport.
##
## SAYAÇ SÖZLEŞMESİ (sunucuyla): sayaçlar FARK olarak gider. Her yeni gönderim (inst, seq+1) ile "uçuşa" alınır ve
## sunucu onaylayana kadar AYNI seq ve AYNI farklarla yeniden yollanır (yanıtı kaybolan istek iki kez sayılmaz); bu arada
## biriken yeni farklar bir sonraki gönderimi bekler. inst kurulum verisine özel: veriler silinirse yenisi üretilir.
## Durum user://device_metrics.json'da (oyun kaydında DEĞİL: kayıt hesaba / başka telefona taşınır, metrik cihaza aittir).
## GarageSystem kurar ("device_metrics" grubu); sahne yeniden kurulunca yenisi gelir — oturum sayımı süreçte bir kez.

const FILE: String = "user://device_metrics.json"
const URL: String = CloudSaveManager.EMAIL_FUNCTIONS_URL + "deviceMetrics"
const SALT: String = "autoyard-metrics|"
const FIRST_DELAY: float = 8.0
const HEARTBEAT: float = 300.0
const DIRTY_DELAY: float = 10.0
const MIN_GAP: float = 30.0
const RETRY_SEC: Array[float] = [30.0, 120.0, 600.0]
const TIMEOUT: float = 20.0
## Arka plana geçerken en az bu kadar gönderilmemiş oyun süresi varsa hemen gönderilir.
const PAUSE_FLUSH_PLAY: float = 20.0
## Arka planda bu kadar kalınca dönüş yeni oturum sayılır (Analytics'in oturum tanımı).
const SESSION_GAP_MS: int = 30 * 60 * 1000
## Sunucunun kabul ettiği diller ve hesap türleri (devices.js LANGS / ACCOUNTS).
const LANGS: PackedStringArray = ["tr", "en", "es", "de", "fr"]
const ACCOUNTS: PackedStringArray = ["guest", "google", "email", "facebook"]
## Sayaçlar ve tek gönderimde en çok (devices.js DELTAS; fazlası bir sonraki gönderime kalır).
const COUNTERS: Dictionary[String, int] = {"play_s": 86_400, "sess": 50, "ads": 500, "iap": 50, "iap_usd_c": 500_000}

## Test / QA: Android olmadan da gönder (transport ile).
static var force_enabled: bool = false
## Bu süreçte açılış sayıldı mı (sahne yeniden kurulunca ikinci kez sayılmaz).
static var _session_counted: bool = false
static var _cached_id: String = ""

## Gönderici: func(data: Dictionary) -> Dictionary ({ok: true, …} ya da {error: neden}). Boşsa düz HTTP.
var transport: Callable = Callable()
## Test: cihaz kimliği yerine (ham kimlik; tuzlanıp özetlenir).
var device_override: String = ""
## Test: son gönderilen gövde ve gönderim sayısı.
var last_request: Dictionary = {}
var sent_count: int = 0

var _state: Dictionary = {}
var _timer: Timer
var _http: HTTPRequest
var _busy: bool = false
var _retry: int = 0
var _last_send_ms: int = -1_000_000
var _play_acc: float = 0.0            # bu oturumda henüz pend'e katılmamış oyun süresi (sn)
var _paused_at_ms: int = -1
var _settings: GameSettings
var _push: PushService
var _cloud: CloudSaveManager
var _save: SaveManager
var _garages: CarGarageManager
var _tutorial: TutorialManager


func _ready() -> void:
	add_to_group("device_metrics")
	_state = _read()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_send)
	add_child(_timer)
	_connect.call_deferred()


func _exit_tree() -> void:
	_fold_play()
	_write()


func _connect() -> void:
	var tree: SceneTree = get_tree()
	_settings = tree.get_first_node_in_group("settings") as GameSettings
	_push = tree.get_first_node_in_group("push") as PushService
	_cloud = tree.get_first_node_in_group("cloud_save") as CloudSaveManager
	_save = tree.get_first_node_in_group("save_manager") as SaveManager
	_garages = tree.get_first_node_in_group("car_garages") as CarGarageManager
	_tutorial = tree.get_first_node_in_group("tutorial") as TutorialManager
	if _settings:
		_settings.settings_changed.connect(_on_settings_changed)
	if _push:
		_push.changed.connect(mark_dirty)
	if _cloud:
		_cloud.user_changed.connect(func(_profile: Variant) -> void: mark_dirty())
	if _tutorial:
		_tutorial.changed.connect(mark_dirty)
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		progress.level_up.connect(func(_level: int) -> void: mark_dirty())
	var ads: AdService = tree.get_first_node_in_group("ads") as AdService
	if ads:
		ads.ad_finished.connect(_on_ad_finished)
	var purchases: PurchaseManager = tree.get_first_node_in_group("purchases") as PurchaseManager
	if purchases:
		purchases.gems_purchased.connect(_on_gems_purchased)
	if not _session_counted and is_active() and has_consent():
		_session_counted = true
		_add(&"sess", 1)
	_schedule(FIRST_DELAY)


func _process(delta: float) -> void:
	if is_active() and has_consent():
		_play_acc += minf(delta, 1.0)   # takılma / uyku sonrası tek dev kare sayılmaz


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _paused_at_ms < 0:
				_paused_at_ms = Time.get_ticks_msec()
			var unsent: float = _play_acc
			_fold_play()
			_write()
			if unsent >= PAUSE_FLUSH_PLAY and is_inside_tree():
				_send()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _paused_at_ms >= 0 and Time.get_ticks_msec() - _paused_at_ms >= SESSION_GAP_MS \
					and is_active() and has_consent():
				_add(&"sess", 1)
				mark_dirty()
			_paused_at_ms = -1


# --- Durum ----------------------------------------------------------------------------

## Gönderim açık mı: Android (ya da test). Rızadan bağımsız (rıza kapalıyken de silme isteği gitmeli).
func is_active() -> bool:
	return force_enabled or OS.get_name() == "Android"


## AYARLAR → KULLANIM İSTATİSTİKLERİ açık mı.
func has_consent() -> bool:
	return _settings == null or _settings.analytics_enabled


## Bu cihazın sunucudaki kimliği (64 onaltılık).
func device_id() -> String:
	if not device_override.is_empty():
		return (SALT + device_override).sha256_text()
	if _cached_id.is_empty():
		_cached_id = (SALT + ReferralManager.stable_device_id()).sha256_text()
	return _cached_id


## Henüz gönderilmemiş sayaç farkları (uçuştaki dahil değil).
func pending() -> Dictionary:
	return (_state.get("pend", {}) as Dictionary).duplicate() if _state.get("pend") is Dictionary else {}


## Bir değişiklik oldu: kısa bir beklemeden sonra gönderilir (daha yakın bir gönderim zaten kuruluysa o kalır).
func mark_dirty() -> void:
	_schedule(DIRTY_DELAY)


## Anlık alanlar (sunucuda son değer yazılır). Testler de okur.
func snapshot() -> Dictionary:
	var stats: Dictionary = CloudSaveManager.stats_of(_save.snapshot()) if _save else {}
	var tut: int = 0
	if _tutorial:
		for id: StringName in TutorialManager.ALL:
			if _tutorial.is_done(id):
				tut += 1
	var acct: String = Telemetry.account_kind(_cloud.get_provider() if _cloud and _cloud.is_authenticated() else "")
	var lang: String = Loc.current()
	return {
		"acct": acct if ACCOUNTS.has(acct) else "other",
		"lang": lang if LANGS.has(lang) else "en",
		"model": _ascii(OS.get_model_name()).left(60),
		"build": clampi(AppInfo.version_code(), 0, 1_000_000),
		"sdk": clampi(GallerySaver.android_sdk(), 0, 100),
		"level": clampi(SaveSafe.i(stats.get("level", 1)), 0, 10_000),
		"money": clampi(SaveSafe.i(stats.get("money", 0)), 0, 1_000_000_000_000),
		"gems": clampi(SaveSafe.i(stats.get("gems", 0)), 0, 1_000_000_000),
		"cars": clampi(SaveSafe.i(stats.get("cars", 0)), 0, 10_000),
		"garages": clampi(_garages.owned_garages().size(), 0, 100) if _garages else 0,
		"tut": tut,
		"push": _push != null and _push.is_enabled(),
		"push_os": PushService.os_allows(),
		"push_asked": _push != null and _push.was_asked(),
		"push_race": _push == null or _push.pref(PushService.RACE),
		"push_gift": _push == null or _push.pref(PushService.GIFT),
		"push_news": _push == null or _push.pref(PushService.NEWS),
	}


# --- Gönderim -------------------------------------------------------------------------

func _schedule(seconds: float) -> void:
	if _timer == null or not is_inside_tree():
		return
	var wait: float = maxf(seconds, MIN_GAP - float(Time.get_ticks_msec() - _last_send_ms) / 1000.0)
	if _timer.is_stopped() or _timer.time_left > wait:
		_timer.start(maxf(wait, 0.05))


func _send() -> void:
	if _busy or not is_active():
		return
	if not has_consent():
		if bool(_state.get("known", false)):
			await _forget()
		return
	_fold_play()
	var inst: String = _inst()   # önce: yeni inst seq'i sıfırlar, uçuşa alınan seq'in üstüne yazmasın
	var fly: Dictionary = _state.get("fly", {}) if _state.get("fly") is Dictionary else {}
	if fly.is_empty():
		var seq: int = SaveSafe.i(_state.get("seq", 0)) + 1
		var deltas: Dictionary = {}
		var pend: Dictionary = pending()
		for key: String in COUNTERS:
			var whole: int = mini(floori(float(pend.get(key, 0))), COUNTERS[key])
			if whole > 0:
				deltas[key] = whole
				pend[key] = float(pend.get(key, 0)) - whole   # oyun süresinin küsuratı bir sonrakine kalır
		fly = {"seq": seq, "d": deltas}
		_state["seq"] = seq
		_state["fly"] = fly
		_state["pend"] = pend
		_write()
	var data: Dictionary = snapshot()
	data["dev"] = device_id()
	data["inst"] = inst
	data["seq"] = SaveSafe.i(fly.get("seq", 1))
	data["d"] = fly.get("d", {})
	var result: Dictionary = await _call(data)
	if result.get("ok", false) == true:
		_state["fly"] = {}
		_state["known"] = true
		_write()
		_retry = 0
		_schedule(HEARTBEAT)
		return
	var reason: String = SaveSafe.s(result.get("error", ""))
	if reason.begins_with("bad_"):
		# Sunucu bu gövdeyi hiç kabul etmeyecek (sürüm uyumsuzluğu): sonsuz döngüye girmesin, uçuştaki fark atılır
		push_warning("DeviceMetrics: sunucu reddetti (%s)" % reason)
		_state["fly"] = {}
		_write()
		_schedule(HEARTBEAT)
		return
	_schedule(RETRY_SEC[mini(_retry, RETRY_SEC.size() - 1)])
	_retry += 1


## Rıza geri alındı: sunucudaki belge silinir; başarılıysa cihazdaki durum sıfırlanır (yeni inst).
func _forget() -> void:
	var result: Dictionary = await _call({"dev": device_id(), "forget": true})
	if result.get("ok", false) == true:
		_state = {"inst": _new_inst()}
		_write()
		_retry = 0
	else:
		_schedule(RETRY_SEC[mini(_retry, RETRY_SEC.size() - 1)])
		_retry += 1


func _call(data: Dictionary) -> Dictionary:
	_busy = true
	_last_send_ms = Time.get_ticks_msec()
	last_request = data.duplicate(true)
	sent_count += 1
	var result: Variant
	if transport.is_valid():
		result = await transport.call(data)
	else:
		result = await _http_call(data)
	_busy = false
	return result if result is Dictionary else {"error": "internal"}


## Callable Cloud Function'ı düz HTTP ile çağırır (CloudSaveManager._http_call_function ile aynı biçim).
func _http_call(data: Dictionary) -> Dictionary:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT
		add_child(_http)
	var err: Error = _http.request(URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"data": data}))
	if err != OK:
		return {"error": "network"}
	var response: Array = await _http.request_completed
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "network"}
	var body: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not body is Dictionary:
		return {"error": "internal"}
	if int(response[1]) == 200 and body.get("result") is Dictionary:
		return body["result"]
	var error: Variant = body.get("error")
	var details: Variant = error.get("details") if error is Dictionary else null
	return {"error": SaveSafe.s((details as Dictionary).get("reason", "internal")) if details is Dictionary else "internal"}


# --- Sayaçlar -------------------------------------------------------------------------

func _add(key: StringName, amount: float) -> void:
	var pend: Dictionary = pending()
	pend[String(key)] = float(pend.get(String(key), 0)) + amount
	_state["pend"] = pend
	_write()


func _fold_play() -> void:
	if _play_acc <= 0.0:
		return
	var pend: Dictionary = pending()
	pend["play_s"] = float(pend.get("play_s", 0)) + _play_acc
	_state["pend"] = pend
	_play_acc = 0.0


func _on_ad_finished(_kind: StringName, rewarded: bool) -> void:
	if rewarded and is_active() and has_consent():
		_add(&"ads", 1)
		mark_dirty()


func _on_gems_purchased(product_id: StringName, _gems: int) -> void:
	if not is_active() or not has_consent():
		return
	_add(&"iap", 1)
	_add(&"iap_usd_c", roundi(float(GemProducts.get_entry(product_id).get("usd", 0.0)) * 100.0))
	mark_dirty()


func _on_settings_changed() -> void:
	if has_consent():
		mark_dirty()
		return
	# Rıza kapandı: birikmiş sayaçlar ve uçuştaki gönderim atılır, sunucudaki belge silinir
	_play_acc = 0.0
	_state.erase("pend")
	_state.erase("fly")
	_write()
	if bool(_state.get("known", false)):
		_schedule(0.0)


# --- Dosya ----------------------------------------------------------------------------

func _inst() -> String:
	var inst: String = SaveSafe.s(_state.get("inst", ""))
	if inst.length() != 32:
		inst = _new_inst()
		_state["inst"] = inst
		_state["seq"] = 0
		_write()
	return inst


static func _new_inst() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func _ascii(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		out += char(c) if c >= 0x20 and c <= 0x7e else "?"
	return out


func _read() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(FILE)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return data if data is Dictionary else {}


func _write() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_state))
