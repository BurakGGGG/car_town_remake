class_name PushService
extends Node
## TELEFON BİLDİRİMİ (FCM). Üç tür (2026-10-21, kullanıcı kararı "genel bildirim izni"):
##   YARIŞ    arkadaşın senin aracını yenince ("Bob Usta yarışta aracını yendi!") — firebase/functions news.js
##   HEDİYE   yönetim paneli postana hediye bırakınca — functions mail.js
##   DUYURU   yönetim panelinin herkese duyurusu (etkinlik, yeni sürüm) — FCM konusu news_<dil>
## YARIŞ ve HEDİYE hesaba gider: jeton push/p_{uid} = {token, lang, prefs: {race, gift}} belgesinde, sunucu kapatılan
## türü göndermez. DUYURU jetonla değil KONUYLA gider: misafir de alır (cihaz konuya abone olur, belge yazılmaz).
## Rızasız jeton yazılmaz, konuya abone olunmaz: oyuncu bildirimleri AÇ der → (Android 13+) bildirim izni → jeton.
## Oturum açıldıkça jeton / dil / tür değiştiyse hesap belgesi yeniden yazılır; dil değişince konu değişir.
## ÇIKIŞ: cihaz jetonu yenilenir (deleteToken → yeni jeton, konuya yeniden abone): eski hesabın yarış / hediye bildirimi
## bu telefona artık gelmez (sunucu geçersiz jetonu ilk gönderimde siler), duyurular gelmeye devam eder.
## NEREDEN AÇILIR: AYARLAR → SES VE BİLDİRİMLER → BİLDİRİMLER (ana anahtar + üç tür) ve İLK YARIŞTAN SONRA bir kez çıkan
## öneri (PushPrompt). İzin oyun açılışında İSTENMEZ. Öneri bu cihazda bir kez gösterilir (should_ask / mark_asked).
##
## Firebase eklentisinde mesajlaşma modülü yok: kütüphane export_plugin.gd bağımlılığıyla gelir, jeton ve konu Godot'un
## JavaClassWrapper köprüsüyle (Task.isComplete yoklanır — Java dinleyicisi gerekmez). GarageSystem kurar, "push"
## grubundan bulunur. Cihaza özel durum: user://push.json {enabled, asked, token, lang, topic, uid, prefs}.

signal changed

const FILE: String = "user://push.json"
const PERMISSION: String = "android.permission.POST_NOTIFICATIONS"
## Bu API düzeyinden itibaren bildirim için çalışma anı izni gerekir (Android 13).
const PERMISSION_SDK: int = 33
const TOKEN_WAIT: float = 15.0
const MESSAGING_CLASS: String = "com.google.firebase.messaging.FirebaseMessaging"
const TOPIC_PREFIX: String = "news_"

const RACE: StringName = &"race"
const GIFT: StringName = &"gift"
const NEWS: StringName = &"news"
const KINDS: Array[StringName] = [RACE, GIFT, NEWS]

## QA / masaüstü görüntüsü: düğmeyi Android olmadan göstermek için.
static var force_available: bool = false

## Son AÇ denemesi neden olmadı (AYARLAR satırı gösterir; HUD bildirimi ayarlar açıkken görünmüyor). Başarıda boş.
var last_failure: String = ""
## Masaüstü / testte abone olunan konu (Android'de FCM tutar).
var fake_topic: String = ""

var _social: SocialManager
var _state: Dictionary = {}
var _busy: bool = false
var _seen_uid: String = ""


func _ready() -> void:
	add_to_group("push")
	_state = _read()
	_connect.call_deferred()


func _connect() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social:
		_social.changed.connect(_on_social_changed)
	if is_enabled() and available() and SaveSafe.s(_state.get("topic", "")) != _wanted_topic():
		_sync_topic()   # dil değişti (sahne yeniden kuruldu) ya da DUYURU türü değişti


## Bildirim açılabilir mi (Android + Firebase eklentisi). Misafir de açabilir (yalnız DUYURU gelir).
func available() -> bool:
	return unavailable_reason() == ""


## Neden açılamıyor: "" açılabilir, "platform" Android değil ya da Firebase eklentisi yok (AYARLAR satırı gizlenir).
func unavailable_reason() -> String:
	if not (force_available or (OS.get_name() == "Android" and Engine.has_singleton("GodotFirebaseAndroid"))):
		return "platform"
	return ""


## Hesaba bağlı türler (YARIŞ, HEDİYE) çalışır mı: oturum açık. Misafirde AYARLAR bu türleri kilitli gösterir.
func has_account() -> bool:
	return _social != null and not _social.uid().is_empty()


