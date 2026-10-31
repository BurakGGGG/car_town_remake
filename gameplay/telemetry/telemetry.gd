class_name Telemetry
extends Node
## ANALİTİK + ÇÖKME RAPORU (2026-10-22): Firebase Analytics (oyun olayları, ekranlar) ve Crashlytics (Java / motor
## çökmeleri kendiliğinden; GDScript hataları bu sınıfın Logger'ıyla "ölümcül olmayan" kayıt olarak).
##
## KULLANIM: Telemetry.event(&"crate_open", {"rarity": "rare"}) her yerden çağrılır (statik). Düğüm henüz kurulmadıysa
## (açılış, giriş kapısı) olay sıraya girer, düğüm gelince gönderilir. Oyun olaylarının çoğu yöneticilerin sinyallerinden
## burada toplanır (_connect_game): kodun her yerine çağrı serpiştirilmez.
##
## RIZA: AYARLAR → HESAP VE GİZLİLİK → KULLANIM İSTATİSTİKLERİ / HATA RAPORLARI (GameSettings, varsayılan AÇIK). Kapatılınca
## Firebase'in toplama anahtarı da kapanır (cihazda kalıcıdır: bir sonraki açılışın ilk saniyelerinde de toplamaz).
## Reklam kimliği toplanmaz, reklam onay sinyalleri reddedilmiş başlar (addons/GodotFirebaseAndroid/export_plugin.gd).
##
## Android dışında (masaüstü / testler) hiçbir şey gönderilmez: olaylar `recorded` listesine yazılır (testler bakar).
## Bağlantı Godot'un JavaClassWrapper köprüsüyle (PushService gibi): ayrı eklenti yok, kütüphaneler Gradle bağımlılığı.
## GarageSystem kurar ("telemetry" grubu); sahne yeniden kurulunca yenisi gelir, Logger ve sıra süreç boyunca tektir.

const ANALYTICS_CLASS: String = "com.google.firebase.analytics.FirebaseAnalytics"
const CRASHLYTICS_CLASS: String = "com.google.firebase.crashlytics.FirebaseCrashlytics"
## Analytics sınırları: olay / parametre adı 40 karakter (harf, rakam, _), metin değeri 100 karakter, olay başına 25 parametre.
const NAME_MAX: int = 40
const VALUE_MAX: int = 100
const PARAMS_MAX: int = 25
## Firebase'in ayırdığı adlar (bunlarla olay yazılamaz): oyunda aynı adla bir olay çıkarsa sonuna _game eklenir.
const RESERVED: PackedStringArray = ["ad_activeview", "ad_click", "ad_exposure", "ad_impression", "ad_query", "ad_reward",
	"adunit_exposure", "app_background", "app_clear_data", "app_exception", "app_remove", "app_store_refund",
	"app_update", "app_upgrade", "error", "first_open", "first_visit", "in_app_purchase", "notification_dismiss",
	"notification_foreground", "notification_open", "notification_receive", "os_update", "session_start",
	"session_start_with_rollout", "user_engagement"]
## Gönderilmeyi bekleyen en çok kayıt (ağ yok / düğüm yok iken taşmasın).
const QUEUE_MAX: int = 200
## Bir oturumda Crashlytics'e en çok bu kadar FARKLI GDScript hatası gider (aynı yerden gelen hata bir kez sayılır).
const ERRORS_PER_SESSION: int = 25
## Masaüstü / test kaydının uzunluğu.
const RECORDED_MAX: int = 200
## SHADER DÖKÜMÜ (bkz. _scan_dump_line): bayrak #define'ları kaynağın bu kadar ilk satırında aranır (motorun eklediği
## varyant / özelleştirme başlığı; şablonun içindeki #define'lar alınmaz). Kimlikte en çok bu kadar ad tutulur.
const DUMP_HEADER_LINES: int = 160
const DUMP_MAX_DEFINES: int = 30
const DUMP_MAX_IDS: int = 30
## Godot'un kendi şablonundaki tek m_ adı (canvas.glsl SHADOW_DEPTH makro parametresi): malzemeyi tanıtmaz.
const DUMP_IGNORED_IDS: PackedStringArray = ["m_uv"]

## Masaüstü / test: gönderilmiş sayılan kayıtlar {kind, name, params} (en yenisi sonda).
static var recorded: Array[Dictionary] = []
## Test: Android olmadan da "gönderildi" sayılsın mı (varsayılan: masaüstünde yalnız kaydedilir).
static var analytics_enabled: bool = true
static var crash_enabled: bool = true

