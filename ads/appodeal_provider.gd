class_name AppodealProvider
extends AdProvider
## GERÇEK sağlayıcı (2026-10-22'den beri): Appodeal 4.4 (aracı platform). Eklenti YOK: SDK ve ağ adaptörleri Gradle
## bağımlılığıdır (AdConfig.APPODEAL_DEPENDENCIES, addons/autoyard_android), oyun SDK'yla Godot'un Java köprüsüyle
## konuşur (JavaClassWrapper; geri çağrı arayüzleri create_proxy ile GDScript nesnesine bağlanır).
## Yalnızca Android'de, Appodeal sınıfı pakette varken ve AdConfig.appodeal_ready() iken kurulur (AdService seçer).
##
## Kural notları:
##  * Hata ayıklama derlemesinde TEST reklamı (setTesting, başlatmadan ÖNCE): geliştiricinin gerçek reklamı izlemesi
##    geçersiz trafik sayılır. Sürüm derlemesinde gerçek reklam.
##  * AB onayı (GDPR): Appodeal 4 başlatırken Google UMP tabanlı onay penceresini KENDİSİ gösterir (yalnız AEA);
##    sonradan değiştirmek için AYARLAR → REKLAM GİZLİLİK SEÇENEKLERİ (ConsentManager.showPrivacyOptionsForm).
##  * Appodeal'ın geri çağrıları Android ana (UI) iş parçacığından gelir → her biri call_deferred ile Godot karesinde
##    işlenir (AdProvider sözleşmesi de "bir sonraki kare" der).
##  * Yuva başına birim yok: iki yuva tek ödüllü önbelleği paylaşır; otomatik önbellek KAPALI, yüklemeyi AdService
##    yönetir (load_rewarded → cache). Bir yükleme sürerken gelen istekler aynı sonucu bekler.
##  * Ödül onRewardedVideoFinished ile gelir; bazı ağlarda yalnız onRewardedVideoClosed(finished=true) gelir → o da ödül
##    sayılır. Ödül ve bitiş her gösterimde en çok BİR kez iletilir.

const APPODEAL_CLASS: String = "com.appodeal.ads.Appodeal"
const CONSENT_CLASS: String = "com.appodeal.consent.ConsentManager"
const REWARDED_CALLBACKS: String = "com.appodeal.ads.RewardedVideoCallbacks"
const INIT_CALLBACK: String = "com.appodeal.ads.initializing.ApdInitializationCallback"
const DISMISS_LISTENER: String = "com.appodeal.consent.OnConsentFormDismissedListener"
const LOG_LEVEL_CLASS: String = "com.appodeal.ads.utils.Log$LogLevel"
## Appodeal.REWARDED_VIDEO (paketin sabiti, javap ile doğrulandı).
const REWARDED_VIDEO: int = 128
## Yükleme geri çağrısı gelmezse yuva "yükleniyor"da kalmasın (AdService kendi yeniden denemesini yapar).
const LOAD_TIMEOUT: float = 60.0
## isLoaded sorgusu (JNI) en çok bu sıklıkla yapılır; arada önbellekteki cevap kullanılır.
const LOADED_POLL_MS: int = 500

var _appodeal: JavaClass
var _activity: Object
## Geri çağrı nesneleri VE Java vekilleri ikisi de tutulur: vekil GDScript nesnesini tutmuyor — nesne düşerse Java
## çağırınca "Parameter obj is null" (callable_jni) olur, geri çağrı kaybolur (telefonda görüldü 2026-10-23).
var _callbacks: _RewardedCallbacks
var _callbacks_proxy: Object
var _init_callback: _InitCallback
var _init_proxy: Object
var _dismissed: _Dismissed
var _dismiss_proxy: Object
var _waiters: Array[Callable] = []
var _load_serial: int = 0
var _loaded: bool = false
var _loaded_checked_ms: int = -LOADED_POLL_MS
var _on_earned: Callable
var _on_finished: Callable
var _earned: bool = false
var _finished: bool = true


