class_name AdMobProvider
extends AdProvider
## GERÇEK sağlayıcı: Poing Studios AdMob eklentisi (addons/admob) → Google Mobile Ads SDK + UMP.
## Yalnızca Android'de, eklenti tekilleri (singleton) varken kurulur; AdService bunu seçer.
##
## Kural notları (eklenti belgesi + Google rehberi):
##  * Reklam nesnesi gösterim bitince destroy() edilir (yerel bellek).
##  * Reklamlar 1 saat sonra geçersiz olur → AdService yeniden yükler.
##  * Google reklamlarında ödül geri çağrısı kapanıştan ÖNCE gelir; aracı (mediation) ağlarda sıra değişebilir,
##    bu yüzden ödül bayrağı kapanışta da okunur ve yalnızca bir kez iletilir.

var _ads: Dictionary = {}       # yuva → RewardedAd
var _loaders: Dictionary = {}   # yuva → RewardedAdLoader


func start(on_ready: Callable) -> void:
	# UMP: önce onay bilgisini güncelle; form gerekiyorsa (AEA/BK/İsviçre) göster; sonra SDK'yı başlat.
	var params: ConsentRequestParameters = ConsentRequestParameters.new()
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	info.update(params,
		func() -> void:
			if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED \
					and info.get_is_consent_form_available():
				_load_and_show_form(on_ready)
			else:
				_init_sdk(on_ready),
		# Onay bilgisi alınamazsa (çevrimdışı vb.) SDK yine başlatılır; Google gerekli onay yoksa kısıtlı reklam sunar.
		func(_error: FormError) -> void:
			_init_sdk(on_ready))


func _load_and_show_form(on_ready: Callable) -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			form.show(func(_error: FormError) -> void:
				_init_sdk(on_ready)),
		func(_error: FormError) -> void:
			_init_sdk(on_ready))


func _init_sdk(on_ready: Callable) -> void:
	# 13+ oyun: reklam içeriği en çok "T" (genç). Çocuk işaretlemesi YOK (hedef kitle çocuk değil).
	var config: RequestConfiguration = RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	MobileAds.set_request_configuration(config)
	var init_listener: OnInitializationCompleteListener = OnInitializationCompleteListener.new()
	init_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		on_ready.call(true)
	MobileAds.initialize(init_listener)


func load_rewarded(slot: StringName, unit_id: String, on_result: Callable) -> void:
	_destroy_ad(slot)
	var loader: RewardedAdLoader = RewardedAdLoader.new()
	_loaders[slot] = loader   # yükleme bitene kadar canlı kalsın
	var callback: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_ads[slot] = ad
		on_result.call(true)
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("AdMob: ödüllü reklam yüklenemedi (%s): %s" % [slot, error.message])
		on_result.call(false)
	loader.load(unit_id, AdRequest.new(), callback)


func show_rewarded(slot: StringName, on_earned: Callable, on_finished: Callable) -> void:
	var ad: RewardedAd = _ads.get(slot, null) as RewardedAd
	if ad == null:
		on_finished.call()
		return
	_ads.erase(slot)   # aynı reklam iki kez gösterilemez
	var state: Array[bool] = [false, false]   # [ödül iletildi, bitti iletildi]
	var finish: Callable = func() -> void:
		if state[1]:
			return
		state[1] = true
		ad.destroy()
		on_finished.call()
	var grant: Callable = func() -> void:
		if state[0]:
			return
		state[0] = true
		on_earned.call()
	var content: FullScreenContentCallback = FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = finish
	content.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("AdMob: gösterilemedi: %s" % error.message)
		finish.call()
	ad.full_screen_content_callback = content
	var listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		grant.call()
	ad.show(listener)


func has_rewarded(slot: StringName) -> bool:
	return _ads.has(slot)


func _destroy_ad(slot: StringName) -> void:
	var old: RewardedAd = _ads.get(slot, null) as RewardedAd
	if old != null:
		old.destroy()
	_ads.erase(slot)