static var _instance: Telemetry
static var _pending: Array[Dictionary] = []
static var _logger: _ErrorLogger
static var _error_mutex: Mutex = Mutex.new()
static var _errors: Array[Dictionary] = []      # Logger'dan (başka iş parçacığı olabilir) gelen hatalar
static var _error_keys: Dictionary = {}         # bu oturumda görülen hata yerleri
## Şu an okunan shader dökümü (_error_mutex ile korunur): son satır numarası (0: döküm yok), bayraklar, m_ adları.
static var _dump_line: int = 0
static var _dump_defines: PackedStringArray = []
static var _dump_ids: PackedStringArray = []
static var _dump_id_regex: RegEx

var _analytics: Variant = null   # JavaObject (FirebaseAnalytics)
var _crashlytics: Variant = null # JavaObject (FirebaseCrashlytics)
var _bundle_class: JavaClass
var _exception_class: JavaClass
var _settings: GameSettings
var _last_screen: StringName = &""
var _user: String = ""
var _tutorial_seen: Dictionary = {}


# --- Statik yüz ------------------------------------------------------------------------------

## Oyun olayı. name: küçük harf + rakam + _ ; params: String / int / float / bool / StringName (diğerleri metne çevrilir).
static func event(name: StringName, params: Dictionary = {}) -> void:
	_push({"kind": &"event", "name": String(name), "params": params})


## Ekran (UiRouter yeri / alt panosu). Aynı ekran üst üste yazılmaz.
static func screen(name: StringName) -> void:
	_push({"kind": &"screen", "name": String(name)})


## Oyuncu kimliği (Firebase UID; misafirde / çıkışta boş = silinir). YALNIZ hata raporuna yazılır (oyuncu destek
## isteyince çökmesi bulunsun); kullanım istatistikleri hesaba bağlanmaz.
static func set_user(uid: String) -> void:
	_push({"kind": &"user", "name": uid})


## Oyuncu özelliği (Analytics'te kitle / kırılım için; en çok 25 tane, değer 36 karakter).
static func set_property(name: StringName, value: String) -> void:
	_push({"kind": &"property", "name": String(name), "value": value.left(36)})


## Giriş yolunun analitik adı (CloudSaveManager.get_provider() → "google" / "facebook" / "email"; boş = "guest").
static func account_kind(provider: String) -> String:
	match provider:
		CloudSaveManager.PROVIDER_GOOGLE:
			return "google"
		CloudSaveManager.PROVIDER_FACEBOOK:
			return "facebook"
		CloudSaveManager.PROVIDER_EMAIL:
			return "email"
		"":
			return "guest"
	return clean_name(provider)


## Çökme raporuna iz (son 64 KB'lık günlüğe; çökme olursa raporda görünür).
static func breadcrumb(text: String) -> void:
	_push({"kind": &"log", "name": text.left(200)})


## CRASHLYTICS KURULUMU: Firebase'in Crashlytics paneli ilk raporla açılır (konsol "test çökmesi zorla" der).
## Yalnız Android hata ayıklama sürümünde (AYARLAR → DESTEK VE HAKKINDA → TEST ÇÖKMESİ).
static func test_crash_available() -> bool:
	return OS.is_debug_build() and OS.get_name() == "Android"


## Oyunu bilerek çökertir (motor çökmesi: crashlytics-ndk yakalar). Rapor oyun YENİDEN açılınca gönderilir.
static func test_crash() -> void:
	breadcrumb("test çökmesi (AYARLAR)")
	OS.crash("AUTO YARD Crashlytics test crash")


## GPU kimliği (çökme raporunun ilk izi): ad | üretici | API + sürücü sürümü | uygulanan kalite. PowerVR sürücüsü
## açılışta shader derlerken çöktüğünde (2026-10-31, 1.1.4) raporda hiçbir iz yoktu.
static func gpu_summary() -> String:
	return "%s | %s | %s | kalite %d" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version(),
		GameSettings.active_quality()]


## Logger'ı kurar (süreçte bir kez). GDScript / motor hataları Crashlytics'e ölümcül olmayan kayıt olarak gider.
static func install_logger() -> void:
	if _logger != null:
		return
	_logger = _ErrorLogger.new()
	OS.add_logger(_logger)