## Bu derlemede Appodeal kullanılabilir mi (Android + SDK pakette)?
static func available() -> bool:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return false
	var cls: JavaClass = JavaClassWrapper.wrap(APPODEAL_CLASS)
	return cls != null and cls.get_java_class_name() == APPODEAL_CLASS and cls.has_java_method(&"initialize")


func start(on_ready: Callable) -> void:
	_appodeal = JavaClassWrapper.wrap(APPODEAL_CLASS)
	_activity = Engine.get_singleton("AndroidRuntime").call("getActivity")
	if _appodeal == null or _activity == null:
		on_ready.call_deferred(false)
		return
	_appodeal.call(&"setTesting", OS.is_debug_build())
	if OS.is_debug_build():
		# Ayrıntılı SDK günlüğü (logcat "Appodeal"); enum değeri valueOf ile alınır (javap: Log$LogLevel.verbose)
		var level_class: JavaClass = JavaClassWrapper.wrap(LOG_LEVEL_CLASS)
		var level: Variant = level_class.call(&"valueOf", "verbose") if level_class else null
		if level != null:
			_appodeal.call(&"setLogLevel", level)
	_appodeal.call(&"setAutoCache", REWARDED_VIDEO, false)
	_callbacks = _RewardedCallbacks.new(self)
	_callbacks_proxy = JavaClassWrapper.create_proxy(_callbacks, PackedStringArray([REWARDED_CALLBACKS]))
	_appodeal.call(&"setRewardedVideoCallbacks", _callbacks_proxy)
	_init_callback = _InitCallback.new(self, on_ready)
	_init_proxy = JavaClassWrapper.create_proxy(_init_callback, PackedStringArray([INIT_CALLBACK]))
	_appodeal.call(&"initialize", _activity, AdConfig.APPODEAL_APP_KEY, REWARDED_VIDEO, _init_proxy)


## Başlatma bitti. Kritik olmayan hatalar (ör. bir ağın başlayamaması) reklamı engellemez: hazır sayılır, gösterim
## yine isLoaded'a bağlıdır.
func _on_initialized(errors: Variant, on_ready: Callable) -> void:
	if errors != null and str(errors) not in ["", "[]", "<null>"]:
		push_warning("Appodeal: başlatma uyarıları: %s" % str(errors).left(300))
	on_ready.call(true)


func unit_for(slot: StringName) -> String:
	return AdConfig.appodeal_unit(slot)


func load_rewarded(_slot: StringName, _unit_id: String, on_result: Callable) -> void:
	if _is_loaded(true):
		on_result.call_deferred(true)
		return
	_waiters.append(on_result)
	if _waiters.size() > 1:
		return   # yükleme zaten sürüyor: aynı sonucu bekler
	_load_serial += 1
	var serial: int = _load_serial
	_appodeal.call(&"cache", _activity, REWARDED_VIDEO)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(LOAD_TIMEOUT).timeout.connect(func() -> void:
			if serial == _load_serial and not _waiters.is_empty():
				push_warning("Appodeal: ödüllü reklam %d sn'de yüklenmedi" % int(LOAD_TIMEOUT))
				_resolve_load(false))


func _resolve_load(ok: bool) -> void:
	_loaded = ok
	_loaded_checked_ms = Time.get_ticks_msec()
	_load_serial += 1
	var waiters: Array[Callable] = _waiters.duplicate()
	_waiters.clear()
	for on_result: Callable in waiters:
		on_result.call(ok)


func show_rewarded(_slot: StringName, on_earned: Callable, on_finished: Callable) -> void:
	if not _finished or not _is_loaded(true):
		on_finished.call_deferred()
		return
	_on_earned = on_earned
	_on_finished = on_finished
	_earned = false
	_finished = false
	_loaded = false
	if not bool(_appodeal.call(&"show", _activity, REWARDED_VIDEO)):
		push_warning("Appodeal: gösterim başlatılamadı")
		_finish.call_deferred()


