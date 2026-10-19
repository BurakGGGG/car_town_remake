class_name AppLovinProvider
extends AdProvider
## GERÇEK sağlayıcı (2026-10-19'dan beri): AppLovin MAX (addons/applovin_max, resmi eklenti 1.2.0 + v2 sarmalayıcı).
## Yalnızca Android'de, eklenti tekili varken ve AdConfig.applovin_ready() iken kurulur; AdService bunu seçer.
##
## Kural notları:
##  * Gizlilik değerleri (kişiselleştirme, ABD "satma") SDK başlatılmadan ÖNCE verilmeli (AppLovin belgesi).
##    Karar AdPrivacy'de; onay penceresi yok (bkz. AdPrivacy başlığı).
##  * AppLovin'de herkese açık test birimi yok → debug derlemede SDK test modu bildirmezse reklam KAPALI
##    (geliştirme sırasında gerçek reklam gösterimi = geçersiz trafik).
##  * Eklenti sinyalleri Android UI iş parçacığından gelebilir → her geri çağrı call_deferred ile ana karede işlenir
##    (AdProvider sözleşmesi de "bir sonraki kare" der).
##  * Ödül (on_ad_received_reward) normalde kapanıştan önce gelir; aracı ağlarda sıra değişebilir → AdService
##    kapanıştan sonra iki kare bekler. Ödül ve bitiş her gösterimde en çok BİR kez iletilir.

const SINGLETON: String = "AppLovinMAXGodotPlugin"

var _listener: AppLovinMAX.RewardedAdEventListener
## birim → bekleyen on_result listesi. Yuvalar aynı birimi paylaşır (AdConfig) → tek yükleme, hepsi haber alır.
var _loads: Dictionary = {}
## Son gösterim: birim + geri çağrılar bir sonraki gösterime kadar tutulur (kapanıştan SONRA gelen ödül kaybolmaz).
var _show_unit: String = ""
var _on_earned: Callable
var _on_finished: Callable
var _earned: bool = false
var _finished: bool = true
var _privacy: Dictionary = {}      # AdPrivacy.load_state()


func start(on_ready: Callable) -> void:
	_privacy = AdPrivacy.load_state()
	_apply_privacy()
	if not AdConfig.APPLOVIN_TEST_DEVICES.is_empty():
		AppLovinMAX.set_test_device_advertising_identifiers(Array(AdConfig.APPLOVIN_TEST_DEVICES))
	_listener = AppLovinMAX.RewardedAdEventListener.new()
	_listener.on_ad_loaded = func(unit: String, _info: AppLovinMAX.AdInfo) -> void:
		_resolve_load.call_deferred(unit, true)
	_listener.on_ad_load_failed = func(unit: String, error: AppLovinMAX.ErrorInfo) -> void:
		push_warning("AppLovin: ödüllü reklam yüklenemedi (%s): %s" % [unit, error.message])
		_resolve_load.call_deferred(unit, false)
	_listener.on_ad_received_reward = func(unit: String, _reward: AppLovinMAX.Reward, _info: AppLovinMAX.AdInfo) -> void:
		_grant.call_deferred(unit)
	_listener.on_ad_hidden = func(unit: String, _info: AppLovinMAX.AdInfo) -> void:
		_finish.call_deferred(unit)
	_listener.on_ad_display_failed = func(unit: String, error: AppLovinMAX.ErrorInfo, _info: AppLovinMAX.AdInfo) -> void:
		push_warning("AppLovin: gösterilemedi (%s): %s" % [unit, error.message])
		_finish.call_deferred(unit)
	AppLovinMAX.set_rewarded_ad_listener(_listener)
	var init: AppLovinMAX.InitializationListener = AppLovinMAX.InitializationListener.new()
	init.on_sdk_initialized = func(config: AppLovinMAX.SdkConfiguration) -> void:
		_on_initialized.call_deferred(config, on_ready)
	AppLovinMAX.initialize(AdConfig.APPLOVIN_SDK_KEY, init, Array(AdConfig.applovin_units()))