## İLK YARIŞTAN SONRAKİ ÖNERİ gösterilsin mi: açılabilir, kapalı ve bu cihazda henüz sorulmadı.
func should_ask() -> bool:
	return available() and not is_enabled() and not _busy and not bool(_state.get("asked", false))


## Öneri gösterildi (ya da oyuncu kendisi açtı / kapattı): bir daha sorulmaz.
func mark_asked() -> void:
	if not bool(_state.get("asked", false)):
		_state["asked"] = true
		_write()


## Bu cihazda bildirimler açık mı (izin verildi, jeton alındı).
func is_enabled() -> bool:
	return bool(_state.get("enabled", false))


func is_busy() -> bool:
	return _busy


## Tür açık mı (yazılmayan tür açık sayılır).
func pref(kind: StringName) -> bool:
	var prefs: Variant = _state.get("prefs", {})
	return (prefs as Dictionary).get(String(kind), true) != false if prefs is Dictionary else true


## Türü açar / kapatır: DUYURU konuya aboneliği, YARIŞ / HEDİYE hesap belgesini değiştirir.
func set_pref(kind: StringName, on: bool) -> void:
	if not KINDS.has(kind) or pref(kind) == on or _busy:
		return
	var prefs: Dictionary = _state.get("prefs", {}) if _state.get("prefs") is Dictionary else {}
	prefs[String(kind)] = on
	_state["prefs"] = prefs
	_write()
	changed.emit()
	if not is_enabled():
		return
	_busy = true
	if kind == NEWS:
		await _sync_topic_now()
	elif has_account():
		await _write_account(SaveSafe.s(_state.get("token", "")))
	_busy = false
	changed.emit()


## BİLDİRİMLER: AÇ — izin + jeton + DUYURU konusu + (hesap varsa) sunucu belgesi. Başarısızsa nedeni notice ile söylenir.
func enable() -> bool:
	if not available() or _busy:
		return false
	_busy = true
	_state["asked"] = true
	last_failure = ""
	changed.emit()
	var ok: bool = await _ask_permission()
	var token: String = ""
	if not ok:
		last_failure = Loc.t("Bildirim izni verilmedi. Telefonun Ayarlar > Uygulamalar bölümünden açabilirsin.")
	else:
		token = await _fetch_token()
		ok = not token.is_empty()
		if ok and has_account():
			ok = await _write_account(token)
		if not ok:
			last_failure = Loc.t("Bildirimler açılamadı. İnternet bağlantını kontrol edip tekrar dene.")
	if ok:
		_state["enabled"] = true
		_state["token"] = token
		await _sync_topic_now()
		_notice(Loc.t("Bildirimler açık: hediye, yarış ve duyurularda haber vereceğiz."))
	else:
		_notice(last_failure)
	_write()
	_busy = false
	changed.emit()
	return ok


## BİLDİRİMLER: KAPAT — sunucudaki hesap belgesi silinir, konudan çıkılır, cihaz jetonu geçersiz kılınır.
func disable() -> void:
	if _busy:
		return
	_busy = true
	changed.emit()
	if has_account():
		await _social.delete_push_token()
	await _set_topic("")
	_delete_token()
	_state["enabled"] = false
	_state["asked"] = true
	_state.erase("uid")
	last_failure = ""
	_write()
	_busy = false
	changed.emit()


## Oturum açıldı: açık bildirimde jeton (yenilenmiş olabilir), dil ya da türler değiştiyse hesap belgesi yazılır.
## Oturum kapandı (çıkış): jeton yenilenir, eski hesabın bildirimleri bu cihaza gelmez; DUYURU aboneliği sürer.
func _on_social_changed() -> void:
	var uid: String = _social.uid()
	if uid == _seen_uid:
		return
	var signed_out: bool = uid.is_empty() and not _seen_uid.is_empty()
	_seen_uid = uid
	if not is_enabled() or not available():
		return
	if signed_out:
		_renew_token()
	elif not uid.is_empty():
		_refresh_account()


## Oturum başında bir kez: jeton (FCM arada yenileyebilir), hesap ya da dil değiştiyse belge yeniden yazılır.
func _refresh_account() -> void:
	if _busy:
		return
	_busy = true
	var token: String = await _fetch_token()
	if not token.is_empty() and has_account() and (token != SaveSafe.s(_state.get("token", ""))
			or SaveSafe.s(_state.get("uid", "")) != _social.uid() or SaveSafe.s(_state.get("lang", "")) != Loc.current()):
		_state["token"] = token
		await _write_account(token)
		_write()
	_busy = false