## SHADER DÖKÜMÜ (2026-10-31): derlenemeyen shader'da Godot kaynağı satır satır basar ("1: #version 300 es", "2: …"),
## hemen ardından "…: Fragment shader compilation failed: <sürücü günlüğü>" hatasını yazar. PowerVR'ın günlüğü yalnız
## "Compile failed." diyordu, hangi malzeme olduğu belli değildi. Logger her baskı satırını buraya verir; ardışık
## numaralı satırlardan kimlik çıkarılır: başlıktaki bayrak #define'ları (varyant: geçiş, gölge, ışık…) ve kullanıcı
## kodunun m_ adları (Godot malzeme shader'ındaki her adı m_ ile yazar → hangi .gdshader / StandardMaterial3D).
## Başka iş parçacığından çağrılabilir (Logger): _error_mutex ile.
static func _scan_dump_line(message: String) -> void:
	var colon: int = message.find(": ")
	if colon < 1 or colon > 5 or not message.left(colon).is_valid_int():
		return
	var number: int = message.left(colon).to_int()
	var text: String = message.substr(colon + 2).strip_edges()
	_error_mutex.lock()
	if number == 1:
		_dump_defines.clear()
		_dump_ids.clear()
	elif _dump_line <= 0 or number != _dump_line + 1:
		_error_mutex.unlock()
		return   # döküm değil (ya da araya başka baskı girdi)
	_dump_line = number
	if number <= DUMP_HEADER_LINES and text.begins_with("#define ") and _dump_defines.size() < DUMP_MAX_DEFINES:
		var flag: String = text.substr(8).strip_edges()
		if not flag.is_empty() and not flag.contains(" ") and not _dump_defines.has(flag):
			_dump_defines.append(flag)
	if text.contains("m_") and _dump_ids.size() < DUMP_MAX_IDS:
		if _dump_id_regex == null:
			_dump_id_regex = RegEx.create_from_string("\\bm_[A-Za-z0-9_]+")
		for found: RegExMatch in _dump_id_regex.search_all(text):
			var id: String = found.get_string()
			if not DUMP_IGNORED_IDS.has(id) and not _dump_ids.has(id) and _dump_ids.size() < DUMP_MAX_IDS:
				_dump_ids.append(id)
	_error_mutex.unlock()


## Son dökümün kimliği ("ad: m_a, m_b | bayrak: X, Y"; döküm yoksa boş) — okununca sıfırlanır (bir hataya bir döküm).
## Çağıran _error_mutex'i TUTMAZ.
static func _take_dump() -> String:
	_error_mutex.lock()
	var out: String = ""
	if _dump_line > 0:
		out = "ad: %s | bayrak: %s" % [", ".join(_dump_ids) if not _dump_ids.is_empty() else "-",
			", ".join(_dump_defines) if not _dump_defines.is_empty() else "-"]
	_dump_line = 0
	_dump_defines.clear()
	_dump_ids.clear()
	_error_mutex.unlock()
	return out


static func _push(entry: Dictionary) -> void:
	if _instance != null and is_instance_valid(_instance) and _instance.is_inside_tree():
		_instance._send(entry)
		return
	_pending.append(entry)
	if _pending.size() > QUEUE_MAX:
		_pending.pop_front()


static func _record(entry: Dictionary) -> void:
	recorded.append(entry)
	if recorded.size() > RECORDED_MAX:
		recorded.pop_front()


## Analytics olay / parametre adı: küçük harf, harf-rakam-_ dışı _, harfle başlar, en çok 40.
static func clean_name(raw: String) -> String:
	var out: String = ""
	for c: String in raw.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" else "_"
	if out.is_empty() or not (out[0] >= "a" and out[0] <= "z"):
		out = "e_" + out
	return out.left(NAME_MAX)


# --- Düğüm -------------------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("telemetry")
	install_logger()
	_instance = self
	_settings = get_tree().get_first_node_in_group("settings") as GameSettings
	if _settings:
		_settings.settings_changed.connect(_apply_consent)
	_bind_android()
	_apply_consent()
	set_property(&"lang", Loc.current())
	# GPU: çökme raporunda ilk iz + Analytics'te oyuncu özelliği (kaç oyuncu hangi GPU'da: PowerVR payı)
	_crash_log("gpu: " + gpu_summary())
	set_property(&"gpu", RenderingServer.get_video_adapter_name())
	var queued: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	for entry: Dictionary in queued:
		_send(entry)
	_connect_game.call_deferred()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(_delta: float) -> void:
	if _errors.is_empty():
		return
	_error_mutex.lock()
	var batch: Array[Dictionary] = _errors.duplicate()
	_errors.clear()
	_error_mutex.unlock()
	for error: Dictionary in batch:
		_report_error(error)