func _grant() -> void:
	if _earned or _finished:
		return
	_earned = true
	_on_earned.call()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_on_finished.call()


func has_rewarded(_slot: StringName) -> bool:
	return _finished and _is_loaded(false)


## Yüklü ödüllü reklam var mı? `fresh` ya da son sorgu eskiyse SDK'ya sorulur (süresi dolan reklam da düşer).
func _is_loaded(fresh: bool) -> bool:
	if _appodeal == null:
		return false
	var now: int = Time.get_ticks_msec()
	if fresh or now - _loaded_checked_ms >= LOADED_POLL_MS:
		_loaded = bool(_appodeal.call(&"isLoaded", REWARDED_VIDEO))
		_loaded_checked_ms = now
	return _loaded


func privacy_options_required() -> bool:
	var consent: JavaClass = JavaClassWrapper.wrap(CONSENT_CLASS)
	if consent == null:
		return false
	var status: Variant = consent.call(&"getPrivacyOptionsRequirementStatus")
	return status is Object and str((status as Object).call(&"name")) == "Required"


func show_privacy_options(on_done: Callable) -> void:
	var consent: JavaClass = JavaClassWrapper.wrap(CONSENT_CLASS)
	if consent == null or _activity == null:
		on_done.call_deferred()
		return
	_dismissed = _Dismissed.new(on_done)
	_dismiss_proxy = JavaClassWrapper.create_proxy(_dismissed, PackedStringArray([DISMISS_LISTENER]))
	consent.call(&"showPrivacyOptionsForm", _activity, _dismiss_proxy)


# --- Java geri çağrıları (Android UI iş parçacığı) → Godot karesi ------------------------------------------

## com.appodeal.ads.RewardedVideoCallbacks
class _RewardedCallbacks extends RefCounted:
	var _provider: WeakRef

	func _init(provider: AppodealProvider) -> void:
		_provider = weakref(provider)

	func _call(method: StringName, args: Array = []) -> void:
		var provider: Object = _provider.get_ref()
		if provider:
			Callable(provider, method).bindv(args).call_deferred()

	func onRewardedVideoLoaded(_is_precache: Variant) -> void:
		_call(&"_resolve_load", [true])

	func onRewardedVideoFailedToLoad() -> void:
		_call(&"_resolve_load", [false])

	func onRewardedVideoShown() -> void:
		pass

	func onRewardedVideoShowFailed() -> void:
		_call(&"_finish")

	func onRewardedVideoFinished(_amount: Variant, _currency: Variant) -> void:
		_call(&"_grant")

	func onRewardedVideoClosed(finished: Variant) -> void:
		if bool(finished):
			_call(&"_grant")
		_call(&"_finish")

	func onRewardedVideoExpired() -> void:
		_call(&"_expired")

	func onRewardedVideoClicked() -> void:
		pass


func _expired() -> void:
	_loaded = false
	_loaded_checked_ms = Time.get_ticks_msec()


## com.appodeal.ads.initializing.ApdInitializationCallback
class _InitCallback extends RefCounted:
	var _provider: WeakRef
	var _on_ready: Callable

	func _init(provider: AppodealProvider, on_ready: Callable) -> void:
		_provider = weakref(provider)
		_on_ready = on_ready

	func onInitializationFinished(errors: Variant) -> void:
		var provider: Object = _provider.get_ref()
		if provider:
			Callable(provider, &"_on_initialized").call_deferred(str(errors) if errors != null else "", _on_ready)


## com.appodeal.consent.OnConsentFormDismissedListener
class _Dismissed extends RefCounted:
	var _on_done: Callable

	func _init(on_done: Callable) -> void:
		_on_done = on_done

	func onConsentFormDismissed(_error: Variant) -> void:
		_on_done.call_deferred()