## Çıkıştan sonra: eski jeton silinir (eski hesabın belgesi geçersiz kalır), yeni jeton DUYURU konusuna abone olur.
func _renew_token() -> void:
	if _busy:
		return
	_busy = true
	await _delete_token_now()
	_state.erase("uid")
	_state["topic"] = ""
	_state["token"] = await _fetch_token()
	await _sync_topic_now()
	_write()
	_busy = false
	changed.emit()


## Hesap belgesi: push/p_{uid} = {token, lang, prefs: {race, gift}}.
func _write_account(token: String) -> bool:
	if token.is_empty() or not has_account():
		return false
	var ok: bool = await _social.write_push_token(token, Loc.current(), {"race": pref(RACE), "gift": pref(GIFT)})
	if ok:
		_state["uid"] = _social.uid()
		_state["lang"] = Loc.current()
	return ok


func _notice(text: String) -> void:
	if _social:
		_social.notice.emit(text)


# --- DUYURU konusu -------------------------------------------------------------------

## Abone olunması gereken konu: açık ve DUYURU türü açıksa news_<dil>, değilse yok.
func _wanted_topic() -> String:
	return TOPIC_PREFIX + Loc.current() if is_enabled() and pref(NEWS) else ""


func _sync_topic() -> void:
	if _busy:
		return
	_busy = true
	await _sync_topic_now()
	_write()
	_busy = false


func _sync_topic_now() -> void:
	await _set_topic(_wanted_topic())


## Eski konudan çıkar, yenisine abone olur (aynıysa bir şey yapmaz).
func _set_topic(topic: String) -> void:
	var current: String = SaveSafe.s(_state.get("topic", ""))
	if current == topic:
		return
	if not current.is_empty():
		await _topic_call(&"unsubscribeFromTopic", current)
	if topic.is_empty() or await _topic_call(&"subscribeToTopic", topic):
		_state["topic"] = topic
	else:
		_state["topic"] = ""   # abone olunamadı: sonraki açılışta yeniden denenir


func _topic_call(method: StringName, topic: String) -> bool:
	if force_available and OS.get_name() != "Android":
		fake_topic = topic if method == &"subscribeToTopic" else ""
		return true
	var messaging: Variant = _messaging()
	if messaging == null:
		return false
	return await _wait_task(messaging.call(method, topic))


# --- Android ----------------------------------------------------------------------

func _ask_permission() -> bool:
	if force_available and OS.get_name() != "Android":
		return true
	if GallerySaver.android_sdk() < PERMISSION_SDK or OS.get_granted_permissions().has(PERMISSION):
		return true
	if OS.request_permission(PERMISSION):
		return true   # zaten verilmiş
	var answer: Array = await get_tree().on_request_permissions_result
	return answer.size() >= 2 and String(answer[0]) == PERMISSION and bool(answer[1])


## FirebaseMessaging.getInstance().getToken() → Task; tamamlanana kadar yoklanır. Alınamazsa boş.
func _fetch_token() -> String:
	if force_available and OS.get_name() != "Android":
		return "qa-token-" + "0".repeat(40)
	var messaging: Variant = _messaging()
	if messaging == null:
		return ""
	var task: Variant = messaging.call(&"getToken")
	if not await _wait_task(task):
		return ""
	var result: Variant = task.call(&"getResult")
	if result is String:
		return result
	if result is Object:   # köprü String'i JavaObject olarak verirse
		return String((result as Object).call(&"toString"))
	return ""


## Task tamamlanana kadar (en çok TOKEN_WAIT) yoklar; başarılıysa true.
func _wait_task(task: Variant) -> bool:
	if task == null:
		return false
	var waited: float = 0.0
	while not bool(task.call(&"isComplete")) and waited < TOKEN_WAIT:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	return bool(task.call(&"isComplete")) and bool(task.call(&"isSuccessful"))


func _delete_token() -> void:
	var messaging: Variant = _messaging()
	if messaging:
		messaging.call(&"deleteToken")   # Task; beklenmez (sunucu eski jetonu ilk gönderimde siler)


## Jeton silinene kadar bekler (yeni jeton ancak eskisi silinince alınır).
func _delete_token_now() -> void:
	var messaging: Variant = _messaging()
	if messaging:
		await _wait_task(messaging.call(&"deleteToken"))


func _messaging() -> Variant:
	if OS.get_name() != "Android":
		return null
	var cls: JavaClass = JavaClassWrapper.wrap(MESSAGING_CLASS)
	if cls == null:
		push_warning("PushService: FirebaseMessaging yok (firebase-messaging bağımlılığı?)")
		return null
	return cls.call(&"getInstance")


func _read() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed if parsed is Dictionary else {}


func _write() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_state))