func _bind_android() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	var analytics: JavaClass = JavaClassWrapper.wrap(ANALYTICS_CLASS)
	if analytics != null and activity != null:
		_analytics = analytics.call(&"getInstance", activity)
	var crash: JavaClass = JavaClassWrapper.wrap(CRASHLYTICS_CLASS)
	if crash != null:
		_crashlytics = crash.call(&"getInstance")
	_bundle_class = JavaClassWrapper.wrap("android.os.Bundle")
	_exception_class = JavaClassWrapper.wrap("java.lang.Exception")
	if _analytics == null or _crashlytics == null:
		push_warning("Telemetry: Firebase Analytics / Crashlytics bulunamadı (Gradle bağımlılığı?)")


## AYARLAR'daki iki anahtar Firebase'in toplama anahtarlarına yazılır (Firebase cihazda saklar).
func _apply_consent() -> void:
	analytics_enabled = _settings == null or _settings.analytics_enabled
	crash_enabled = _settings == null or _settings.crash_reports_enabled
	if _analytics != null:
		_analytics.call(&"setAnalyticsCollectionEnabled", analytics_enabled)
	if _crashlytics != null:
		_set_crash_collection(crash_enabled)


## Crashlytics'in otomatik toplama anahtarı. setCrashlyticsCollectionEnabled'ın iki aşırı yüklemesi (boolean / Boolean)
## Godot'un Java köprüsünde çözülemiyor ("Nonexistent function" — telefonda görüldü 2026-10-22). Crashlytics aynı değeri
## kendi SharedPreferences'ından okur (DataCollectionArbiter, setCrashlyticsCollectionEnabled'ın da yazdığı yer): oraya
## yazılır, BİR SONRAKİ açılıştan geçerli. Bu oturumun GDScript hataları / izleri zaten crash_enabled ile kesilir.
func _set_crash_collection(on: bool) -> void:
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	if activity == null:
		return
	var prefs: Variant = activity.call(&"getSharedPreferences", "com.google.firebase.crashlytics", 0)
	if prefs == null:
		return
	var editor: Variant = prefs.call(&"edit")
	if editor != null:
		editor.call(&"putBoolean", "firebase_crashlytics_collection_enabled", on)
		editor.call(&"apply")


func _send(entry: Dictionary) -> void:
	var kind: StringName = entry.get("kind", &"")
	match kind:
		&"event":
			if analytics_enabled:
				_log_event(clean_name(String(entry["name"])), entry.get("params", {}))
		&"screen":
			var screen_name: StringName = StringName(String(entry["name"]))
			if screen_name == _last_screen:
				return
			_last_screen = screen_name
			if analytics_enabled:
				_log_event("screen_view", {"screen_name": String(screen_name), "screen_class": "Godot"})
			_crash_log("ekran: %s" % screen_name)
		&"user":
			var uid: String = String(entry["name"])
			if uid == _user:
				return
			_user = uid
			_record({"kind": &"user", "name": uid})
			if _crashlytics != null:
				_crashlytics.call(&"setUserId", uid)
		&"property":
			_record(entry)
			if _analytics != null and analytics_enabled:
				_analytics.call(&"setUserProperty", clean_name(String(entry["name"])).left(24), String(entry["value"]))
		&"log":
			_crash_log(String(entry["name"]))


func _log_event(name: String, params: Dictionary) -> void:
	if RESERVED.has(name) or name.begins_with("firebase_") or name.begins_with("google_") or name.begins_with("ga_"):
		name = (name + "_game").left(NAME_MAX)
	var clean: Dictionary = {}
	for key: Variant in params:
		if clean.size() >= PARAMS_MAX:
			break
		var value: Variant = params[key]
		if value is bool:
			value = 1 if value else 0
		elif value is StringName or not (value is int or value is float or value is String):
			value = str(value)
		if value is String:
			value = (value as String).left(VALUE_MAX)
		clean[clean_name(str(key))] = value
	_record({"kind": &"event", "name": name, "params": clean})
	if _analytics == null:
		return
	var bundle: Variant = _bundle_class.call(&"Bundle") if _bundle_class else null
	if bundle == null:
		return
	for key: String in clean:
		var value: Variant = clean[key]
		if value is int:
			bundle.call(&"putLong", key, value)
		elif value is float:
			bundle.call(&"putDouble", key, value)
		else:
			bundle.call(&"putString", key, value)
	_analytics.call(&"logEvent", name, bundle)