func _on_initialized(config: AppLovinMAX.SdkConfiguration, on_ready: Callable) -> void:
	# SDK'nın IP'den bulduğu ülke bir sonraki açılışın kararında kullanılır; ülke değiştiyse karar hemen tazelenir.
	var country: String = AdPrivacy.clean_country(config.country_code)
	if country != "" and country != String(_privacy.get("country", "")):
		_privacy["country"] = country
		AdPrivacy.save_state(_privacy)
		_apply_privacy()
	if not config.is_successfully_initialized:
		push_warning("AppLovin: SDK başlatılamadı")
		on_ready.call(false)
		return
	if OS.is_debug_build() and not config.is_test_mode_enabled:
		# Telefonun reklam kimliğini AdConfig.APPLOVIN_TEST_DEVICES'a ya da MAX paneli → Test Mode'a ekle.
		push_warning("AppLovin: debug derleme ama test modu kapalı — gerçek reklam gösterilmez (test cihazı kayıtlı değil)")
		on_ready.call(false)
		return
	on_ready.call(true)


func _apply_privacy() -> void:
	var on: bool = personalized_ads()
	AppLovinMAX.set_has_user_consent(on)
	AppLovinMAX.set_do_not_sell(not on)


func unit_for(slot: StringName) -> String:
	return AdConfig.applovin_unit(slot)


func load_rewarded(_slot: StringName, unit_id: String, on_result: Callable) -> void:
	# MAX hazır reklamın süresini kendisi yönetir; hazırken gelen yükleme isteği (AdService'in 50 dk tazelemesi)
	# geri çağrısız kalabilir ve yuva "yükleniyor"da takılırdı → hazırsa hemen "yüklendi" denir.
	if AppLovinMAX.is_rewarded_ad_ready(unit_id):
		on_result.call_deferred(true)
		return
	var waiting: bool = _loads.has(unit_id)
	if not waiting:
		_loads[unit_id] = []
	(_loads[unit_id] as Array).append(on_result)
	if not waiting:
		AppLovinMAX.load_rewarded_ad(unit_id)


func _resolve_load(unit: String, ok: bool) -> void:
	var waiters: Array = _loads.get(unit, [])
	_loads.erase(unit)
	for on_result: Callable in waiters:
		on_result.call(ok)


func show_rewarded(slot: StringName, on_earned: Callable, on_finished: Callable) -> void:
	var unit: String = unit_for(slot)
	if unit == "" or not _finished or not AppLovinMAX.is_rewarded_ad_ready(unit):
		on_finished.call_deferred()
		return
	_show_unit = unit
	_on_earned = on_earned
	_on_finished = on_finished
	_earned = false
	_finished = false
	AppLovinMAX.show_rewarded_ad(unit, String(slot))   # yerleşim adı = yuva (MAX raporlarında ayrı görünür)


func _grant(unit: String) -> void:
	if unit != _show_unit or _earned:
		return
	_earned = true
	_on_earned.call()


func _finish(unit: String) -> void:
	if unit != _show_unit or _finished:
		return
	_finished = true
	_on_finished.call()


func has_rewarded(slot: StringName) -> bool:
	var unit: String = unit_for(slot)
	return unit != "" and AppLovinMAX.is_rewarded_ad_ready(unit)


func personalization_toggle() -> bool:
	return true


func personalized_ads() -> bool:
	return AdPrivacy.personalized(int(_privacy.get("choice", AdPrivacy.Choice.UNSET)),
			AdPrivacy.region(String(_privacy.get("country", "")), OS.get_locale()))


func set_personalized_ads(on: bool) -> void:
	_privacy["choice"] = AdPrivacy.Choice.ON if on else AdPrivacy.Choice.OFF
	AdPrivacy.save_state(_privacy)
	_apply_privacy()
