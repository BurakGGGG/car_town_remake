class_name InstallReferrer
extends RefCounted
## PLAY YÜKLEME KAYNAĞI (2026-10-23, ARKADAŞ DAVETİ Faz 3; docs/ARKADAS_DAVET.md). Davet sayfası oyunu yüklü olmayanı
## Play'e `&referrer=ref%3D<KOD>` ile yollar; Play bu metni kurulumla saklar (90 gün). Oyun ilk açılışta Google'ın
## Install Referrer kütüphanesiyle (com.android.installreferrer, Gradle bağımlılığı addons/autoyard_android) okur ve
## `ref=` kodunu ReferralManager'a verir (kaynak "play"). Eklenti yok: dinleyici arayüzü (InstallReferrerStateListener)
## JavaClassWrapper.create_proxy ile GDScript nesnesinden kurulur. Dinleyici Android'in UI iş parçacığında çağrılır →
## yalnızca sonucu call_deferred ile Godot'nun iş parçacığına aktarır.
## Kesin sonuçta (OK, desteklenmiyor, geliştirici hatası) bir daha sorulmaz; servis geçici yoksa sonraki açılışta yeniden
## denenir (en çok MAX_TRIES). Durum ReferralManager'ın cihaz dosyasında ("play_ref": {done, tries}).

const CLIENT_CLASS: String = "com.android.installreferrer.api.InstallReferrerClient"
const LISTENER_CLASS: String = "com.android.installreferrer.api.InstallReferrerStateListener"
## InstallReferrerClient.InstallReferrerResponse
const OK: int = 0
const SERVICE_UNAVAILABLE: int = 1
const FEATURE_NOT_SUPPORTED: int = 2
const DEVELOPER_ERROR: int = 3
const MAX_TRIES: int = 3

## Süreç başına bir kez sorulur (sahne girişte yeniden kurulsa da).
static var _started: bool = false
static var _client: Object
static var _listener: _Listener
static var _proxy: Object


## Android'de, daha önce kesin sonuç alınmadıysa yükleme kaynağını sorar. Sonuç: on_code(kod) (kod yoksa çağrılmaz).
static func check(on_code: Callable) -> void:
	if _started or OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var meta: Dictionary = ReferralManager._read_meta()
	var state: Dictionary = meta.get("play_ref", {}) if meta.get("play_ref") is Dictionary else {}
	if SaveSafe.b(state.get("done", false)) or SaveSafe.i(state.get("tries", 0)) >= MAX_TRIES:
		return
	_started = true
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	var client_class: JavaClass = JavaClassWrapper.wrap(CLIENT_CLASS)
	if activity == null or client_class == null:
		_finish(-1, "", on_code)
		return
	var builder: Object = client_class.call("newBuilder", activity)
	_client = builder.call("build") if builder and not _failed() else null
	if _client == null or _failed():
		_finish(-1, "", on_code)   # kütüphane pakette yok (eski dışa aktarma)
		return
	_listener = _Listener.new()
	_listener.on_result = func(code: int) -> void: _on_setup.call_deferred(code, on_code)
	_proxy = JavaClassWrapper.create_proxy(_listener, PackedStringArray([LISTENER_CLASS]))
	if _proxy == null:
		_finish(-1, "", on_code)
		return
	_client.call("startConnection", _proxy)
	if _failed():
		_finish(-1, "", on_code)


## Kaynak metninden davet kodu: "ref=K7P2QX&inv=…" (Play metni URL kodlu gelebilir). Yoksa boş.
static func parse(referrer: String) -> String:
	var text: String = referrer.uri_decode()
	for pair: String in text.split("&"):
		if pair.begins_with("ref="):
			var code: String = SocialNames.normalize_code(pair.substr(4))
			return code if SocialNames.is_valid_code(code) else ""
	return ""


static func _on_setup(code: int, on_code: Callable) -> void:
	var referrer: String = ""
	if code == OK and _client:
		var details: Object = _client.call("getInstallReferrer")
		if details and not _failed():
			var value: Variant = details.call("getInstallReferrer")
			referrer = value if value is String else ""
	_finish(code, referrer, on_code)


static func _finish(code: int, referrer: String, on_code: Callable) -> void:
	if _client:
		_client.call("endConnection")
		_failed()
	var meta: Dictionary = ReferralManager._read_meta()
	var state: Dictionary = meta.get("play_ref", {}) if meta.get("play_ref") is Dictionary else {}
	state["tries"] = SaveSafe.i(state.get("tries", 0)) + 1
	state["done"] = code in [OK, FEATURE_NOT_SUPPORTED, DEVELOPER_ERROR]
	meta["play_ref"] = state
	ReferralManager._write_meta(meta)
	var found: String = parse(referrer)
	if OS.is_debug_build():
		print("InstallReferrer: yanıt %d, kaynak '%s', kod '%s'" % [code, referrer.left(120), found])
	_client = null
	_proxy = null
	_listener = null
	if not found.is_empty() and on_code.is_valid():
		on_code.call(found)


static func _failed() -> bool:
	var exception: JavaObject = JavaClassWrapper.get_exception()
	if exception == null:
		return false
	push_warning("InstallReferrer: %s" % str(exception.call("toString")))
	return true


## InstallReferrerStateListener'ın GDScript karşılığı (create_proxy yöntem adlarını Java arayüzüyle eşler).
class _Listener:
	extends RefCounted
	var on_result: Callable

	func onInstallReferrerSetupFinished(response_code: int) -> void:
		on_result.call(response_code)

	func onInstallReferrerServiceDisconnected() -> void:
		pass