func _crash_log(text: String) -> void:
	_record({"kind": &"log", "name": text})
	if _crashlytics != null and crash_enabled:
		_crashlytics.call(&"log", text)


## Logger'dan gelen hata: Crashlytics'e ölümcül olmayan istisna (ileti = yer + neden) + Analytics'e sayaç olayı.
func _report_error(error: Dictionary) -> void:
	var where: String = String(error["where"])
	var text: String = "GDScript: %s @ %s" % [String(error["message"]), where]
	_record({"kind": &"error", "name": text})
	if analytics_enabled:
		_log_event("script_error", {"where": where.right(VALUE_MAX)})
	if _crashlytics == null or not crash_enabled:
		return
	if not String(error.get("trace", "")).is_empty():
		_crashlytics.call(&"log", String(error["trace"]).left(1000))
	var exception: Variant = _exception_class.call(&"Exception", text.left(500)) if _exception_class else null
	if exception != null:
		_crashlytics.call(&"recordException", exception)


# --- Oyun olayları -------------------------------------------------------------------------------

## Yöneticilerin sinyalleri olaylara bağlanır (sahne kurulduktan sonra: hepsi gruplarıyla bulunur).
func _connect_game() -> void:
	var tree: SceneTree = get_tree()
	var router: UiRouter = tree.get_first_node_in_group("ui_router") as UiRouter
	if router:
		router.stack_changed.connect(func(top: StringName, _place_open: bool) -> void:
			screen(top if top != &"" else &"world"))
	var repair: RepairManager = tree.get_first_node_in_group("repair_manager") as RepairManager
	if repair:
		repair.job_collected.connect(func(job_id: StringName, reward: int) -> void:
			event(&"repair_collect", {"job": job_id, "reward": reward}))
		repair.gem_finished.connect(func(_car: Node3D) -> void: event(&"repair_gem_finish"))
		repair.customer_left.connect(func(_car: Node3D) -> void: event(&"customer_left"))
	var crates: CrateManager = tree.get_first_node_in_group("crates") as CrateManager
	if crates:
		crates.crate_opened.connect(func(_uid: int, result: Dictionary) -> void:
			event(&"crate_open", {"crate": result.get("crate", ""), "rarity": result.get("rarity", ""),
				"vehicle": result.get("vehicle", ""), "duplicate": bool(result.get("duplicate", false))}))
	var race: RaceManager = tree.get_first_node_in_group("race") as RaceManager
	if race:
		race.race_finished.connect(func(won: bool, money: int, _xp: int) -> void:
			event(&"race_finish", {"won": won, "money": money}))
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		progress.level_up.connect(func(level: int) -> void:
			event(&"level_up", {"level": level})
			set_property(&"level", str(level)))
		set_property(&"level", str(progress.level))
	var mods: PerformanceModManager = tree.get_first_node_in_group("performance_mods") as PerformanceModManager
	if mods:
		mods.install_completed.connect(_on_mod_installed)
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership:
		ownership.vehicle_purchased.connect(func(id: StringName) -> void: event(&"vehicle_buy", {"vehicle": id}))
	var decor: DecorManager = tree.get_first_node_in_group("decor") as DecorManager
	if decor:
		decor.purchased.connect(func(id: StringName) -> void: event(&"decor_buy", {"item": id}))
	var mastery: JobMastery = tree.get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(func(job_id: StringName, stars: int) -> void:
			event(&"mastery_up", {"job": job_id, "stars": stars}))
	var junkyard: JunkyardManager = tree.get_first_node_in_group("junkyard") as JunkyardManager
	if junkyard:
		junkyard.project_completed.connect(func(id: StringName) -> void: event(&"restoration_complete", {"vehicle": id}))
	var purchases: PurchaseManager = tree.get_first_node_in_group("purchases") as PurchaseManager
	if purchases:
		purchases.purchase_finished.connect(func(id: StringName, status: StringName) -> void:
			event(&"iap_result", {"product": id, "status": status}))
		purchases.refund_applied.connect(func(id: StringName, taken: int, missing: int) -> void:
			event(&"iap_refund", {"product": id, "taken": taken, "missing": missing}))
	var ads: AdService = tree.get_first_node_in_group("ads") as AdService
	if ads:
		ads.ad_finished.connect(func(kind: StringName, rewarded: bool) -> void:
			event(&"ad_finished", {"kind": kind, "rewarded": rewarded}))
	var tutorial: TutorialManager = tree.get_first_node_in_group("tutorial") as TutorialManager
	if tutorial:
		for id: StringName in TutorialManager.ALL:
			_tutorial_seen[id] = tutorial.is_done(id)
		tutorial.changed.connect(_on_tutorial_changed.bind(tutorial))
	var cloud: CloudSaveManager = tree.get_first_node_in_group("cloud_save") as CloudSaveManager
	if cloud:
		cloud.user_changed.connect(func(_profile: Variant) -> void: _sync_user(cloud))
		_sync_user(cloud)


