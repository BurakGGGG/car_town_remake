class_name PushService
extends Node
## TELEFON BİLDİRİMİ (FCM): arkadaşın senin aracını yenince oyun KAPALIYKEN de telefonuna "Bob Usta yarışta aracını
## yendi! İntikam almak için dokun" bildirimi gelir. Bildirimi sunucu gönderir (firebase/functions: news.js — yalnızca
## gönderen kazandıysa, aynı gönderen → aynı alıcı çiftine 6 saatte en çok bir; kullanıcı kuralı 2026-10-17).
## Bu düğüm yalnızca cihaz jetonunu yönetir: oyuncu ARKADAŞLAR → YARIŞ BİLDİRİMLERİ: AÇ der → (Android 13+) bildirim izni
## → FirebaseMessaging jetonu → push/p_{uid} = {token, lang}. Rızasız jeton yazılmaz. Oturum açıldıkça jeton / dil
## değiştiyse yeniden yazılır; oyuncu çıkış yapınca jeton geçersiz kılınır (deleteToken: sunucu da belgeyi siler).
##
## Firebase eklentisinde mesajlaşma modülü yok: kütüphane export_plugin.gd bağımlılığıyla gelir, jeton Godot'un
## JavaClassWrapper köprüsüyle alınır (Task.isComplete yoklanır — Java dinleyicisi gerekmez). GarageSystem kurar,
## "push" grubundan bulunur. Cihaza özel durum: user://push.json {enabled, uid, token, lang}.

signal changed

const FILE: String = "user://push.json"
const PERMISSION: String = "android.permission.POST_NOTIFICATIONS"
## Bu API düzeyinden itibaren bildirim için çalışma anı izni gerekir (Android 13).
const PERMISSION_SDK: int = 33
const TOKEN_WAIT: float = 15.0
const MESSAGING_CLASS: String = "com.google.firebase.messaging.FirebaseMessaging"

## QA / masaüstü görüntüsü: düğmeyi Android olmadan göstermek için.
static var force_available: bool = false

var _social: SocialManager
var _state: Dictionary = {}
var _busy: bool = false
var _seen_ready: bool = false
var _refreshed_uid: String = ""


func _ready() -> void:
	add_to_group("push")
	_state = _read()
	_connect.call_deferred()


func _connect() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social:
		_social.changed.connect(_on_social_changed)


## Bildirim açılabilir mi (Android + Firebase eklentisi + sosyal oturum hazır).
func available() -> bool:
	if _social == null or not _social.is_ready():
		return false
	return force_available or (OS.get_name() == "Android" and Engine.has_singleton("GodotFirebaseAndroid"))


## Bu hesap için açık mı (cihazdaki son durum).
func is_enabled() -> bool:
	return bool(_state.get("enabled", false)) and _social != null and SaveSafe.s(_state.get("uid", "")) == _social.uid()


func is_busy() -> bool:
	return _busy


## YARIŞ BİLDİRİMLERİ: AÇ — izin + jeton + sunucuya kayıt. Başarısızsa nedeni SocialManager.notice ile söylenir.
func enable() -> bool:
	if not available() or _busy:
		return false
	_busy = true
	changed.emit()
	var ok: bool = await _ask_permission()
	var token: String = ""
	if not ok:
		_social.notice.emit(Loc.t("Bildirim izni verilmedi. Telefonun Ayarlar > Uygulamalar bölümünden açabilirsin."))
	else:
		token = await _fetch_token()
		ok = not token.is_empty() and await _social.write_push_token(token, Loc.current())
		if not ok:
			_social.notice.emit(Loc.t("Bildirimler açılamadı. İnternet bağlantını kontrol edip tekrar dene."))
	if ok:
		_state = {"enabled": true, "uid": _social.uid(), "token": token, "lang": Loc.current()}
		_write()
		_social.notice.emit(Loc.t("Yarış bildirimleri açık: arkadaşın seni yenince haber vereceğiz."))
	_busy = false
	changed.emit()
	return ok


## YARIŞ BİLDİRİMLERİ: KAPAT — sunucudaki kayıt silinir, cihaz jetonu geçersiz kılınır.
func disable() -> void:
	if _busy:
		return
	_busy = true
	changed.emit()
	if _social:
		await _social.delete_push_token()
	_delete_token()
	_state["enabled"] = false
	_write()
	_busy = false
	changed.emit()


## Oturum açıldı: açık bildirimde jeton (yenilenmiş olabilir) ya da dil (AYARLAR) değiştiyse yeniden yazılır.
## Oturum bu açılışta hazırken kapandıysa (çıkış): jeton geçersiz kılınır.
func _on_social_changed() -> void:
	if _social.is_ready():
		_seen_ready = true
		if is_enabled() and not _busy and _refreshed_uid != _social.uid() and available():
			_refreshed_uid = _social.uid()
			_refresh_token()
	elif _seen_ready and _social.get_state() == SocialManager.State.SIGNED_OUT and bool(_state.get("enabled", false)):
		_seen_ready = false
		_refreshed_uid = ""
		_delete_token()
		_state["enabled"] = false
		_write()
		changed.emit()


func _refresh_token() -> void:
	_busy = true
	var token: String = await _fetch_token()
	if not token.is_empty() and (token != SaveSafe.s(_state.get("token", "")) or Loc.current() != SaveSafe.s(_state.get("lang", ""))):
		if await _social.write_push_token(token, Loc.current()):
			_state["token"] = token
			_state["lang"] = Loc.current()
			_write()
	_busy = false


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
	if task == null:
		return ""
	var waited: float = 0.0
	while not bool(task.call(&"isComplete")) and waited < TOKEN_WAIT:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	if not bool(task.call(&"isComplete")) or not bool(task.call(&"isSuccessful")):
		return ""
	var result: Variant = task.call(&"getResult")
	if result is String:
		return result
	if result is Object:   # köprü String'i JavaObject olarak verirse
		return String((result as Object).call(&"toString"))
	return ""


func _delete_token() -> void:
	var messaging: Variant = _messaging()
	if messaging:
		messaging.call(&"deleteToken")   # Task; beklenmez (sunucu eski jetonu ilk gönderimde siler)


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