func _on_mod_installed(vehicle_id: StringName, category: StringName, stage: int, _old_class: String,
		_new_class: String) -> void:
	event(&"mod_install", {"vehicle": vehicle_id, "category": category, "stage": stage})


func _on_tutorial_changed(tutorial: TutorialManager) -> void:
	for id: StringName in TutorialManager.ALL:
		var done: bool = tutorial.is_done(id)
		if done and not bool(_tutorial_seen.get(id, false)):
			event(&"tutorial_complete", {"lesson": id})
		_tutorial_seen[id] = done


## UID yalnız Crashlytics'e; Analytics'e yalnız hesap TÜRÜ (`account`: guest / google / email / facebook) gider →
## tutma ve gelir misafir / hesaplı oyuncuya göre kırılabilir (2026-10-28).
func _sync_user(cloud: CloudSaveManager) -> void:
	set_user(cloud.get_uid())
	set_property(&"account", account_kind(cloud.get_provider() if cloud.is_authenticated() else ""))


## GDScript / motor hatalarını yakalar. Başka iş parçacığından da çağrılır: yalnız kilitli listeye yazar
## (Java çağrısı ana iş parçacığında, _process'te). Uyarılar alınmaz (oyun bilerek push_warning kullanıyor).
class _ErrorLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var where: String = "%s:%d %s" % [file.get_file(), line, function]
		var message: String = rationale if not rationale.is_empty() else code
		var trace: String = ""
		if not script_backtraces.is_empty() and script_backtraces[0] != null and not script_backtraces[0].is_empty():
			var top: ScriptBacktrace = script_backtraces[0]
			trace = top.format()
			# push_error motorun tek satırından gelir (variant_utility.cpp): asıl yer betik yığınının tepesi
			where = "%s:%d %s" % [top.get_frame_file(0).get_file(), top.get_frame_line(0), top.get_frame_function(0)]
		# Yığın yoksa (sürüm derlemesi) push_error'ların yeri aynıdır: ileti de anahtara girer
		var key: String = where + "|" + message.left(80)
		# Derlenemeyen shader: hemen önce basılan kaynağın kimliği iletiye (Crashlytics başlığında görünsün) ve anahtara
		# (farklı malzemelerin aynı "Compile failed." hatası ayrı raporlansın) girer. Bkz. Telemetry._scan_dump_line.
		if message.contains("shader compilation failed"):
			var shader_id: String = Telemetry._take_dump()
			if not shader_id.is_empty():
				message = "%s [%s]" % [message.replace("\n", " ").strip_edges(), shader_id]
				key += "|" + shader_id
				trace = ("shader " + shader_id + "\n" + trace).strip_edges()
		Telemetry._error_mutex.lock()
		if not Telemetry._error_keys.has(key) and Telemetry._error_keys.size() < Telemetry.ERRORS_PER_SESSION:
			Telemetry._error_keys[key] = true
			Telemetry._errors.append({"where": where, "message": message.left(300), "trace": trace})
		Telemetry._error_mutex.unlock()

	## Her baskı satırı: yalnız shader dökümü aranır (bkz. Telemetry._scan_dump_line; numarasız satır hemen döner).
	func _log_message(message: String, _error: bool) -> void:
		Telemetry._scan_dump_line(message)
